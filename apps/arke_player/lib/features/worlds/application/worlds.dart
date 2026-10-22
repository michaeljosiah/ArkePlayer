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
