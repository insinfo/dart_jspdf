import 'package:test/test.dart';
import 'package:jspdf/jspdf.dart';

void main() {
  group('PdfOutline', () {
    late PdfOutline outline;

    setUp(() {
      outline = PdfOutline();
    });

    test('raiz começa vazia', () {
      expect(outline.root.children, isEmpty);
    });

    test('add item à raiz', () {
      outline.add(null, 'Chapter 1');
      expect(outline.root.children.length, equals(1));
      expect(outline.root.children.first.title, equals('Chapter 1'));
    });

    test('add sub-items', () {
      final ch1 = outline.add(null, 'Chapter 1');
      outline.add(ch1, 'Section 1.1');
      outline.add(ch1, 'Section 1.2');

      expect(ch1.children.length, equals(2));
      expect(ch1.children.first.title, equals('Section 1.1'));
    });

    test('add item com pageNumber', () {
      outline.add(null, 'Page 1', options: {'pageNumber': 1});
      expect(
        outline.root.children.first.options!['pageNumber'],
        equals(1),
      );
    });

    test('render gera string PDF', () {
      outline.add(null, 'Chapter 1', options: {'pageNumber': 1});
      outline.add(null, 'Chapter 2', options: {'pageNumber': 2});

      var nextId = 100;
      final rendered = outline.render(
        objectIdAssigner: () => nextId++,
        pageObjIdLookup: (page) => page * 2 + 3,
        pageHeight: 841.89,
      );

      expect(rendered, contains('/Type /Outlines'));
      expect(rendered, contains('Chapter 1'));
      expect(rendered, contains('Chapter 2'));
      expect(rendered, contains('/Dest'));
      expect(rendered, contains('0 R'));
    });

    test('render com hierarquia', () {
      final ch1 = outline.add(null, 'Chapter 1');
      outline.add(ch1, 'Section 1.1');

      var nextId = 10;
      final rendered = outline.render(
        objectIdAssigner: () => nextId++,
        pageObjIdLookup: (page) => page * 2,
        pageHeight: 800,
      );

      expect(rendered, contains('/First'));
      expect(rendered, contains('/Last'));
      expect(rendered, contains('/Parent'));
      expect(rendered, contains('/Count'));
    });
  });

  group('ViewerPreferences', () {
    late ViewerPreferences prefs;

    setUp(() {
      prefs = ViewerPreferences();
    });

    test('sem preferências definidas, retorna null', () {
      expect(prefs.toPdfDict(), isNull);
    });

    test('define FitWindow', () {
      prefs.set({'FitWindow': true});
      expect(prefs.isSet('FitWindow'), isTrue);
      expect(prefs.getValue('FitWindow'), isTrue);

      final dict = prefs.toPdfDict();
      expect(dict, isNotNull);
      expect(dict!, contains('/FitWindow true'));
      expect(dict, contains('/ViewerPreferences'));
    });

    test('define HideToolbar', () {
      prefs.set({'HideToolbar': true});
      final dict = prefs.toPdfDict()!;
      expect(dict, contains('/HideToolbar true'));
    });

    test('define Direction', () {
      prefs.set({'Direction': 'R2L'});
      final dict = prefs.toPdfDict()!;
      expect(dict, contains('/Direction /R2L'));
    });

    test('define PrintScaling', () {
      prefs.set({'PrintScaling': 'None'});
      final dict = prefs.toPdfDict()!;
      expect(dict, contains('/PrintScaling /None'));
    });

    test('define NumCopies', () {
      prefs.set({'NumCopies': 5});
      final dict = prefs.toPdfDict()!;
      expect(dict, contains('/NumCopies 5'));
    });

    test('ignora valor inválido para name', () {
      prefs.set({'Direction': 'InvalidValue'});
      expect(prefs.isSet('Direction'), isFalse);
    });

    test('ignora tipo errado', () {
      prefs.set({'FitWindow': 'invalid'}); // Deve ser bool
      expect(prefs.isSet('FitWindow'), isFalse);
    });

    test('ignora chave desconhecida', () {
      prefs.set({'UnknownKey': true});
      expect(prefs.toPdfDict(), isNull);
    });

    test('reset volta aos valores padrão', () {
      prefs.set({'FitWindow': true, 'HideToolbar': true});
      expect(prefs.toPdfDict(), isNotNull);

      prefs.reset();
      expect(prefs.toPdfDict(), isNull);
      expect(prefs.isSet('FitWindow'), isFalse);
    });

    test('múltiplas preferências', () {
      prefs.set({
        'HideToolbar': true,
        'HideMenubar': true,
        'FitWindow': true,
        'CenterWindow': true,
      });
      final dict = prefs.toPdfDict()!;
      expect(dict, contains('/HideToolbar'));
      expect(dict, contains('/HideMenubar'));
      expect(dict, contains('/FitWindow'));
      expect(dict, contains('/CenterWindow'));
    });

    test('define PrintPageRange como array', () {
      prefs.set({
        'PrintPageRange': [
          [1, 5],
          [7, 9]
        ]
      });
      final dict = prefs.toPdfDict()!;
      expect(dict, contains('/PrintPageRange'));
      expect(dict, contains('[0 4 6 8]'));
    });
  });

  group('setLanguage', () {
    test('valida códigos portados da referência', () {
      expect(isValidPdfLanguageCode('en-US'), isTrue);
      expect(isValidPdfLanguageCode('pt-BR'), isTrue);
      expect(isValidPdfLanguageCode('zz-ZZ'), isFalse);
    });

    test('emite Lang no catálogo para código válido', () {
      final pdf = JsPdf()
        ..setLanguage('pt-BR')
        ..text('Olá', 10, 10);

      expect(pdf.output(), contains('/Lang (pt-BR)'));
    });

    test('ignora código inválido como no plugin JS', () {
      final pdf = JsPdf()
        ..setLanguage('zz-ZZ')
        ..text('Hello', 10, 10);

      expect(pdf.output(), isNot(contains('/Lang')));
    });
  });

  group('cellToPdf', () {
    test('gera operadores para célula com borda', () {
      final ops = cellToPdf(
        x: 10,
        y: 100,
        width: 80,
        height: 20,
        text: 'Hello',
        drawBorder: true,
      );
      expect(ops.any((s) => s.contains('re S')), isTrue); // Retângulo de borda
      expect(ops.any((s) => s.contains('BT')), isTrue); // Begin Text
      expect(ops.any((s) => s.contains('Hello')), isTrue);
      expect(ops.any((s) => s.contains('ET')), isTrue); // End Text
    });

    test('gera operadores sem borda', () {
      final ops = cellToPdf(
        x: 10,
        y: 100,
        width: 80,
        height: 20,
        text: 'No border',
        drawBorder: false,
      );
      expect(ops.any((s) => s.contains('re S')), isFalse);
      expect(ops.any((s) => s.contains('BT')), isTrue);
    });

    test('texto alinhado ao centro', () {
      final ops = cellToPdf(
        x: 10,
        y: 100,
        width: 200,
        height: 20,
        text: 'Hi',
        align: CellAlign.center,
      );
      expect(ops.any((s) => s.contains('BT')), isTrue);
    });

    test('texto alinhado à direita', () {
      final ops = cellToPdf(
        x: 10,
        y: 100,
        width: 200,
        height: 20,
        text: 'Hi',
        align: CellAlign.right,
      );
      expect(ops.any((s) => s.contains('BT')), isTrue);
    });
  });

  group('calculateLineHeight', () {
    test('texto curto = 1 linha', () {
      final h = calculateLineHeight('Hi', 200, 12);
      expect(h, closeTo(18, 1)); // 1 line × 12 × 1.5
    });

    test('texto longo produz múltiplas linhas', () {
      final longText = 'A' * 200;
      final h = calculateLineHeight(longText, 100, 12);
      expect(h, greaterThan(18)); // Mais de 1 linha
    });
  });

  group('calculateRowHeight', () {
    test('usa a altura da maior célula', () {
      final cols = [
        TableColumn(name: 'a', prompt: 'A', width: 50),
        TableColumn(name: 'b', prompt: 'B', width: 50),
      ];
      final row = {'a': 'Short', 'b': 'A' * 100}; // b é muito mais longo
      final height = calculateRowHeight(cols, row, 10);
      final shortHeight = calculateLineHeight(
        'Short',
        50 - 6,
        10,
      );
      expect(height, greaterThanOrEqualTo(shortHeight));
    });
  });

  group('TableColumn', () {
    test('construtor com valores padrão', () {
      const col = TableColumn(name: 'id', prompt: 'ID', width: 40);
      expect(col.name, equals('id'));
      expect(col.prompt, equals('ID'));
      expect(col.width, equals(40));
      expect(col.align, equals(CellAlign.left));
      expect(col.padding, equals(3));
    });
  });
}
