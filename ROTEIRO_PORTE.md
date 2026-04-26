# Roteiro de Porte: jsPDF → Dart (dart:html)

> **Projeto:** `jspdf` (Dart package)  
> **Origem:** `referencias/jsPDF-master/src/` (JavaScript)  
> **Destino:** `lib/src/` (Dart)  
> **Data:** 2026-04-21

---

não dependa de nada de C:\MyDartProjects\jsPDF\referencias o que precisar compie para o repositorio pois no futuro esta pasta sera removida 

## Regra Bloqueante de Portabilidade

- **Zero dependências externas em runtime**: tudo que o jsPDF precisar deve ser implementado do zero dentro deste repositório, sem depender de packages externos nem da pasta `referencias/`.
- **Compatibilidade dupla obrigatória**: todo código de runtime deve compilar tanto para Web quanto para Dart VM. APIs específicas de navegador devem usar imports/exports condicionais com fallback VM.
- **Dependências de desenvolvimento**: packages em `dev_dependencies` são permitidos apenas para testes, build e validação; não podem ser necessários para usar a biblioteca em runtime.

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
| 2.2 | `pdf_security.dart` | libs/pdfsecurity.js + libs/rc4.js | ✅ (RC4, MD5, Standard Security R2, encryptor por objeto, integração `/Encrypt`) |

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
| 4.10 | `vFS/addFont TTF` | modules/vfs.js + modules/ttfsupport.js | ✅ (vFS em memória, addFont, TTF base64/binary string, Identity-H) |
| 4.11 | `setlanguage.dart` | modules/setlanguage.js | ✅ (`/Lang` no catálogo, códigos ISO/locale portados) |

### Fase 5 — Suporte a Imagens e Avançado ✅ PARCIALMENTE CONCLUÍDA
| # | Módulo | Origem JS | Status |
|---|---|---|---|
| 5.1 | `addimage.dart` | modules/addimage.js | ✅ (detecção de tipo, JPEG info, base64, conversores, `addImage` PNG/JPEG e `/XObject`) |
| 5.2 | `jpeg_support.dart` | modules/jpeg_support.js | ✅ (SOF parsing, processJpeg, color space detection) |
| 5.3 | `png_support.dart` | modules/png_support.js + libs/fast-png | ✅ (decode PNG local, PLTE/tRNS, filtros, SMask, Flate/ZLib web) |
| 5.4 | `context2d.dart` | modules/context2d.js | ✅ PARCIAL (Canvas paths, fill/stroke/clip, texto básico, operadores PDF raw, `drawImage` PNG/JPEG; falta fidelidade de métricas para o editor e crop de imagem) |
| 5.5 | `html.dart` | modules/html.js | ✅ (parser textual HTML em Dart puro, entidades, blocos/listas/títulos, wrapping e paginação) |

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
4. **Web/VM por exports condicionais**: APIs de navegador ficam em `platform/`, com fallback compilável na VM
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

**Total de arquivos portados:** 34 arquivos Dart
**Testes unitários:** 245 testes ✅ All passed
**`dart analyze`: 0 issues** ✅

### Libs portadas
| Arquivo | Origem JS | Status |
|---|---|---|
| `lib/src/pdfname.dart` | libs/pdfname.js | ✅ (PDF Name Object encoding) |
| `lib/src/pdf_security.dart` | libs/pdfsecurity.js + libs/rc4.js | ✅ (MD5 local, RC4, permissões, dicionário `/Encrypt`, streams/info criptografados) |
| `lib/src/libs/ttffont.dart` | libs/ttffont.js (~1950 linhas) | ✅ (parser TTF robusto: validação de bounds, Directory/head/cmap/name/hhea/maxp/hmtx/post/OS2/loca/glyf, `cmap` format 0/4/6/12, nomes UTF-16BE, métricas escaladas, compound glyph remap, subset, PDFObject) |
| `lib/src/libs/fast_png.dart` | libs/fast-png | ✅ (decode PNG, IHDR/PLTE/tRNS/IDAT/IEND, filtros None/Sub/Up/Average/Paeth, CRC) |
| `lib/src/libs/zlib.dart` + export condicional | libs/fflate.js / ZLibCodec | ✅ (inflate/deflate stored web-safe, wrapper dart:io opcional) |
| `lib/src/platform/browser_platform.dart` + exports condicionais | infraestrutura Web/VM | ✅ (Blob/download no browser, stubs VM compiláveis) |
| `lib/src/modules/setlanguage.dart` | modules/setlanguage.js | ✅ (`setLanguage`, validação de códigos e `/Lang`) |

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
| `test/modules_test.dart` | modules/outline, viewerpreferences, cell, setlanguage | 30 |
| `test/jpeg_support_test.dart` | modules/jpeg_support.dart | 5 |
| `test/utf8_test.dart` | pdfname, TtfData, PDFObject, utf8, ToUnicodeCmap | 27 |
| `test/png_support_test.dart` | fast_png.dart, png_support.dart | 6 |
| `test/zlib_test.dart` | zlib.dart web-safe | 2 |
| `test/context2d_test.dart` | modules/context2d.dart, APIs de compatibilidade do editor | 14 |
| `test/html_test.dart` | modules/html.dart | 5 |
| `test/pdf_security_test.dart` | pdf_security.dart | 7 |
| `test/ttffont_integration_test.dart` | TTFFont + vFS/addFont embedding | 9 |
| **Total** | | **245** |

