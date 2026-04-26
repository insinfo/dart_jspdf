import 'dart:typed_data';

class ZLibCodec {
  final int level;
  final bool verifyChecksum;

  const ZLibCodec({this.level = 6, this.verifyChecksum = true});

  Uint8List encode(List<int> input) => zlibEncodeStored(input);

  Uint8List decode(List<int> input) => zlibDecode(
        input is Uint8List ? input : Uint8List.fromList(input),
        verifyChecksum: verifyChecksum,
      );
}

Uint8List zlibDecode(Uint8List bytes, {bool verifyChecksum = true}) {
  if (bytes.length < 6) {
    throw const FormatException('ZLib stream is too short.');
  }
  final int cmf = bytes[0];
  final int flg = bytes[1];
  if ((cmf & 0x0f) != 8) {
    throw const FormatException('Unsupported ZLib compression method.');
  }
  if (((cmf << 8) + flg) % 31 != 0) {
    throw const FormatException('Invalid ZLib header check bits.');
  }
  if ((flg & 0x20) != 0) {
    throw const FormatException('Preset ZLib dictionaries are not supported.');
  }

  final Uint8List deflateBytes =
      Uint8List.sublistView(bytes, 2, bytes.length - 4);
  final Uint8List output = _inflateRaw(deflateBytes);

  if (verifyChecksum) {
    final int expected = _readUint32(bytes, bytes.length - 4);
    final int actual = adler32(output);
    if (expected != actual) {
      throw const FormatException('Invalid ZLib Adler-32 checksum.');
    }
  }

  return output;
}

Uint8List zlibEncodeStored(List<int> bytes) {
  final BytesBuilder builder = BytesBuilder(copy: false);
  builder.addByte(0x78);
  builder.addByte(0x01);

  int offset = 0;
  while (offset < bytes.length || bytes.isEmpty && offset == 0) {
    final int remaining = bytes.length - offset;
    final int blockLength = remaining > 0xffff ? 0xffff : remaining;
    final bool isFinal = offset + blockLength >= bytes.length;
    builder.addByte(isFinal ? 0x01 : 0x00);
    builder.addByte(blockLength & 0xff);
    builder.addByte((blockLength >> 8) & 0xff);
    final int inverted = blockLength ^ 0xffff;
    builder.addByte(inverted & 0xff);
    builder.addByte((inverted >> 8) & 0xff);
    if (blockLength > 0) {
      builder.add(bytes.sublist(offset, offset + blockLength));
    }
    offset += blockLength;
    if (bytes.isEmpty) {
      break;
    }
  }

  final int checksum = adler32(bytes);
  builder.addByte((checksum >> 24) & 0xff);
  builder.addByte((checksum >> 16) & 0xff);
  builder.addByte((checksum >> 8) & 0xff);
  builder.addByte(checksum & 0xff);
  return builder.takeBytes();
}

int adler32(List<int> bytes) {
  int a = 1;
  int b = 0;
  for (final int byte in bytes) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return ((b << 16) | a) & 0xffffffff;
}

Uint8List _inflateRaw(Uint8List bytes) {
  final _BitReader reader = _BitReader(bytes);
  final List<int> output = <int>[];
  bool isFinal = false;

  while (!isFinal) {
    isFinal = reader.readBits(1) == 1;
    final int blockType = reader.readBits(2);
    switch (blockType) {
      case 0:
        _inflateStored(reader, output);
        break;
      case 1:
        _inflateCompressed(
            reader, output, _fixedLiteralLengthTree, _fixedDistanceTree);
        break;
      case 2:
        final _DynamicTrees trees = _readDynamicTrees(reader);
        _inflateCompressed(
            reader, output, trees.literalLengthTree, trees.distanceTree);
        break;
      default:
        throw const FormatException('Invalid DEFLATE block type.');
    }
  }

  return Uint8List.fromList(output);
}

