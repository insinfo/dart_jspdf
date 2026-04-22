import 'dart:convert';
import 'dart:html';
import 'dart:math' as math;
import 'dart:typed_data';

import 'color.dart';
import 'fonts.dart';

import 'gstate.dart';
import 'matrix.dart';
import 'page_formats.dart';
import 'pattern.dart';
import 'pdf_document.dart';
import 'pubsub.dart';
import 'utils.dart';

/// Opções de configuração do documento JsPdf.
class JsPdfOptions {
  /// Orientação: 'portrait'/'p' ou 'landscape'/'l'.
  final String orientation;

  /// Unidade de medida: 'pt', 'mm', 'cm', 'in', 'px', 'pc', 'em', 'ex'.
  final String unit;

  /// Formato da página: nome (ex: 'a4') ou dimensões [largura, altura].
  final dynamic format;

  /// Compressão (FlateEncode). Nota: não implementado neste porte inicial.
  final bool compress;

  /// Precisão de posições de elementos.
  final int? precision;

  /// Precisão de floats.
  final dynamic floatPrecision;

  /// Unidade do usuário (não confundir com unit base).
  final double userUnit;

  /// Apenas incluir fontes usadas.
  final bool putOnlyUsedFonts;

  /// Operação de path padrão.
  final String defaultPathOperation;

  /// Tamanho da fonte inicial.
  final double fontSize;

  /// Right-to-left.
  final bool r2l;

  /// Hotfixes habilitados.
  final List<String> hotfixes;

  const JsPdfOptions({
    this.orientation = 'portrait',
    this.unit = 'mm',
    this.format = 'a4',
    this.compress = false,
    this.precision,
    this.floatPrecision = 16,
    this.userUnit = 1.0,
    this.putOnlyUsedFonts = false,
    this.defaultPathOperation = 'S',
    this.fontSize = 16,
    this.r2l = false,
    this.hotfixes = const [],
  });
}

/// Modo da API (compatível ou avançado).
enum ApiMode { compat, advanced }

/// Gerador de documentos PDF para Dart/Web.
///
/// Porte completo do jsPDF para Dart usando dart:html.
/// Oferece API fluente para criação de PDFs no navegador.
///
/// Exemplo de uso:
/// ```dart
/// final pdf = JsPdf();
/// pdf.text('Hello World!', 10, 10);
/// pdf.save('test.pdf');
/// ```
class JsPdf {
  late final PdfDocumentBuilder _doc;
  late final PubSub _events;
  late final String Function(num) _hpf;

  // --- State ---
  String _pdfVersion = '1.3';
  ApiMode _apiMode = ApiMode.compat;
  // ignore: unused_field
  String _defaultPathOperation = 'S';
  // ignore: unused_field
  int? _precision;
  late double _scaleFactor;
  late double _userUnit;
  late bool _putOnlyUsedFonts;
  // ignore: unused_field
  late bool _r2l;
  // ignore: unused_field
  late List<String> _hotfixes;

  // Font state
  final Map<String, PdfFont> _fonts = {};
  final Map<String, Map<String, String>> _fontmap = {};
  String _activeFontKey = '';
  double _activeFontSize = 16;
  // ignore: unused_field
  final List<Map<String, dynamic>> _fontStateStack = [];

  // Color state
  String _textColor = '0 g';
  String _drawColor = '0 G';
  String _fillColor = '0 g';

  // Graphics state
  double _lineWidth = 0.200025;
  // ignore: unused_field
  String _lineJoin = 'miter';
  // ignore: unused_field
  String _lineCap = 'butt';
  // ignore: unused_field
  double _miterLimit = 10.0;
  // ignore: unused_field
  List<List<num>> _dashPattern = [];
  double _lineHeightFactor = 1.15;
  double _charSpace = 0;

  // GState - reservados para uso futuro (módulos avançados)
  // ignore: unused_field
  final Map<String, GState> _gStates = {};
  // ignore: unused_field
  final Map<String, String> _gStatesMap = {};
  // ignore: unused_field
  GState? _activeGState;

  // Patterns - reservados para uso futuro
  // ignore: unused_field
  final Map<String, PdfPattern> _patterns = {};
  // ignore: unused_field
  final Map<String, String> _patternMap = {};

