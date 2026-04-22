import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:jspdf/src/modules/addimage.dart';

void main() {
  group('Image Type Detection', () {
    test('detecta JPEG por magic bytes', () {
      final jpegData = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
      ]);
      expect(getImageFileTypeByImageData(jpegData), equals('JPEG'));
    });

    test('detecta JPEG RAW', () {
      final jpegRaw = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB, 0x00]);
      expect(getImageFileTypeByImageData(jpegRaw), equals('JPEG'));
    });

    test('detecta PNG por magic bytes', () {
      final pngData = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
      expect(getImageFileTypeByImageData(pngData), equals('PNG'));
    });

    test('detecta GIF87a', () {
      final gifData = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x37, 0x61,
      ]);
      expect(getImageFileTypeByImageData(gifData), equals('GIF87a'));
    });

    test('detecta GIF89a', () {
      final gifData = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
      ]);
      expect(getImageFileTypeByImageData(gifData), equals('GIF89a'));
    });

    test('detecta BMP', () {
      final bmpData = Uint8List.fromList([0x42, 0x4D, 0x00, 0x00]);
      expect(getImageFileTypeByImageData(bmpData), equals('BMP'));
    });

    test('retorna fallback para dados desconhecidos', () {
      final unknown = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(getImageFileTypeByImageData(unknown), equals('UNKNOWN'));
      expect(getImageFileTypeByImageData(unknown, 'JPEG'), equals('JPEG'));
    });

    test('detecta TIFF Motorola', () {
      final tiff = Uint8List.fromList([0x4D, 0x4D, 0x00, 0x2A]);
      expect(getImageFileTypeByImageData(tiff), equals('TIFF'));
    });

    test('detecta TIFF Intel', () {
      final tiff = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00]);
      expect(getImageFileTypeByImageData(tiff), equals('TIFF'));
    });
  });

  group('sHashCode', () {
    test('gera hash de string', () {
      final hash = sHashCode('hello');
      expect(hash, isNonZero);
    });

    test('hashes diferentes para strings diferentes', () {
      expect(sHashCode('hello'), isNot(equals(sHashCode('world'))));
    });

    test('hash de Uint8List', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final hash = sHashCode(data);
      expect(hash, isNonZero);
    });

    test('hash consistente para mesmos dados', () {
      expect(sHashCode('test'), equals(sHashCode('test')));
    });
  });

  group('validateStringAsBase64', () {
    test('valida base64 correto', () {
      expect(validateStringAsBase64('SGVsbG8='), isTrue);
      expect(validateStringAsBase64('dGVzdA=='), isTrue);
    });

    test('rejeita string vazia', () {
      expect(validateStringAsBase64(''), isFalse);
    });

    test('rejeita comprimento inválido', () {
      expect(validateStringAsBase64('abc'), isFalse);
    });
  });

  group('extractImageFromDataUrl', () {
    test('extrai dados de data URL válida', () {
      const url = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==';
      final result = extractImageFromDataUrl(url);
      expect(result, equals('iVBORw0KGgoAAAANSUhEUg=='));
    });

    test('retorna null para URL inválida', () {
      expect(extractImageFromDataUrl('not a data url'), isNull);
      expect(extractImageFromDataUrl(null), isNull);
    });

    test('retorna null sem base64', () {
      expect(
        extractImageFromDataUrl('data:text/plain,hello'),
        isNull,
      );
    });
  });

  group('binaryStringToUint8Array', () {
    test('converte string para bytes', () {
      final bytes = binaryStringToUint8Array('ABC');
      expect(bytes.length, equals(3));
      expect(bytes[0], equals(65)); // 'A'
      expect(bytes[1], equals(66)); // 'B'
      expect(bytes[2], equals(67)); // 'C'
    });
  });

  group('uint8ArrayToBinaryString', () {
    test('converte bytes para string', () {
      final bytes = Uint8List.fromList([65, 66, 67]);
      expect(uint8ArrayToBinaryString(bytes), equals('ABC'));
    });

    test('roundtrip preserva dados', () {
      const original = 'Hello World!';
      final bytes = binaryStringToUint8Array(original);
      final restored = uint8ArrayToBinaryString(bytes);
      expect(restored, equals(original));
    });
  });

  group('extractJpegInfo', () {
    test('retorna null para dados insuficientes', () {
      expect(extractJpegInfo(Uint8List.fromList([0xFF])), isNull);
    });

    test('retorna null para dados não-JPEG', () {
      expect(
        extractJpegInfo(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])),
        isNull,
      );
    });

    test('extrai info de JPEG válido com SOF0', () {
      // Minimal JPEG with SOF0 marker
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xC0, // SOF0
        0x00, 0x0B, // Length
        0x08, // Precision
        0x00, 0x64, // Height = 100
        0x00, 0xC8, // Width = 200
        0x03, // Num components = 3 (RGB)
        0x01, 0x22, 0x00, // Component 1
      ]);

      final info = extractJpegInfo(jpeg);
      expect(info, isNotNull);
      expect(info!.width, equals(200));
      expect(info.height, equals(100));
      expect(info.numComponents, equals(3));
      expect(info.colorSpace, equals(ColorSpaces.deviceRGB));
    });
  });

  group('PdfImage', () {
    test('cria com dados básicos', () {
      final img = PdfImage(
        data: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 200,
      );
      expect(img.width, equals(100));
      expect(img.height, equals(200));
      expect(img.colorSpace, equals(ColorSpaces.deviceRGB));
      expect(img.bitsPerComponent, equals(8));
    });
  });
}
