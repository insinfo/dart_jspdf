/// Plugin de Viewer Preferences para PDF.
///
/// Controla como o documento é apresentado ao abrir
/// (ocultar toolbar, centralizar janela, imprimir, etc.).
///
/// Portado de modules/viewerpreferences.js do jsPDF.

/// Configuração individual de preferência.
class _ViewerPref {
  final dynamic defaultValue;
  dynamic value;
  final String type; // 'boolean', 'name', 'integer', 'array'
  bool explicitSet;
  final List<dynamic>? valueSet;
  final double pdfVersion;

  _ViewerPref({
    required this.defaultValue,
    required this.type,
    this.valueSet,
    required this.pdfVersion,
  })  : value = defaultValue,
        explicitSet = false;

  void reset() {
    value = defaultValue;
    explicitSet = false;
  }
}

/// Preferências de visualização do PDF.
class ViewerPreferences {
  final Map<String, _ViewerPref> _config;

  ViewerPreferences._()
      : _config = {
          'HideToolbar': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.3,
          ),
          'HideMenubar': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.3,
          ),
          'HideWindowUI': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.3,
          ),
          'FitWindow': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.3,
          ),
          'CenterWindow': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.3,
          ),
          'DisplayDocTitle': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.4,
          ),
          'NonFullScreenPageMode': _ViewerPref(
            defaultValue: 'UseNone', type: 'name',
            valueSet: ['UseNone', 'UseOutlines', 'UseThumbs', 'UseOC'],
            pdfVersion: 1.3,
          ),
          'Direction': _ViewerPref(
            defaultValue: 'L2R', type: 'name',
            valueSet: ['L2R', 'R2L'], pdfVersion: 1.3,
          ),
          'ViewArea': _ViewerPref(
            defaultValue: 'CropBox', type: 'name',
            valueSet: ['MediaBox', 'CropBox', 'TrimBox', 'BleedBox', 'ArtBox'],
            pdfVersion: 1.4,
          ),
          'ViewClip': _ViewerPref(
            defaultValue: 'CropBox', type: 'name',
            valueSet: ['MediaBox', 'CropBox', 'TrimBox', 'BleedBox', 'ArtBox'],
            pdfVersion: 1.4,
          ),
          'PrintArea': _ViewerPref(
            defaultValue: 'CropBox', type: 'name',
            valueSet: ['MediaBox', 'CropBox', 'TrimBox', 'BleedBox', 'ArtBox'],
            pdfVersion: 1.4,
          ),
          'PrintClip': _ViewerPref(
            defaultValue: 'CropBox', type: 'name',
            valueSet: ['MediaBox', 'CropBox', 'TrimBox', 'BleedBox', 'ArtBox'],
            pdfVersion: 1.4,
          ),
          'PrintScaling': _ViewerPref(
            defaultValue: 'AppDefault', type: 'name',
            valueSet: ['AppDefault', 'None'], pdfVersion: 1.6,
          ),
          'Duplex': _ViewerPref(
            defaultValue: 'none', type: 'name',
            valueSet: ['Simplex', 'DuplexFlipShortEdge', 'DuplexFlipLongEdge', 'none'],
            pdfVersion: 1.7,
          ),
          'PickTrayByPDFSize': _ViewerPref(
            defaultValue: false, type: 'boolean',
            valueSet: [true, false], pdfVersion: 1.7,
          ),
          'PrintPageRange': _ViewerPref(
            defaultValue: '', type: 'array',
            valueSet: null, pdfVersion: 1.7,
          ),
          'NumCopies': _ViewerPref(
            defaultValue: 1, type: 'integer',
            valueSet: null, pdfVersion: 1.7,
          ),
        };

  /// Cria uma nova instância.
  factory ViewerPreferences() => ViewerPreferences._();

  /// Define preferências a partir de um mapa.
  ///
  /// Exemplo:
  /// ```dart
  /// prefs.set({'FitWindow': true, 'HideToolbar': true});
  /// ```
  void set(Map<String, dynamic> options) {
    for (final entry in options.entries) {
      final method = entry.key;
      final value = entry.value;

      if (!_config.containsKey(method)) continue;

      final pref = _config[method]!;

      if (pref.type == 'boolean' && value is bool) {
        pref.value = value;
        pref.explicitSet = true;
      } else if (pref.type == 'name' &&
          value is String &&
          (pref.valueSet?.contains(value) ?? false)) {
        pref.value = value;
        pref.explicitSet = true;
      } else if (pref.type == 'integer' && value is int) {
        pref.value = value;
        pref.explicitSet = true;
      } else if (pref.type == 'array' && value is List) {
        final rangeArray = <String>[];
        for (final range in value) {
          if (range is List<int>) {
            if (range.length == 1) {
              rangeArray.add('${range[0] - 1}');
            } else if (range.length >= 2) {
              rangeArray.add('${range[0] - 1} ${range[1] - 1}');
            }
          }
        }
        pref.value = '[${rangeArray.join(' ')}]';
        pref.explicitSet = true;
      }
    }
  }

  /// Reseta todas as preferências para valores padrão.
  void reset() {
    for (final pref in _config.values) {
      pref.reset();
    }
  }

  /// Gera o dicionário PDF de preferências.
  ///
  /// Retorna null se nenhuma preferência foi explicitamente definida.
  String? toPdfDict() {
    final entries = <String>[];

    for (final entry in _config.entries) {
      if (entry.value.explicitSet) {
        if (entry.value.type == 'name') {
          entries.add('/${entry.key} /${entry.value.value}');
        } else {
          entries.add('/${entry.key} ${entry.value.value}');
        }
      }
    }

    if (entries.isEmpty) return null;
    return '/ViewerPreferences\n<<\n${entries.join('\n')}\n>>';
  }

  /// Verifica se uma preferência foi definida.
  bool isSet(String key) => _config[key]?.explicitSet ?? false;

  /// Obtém o valor de uma preferência.
  dynamic getValue(String key) => _config[key]?.value;
}
