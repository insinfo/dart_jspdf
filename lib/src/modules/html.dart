/// Plugin HTML — renderiza HTML para PDF.
///
/// Na versão JS original, este módulo usa html2canvas para renderizar DOM para
/// canvas. Neste porte, para cumprir a regra de zero dependências externas e
/// compatibilidade Web/VM, o módulo implementa uma renderização textual HTML em
/// Dart puro: tags de bloco, títulos, listas, quebras de linha e entidades.
///
/// Portado de modules/html.js do jsPDF (~1094 linhas).

/// Opções de configuração para renderização HTML → PDF.
class HtmlToPdfOptions {
  /// Nome do arquivo PDF.
  final String filename;

  /// Margem [top, right, bottom, left] em unidades do PDF.
  final List<double> margin;

  /// Habilitar extração de links.
  final bool enableLinks;

  /// Posição X inicial.
  final double x;

  /// Posição Y inicial.
  final double y;

  /// Cor de fundo.
  final String backgroundColor;

  /// Tipo de imagem para conversão intermediária.
  final String imageType;

  /// Qualidade da imagem (0.0 – 1.0).
  final double imageQuality;

  /// Auto paginação (false, true/'slice', 'text').
  final dynamic autoPaging;

  /// Largura customizada em pontos.
  final double? width;

  /// Largura da janela virtual para renderização.
  final double? windowWidth;

  /// Callback após renderização.
  final void Function(dynamic pdf)? callback;

  /// Tamanho de fonte base para texto comum.
  final double fontSize;

  /// Fator de altura de linha.
  final double lineHeightFactor;

  const HtmlToPdfOptions({
    this.filename = 'file.pdf',
    this.margin = const [0, 0, 0, 0],
    this.enableLinks = true,
    this.x = 0,
    this.y = 0,
    this.backgroundColor = 'transparent',
    this.imageType = 'jpeg',
    this.imageQuality = 0.95,
    this.autoPaging = true,
    this.width,
    this.windowWidth,
    this.callback,
    this.fontSize = 12,
    this.lineHeightFactor = 1.2,
  });

  /// Cria uma nova instância com margem normalizada.
  HtmlToPdfOptions withNormalizedMargin() {
    List<double> m;
    if (margin.length == 1) {
      m = [margin[0], margin[0], margin[0], margin[0]];
    } else if (margin.length == 2) {
      m = [margin[0], margin[1], margin[0], margin[1]];
    } else if (margin.length >= 4) {
      m = margin.sublist(0, 4);
    } else {
      m = [0, 0, 0, 0];
    }
    return HtmlToPdfOptions(
      filename: filename,
      margin: m,
      enableLinks: enableLinks,
      x: x,
      y: y,
      backgroundColor: backgroundColor,
      imageType: imageType,
      imageQuality: imageQuality,
      autoPaging: autoPaging,
      width: width,
      windowWidth: windowWidth,
      callback: callback,
      fontSize: fontSize,
      lineHeightFactor: lineHeightFactor,
    );
  }
}

/// Linha textual extraída do HTML.
class HtmlTextLine {
  final String text;
  final double fontSize;
  final double spacingBefore;
  final double spacingAfter;
  final double indent;

  const HtmlTextLine({
    required this.text,
    required this.fontSize,
    this.spacingBefore = 0,
    this.spacingAfter = 0,
    this.indent = 0,
  });
}

/// Tamanho de página com margens.
class PageSize {
  final double width;
  final double height;
  final double k;
  final PageSizeInner inner;

  const PageSize({
    required this.width,
    required this.height,
    required this.k,
    required this.inner,
  });
}

/// Dimensões internas (sem margem).
class PageSizeInner {
  final double width;
  final double height;
  final double pxWidth;
  final double pxHeight;
  final double ratio;

  const PageSizeInner({
    required this.width,
    required this.height,
    required this.pxWidth,
    required this.pxHeight,
    required this.ratio,
  });
}

/// Calcula o tamanho interno de uma página dados [width], [height],
/// o fator de escala [k] e as [margin] (TRBL).
PageSize calculatePageSize({
  required double width,
  required double height,
  required double k,
  required List<double> margin,
}) {
  final innerW = width - margin[1] - margin[3];
  final innerH = height - margin[0] - margin[2];
  final pxW = (innerW * k / 72 * 96).floor().toDouble();
  final pxH = (innerH * k / 72 * 96).floor().toDouble();

  return PageSize(
    width: width,
    height: height,
    k: k,
    inner: PageSizeInner(
      width: innerW,
      height: innerH,
      pxWidth: pxW,
      pxHeight: pxH,
      ratio: innerH / innerW,
    ),
  );
}

