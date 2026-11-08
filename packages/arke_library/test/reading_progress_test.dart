import 'package:arke_library/arke_library.dart';
import 'package:test/test.dart';

void main() {
  test('short EPUB at full CFI percentage keeps its place before the last screen page', () {
    expect(hasFinishedPaginatedBook(progress: 1, chapterPage: 1, chapterTotalPages: 2), isFalse);
  });

  test('last chapter page at full percentage finishes the book', () {
    expect(hasFinishedPaginatedBook(progress: 1, chapterPage: 2, chapterTotalPages: 2), isTrue);
    expect(hasFinishedPaginatedBook(progress: 1, chapterPage: 1, chapterTotalPages: 1), isTrue);
  });

  test('last page of an earlier chapter does not finish the book', () {
    expect(hasFinishedPaginatedBook(progress: 0.6, chapterPage: 4, chapterTotalPages: 4), isFalse);
  });

  test('missing or invalid pagination preserves the resumable place', () {
    for (final pages in [(null, null), (1, null), (null, 1), (0, 0), (-1, -1), (3, 2)]) {
      expect(hasFinishedPaginatedBook(progress: 1, chapterPage: pages.$1, chapterTotalPages: pages.$2), isFalse);
    }
  });

  test('nonfinite location percentages never finish the book', () {
    for (final progress in [double.nan, double.infinity, double.negativeInfinity]) {
      expect(hasFinishedPaginatedBook(progress: progress, chapterPage: 1, chapterTotalPages: 1), isFalse);
    }
  });
}