  // Document properties
  final Map<String, String> _documentProperties = {
    'title': '',
    'subject': '',
    'author': '',
    'keywords': '',
    'creator': '',
  };

  // Display mode
  String? _zoomMode;
  String? _pageMode;
  String? _layoutMode;

  // Creation date
  late String _creationDate;
  late String _fileId;

  // Used fonts tracking
  final Map<String, bool> _usedFonts = {};

  // Graphics state stack
  final List<Map<String, dynamic>> _graphicsStateStack = [];

  JsPdf([JsPdfOptions? options]) {
    options ??= const JsPdfOptions();

    _defaultPathOperation = options.defaultPathOperation;
    _userUnit = options.userUnit.abs();
    _putOnlyUsedFonts = options.putOnlyUsedFonts;
    _r2l = options.r2l;
    _hotfixes = List.from(options.hotfixes);

    if (options.precision != null) {
      _precision = options.precision;
    }

    _hpf = createHpf(options.floatPrecision);

    // Configurar unidade e fator de escala
    _scaleFactor = getScaleFactor(options.unit);

    // Configurar formato de página
    List<double> dimensions;
    if (options.format is String) {
      final fmt = getPageFormat(options.format as String);
      if (fmt == null) {
        throw ArgumentError('Invalid format: ${options.format}');
      }
      dimensions = fmt;
    } else if (options.format is List) {
      dimensions = (options.format as List).cast<double>();
    } else {
      dimensions = getPageFormat('a4')!;
    }

    // Criar o builder de documento
    _doc = PdfDocumentBuilder(pdfVersion: _pdfVersion, hpf: _hpf);
    _events = PubSub();

    // Configurar fontes padrão
    _addStandardFonts();
    _activeFontKey = 'F1';
    _activeFontSize = options.fontSize;

    // Configurar data e ID
    _creationDate = convertDateToPDFDate(DateTime.now());
    _fileId = normalizeFileId(null);

    // Orientação
    final orientLower = options.orientation.toLowerCase();
    final isLandscape = orientLower == 'l' || orientLower == 'landscape';

    double pageWidth, pageHeight;
    if (isLandscape) {
      pageWidth = math.max(dimensions[0], dimensions[1]);
      pageHeight = math.min(dimensions[0], dimensions[1]);
    } else {
      pageWidth = math.min(dimensions[0], dimensions[1]);
      pageHeight = math.max(dimensions[0], dimensions[1]);
    }

    // Adicionar primeira página
    _doc.addPage(MediaBox.fromDimensions(pageWidth, pageHeight),
        userUnit: _userUnit);
  }

  // ==========================================================================
  // PDF Version
  // ==========================================================================

  String get pdfVersion => _pdfVersion;
  set pdfVersion(String v) => _pdfVersion = v;

  // ==========================================================================
  // Font Management
  // ==========================================================================

  void _addStandardFonts() {
    var keyIndex = 1;
    for (final sf in standardFonts) {
      final key = 'F$keyIndex';
      final font = PdfFont(
        key: key,
        fontName: sf.fontName,
        fontStyle: sf.fontStyle,
        encoding: sf.encoding,
        postScriptName: sf.postScriptName,
      );
      _fonts[key] = font;

      _fontmap.putIfAbsent(sf.fontName, () => {});
      _fontmap[sf.fontName]![sf.fontStyle] = key;

      keyIndex++;
    }
  }

  /// Define a fonte ativa.
  JsPdf setFont(String fontName, {String fontStyle = 'normal'}) {
    final nameLower = fontName.toLowerCase();
    String? key;

    if (_fontmap.containsKey(nameLower) &&
        _fontmap[nameLower]!.containsKey(fontStyle)) {
      key = _fontmap[nameLower]![fontStyle];
    } else if (_fontmap.containsKey(fontName) &&
        _fontmap[fontName]!.containsKey(fontStyle)) {
      key = _fontmap[fontName]![fontStyle];
    }

    if (key == null) {
      // Fallback para times normal
      key = _fontmap['times']?['normal'] ?? 'F1';
    }

    _activeFontKey = key;
    if (_putOnlyUsedFonts) {
      _usedFonts[key] = true;
    }

    return this;
  }

