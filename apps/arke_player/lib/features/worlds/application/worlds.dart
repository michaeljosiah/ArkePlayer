import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../players/application/players.dart';
import '../../settings/application/settings_controller.dart';

/// Arke's address for its list of worlds (SPEC-058 R-31, P12 rule 1): HTTPS, as a package is.
final arkeWorldsList = Uri.parse('https://github.com/michaeljosiah/ArkeStudio/releases/download/arke-player-worlds/catalogue.json');

/// The list fetched from [arkeWorldsList], kept beside the library.
final hostedCatalogueProvider = FutureProvider<HostedCatalogue>((ref) async {
  final root = await ref.watch(libraryRootProvider.future);
  return HostedCatalogue(url: arkeWorldsList, kept: File('${root.parent.path}${Platform.pathSeparator}catalogue.json'));
});

/// Arke's worlds (P9 rule 1, SPEC-058 R-31): of the list that ships with the app and the one last
/// fetched, the newer. A world whose package is not published yet is in the list but never offered.
final catalogueProvider = FutureProvider<List<CatalogueWorld>>((ref) async {
  final shipped = parseCatalogue(await rootBundle.loadString('assets/worlds/catalogue.json'));
  final hosted = await ref.watch(hostedCatalogueProvider.future);
  return newestCatalogue(shipped, await hosted.keptList()).worlds;
});

/// Discover's feature and band as Arke's list names them (P16 call 15), from the same newer list
/// [catalogueProvider] shows; the shipped list's alone when the kept one cannot be read. Discover
/// falls back to its own choice while this is unread.
final listPicksProvider = FutureProvider<({CatalogueFeature? feature, String? band})>((ref) async {
  ref.watch(catalogueProvider);
  final shipped = parseCatalogue(await rootBundle.loadString('assets/worlds/catalogue.json'));
  Catalogue? kept;
  try {
    kept = await (await ref.watch(hostedCatalogueProvider.future)).keptList();
  } on Object {
    kept = null;
  }
  final newest = newestCatalogue(shipped, kept);
  return (feature: newest.feature, band: newest.band);
});

/// Where the pictures Arke's list pins are kept (SPEC-058 rev 10), beside the library as the list is.
final pictureKeeperProvider = FutureProvider<PictureKeeper>((ref) async {
  final root = await ref.watch(libraryRootProvider.future);
  return PictureKeeper(folder: Directory('${root.parent.path}${Platform.pathSeparator}pictures'));
});

/// The pictures kept, by digest (SPEC-058 rev 10): what a row shows in place of the bundled one. It
/// grows as each picture arrives, so every row showing it changes without a restart.
final keptPicturesProvider = AsyncNotifierProvider<KeptPictures, Map<String, File>>(KeptPictures.new);

class KeptPictures extends AsyncNotifier<Map<String, File>> {
  var _generation = 0;
  Future<void> _running = Future.value();

  @override
  Future<Map<String, File>> build() async => (await ref.watch(pictureKeeperProvider.future)).kept();

  /// Keeps the pictures [worlds] pin: fetches each one not yet kept, one at a time and on any
  /// network — they are small, as the list is; `Wi-Fi only` is for worlds — and deletes those no
  /// list names any more. A newer list waits for the picture in hand, then the older one stops.
  /// A picture that does not come is simply not there yet: its row keeps the bundled one.
  Future<void> keepFor(Iterable<CatalogueWorld> worlds) {
    final generation = ++_generation;
    final pins = pinsOf(worlds);
    return _running = _running
        .then((_) async {
          if (generation != _generation) return;
          await future;
          final keeper = await ref.read(pictureKeeperProvider.future);
          await keeper.keep(
            pins,
            stopped: () => generation != _generation || !ref.mounted,
            onKept: (pin, file) {
              if (ref.mounted) state = AsyncData({...?state.value, pin.sha256: file});
            },
          );
          // What the list no longer names went with it.
          final kept = await keeper.kept();
          if (ref.mounted) state = AsyncData(kept);
        })
        .catchError((Object _) {});
  }
}

/// Asks Arke's address for its list once a launch, when Worlds or a world's page opens; the hosted
/// list itself asks at most once a day. A newer list replaces the one shown. Never under test, which
/// must not reach the network.
final catalogueRefreshProvider = FutureProvider<void>((ref) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  final hosted = await ref.read(hostedCatalogueProvider.future);
  final before = (await hosted.keptList())?.serial;
  final after = (await hosted.refresh())?.serial;
  if (after != before) ref.invalidate(catalogueProvider);
});

/// P13: explicit checks share one state across navigation and never overlap the startup check.
enum CatalogueCheck { idle, checking, checked, failed }

