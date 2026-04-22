/// Plugin de suporte a PNG para PDF.
///
/// Processa dados PNG decodificados, separando canais de cor e alfa,
/// aplica filtros PNG (None, Sub, Up, Average, Paeth) e prepara
/// a imagem para inserção no documento PDF.
///
/// Portado de modules/png_support.js do jsPDF.

import 'dart:typed_data';

// ============================================================================
// PNG Filter Methods (conforming to PNG spec)
// ============================================================================

/// Filtro None: sem filtro, apenas prefixo 0.
List<int> filterNone(Uint8List line, int bytesPerPixel, [Uint8List? prevLine]) => [0, ...line];

/// Filtro Sub: diferença com pixel à esquerda.
List<int> filterSub(Uint8List line, int bytesPerPixel, [Uint8List? prevLine]) {
  final len = line.length;
  final result = List<int>.filled(len + 1, 0);
  result[0] = 1;
  for (var i = 0; i < len; i++) {
    final left = i >= bytesPerPixel ? line[i - bytesPerPixel] : 0;
    result[i + 1] = (line[i] - left + 0x100) & 0xFF;
  }
  return result;
}

/// Filtro Up: diferença com pixel acima.
List<int> filterUp(Uint8List line, int bytesPerPixel, [Uint8List? prevLine]) {
  final len = line.length;
  final result = List<int>.filled(len + 1, 0);
  result[0] = 2;
  for (var i = 0; i < len; i++) {
    final up = prevLine != null && i < prevLine.length ? prevLine[i] : 0;
    result[i + 1] = (line[i] - up + 0x100) & 0xFF;
  }
  return result;
}

/// Filtro Average: média de esquerda e acima.
List<int> filterAverage(Uint8List line, int bytesPerPixel, [Uint8List? prevLine]) {
  final len = line.length;
  final result = List<int>.filled(len + 1, 0);
  result[0] = 3;
  for (var i = 0; i < len; i++) {
    final left = i >= bytesPerPixel ? line[i - bytesPerPixel] : 0;
    final up = prevLine != null && i < prevLine.length ? prevLine[i] : 0;
    result[i + 1] = (line[i] + 0x100 - ((left + up) >> 1)) & 0xFF;
  }
  return result;
}

/// Predictor Paeth.
int paethPredictor(int left, int up, int upLeft) {
  if (left == up && up == upLeft) return left;
  final pLeft = (up - upLeft).abs();
  final pUp = (left - upLeft).abs();
  final pUpLeft = (left + up - upLeft - upLeft).abs();
  if (pLeft <= pUp && pLeft <= pUpLeft) return left;
  if (pUp <= pUpLeft) return up;
  return upLeft;
}

/// Filtro Paeth.
List<int> filterPaeth(Uint8List line, int bytesPerPixel, [Uint8List? prevLine]) {
  final len = line.length;
  final result = List<int>.filled(len + 1, 0);
  result[0] = 4;
  for (var i = 0; i < len; i++) {
    final left = i >= bytesPerPixel ? line[i - bytesPerPixel] : 0;
    final up = prevLine != null && i < prevLine.length ? prevLine[i] : 0;
    final upLeft = (prevLine != null && i >= bytesPerPixel && i - bytesPerPixel < prevLine.length)
        ? prevLine[i - bytesPerPixel]
        : 0;
    final paeth = paethPredictor(left, up, upLeft);
    result[i + 1] = (line[i] - paeth + 0x100) & 0xFF;
  }
  return result;
}

/// Tipo de filtro para seleção.
typedef PngFilterFn = List<int> Function(Uint8List line, int bytesPerPixel, [Uint8List? prevLine]);

/// Retorna todos os métodos de filtro.
List<PngFilterFn> getFilterMethods() => [filterNone, filterSub, filterUp, filterAverage, filterPaeth];

/// Índice do array com menor soma absoluta.
int getIndexOfSmallestSum(List<List<int>> arrays) {
  var minSum = 0x7FFFFFFFFFFFFFFF;
  var minIndex = 0;
  for (var i = 0; i < arrays.length; i++) {
    var sum = 0;
    for (final v in arrays[i]) {
      sum += v.abs();
    }
    if (sum < minSum) {
      minSum = sum;
      minIndex = i;
    }
  }
  return minIndex;
}

