import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:jspdf/jspdf.dart';

void main() {
  // ==========================================================================
  // XMP Metadata
  // ==========================================================================

  group('XMP Metadata', () {
    test('escapeXml escapes special characters', () {
      expect(escapeXml('a & b'), equals('a &amp; b'));
      expect(escapeXml('<tag>'), equals('&lt;tag&gt;'));
      expect(escapeXml('"quoted"'), equals('&quot;quoted&quot;'));
      expect(escapeXml("it's"), equals("it&apos;s"));
    });

    test('buildXmpContent wraps metadata in RDF envelope by default', () {
      final config = XmpMetadataConfig(
        metadata: 'Hello',
        namespaceUri: 'http://example.com/',
        rawXml: false,
      );
      final content = buildXmpContent(config);
      expect(content, contains('<x:xmpmeta'));
      expect(content, contains('<rdf:RDF'));
      expect(content, contains('xmlns:jspdf="http://example.com/"'));
      expect(content, contains('</x:xmpmeta>'));
    });

    test('buildXmpContent with rawXml=true returns content verbatim', () {
      const raw = '<x:xmpmeta><custom/></x:xmpmeta>';
      final config = XmpMetadataConfig(
        metadata: raw,
        rawXml: true,
      );
      final content = buildXmpContent(config);
      expect(content, equals(raw));
    });

    test('JsPdf.addMetadata stores metadata config', () {
      final pdf = JsPdf();
      pdf.addMetadata('Test metadata');
      // Build document and check that it contains /Metadata reference
      final output = pdf.output() as String;
      expect(output, contains('/Metadata'));
      expect(output, contains('/Type /Metadata'));
      expect(output, contains('/Subtype /XML'));
    });

    test('JsPdf.addMetadata with namespace URI', () {
      final pdf = JsPdf();
      pdf.addMetadata('my value', 'http://myns.example.com/');
      final output = pdf.output() as String;
      expect(output, contains('myns.example.com'));
    });

    test('JsPdf.addMetadata with rawXml=true', () {
      final pdf = JsPdf();
      pdf.addMetadata(
          '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF '
          'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
          '</rdf:RDF></x:xmpmeta>',
          true);
      final output = pdf.output() as String;
      expect(output, contains('/Metadata'));
    });
  });

  // ==========================================================================
  // Filters
  // ==========================================================================

  group('Filters', () {
    test('ASCIIHexEncode round-trip', () {
      const input = 'Hello';
      final encoded = asciiHexEncode(input);
      expect(encoded, endsWith('>'));
      final decoded = asciiHexDecode(encoded);
      expect(decoded, equals(input));
    });

    test('ASCIIHexDecode strips trailing >', () {
      final decoded = asciiHexDecode('48656c6c6f>');
      expect(decoded, equals('Hello'));
    });

    test('ASCIIHexDecode handles whitespace', () {
      final decoded = asciiHexDecode('48 65 6c 6c 6f>');
      expect(decoded, equals('Hello'));
    });

    test('ASCIIHexDecode returns empty string for invalid hex', () {
      final decoded = asciiHexDecode('ZZZZ');
      expect(decoded, equals(''));
    });

    test('ASCII85Encode round-trip', () {
      const input = 'Hello World';
      final encoded = ascii85Encode(input);
      expect(encoded, endsWith('~>'));
      final decoded = ascii85Decode(encoded);
      expect(decoded, equals(input));
    });

    test('ASCII85Encode all-zero bytes → z shorthand', () {
      final encoded = ascii85Encode('\x00\x00\x00\x00');
      expect(encoded, startsWith('z'));
    });

    test('ASCII85Decode z expands correctly', () {
      final decoded = ascii85Decode('z~>');
      expect(decoded.length, equals(4));
      expect(decoded.codeUnitAt(0), equals(0));
    });

    test('FlateEncode/Decode round-trip', () {
      const input = 'The quick brown fox jumps over the lazy dog';
      final encoded = flateEncode(input);
      expect(encoded, isNotEmpty);
      expect(encoded, isNot(equals(input)));
      final decoded = flateDecode(encoded);
      expect(decoded, equals(input));
    });

    test('processDataByFilters with ASCIIHexEncode', () {
      final result = processDataByFilters('Hello', ['ASCIIHexEncode']);
      expect(result.data, endsWith('>'));
      expect(result.reverseChain, equals('/ASCIIHexDecode'));
    });

    test('processDataByFilters with chained filters', () {
      final result = processDataByFilters(
        'test data',
        ['FlateEncode', 'ASCIIHexEncode'],
      );
      expect(result.data, isNotEmpty);
      expect(result.reverseChain, equals('/ASCIIHexDecode /FlateDecode'));
    });

    test('processDataByFilters throws on unknown filter', () {
      expect(
        () => processDataByFilters('data', ['UnknownFilter']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('JsPdf.applyFilters delegates to processDataByFilters', () {
      final pdf = JsPdf();
      final result = pdf.applyFilters('Hello', ['ASCIIHexEncode']);
      expect(result.data, endsWith('>'));
    });
  });

  // ==========================================================================
  // RGBA Support
  // ==========================================================================

  group('RGBA Support', () {
    Uint8List _makeRgba(List<int> r, List<int> g, List<int> b, List<int> a) {
      final pixels = Uint8List(r.length * 4);
      for (int i = 0; i < r.length; i++) {
        pixels[i * 4] = r[i];
        pixels[i * 4 + 1] = g[i];
        pixels[i * 4 + 2] = b[i];
        pixels[i * 4 + 3] = a[i];
      }
      return pixels;
    }

    test('processRGBA separates RGB channels', () {
      final pixels = _makeRgba([255, 0], [0, 255], [0, 0], [255, 255]);
      final imgData = RgbaImageData(data: pixels, width: 2, height: 1);
      final image = processRGBA(imgData, 1);
      expect(image.width, equals(2));
      expect(image.height, equals(1));
      expect(image.colorSpace, equals(ColorSpaces.deviceRGB));
      expect(image.bitsPerComponent, equals(8));
      // 2 pixels × 3 channels = 6 bytes
      expect(image.data.length, equals(6));
    });

    test('processRGBA creates sMask when alpha < 255', () {
      final pixels = _makeRgba([255], [0], [0], [128]);
      final imgData = RgbaImageData(data: pixels, width: 1, height: 1);
      final image = processRGBA(imgData, 1);
      expect(image.sMask, isNotNull);
      expect(image.sMask!.length, equals(1));
      expect(image.sMask![0], equals(128));
    });

    test('processRGBA omits sMask when all pixels opaque', () {
      final pixels = _makeRgba([255, 100], [100, 200], [0, 50], [255, 255]);
      final imgData = RgbaImageData(data: pixels, width: 2, height: 1);
      final image = processRGBA(imgData, 1);
      expect(image.sMask, isNull);
    });

    test('JsPdf.addImageFromRGBA adds image to document', () {
      final pixels = Uint8List(4 * 4 * 4); // 4×4 image, RGBA
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255; // R
        pixels[i + 1] = 0; // G
        pixels[i + 2] = 0; // B
        pixels[i + 3] = 255; // A
      }
      final imgData = RgbaImageData(data: pixels, width: 4, height: 4);
      final pdf = JsPdf();
      pdf.addImageFromRGBA(imgData, 10.0, 10.0, 50.0, 50.0);
      final output = pdf.output() as String;
      expect(output, contains('/XObject'));
    });
  });

  // ==========================================================================
  // BMP Support
  // ==========================================================================

  group('BMP Support', () {
    Uint8List _makeBmp24(int width, int height, List<List<int>> rows) {
      // Build a minimal 24-bit BMP
      final int rowStride = (width * 3 + 3) & ~3;
      final int pixelDataSize = rowStride * height;
      final int fileSize = 54 + pixelDataSize;

      final ByteData bd = ByteData(fileSize);
      int offset = 0;

      // BMP file header (14 bytes)
      bd.setUint8(offset++, 0x42); // 'B'
      bd.setUint8(offset++, 0x4d); // 'M'
      bd.setUint32(offset, fileSize, Endian.little);
      offset += 4;
      bd.setUint32(offset, 0, Endian.little); // reserved
      offset += 4;
      bd.setUint32(offset, 54, Endian.little); // pixel data offset
      offset += 4;

      // DIB header (BITMAPINFOHEADER, 40 bytes)
      bd.setUint32(offset, 40, Endian.little); // header size
      offset += 4;
      bd.setUint32(offset, width, Endian.little);
      offset += 4;
      bd.setInt32(offset, height, Endian.little);
      offset += 4;
      bd.setUint16(offset, 1, Endian.little); // planes
      offset += 2;
      bd.setUint16(offset, 24, Endian.little); // bitPP
      offset += 2;
      bd.setUint32(offset, 0, Endian.little); // compression (none)
      offset += 4;
      bd.setUint32(offset, pixelDataSize, Endian.little);
      offset += 4;
      bd.setUint32(offset, 2835, Endian.little); // hr
      offset += 4;
      bd.setUint32(offset, 2835, Endian.little); // vr
      offset += 4;
      bd.setUint32(offset, 0, Endian.little); // colors
      offset += 4;
      bd.setUint32(offset, 0, Endian.little); // importantColors
      offset += 4;

      // Pixel data (bottom-up)
      for (int y = height - 1; y >= 0; y--) {
        final rowIndex = height - 1 - y;
        for (int x = 0; x < width; x++) {
          final pixel = rows[rowIndex][x];
          final r = (pixel >> 16) & 0xFF;
          final g = (pixel >> 8) & 0xFF;
          final b = pixel & 0xFF;
          bd.setUint8(offset++, b); // BMP stores BGR
          bd.setUint8(offset++, g);
          bd.setUint8(offset++, r);
        }
        // Row padding
        while (offset % rowStride != 54 % rowStride) {
          offset++;
        }
      }

      return bd.buffer.asUint8List();
    }

    test('BmpDecoder decodes 24-bit BMP', () {
      final bmpBytes = _makeBmp24(2, 1, [
        [0xFF0000, 0x00FF00],
      ]);
      final decoder = BmpDecoder(bmpBytes);
      expect(decoder.width, equals(2));
      expect(decoder.height, equals(1));
      final data = decoder.getData();
      expect(data.length, equals(8)); // 2×1×4 = 8
    });

    test('processBMP returns PdfImage with correct dimensions', () {
      final bmpBytes = _makeBmp24(2, 2, [
        [0xFF0000, 0x00FF00],
        [0x0000FF, 0xFFFFFF],
      ]);
      final image = processBMP(bmpBytes, 1);
      expect(image.width, equals(2));
      expect(image.height, equals(2));
      expect(image.colorSpace, equals(ColorSpaces.deviceRGB));
    });

    test('BmpDecoder throws on invalid magic bytes', () {
      final badBytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(() => BmpDecoder(badBytes), throwsFormatException);
    });

    test('addImage detects and decodes BMP format', () {
      final bmpBytes = _makeBmp24(1, 1, [
        [0xFF0000],
      ]);
      final pdf = JsPdf();
      // Should not throw
      expect(
        () => pdf.addImage(bmpBytes, 10.0, 10.0, 20.0, 20.0),
        returnsNormally,
      );
    });
  });

  // ==========================================================================
  // Canvas Wrapper
  // ==========================================================================

  group('PdfCanvas', () {
    test('canvas.getContext("2d") returns Context2D', () {
      final pdf = JsPdf();
      final ctx = pdf.canvas.getContext('2d');
      expect(ctx, isNotNull);
      expect(ctx, isA<Context2D>());
    });

    test('canvas.getContext("2d") returns same instance as pdf.context2d', () {
      final pdf = JsPdf();
      final ctx = pdf.canvas.getContext('2d');
      expect(identical(ctx, pdf.context2d), isTrue);
    });

    test('canvas.getContext with unknown type returns null', () {
      final pdf = JsPdf();
      final ctx = pdf.canvas.getContext('webgl');
      expect(ctx, isNull);
    });

    test('canvas width/height default values', () {
      final pdf = JsPdf();
      expect(pdf.canvas.width, equals(150));
      expect(pdf.canvas.height, equals(300));
    });

    test('canvas width/height are settable', () {
      final pdf = JsPdf();
      pdf.canvas.width = 800;
      pdf.canvas.height = 600;
      expect(pdf.canvas.width, equals(800));
      expect(pdf.canvas.height, equals(600));
    });

    test('canvas width resets to 150 on non-positive value', () {
      final pdf = JsPdf();
      pdf.canvas.width = 0;
      expect(pdf.canvas.width, equals(150));
      pdf.canvas.width = -5;
      expect(pdf.canvas.width, equals(150));
    });

    test('canvas height resets to 300 on non-positive value', () {
      final pdf = JsPdf();
      pdf.canvas.height = 0;
      expect(pdf.canvas.height, equals(300));
    });

    test('canvas.toDataURL throws UnsupportedError', () {
      final pdf = JsPdf();
      expect(() => pdf.canvas.toDataURL(), throwsUnsupportedError);
    });

    test('getContext with contextAttributes applies to ctx', () {
      final pdf = JsPdf();
      final ctx = pdf.canvas.getContext('2d', {'lineWidth': 5.0});
      expect(ctx!.lineWidth, equals(5.0));
    });

    test('Context2D.applyAttribute sets fillStyle', () {
      final pdf = JsPdf();
      pdf.context2d.applyAttribute('fillStyle', '#ff0000');
      expect(pdf.context2d.fillStyle, isNotEmpty);
    });

    test('Context2D.applyAttribute ignores unknown keys', () {
      final pdf = JsPdf();
      expect(() => pdf.context2d.applyAttribute('unknownProp', 'value'),
          returnsNormally);
    });
  });
}