  /// Retorna a fonte ativa.
  PdfFont getFont() => _fonts[_activeFontKey]!;

  /// Define o tamanho da fonte em pontos.
  JsPdf setFontSize(double size) {
    if (_apiMode == ApiMode.advanced) {
      _activeFontSize = size / _scaleFactor;
    } else {
      _activeFontSize = size;
    }
    return this;
  }

  /// Retorna o tamanho da fonte atual.
  double getFontSize() {
    if (_apiMode == ApiMode.compat) {
      return _activeFontSize;
    } else {
      return _activeFontSize * _scaleFactor;
    }
  }

  /// Retorna lista de fontes disponíveis.
  Map<String, List<String>> getFontList() {
    final result = <String, List<String>>{};
    for (final entry in _fontmap.entries) {
      result[entry.key] = entry.value.keys.toList();
    }
    return result;
  }

  // ==========================================================================
  // Font Size, Color, Style
  // ==========================================================================

  /// Define a cor do texto.
  JsPdf setTextColor(dynamic ch1, [dynamic ch2, dynamic ch3]) {
    _textColor = _buildColorString(ch1, ch2, ch3, pdfColorType: 'fill');
    return this;
  }

  /// Define a cor do traçado.
  JsPdf setDrawColor(dynamic ch1, [dynamic ch2, dynamic ch3]) {
    _drawColor = _buildColorString(ch1, ch2, ch3, pdfColorType: 'draw');
    _doc.out(_drawColor);
    return this;
  }

  /// Define a cor de preenchimento.
  JsPdf setFillColor(dynamic ch1, [dynamic ch2, dynamic ch3]) {
    _fillColor = _buildColorString(ch1, ch2, ch3, pdfColorType: 'fill');
    _doc.out(_fillColor);
    return this;
  }

  String _buildColorString(
    dynamic ch1,
    dynamic ch2,
    dynamic ch3, {
    String pdfColorType = 'fill',
  }) {
    return encodeColorString(
      ColorOptions(ch1: ch1, ch2: ch2, ch3: ch3, pdfColorType: pdfColorType),
    );
  }

  // ==========================================================================
  // Line Style
  // ==========================================================================

  /// Define a largura da linha.
  JsPdf setLineWidth(double width) {
    _lineWidth = width;
    _doc.out('${_hpf(width * _scaleFactor)} w');
    return this;
  }

  /// Define o padrão de traço (dash).
  JsPdf setLineDash(List<num> dashArray, [num dashPhase = 0]) {
    _dashPattern = [dashArray, [dashPhase]];
    final scaled = dashArray.map((d) => _hpf(d * _scaleFactor)).join(' ');
    _doc.out('[$scaled] ${_hpf(dashPhase * _scaleFactor)} d');
    return this;
  }

  /// Define o estilo de junção de linhas.
  JsPdf setLineJoin(dynamic style) {
    int joinCode;
    if (style is int) {
      joinCode = style;
    } else {
      switch (style.toString()) {
        case 'miter':
          joinCode = 0;
          break;
        case 'round':
          joinCode = 1;
          break;
        case 'bevel':
          joinCode = 2;
          break;
        default:
          joinCode = 0;
      }
    }
    _doc.out('$joinCode j');
    return this;
  }

  /// Define o estilo de terminação de linha.
  JsPdf setLineCap(dynamic style) {
    int capCode;
    if (style is int) {
      capCode = style;
    } else {
      switch (style.toString()) {
        case 'butt':
          capCode = 0;
          break;
        case 'round':
          capCode = 1;
          break;
        case 'square':
          capCode = 2;
          break;
        default:
          capCode = 0;
      }
    }
    _doc.out('$capCode J');
    return this;
  }

  // ==========================================================================
  // Drawing Primitives
  // ==========================================================================

  /// Estilo de desenho PDF.
  String _getStyle(String? style) {
    switch (style) {
      case 'D':
      case null:
        return 'S'; // stroke
      case 'F':
        return 'f'; // fill
      case 'FD':
      case 'DF':
        return 'B'; // fill + stroke
      case 'f':
      case 'f*':
      case 'B':
      case 'B*':
        return style;
      default:
        return 'S';
    }
  }

