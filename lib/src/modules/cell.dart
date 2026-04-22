import '../utils.dart';

/// Plugin de tabelas (cell) para PDF.
///
/// Permite criar tabelas com cabeçalhos, linhas, alinhamento
/// e auto-quebra de página.
///
/// Portado de modules/cell.js do jsPDF.

/// Alinhamento de texto em uma célula.
enum CellAlign { left, center, right, justify }

/// Margem de uma célula (esquerda, topo).
class CellMargin {
  final double left;
  final double top;
  const CellMargin({this.left = 0, this.top = 0});
}

/// Definição de uma coluna para tabelas.
class TableColumn {
  /// Nome/chave da coluna.
  final String name;

  /// Texto exibido no cabeçalho.
  final String prompt;

  /// Largura da coluna.
  final double width;

  /// Alinhamento do texto (opcional).
  final CellAlign align;

  /// Padding interno.
  final double padding;

  const TableColumn({
    required this.name,
    required this.prompt,
    required this.width,
    this.align = CellAlign.left,
    this.padding = 3,
  });
}

/// Configuração de uma tabela.
class TableConfig {
  /// Largura das linhas de borda.
  final double lineWidth;

  /// Tamanho da fonte do cabeçalho.
  final double headerFontSize;

  /// Tamanho da fonte do corpo.
  final double fontSize;

  /// Margem da tabela.
  final CellMargin margin;

  /// Se o cabeçalho deve ser desenhado na primeira linha.
  final bool printHeaders;

  /// Se deve usar auto quebra de página.
  final bool autoSize;

  /// Padding vertical interno dos cells.
  final double padding;

  /// Cor de fundo do cabeçalho (hex).
  final String? headerBackColor;

  /// Cor de fundo das linhas alternadas.
  final String? alternateRowColor;

  const TableConfig({
    this.lineWidth = 0.1,
    this.headerFontSize = 12,
    this.fontSize = 10,
    this.margin = const CellMargin(),
    this.printHeaders = true,
    this.autoSize = true,
    this.padding = 3,
    this.headerBackColor,
    this.alternateRowColor,
  });
}

/// Extensão para desenho de células individuais e tabelas.
///
/// Funciona com a classe JsPdf principal via métodos internos.
/// Exemplo de uso com dados de mapa:
/// ```dart
/// final headers = [
///   TableColumn(name: 'id', prompt: 'ID', width: 40),
///   TableColumn(name: 'name', prompt: 'Name', width: 120),
/// ];
/// final data = [
///   {'id': '1', 'name': 'Alice'},
///   {'id': '2', 'name': 'Bob'},
/// ];
/// drawTable(pdf, headers, data, config: TableConfig());
/// ```

/// Calcula a altura necessária para renderizar texto em multilinha.
double calculateLineHeight(
  String text,
  double columnWidth,
  double fontSize,
) {
  final charWidth = fontSize * 0.55; // Estimativa média
  final maxCharsPerLine = (columnWidth / charWidth).floor();
  if (maxCharsPerLine <= 0) return fontSize * 1.5;

  final lines = (text.length / maxCharsPerLine).ceil();
  return lines * fontSize * 1.5;
}

/// Calcula a altura de uma linha da tabela (maior célula).
double calculateRowHeight(
  List<TableColumn> columns,
  Map<String, String> rowData,
  double fontSize,
) {
  var maxHeight = fontSize * 1.5;

  for (final col in columns) {
    final text = rowData[col.name] ?? '';
    final cellHeight = calculateLineHeight(
      text,
      col.width - col.padding * 2,
      fontSize,
    );
    if (cellHeight > maxHeight) {
      maxHeight = cellHeight;
    }
  }

  return maxHeight;
}

/// Gera os operadores PDF para uma célula.
///
/// Retorna uma lista de strings de conteúdo PDF para uma célula.
List<String> cellToPdf({
  required double x,
  required double y,
  required double width,
  required double height,
  required String text,
  CellAlign align = CellAlign.left,
  double padding = 3,
  bool drawBorder = true,
  double lineWidth = 0.1,
}) {
  final ops = <String>[];

  // Borda
  if (drawBorder) {
    ops.add('${_f(lineWidth)} w');
    ops.add('${_f(x)} ${_f(y)} ${_f(width)} ${_f(-height)} re S');
  }

  // Posição do texto baseada no alinhamento
  double textX;
  switch (align) {
    case CellAlign.center:
      textX = x + width / 2 - (text.length * 0.55 * 10 / 2);
      break;
    case CellAlign.right:
      textX = x + width - padding - (text.length * 0.55 * 10);
      break;
    case CellAlign.left:
    case CellAlign.justify:
      textX = x + padding;
      break;
  }

  // Trunca texto se necessário
  final escaped = pdfEscape(text);
  ops.add('BT');
  ops.add('${_f(textX)} ${_f(y - padding - 10)} Td');
  ops.add('($escaped) Tj');
  ops.add('ET');

  return ops;
}

String _f(double v) {
  return v.toStringAsFixed(2);
}
