import 'package:test/test.dart';
import 'package:jspdf/src/color.dart';
import 'package:jspdf/src/rgb_color.dart';

void main() {
  group('RGBColor', () {
    test('parse hex #RRGGBB', () {
      final c = RGBColor('#ff0000');
      expect(c.ok, isTrue);
      expect(c.r, equals(255));
      expect(c.g, equals(0));
      expect(c.b, equals(0));
    });

    test('parse hex curto #RGB', () {
      final c = RGBColor('#f00');
      expect(c.ok, isTrue);
      expect(c.r, equals(255));
      expect(c.g, equals(0));
      expect(c.b, equals(0));
    });

    test('parse nome de cor CSS', () {
      final c = RGBColor('red');
      expect(c.ok, isTrue);
      expect(c.r, equals(255));
      expect(c.g, equals(0));
      expect(c.b, equals(0));
    });

    test('parse nome de cor CSS complexo', () {
      final c = RGBColor('cornflowerblue');
      expect(c.ok, isTrue);
      expect(c.r, equals(100));
      expect(c.g, equals(149));
      expect(c.b, equals(237));
    });

    test('parse rgb(r, g, b)', () {
      final c = RGBColor('rgb(100, 200, 50)');
      expect(c.ok, isTrue);
      expect(c.r, equals(100));
      expect(c.g, equals(200));
      expect(c.b, equals(50));
    });

    test('parse rgba(r, g, b, a)', () {
      final c = RGBColor('rgba(100, 200, 50, 0.5)');
      expect(c.ok, isTrue);
      expect(c.r, equals(100));
      expect(c.a, closeTo(0.5, 0.01));
    });

    test('toHex', () {
      final c = RGBColor('red');
      expect(c.toHex(), equals('#ff0000'));
    });

    test('toRGB', () {
      final c = RGBColor('#0066ff');
      expect(c.toRGB(), equals('rgb(0, 102, 255)'));
    });

    test('cor inválida ok = false', () {
      final c = RGBColor('notacolor_xyz');
      expect(c.ok, isFalse);
    });

    test('branco', () {
      final c = RGBColor('white');
      expect(c.ok, isTrue);
      expect(c.r, equals(255));
      expect(c.g, equals(255));
      expect(c.b, equals(255));
    });

    test('preto', () {
      final c = RGBColor('black');
      expect(c.ok, isTrue);
      expect(c.r, equals(0));
      expect(c.g, equals(0));
      expect(c.b, equals(0));
    });
  });

  group('decodeColorString', () {
    test('decodifica grayscale', () {
      final hex = decodeColorString('0.5 g');
      expect(hex, startsWith('#'));
      expect(hex.length, equals(7));
    });

    test('decodifica RGB', () {
      final hex = decodeColorString('1 0 0 rg');
      expect(hex, equals('#ff0000'));
    });

    test('decodifica CMYK', () {
      final hex = decodeColorString('0 0 0 0 k'); // Pure white in CMYK
      expect(hex, equals('#ffffff'));
    });
  });

  group('encodeColorString', () {
    test('codifica grayscale', () {
      final color = encodeColorString(
        ColorOptions(ch1: 128, pdfColorType: 'fill'),
      );
      expect(color, contains('g'));
    });

    test('codifica RGB fill', () {
      final color = encodeColorString(
        ColorOptions(ch1: 255, ch2: 0, ch3: 0, pdfColorType: 'fill'),
      );
      expect(color, contains('rg'));
    });

    test('codifica RGB stroke', () {
      final color = encodeColorString(
        ColorOptions(ch1: 255, ch2: 0, ch3: 0, pdfColorType: 'draw'),
      );
      expect(color, contains('RG'));
    });

    test('codifica de hex string', () {
      final color = encodeColorString(
        ColorOptions(ch1: '#ff0000', pdfColorType: 'fill'),
      );
      expect(color, contains('rg'));
    });

    test('codifica de nome de cor CSS', () {
      final color = encodeColorString(
        ColorOptions(ch1: 'red', pdfColorType: 'fill'),
      );
      expect(color, contains('rg'));
    });

    test('codifica hex curto', () {
      final color = encodeColorString(
        ColorOptions(ch1: '#f00', pdfColorType: 'fill'),
      );
      expect(color, contains('rg'));
    });
  });
}
