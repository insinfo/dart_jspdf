import 'package:jspdf/src/libs/zlib.dart';
import 'package:test/test.dart';

void main() {
  group('ZLibCodec puro', () {
    test('encode/decode roundtrip com blocos stored', () {
      final codec = ZLibCodec();
      final data = <int>[0, 1, 2, 3, 255, ...'hello'.codeUnits];

      final encoded = codec.encode(data);
      final decoded = codec.decode(encoded);

      expect(decoded, equals(data));
    });

    test('valida Adler-32', () {
      final encoded = ZLibCodec().encode(<int>[1, 2, 3]);
      encoded[encoded.length - 1] ^= 0xff;

      expect(() => ZLibCodec().decode(encoded), throwsFormatException);
    });
  });
}
