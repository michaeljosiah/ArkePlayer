import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../stories/application/stories.dart';
import '../../worlds/application/worlds.dart';

/// `24 pages`.
String pageCount(int count) => count == 1 ? '1 page' : '$count pages';

/// A Fold open's spreads (P21 rule 9), as book pages face: 1 and 2, then 3 and 4, an odd last page
/// alone. Each is its first page's index and its second's.
List<(int, int?)> comicSpreads(int count) => [for (var at = 0; at < count; at += 2) (at, at + 1 < count ? at + 1 : null)];

/// The reader's count: `3 of 11`, or a spread's `2 – 3 of 11` (P21e, P21i).
String pageOf(int first, int? second, int count) => second == null ? '${first + 1} of $count' : '${first + 1} – ${second + 1} of $count';

/// The page count in a listed graphic novel's kind line, `Graphic novel · 11 pages`, before its
/// document is on the phone.
int? listedPages(String kind) => int.tryParse(RegExp(r'(\d+) pages?').firstMatch(kind)?.group(1) ?? '');

/// A tile's kind line, `Graphic novel · 24 pages` (P20a).
String comicTileKind(LibraryComic comic) => 'Graphic novel · ${pageCount(comic.pages)}';

/// An installed graphic novel, read (SPEC-064 R-50): its document, read against the package's own
/// manifest, and where each page's picture is on the phone.
class LoadedComic {
  const LoadedComic({required this.worldId, required this.worldName, required this.production, required this.document, required this.pathOf});

  final String worldId;
  final String worldName;
  final LibraryProduction production;
  final ComicDocument document;

  /// An asset id's file.
  final String Function(String assetId) pathOf;

  /// Every page in reading order, with the chapter it is in.
  List<({ComicPage page, int chapter})> get pages => [
    for (final (index, chapter) in document.chapters.indexed)
      for (final page in chapter.pages) (page: page, chapter: index),
  ];

  /// The first page's index of each chapter.
  List<int> get chapterStarts {
    final starts = <int>[];
    var at = 0;
    for (final chapter in document.chapters) {
      starts.add(at);
      at += chapter.pages.length;
    }
    return starts;
  }
}

/// A graphic novel of an installed world, by world and production id; null when it is not installed,
/// or its document cannot be read.
final loadedComicProvider = FutureProvider.family<LoadedComic?, (String, String)>((ref, key) async {
  final (worldId, productionId) = key;
  final world = ref.watch(installedWorldProvider(worldId));
  final production = world?.productions.where((production) => production.id == productionId).firstOrNull;
  final comic = production?.comic;
  final package = production?.package;
  if (world == null || production == null || comic == null || package == null) return null;
  final store = await ref.watch(libraryStoreProvider.future);
  final separator = Platform.pathSeparator;
  final folder = store.resolve(package.folder);
  try {
    final manifest = switch (readWorldManifest(await File('$folder$separator$worldManifestFile').readAsString())) {
      WorldManifestOk(:final manifest) => manifest,
      WorldManifestRefused() => null,
    };
    if (manifest == null) return null;
    final document = switch (readComic(await File(store.resolve(comic.document)).readAsString(), manifest.assets)) {
      ComicOk(:final document) => document,
      ComicRefused() => null,
    };
    if (document == null) return null;
    return LoadedComic(
      worldId: world.id,
      worldName: world.name,
      production: production,
      document: document,
      pathOf: (assetId) => '$folder$separator${manifest.assets[assetId]!.path.replaceAll('/', separator)}',
    );
  } on FileSystemException {
    return null;
  }
});

/// A graphic novel's first page, shown whole in its cover's place until it has one (P21 rule 1):
/// never a crop of it, and never the world's key art. Null until it is on the phone.
final comicFirstPageProvider = Provider.family<ImageProvider?, (String, String)>((ref, key) {
  final comic = ref.watch(loadedComicProvider(key)).value;
  final first = comic?.pages.firstOrNull;
  return comic == null || first == null ? null : FileImage(File(comic.pathOf(first.page.picture)));
});

/// The page a person is on in a graphic novel (P20 rule 8), kept with the stories' places in the
/// library's index, so it is written as atomically as a place is. Null before the first page turns.
final comicPageProvider = Provider.family<int?, (String, String)>((ref, key) {
  final saves = ref.watch(storySavesProvider).value;
  final page = saves?[LibraryStore.storyKey(key.$1, key.$2)]?['comicPage'];
  return page is int && page >= 0 ? page : null;
});

/// Keeps the page a person is on.
Future<void> keepComicPage(WidgetRef ref, String worldId, String productionId, int page) =>
    ref.read(storySavesProvider.notifier).keepPage(worldId, productionId, page);
