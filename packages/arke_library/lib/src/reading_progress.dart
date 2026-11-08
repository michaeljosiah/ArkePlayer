/// EPUB location percentages are coarse for short books. A full percentage alone
/// must not discard the saved CFI while another screen page remains (P5e, P12d).
bool hasFinishedPaginatedBook({required double progress, required int? chapterPage, required int? chapterTotalPages}) =>
    progress.isFinite && progress >= 0.999 && chapterPage != null && chapterTotalPages != null && chapterTotalPages > 0 && chapterPage == chapterTotalPages;
