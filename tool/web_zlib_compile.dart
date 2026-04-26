import 'package:jspdf/src/libs/zlib_codec.dart';

void main() {
  final codec = ZLibCodec();
  final encoded = codec.encode(<int>[1, 2, 3, 4]);
  final decoded = codec.decode(encoded);
  if (decoded.length != 4 || decoded[0] != 1 || decoded[3] != 4) {
    throw StateError('ZLibCodec roundtrip failed');
  }
}
