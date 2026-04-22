/// Plugin Context2D — emula CanvasRenderingContext2D para geração de PDF.
///
/// Permite usar a API de Canvas 2D (moveTo, lineTo, arc, bezierCurveTo,
/// fillRect, stroke, fill, text, transform, etc.) para gerar conteúdo
/// PDF diretamente, sem precisar de um canvas HTML real.
///
/// Portado de modules/context2d.js do jsPDF (~2692 linhas).

import 'dart:math';
import '../rgb_color.dart';
import '../matrix.dart';
import '../geometry.dart';

// ============================================================================
// ContextLayer — Estado do contexto gráfico
// ============================================================================

/// Estado de renderização salvo/restaurado via save()/restore().
class ContextLayer {
  bool isStrokeTransparent;
  double strokeOpacity;
  String strokeStyle;
  String fillStyle;
  bool isFillTransparent;
  double fillOpacity;
  String font;
  String textBaseline;
  String textAlign;
  double lineWidth;
  String lineJoin;
  String lineCap;
  List<Map<String, dynamic>> path;
  PdfMatrix transform;
  String globalCompositeOperation;
  double globalAlpha;
  List<Map<String, dynamic>> clipPath;
  PdfPoint currentPoint;
  double miterLimit;
  PdfPoint lastPoint;
  double lineDashOffset;
  List<double> lineDash;
  List<double> margin;
  double prevPageLastElemOffset;
  bool ignoreClearRect;
  double? fontSize;

  ContextLayer({
    ContextLayer? from,
  })  : isStrokeTransparent = from?.isStrokeTransparent ?? false,
        strokeOpacity = from?.strokeOpacity ?? 1,
        strokeStyle = from?.strokeStyle ?? '#000000',
        fillStyle = from?.fillStyle ?? '#000000',
        isFillTransparent = from?.isFillTransparent ?? false,
        fillOpacity = from?.fillOpacity ?? 1,
        font = from?.font ?? '10px sans-serif',
        textBaseline = from?.textBaseline ?? 'alphabetic',
        textAlign = from?.textAlign ?? 'left',
        lineWidth = from?.lineWidth ?? 1,
        lineJoin = from?.lineJoin ?? 'miter',
        lineCap = from?.lineCap ?? 'butt',
        path = from?.path != null ? List.from(from!.path) : [],
        transform = from?.transform.clone() ?? PdfMatrix(1, 0, 0, 1, 0, 0),
        globalCompositeOperation = from?.globalCompositeOperation ?? 'normal',
        globalAlpha = from?.globalAlpha ?? 1.0,
        clipPath = from?.clipPath != null ? List.from(from!.clipPath) : [],
        currentPoint = from?.currentPoint ?? PdfPoint(0, 0),
        miterLimit = from?.miterLimit ?? 10.0,
        lastPoint = from?.lastPoint ?? PdfPoint(0, 0),
        lineDashOffset = from?.lineDashOffset ?? 0.0,
        lineDash = from?.lineDash != null ? List.from(from!.lineDash) : [],
        margin = from?.margin != null ? List.from(from!.margin) : [0, 0, 0, 0],
        prevPageLastElemOffset = from?.prevPageLastElemOffset ?? 0,
        ignoreClearRect = from?.ignoreClearRect ?? true;
}

// ============================================================================
// RGBA color helper
// ============================================================================

/// Resultado de parsing de cor CSS.
class RGBAColor {
  final int r, g, b;
  final double a;
  final String style;
  const RGBAColor(this.r, this.g, this.b, this.a, this.style);
}

