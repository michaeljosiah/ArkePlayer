import 'dart:io';
import 'dart:isolate';

import 'package:arke_library/arke_library.dart';
import 'package:arke_media/arke_media.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/services.dart';
import '../../players/application/listening_plan.dart';
import '../../players/application/players.dart';
import 'worlds.dart';

/// A world's guide as this phone has it, with its files resolved (SPEC-059 R-18).
class WorldGuide {
  const WorldGuide({required this.guide, required this.pathOf});

  final Guide guide;

  /// The file an asset of the guide's package is on this phone.
  final String Function(String assetId) pathOf;

  /// The picture for an entry, portrait or picture, if it has one.
  String? pictureOf(GuideEntry entry) => switch (entry) {
    GuideCharacter(:final portrait?) => pathOf(portrait),
    GuidePlace(:final picture?) => pathOf(picture),
    _ => null,
  };
}

/// Every change to the guides kept on their own and to what has been revealed, counted: a stream
/// of the same value would be one change, as Riverpod tells only of a value that differs.
final _guideChangesProvider = StreamProvider<int>((ref) async* {
  final store = await ref.watch(libraryStoreProvider.future);
  var changes = 0;
  yield changes;
  await for (final _ in store.guideChanges) {
    yield ++changes;
  }
});

/// A world's guide: the installed package's, else the guide fetched alone, else none. A guide that
/// cannot be read draws as none, as a guide never fetched does offline (R-22).
final worldGuideProvider = FutureProvider.family<WorldGuide?, String>((ref, worldId) async {
  ref.watch(_guideChangesProvider);
  final installed = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
  final store = await ref.watch(libraryStoreProvider.future);
  final kept = store.guides.where((guide) => guide.worldId == worldId).firstOrNull;
  final (folder, document) = switch ((installed?.guide, kept)) {
    (final String guide, _) => (store.worldDirectory(worldId), guide),
    (_, final LibraryGuide kept) => (store.guideDirectory(worldId), kept.guide),
    _ => (null, null),
  };
  if (folder == null || document == null) return null;
  try {
    final separator = Platform.pathSeparator;
    final manifest = switch (readWorldManifest(await File('${folder.path}$separator$worldManifestFile').readAsString())) {
      WorldManifestOk(:final manifest) => manifest,
      WorldManifestRefused() => null,
    };
    if (manifest == null) return null;
    final guide = switch (readGuide(await File(store.resolve(document)).readAsString(), manifest.assets)) {
      GuideOk(:final guide) => guide,
      GuideRefused() => null,
    };
    if (guide == null) return null;
    return WorldGuide(guide: guide, pathOf: (assetId) => '${folder.path}$separator${manifest.assets[assetId]!.path.replaceAll('/', separator)}');
  } on FileSystemException {
    return null;
  }
});

/// The guide alone, fetched the first time a world's page opens and kept (SPEC-059 R-10, R-18):
/// only for a world whose installed package carries none, and only once for its pin. Offline it
/// fails quietly, and the page draws no guide (R-22); the next visit tries again.
final guideFetchProvider = FutureProvider.autoDispose.family<void, String>((ref, worldId) async {
  final world = (await ref.watch(catalogueProvider.future)).where((world) => world.id == worldId).firstOrNull;
  final installed = (await ref.watch(libraryWorldsProvider.future)).where((world) => world.id == worldId).firstOrNull;
  if (world?.guide == null || installed?.guide != null) return;
  try {
    final installer = await ref.read(worldInstallerProvider.future);
    await installer.fetchGuide(world!);
  } on Object {
    // No connection, or a guide that is not its pin: nothing is kept, and nothing is said.
  }
});

/// What of a world's guide this phone may show (SPEC-059 R-20, R-21): where its places are in each
/// production the guide names, heard or read, with what the person revealed. A world not installed
/// has no places, so only what was revealed shows.
final guideReachProvider = FutureProvider.family<GuideReach, String>((ref, worldId) async {
  ref.watch(_guideChangesProvider);
  final guide = (await ref.watch(worldGuideProvider(worldId).future))?.guide;
  final store = await ref.watch(libraryStoreProvider.future);
  final revealed = store.revealed[worldId] ?? const {};
  final installed = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
  if (guide == null || installed == null) return GuideReach(revealed: revealed);
  final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};

  final reached = <String, Reached>{};
  for (final production in guide.productions) {
    final held = installed.productions.where((held) => held.id == production.id).firstOrNull;
    if (held == null) continue;
    final narration = items[held.narration];
    final book = items[held.book];
    ListeningDocument? listening;
    if (narration?.format == FileFormat.listening) {
      try {
        listening = (await loadListeningPlan(store, narration!)).document;
      } on Object {
        listening = null;
      }
    }
    var spine = const <String>[];
    if (book?.place?.locator != null) {
      final path = store.resolve(book!.file);
      try {
        spine = await Isolate.run(() => readEpubSpineAt(path));
      } on Object {
        spine = const [];
      }
    }
    reached[production.id] = reachedIn(production, listening: listening, narration: narration, book: book, spine: spine);
  }
  return GuideReach(reached: reached, revealed: revealed);
});

/// Reveal (P11h): everything in the production up to and including that chapter.
Future<void> reveal(WidgetRef ref, String worldId, GuideAfter after) async {
  final store = await ref.read(libraryStoreProvider.future);
  await store.reveal(worldId, after.production, after.number);
}

/// The world's name, installed or in the list, for a guide page's meta line.
final worldNameProvider = Provider.family<String?, String>(
  (ref, worldId) =>
      ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull?.name ??
      ref.watch(catalogueProvider).value?.where((world) => world.id == worldId).firstOrNull?.name,
);

/// Plays a character's line in their voice (P11d), pausing the narration first so the two never
/// speak at once. Replaced in tests, which never play.
final voiceLineProvider = Provider<Future<void> Function(String path)>((ref) {
  AudioPlayer? player;
  ref.onDispose(() => player?.dispose());
  return (path) async {
    await ref.read(audioEngineProvider)?.pause();
    final line = player ??= AudioPlayer();
    await line.setFilePath(path);
    await line.play();
  };
});
