import '../jspdf.dart';
import '../utils.dart';

/// Plugin de anotações PDF.
///
/// Suporta:
/// - Links para URLs
/// - Links para páginas internas
/// - Anotações de texto
/// - FreeText annotations
///
/// Portado de modules/annotations.js do jsPDF.

/// Tipo de anotação.
enum AnnotationType { link, text, freetext, reference }

/// Opções para criação de links.
class LinkOptions {
  /// URL de destino (para links externos).
  final String? url;

  /// Número da página de destino (para links internos).
  final int? pageNumber;

  /// Posição vertical no destino.
  final double? top;

  /// Posição horizontal no destino.
  final double? left;

  /// Fator de magnificação: 'XYZ', 'Fit', 'FitH', 'FitV'.
  final String magFactor;

  /// Zoom (para XYZ).
  final double zoom;

  /// Nome de destino nomeado.
  final String? name;

  const LinkOptions({
    this.url,
    this.pageNumber,
    this.top,
    this.left,
    this.magFactor = 'XYZ',
    this.zoom = 0,
    this.name,
  });
}

/// Limites de uma anotação na página.
class AnnotationBounds {
  final double x;
  final double y;
  final double w;
  final double h;

  const AnnotationBounds({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

/// Uma anotação PDF.
class PdfAnnotation {
  final AnnotationType type;
  final AnnotationBounds? bounds;
  final LinkOptions? options;
  final String? contents;
  final String? title;
  final String? color;
  final bool open;

  /// Limites finais já convertidos para coordenadas PDF.
  Map<String, String>? finalBounds;

  PdfAnnotation({
    required this.type,
    this.bounds,
    this.options,
    this.contents,
    this.title,
    this.color,
    this.open = false,
    this.finalBounds,
  });
}

/// Extensão do JsPdf para suporte a anotações.
extension JsPdfAnnotations on JsPdf {
  /// Cria um link na página atual.
  ///
  /// [x], [y], [w], [h] definem a área clicável.
  /// [options] define o destino do link.
  JsPdf link(double x, double y, double w, double h, LinkOptions options) {
    final k = scaleFactor;
    final pageHeight = getPageHeight();

    final annotation = PdfAnnotation(
      type: AnnotationType.link,
      options: options,
      finalBounds: {
        'x': _coordStr(x * k),
        'y': _coordStr((pageHeight - y) * k),
        'w': _coordStr((x + w) * k),
        'h': _coordStr((pageHeight - (y + h)) * k),
      },
    );

    _getAnnotations().add(<String, dynamic>{
      'type': 'link',
      'pdf': _annotationToPdf(annotation),
    });
    return this;
  }

  /// Escreve texto e cria uma área clicável com o mesmo tamanho aproximado.
  JsPdf textWithLink(
    String text,
    double x,
    double y,
    LinkOptions options,
  ) {
    this.text(text, x, y);
    return link(
        x, y - getFontSize(), getTextWidth(text), getFontSize(), options);
  }

  /// Retorna a largura do texto na unidade atual.
  double getTextWidth(String text) {
    final fontSize = getFontSize();
    return (getStringUnitWidth(text) * fontSize) / scaleFactor;
  }

  /// Largura unitária de uma string (proporcional ao tamanho da fonte).
  /// Simplificação: usa estimativa baseada na fonte padrão.
  double getStringUnitWidth(String text) {
    // Estimativa simplificada para fontes padrão
    // Em uma implementação completa, usaríamos métricas reais da fonte
    return text.length * 0.55;
  }

  String _coordStr(double value) {
    return f2(value);
  }

  String _annotationToPdf(PdfAnnotation annotation) {
    final bounds = annotation.finalBounds!;
    final options = annotation.options;
    final buffer = StringBuffer()
      ..write('<<')
      ..write('/Type /Annot ')
      ..write('/Subtype /Link ')
      ..write(
          '/Rect [${bounds['x']} ${bounds['y']} ${bounds['w']} ${bounds['h']}] ')
      ..write('/Border [0 0 0] ');

    if (options?.url != null) {
      buffer
        ..write('/A <<')
        ..write('/S /URI ')
        ..write('/URI (${pdfEscape(options!.url!)})')
        ..write('>>');
    } else if (options?.pageNumber != null) {
      final destinationPage = options!.pageNumber!.clamp(1, getNumberOfPages());
      final left = options.left == null
          ? 'null'
          : _coordStr(options.left! * scaleFactor);
      final top = options.top == null
          ? 'null'
          : _coordStr(
              (getPageHeight(destinationPage) - options.top!) * scaleFactor);
      buffer.write(
          '/Dest [$destinationPage 0 R /${options.magFactor} $left $top ${f2(options.zoom)}]');
    }

    buffer.write('>>');
    return buffer.toString();
  }

  /// Acesso às anotações da página atual (armazenadas internamente).
  List<Map<String, dynamic>> _getAnnotations() {
    return internal.pagesContext[internal.currentPage]!.annotations;
  }
}
