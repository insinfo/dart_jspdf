import 'package:jspdf/src/modules/html.dart';
import 'package:test/test.dart';

void main() {
  group('parseHtmlTextLines', () {
    test('extrai títulos, parágrafos e entidades', () {
      final lines = parseHtmlTextLines(
        '<h1>Título &amp; PDF</h1><p>Olá&nbsp;<strong>mundo</strong>.</p>',
        baseFontSize: 10,
      );

      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Título & PDF'));
      expect(lines[0].fontSize, equals(20));
      expect(lines[1].text, equals('Olá mundo.'));
      expect(lines[1].fontSize, equals(10));
    });

    test('remove scripts/styles e renderiza listas', () {
      final lines = parseHtmlTextLines(
        '<style>p{color:red}</style><script>alert(1)</script><ol><li>Um</li><li>Dois</li></ol><ul><li>Azul</li></ul>',
      );

      expect(lines.map((line) => line.text),
          equals(<String>['1. Um', '2. Dois', '- Azul']));
      expect(lines.every((line) => line.indent == 12), isTrue);
    });
  });

  group('wrapHtmlTextLine', () {
    test('quebra texto usando largura estimada', () {
      final wrapped = wrapHtmlTextLine(
        const HtmlTextLine(text: 'alpha beta gamma delta', fontSize: 10),
        55,
      );

      expect(wrapped.map((line) => line.text),
          equals(<String>['alpha beta', 'gamma delta']));
    });
  });

  group('HtmlWorker', () {
    test('renderiza linhas no PDF e pagina', () {
      final pdf = _FakePdf(pageWidth: 100);
      final worker = HtmlWorker(pdf: pdf).set(
        const HtmlToPdfOptions(
          margin: <double>[10, 10, 10, 10],
          fontSize: 10,
          lineHeightFactor: 1,
        ),
      );

      worker
          .from(
              '<h1>Doc</h1><p>Primeiro parágrafo</p><p>Segundo parágrafo longo</p>')
          .toPdf();

      expect(pdf.fontSizes.first, equals(20));
      expect(pdf.textCalls.first.text, equals('Doc'));
      expect(pdf.textCalls.map((call) => call.text),
          containsAll(<String>['Primeiro', 'parágrafo']));
      expect(pdf.addedPages, greaterThanOrEqualTo(1));
    });

    test('html helper executa fluxo completo', () {
      final pdf = _FakePdf(pageHeight: 200);

      final result = html(pdf, '<p>Hello</p>');

      expect(identical(result, pdf), isTrue);
      expect(pdf.textCalls.single.text, equals('Hello'));
    });
  });
}

class _FakePdf {
  final double pageHeight;
  final double pageWidth;
  final List<_TextCall> textCalls = <_TextCall>[];
  final List<double> fontSizes = <double>[];
  int addedPages = 0;

  _FakePdf({this.pageHeight = 45, this.pageWidth = 100});

  double getPageWidth() => pageWidth;

  double getPageHeight() => pageHeight;

  _FakePdf addPage() {
    addedPages++;
    return this;
  }

  _FakePdf setFontSize(double size) {
    fontSizes.add(size);
    return this;
  }

  _FakePdf text(String text, double x, double y) {
    textCalls.add(_TextCall(text, x, y));
    return this;
  }

  void save(String filename) {}
}

class _TextCall {
  final String text;
  final double x;
  final double y;

  const _TextCall(this.text, this.x, this.y);
}
