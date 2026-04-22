# Roteiro de Porte: jsPDF → Dart (dart:html)

> **Projeto:** `jspdf` (Dart package)  
> **Origem:** `referencias/jsPDF-master/src/` (JavaScript)  
> **Destino:** `lib/src/` (Dart)  
> **Data:** 2026-04-21

---

não dependa de nada de C:\MyDartProjects\jsPDF\referencias o que precisar compie para o repositorio pois no futuro esta pasta sera removida 

## Visão Geral da Arquitetura

O jsPDF original é uma classe monolítica (~6180 linhas em `jspdf.js`) com plugins em `modules/` e utilitários em `libs/`.  
O porte Dart será modular, clean e idiomático:

```
lib/
├── jspdf.dart                  ← barrel export
└── src/
    ├── jspdf.dart              ← classe principal JsPdf
    ├── pubsub.dart             ← sistema de eventos interno
    ├── gstate.dart             ← graphics state
    ├── pattern.dart            ← Pattern, ShadingPattern, TilingPattern
    ├── matrix.dart             ← Matrix 2D homogênea
    ├── geometry.dart           ← Point, Rectangle
    ├── page_formats.dart       ← formatos de página (a4, letter, etc.)
    ├── pdf_document.dart       ← builder de documento PDF (objetos, xref, etc.)
    ├── color.dart              ← encode/decode de cores PDF
    ├── fonts.dart              ← gerenciamento de fontes padrão
    ├── pdf_security.dart       ← criptografia PDF (RC4)
    ├── utils.dart              ← utilitários (hpf, padd2, pdfEscape, etc.)
    ├── rgb_color.dart          ← parser de cores CSS/hex
    └── modules/
        ├── split_text_to_size.dart
        ├── annotations.dart
        ├── autoprint.dart
        ├── cell.dart
        ├── total_pages.dart
        ├── utf8.dart
        ├── standard_fonts_metrics.dart
        └── ... (demais módulos)
```

---

## Fases do Porte

### Fase 1 — Core Foundation ✅ CONCLUÍDA
| # | Arquivo Dart | Origem JS | Linhas JS | Status |
|---|---|---|---|---|
| 1.1 | `utils.dart` | jspdf.js (funções utilitárias) | ~50 | ✅ |
| 1.2 | `geometry.dart` | jspdf.js (Point, Rectangle) | ~30 | ✅ |
| 1.3 | `matrix.dart` | jspdf.js (Matrix class) | ~250 | ✅ |
| 1.4 | `pubsub.dart` | jspdf.js (PubSub class) | ~80 | ✅ |
| 1.5 | `gstate.dart` | jspdf.js (GState class) | ~50 | ✅ |
| 1.6 | `pattern.dart` | jspdf.js (Pattern, Shading, Tiling) | ~40 | ✅ |
| 1.7 | `page_formats.dart` | jspdf.js (pageFormats map) | ~50 | ✅ |
| 1.8 | `color.dart` | jspdf.js (encode/decode color) | ~120 | ✅ |
| 1.9 | `rgb_color.dart` | libs/rgbcolor.js | ~150 | ✅ |
| 1.10 | `fonts.dart` | jspdf.js (standard fonts) | ~30 | ✅ |

### Fase 2 — PDF Document Builder ✅ CONCLUÍDA
| # | Arquivo Dart | Origem JS | Status |
|---|---|---|---|
| 2.1 | `pdf_document.dart` | jspdf.js (object mgmt, putStream, putPages, buildDocument, xref, trailer) | ✅ |
| 2.2 | `pdf_security.dart` | libs/pdfsecurity.js + libs/rc4.js | 🔜 |

### Fase 3 — Classe Principal JsPdf ✅ CONCLUÍDA
| # | Arquivo Dart | Descrição | Status |
|---|---|---|---|
| 3.1 | `jspdf.dart` | Classe principal unificando core + API pública (text, line, rect, circle, setFont, setFontSize, addPage, output, save) | ✅ |

### Fase 4 — Módulos/Plugins ✅ CONCLUÍDA
| # | Módulo | Origem JS | Status |
|---|---|---|---|
| 4.1 | `split_text_to_size.dart` | modules/split_text_to_size.js | ✅ |
| 4.2 | `standard_fonts_metrics.dart` | modules/standard_fonts_metrics.js | ✅ (14 fontes, compress/uncompress, widths/kerning) |
| 4.3 | `annotations.dart` | modules/annotations.js | ✅ |
| 4.4 | `cell.dart` | modules/cell.js | ✅ (tabelas, alinhamento, padding, altura de linha) |
| 4.5 | `utf8.dart` | modules/utf8.js | ✅ (Identity-H, WinAnsi, pdfEscape16, ToUnicode CMap) |
| 4.6 | `total_pages.dart` | modules/total_pages.js | ✅ |
| 4.7 | `autoprint.dart` | modules/autoprint.js + javascript.js | ✅ (autoprint + addJS) |
| 4.8 | `outline.dart` | modules/outline.js | ✅ (bookmarks/outlines hierárquicos) |
| 4.9 | `viewerpreferences.dart` | modules/viewerpreferences.js | ✅ (17 preferências de visualização) |

