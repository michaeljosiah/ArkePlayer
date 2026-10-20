import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'item.dart';
import 'world.dart';

/// The library on this device: one folder per item under `items/`, one per installed world under
/// `worlds/`, and `library.json` naming them.
///
/// The index is rewritten whole on every change, through a temporary file and a rename, so a crash
/// mid-write leaves the previous index rather than half of one. Writes are queued, never
/// interleaved. A folder in `items/` or `worlds/` that the index does not name is an add or an
/// install that never finished, and [load] deletes it: nothing is ever half-added (P7 rule 3,
/// P9 rule 5).
class LibraryStore {
  LibraryStore(this.root);

  final Directory root;

  File get _index => File('${root.path}${Platform.pathSeparator}library.json');
  Directory get _items => Directory('${root.path}${Platform.pathSeparator}items');
  Directory get _worlds => Directory('${root.path}${Platform.pathSeparator}worlds');

  List<LibraryItem> _cache = const [];
  List<LibraryWorld> _worldCache = const [];
  Future<void> _queue = Future.value();
  final _changes = StreamController<List<LibraryItem>>.broadcast();
  final _worldChanges = StreamController<List<LibraryWorld>>.broadcast();

  /// Every change to the library's items, newest state first.
  Stream<List<LibraryItem>> get changes => _changes.stream;
  List<LibraryItem> get items => _cache;

  /// Every change to the installed worlds.
  Stream<List<LibraryWorld>> get worldChanges => _worldChanges.stream;
  List<LibraryWorld> get worlds => _worldCache;

  /// The folder an item's files live in.
  Directory itemDirectory(String id) => Directory('${_items.path}${Platform.pathSeparator}$id');

  /// The folder an installed world's files live in.
  Directory worldDirectory(String id) => Directory('${_worlds.path}${Platform.pathSeparator}$id');

  /// The absolute path of a file named relative to the library's root.
  String resolve(String relative) => '${root.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

  Future<List<LibraryItem>> load() => _serial(() async {
    if (await _index.exists()) {
      final json = jsonDecode(await _index.readAsString()) as Map<String, Object?>;
      _cache = List.unmodifiable([for (final item in json['items']! as List<Object?>) LibraryItem.fromJson((item! as Map).cast<String, Object?>())]);
      _worldCache = List.unmodifiable([
        for (final world in (json['worlds'] as List<Object?>? ?? const [])) LibraryWorld.fromJson((world! as Map).cast<String, Object?>()),
      ]);
    }
    await _clearUnknown(_items, {for (final item in _cache) item.id});
    await _clearUnknown(_worlds, {for (final world in _worldCache) world.id});
    _changes.add(_cache);
    _worldChanges.add(_worldCache);
    return _cache;
  });

  static Future<void> _clearUnknown(Directory parent, Set<String> known) async {
    if (!await parent.exists()) return;
    await for (final entry in parent.list()) {
      final name = entry.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      if (entry is Directory && !known.contains(name)) await entry.delete(recursive: true);
    }
  }

  /// A new, unused item id, and its folder, ready to copy into before [add].
  Future<String> reserve() async {
    final id = _randomId();
    await itemDirectory(id).create(recursive: true);
    return id;
  }

  /// A fresh folder beside the installed worlds to download and check a world in. Its name is
  /// never a world's, so a crash leaves a folder [load] clears.
  Future<Directory> stageWorld() async {
    final folder = Directory('${_worlds.path}${Platform.pathSeparator}.installing-${_randomId()}');
    await folder.create(recursive: true);
    return folder;
  }

  static String _randomId() {
    final random = Random.secure();
    return List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join();
  }

  /// Adds an item whose files are already in its folder.
  Future<void> add(LibraryItem item) => _serial(() async {
    _cache = List.unmodifiable([item, ..._cache.where((existing) => existing.id != item.id)]);
    await _write();
  });

  /// Installs a world whose checked files are in [staged]: moves them to the world's folder, then
  /// names the world and its items in one write of the index. Items' paths are relative to the
  /// library's root, under `worlds/<id>/`.
  Future<void> addWorld(LibraryWorld world, List<LibraryItem> worldItems, Directory staged) => _serial(() async {
    final folder = worldDirectory(world.id);
    if (await folder.exists()) await folder.delete(recursive: true);
    await staged.rename(folder.path);
    final ids = {for (final item in worldItems) item.id};
    _cache = List.unmodifiable([...worldItems, ..._cache.where((existing) => !ids.contains(existing.id))]);
    _worldCache = List.unmodifiable([world, ..._worldCache.where((existing) => existing.id != world.id)]);
    await _write();
  });

  /// Removes an item and deletes its files and its place.
  Future<void> remove(String id) => _serial(() async {
    _cache = List.unmodifiable(_cache.where((item) => item.id != id));
    await _write();
    final folder = itemDirectory(id);
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  /// Removes an installed world, its items and their places, and deletes its files (P9 rule 6).
  Future<void> removeWorld(String id) => _serial(() async {
    _cache = List.unmodifiable(_cache.where((item) => item.worldId != id));
    _worldCache = List.unmodifiable(_worldCache.where((world) => world.id != id));
    await _write();
    final folder = worldDirectory(id);
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  /// Abandons a reserved folder whose file was refused or cancelled.
  Future<void> discard(String id) async {
    if (_cache.any((item) => item.id == id)) return;
    final folder = itemDirectory(id);
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  /// Keeps where a person is in an item.
  Future<void> keepPlace(String id, Place place, {bool? finished}) => _serial(() async {
    _cache = List.unmodifiable([for (final item in _cache) item.id == id ? item.copyWith(place: place, finished: finished) : item]);
    await _write();
  });

  Future<void> _write() async {
    await root.create(recursive: true);
    final temporary = File('${_index.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'items': [for (final item in _cache) item.toJson()],
        if (_worldCache.isNotEmpty) 'worlds': [for (final world in _worldCache) world.toJson()],
      }),
      flush: true,
    );
    await temporary.rename(_index.path);
    _changes.add(_cache);
    _worldChanges.add(_worldCache);
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> close() async {
    await _changes.close();
    await _worldChanges.close();
  }
}