  /// Desenha uma linha de (x1,y1) a (x2,y2).
  JsPdf line(double x1, double y1, double x2, double y2) {
    if (_apiMode == ApiMode.compat) {
      _doc.out(
        '${_hpf(x1 * _scaleFactor)} ${_hpf(_transformY(y1) * _scaleFactor)} m '
        '${_hpf(x2 * _scaleFactor)} ${_hpf(_transformY(y2) * _scaleFactor)} l S',
      );
    } else {
      _doc.out(
        '${_hpf(x1)} ${_hpf(y1)} m ${_hpf(x2)} ${_hpf(y2)} l S',
      );
    }
    return this;
  }

  /// Desenha um retângulo.
  JsPdf rect(double x, double y, double w, double h, [String? style]) {
    final op = _getStyle(style);
    if (_apiMode == ApiMode.compat) {
      _doc.out(
        '${_hpf(x * _scaleFactor)} ${_hpf(_transformY(y) * _scaleFactor)} '
        '${_hpf(w * _scaleFactor)} ${_hpf(-h * _scaleFactor)} re $op',
      );
    } else {
      _doc.out('${_hpf(x)} ${_hpf(y)} ${_hpf(w)} ${_hpf(h)} re $op');
    }
    return this;
  }

  /// Desenha um retângulo arredondado.
  JsPdf roundedRect(
    double x,
    double y,
    double w,
    double h,
    double rx,
    double ry, [
    String? style,
  ]) {
    final op = _getStyle(style);
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final MyArc = 4 / 3 * (math.sqrt(2) - 1);

    final xVal = x * k;
    final yVal = ((_apiMode == ApiMode.compat) ? _transformY(y) : y) * k;
    final wVal = w * k;
    final hVal = ((_apiMode == ApiMode.compat) ? -h : h) * k;
    final rxVal = rx * k;
    final ryVal = ry * k;

    _doc.out('${_hpf(xVal + rxVal)} ${_hpf(yVal)} m');
    _doc.out('${_hpf(xVal + wVal - rxVal)} ${_hpf(yVal)} l');
    _doc.out(
      '${_hpf(xVal + wVal - rxVal + MyArc * rxVal)} ${_hpf(yVal)} '
      '${_hpf(xVal + wVal)} ${_hpf(yVal + ryVal - MyArc * ryVal)} '
      '${_hpf(xVal + wVal)} ${_hpf(yVal + ryVal)} c',
    );
    _doc.out('${_hpf(xVal + wVal)} ${_hpf(yVal + hVal - ryVal)} l');
    _doc.out(
      '${_hpf(xVal + wVal)} ${_hpf(yVal + hVal - ryVal + MyArc * ryVal)} '
      '${_hpf(xVal + wVal - rxVal + MyArc * rxVal)} ${_hpf(yVal + hVal)} '
      '${_hpf(xVal + wVal - rxVal)} ${_hpf(yVal + hVal)} c',
    );
    _doc.out('${_hpf(xVal + rxVal)} ${_hpf(yVal + hVal)} l');
    _doc.out(
      '${_hpf(xVal + rxVal - MyArc * rxVal)} ${_hpf(yVal + hVal)} '
      '${_hpf(xVal)} ${_hpf(yVal + hVal - ryVal + MyArc * ryVal)} '
      '${_hpf(xVal)} ${_hpf(yVal + hVal - ryVal)} c',
    );
    _doc.out('${_hpf(xVal)} ${_hpf(yVal + ryVal)} l');
    _doc.out(
      '${_hpf(xVal)} ${_hpf(yVal + ryVal - MyArc * ryVal)} '
      '${_hpf(xVal + rxVal - MyArc * rxVal)} ${_hpf(yVal)} '
      '${_hpf(xVal + rxVal)} ${_hpf(yVal)} c',
    );
    _doc.out(op);
    return this;
  }

