/// Plugin HTML — renderiza HTML para PDF.
///
/// Na versão JS original, este módulo usa html2canvas para
/// renderizar DOM para canvas, e então para PDF. No Dart,
/// fornecemos a estrutura do Worker e os métodos de conversão,
/// prontos para integração com uma lib de renderização HTML.
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
    );
  }
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
}
