import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:jspdf/jspdf.dart';
import 'package:test/test.dart';

void main() {
  group('TTFFont Integration Test', () {
    late Uint8List fontBytes;
    late TTFFont font;

    setUpAll(() {
      // Carrega um arquivo TTF real copiado para a pasta de testes.
      final file = File('test/assets/Roboto-Regular.ttf');
      if (!file.existsSync()) {
        fail(
            'Arquivo Roboto-Regular.ttf não encontrado. Certifique-se de executar os testes na raiz do projeto.');
      }
      fontBytes = file.readAsBytesSync();
    });

    test('Lê tabelas de uma fonte TTF real sem lançar exceções', () {
      expect(() {
        font = TTFFont(fontBytes);
      }, returnsNormally);

      // Algumas asserções sobre os dados extraídos pelo parser:
      expect(font.ascender, isNonZero);
      expect(font.head.unitsPerEm, isPositive);
      expect(font.capHeight, isNonZero);
    });

    test('decodifica nomes e métricas profissionais da fonte', () {
      font = TTFFont(fontBytes);

      expect(font.postScriptName, isNotEmpty);
      expect(font.postScriptName, isNot(contains('\u0000')));
      expect(font.familyName, isNotNull);
      expect(font.fullName, isNotNull);
      expect(font.bbox, hasLength(4));
      expect(font.ascender, greaterThan(0));
      expect(font.decender, lessThan(0));
      expect(font.lineHeight(12), greaterThanOrEqualTo(12));
      expect(font.widthOfString('AV', 12), greaterThan(0));
    });

    test('Mapeamento de Character para GlyphId (cmap)', () {
      font = TTFFont(fontBytes);

      // Letra 'A'
      final glyphA = font.characterToGlyph(0x0041);
      expect(glyphA, isNonZero, reason: "Deve encontrar o Glyph ID para 'A'");

      // Letra 'a'
      final glypha = font.characterToGlyph(0x0061);
      expect(glypha, isNonZero, reason: "Deve encontrar o Glyph ID para 'a'");
      expect(glyphA, isNot(equals(glypha)),
          reason: "'A' e 'a' devem ter glyphs diferentes");
    });

    test('itera strings por code points Unicode', () {
      font = TTFFont(fontBytes);

      expect(font.codePoints('A😀'), equals(<int>[0x41, 0x1f600]));
      expect(() => font.widthOfString('A😀', 12), returnsNormally);
    });

    test('Subsetting: Encode subset font', () {
      font = TTFFont(fontBytes);

      // Define alguns glyphIds que simulamos ter usado.
      // 0 = missing glyph (sempre presente),
      // Em Roboto, vamos assumir que A e 'espaço' são mapeados para algo.
      final glyphA = font.characterToGlyph(0x0041); // 'A'
      final glyphB = font.characterToGlyph(0x0042); // 'B'

      font.glyIdsUsed.clear();
      font.glyIdsUsed.addAll([0, glyphA, glyphB]);

      // Chama o Subset encode
      final encodedSubset = font.subset.encode(font.glyIdsUsed, 1);

      expect(encodedSubset, isNotEmpty,
          reason: "Subset encode não deve estar vazio");
    });

    test('JsPdf registra TTF da vFS e embute fonte Identity-H', () {
      final pdf = JsPdf()
        ..addFileToVFS('Roboto-Regular.ttf', base64.encode(fontBytes))
        ..addFont('Roboto-Regular.ttf', 'roboto')
        ..setFont('roboto')
        ..text('AB', 10, 10);

      expect(pdf.existsFileInVFS('Roboto-Regular.ttf'), isTrue);
      expect(pdf.getFileFromVFS('Roboto-Regular.ttf'), isNotNull);

      final output = pdf.output() as String;

      expect(output, contains('/Subtype /Type0'));
      expect(output, contains('/Encoding /Identity-H'));
      expect(output, contains('/FontFile2'));
      expect(output, contains('/ToUnicode'));
      expect(output, isNot(contains('(AB) Tj')));
    });

    test('JsPdf aceita TTF da vFS como binary string', () {
      final pdf = JsPdf()
        ..addFileToVFS('Roboto-Regular.ttf', String.fromCharCodes(fontBytes))
        ..addFont('Roboto-Regular.ttf', 'roboto')
        ..setFont('roboto')
        ..text('A', 10, 10);

      final output = pdf.output() as String;

      expect(output, contains('/FontFile2'));
      expect(output, contains('<'));
    });
  });
}
