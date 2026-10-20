import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where the library lives: the app's own support directory, never shared storage, so a file
/// added is the Player's copy and Remove deletes only that copy.
final libraryRootProvider = FutureProvider<Directory>((ref) async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}${Platform.pathSeparator}library');
});

/// The library, loaded once. Unfinished adds left by a crash are cleared as it loads.
final libraryStoreProvider = FutureProvider<LibraryStore>((ref) async {
  final store = LibraryStore(await ref.watch(libraryRootProvider.future));
  await store.load();
  ref.onDispose(store.close);
  return store;
});

/// Every item, kept current as items are added, removed and played.
final libraryItemsProvider = StreamProvider<List<LibraryItem>>((ref) async* {
  final store = await ref.watch(libraryStoreProvider.future);
  yield store.items;
  yield* store.changes;
});

/// The free space on the volume the library lives on.
abstract interface class StorageInfo {
  Future<int?> freeBytes(String path);
  Future<int?> totalBytes(String path);
}

class PlatformStorageInfo implements StorageInfo {
  const PlatformStorageInfo();

  static const _channel = MethodChannel('studio.arke.player/storage');

  @override
  Future<int?> freeBytes(String path) => _ask('freeBytes', path);

  @override
  Future<int?> totalBytes(String path) => _ask('totalBytes', path);

  Future<int?> _ask(String method, String path) async {
    try {
      return await _channel.invokeMethod<int>(method, {'path': path});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final storageInfoProvider = Provider<StorageInfo>((ref) => const PlatformStorageInfo());

/// The app's version, as About shows it (P8f). Kept beside the pubspec's `version`.
const appVersion = '0.1.0';

/// The volume's free and total space, for Downloads (P6a) and You (P8f).
final volumeProvider = FutureProvider.autoDispose<({int? free, int? total})>((ref) async {
  ref.watch(libraryItemsProvider);
  final root = await ref.watch(libraryRootProvider.future);
  final storage = ref.watch(storageInfoProvider);
  return (free: await storage.freeBytes(root.parent.path), total: await storage.totalBytes(root.parent.path));
});