final catalogueCheckProvider = NotifierProvider<CatalogueCheckController, CatalogueCheck>(CatalogueCheckController.new);

class CatalogueCheckController extends Notifier<CatalogueCheck> {
  @override
  CatalogueCheck build() => CatalogueCheck.idle;

  Future<void> check() async {
    if (state == CatalogueCheck.checking) return;
    state = CatalogueCheck.checking;
    try {
      // Finish any automatic fetch before forcing one, so an older response cannot overwrite it.
      await ref.read(catalogueRefreshProvider.future).catchError((Object _) {});
      final hosted = await ref.read(hostedCatalogueProvider.future);
      await hosted.refresh(force: true);
      ref.invalidate(catalogueProvider);
      await ref.read(catalogueProvider.future);
      state = CatalogueCheck.checked;
    } on Object {
      state = CatalogueCheck.failed;
    }
  }
}

/// The installed world an address names: the world of that id, or the one Arke's list says replaced
/// it (SPEC-058 R-30), so a page opened under a world's old id, or left open while it was updated
/// to a new one, still finds it.
final installedWorldProvider = Provider.family<LibraryWorld?, String>((ref, worldId) {
  final worlds = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
  final own = worlds.where((world) => world.id == worldId).firstOrNull;
  if (own != null) return own;
  final successor = ref.watch(catalogueProvider).value?.where((world) => world.replaces.contains(worldId)).firstOrNull;
  return successor == null ? null : worlds.where((world) => world.id == successor.id).firstOrNull;
});

/// The newer edition Arke's list names for an installed world, if any (SPEC-058 R-30, R-32, P12
/// rule 2): its own entry's, or the entry of a world that replaces its id. Its install runs under
/// the listed id, so Downloads and every card follow the one install.
final worldUpdateProvider = Provider.family<CatalogueWorld?, String>((ref, worldId) {
  final installed = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
  final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], worldId);
  return installed != null && listed != null && hasUpdate(listed, installed) ? listed : null;
});

/// Every installed world, kept current as worlds are installed and removed.
final libraryWorldsProvider = StreamProvider<List<LibraryWorld>>((ref) async* {
  final store = await ref.watch(libraryStoreProvider.future);
  yield store.worlds;
  yield* store.worldChanges;
});

/// Available (P9 rule 2): every published world not installed. Empty, and so absent everywhere,
/// when there is nothing left to install.
final availableProvider = Provider<List<CatalogueWorld>>(
  (ref) => availableWorlds(ref.watch(catalogueProvider).value ?? const [], ref.watch(libraryWorldsProvider).value ?? const []),
);

final worldInstallerProvider = FutureProvider<WorldInstaller>((ref) async {
  final store = await ref.watch(libraryStoreProvider.future);
  return WorldInstaller(store: store, freeBytes: ref.watch(storageInfoProvider).freeBytes);
});

/// Where one world's install is.
sealed class InstallState {
  const InstallState();
}

class NotInstalling extends InstallState {
  const NotInstalling();
}

class Installing extends InstallState {
  const Installing(this.step, {this.updating = false});
  final InstallStep step;

  /// A newer edition coming in over an installed one (P12).
  final bool updating;

  /// The whole install, 0 to 1: the download is most of it, the check the rest.
  double get fraction => switch (step) {
    Downloading(:final received, :final total) => total <= 0 ? 0 : 0.9 * received / total,
    Copying(:final copied, :final total) => total <= 0 ? 0 : 0.9 * copied / total,
    Checking(:final checked, :final total) => total <= 0 ? 0.9 : 0.9 + 0.1 * checked / total,
  };

  /// The page's line (P9d): what is happening, as data.
  String get line => switch (step) {
    Downloading(:final received, :final total) => 'Downloading · ${formatBytes(received)} of ${formatBytes(total)}',
    Copying(:final copied, :final total) => '${formatBytes(copied)} of ${formatBytes(total)}',
    Checking(:final checked, :final total) => 'Checking · $checked of $total files',
  };

  /// Home's card and Downloads (P9 rule 4, P12e).
  String get short => '${updating ? 'Updating' : 'Installing'} · ${(fraction * 100).floor()}%';
}

class InstallFailed extends InstallState {
  const InstallFailed(this.refusal);
  final InstallRefusal refusal;
}

/// One world's install, or its update (P12). It is not disposed with its page: leaving the page
/// does not stop it, and Home and Downloads show it going on (P9 rule 4).
class InstallController extends Notifier<InstallState> {
  InstallController(this.worldId);

  final String worldId;
  InstallCancel? _cancel;

