/// Plugin para impressão automática do PDF.
///
/// Faz o PDF abrir automaticamente o diálogo de impressão
/// quando aberto em um visualizador PDF.
///
/// Portado de modules/autoprint.js do jsPDF.

import '../jspdf.dart';

/// Variante do autoprint.
enum AutoPrintVariant { nonConform, javascript }

/// Extensão do JsPdf para impressão automática.
extension JsPdfAutoPrint on JsPdf {
  /// Configura o PDF para abrir automaticamente a caixa de impressão.
  ///
  /// [variant] define o método:
  /// - [AutoPrintVariant.nonConform]: usa /OpenAction (mais compatível)
  /// - [AutoPrintVariant.javascript]: usa JavaScript embutido
  JsPdf autoPrint({AutoPrintVariant variant = AutoPrintVariant.nonConform}) {
    switch (variant) {
      case AutoPrintVariant.javascript:
        addJS('print({});');
        break;
      case AutoPrintVariant.nonConform:
        // Registra ação de impressão via PubSub
        events.subscribe('postPutResources', (args) {
          final refTag = internal.newObject();
          internal.out('<<');
          internal.out('/S /Named');
          internal.out('/Type /Action');
          internal.out('/N /Print');
          internal.out('>>');
          internal.out('endobj');
          // Armazena para uso no catálogo
          _autoPrintRef = refTag;
        });
        events.subscribe('putCatalog', (args) {
          if (_autoPrintRef != null) {
            internal.out('/OpenAction $_autoPrintRef 0 R');
          }
        });
        break;
    }
    return this;
  }

  /// Adiciona JavaScript embutido no PDF.
  JsPdf addJS(String javascript) {
    final escaped = _escapeParens(javascript);

    events.subscribe('postPutResources', (args) {
      final namesObj = internal.newObject();
      internal.out('<<');
      internal.out('/Names [(EmbeddedJS) ${namesObj + 1} 0 R]');
      internal.out('>>');
      internal.out('endobj');

      internal.newObject();
      internal.out('<<');
      internal.out('/S /JavaScript');
      internal.out('/JS ($escaped)');
      internal.out('>>');
      internal.out('endobj');
      _jsNamesObj = namesObj;
    });

    events.subscribe('putCatalog', (args) {
      if (_jsNamesObj != null) {
        internal.out('/Names <</JavaScript $_jsNamesObj 0 R>>');
      }
    });

    return this;
  }

  /// Escapa parênteses em JavaScript para PDF.
  String _escapeParens(String str) {
    final sb = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      final ch = str[i];
      if (ch == '(' || ch == ')') {
        var bs = 0;
        for (var j = i - 1; j >= 0 && str[j] == '\\'; j--) {
          bs++;
        }
        if (bs % 2 == 0) {
          sb.write('\\$ch');
        } else {
          sb.write(ch);
        }
      } else {
        sb.write(ch);
      }
    }
    return sb.toString();
  }
}

// Estado global para autoprint (seria integrado ao JsPdf em prod)
int? _autoPrintRef;
int? _jsNamesObj;
