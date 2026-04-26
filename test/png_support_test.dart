import 'dart:typed_data';

import 'package:jspdf/src/libs/fast_png.dart';
import 'package:jspdf/src/libs/zlib_codec.dart';
import 'package:jspdf/src/modules/addimage.dart';
import 'package:jspdf/src/modules/png_support.dart';
import 'package:test/test.dart';

void main() {
  group('fast_png decodePng', () {
    test('decodifica RGB com filtros None e Sub', () {
      final png = _buildPng(
        width: 2,
        height: 2,
        depth: 8,
        colorType: pngColorTypeTruecolor,
        rows: <List<int>>[
          <int>[0, 10, 20, 30, 15, 25, 35],
          <int>[1, 40, 50, 60, 5, 5, 5],
        ],
      );

      final decoded = decodePng(png);

      expect(decoded.width, equals(2));
      expect(decoded.height, equals(2));
      expect(decoded.channels, equals(3));
      expect(decoded.depth, equals(8));
      expect(decoded.data,
          equals(<int>[10, 20, 30, 15, 25, 35, 40, 50, 60, 45, 55, 65]));
    });

    test('decodifica paleta e transparencia tRNS', () {
      final png = _buildPng(
        width: 2,
        height: 1,
        depth: 8,
        colorType: pngColorTypeIndexed,
        palette: <int>[255, 0, 0, 0, 0, 255],
        transparency: <int>[255, 0],
        rows: <List<int>>[
          <int>[0, 0, 1],
        ],
      );

      final decoded = decodePng(png);

      expect(decoded.palette, isNotNull);
      expect(decoded.palette![0], equals(<int>[255, 0, 0, 255]));
      expect(decoded.palette![1], equals(<int>[0, 0, 255, 0]));
      expect(decoded.data, equals(<int>[0, 1]));
    });

    test('valida CRC dos chunks', () {
      final png = _buildPng(
        width: 1,
        height: 1,
        depth: 8,
        colorType: pngColorTypeGrayscale,
        rows: <List<int>>[
          <int>[0, 42],
        ],
      );
      png[png.length - 1] ^= 0xff;

      expect(() => decodePng(png), throwsFormatException);
    });
  });

  group('processPNG', () {
    test('processa PNG RGBA com SMask', () {
      final png = _buildPng(
        width: 2,
        height: 1,
        depth: 8,
        colorType: pngColorTypeTruecolorAlpha,
        rows: <List<int>>[
          <int>[0, 10, 20, 30, 255, 40, 50, 60, 128],
        ],
      );

      final result = processPNG(png, alias: 'rgba');

      expect(result.alias, equals('rgba'));
      expect(result.width, equals(2));
      expect(result.height, equals(1));
      expect(result.colorSpace, equals(ColorSpaces.deviceRGB));
      expect(result.needSMask, isTrue);
      expect(result.colorBytes, equals(<int>[10, 20, 30, 40, 50, 60]));
      expect(result.alphaBytes, equals(<int>[255, 128]));
      expect(result.sMask, equals(<int>[255, 128]));
    });

    test('processa PNG indexado com máscara simples', () {
      final png = _buildPng(
        width: 2,
        height: 1,
        depth: 8,
        colorType: pngColorTypeIndexed,
        palette: <int>[255, 0, 0, 0, 0, 255],
        transparency: <int>[255, 0],
        rows: <List<int>>[
          <int>[0, 0, 1],
        ],
      );

      final result = processPNG(png);

      expect(result.colorSpace, equals(ColorSpaces.indexed));
      expect(result.palette, equals(<int>[255, 0, 0, 0, 0, 255]));
      expect(result.mask, equals(<int>[1]));
      expect(result.needSMask, isFalse);
    });

    test('compacta dados com FlateDecode e predictor', () {
      final png = _buildPng(
        width: 2,
        height: 1,
        depth: 8,
        colorType: pngColorTypeTruecolor,
        rows: <List<int>>[
          <int>[0, 10, 20, 30, 15, 25, 35],
        ],
      );

      final result =
          processPNG(png, index: 7, compression: PngCompression.fast);
      final inflated = ZLibCodec().decode(result.data);

      expect(result.index, equals(7));
      expect(result.filter, equals(DecodeMethod.flateDecode));
      expect(result.predictor, equals(11));
      expect(result.decodeParameters,
          equals('/Predictor 11 /Colors 3 /BitsPerComponent 8 /Columns 2'));
      expect(inflated, equals(<int>[1, 10, 20, 30, 5, 5, 5]));
    });
  });
}

Uint8List _buildPng({
  required int width,
  required int height,
  required int depth,
  required int colorType,
  required List<List<int>> rows,
  List<int>? palette,
  List<int>? transparency,
}) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  builder.add(pngSignature);
  builder.add(_chunk('IHDR', <int>[
    ..._uint32(width),
    ..._uint32(height),
    depth,
    colorType,
    0,
    0,
    0,
  ]));
  if (palette != null) {
    builder.add(_chunk('PLTE', palette));
  }
  if (transparency != null) {
    builder.add(_chunk('tRNS', transparency));
  }
  final List<int> raw =
      rows.expand((List<int> row) => row).toList(growable: false);
  builder.add(_chunk('IDAT', ZLibCodec().encode(raw)));
  builder.add(_chunk('IEND', const <int>[]));
  return builder.takeBytes();
}

List<int> _chunk(String type, List<int> data) {
  final List<int> typeBytes = type.codeUnits;
  return <int>[
    ..._uint32(data.length),
    ...typeBytes,
    ...data,
    ..._uint32(_crc32(typeBytes, data)),
  ];
}

List<int> _uint32(int value) => <int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

int _crc32(List<int> type, List<int> data) {
  int crc = 0xffffffff;
  for (final int byte in type) {
    crc = _crc32Byte(crc, byte);
  }
  for (final int byte in data) {
    crc = _crc32Byte(crc, byte);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

int _crc32Byte(int crc, int byte) {
  int value = (crc ^ byte) & 0xff;
  for (int k = 0; k < 8; k++) {
    if ((value & 1) != 0) {
      value = 0xedb88320 ^ (value >> 1);
    } else {
      value >>= 1;
    }
  }
  return (crc >> 8) ^ value;
}