### Próximos passos pendentes
- Portar módulos avançados ainda ausentes da referência conforme prioridade: `xmp_metadata`, `svg`, `acroform`, `bmp/gif/webp_support`, `rgba_support`.

---

## Compatibilidade alvo: `canvas-editor-port` / `canvas-editor-feature-pdf`

Referência analisada: `C:\MyDartProjects\canvas-editor-port\referencias\canvas-editor-feature-pdf` (`jspdf@^2.5.1`).  
Objetivo: deixar este pacote Dart robusto o bastante para substituir o `jsPDF` usado na exportação PDF do editor de texto TypeScript, mantendo a regra de zero dependências externas e compilação Web/VM.

### APIs usadas pela referência do editor

| Origem | API usada | Status no porte Dart | Ação necessária |
|---|---|---|---|
| `new jsPDF({...})` | `orientation: 'p'`, `unit: 'px'`, `format: [width, height]`, `hotfixes: ['px_scaling']`, `compress: true` | 🟡 Parcial | `format: [width, height]` e `compress: true` já funcionam; `px_scaling` ainda precisa teste visual dedicado contra jsPDF. |
| `doc.context2d` | getter/propriedade `context2d` | ✅ Presente | Instância persistente exposta em `JsPdf.context2d` e alias `context2D`. |
| `ctx.save/restore` | pilha de estado | ✅ Presente | Cobrir por testes com estilos, transformações e dash. |
| `ctx.font/fillStyle/strokeStyle/lineWidth/globalAlpha` | estado Canvas | ✅ Presente | Parser CSS cobre tamanho, família com aspas/espaços, `italic/oblique`, `bold/bolder` e pesos numéricos; `globalAlpha` usa ExtGState. |
| `ctx.beginPath/moveTo/lineTo/rect/closePath/stroke/fill/fillRect/clearRect` | desenho vetorial | 🟡 Parcial | Base existe; precisa teste visual/estrutural para separador, tabela, checkbox, highlight, page break. `clearRect` hoje é ignorado por padrão. |
| `ctx.translate/rotate` | transformações | ✅ Presente | Usado por tabela e watermark; manter testes de transformação. |
| `ctx.setLineDash` | linhas tracejadas | ✅ Presente | Já existe no `Context2D`; validar com separador e page break. |
| `ctx.fillText` | texto | 🟡 Parcial | Funciona com seleção de família/peso/estilo; ainda falta fidelidade fina de baseline e alinhamentos avançados do Canvas. |
| `ctx.measureText` / canvas fake | `width`, `actualBoundingBoxAscent`, `actualBoundingBoxDescent` | ✅ Presente | Usa `TTFFont` quando disponível e métricas das fontes padrão como fallback; retorna ascent/descent/font bounding boxes. |
| `ctx.drawImage(value, x, y, w, h)` | imagens do documento | ✅ Presente | Integrado a `JsPdf.addImage` com `/XObject`, cache/alias, PNG/JPEG bytes/data URL, crop de 9 argumentos por clipping e entrada Web para `ImageElement`, `CanvasElement` e `ImageData` via export condicional. |
| `doc.addFont('/canvas-editor-pdf/font/msyh.ttf', 'Yahei', 'normal')` | fonte TTF por caminho | 🟡 Parcial | vFS/addFont funciona, mas depende de preload. Definir API web/VM para registrar bytes/base64 do asset antes do `addFont`, sem carregar de `referencias/`. |
| `doc.setFont('Yahei')` | seleção de fonte | ✅ Presente | Garantir seleção por peso quando `ctx.font` contém `bold`. |
| `doc.addPage([width, height], 'p')` | formato custom por página | ✅ Presente | `JsPdf.addPage` aceita `String` ou `List<num>` e converte dimensões da unidade pública para pontos internos. |
| `doc.setDocumentProperties(...)` | metadata | ✅ Presente | Aceita `Map<String, String>`; validar campos `title/subject/author/keywords/creator`. |
| `doc.output('bloburi')` | URL para abrir PDF no browser | ✅ Presente | Já usa export condicional Web/VM. |
| `doc.textWithLink(...)` | hyperlink | ✅ Presente | Implementado como `text()` + `link()`, com anotação gravada no PDF. |
| `doc.setGState(new GState({ opacity }))` | opacidade para highlight/watermark | ✅ Presente | `addGState`, `setGState`, `/ExtGState` no resource dictionary e operador `/GSn gs` implementados. |
| annotations/link | `/Annots` por página | ✅ Presente | `link()` grava anotações no `PageContext` e `PdfDocumentBuilder.putPage` emite `/Annots`. |

