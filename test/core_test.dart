import 'package:test/test.dart';
import 'package:jspdf/src/page_formats.dart';
import 'package:jspdf/src/fonts.dart';
import 'package:jspdf/src/gstate.dart';
import 'package:jspdf/src/pattern.dart';
import 'package:jspdf/src/pdf_document.dart';

void main() {
  group('PageFormats', () {
    test('a4 tem dimensões corretas', () {
      final a4 = getPageFormat('a4');
      expect(a4, isNotNull);
      expect(a4![0], closeTo(595.28, 0.01));
      expect(a4[1], closeTo(841.89, 0.01));
    });

    test('letter tem dimensões corretas', () {
      final letter = getPageFormat('letter');
      expect(letter, isNotNull);
      expect(letter![0], equals(612));
      expect(letter[1], equals(792));
    });

    test('formato desconhecido retorna null', () {
      expect(getPageFormat('invalid'), isNull);
    });

    test('case insensitive', () {
      expect(getPageFormat('A4'), isNotNull);
      expect(getPageFormat('LETTER'), isNotNull);
    });

    test('todos os formatos existem', () {
      final expectedFormats = [
        'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10',
        'b0', 'b1', 'b2', 'b3', 'b4', 'b5',
        'c0', 'c1', 'c2', 'c3', 'c4', 'c5',
        'letter', 'legal', 'tabloid', 'ledger',
      ];
      for (final fmt in expectedFormats) {
        expect(getPageFormat(fmt), isNotNull, reason: '$fmt should exist');
      }
    });
  });

  group('ScaleFactor', () {
    test('pt = 1', () => expect(getScaleFactor('pt'), equals(1)));
    test('mm', () => expect(getScaleFactor('mm'), closeTo(2.8346, 0.01)));
    test('cm', () => expect(getScaleFactor('cm'), closeTo(28.346, 0.01)));
    test('in', () => expect(getScaleFactor('in'), equals(72)));
    test('unidade inválida lança erro', () {
      expect(() => getScaleFactor('invalid'), throwsA(isA<ArgumentError>()));
    });
  });

  group('StandardFonts', () {
    test('existem 14 fontes padrão', () {
      expect(standardFonts.length, equals(14));
    });

    test('Helvetica existe', () {
      final helvetica = standardFonts.where(
        (f) => f.fontName == 'helvetica' && f.fontStyle == 'normal',
      );
      expect(helvetica, isNotEmpty);
      expect(helvetica.first.postScriptName, equals('Helvetica'));
    });

    test('todas as fontes têm campos obrigatórios', () {
      for (final font in standardFonts) {
        expect(font.postScriptName, isNotEmpty);
        expect(font.fontName, isNotEmpty);
        expect(font.fontStyle, isNotEmpty);
      }
    });
  });

  group('combineFontStyleAndFontWeight', () {
    test('normal + 400 = normal', () {
      expect(combineFontStyleAndFontWeight('normal', 400), equals('normal'));
    });

    test('normal + 700 = bold', () {
      expect(combineFontStyleAndFontWeight('normal', 700), equals('bold'));
    });

    test('italic + 400 = italic', () {
      expect(combineFontStyleAndFontWeight('italic', 400), equals('italic'));
    });

    test('combinação inválida lança erro', () {
      expect(
        () => combineFontStyleAndFontWeight('bold', 'normal'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GState', () {
    test('construtor padrão', () {
      final gs = GState();
      expect(gs.opacity, isNull);
      expect(gs.strokeOpacity, isNull);
      expect(gs.id, equals(''));
      expect(gs.objectNumber, equals(-1));
    });

    test('fromMap', () {
      final gs = GState.fromMap({
        'opacity': 0.5,
        'stroke-opacity': 0.8,
      });
      expect(gs.opacity, equals(0.5));
      expect(gs.strokeOpacity, equals(0.8));
    });

    test('equals', () {
      final gs1 = GState(opacity: 0.5, strokeOpacity: 0.8);
      final gs2 = GState(opacity: 0.5, strokeOpacity: 0.8);
      final gs3 = GState(opacity: 0.3, strokeOpacity: 0.8);

      expect(gs1.equals(gs2), isTrue);
      expect(gs1.equals(gs3), isFalse);
      expect(gs1.equals(null), isFalse);
    });
  });

  group('Pattern', () {
    test('ShadingPattern axial', () {
      final sp = ShadingPattern(
        gradientType: 'axial',
        coords: [0, 0, 100, 100],
        colors: [
          {'offset': 0.0, 'color': [255, 0, 0]},
          {'offset': 1.0, 'color': [0, 0, 255]},
        ],
      );
      expect(sp.type, equals(2));
    });

    test('ShadingPattern radial', () {
      final sp = ShadingPattern(
        gradientType: 'radial',
        coords: [50, 50, 0, 50, 50, 100],
        colors: [],
      );
      expect(sp.type, equals(3));
    });

    test('TilingPattern', () {
      final tp = TilingPattern(
        boundingBox: [0, 0, 100, 100],
        xStep: 50,
        yStep: 50,
      );
      expect(tp.xStep, equals(50));
      expect(tp.yStep, equals(50));
      expect(tp.stream, isEmpty);
    });
  });

  group('PdfDocumentBuilder', () {
    test('cria builder com versão padrão', () {
      final builder = PdfDocumentBuilder();
      expect(builder.numberOfPages, equals(0));
    });

    test('addPage incrementa contagem', () {
      final builder = PdfDocumentBuilder();
      builder.addPage(MediaBox.fromDimensions(595.28, 841.89));
      expect(builder.numberOfPages, equals(1));
      expect(builder.currentPage, equals(1));

      builder.addPage(MediaBox.fromDimensions(595.28, 841.89));
      expect(builder.numberOfPages, equals(2));
    });

    test('newObject incrementa objectNumber', () {
      final builder = PdfDocumentBuilder();
      // Os primeiros 2 objetos são reservados (root + resource dict)
      final initialObj = builder.objectNumber;
      builder.newObject();
      expect(builder.objectNumber, greaterThan(initialObj));
    });

    test('out adiciona conteúdo', () {
      final builder = PdfDocumentBuilder();
      builder.addPage(MediaBox.fromDimensions(100, 100));
      builder.out('test content');
      expect(builder.pages[1], contains('test content'));
    });

    test('MediaBox clone', () {
      final box = MediaBox(0, 0, 100, 200);
      final cloned = box.clone();
      expect(cloned.bottomLeftX, equals(0));
      expect(cloned.topRightX, equals(100));
      expect(cloned.topRightY, equals(200));

      cloned.topRightX = 500;
      expect(box.topRightX, equals(100)); // Original não foi modificado
    });

    test('buildDocument gera PDF válido', () {
      final builder = PdfDocumentBuilder();
      builder.addPage(MediaBox.fromDimensions(595.28, 841.89));
      builder.out('BT /F1 12 Tf 100 700 Td (Hello) Tj ET');

      final pdfString = builder.buildDocument(
        fileId: 'AABBCCDD11223344AABBCCDD11223344',
        creationDate: 'D:20240101120000+00\'00\'',
        putResourcesCallback: () {
          builder.newObjectDeferredBegin(
            builder.resourceDictionaryObjId,
            doOutput: true,
          );
          builder.out('<<');
          builder.out('/ProcSet [/PDF /Text]');
          builder.out('/Font << /F1 << /Type /Font /BaseFont /Helvetica /Subtype /Type1 >> >>');
          builder.out('>>');
          builder.out('endobj');
        },
      );

      expect(pdfString, startsWith('%PDF-1.3'));
      expect(pdfString, contains('%%EOF'));
      expect(pdfString, contains('/Type /Page'));
      expect(pdfString, contains('/Type /Pages'));
      expect(pdfString, contains('/Type /Catalog'));
      expect(pdfString, contains('Hello'));
      expect(pdfString, contains('xref'));
      expect(pdfString, contains('trailer'));
    });
  });
}