  @override
  InstallState build() => const NotInstalling();

  Future<void> start(CatalogueWorld world) async {
    if (state is Installing) return;
    final cancel = _cancel = InstallCancel();
    final updating = ref.read(libraryWorldsProvider).value?.any((installed) => world.covers(installed.id)) ?? false;
    state = Installing(Downloading(0, world.package?.byteLength ?? 0), updating: updating);
    try {
      final installer = await ref.read(worldInstallerProvider.future);
      void onStep(InstallStep step) {
        if (!cancel.isCancelled) state = Installing(step, updating: updating);
      }

      if (updating) {
        await installer.update(world, cancel: cancel, onStep: onStep, beforeSwap: () => _released(world));
      } else {
        await installer.install(world, cancel: cancel, onStep: onStep);
      }
      state = const NotInstalling();
      // Once a world is in, later opens land on Home rather than first open (P8a).
      await ref.read(settingsProvider.notifier).change((settings) => settings.copyWith(seenFirstOpen: true));
    } on InstallCancelled {
      state = const NotInstalling();
    } on InstallRefusal catch (refusal) {
      state = InstallFailed(refusal);
    } on Object {
      // Anything unforeseen still ends the install with nothing kept; say only that it stopped.
      state = const InstallFailed(DownloadStopped());
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// Waits while anything of the world plays, then lets go of it, so the new edition's files are the
  /// ones its next play opens; the place is kept as it stops (P12 rule 4).
  Future<void> _released(CatalogueWorld world) async {
    final engine = ref.read(audioEngineProvider);
    bool held() {
      final id = engine?.item?.worldId;
      return id != null && world.covers(id);
    }

    if (engine == null || !held()) return;
    if (engine.playing) await engine.playingStream.firstWhere((playing) => !playing || !held());
    if (held()) await engine.stop();
  }

  /// Cancel deletes what has come (P9 rule 4).
  void cancel() {
    _cancel?.cancel();
    state = const NotInstalling();
  }

  /// Close on a refusal.
  void dismiss() {
    if (state is InstallFailed) state = const NotInstalling();
  }
}

final installProvider = NotifierProvider.family<InstallController, InstallState, String>(InstallController.new);

/// The newer package Arke's list names for an installed production published on its own (SPEC-058
/// R-72), by world and production id: that production's `Update`.
final productionUpdateProvider = Provider.family<CatalogueProduction?, (String, String)>((ref, key) {
  final (worldId, productionId) = key;
  final installed = ref.watch(installedWorldProvider(worldId));
  final listed = listedFor(ref.watch(catalogueProvider).value ?? const [], worldId);
  if (installed == null || listed == null) return null;
  return productionUpdates(listed, installed).where((production) => installedProduction(production, installed)?.id == productionId).firstOrNull;
});

/// One production package's Update, by world and production id (R-72): pressed, as an edition's is
/// (P12 call 9). Like a world's install, it outlives its page.
class ProductionInstallController extends Notifier<InstallState> {
  ProductionInstallController(this.key);

  final (String, String) key;
  InstallCancel? _cancel;

  @override
  InstallState build() => const NotInstalling();

  Future<void> start(CatalogueWorld world, CatalogueProduction production) async {
    if (state is Installing) return;
    final cancel = _cancel = InstallCancel();
    state = Installing(Downloading(0, production.alone?.byteLength ?? 0), updating: true);
    try {
      final installer = await ref.read(worldInstallerProvider.future);
      await installer.installProduction(
        world,
        production,
        cancel: cancel,
        onStep: (step) {
          if (!cancel.isCancelled) state = Installing(step, updating: true);
        },
        beforeSwap: _released,
      );
      state = const NotInstalling();
    } on InstallCancelled {
      state = const NotInstalling();
    } on InstallRefusal catch (refusal) {
      state = InstallFailed(refusal);
    } on Object {
      state = const InstallFailed(DownloadStopped());
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// Waits while the album plays, then lets go of it, so its next play opens the new files.
  Future<void> _released() async {
    final engine = ref.read(audioEngineProvider);
    bool held() => engine?.music?.worldId == key.$1 && engine?.music?.production.id == key.$2;
    if (engine == null || !held()) return;
    if (engine.playing) await engine.playingStream.firstWhere((playing) => !playing || !held());
    if (held()) await engine.stop();
  }

  void cancel() {
    _cancel?.cancel();
    state = const NotInstalling();
  }

  void dismiss() {
    if (state is InstallFailed) state = const NotInstalling();
  }
}

final productionInstallProvider = NotifierProvider.family<ProductionInstallController, InstallState, (String, String)>(ProductionInstallController.new);