### Prioridade de implementação para atender o editor

1. **Bloqueadores diretos de execução**
    - ✅ `JsPdf.context2d` persistente.
    - ✅ `Context2D.drawImage` integrado a `addImage`/XObject para PNG/JPEG sem crop.
    - ✅ `JsPdf.addPage([width, height], 'p')`.
    - ✅ `JsPdf.textWithLink` e escrita real de `/Annots`.
    - ✅ `JsPdf.setGState`/`GState` real para `highlight` e `watermark`.

2. **Fidelidade visual do editor**
    - ✅ `Context2D.measureText` com `width`, `actualBoundingBoxAscent` e `actualBoundingBoxDescent` usando métricas reais de TTF e fontes padrão.
    - ✅ Parser de `ctx.font` para `italic`, `bold`, tamanho e família; seleção correta de `Yahei normal/bold` quando as variantes foram registradas.
    - Testes de renderização dos casos do editor: texto, tabela, separador tracejado, checkbox, hyperlink, superscript/subscript, header, page number, watermark e highlight.
    - Definir comportamento de `clearRect` para páginas do editor; se continuar como no jsPDF, documentar/parametrizar `ignoreClearRect`.

3. **Imagens e assets**
    - ✅ `JsPdf.addImage` público com PNG/JPEG, data URL, `Uint8List`, cache por alias e escrita de `/XObject` no resource dictionary.
    - ✅ Implementar crop de imagem (`drawImage` com 9 argumentos) e entradas de browser (`HTMLImageElement`, `CanvasElement`, `ImageData`) por camada condicional Web/VM.
    - Manter suporte PNG/JPEG já portado e adicionar fallback/erro claro para formatos ainda ausentes.
    - Planejar assets do editor: fontes `msyh.ttf` e `msyh-bold.ttf` devem ser copiadas/registradas no projeto Dart consumidor via bytes/base64, nunca carregadas de `referencias/`.

4. **Robustez de PDF gerado**
    - ✅ Compressão Flate para streams gerais quando `JsPdfOptions.compress == true`, usando a implementação local de zlib compatível com Web/VM.
    - Integrar `/ExtGState`, `/XObject` e `/Annots` no `PdfDocumentBuilder` sem globais estáticos que vazem entre documentos.
    - Adicionar testes de compilação Web/VM para o cenário mínimo do editor.

5. **Módulos que permanecem secundários para este editor**
    - `xmp_metadata`, `svg`, `acroform`, `bmp/gif/webp_support`, `rgba_support` continuam pendentes, mas não aparecem como dependência direta da referência PDF analisada. SVG e formatos extras podem subir de prioridade se imagens/LaTeX do editor exigirem esses formatos.

### Critério de pronto para o porte do editor

- Um exemplo Dart mínimo deve criar `JsPdf(JsPdfOptions(unit: 'px', format: [width, height], compress: true))`, registrar as fontes Yahei via vFS, usar `pdf.context2d` para texto/tabela/checkbox/separador/imagem/watermark, adicionar nova página customizada, criar hyperlink e retornar `output('bloburi')` no Web.
- O mesmo exemplo deve compilar na Dart VM, retornando fallback seguro para APIs de Blob/URL quando executado fora do browser.
- Validação obrigatória antes de considerar a etapa concluída: `dart analyze`, `dart test`, `dart compile exe tool/vm_compile.dart -o .dart_tool/vm_compile.exe` e `dart compile js tool/vm_compile.dart -o .dart_tool/web_compile.js`.

### Última validação

- 2026-04-26: `dart analyze` ✅, `dart test` ✅ 245 testes, `dart compile exe tool/vm_compile.dart -o .dart_tool/vm_compile.exe` ✅, `dart compile js tool/vm_compile.dart -o .dart_tool/web_compile.js` ✅.
