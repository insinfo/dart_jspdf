/// Plugin de Outline (Bookmarks) para PDF.
///
/// Permite adicionar uma árvore de bookmarks/outlines
/// ao documento PDF para navegação.
///
/// Portado de modules/outline.js do jsPDF.

import '../utils.dart';

/// Um nó na árvore de outlines.
class OutlineNode {
  /// Título exibido no painel de bookmarks.
  final String title;

  /// Opções (ex: pageNumber).
  final Map<String, dynamic>? options;

  /// Filhos deste nó.
  final List<OutlineNode> children = [];

  /// ID do objeto no PDF (atribuído durante render).
  int id = -1;

  OutlineNode({
    required this.title,
    this.options,
  });
}

/// Gerenciador de outlines do PDF.
class PdfOutline {
  /// Nó raiz (não exibido, contém filhos de nível 1).
  final OutlineNode root = OutlineNode(title: '');

  /// Se true, cria named destinations para cada página.
  bool createNamedDestinations = false;

  /// Adiciona um item ao outline.
  ///
  /// [parent] é o nó pai (null para raiz).
  /// [title] é o texto do bookmark.
  /// [options] pode conter 'pageNumber'.
  OutlineNode add(OutlineNode? parent, String title,
      {Map<String, dynamic>? options}) {
    final item = OutlineNode(title: title, options: options);
    (parent ?? root).children.add(item);
    return item;
  }

  /// Renderiza o outline para string PDF.
  ///
  /// [objectIdAssigner] deve retornar um ID de objeto novo para cada chamada.
  /// [pageObjIdLookup] retorna o objId para um dado pageNumber.
  /// [pageHeight] é a altura da página (para coordenadas verticais).
  String render({
    required int Function() objectIdAssigner,
    required int Function(int pageNumber) pageObjIdLookup,
    required double pageHeight,
  }) {
    final sb = StringBuffer();

    _genIds(root, objectIdAssigner);
    _renderRoot(sb, root);
    _renderItems(sb, root, pageObjIdLookup, pageHeight);

    return sb.toString();
  }

  void _genIds(OutlineNode node, int Function() assigner) {
    node.id = assigner();
    for (final child in node.children) {
      _genIds(child, assigner);
    }
  }

  void _renderRoot(StringBuffer sb, OutlineNode node) {
    sb.writeln();
    sb.writeln('${node.id} 0 obj');
    sb.writeln('<<');
    sb.writeln('/Type /Outlines');
    if (node.children.isNotEmpty) {
      sb.writeln('/First ${node.children.first.id} 0 R');
      sb.writeln('/Last ${node.children.last.id} 0 R');
    }
    sb.writeln('/Count ${_countR(node)}');
    sb.writeln('>>');
    sb.writeln('endobj');
  }

  void _renderItems(
    StringBuffer sb,
    OutlineNode node,
    int Function(int) pageObjIdLookup,
    double pageHeight,
  ) {
    for (var i = 0; i < node.children.length; i++) {
      final item = node.children[i];
      sb.writeln();
      sb.writeln('${item.id} 0 obj');
      sb.writeln('<<');
      sb.writeln('/Title (${pdfEscape(item.title)})');
      sb.writeln('/Parent ${node.id} 0 R');

      if (i > 0) {
        sb.writeln('/Prev ${node.children[i - 1].id} 0 R');
      }
      if (i < node.children.length - 1) {
        sb.writeln('/Next ${node.children[i + 1].id} 0 R');
      }
      if (item.children.isNotEmpty) {
        sb.writeln('/First ${item.children.first.id} 0 R');
        sb.writeln('/Last ${item.children.last.id} 0 R');
      }

      final count = _countR(item);
      if (count > 0) {
        sb.writeln('/Count $count');
      }

      if (item.options != null && item.options!.containsKey('pageNumber')) {
        final pageNum = item.options!['pageNumber'] as int;
        final objId = pageObjIdLookup(pageNum);
        sb.writeln('/Dest [$objId 0 R /XYZ 0 ${pageHeight.toStringAsFixed(2)} 0]');
      }

      sb.writeln('>>');
      sb.writeln('endobj');
    }

    for (final child in node.children) {
      _renderItems(sb, child, pageObjIdLookup, pageHeight);
    }
  }

  int _countR(OutlineNode node) {
    var count = 0;
    for (final child in node.children) {
      count++;
      count += _countR(child);
    }
    return count;
  }
}
