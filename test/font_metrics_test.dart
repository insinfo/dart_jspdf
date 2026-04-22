import 'package:test/test.dart';
import 'package:jspdf/src/modules/standard_fonts_metrics.dart';

void main() {
  group('uncompress', () {
    test('descomprime Courier (monoespacada)', () {
      final result = uncompress("{'widths'{k3w'fof'6o}'kerning'{'fof'-6o}}");
      expect(result, isA<Map>());
      expect(result.containsKey('widths'), isTrue);
      expect(result.containsKey('kerning'), isTrue);
    });

    test('descomprime formato com chaves numéricas', () {
      final result = uncompress("{1k2l3m}");
      expect(result, isA<Map>());
      expect(result.length, greaterThan(0));
    });

    test('lança erro para string vazia', () {
      expect(() => uncompress(''), throwsA(isA<ArgumentError>()));
    });

    test('descomprime Helvetica widths', () {
      final metrics = fontMetrics['Helvetica'];
      expect(metrics, isNotNull);
      final widths = metrics!['widths'];
      expect(widths, isA<Map>());
      expect((widths as Map).isNotEmpty, isTrue);
    });

    test('descomprime Helvetica kerning', () {
      final metrics = fontMetrics['Helvetica'];
      expect(metrics, isNotNull);
      final kerning = metrics!['kerning'];
      expect(kerning, isA<Map>());
    });
  });

  group('compress / uncompress roundtrip', () {
    test('roundtrip preserva dados numéricos', () {
      final original = <dynamic, dynamic>{1: 500, 2: 600, 3: 700};
      final compressed = compress(original);
      expect(compressed, isNotEmpty);
      final restored = uncompress(compressed);
      expect(restored[1], equals(500));
      expect(restored[2], equals(600));
      expect(restored[3], equals(700));
    });

    test('roundtrip com valores negativos', () {
      final original = <dynamic, dynamic>{1: -100, 2: 200};
      final compressed = compress(original);
      final restored = uncompress(compressed);
      expect(restored[1], equals(-100));
      expect(restored[2], equals(200));
    });
  });

  group('fontMetrics', () {
    test('contém todas as 14 fontes PDF padrão', () {
      final expectedFonts = [
        'Courier', 'Courier-Bold', 'Courier-BoldOblique', 'Courier-Oblique',
        'Helvetica', 'Helvetica-Bold', 'Helvetica-Oblique', 'Helvetica-BoldOblique',
        'Times-Roman', 'Times-Bold', 'Times-Italic', 'Times-BoldItalic',
        'Symbol', 'ZapfDingbats',
      ];
      for (final font in expectedFonts) {
        expect(fontMetrics.containsKey(font), isTrue, reason: '$font missing');
      }
    });

    test('cada fonte tem widths e kerning', () {
      for (final entry in fontMetrics.entries) {
        expect(entry.value.containsKey('widths'), isTrue,
            reason: '${entry.key} missing widths');
        expect(entry.value.containsKey('kerning'), isTrue,
            reason: '${entry.key} missing kerning');
      }
    });

    test('Courier é monoespacada (uma largura para todos)', () {
      final widths = fontMetrics['Courier']!['widths'] as Map;
      // Courier tem apenas 1-2 entradas (default width + fof)
      expect(widths.length, lessThanOrEqualTo(3));
    });

    test('Helvetica tem múltiplas larguras', () {
      final widths = fontMetrics['Helvetica']!['widths'] as Map;
      expect(widths.length, greaterThan(50));
    });
  });

  group('getFontWidths', () {
    test('retorna widths para Helvetica', () {
      final widths = getFontWidths('Helvetica');
      expect(widths, isNotNull);
      expect(widths!.isNotEmpty, isTrue);
    });

    test('retorna null para fonte inexistente', () {
      expect(getFontWidths('FakeFont'), isNull);
    });
  });

  group('getFontKerning', () {
    test('retorna kerning para Times-Roman', () {
      final kerning = getFontKerning('Times-Roman');
      expect(kerning, isNotNull);
      expect(kerning!.isNotEmpty, isTrue);
    });

    test('retorna null para fonte inexistente', () {
      expect(getFontKerning('FakeFont'), isNull);
    });
  });

  group('getCharWidthForFont', () {
    test('retorna largura para caractere conhecido', () {
      final width = getCharWidthForFont(65, 'Helvetica'); // 'A'
      expect(width, greaterThan(0));
    });

    test('retorna fallback para fonte inexistente', () {
      final width = getCharWidthForFont(65, 'FakeFont');
      expect(width, equals(600)); // Default fallback
    });
  });

  group('getStringWidthForFont', () {
    test('calcula largura de string', () {
      final width = getStringWidthForFont('Hello', 'Helvetica');
      expect(width, greaterThan(0));
    });

    test('string vazia tem largura zero', () {
      expect(getStringWidthForFont('', 'Helvetica'), equals(0));
    });

    test('strings mais longas são mais largas', () {
      final short = getStringWidthForFont('Hi', 'Helvetica');
      final long = getStringWidthForFont('Hello World', 'Helvetica');
      expect(long, greaterThan(short));
    });
  });

  group('encodingBlock', () {
    test('é descomprimido corretamente', () {
      expect(encodingBlock, isA<Map>());
      expect(encodingBlock.isNotEmpty, isTrue);
    });
  });
}