  /// Desenha uma elipse.
  JsPdf ellipse(double x, double y, double rx, double ry, [String? style]) {
    final op = _getStyle(style);
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final lx = 4 / 3 * (math.sqrt(2) - 1) * rx * k;
    final ly = 4 / 3 * (math.sqrt(2) - 1) * ry * k;
    final xk = x * k;
    final yk =
        ((_apiMode == ApiMode.compat) ? _transformY(y) : y) * k;
    final rxk = rx * k;
    final ryk = ry * k;

    _doc.out('${_hpf(xk + rxk)} ${_hpf(yk)} m');
    _doc.out(
      '${_hpf(xk + rxk)} ${_hpf(yk - ly)} '
      '${_hpf(xk + lx)} ${_hpf(yk - ryk)} '
      '${_hpf(xk)} ${_hpf(yk - ryk)} c',
    );
    _doc.out(
      '${_hpf(xk - lx)} ${_hpf(yk - ryk)} '
      '${_hpf(xk - rxk)} ${_hpf(yk - ly)} '
      '${_hpf(xk - rxk)} ${_hpf(yk)} c',
    );
    _doc.out(
      '${_hpf(xk - rxk)} ${_hpf(yk + ly)} '
      '${_hpf(xk - lx)} ${_hpf(yk + ryk)} '
      '${_hpf(xk)} ${_hpf(yk + ryk)} c',
    );
    _doc.out(
      '${_hpf(xk + lx)} ${_hpf(yk + ryk)} '
      '${_hpf(xk + rxk)} ${_hpf(yk + ly)} '
      '${_hpf(xk + rxk)} ${_hpf(yk)} c',
    );
    _doc.out(op);
    return this;
  }

  /// Desenha um círculo.
  JsPdf circle(double x, double y, double r, [String? style]) {
    return ellipse(x, y, r, r, style);
  }

  /// Desenha um triângulo.
  JsPdf triangle(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3, [
    String? style,
  ]) {
    final op = _getStyle(style);
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final ty = _apiMode == ApiMode.compat
        ? (double y) => _transformY(y)
        : (double y) => y;

    _doc.out(
      '${_hpf(x1 * k)} ${_hpf(ty(y1) * k)} m '
      '${_hpf(x2 * k)} ${_hpf(ty(y2) * k)} l '
      '${_hpf(x3 * k)} ${_hpf(ty(y3) * k)} l h $op',
    );
    return this;
  }

  // ==========================================================================
  // Text
  // ==========================================================================

  /// Insere texto no PDF.
  ///
  /// [text] pode ser uma string ou lista de strings (multilinha).
  /// [x], [y] posição em unidades do documento.
  JsPdf text(dynamic text, double x, double y, {
    double? angle,
    String? align,
    double? maxWidth,
    double? lineHeightFactor,
  }) {
    final lines = text is List<String> ? text : [text.toString()];
    final k = _apiMode == ApiMode.compat ? _scaleFactor : 1.0;
    final fontSize = _activeFontSize;

    // Calcular posição
    var xPos = x * k;
    var yPos = (_apiMode == ApiMode.compat ? _transformY(y) : y) * k;

    final lhf = lineHeightFactor ?? _lineHeightFactor;
    final lineHeight = fontSize * lhf;

    // Alinhamento
    // (simplificado para o porte inicial)

    // Transformação por ângulo
    PdfMatrix? tm;
    if (angle != null && angle != 0) {
      final rad = angle * math.pi / 180;
      final c = math.cos(rad);
      final s = math.sin(rad);
      tm = PdfMatrix(c, s, -s, c, xPos, yPos);
    }

    _doc.out('BT');
    _doc.out(_textColor);

    if (tm != null) {
      _doc.out('${tm.toString()} Tm');
    } else {
      _doc.out('${_hpf(xPos)} ${_hpf(yPos)} Td');
    }

    _doc.out('/${_activeFontKey} ${f2(fontSize)} Tf');

    if (_charSpace != 0) {
      _doc.out('${_hpf(_charSpace)} Tc');
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final escapedLine = pdfEscape(line);

      if (i == 0) {
        _doc.out('($escapedLine) Tj');
      } else {
        _doc.out('0 ${_hpf(-lineHeight)} Td ($escapedLine) Tj');
      }
    }

    _doc.out('ET');
    return this;
  }

  // ==========================================================================
  // Page Management
  // ==========================================================================

