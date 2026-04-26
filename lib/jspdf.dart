/// jsPDF para Dart — Gerador de PDF no navegador.
///
/// Porte completo do jsPDF (JavaScript) para Dart
///
/// Exemplo de uso:
/// ```dart
/// import 'package:jspdf/jspdf.dart';
///
/// void main() {
///   final pdf = JsPdf();
///   pdf.text('Hello World!', 10, 10);
///   pdf.save('test.pdf');
/// }
/// ```
library jspdf;

// Core
export 'src/jspdf.dart';
export 'src/matrix.dart';
export 'src/geometry.dart';
export 'src/gstate.dart';
export 'src/pattern.dart';
export 'src/page_formats.dart';
export 'src/fonts.dart';
export 'src/color.dart';
export 'src/rgb_color.dart';
export 'src/utils.dart';
export 'src/pubsub.dart';
export 'src/pdf_document.dart';
export 'src/pdf_security.dart';

// Modules
export 'src/modules/total_pages.dart';
export 'src/modules/annotations.dart';
export 'src/modules/split_text_to_size.dart';
export 'src/modules/addimage.dart';
export 'src/modules/autoprint.dart';
export 'src/modules/standard_fonts_metrics.dart';
export 'src/modules/outline.dart';
export 'src/modules/viewerpreferences.dart';
export 'src/modules/jpeg_support.dart';
export 'src/modules/cell.dart';
export 'src/modules/utf8.dart';
export 'src/modules/png_support.dart';
export 'src/modules/context2d.dart';
export 'src/modules/html.dart';
export 'src/modules/setlanguage.dart';

// Libs
export 'src/pdfname.dart';
export 'src/libs/ttffont.dart';
export 'src/libs/fast_png.dart';
export 'src/libs/zlib_codec.dart';