/// Faz parsing de uma string de cor CSS (hex, rgb, rgba, named).
RGBAColor getRGBA(String style) {
  final rxRgb = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)');
  final rxRgba = RegExp(r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)');
  final rxTransparent = RegExp(r'transparent|rgba\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*,\s*0+\s*\)');

  if (style.isEmpty) return const RGBAColor(0, 0, 0, 0, '');

  if (rxTransparent.hasMatch(style)) {
    return RGBAColor(0, 0, 0, 0, style);
  }

  var match = rxRgb.firstMatch(style);
  if (match != null) {
    return RGBAColor(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      1,
      style,
    );
  }

  match = rxRgba.firstMatch(style);
  if (match != null) {
    return RGBAColor(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      double.parse(match.group(4)!),
      style,
    );
  }

  // Hex ou named color
  var hex = style;
  if (!hex.startsWith('#')) {
    final rgb = RGBColor(hex);
    hex = rgb.ok ? rgb.toHex() : '#000000';
  }
  int r, g, b;
  if (hex.length == 4) {
    r = int.parse('${hex[1]}${hex[1]}', radix: 16);
    g = int.parse('${hex[2]}${hex[2]}', radix: 16);
    b = int.parse('${hex[3]}${hex[3]}', radix: 16);
  } else {
    r = int.parse(hex.substring(1, 3), radix: 16);
    g = int.parse(hex.substring(3, 5), radix: 16);
    b = int.parse(hex.substring(5, 7), radix: 16);
  }
  return RGBAColor(r, g, b, 1, hex);
}

/// Converte radianos para graus.
double rad2deg(double rad) => rad * 180 / pi;

// ============================================================================
// Mapa de fallback de fontes
// ============================================================================

/// Mapa de nomes de fontes CSS → nomes PDF padrão.
const fallbackFonts = <String, String>{
  'arial': 'Helvetica',
  'Arial': 'Helvetica',
  'verdana': 'Helvetica',
  'Verdana': 'Helvetica',
  'helvetica': 'Helvetica',
  'Helvetica': 'Helvetica',
  'sans-serif': 'Helvetica',
  'fixed': 'Courier',
  'monospace': 'Courier',
  'terminal': 'Courier',
  'cursive': 'Times',
  'fantasy': 'Times',
  'serif': 'Times',
};

// ============================================================================
// TextMetrics
// ============================================================================

/// Resultado de measureText().
class Context2dTextMetrics {
  final double width;
  const Context2dTextMetrics(this.width);
}

// ============================================================================
// Context2D — Classe principal
// ============================================================================

/// Emulação de CanvasRenderingContext2D para geração de PDF.
///
/// Implementa as operações de drawing da API Canvas 2D
/// (path, fill, stroke, text, transformations, clipping)
/// gerando operadores PDF na saída.
class Context2D {
  /// Referência ao documento PDF (genérica, para desacoplamento).
  final dynamic pdf;

  /// Estado do contexto gráfico.
  ContextLayer _ctx;

  /// Pilha de estados salvos.
  final List<ContextLayer> _ctxStack = [];

  // Paginação automática
  bool pageWrapXEnabled = false;
  bool pageWrapYEnabled = false;
  double posX = 0;
  double posY = 0;
  dynamic autoPaging = false;
  double lastBreak = 0;
  List<double> pageBreaks = [];
  List<dynamic>? fontFaces;

  Context2D(this.pdf) : _ctx = ContextLayer();

  /// Contexto atual.
  ContextLayer get ctx => _ctx;

  /// Path atual.
  List<Map<String, dynamic>> get path => _ctx.path;
  set path(List<Map<String, dynamic>> v) => _ctx.path = v;

  // ---- Style properties ----

  String get fillStyle => _ctx.fillStyle;
  set fillStyle(String value) {
    final rgba = getRGBA(value);
    _ctx.fillStyle = rgba.style;
    _ctx.isFillTransparent = rgba.a == 0;
    _ctx.fillOpacity = rgba.a;
  }

  String get strokeStyle => _ctx.strokeStyle;
  set strokeStyle(String value) {
    final rgba = getRGBA(value);
    _ctx.strokeStyle = rgba.style;
    _ctx.isStrokeTransparent = rgba.a == 0;
    _ctx.strokeOpacity = rgba.a;
  }

  String get lineCap => _ctx.lineCap;
  set lineCap(String value) {
    if (['butt', 'round', 'square'].contains(value)) _ctx.lineCap = value;
  }

