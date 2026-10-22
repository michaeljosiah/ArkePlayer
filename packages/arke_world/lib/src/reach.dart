import 'dart:math';

import 'package:arke_library/arke_library.dart';

import 'guide.dart';
import 'listening.dart';

/// The chapter number a finished production has reached: all of them.
const reachedAll = 1 << 30;

/// The spine index a CFI's first step names: `epubcfi(/6/14!/4/2:0)` is in the seventh document.
int? spineIndexOfCfi(String? cfi) {
  final match = RegExp(r'^epubcfi\(/6/(\d+)').firstMatch(cfi ?? '');
  if (match == null) return null;
  final step = int.parse(match.group(1)!);
  return step >= 2 && step.isEven ? step ~/ 2 - 1 : null;
}

/// Where a reader is in one production of a world (SPEC-059 R-20): [at], the number of the chapter
/// their furthest place is in; [through], the last chapter whose start that place has passed.
typedef Reached = ({int at, int through});

/// Where this phone's places put a reader in [production], heard or read. A chapter is known by
/// the guide's number for it, else by the listening document's order. A place in the narration is
/// a chapter and an offset into it: a chapter just begun, at its very start, is not yet passed. A
/// place in the book is a CFI, whose document is found through the [spine] and then the guide's or
/// the listening document's map of documents to chapters; being in a chapter's document is being
/// past its start.
Reached reachedIn(GuideProduction production, {ListeningDocument? listening, LibraryItem? narration, LibraryItem? book, List<String> spine = const []}) {
  int? numberOf(String chapterId) =>
      production.chapters.where((chapter) => chapter.id == chapterId).firstOrNull?.number ??
      listening?.chapters.where((chapter) => chapter.id == chapterId).firstOrNull?.order;

  var at = 0;
  var through = 0;
  final heard = narration?.place;
  if (listening != null && heard?.locator != null) {
    final number = numberOf(heard!.locator!);
    if (number != null) {
      at = max(at, number);
      through = max(through, (heard.position ?? Duration.zero) > Duration.zero ? number : number - 1);
    }
  }
  final index = spineIndexOfCfi(book?.place?.locator);
  if (index != null && index < spine.length) {
    final byDocument = <String, int>{
      for (final chapter in listening?.chapters ?? const <ListeningChapter>[])
        if (chapter.book != null) chapter.book!: numberOf(chapter.id)!,
      for (final chapter in production.chapters)
        if (chapter.book != null) chapter.book!: chapter.number,
    };
    // A document between chapters (a title page, an interlude) is in the chapter before it.
    for (var i = index; i >= 0; i--) {
      if (byDocument[spine[i]] case final number?) {
        at = max(at, number);
        through = max(through, number);
        break;
      }
    }
  }
  if ((narration?.finished ?? false) || (book?.finished ?? false)) through = reachedAll;
  return (at: at, through: through);
}

/// What of a world's guide this phone may show (SPEC-059 R-20, R-21): by production, where its
/// places are, with what the person chose to reveal. Nothing here ever leaves the phone.
class GuideReach {
  const GuideReach({this.reached = const {}, this.revealed = const {}});

  final Map<String, Reached> reached;

  /// By production, the chapter number revealed through.
  final Map<String, int> revealed;

  static const none = GuideReach();

  /// Shown: public from the start, or after a chapter reached or revealed.
  bool shows(GuideAfter? after) => after == null || after.number <= max(reached[after.production]?.through ?? 0, revealed[after.production] ?? 0);

  /// The chapter the reader is at in [production], for Reveal's line; null before they start.
  int? at(String production) => switch (reached[production]?.at) {
    final int at when at > 0 => at,
    _ => null,
  };
}