void _inflateStored(_BitReader reader, List<int> output) {
  reader.alignToByte();
  final int length = reader.readByte() | (reader.readByte() << 8);
  final int invertedLength = reader.readByte() | (reader.readByte() << 8);
  if ((length ^ 0xffff) != invertedLength) {
    throw const FormatException('Invalid DEFLATE stored block length.');
  }
  for (int i = 0; i < length; i++) {
    output.add(reader.readByte());
  }
}

void _inflateCompressed(
  _BitReader reader,
  List<int> output,
  _HuffmanTree literalLengthTree,
  _HuffmanTree distanceTree,
) {
  while (true) {
    final int symbol = literalLengthTree.decode(reader);
    if (symbol < 256) {
      output.add(symbol);
      continue;
    }
    if (symbol == 256) {
      return;
    }
    if (symbol > 285) {
      throw const FormatException('Invalid DEFLATE length symbol.');
    }

    final int lengthIndex = symbol - 257;
    int length = _lengthBases[lengthIndex];
    final int lengthExtraBits = _lengthExtraBits[lengthIndex];
    if (lengthExtraBits > 0) {
      length += reader.readBits(lengthExtraBits);
    }

    final int distanceSymbol = distanceTree.decode(reader);
    if (distanceSymbol >= _distanceBases.length) {
      throw const FormatException('Invalid DEFLATE distance symbol.');
    }
    int distance = _distanceBases[distanceSymbol];
    final int distanceExtraBits = _distanceExtraBits[distanceSymbol];
    if (distanceExtraBits > 0) {
      distance += reader.readBits(distanceExtraBits);
    }
    if (distance <= 0 || distance > output.length) {
      throw const FormatException('Invalid DEFLATE backward distance.');
    }

    for (int i = 0; i < length; i++) {
      output.add(output[output.length - distance]);
    }
  }
}

_DynamicTrees _readDynamicTrees(_BitReader reader) {
  final int literalLengthCount = reader.readBits(5) + 257;
  final int distanceCount = reader.readBits(5) + 1;
  final int codeLengthCount = reader.readBits(4) + 4;
  const List<int> codeLengthOrder = <int>[
    16,
    17,
    18,
    0,
    8,
    7,
    9,
    6,
    10,
    5,
    11,
    4,
    12,
    3,
    13,
    2,
    14,
    1,
    15,
  ];

  final List<int> codeLengthLengths = List<int>.filled(19, 0);
  for (int i = 0; i < codeLengthCount; i++) {
    codeLengthLengths[codeLengthOrder[i]] = reader.readBits(3);
  }

  final _HuffmanTree codeLengthTree = _HuffmanTree(codeLengthLengths);
  final int totalLengthCount = literalLengthCount + distanceCount;
  final List<int> lengths = <int>[];

  while (lengths.length < totalLengthCount) {
    final int symbol = codeLengthTree.decode(reader);
    if (symbol <= 15) {
      lengths.add(symbol);
    } else if (symbol == 16) {
      if (lengths.isEmpty) {
        throw const FormatException('Invalid DEFLATE repeat code.');
      }
      final int repeat = reader.readBits(2) + 3;
      final int previous = lengths.last;
      for (int i = 0; i < repeat; i++) {
        lengths.add(previous);
      }
    } else if (symbol == 17) {
      final int repeat = reader.readBits(3) + 3;
      for (int i = 0; i < repeat; i++) {
        lengths.add(0);
      }
    } else if (symbol == 18) {
      final int repeat = reader.readBits(7) + 11;
      for (int i = 0; i < repeat; i++) {
        lengths.add(0);
      }
    } else {
      throw const FormatException('Invalid DEFLATE code length symbol.');
    }
  }

  final List<int> literalLengthLengths = lengths.sublist(0, literalLengthCount);
  final List<int> distanceLengths =
      lengths.sublist(literalLengthCount, totalLengthCount);
  return _DynamicTrees(
    _HuffmanTree(literalLengthLengths),
    _HuffmanTree(distanceLengths),
  );
}

class _DynamicTrees {
  final _HuffmanTree literalLengthTree;
  final _HuffmanTree distanceTree;

  const _DynamicTrees(this.literalLengthTree, this.distanceTree);
}

class _HuffmanTree {
  final Map<int, int> _symbolsByLengthAndCode;
  final int _maxBits;