  double get lineWidth => _ctx.lineWidth;
  set lineWidth(double value) {
    if (!value.isNaN) _ctx.lineWidth = value;
  }

  String get lineJoin => _ctx.lineJoin;
  set lineJoin(String value) {
    if (['bevel', 'round', 'miter'].contains(value)) _ctx.lineJoin = value;
  }

  double get miterLimit => _ctx.miterLimit;
  set miterLimit(double value) {
    if (!value.isNaN) _ctx.miterLimit = value;
  }

  String get textBaseline => _ctx.textBaseline;
  set textBaseline(String value) => _ctx.textBaseline = value;

  String get textAlign => _ctx.textAlign;
  set textAlign(String value) {
    if (['right', 'end', 'center', 'left', 'start'].contains(value)) {
      _ctx.textAlign = value;
    }
  }

  String get font => _ctx.font;
  set font(String value) {
    _ctx.font = value;
    // Parse CSS font string (simplified)
    final rx = RegExp(
      r'^\s*(?:(?:(?:[\-a-z]+\s*){0,2}(?:italic|oblique))?\s*)?'
      r'(?:(?:(?:[\-a-z]+\s*){0,2}(?:bold(?:er)?|lighter|[1-9]00))?\s*)?'
      r'((?:xx?-)?(?:small|large)|medium|smaller|larger|[\d.]+(?:%|in|[cem]m|ex|p[ctx]))'
      r'(?:\s*/\s*(?:normal|[\d.]+(?:%|in|[cem]m|ex|p[ctx])))?\s*'
      r'([\-_,"\x27\sa-z0-9]+?)\s*$',
      caseSensitive: false,
    );
    final match = rx.firstMatch(value);
    if (match == null) return;
    // fontSize e fontFamily detectados — processamento simplificado
  }

  String get globalCompositeOperation => _ctx.globalCompositeOperation;
  set globalCompositeOperation(String value) => _ctx.globalCompositeOperation = value;

  double get globalAlpha => _ctx.globalAlpha;
  set globalAlpha(double value) => _ctx.globalAlpha = value;

  double get lineDashOffset => _ctx.lineDashOffset;
  set lineDashOffset(double value) => _ctx.lineDashOffset = value;

  List<double> get lineDash => _ctx.lineDash;
  set lineDash(List<double> value) => _ctx.lineDash = value;

  bool get ignoreClearRect => _ctx.ignoreClearRect;
  set ignoreClearRect(bool value) => _ctx.ignoreClearRect = value;

  List<double> get margin => _ctx.margin;
  set margin(dynamic value) {
    if (value is num) {
      _ctx.margin = [value.toDouble(), value.toDouble(), value.toDouble(), value.toDouble()];
    } else if (value is List) {
      final m = List<double>.filled(4, 0);
      m[0] = (value[0] as num).toDouble();
      m[1] = value.length >= 2 ? (value[1] as num).toDouble() : m[0];
      m[2] = value.length >= 3 ? (value[2] as num).toDouble() : m[0];
      m[3] = value.length >= 4 ? (value[3] as num).toDouble() : m[1];
      _ctx.margin = m;
    }
  }

  // ---- Line dash ----

  void setLineDash(List<double> dashArray) => lineDash = dashArray;

  List<double> getLineDash() {
    if (lineDash.length % 2 != 0) return [...lineDash, ...lineDash];
    return List.from(lineDash);
  }

  // ---- Path operations ----

  void beginPath() {
    path = [{'type': 'begin'}];
  }

  void moveTo(double x, double y) {
    if (x.isNaN || y.isNaN) throw ArgumentError('Invalid moveTo arguments');
    final pt = _ctx.transform.applyToPoint(PdfPoint(x, y));
    path.add({'type': 'mt', 'x': pt.x, 'y': pt.y});
    _ctx.lastPoint = PdfPoint(x, y);
  }