/// Estado do Worker de renderização HTML → PDF.
///
/// Gerencia o pipeline:
/// source (HTML/element) → container → canvas → image → PDF.
class HtmlWorkerState {
  /// Opções de renderização.
  HtmlToPdfOptions options;

  /// Tamanho da página.
  PageSize? pageSize;

  /// Progresso (0.0 – 1.0).
  double progress = 0;

  /// Estado atual do pipeline.
  String state = 'idle';

  /// Fonte HTML recebida pelo worker.
  String? sourceHtml;

  /// Linhas extraídas da fonte HTML.
  List<HtmlTextLine> lines = const <HtmlTextLine>[];

  HtmlWorkerState({
    HtmlToPdfOptions? options,
  }) : options = options ?? const HtmlToPdfOptions();

  /// Atualiza o progresso.
  void updateProgress(double val, [String? newState]) {
    progress += val;
    if (newState != null) state = newState;
  }
}

/// Pipeline de renderização HTML → PDF.
///
/// Exemplo de uso:
/// ```dart
/// final worker = HtmlWorker(pdf: myPdf);
/// // Configurar opções
/// worker.state.options = HtmlToPdfOptions(
///   margin: [10, 10, 10, 10],
///   filename: 'output.pdf',
/// );
/// // Calcular page size
/// worker.setPageSize(pageWidth: 595.28, pageHeight: 841.89, k: 1.0);
/// ```
class HtmlWorker {
  /// Referência ao documento PDF.
  final dynamic pdf;

  /// Estado do worker.
  final HtmlWorkerState state;

  HtmlWorker({required this.pdf}) : state = HtmlWorkerState();

  /// Define opções do worker.
  HtmlWorker set(HtmlToPdfOptions options) {
    state.options = options.withNormalizedMargin();
    return this;
  }

  /// Define a origem HTML. Elementos DOM não são aceitos neste porte porque a
  /// biblioteca precisa compilar também na Dart VM.
  HtmlWorker from(dynamic source) {
    if (source is! String) {
      throw ArgumentError.value(source, 'source', 'Expected an HTML string.');
    }
    state.sourceHtml = source;
    state.updateProgress(0.2, 'source');
    return this;
  }

  /// Define o tamanho da página.
  void setPageSize({
    required double pageWidth,
    required double pageHeight,
    required double k,
  }) {
    state.pageSize = calculatePageSize(
      width: pageWidth,
      height: pageHeight,
      k: k,
      margin: state.options.margin,
    );
  }

  /// Verifica se há margens configuradas.
  bool get hasMargins {
    final m = state.options.margin;
    return m[0] > 0 || m[1] > 0 || m[2] > 0 || m[3] > 0;
  }

  /// Calcula a escala para a conversão.
  double calculateScale() {
    final opt = state.options;
    if (opt.width != null && opt.windowWidth != null) {
      return opt.width! / opt.windowWidth!;
    }
    return 1.0;
  }

  /// Converte a origem HTML para linhas textuais renderizáveis.
  List<HtmlTextLine> toTextLines() {
    final source = state.sourceHtml;
    if (source == null) {
      throw StateError('Cannot render HTML before calling from().');
    }
    state.lines =
        parseHtmlTextLines(source, baseFontSize: state.options.fontSize);
    state.updateProgress(0.3, 'text');
    return state.lines;
  }

