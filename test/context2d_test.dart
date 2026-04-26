import 'dart:convert';
import 'dart:typed_data';

import 'package:jspdf/jspdf.dart';
import 'package:test/test.dart';

void main() {
  group('Context2D', () {
    test('emite operadores PDF para fillRect', () {
      final pdf = _FakePdf();
      Context2D(pdf)
        ..fillStyle = '#ff0000'
        ..fillRect(10, 20, 30, 40);

      final raw = pdf.raw.join('\n');
      expect(raw, contains('1 0 0 rg'));
      expect(raw, contains('10 180 m'));
      expect(raw, contains('40 180 l'));
      expect(raw, contains('f'));
    });

    test('emite stroke com line dash e largura', () {
      final pdf = _FakePdf();
      final ctx = Context2D(pdf)
        ..strokeStyle = 'rgb(0, 0, 255)'
        ..lineWidth = 2
        ..setLineDash(<double>[4, 2]);

      ctx.beginPath();
      ctx.moveTo(5, 5);
      ctx.lineTo(15, 15);
      ctx.stroke();

      final raw = pdf.raw.join('\n');
      expect(raw, contains('2 w'));
      expect(raw, contains('[4 2] 0 d'));
      expect(raw, contains('0 0 1 RG'));
      expect(raw, contains('5 195 m'));
      expect(raw, contains('15 185 l'));
      expect(raw, contains('S'));
    });

    test('fillText delega para API de texto do PDF', () {
      final pdf = _FakePdf();
      final ctx = Context2D(pdf)
        ..font = '16px Helvetica'
        ..fillStyle = '#00ff00';

      ctx.fillText('Hello', 12, 34, 100);

      expect(pdf.textColor, equals(<int>[0, 255, 0]));
      expect(pdf.fontSize, closeTo(12, 0.001));
      expect(pdf.textCalls.single.text, equals('Hello'));
      expect(pdf.textCalls.single.x, equals(12));
      expect(pdf.textCalls.single.y, equals(34));
      expect(pdf.textCalls.single.maxWidth, equals(100));
    });

    test('parser de ctx.font seleciona família, peso e estilo', () {
      final pdf = _FakePdf();
      final ctx = Context2D(pdf)
        ..font = 'italic 700 20px "Open Sans", sans-serif';

      ctx.fillText('Bold italic', 10, 20);

      expect(pdf.font, equals('open sans'));
      expect(pdf.fontStyle, equals('bolditalic'));
      expect(pdf.fontSize, closeTo(15, 0.001));
    });

    test('measureText retorna ascent/descent além de largura', () {
      final pdf = _FakePdf();
      final ctx = Context2D(pdf)..font = '16px Helvetica';

      final metrics = ctx.measureText('Hello');

      expect(metrics.width, closeTo(20, 0.001));
      expect(metrics.actualBoundingBoxAscent, closeTo(9, 0.001));
      expect(metrics.actualBoundingBoxDescent, closeTo(3, 0.001));
    });

    test('JsPdf expõe context2d persistente', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[200, 100]));

      expect(identical(pdf.context2d, pdf.context2D), isTrue);

      pdf.context2d
        ..font = '12px helvetica'
        ..fillText('ctx', 10, 20);

      final output = pdf.output() as String;
      expect(output, contains('(ctx) Tj'));
    });

    test('globalAlpha emite ExtGState no PDF final', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[100, 100]));

      pdf.context2d
        ..globalAlpha = 0.5
        ..fillStyle = '#ff0000'
        ..fillRect(10, 10, 20, 20);

      final output = pdf.output() as String;
      expect(output, contains('/ExtGState'));
      expect(output, contains('/ca 0.5'));
      expect(output, contains('/GS1 gs'));
    });

    test('drawImage delega para addImage e desenha XObject', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[120, 80]));

      pdf.context2d.drawImage(_minimalJpeg(), 10, 15, 30, 20);

      final output = pdf.output() as String;
      expect(output, contains('/Subtype /Image'));
      expect(output, contains('/Filter /DCTDecode'));
      expect(output, contains('/I1 Do'));
    });

    test('drawImage com 9 argumentos aplica clipping de crop', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[120, 80]));

      pdf.context2d.drawImage(_minimalJpeg(), 20, 10, 50, 40, 5, 6, 25, 20);

      final output = pdf.output() as String;
      expect(output, contains('re W n'));
      expect(output, contains('/I1 Do'));
    });
  });

  group('editor compatibility APIs', () {
    test('addPage aceita formato customizado em lista', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[320, 480]));

      pdf.addPage(<double>[640, 360], 'l');

      expect(pdf.getNumberOfPages(), equals(2));
      expect(pdf.getPageWidth(2), equals(640));
      expect(pdf.getPageHeight(2), equals(360));
    });

    test('textWithLink grava anotação de URL na página', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[300, 200]));

      pdf.textWithLink(
          'site', 20, 40, const LinkOptions(url: 'https://example.com'));

      final output = pdf.output() as String;
      expect(output, contains('/Annots ['));
      expect(output, contains('/Subtype /Link'));
      expect(output, contains('/URI (https://example.com)'));
      expect(output, contains('(site) Tj'));
    });

    test('setGState grava ExtGState e mantém estado ativo', () {
      final pdf = JsPdf()
        ..setGState(GState(opacity: 0.25, strokeOpacity: 0.75));

      expect(pdf.activeGState?.opacity, equals(0.25));
      expect(pdf.activeGState?.strokeOpacity, equals(0.75));

      final output = pdf.output() as String;
      expect(output, contains('/Type /ExtGState'));
      expect(output, contains('/ca 0.25'));
      expect(output, contains('/CA 0.75'));
      expect(output, contains('/GS1 gs'));
    });

    test('addImage aceita data URL base64 JPEG', () {
      final pdf =
          JsPdf(const JsPdfOptions(unit: 'px', format: <double>[120, 80]));
      final dataUrl = 'data:image/jpeg;base64,${base64.encode(_minimalJpeg())}';

      pdf.addImage(dataUrl, 'JPEG', 5, 6, 7, 8, 'logo');

      final output = pdf.output() as String;
      expect(output, contains('/XObject <<'));
      expect(output, contains('/I1 '));
      expect(output, contains('/Width 200'));
      expect(output, contains('/Height 100'));
      expect(output, contains('/I1 Do'));
    });

    test('compress true aplica FlateDecode no stream da página', () {
      final pdf = JsPdf(const JsPdfOptions(compress: true))
        ..text('compressed text', 10, 10);

      final output = pdf.output() as String;
      expect(output, contains('/Filter /FlateDecode'));
      expect(output, isNot(contains('(compressed text) Tj')));
    });
  });
}