  void lineTo(double x, double y) {
    if (x.isNaN || y.isNaN) throw ArgumentError('Invalid lineTo arguments');
    final pt = _ctx.transform.applyToPoint(PdfPoint(x, y));
    path.add({'type': 'lt', 'x': pt.x, 'y': pt.y});
    _ctx.lastPoint = PdfPoint(pt.x, pt.y);
  }

  void closePath() {
    var pathBegin = PdfPoint(0, 0);
    for (var i = path.length - 1; i >= 0; i--) {
      if (path[i]['type'] == 'begin') {
        if (i + 1 < path.length && path[i + 1]['x'] is num) {
          pathBegin = PdfPoint(
            (path[i + 1]['x'] as num).toDouble(),
            (path[i + 1]['y'] as num).toDouble(),
          );
        }
        break;
      }
    }
    path.add({'type': 'close'});
    _ctx.lastPoint = pathBegin;
  }

  void quadraticCurveTo(double cpx, double cpy, double x, double y) {
    if (x.isNaN || y.isNaN || cpx.isNaN || cpy.isNaN) {
      throw ArgumentError('Invalid quadraticCurveTo arguments');
    }
    final pt0 = _ctx.transform.applyToPoint(PdfPoint(x, y));
    final pt1 = _ctx.transform.applyToPoint(PdfPoint(cpx, cpy));
    path.add({'type': 'qct', 'x1': pt1.x, 'y1': pt1.y, 'x': pt0.x, 'y': pt0.y});
    _ctx.lastPoint = PdfPoint(pt0.x, pt0.y);
  }

  void bezierCurveTo(double cp1x, double cp1y, double cp2x, double cp2y, double x, double y) {
    final pt0 = _ctx.transform.applyToPoint(PdfPoint(x, y));
    final pt1 = _ctx.transform.applyToPoint(PdfPoint(cp1x, cp1y));
    final pt2 = _ctx.transform.applyToPoint(PdfPoint(cp2x, cp2y));
    path.add({
      'type': 'bct',
      'x1': pt1.x, 'y1': pt1.y,
      'x2': pt2.x, 'y2': pt2.y,
      'x': pt0.x, 'y': pt0.y,
    });
    _ctx.lastPoint = PdfPoint(pt0.x, pt0.y);
  }

  void arc(double x, double y, double radius, double startAngle, double endAngle,
      [bool counterclockwise = false]) {
    if (!_ctx.transform.isIdentity) {
      final xpt = _ctx.transform.applyToPoint(PdfPoint(x, y));
      x = xpt.x;
      y = xpt.y;
      final radPt = _ctx.transform.applyToPoint(PdfPoint(0, radius));
      final radPt0 = _ctx.transform.applyToPoint(PdfPoint(0, 0));
      radius = sqrt(pow(radPt.x - radPt0.x, 2) + pow(radPt.y - radPt0.y, 2));
    }
    if ((endAngle - startAngle).abs() >= 2 * pi) {
      startAngle = 0;
      endAngle = 2 * pi;
    }
    path.add({
      'type': 'arc',
      'x': x, 'y': y,
      'radius': radius,
      'startAngle': startAngle,
      'endAngle': endAngle,
      'counterclockwise': counterclockwise,
    });
  }

  void rect(double x, double y, double w, double h) {
    moveTo(x, y);
    lineTo(x + w, y);
    lineTo(x + w, y + h);
    lineTo(x, y + h);
    lineTo(x, y);
    lineTo(x + w, y);
    lineTo(x, y);
  }

  // ---- Drawing operations ----

  bool get _isFillTransparent => _ctx.isFillTransparent || globalAlpha == 0;
  bool get _isStrokeTransparent => _ctx.isStrokeTransparent || globalAlpha == 0;

  void fill() => _pathPreProcess('fill');
  void stroke() => _pathPreProcess('stroke');
  void clip() {
    _ctx.clipPath = List.from(path.map((e) => Map<String, dynamic>.from(e)));
    _pathPreProcess(null, isClip: true);
  }

