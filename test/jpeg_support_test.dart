import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:jspdf/src/modules/jpeg_support.dart';
import 'package:jspdf/src/modules/addimage.dart';

void main() {
  group('getJpegInfoFromBinary', () {
    test('retorna null para dados muito curtos', () {
      expect(getJpegInfoFromBinary('abc'), isNull);
    });

    test('extrai info de JPEG com SOF0', () {
      // Construir JPEG minimalista binário
      // SOI + padding + SOF0 marker
      final bytes = <int>[
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, // APP0
        0x00, 0x02, // Length = 2 (block length for first marker)
        // Após skip do bloco, próximo marker:
        0xFF, 0xC0, // SOF0
        0x00, 0x0B, // Length
        0x08, // Precision
        0x00, 0xC8, // Height = 200
        0x01, 0x00, // Width = 256
        0x03, // 3 components (RGB)
      ];
      final binaryStr = String.fromCharCodes(bytes);
      final info = getJpegInfoFromBinary(binaryStr);
      expect(info, isNotNull);
      expect(info!.width, equals(256));
      expect(info.height, equals(200));
      expect(info.numComponents, equals(3));
      expect(info.colorSpace, equals(ColorSpaces.deviceRGB));
    });
  });

  group('processJpeg', () {
    test('retorna null para dados inválidos', () {
      expect(
        processJpeg(data: 'not a jpeg'),
        isNull,
      );
    });

    test('processa Uint8List válido', () {
      // JPEG mínimo com SOI + SOF0
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, // APP0
        0x00, 0x02, // block length
        0xFF, 0xC0, // SOF0
        0x00, 0x0B,
        0x08,
        0x00, 0x64, // Height = 100
        0x00, 0xC8, // Width = 200
        0x01, // 1 component (Grayscale)
      ]);

      final result = processJpeg(data: bytes, index: 0);
      expect(result, isNotNull);
      expect(result!.width, equals(200));
      expect(result.height, equals(100));
      expect(result.colorSpace, equals(ColorSpaces.deviceGray));
      expect(result.filter, equals('DCTDecode'));
      expect(result.bitsPerComponent, equals(8));
    });

    test('processa binary string', () {
      final bytes = [
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, // APP0
        0x00, 0x02,
        0xFF, 0xC0, // SOF0
        0x00, 0x0B,
        0x08,
        0x00, 0x50, // Height = 80
        0x00, 0xA0, // Width = 160
        0x04, // 4 components (CMYK)
      ];
      final binaryStr = String.fromCharCodes(bytes);

      final result = processJpeg(data: binaryStr);
      expect(result, isNotNull);
      expect(result!.width, equals(160));
      expect(result.height, equals(80));
      expect(result.colorSpace, equals(ColorSpaces.deviceCMYK));
    });

    test('retorna null para tipo não suportado', () {
      expect(processJpeg(data: 42), isNull);
    });

    test('permite override de colorSpace', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x02,
        0xFF, 0xC0, 0x00, 0x0B, 0x08,
        0x00, 0x64, 0x00, 0xC8, 0x03,
      ]);
      final result = processJpeg(
        data: bytes,
        colorSpace: ColorSpaces.deviceGray,
      );
      expect(result, isNotNull);
      expect(result!.colorSpace, equals(ColorSpaces.deviceGray));
    });
  });
}