  /// Adiciona uma nova página ao documento.
  JsPdf addPage([String? format, String? orientation]) {
    List<double> dimensions;
    if (format != null) {
      dimensions = getPageFormat(format) ?? getPageFormat('a4')!;
    } else {
      // Usa dimensões da página atual
      final ctx = _doc.pagesContext[_doc.currentPage]!;
      dimensions = [
        ctx.mediaBox.topRightX - ctx.mediaBox.bottomLeftX,
        ctx.mediaBox.topRightY - ctx.mediaBox.bottomLeftY,
      ];
    }

    final orientLower = (orientation ?? 'portrait').toLowerCase();
    final isLandscape = orientLower == 'l' || orientLower == 'landscape';

    double pageWidth, pageHeight;
    if (isLandscape) {
      pageWidth = math.max(dimensions[0], dimensions[1]);
      pageHeight = math.min(dimensions[0], dimensions[1]);
    } else {
      pageWidth = math.min(dimensions[0], dimensions[1]);
      pageHeight = math.max(dimensions[0], dimensions[1]);
    }

    _doc.addPage(
      MediaBox.fromDimensions(pageWidth, pageHeight),
      userUnit: _userUnit,
    );

    // Emitir estados gráficos padrão na nova página
    _doc.out('${_hpf(_lineWidth * _scaleFactor)} w');
    _doc.out(_drawColor);

    return this;
  }

