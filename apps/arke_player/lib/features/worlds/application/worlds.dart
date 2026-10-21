import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../settings/application/settings_controller.dart';

/// The worlds that ship with the app (P9 rule 1). A world whose package is not published yet is
/// in the list but never offered.
final catalogueProvider = FutureProvider<List<CatalogueWorld>>((ref) async => readCatalogue(await rootBundle.loadString('assets/worlds/catalogue.json')));

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
  const Installing(this.step);
  final InstallStep step;

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

  /// Home's card and Downloads (P9 rule 4).
  String get short => 'Installing · ${(fraction * 100).floor()}%';
}

class InstallFailed extends InstallState {
  const InstallFailed(this.refusal);
  final InstallRefusal refusal;
}

/// One world's install. It is not disposed with its page: leaving the page does not stop it, and
/// Home and Downloads show it going on (P9 rule 4).
class InstallController extends Notifier<InstallState> {
  InstallController(this.worldId);

  final String worldId;
  InstallCancel? _cancel;

  @override
  InstallState build() => const NotInstalling();

  Future<void> start(CatalogueWorld world) async {
    if (state is Installing) return;
    final cancel = _cancel = InstallCancel();
    state = Installing(Downloading(0, world.package?.byteLength ?? 0));
    try {
      final installer = await ref.read(worldInstallerProvider.future);
      await installer.install(
        world,
        cancel: cancel,
        onStep: (step) {
          if (!cancel.isCancelled) state = Installing(step);
        },
      );
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