  /// Renderiza a origem HTML no PDF usando texto e paginação básica.
  dynamic toPdf() {
    final lines = state.lines.isEmpty ? toTextLines() : state.lines;
    final options = state.options.withNormalizedMargin();
    state.options = options;

    final double pageWidth =
        _callPdfNumber('getPageWidth', fallback: options.width ?? 595.28);
    final double pageHeight = _callPdfNumber('getPageHeight', fallback: 841.89);
    final PageSize pageSize = state.pageSize ??
        calculatePageSize(
            width: pageWidth, height: pageHeight, k: 1, margin: options.margin);
    state.pageSize = pageSize;

    final double usableWidth = options.width ?? pageSize.inner.width;
    final double left = options.x + options.margin[3];
    final double top = options.y + options.margin[0];
    final double bottom = pageHeight - options.margin[2];
    double cursorY = top;

    for (final line in lines) {
      cursorY += line.spacingBefore;
      final wrapped = wrapHtmlTextLine(line, usableWidth);
      for (final wrappedLine in wrapped) {
        final double lineHeight =
            wrappedLine.fontSize * options.lineHeightFactor;
        if (options.autoPaging != false && cursorY + lineHeight > bottom) {
          _callPdf('addPage', const <dynamic>[]);
          cursorY = top;
        }
        _callPdf('setFontSize', <dynamic>[wrappedLine.fontSize]);
        _callPdf('text',
            <dynamic>[wrappedLine.text, left + wrappedLine.indent, cursorY]);
        cursorY += lineHeight;
      }
      cursorY += line.spacingAfter;
    }

    state.updateProgress(0.5, 'pdf');
    options.callback?.call(pdf);
    return pdf;
  }

  /// Executa o fluxo completo: from() deve ter sido chamado antes.
  dynamic save() {
    toPdf();
    return _callPdf('save', <dynamic>[state.options.filename]);
  }

