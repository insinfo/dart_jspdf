# jsPDF Dart

Port of jsPDF for Dart with a familiar fluent API for generating PDF files in Web and Dart VM projects.

This package is designed to be self-contained at runtime: PDF generation, PNG/JPEG handling, TTF embedding, zlib/Flate support, encryption helpers, Context2D compatibility, and browser output helpers live inside this repository.

## Requirements

- Dart SDK 3.6.0 or newer.
- No runtime package dependencies are required by the library itself.
- Browser-only outputs such as `blob`, `bloburl`, `bloburi`, and `save()` are available only when running on Web. VM builds still compile through conditional exports and throw a clear `UnsupportedError` for browser-only actions.

## Install

For local development, add the package with a path dependency:

```yaml
dependencies:
  jspdf:
    path: ../jsPDF
```

Then run:

```bash
dart pub get
```

Import the public API:

```dart
import 'package:jspdf/jspdf.dart';
```

## Basic PDF

```dart
import 'dart:io';
import 'package:jspdf/jspdf.dart';

void main() {
  final pdf = JsPdf(
    const JsPdfOptions(
      unit: 'px',
      format: <double>[595, 842],
      compress: true,
    ),
  );

  pdf
    ..setFont('helvetica')
    ..setFontSize(18)
    ..text('Hello from Dart jsPDF', 40, 60)
    ..setFontSize(12)
    ..text('Generated on the Dart VM.', 40, 90);

  final output = pdf.output() as String;
  File('example.pdf').writeAsBytesSync(output.codeUnits);
}
```

## Browser Output

```dart
import 'package:jspdf/jspdf.dart';

void createAndOpenPdf() {
  final pdf = JsPdf()
    ..text('PDF in the browser', 20, 20);

  final url = pdf.output('bloburi') as String;
  // Use the URL in an anchor, iframe, or window.open in browser code.
  print(url);
}

void downloadPdf() {
  final pdf = JsPdf()
    ..text('Download me', 20, 20);

  pdf.save('document.pdf');
}
```

## Custom Pages

```dart
final pdf = JsPdf(
  const JsPdfOptions(unit: 'px', format: <double>[320, 480]),
);

pdf
  ..text('First page', 24, 32)
  ..addPage(<double>[640, 360], 'landscape')
  ..text('Second custom page', 24, 32);
```

## Images

`addImage` accepts PNG/JPEG bytes, data URLs, base64 strings, binary strings, and browser image/canvas objects when running on Web.

```dart
import 'dart:typed_data';
import 'package:jspdf/jspdf.dart';

void addLogo(Uint8List pngBytes) {
  final pdf = JsPdf(const JsPdfOptions(unit: 'px'));

  pdf.addImage(pngBytes, 'PNG', 24, 24, 128, 64, 'logo');

  final result = pdf.output() as String;
  print(result.length);
}
```

Canvas-style crop through `Context2D.drawImage` is supported with the 9-argument form:

```dart
pdf.context2d.drawImage(imageBytes, 10, 10, 80, 40, 20, 30, 160, 80);
```

## TrueType Fonts

Register TTF data through the in-memory vFS. The font data can be base64 or a binary string.

```dart
import 'dart:convert';
import 'dart:io';
import 'package:jspdf/jspdf.dart';

void main() {
  final fontBytes = File('assets/Roboto-Regular.ttf').readAsBytesSync();
  final pdf = JsPdf();

  pdf
    ..addFileToVFS('Roboto-Regular.ttf', base64.encode(fontBytes))
    ..addFont('Roboto-Regular.ttf', 'roboto')
    ..setFont('roboto')
    ..text('Unicode text with embedded TTF', 20, 30);

  File('font-example.pdf').writeAsBytesSync((pdf.output() as String).codeUnits);
}
```

The TTF parser supports core TrueType tables, Unicode cmap formats including format 12, UTF-16 name decoding, subset embedding, compound glyph remapping, and ToUnicode CMap generation for non-BMP code points.

## Context2D

`context2d` provides a CanvasRenderingContext2D-like API for PDF drawing, useful for ports that already render through canvas commands.

```dart
final pdf = JsPdf(const JsPdfOptions(unit: 'px', format: <double>[400, 240]));
final ctx = pdf.context2d;

ctx
  ..fillStyle = '#f2f2f2'
  ..fillRect(20, 20, 160, 80)
  ..strokeStyle = '#3366cc'
  ..lineWidth = 2;

ctx.beginPath();
ctx.moveTo(20, 120);
ctx.lineTo(180, 120);
ctx.stroke();

ctx
  ..font = 'italic 700 20px "Open Sans", sans-serif'
  ..fillStyle = '#111111'
  ..fillText('Canvas-like text', 24, 64);

final metrics = ctx.measureText('Canvas-like text');
print(metrics.width);
```

## HTML Text Rendering

The HTML module intentionally avoids DOM and html2canvas dependencies. It renders a textual subset of HTML: blocks, headings, lists, line breaks, entities, wrapping, and basic pagination.

```dart
final pdf = JsPdf();
html(
  pdf,
  '<h1>Report</h1><p>Hello &amp; welcome.</p><ul><li>One</li><li>Two</li></ul>',
  options: const HtmlToPdfOptions(margin: <double>[24, 24, 24, 24]),
);
```

## Links, Language, Opacity, and Encryption

```dart
final pdf = JsPdf(
  const JsPdfOptions(
    encryption: PdfEncryptionOptions(
      userPermissions: <String>['print', 'copy'],
      userPassword: 'user',
      ownerPassword: 'owner',
    ),
  ),
);

pdf
  ..setLanguage('pt-BR')
  ..setGState(GState(opacity: 0.5))
  ..textWithLink(
    'Open site',
    20,
    40,
    const LinkOptions(url: 'https://example.com'),
  );
```

## Validation

The project CI runs on Ubuntu 24.04 with Dart 3.6.2 and executes:

```bash
dart pub get
dart analyze
dart test
dart compile exe tool/vm_compile.dart -o .dart_tool/vm_compile
dart compile js tool/vm_compile.dart -o .dart_tool/web_compile.js
```

Run the same commands locally before publishing changes.

## Current Scope

Implemented areas include core PDF generation, standard fonts, TTF embedding, PNG/JPEG embedding, Context2D basics, textual HTML rendering, annotations/links, language metadata, viewer preferences, outlines, cells, compression, and PDF Standard Security R2.

Advanced modules such as SVG rendering, AcroForm, XMP metadata, BMP/GIF/WebP/RGBA helpers, DOCX conversion, and full browser DOM/CSS rendering are outside the current implemented scope.