  /// Define a página ativa por número (1-based).
  JsPdf setPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= _doc.numberOfPages) {
      _doc.setOutputDestination(_doc.pages[pageNumber]);
    }
    return this;
  }

  /// Retorna o número de páginas.
  int getNumberOfPages() => _doc.numberOfPages;

  /// Retorna largura da página atual (em unidades do documento).
  double getPageWidth([int? pageNumber]) {
    pageNumber ??= _doc.currentPage;
    final ctx = _doc.pagesContext[pageNumber]!;
    return (ctx.mediaBox.topRightX - ctx.mediaBox.bottomLeftX) / _scaleFactor;
  }

  /// Retorna altura da página atual (em unidades do documento).
  double getPageHeight([int? pageNumber]) {
    pageNumber ??= _doc.currentPage;
    final ctx = _doc.pagesContext[pageNumber]!;
    return (ctx.mediaBox.topRightY - ctx.mediaBox.bottomLeftY) / _scaleFactor;
  }

  // ==========================================================================
  // Document Properties
  // ==========================================================================

  /// Define propriedades do documento.
  JsPdf setDocumentProperties(Map<String, String> properties) {
    for (final entry in properties.entries) {
      if (_documentProperties.containsKey(entry.key)) {
        _documentProperties[entry.key] = entry.value;
      }
    }
    return this;
  }

  /// Alias para setDocumentProperties.
  JsPdf setProperties(Map<String, String> properties) =>
      setDocumentProperties(properties);

  /// Define zoom e layout de exibição.
  JsPdf setDisplayMode(dynamic zoom, [String? layout, String? pmode]) {
    if (zoom is String || zoom is int) {
      _zoomMode = zoom.toString();
    }
    if (layout != null) _layoutMode = layout;
    if (pmode != null) _pageMode = pmode;
    return this;
  }

  // ==========================================================================
  // Graphics State
  // ==========================================================================

  /// Salva o estado gráfico atual.
  JsPdf saveGraphicsState() {
    _doc.out('q');
    _graphicsStateStack.add({
      'textColor': _textColor,
      'drawColor': _drawColor,
      'fillColor': _fillColor,
      'lineWidth': _lineWidth,
      'activeFontKey': _activeFontKey,
      'activeFontSize': _activeFontSize,
    });
    return this;
  }

  /// Restaura o estado gráfico anterior.
  JsPdf restoreGraphicsState() {
    _doc.out('Q');
    if (_graphicsStateStack.isNotEmpty) {
      final state = _graphicsStateStack.removeLast();
      _textColor = state['textColor'] as String;
      _drawColor = state['drawColor'] as String;
      _fillColor = state['fillColor'] as String;
      _lineWidth = state['lineWidth'] as double;
      _activeFontKey = state['activeFontKey'] as String;
      _activeFontSize = state['activeFontSize'] as double;
    }
    return this;
  }

  // ==========================================================================
  // Output & Save
  // ==========================================================================

  /// Monta e retorna o documento PDF.
  ///
  /// [type] pode ser:
  /// - null/undefined: retorna raw string
  /// - 'arraybuffer': retorna ByteBuffer
  /// - 'blob': retorna Blob
  /// - 'bloburl'/'bloburi': retorna URL do blob
  /// - 'dataurlstring'/'datauristring': retorna data URI
  dynamic output([String? type]) {
    final pdfString = _buildDocument();

    switch (type) {
      case null:
        return pdfString;
      case 'arraybuffer':
        return _getArrayBuffer(pdfString);
      case 'blob':
        return _getBlob(pdfString);
      case 'bloburl':
      case 'bloburi':
        return Url.createObjectUrlFromBlob(_getBlob(pdfString));
      case 'datauristring':
      case 'dataurlstring':
        final encoded = base64.encode(utf8.encode(pdfString));
        return 'data:application/pdf;base64,$encoded';
      default:
        return pdfString;
    }
  }

  /// Salva o PDF fazendo download no browser.
  void save([String filename = 'generated.pdf']) {
    final blob = _getBlob(_buildDocument());
    final url = Url.createObjectUrlFromBlob(blob);

    final anchor = AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';

    document.body!.append(anchor);
    anchor.click();

    // Cleanup
    Future.delayed(const Duration(milliseconds: 500), () {
      anchor.remove();
      Url.revokeObjectUrl(url);
    });
  }

  // ==========================================================================
  // Internal Helpers
  // ==========================================================================

  double _transformY(double y) {
    if (_apiMode == ApiMode.compat) {
      return getPageHeight() - y;
    }
    return y;
  }


  String _buildDocument() {
    return _doc.buildDocument(
      fileId: _fileId,
      creationDate: _creationDate,
      documentProperties: _documentProperties,
      zoomMode: _zoomMode,
      layoutMode: _layoutMode,
      pageMode: _pageMode,
      putResourcesCallback: _putResources,
    );
  }

  void _putResources() {
    _putFonts();
    _doc.newObjectDeferredBegin(
      _doc.resourceDictionaryObjId,
      doOutput: true,
    );
    _doc.out('<<');
    _putResourceDictionary();
    _doc.out('>>');
    _doc.out('endobj');
  }

  void _putFonts() {
    for (final font in _fonts.values) {
      if (_putOnlyUsedFonts && !_usedFonts.containsKey(font.key)) {
        continue;
      }
      font.objectNumber = _doc.newObject();
      _doc.out('<<');
      _doc.out('/Type /Font');
      _doc.out('/BaseFont /${font.postScriptName}');
      _doc.out('/Subtype /Type1');
      if (font.encoding != null) {
        _doc.out('/Encoding /${font.encoding}');
      }
      _doc.out('>>');
      _doc.out('endobj');
    }
  }

  void _putResourceDictionary() {
    _doc.out('/ProcSet [/PDF /Text /ImageB /ImageC /ImageI]');

    // Fonts
    _doc.out('/Font <<');
    for (final font in _fonts.values) {
      if (_putOnlyUsedFonts && !_usedFonts.containsKey(font.key)) {
        continue;
      }
      _doc.out('/${font.key} ${font.objectNumber} 0 R');
    }
    _doc.out('>>');

    // XObjects (imagens, etc.) - placeholder
    _doc.out('/XObject <<');
    _doc.out('>>');
  }

  Blob _getBlob(String data) {
    final buffer = _getArrayBuffer(data);
    return Blob([buffer], 'application/pdf');
  }

  ByteBuffer _getArrayBuffer(String data) {
    final len = data.length;
    final ab = Uint8List(len);
    for (var i = 0; i < len; i++) {
      ab[i] = data.codeUnitAt(i) & 0xFF;
    }
    return ab.buffer;
  }

  // ==========================================================================
  // Internal API (para uso dos módulos/plugins)
  // ==========================================================================

  /// Acesso interno para os módulos.
  PdfDocumentBuilder get internal => _doc;
  PubSub get events => _events;
  double get scaleFactor => _scaleFactor;
  double get charSpace => _charSpace;
  String get textColor => _textColor;
  double get lineHeightFactor => _lineHeightFactor;
}
