import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:jspdf/src/libs/ttffont.dart';

void main() {
  group('TTFFont Integration Test', () {
    late Uint8List fontBytes;
    late TTFFont font;

    setUpAll(() {
      // Carrega um arquivo TTF real copiado para a pasta de testes.
      final file = File('test/assets/Roboto-Regular.ttf');
      if (!file.existsSync()) {
        fail('Arquivo Roboto-Regular.ttf não encontrado. Certifique-se de executar os testes na raiz do projeto.');
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

    test('Mapeamento de Character para GlyphId (cmap)', () {
      font = TTFFont(fontBytes);
      
      // Letra 'A'
      final glyphA = font.characterToGlyph(0x0041);
      expect(glyphA, isNonZero, reason: "Deve encontrar o Glyph ID para 'A'");
      
      // Letra 'a'
      final glypha = font.characterToGlyph(0x0061);
      expect(glypha, isNonZero, reason: "Deve encontrar o Glyph ID para 'a'");
      expect(glyphA, isNot(equals(glypha)), reason: "'A' e 'a' devem ter glyphs diferentes");
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
      
      expect(encodedSubset, isNotEmpty, reason: "Subset encode não deve estar vazio");
    });
  });
}
