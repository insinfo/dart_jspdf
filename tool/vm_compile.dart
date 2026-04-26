import 'package:jspdf/jspdf.dart';

void main() {
  final pdf = JsPdf();
  pdf.text('VM compile check', 10, 10);
  final output = pdf.output() as String;
  if (!output.contains('%PDF-')) {
    throw StateError('PDF output was not generated');
  }
}
