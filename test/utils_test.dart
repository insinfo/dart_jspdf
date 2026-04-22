import 'package:test/test.dart';
import 'package:jspdf/src/utils.dart';

void main() {
  group('roundToPrecision', () {
    test('arredonda para precisão especificada', () {
      expect(roundToPrecision(3.14159, 2), equals('3.14'));
      expect(roundToPrecision(3.14159, 4), equals('3.1416'));
    });

    test('remove zeros à direita', () {
      expect(roundToPrecision(1.50000, 5), equals('1.5'));
      expect(roundToPrecision(2.0, 3), equals('2.'));
    });

    test('lança erro para NaN', () {
      expect(
        () => roundToPrecision(double.nan, 2),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('createHpf', () {
    test('precisão fixa inteira', () {
      final hpf = createHpf(2);
      expect(hpf(3.14159), equals('3.14'));
    });

    test('precisão smart', () {
      final hpf = createHpf('smart');
      // Números pequenos → 16 casas
      final small = hpf(0.00123);
      expect(small.contains('0.00123'), isTrue);

      // Números grandes → 5 casas
      final big = hpf(123.456789);
      expect(big, equals('123.45679'));
    });

    test('lança erro para NaN', () {
      final hpf = createHpf(16);
      expect(() => hpf(double.nan), throwsA(isA<ArgumentError>()));
    });
  });

  group('f2 e f3', () {
    test('f2 formata com 2 casas', () {
      expect(f2(3.14159), equals('3.14'));
      expect(f2(0), equals('0.'));
    });

    test('f3 formata com 3 casas', () {
      expect(f3(3.14159), equals('3.142'));
    });
  });

  group('padd2', () {
    test('adiciona zero à esquerda', () {
      expect(padd2(5), equals('05'));
      expect(padd2(12), equals('12'));
      expect(padd2(0), equals('00'));
    });
  });

  group('padd2Hex', () {
    test('padding hexadecimal', () {
      expect(padd2Hex('f'), equals('0f'));
      expect(padd2Hex('ff'), equals('ff'));
    });
  });

  group('pdfEscape', () {
    test('escapa caracteres especiais', () {
      expect(pdfEscape(r'test\path'), equals(r'test\\path'));
      expect(pdfEscape('(hello)'), equals(r'\(hello\)'));
      expect(pdfEscape('test\rline'), equals(r'test\rline'));
    });

    test('string sem caracteres especiais fica igual', () {
      expect(pdfEscape('hello world'), equals('hello world'));
    });
  });

  group('convertDateToPDFDate', () {
    test('converte DateTime para formato PDF', () {
      final date = DateTime(2024, 3, 15, 10, 30, 45);
      final pdfDate = convertDateToPDFDate(date);
      expect(pdfDate, startsWith('D:20240315103045'));
    });

    test('formato inclui timezone', () {
      final date = DateTime.now();
      final pdfDate = convertDateToPDFDate(date);
      expect(pdfDate, startsWith('D:'));
      // Deve ter pelo menos 'D:' + 14 chars de data + timezone
      expect(pdfDate.length, greaterThan(16));
    });
  });

  group('convertPDFDateToDate', () {
    test('converte string PDF de volta para DateTime', () {
      final date = DateTime(2024, 3, 15, 10, 30, 45);
      final pdfDate = convertDateToPDFDate(date);
      final restored = convertPDFDateToDate(pdfDate);

      expect(restored.year, equals(2024));
      expect(restored.month, equals(3));
      expect(restored.day, equals(15));
      expect(restored.hour, equals(10));
      expect(restored.minute, equals(30));
      expect(restored.second, equals(45));
    });
  });

  group('generateFileId', () {
    test('gera ID de 32 caracteres', () {
      final id = generateFileId();
      expect(id.length, equals(32));
      expect(RegExp(r'^[A-F0-9]{32}$').hasMatch(id), isTrue);
    });

    test('gera IDs diferentes', () {
      final id1 = generateFileId();
      final id2 = generateFileId();
      expect(id1, isNot(equals(id2)));
    });
  });

  group('normalizeFileId', () {
    test('aceita hex válido de 32 chars', () {
      const hex = 'aabbccdd11223344aabbccdd11223344';
      expect(normalizeFileId(hex), equals(hex.toUpperCase()));
    });

    test('gera novo ID para valor inválido', () {
      final id = normalizeFileId('invalid');
      expect(id.length, equals(32));
      expect(RegExp(r'^[A-F0-9]{32}$').hasMatch(id), isTrue);
    });

    test('gera novo ID para null', () {
      final id = normalizeFileId(null);
      expect(id.length, equals(32));
    });
  });
}