/// Aplica um filtro PNG às linhas de pixels.
Uint8List applyPngFilterMethod(
  Uint8List bytes,
  int lineByteLength,
  int bytesPerPixel,
  PngFilterFn? filterMethod,
) {
  final lines = bytes.length ~/ lineByteLength;
  final result = Uint8List(bytes.length + lines);
  final filterMethods = getFilterMethods();
  Uint8List? prevLine;

  for (var i = 0; i < lines; i++) {
    final offset = i * lineByteLength;
    final line = Uint8List.sublistView(bytes, offset, offset + lineByteLength);

    List<int> filtered;
    if (filterMethod != null) {
      filtered = filterMethod(line, bytesPerPixel, prevLine);
    } else {
      // Optimal: testa todos os filtros e escolhe o menor
      final results = filterMethods.map((f) => f(line, bytesPerPixel, prevLine)).toList();
      final ind = getIndexOfSmallestSum(results);
      filtered = results[ind];
    }

    final destOffset = offset + i;
    for (var j = 0; j < filtered.length && destOffset + j < result.length; j++) {
      result[destOffset + j] = filtered[j];
    }
    prevLine = line;
  }

  return result;
}

// ============================================================================
// Compression helpers
// ============================================================================

/// Nível de compressão para PNG.
enum PngCompression { none, fast, medium, slow }

/// Retorna o predictor PDF para o tipo de compressão.
int getPredictorFromCompression(PngCompression compression) {
  switch (compression) {
    case PngCompression.fast:
      return 11;
    case PngCompression.medium:
      return 13;
    case PngCompression.slow:
      return 14;
    case PngCompression.none:
      return 12;
  }
}

// ============================================================================
// Bit-level read/write for PNG data
// ============================================================================

/// Lê um sample de [depth] bits na posição [sampleIndex] do buffer.
int readSample(ByteData view, int sampleIndex, int depth) {
  final bitIndex = sampleIndex * depth;
  final byteIndex = bitIndex ~/ 8;
  final bitOffset = 16 - (bitIndex - byteIndex * 8 + depth);
  final bitMask = (1 << depth) - 1;
  final word = _safeGetUint16(view, byteIndex);
  return (word >> bitOffset) & bitMask;
}

/// Escreve um sample de [depth] bits na posição [sampleIndex].
void writeSample(ByteData view, int value, int sampleIndex, int depth) {
  final bitIndex = sampleIndex * depth;
  final byteIndex = bitIndex ~/ 8;
  final bitOffset = 16 - (bitIndex - byteIndex * 8 + depth);
  final bitMask = (1 << depth) - 1;
  final writeValue = (value & bitMask) << bitOffset;
  final word = _safeGetUint16(view, byteIndex) & ~(bitMask << bitOffset) & 0xFFFF;
  _safeSetUint16(view, byteIndex, word | writeValue);
}

int _safeGetUint16(ByteData view, int byteIndex) {
  if (byteIndex + 1 < view.lengthInBytes) {
    return view.getUint16(byteIndex, Endian.big);
  }
  return view.getUint8(byteIndex) << 8;
}

void _safeSetUint16(ByteData view, int byteIndex, int value) {
  if (byteIndex + 1 < view.lengthInBytes) {
    view.setUint16(byteIndex, value, Endian.big);
    return;
  }
  view.setUint8(byteIndex, (value >> 8) & 0xFF);
}

// ============================================================================
// PNG Processing
// ============================================================================

/// Dados PNG decodificados (input).
class DecodedPng {
  final int width;
  final int height;
  final int channels;
  final int depth;
  final Uint8List data;
  final List<List<int>>? palette;

  const DecodedPng({
    required this.width,
    required this.height,
    required this.channels,
    required this.depth,
    required this.data,
    this.palette,
  });
}

/// Resultado do processamento PNG.
class PngProcessResult {
  final String colorSpace;
  final int colorsPerPixel;
  final int? sMaskBitsPerComponent;
  final Uint8List colorBytes;
  final Uint8List? alphaBytes;
  final bool needSMask;
  final List<int>? palette;
  final List<int>? mask;
  final int width;
  final int height;
  final int bitsPerComponent;
  final String? filter;
  final String? decodeParameters;
  final String? alias;
  final int? predictor;
  final String? sMask;

  const PngProcessResult({
    required this.colorSpace,
    required this.colorsPerPixel,
    this.sMaskBitsPerComponent,
    required this.colorBytes,
    this.alphaBytes,
    required this.needSMask,
    this.palette,
    this.mask,
    required this.width,
    required this.height,
    required this.bitsPerComponent,
    this.filter,
    this.decodeParameters,
    this.alias,
    this.predictor,
    this.sMask,
  });
}

