import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import 'file_importer.dart';

/// Reads a PDF with PDFium: its page count and a picture of the first page, 360 wide — the
/// first page is a document's cover in Library (P7b). A PDF that needs a password is DRM to the
/// Player, which never asks for one, and is refused as `Protected file`.
class PdfrxPeek implements PdfPeek {
  const PdfrxPeek();

  @override
  Future<PdfFacts> peek(String path) async {
    final PdfDocument document;
    try {
      document = await PdfDocument.openFile(path);
    } on PdfPasswordException {
      return const PdfFacts(pages: 0, protectedFile: true);
    }
    try {
      final pages = document.pages.length;
      if (pages == 0) return const PdfFacts(pages: 0);
      final first = document.pages.first;
      const width = 360.0;
      final height = width * first.height / first.width;
      final rendered = await first.render(fullWidth: width, fullHeight: height, backgroundColor: 0xFFFFFFFF);
      if (rendered == null) return PdfFacts(pages: pages);
      try {
        final image = await rendered.createImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return PdfFacts(pages: pages, firstPage: png?.buffer.asUint8List());
      } finally {
        rendered.dispose();
      }
    } finally {
      await document.dispose();
    }
  }
}