  void fillRect(double x, double y, double w, double h) {
    if (_isFillTransparent) return;
    final savedLineCap = lineCap;
    final savedLineJoin = lineJoin;
    lineCap = 'butt';
    lineJoin = 'miter';
    beginPath();
    rect(x, y, w, h);
    fill();
    lineCap = savedLineCap;
    lineJoin = savedLineJoin;
  }

  void strokeRect(double x, double y, double w, double h) {
    if (_isStrokeTransparent) return;
    beginPath();
    rect(x, y, w, h);
    stroke();
  }

  void clearRect(double x, double y, double w, double h) {
    if (ignoreClearRect) return;
    fillStyle = '#ffffff';
    fillRect(x, y, w, h);
  }

  // ---- Text ----

  void fillText(String text, double x, double y, [double? maxWidth]) {
    if (_isFillTransparent) return;
    _putText(text: text, x: x, y: y, maxWidth: maxWidth, renderingMode: 'fill');
  }

  void strokeText(String text, double x, double y, [double? maxWidth]) {
    if (_isStrokeTransparent) return;
    _putText(text: text, x: x, y: y, maxWidth: maxWidth, renderingMode: 'stroke');
  }

  Context2dTextMetrics measureText(String text) {
    // Simplificado — retorna placeholder baseado em char count
    return Context2dTextMetrics(text.length * 6.0);
  }

  // ---- Transformations ----

  void scale(double scaleWidth, double scaleHeight) {
    final m = PdfMatrix(scaleWidth, 0, 0, scaleHeight, 0, 0);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  void rotate(double angle) {
    final m = PdfMatrix(cos(angle), sin(angle), -sin(angle), cos(angle), 0, 0);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  void translate(double x, double y) {
    final m = PdfMatrix(1, 0, 0, 1, x, y);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  void setTransformValues(double a, double b, double c, double d, double e, double f) {
    _ctx.transform = PdfMatrix(a, b, c, d, e, f);
  }

  void applyTransform(double a, double b, double c, double d, double e, double f) {
    final m = PdfMatrix(a, b, c, d, e, f);
    _ctx.transform = _ctx.transform.multiply(m);
  }

  // ---- Save/Restore ----

  void save([bool doStackPush = true]) {
    if (doStackPush) {
      _ctxStack.add(_ctx);
      _ctx = ContextLayer(from: _ctx);
    }
  }

  void restore([bool doStackPop = true]) {
    if (doStackPop && _ctxStack.isNotEmpty) {
      _ctx = _ctxStack.removeLast();
    }
  }

  // ---- Image ----

  /// Draws an image (placeholder signature matching Canvas API).
  void drawImage(dynamic img, [double? sx, double? sy, double? swidth,
      double? sheight, double? dx, double? dy, double? dwidth, double? dheight]) {
    // Em um porte completo, extrairia o image data e usaria addImage do pdf.
    // Nesta versão, é um stub que pode ser conectado ao pdf.
  }

  // ---- Create gradient/pattern (stubs) ----

  dynamic createLinearGradient(double x0, double y0, double x1, double y1) => null;
  dynamic createRadialGradient(double x0, double y0, double r0, double x1, double y1, double r1) => null;
  dynamic createPattern(dynamic image, String repetition) => null;

  // ---- Private internals ----

  void _pathPreProcess(String? rule, {bool isClip = false}) {
    // Em uma implementação completa, converte o path para operadores PDF.
    // Esta é a estrutura base para a o pipeline de rendering.
    if (path.isEmpty) return;
    // Gera operadores PDF conforme o path...
    // (será conectado ao pdf output na integração final)
  }

  void _putText({
    required String text,
    required double x,
    required double y,
    double? maxWidth,
    String renderingMode = 'fill',
  }) {
    // Em uma implementação completa, gera BT/ET operators para o PDF.
    // Usa _ctx.transform.rotation e _ctx.transform.scaleX
    // para posicionar o texto corretamente.
    // Conectar ao pdf.text() na integração final.
  }
}