  _HuffmanTree(List<int> codeLengths)
      : _symbolsByLengthAndCode = <int, int>{},
        _maxBits = codeLengths.fold<int>(
            0, (int max, int length) => length > max ? length : max) {
    if (_maxBits == 0) {
      return;
    }

    final List<int> blCount = List<int>.filled(_maxBits + 1, 0);
    for (final int length in codeLengths) {
      if (length > 0) {
        blCount[length]++;
      }
    }

    final List<int> nextCode = List<int>.filled(_maxBits + 1, 0);
    int code = 0;
    for (int bits = 1; bits <= _maxBits; bits++) {
      code = (code + blCount[bits - 1]) << 1;
      nextCode[bits] = code;
    }

    for (int symbol = 0; symbol < codeLengths.length; symbol++) {
      final int length = codeLengths[symbol];
      if (length == 0) {
        continue;
      }
      final int canonicalCode = nextCode[length]++;
      final int reversedCode = _reverseBits(canonicalCode, length);
      _symbolsByLengthAndCode[(length << 16) | reversedCode] = symbol;
    }
  }

  int decode(_BitReader reader) {
    int code = 0;
    for (int length = 1; length <= _maxBits; length++) {
      code |= reader.readBits(1) << (length - 1);
      final int? symbol = _symbolsByLengthAndCode[(length << 16) | code];
      if (symbol != null) {
        return symbol;
      }
    }
    throw const FormatException('Invalid DEFLATE Huffman code.');
  }
}

class _BitReader {
  final Uint8List bytes;
  int byteOffset = 0;
  int bitBuffer = 0;
  int bitCount = 0;

  _BitReader(this.bytes);

  int readBits(int count) {
    while (bitCount < count) {
      if (byteOffset >= bytes.length) {
        throw const FormatException('Unexpected end of DEFLATE stream.');
      }
      bitBuffer |= bytes[byteOffset++] << bitCount;
      bitCount += 8;
    }
    final int mask = (1 << count) - 1;
    final int value = bitBuffer & mask;
    bitBuffer >>= count;
    bitCount -= count;
    return value;
  }

  int readByte() => readBits(8);

  void alignToByte() {
    final int drop = bitCount % 8;
    if (drop > 0) {
      readBits(drop);
    }
  }
}

int _reverseBits(int value, int length) {
  int reversed = 0;
  for (int i = 0; i < length; i++) {
    reversed = (reversed << 1) | (value & 1);
    value >>= 1;
  }
  return reversed;
}

int _readUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

final _HuffmanTree _fixedLiteralLengthTree = _HuffmanTree(<int>[
  ...List<int>.filled(144, 8),
  ...List<int>.filled(112, 9),
  ...List<int>.filled(24, 7),
  ...List<int>.filled(8, 8),
]);

final _HuffmanTree _fixedDistanceTree = _HuffmanTree(List<int>.filled(32, 5));

const List<int> _lengthBases = <int>[
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  13,
  15,
  17,
  19,
  23,
  27,
  31,
  35,
  43,
  51,
  59,
  67,
  83,
  99,
  115,
  131,
  163,
  195,
  227,
  258,
];

const List<int> _lengthExtraBits = <int>[
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  3,
  3,
  3,
  3,
  4,
  4,
  4,
  4,
  5,
  5,
  5,
  5,
  0,
];

const List<int> _distanceBases = <int>[
  1,
  2,
  3,
  4,
  5,
  7,
  9,
  13,
  17,
  25,
  33,
  49,
  65,
  97,
  129,
  193,
  257,
  385,
  513,
  769,
  1025,
  1537,
  2049,
  3073,
  4097,
  6145,
  8193,
  12289,
  16385,
  24577,
];

const List<int> _distanceExtraBits = <int>[
  0,
  0,
  0,
  0,
  1,
  1,
  2,
  2,
  3,
  3,
  4,
  4,
  5,
  5,
  6,
  6,
  7,
  7,
  8,
  8,
  9,
  9,
  10,
  10,
  11,
  11,
  12,
  12,
  13,
  13,
];
