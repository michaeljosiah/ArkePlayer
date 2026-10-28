import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../settings/application/settings_controller.dart';
import '../../worlds/application/worlds.dart';
import 'notices.dart';

/// `Chapter 24`, `Chapters 24–25`; `Episodes 41–45` for what is watched in episodes.
String chaptersLabel(List<CataloguePartChapter> chapters, {bool episodes = false}) {
  if (chapters.isEmpty) return episodes ? 'New episodes' : 'New chapters';
  final word = episodes ? 'Episode' : 'Chapter';
  final first = chapters.first.number;
  final last = chapters.last.number;
  return first == last ? '$word $first' : '${word}s $first–$last';
}

/// Whether the phone is on Wi-Fi, or a wired network, which a download needs while `Wi-Fi only`
/// is on (P6b, SPEC-058 R-51). Replaced in tests, which have no network to ask about.
final onWifiProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    final kinds = await Connectivity().checkConnectivity();
    return kinds.contains(ConnectivityResult.wifi) || kinds.contains(ConnectivityResult.ethernet);
  },
);

/// Where a part fetched by the daily check waits for the app to add it: beside the library, never
/// in it, as the check runs while the app may be writing the library's index.
Directory partInbox(Directory libraryRoot) => Directory('${libraryRoot.parent.path}${Platform.pathSeparator}parts-inbox');

File inboxFile(Directory inbox, String worldId, CataloguePart part) => File('${inbox.path}${Platform.pathSeparator}$worldId-${part.sha256}.zip');

/// A part on its way to an installed world (P15k), or a production published on its own (SPEC-058
/// R-72) — an album listed after the world was installed: coming, or waiting for Wi-Fi.
class PartArrival {
  const PartArrival({required this.world, this.part, this.production, this.step}) : assert((part == null) != (production == null));
  final CatalogueWorld world;
  final CataloguePart? part;
  final CatalogueProduction? production;

  /// Null while it waits.
  final InstallStep? step;

  bool get waiting => step == null;

  int get byteLength => part?.byteLength ?? production!.alone!.byteLength;

  /// Downloads' line: `Chapter 3 · 9 of 18 MB`, `Episodes 41–45 · 64 MB · Waiting`, or an album's
  /// title in place of the chapters.
  String line({bool episodes = false}) {
    final what = part == null ? production!.title : chaptersLabel(part!.chapters, episodes: episodes);
    return switch (step) {
      null => '$what · ${formatBytes(byteLength)} · Waiting',
      Downloading(:final received, :final total) => '$what · ${formatBytes(received)} of ${formatBytes(total)}',
      Copying() || Checking() => '$what · Checking',
    };
  }

  double? get fraction => switch (step) {
    Downloading(:final received, :final total) => total <= 0 ? 0 : received / total,
    Copying() || Checking() => 1,
    null => null,
  };
}

/// Adds every part Arke's list names that an installed world lacks, in order (SPEC-058 R-51): one
/// the daily check fetched ahead from where it waits, the rest downloaded when [mayDownload]. A world
/// whose next part cannot come waits, and its later parts with it; one refused is tried again at the
/// next check. [onAdded] hears each part added, and whether it had been fetched ahead.
///
/// Then each production published on its own that the list names and the world lacks (R-72), such
/// as an album listed after the world was installed, on the same terms. Only the app brings these:
/// the daily check fetches parts ahead, which an album, heard when chosen, does not need.
Future<void> addMissingParts({
  required List<CatalogueWorld> catalogue,
  required LibraryStore store,
  required WorldInstaller installer,
  required Directory inbox,
  required bool mayDownload,
  void Function(String worldId, PartArrival? arrival)? onProgress,
  Future<void> Function(CatalogueWorld world, CataloguePart part, {required bool ahead})? onAdded,
}) async {
  for (final world in store.worlds) {
    final listed = listedFor(catalogue, world.id);
    if (listed == null) continue;
    var waited = false;
    for (final part in missingParts(listed, world)) {
      final waiting = inboxFile(inbox, world.id, part);
      final ahead = await waiting.exists();
      if (!ahead && !mayDownload) {
        onProgress?.call(world.id, PartArrival(world: listed, part: part));
        waited = true;
        break;
      }
      try {
        onProgress?.call(world.id, PartArrival(world: listed, part: part, step: Downloading(0, part.byteLength)));
        await installer.installPart(
          listed,
          part,
          from: ahead ? waiting : null,
          onStep: (step) => onProgress?.call(world.id, PartArrival(world: listed, part: part, step: step)),
        );
        if (ahead) await waiting.delete();
        onProgress?.call(world.id, null);
        await onAdded?.call(listed, part, ahead: ahead);
      } on InstallRefusal {
        // A part fetched ahead that will not go in is fetched again next time.
        if (ahead && await waiting.exists()) await waiting.delete();
        onProgress?.call(world.id, null);
        break;
      }
    }
    if (waited) continue;
    // The installed world as the parts left it: a production names the edition it is beside.
    final current = store.worlds.where((held) => held.id == world.id).firstOrNull ?? world;
    for (final production in missingProductions(listed, current)) {
      if (!mayDownload) {
        onProgress?.call(world.id, PartArrival(world: listed, production: production));
        break;
      }
      try {
        onProgress?.call(world.id, PartArrival(world: listed, production: production, step: Downloading(0, production.alone!.byteLength)));
        await installer.installProduction(
          listed,
          production,
          onStep: (step) => onProgress?.call(world.id, PartArrival(world: listed, production: production, step: step)),
        );
        onProgress?.call(world.id, null);
      } on InstallRefusal {
        // Tried again at the next check; the rest of the world's music still comes.
        onProgress?.call(world.id, null);
      }
    }
  }
}

/// The parts on their way, by world (P15k), and the check that brings them: when the app opens or
/// comes back, and when Arke's list changes.
class PartsController extends Notifier<Map<String, PartArrival>> {
  bool _running = false;

  @override
  Map<String, PartArrival> build() => const {};

  Future<void> check() async {
    if (_running) return;
    _running = true;
    try {
      final catalogue = await ref.read(catalogueProvider.future);
      final store = await ref.read(libraryStoreProvider.future);
      final installer = await ref.read(worldInstallerProvider.future);
      final settings = await ref.read(settingsProvider.future);
      final root = await ref.read(libraryRootProvider.future);
      final mayDownload = !settings.wifiOnly || await ref.read(onWifiProvider)().catchError((Object _) => false);
      await addMissingParts(
        catalogue: catalogue,
        store: store,
        installer: installer,
        inbox: partInbox(root),
        mayDownload: mayDownload,
        onProgress: (worldId, arrival) => state = {
          for (final MapEntry(:key, :value) in state.entries)
            if (key != worldId) key: value,
          worldId: ?arrival,
        },
        onAdded: (world, part, {required ahead}) async {
          // A part the daily check fetched was told of then (R-54).
          if (ahead || !settings.notify.contains(world.id)) return;
          await ref.read(noticesProvider).chapterArrived(store, world, part);
        },
      );
    } on Object {
      // No list, no store or no connection: the next check tries again.
    } finally {
      _running = false;
    }
  }
}

final partsProvider = NotifierProvider<PartsController, Map<String, PartArrival>>(PartsController.new);
