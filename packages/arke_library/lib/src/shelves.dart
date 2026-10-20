import 'item.dart';
import 'world.dart';

/// Files added from the phone, not the items an installed world brought (P9 rule 6).
Iterable<LibraryItem> _files(Iterable<LibraryItem> items) => items.where((item) => item.worldId == null);

/// Home's Continue: what is in progress, last played first, at most eight (P1 rule 4).
List<LibraryItem> continueShelf(Iterable<LibraryItem> items) {
  final inProgress = items.where((item) => item.inProgress).toList()..sort((a, b) => b.place!.updatedAt.compareTo(a.place!.updatedAt));
  return inProgress.take(8).toList();
}

/// Home's Added: the newest files, at most ten (P8 rule 5).
List<LibraryItem> addedShelf(Iterable<LibraryItem> items) {
  final newest = _files(items).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return newest.take(10).toList();
}

/// The kinds a library holds, in chip order. Library shows chips only when there are two or more
/// (P8 rule 4).
List<LibraryKind> kindsPresent(Iterable<LibraryItem> items) {
  final present = {for (final item in _files(items)) item.kind};
  return [
    for (final kind in LibraryKind.values)
      if (present.contains(kind)) kind,
  ];
}

/// Library's rows: newest first, of one kind or all.
List<LibraryItem> libraryRows(Iterable<LibraryItem> items, {LibraryKind? kind}) {
  final rows = _files(items).where((item) => kind == null || item.kind == kind).toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return rows;
}

/// The space the library takes: its files, and each installed world whole.
int bytesUsed(Iterable<LibraryItem> items, [Iterable<LibraryWorld> worlds = const []]) =>
    _files(items).fold(0, (sum, item) => sum + item.byteLength) + worlds.fold(0, (sum, world) => sum + world.byteLength);