### Fase 5 — Suporte a Imagens e Avançado ✅ PARCIALMENTE CONCLUÍDA
| # | Módulo | Origem JS | Status |
|---|---|---|---|
| 5.1 | `addimage.dart` | modules/addimage.js | ✅ (detecção de tipo, JPEG info, base64, conversores) |
| 5.2 | `jpeg_support.dart` | modules/jpeg_support.js | ✅ (SOF parsing, processJpeg, color space detection) |
| 5.3 | `png_support.dart` | modules/png_support.js | 🔜 |
| 5.4 | `context2d.dart` | modules/context2d.js | 🔜 |
| 5.5 | `html.dart` | modules/html.js (dart:html equivalent) | 🔜 |

### Fase 6 — Exportação Web (dart:html) ✅ CONCLUÍDA
| # | Funcionalidade | Status |
|---|---|---|
| 6.1 | `save()` via Blob + AnchorElement download | ✅ (em jspdf.dart) |
| 6.2 | `output('bloburl')` via Url.createObjectUrlFromBlob | ✅ (em jspdf.dart) |
| 6.3 | `output('dataurlstring')` via base64 | ✅ (em jspdf.dart) |

---

## Convenções de Porte

1. **Dart idiomático**: classes com named parameters, null safety, getters/setters
2. **Sem `var`**: usar `final`, `late`, tipos explícitos
3. **PubSub → callbacks tipados**: manter padrão leve
4. **dart:html**: para Blob, AnchorElement, Url (output/save web)
5. **dart:typed_data**: para ByteBuffer/Uint8List (substituir ArrayBuffer)
6. **dart:convert**: para base64, utf8
7. **dart:math**: para operações matemáticas

---

## Mapeamento de Tipos JS → Dart

| JavaScript | Dart |
|---|---|
| `Array` | `List` |
| `Object` (map) | `Map<String, dynamic>` |
| `ArrayBuffer` | `ByteBuffer` |
| `Uint8Array` | `Uint8List` |
| `Blob` | `Blob` (dart:html) |
| `undefined` | `null` |
| `function` | `Function` / typedef |
| `prototype` | class methods |
| `this` | implicit |
| `arguments` | named/positional params |
| `Math.random()` | `Random().nextDouble()` |
| `parseInt()` | `int.parse()` |
| `parseFloat()` | `double.parse()` |
| `isNaN()` | `.isNaN` |
| `toString(35)` | custom radix converter |
| `String.prototype.charCodeAt()` | `.codeUnitAt()` |

---

## Fases 1–6 avançadas ✅

**Total de arquivos portados:** 25 arquivos Dart
**Testes unitários:** 200 testes ✅ All passed
**`dart analyze`: 0 issues** ✅

### Libs portadas
| Arquivo | Origem JS | Status |
|---|---|---|
| `lib/src/pdfname.dart` | libs/pdfname.js | ✅ (PDF Name Object encoding) |
| `lib/src/libs/ttffont.dart` | libs/ttffont.js (~1950 linhas) | ✅ (parser TTF completo: Data, Directory, 10 tabelas, Subset, PDFObject) |

### Suíte de Testes
| Arquivo de Teste | Cobertura | Testes |
|---|---|---|
| `test/utils_test.dart` | utils.dart | 22 |
| `test/matrix_test.dart` | matrix.dart, geometry.dart | 17 |
| `test/pubsub_test.dart` | pubsub.dart | 10 |
| `test/color_test.dart` | color.dart, rgb_color.dart | 22 |
| `test/core_test.dart` | page_formats, fonts, gstate, pattern, pdf_document | 27 |
| `test/addimage_test.dart` | modules/addimage.dart | 22 |
| `test/font_metrics_test.dart` | modules/standard_fonts_metrics.dart | 22 |
| `test/modules_test.dart` | modules/outline, viewerpreferences, cell | 27 |
| `test/jpeg_support_test.dart` | modules/jpeg_support.dart | 5 |
| `test/utf8_test.dart` | pdfname, TtfData, PDFObject, utf8, ToUnicodeCmap | 26 |
| **Total** | | **200** |

### Próximos passos pendentes
- `png_support.dart` — parsing de PNG (IHDR, IDAT, defiltering)
- `context2d.dart` — Canvas 2D API para geração de PDF via path
- `html.dart` — renderização de HTML para PDF
- Testes de integração com TTF real (embedding de fontes em PDF)