Uint8List _minimalJpeg() {
  return Uint8List.fromList(<int>[
    0xFF,
    0xD8,
    0xFF,
    0xE0,
    0x00,
    0x02,
    0xFF,
    0xC0,
    0x00,
    0x0B,
    0x08,
    0x00,
    0x64,
    0x00,
    0xC8,
    0x03,
  ]);
}

class _FakePdf {
  final List<String> raw = <String>[];
  final List<_TextCall> textCalls = <_TextCall>[];
  List<int> textColor = <int>[0, 0, 0];
  double fontSize = 0;
  String font = '';
  String fontStyle = '';

  double getPageHeight() => 200;

  _FakePdf addRawContent(String content) {
    raw.add(content);
    return this;
  }

  _FakePdf setTextColor(dynamic r, [dynamic g, dynamic b]) {
    textColor = <int>[
      (r as num).round(),
      (g as num).round(),
      (b as num).round()
    ];
    return this;
  }

  _FakePdf setFontSize(double size) {
    fontSize = size;
    return this;
  }

  _FakePdf setFont(String fontName, {String fontStyle = 'normal'}) {
    font = fontName;
    this.fontStyle = fontStyle;
    return this;
  }

  Map<String, double> measureTextMetrics(
    String text,
    String fontName,
    String fontStyle,
    double fontSize,
  ) {
    return <String, double>{
      'width': text.length * fontSize / 3,
      'actualBoundingBoxAscent': fontSize * 0.75,
      'actualBoundingBoxDescent': fontSize * 0.25,
      'fontBoundingBoxAscent': fontSize * 0.75,
      'fontBoundingBoxDescent': fontSize * 0.25,
    };
  }

  _FakePdf text(
    String text,
    double x,
    double y, {
    double? maxWidth,
    String? align,
    double? angle,
    double? lineHeightFactor,
  }) {
    textCalls.add(_TextCall(text, x, y, maxWidth, align));
    return this;
  }
}

class _TextCall {
  final String text;
  final double x;
  final double y;
  final double? maxWidth;
  final String? align;

  const _TextCall(this.text, this.x, this.y, this.maxWidth, this.align);
}
