import '../jspdf.dart';

/// Plugin para substituição do total de páginas.
///
/// Permite usar um placeholder (ex: '{total_pages}') que será
/// substituído pelo número real de páginas ao finalizar.
///
/// Portado de modules/total_pages.js do jsPDF.
///
/// Exemplo:
/// ```dart
/// final pdf = JsPdf();
/// pdf.text('Página 1 de {total}', 10, 10);
/// pdf.addPage();
/// pdf.text('Página 2 de {total}', 10, 10);
/// putTotalPages(pdf, '{total}');
/// pdf.save('test.pdf');
/// ```
void putTotalPages(JsPdf pdf, String pageExpression) {
  final totalNumberOfPages = pdf.getNumberOfPages();
  final replaceExpression = RegExp(RegExp.escape(pageExpression));

  for (var n = 1; n <= pdf.getNumberOfPages(); n++) {
    final page = pdf.internal.pages[n];
    for (var i = 0; i < page.length; i++) {
      page[i] = page[i].replaceAll(
        replaceExpression,
        totalNumberOfPages.toString(),
      );
    }
  }
}