/// Processa PNG indexado (com paleta).
PngProcessResult processIndexedPNG(DecodedPng png) {
  final paletteData = png.palette!;
  var needSMask = false;
  final palette = <int>[];
  final maskList = <int>[];
  Uint8List? alphaBytes;
  var hasSemiTransparency = false;
  const maxMaskLength = 1;
  var maskLength = 0;

  for (var i = 0; i < paletteData.length; i++) {
    final entry = paletteData[i];
    palette.addAll([entry[0], entry[1], entry[2]]);
    if (entry.length > 3) {
      final a = entry[3];
      if (a == 0) {
        maskLength++;
        if (maskList.length < maxMaskLength) maskList.add(i);
      } else if (a < 255) {
        hasSemiTransparency = true;
      }
    }
  }

  List<int>? mask = maskList;

  if (hasSemiTransparency || maskLength > maxMaskLength) {
    needSMask = true;
    mask = null;
    final totalPixels = png.width * png.height;
    alphaBytes = Uint8List(totalPixels);
    final dataView = ByteData.sublistView(png.data);
    for (var p = 0; p < totalPixels; p++) {
      final paletteIndex = readSample(dataView, p, png.depth);
      if (paletteIndex < paletteData.length && paletteData[paletteIndex].length > 3) {
        alphaBytes[p] = paletteData[paletteIndex][3];
      } else {
        alphaBytes[p] = 255;
      }
    }
  } else if (maskLength == 0) {
    mask = null;
  }

  return PngProcessResult(
    colorSpace: 'Indexed',
    colorsPerPixel: 1,
    sMaskBitsPerComponent: needSMask ? 8 : null,
    colorBytes: png.data,
    alphaBytes: alphaBytes,
    needSMask: needSMask,
    palette: palette,
    mask: mask,
    width: png.width,
    height: png.height,
    bitsPerComponent: png.depth,
  );
}

/// Processa PNG com canal alfa (RGBA ou GrayAlpha).
PngProcessResult processAlphaPNG(DecodedPng png) {
  final colorSpace = png.channels == 2 ? 'DeviceGray' : 'DeviceRGB';
  final colorsPerPixel = png.channels - 1;
  final totalPixels = png.width * png.height;
  final colorChannels = colorsPerPixel;
  final totalColorSamples = totalPixels * colorChannels;
  final totalAlphaSamples = totalPixels;

  final colorByteLen = (totalColorSamples * png.depth / 8).ceil();
  final alphaByteLen = (totalAlphaSamples * png.depth / 8).ceil();
  final colorBytes = Uint8List(colorByteLen);
  final alphaBytes = Uint8List(alphaByteLen);

  final dataView = ByteData.sublistView(png.data);
  final colorView = ByteData.sublistView(colorBytes);
  final alphaView = ByteData.sublistView(alphaBytes);

  var needSMask = false;
  for (var p = 0; p < totalPixels; p++) {
    final pixelStartIndex = p * png.channels;
    for (var s = 0; s < colorChannels; s++) {
      final sampleIndex = pixelStartIndex + s;
      final colorValue = readSample(dataView, sampleIndex, png.depth);
      writeSample(colorView, colorValue, p * colorChannels + s, png.depth);
    }
    final sampleIndex = pixelStartIndex + colorChannels;
    final alphaValue = readSample(dataView, sampleIndex, png.depth);
    if (alphaValue < (1 << png.depth) - 1) needSMask = true;
    writeSample(alphaView, alphaValue, p, png.depth);
  }

  return PngProcessResult(
    colorSpace: colorSpace,
    colorsPerPixel: colorsPerPixel,
    sMaskBitsPerComponent: needSMask ? png.depth : null,
    colorBytes: colorBytes,
    alphaBytes: alphaBytes,
    needSMask: needSMask,
    width: png.width,
    height: png.height,
    bitsPerComponent: png.depth,
  );
}

/// Processa PNG opaco (RGB ou Grayscale, sem alfa).
PngProcessResult processOpaquePNG(DecodedPng png) {
  final colorSpace = png.channels == 1 ? 'DeviceGray' : 'DeviceRGB';
  final colorsPerPixel = colorSpace == 'DeviceGray' ? 1 : 3;

  return PngProcessResult(
    colorSpace: colorSpace,
    colorsPerPixel: colorsPerPixel,
    colorBytes: png.data,
    needSMask: false,
    width: png.width,
    height: png.height,
    bitsPerComponent: png.depth,
  );
}

/// Processa um PNG decodificado para embedding no PDF.
///
/// [png] é o PNG já decodificado (via fast-png ou similar).
/// [compression] define se os dados serão comprimidos com zlib.
PngProcessResult processPNG(DecodedPng png, {PngCompression compression = PngCompression.none}) {
  PngProcessResult result;

  if (png.palette != null && png.channels == 1) {
    result = processIndexedPNG(png);
  } else if (png.channels == 2 || png.channels == 4) {
    result = processAlphaPNG(png);
  } else {
    result = processOpaquePNG(png);
  }

  return result;
}
