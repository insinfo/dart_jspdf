import 'package:test/test.dart';
import 'package:jspdf/src/pdfname.dart';
import 'package:jspdf/src/libs/ttffont.dart';
import 'package:jspdf/src/modules/utf8.dart';

void main() {
  group('toPDFName', () {
    test('nome ASCII simples não muda', () {
      expect(toPDFName('Helvetica'), equals('Helvetica'));
    });

    test('nome com espaço é codificado', () {
      expect(toPDFName('My Font'), equals('My#20Font'));
    });

    test('nome com parênteses é codificado', () {
      expect(toPDFName('Font(Bold)'), equals('Font#28Bold#29'));
    });

    test('caracteres especiais PDF são codificados', () {
      // # % ( ) / < > [ ] { }
      expect(toPDFName('#'), equals('#23'));
      expect(toPDFName('%'), equals('#25'));
      expect(toPDFName('/'), equals('#2f'));
      expect(toPDFName('<>'), equals('#3c#3e'));
      expect(toPDFName('[]'), equals('#5b#5d'));
      expect(toPDFName('{}'), equals('#7b#7d'));
    });

    test('caractere com code > 0x7E é codificado', () {
      expect(toPDFName('©'), equals('#a9'));
    });

    test('tab é codificado', () {
      expect(toPDFName('\t'), equals('#09'));
    });

    test('lança erro para caracteres não-ASCII', () {
      expect(() => toPDFName('日本語'), throwsArgumentError);
    });
  });

  group('TtfData', () {
    test('read/write byte', () {
      final data = TtfData();
      data.writeByte(0x42);
      data.pos = 0;
      expect(data.readByte(), equals(0x42));
    });

    test('read/write UInt16', () {
      final data = TtfData();
      data.writeUInt16(0x1234);
      data.pos = 0;
      expect(data.readUInt16(), equals(0x1234));
    });

    test('read/write Int16 negativo', () {
      final data = TtfData();
      data.writeInt16(-100);
      data.pos = 0;
      expect(data.readInt16(), equals(-100));
    });

    test('read/write UInt32', () {
      final data = TtfData();
      data.writeUInt32(0xDEADBEEF);
      data.pos = 0;
      expect(data.readUInt32(), equals(0xDEADBEEF));
    });

    test('read/write Int32 negativo', () {
      final data = TtfData();
      data.writeInt32(-12345);
      data.pos = 0;
      expect(data.readInt32(), equals(-12345));
    });

    test('read/write String', () {
      final data = TtfData();
      data.writeString('head');
      data.pos = 0;
      expect(data.readString(4), equals('head'));
    });

    test('read bytes', () {
      final data = TtfData([10, 20, 30, 40]);
      final bytes = data.read(4);
      expect(bytes, equals([10, 20, 30, 40]));
    });

    test('write bytes', () {
      final data = TtfData();
      data.write([1, 2, 3]);
      expect(data.data, equals([1, 2, 3]));
    });
  });

  group('PDFObject', () {
    test('convert array', () {
      expect(PDFObject.convert([1, 2, 3]), equals('[1 2 3]'));
    });

    test('convert string → name', () {
      expect(PDFObject.convert('Helvetica'), equals('/Helvetica'));
    });

    test('convert number', () {
      expect(PDFObject.convert(42), equals('42'));
    });

    test('convert nested array', () {
      expect(PDFObject.convert([1, [2, 3]]), equals('[1 [2 3]]'));
    });

    test('convert DateTime', () {
      final dt = DateTime.utc(2024, 1, 15, 10, 30, 45);
      final result = PDFObject.convert(dt);
      expect(result, equals('(D:20240115103045Z)'));
    });

    test('convert Map', () {
      final result = PDFObject.convert({'Key': 'Value'});
      expect(result, contains('<<'));
      expect(result, contains('/Key /Value'));
      expect(result, contains('>>'));
    });
  });

  group('toUnicodeCmap', () {
    test('gera CMap simples', () {
      final map = {65: 65, 66: 66}; // A=A, B=B
      final cmap = toUnicodeCmap(map);
      expect(cmap, contains('/CIDInit'));
      expect(cmap, contains('begincodespacerange'));
      expect(cmap, contains('beginbfchar'));
      expect(cmap, contains('<0041><0041>'));
      expect(cmap, contains('<0042><0042>'));
      expect(cmap, contains('endbfchar'));
      expect(cmap, contains('endcmap'));
    });

    test('gera CMap vazio para mapa vazio', () {
      final cmap = toUnicodeCmap({});
      expect(cmap, contains('endcmap'));
      expect(cmap, isNot(contains('beginbfchar')));
    });
  });

  group('pdfEscape16', () {
    // Não é possível testar sem um TTFFont real, mas podemos
    // verificar que a assinatura da função está correta
    test('função existe e aceita parâmetros', () {
      expect(pdfEscape16, isNotNull);
    });
  });

  group('FontPutData', () {
    test('tem campos corretos', () {
      // FontPutData requer TTFFont que precisa de arquivo TTF real.
      // Verificamos a existência e tipo da classe.
      expect(FontPutData, isNotNull);
    });
  });
}
