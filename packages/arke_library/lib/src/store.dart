import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'item.dart';

/// The library on this device: one folder per item under `items/`, and `library.json` naming them.
///
/// The index is rewritten whole on every change, through a temporary file and a rename, so a crash
/// mid-write leaves the previous index rather than half of one. Writes are queued, never
/// interleaved. A file in `items/` that the index does not name is an add that never finished, and
/// [load] deletes it: nothing is ever half-added (P7 rule 3).
class LibraryStore {
  LibraryStore(this.root);

  final Directory root;

  File get _index => File('${root.path}${Platform.pathSeparator}library.json');
  Directory get _items => Directory('${root.path}${Platform.pathSeparator}items');

  List<LibraryItem> _cache = const [];
  Future<void> _queue = Future.value();
  final _changes = StreamController<List<LibraryItem>>.broadcast();

  /// Every change to the library, newest state first.
  Stream<List<LibraryItem>> get changes => _changes.stream;
  List<LibraryItem> get items => _cache;

  /// The folder an item's files live in.
  Directory itemDirectory(String id) => Directory('${_items.path}${Platform.pathSeparator}$id');

  /// The absolute path of a file named relative to the library's root.
  String resolve(String relative) => '${root.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

  Future<List<LibraryItem>> load() => _serial(() async {
    if (await _index.exists()) {
      final json = jsonDecode(await _index.readAsString()) as Map<String, Object?>;
      _cache = List.unmodifiable([for (final item in json['items']! as List<Object?>) LibraryItem.fromJson((item! as Map).cast<String, Object?>())]);
    }
    if (await _items.exists()) {
      final known = {for (final item in _cache) item.id};
      await for (final entry in _items.list()) {
        final name = entry.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
        if (entry is Directory && !known.contains(name)) await entry.delete(recursive: true);
      }
    }
    _changes.add(_cache);
    return _cache;
  });

  /// A new, unused item id, and its folder, ready to copy into before [add].
  Future<String> reserve() async {
    final random = Random.secure();
    final id = List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join();
    await itemDirectory(id).create(recursive: true);
    return id;
  }

  /// Adds an item whose files are already in its folder.
  Future<void> add(LibraryItem item) => _serial(() async {
    _cache = List.unmodifiable([item, ..._cache.where((existing) => existing.id != item.id)]);
    await _write();
  });

  /// Removes an item and deletes its files and its place.
  Future<void> remove(String id) => _serial(() async {
    _cache = List.unmodifiable(_cache.where((item) => item.id != id));
    await _write();
    final folder = itemDirectory(id);
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
      }),
      flush: true,
    );
    await temporary.rename(_index.path);
    _changes.add(_cache);
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> close() => _changes.close();
}