  dynamic _callPdf(String method, List<dynamic> positional) {
    try {
      switch (method) {
        case 'addPage':
          return Function.apply(pdf.addPage, positional);
        case 'setFontSize':
          return Function.apply(pdf.setFontSize, positional);
        case 'text':
          return Function.apply(pdf.text, positional);
        case 'save':
          return Function.apply(pdf.save, positional);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  double _callPdfNumber(String method, {required double fallback}) {
    try {
      dynamic result;
      switch (method) {
        case 'getPageWidth':
          result = Function.apply(pdf.getPageWidth, const <dynamic>[]);
          break;
        case 'getPageHeight':
          result = Function.apply(pdf.getPageHeight, const <dynamic>[]);
          break;
      }
      if (result is num) return result.toDouble();
    } catch (_) {
      return fallback;
    }
    return fallback;
  }
}

/// API direta semelhante ao plugin JS: renderiza [source] no [pdf].
dynamic html(dynamic pdf, String source,
    {HtmlToPdfOptions options = const HtmlToPdfOptions()}) {
  return HtmlWorker(pdf: pdf).set(options).from(source).toPdf();
}

/// Extrai linhas textuais de um HTML simples sem usar DOM.
List<HtmlTextLine> parseHtmlTextLines(String html, {double baseFontSize = 12}) {
  final String sanitized = html
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(
          RegExp(r'<script\b[^>]*>.*?</script>',
              caseSensitive: false, dotAll: true),
          '')
      .replaceAll(
          RegExp(r'<style\b[^>]*>.*?</style>',
              caseSensitive: false, dotAll: true),
          '');

  final List<HtmlTextLine> lines = <HtmlTextLine>[];
  final StringBuffer buffer = StringBuffer();
  final List<_ListContext> lists = <_ListContext>[];
  double currentFontSize = baseFontSize;
  double spacingBefore = 0;
  double spacingAfter = 0;
  double currentIndent = 0;

  void flush() {
    final text = _normalizeWhitespace(buffer.toString());
    buffer.clear();
    if (text.isEmpty) return;
    lines.add(HtmlTextLine(
      text: text,
      fontSize: currentFontSize,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
      indent: currentIndent,
    ));
    currentFontSize = baseFontSize;
    spacingBefore = 0;
    spacingAfter = 0;
    currentIndent = lists.length * 12.0;
  }

  final tokenRegex = RegExp(r'<[^>]+>|[^<]+', dotAll: true);
  for (final match in tokenRegex.allMatches(sanitized)) {
    final token = match.group(0)!;
    if (token.startsWith('<')) {
      final tag = _tagName(token);
      final closing = RegExp(r'^\s*</').hasMatch(token);
      final selfClosing = token.endsWith('/>');

      if (!closing) {
        if (_blockTags.contains(tag)) {
          flush();
          currentFontSize = _fontSizeForTag(tag, baseFontSize);
          spacingBefore = _spacingBeforeForTag(tag, baseFontSize);
          spacingAfter = _spacingAfterForTag(tag, baseFontSize);
        } else if (tag == 'br') {
          flush();
        } else if (tag == 'ul') {
          flush();
          lists.add(_ListContext(ordered: false));
          currentIndent = lists.length * 12.0;
        } else if (tag == 'ol') {
          flush();
          lists.add(_ListContext(ordered: true));
          currentIndent = lists.length * 12.0;
        } else if (tag == 'li') {
          flush();
          final list =
              lists.isNotEmpty ? lists.last : _ListContext(ordered: false);
          final prefix = list.ordered ? '${++list.index}. ' : '- ';
          buffer.write(prefix);
          currentIndent = lists.length * 12.0;
        }
        if (selfClosing && _blockTags.contains(tag)) flush();
      } else {
        if (_blockTags.contains(tag) || tag == 'li') {
          flush();
        } else if ((tag == 'ul' || tag == 'ol') && lists.isNotEmpty) {
          flush();
          lists.removeLast();
          currentIndent = lists.length * 12.0;
        }
      }
      continue;
    }

    final text = decodeHtmlEntities(token);
    if (text.trim().isEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
    } else {
      buffer.write(text);
    }
  }
  flush();
  return lines;
}

/// Quebra uma linha extraída do HTML em linhas menores usando largura estimada.
List<HtmlTextLine> wrapHtmlTextLine(HtmlTextLine line, double maxWidth) {
  final double avgCharWidth = line.fontSize * 0.5;
  final int maxChars = (maxWidth / avgCharWidth).floor().clamp(1, 1000000);
  if (line.text.length <= maxChars) return <HtmlTextLine>[line];

  final List<HtmlTextLine> wrapped = <HtmlTextLine>[];
  final words = line.text.split(RegExp(r'\s+'));
  final StringBuffer current = StringBuffer();
  for (final word in words) {
    final nextLength =
        current.isEmpty ? word.length : current.length + 1 + word.length;
    if (nextLength > maxChars && current.isNotEmpty) {
      wrapped.add(HtmlTextLine(
          text: current.toString(),
          fontSize: line.fontSize,
          indent: line.indent));
      current.clear();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(word);
  }
  if (current.isNotEmpty) {
    wrapped.add(HtmlTextLine(
        text: current.toString(),
        fontSize: line.fontSize,
        indent: line.indent));
  }
  if (wrapped.isNotEmpty) {
    wrapped[0] = HtmlTextLine(
      text: wrapped[0].text,
      fontSize: wrapped[0].fontSize,
      spacingBefore: line.spacingBefore,
      indent: wrapped[0].indent,
    );
    final last = wrapped.length - 1;
    wrapped[last] = HtmlTextLine(
      text: wrapped[last].text,
      fontSize: wrapped[last].fontSize,
      spacingAfter: line.spacingAfter,
      indent: wrapped[last].indent,
    );
  }
  return wrapped;
}

String decodeHtmlEntities(String value) {
  return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
      (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      return String.fromCharCode(int.parse(entity.substring(2), radix: 16));
    }
    if (entity.startsWith('#')) {
      return String.fromCharCode(int.parse(entity.substring(1)));
    }
    return _namedEntities[entity] ?? match.group(0)!;
  });
}

const Set<String> _blockTags = <String>{
  'address',
  'article',
  'aside',
  'blockquote',
  'div',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'main',
  'p',
  'pre',
  'section',
  'table',
  'tr',
};

const Map<String, String> _namedEntities = <String, String>{
  'amp': '&',
  'apos': "'",
  'gt': '>',
  'lt': '<',
  'nbsp': ' ',
  'quot': '"',
};

String _tagName(String tag) {
  final match = RegExp(r'^\s*</?\s*([a-zA-Z0-9]+)').firstMatch(tag);
  return match?.group(1)?.toLowerCase() ?? '';
}

String _normalizeWhitespace(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();

double _fontSizeForTag(String tag, double base) {
  switch (tag) {
    case 'h1':
      return base * 2.0;
    case 'h2':
      return base * 1.5;
    case 'h3':
      return base * 1.25;
    case 'h4':
      return base * 1.1;
    case 'h5':
      return base;
    case 'h6':
      return base * 0.9;
    default:
      return base;
  }
}

double _spacingBeforeForTag(String tag, double base) =>
    tag.startsWith('h') ? base * 0.4 : 0;

double _spacingAfterForTag(String tag, double base) {
  if (tag.startsWith('h')) return base * 0.3;
  if (tag == 'p' || tag == 'blockquote') return base * 0.4;
  return 0;
}

class _ListContext {
  final bool ordered;
  int index = 0;

  _ListContext({required this.ordered});
}
