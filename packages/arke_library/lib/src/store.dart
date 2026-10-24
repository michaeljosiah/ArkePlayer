import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'item.dart';
import 'world.dart';

/// The library on this device: one folder per item under `items/`, one per installed world under
/// `worlds/`, one per world's guide fetched on its own under `guides/`, and `library.json` naming
/// them, with the places reached and what has been revealed.
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
  Directory get _guides => Directory('${root.path}${Platform.pathSeparator}guides');

  List<LibraryItem> _cache = const [];
  List<LibraryWorld> _worldCache = const [];
  List<LibraryGuide> _guideCache = const [];
  Map<String, Map<String, int>> _revealed = const {};
  Future<void> _queue = Future.value();
  final _changes = StreamController<List<LibraryItem>>.broadcast();
  final _worldChanges = StreamController<List<LibraryWorld>>.broadcast();
  final _guideChanges = StreamController<void>.broadcast();

  /// Every change to the library's items, newest state first.
  Stream<List<LibraryItem>> get changes => _changes.stream;
  List<LibraryItem> get items => _cache;

  /// Every change to the installed worlds.
  Stream<List<LibraryWorld>> get worldChanges => _worldChanges.stream;
  List<LibraryWorld> get worlds => _worldCache;

  /// Every change to the guides fetched on their own or to what has been revealed.
  Stream<void> get guideChanges => _guideChanges.stream;

  /// The guides fetched before their worlds were installed (SPEC-059 R-10).
  List<LibraryGuide> get guides => _guideCache;

  /// What a person chose to see before reaching it (SPEC-059 R-20, R-21): by world, then by
  /// production, the chapter number revealed through. Kept here with the places, never sent.
  Map<String, Map<String, int>> get revealed => _revealed;

  /// The folder an item's files live in.
  Directory itemDirectory(String id) => Directory('${_items.path}${Platform.pathSeparator}$id');

  /// The folder an installed world's files live in.
  Directory worldDirectory(String id) => Directory('${_worlds.path}${Platform.pathSeparator}$id');

  /// The folder a world's guide, fetched on its own, lives in.
  Directory guideDirectory(String worldId) => Directory('${_guides.path}${Platform.pathSeparator}$worldId');

  /// The absolute path of a file named relative to the library's root.
  String resolve(String relative) => '${root.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

  Future<List<LibraryItem>> load() => _serial(() async {
    if (await _index.exists()) {
      final json = jsonDecode(await _index.readAsString()) as Map<String, Object?>;
      _cache = List.unmodifiable([for (final item in json['items']! as List<Object?>) LibraryItem.fromJson((item! as Map).cast<String, Object?>())]);
      _worldCache = List.unmodifiable([
        for (final world in (json['worlds'] as List<Object?>? ?? const [])) LibraryWorld.fromJson((world! as Map).cast<String, Object?>()),
      ]);
      _guideCache = List.unmodifiable([
        for (final guide in (json['guides'] as List<Object?>? ?? const [])) LibraryGuide.fromJson((guide! as Map).cast<String, Object?>()),
      ]);
      _revealed = Map.unmodifiable({
        for (final MapEntry(:key, :value) in ((json['revealed'] as Map?)?.cast<String, Object?>() ?? const {}).entries)
          key: Map<String, int>.unmodifiable((value! as Map).cast<String, int>()),
      });
    }
    await _clearUnknown(_items, {for (final item in _cache) item.id});
    await _clearUnknown(_worlds, {for (final world in _worldCache) world.id});
    await _clearUnknown(_guides, {for (final guide in _guideCache) guide.worldId});
    _changes.add(_cache);
    _worldChanges.add(_worldCache);
    _guideChanges.add(null);
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

  /// A fresh folder beside the guides to download and check a guide in, cleared by [load] if a
  /// crash leaves it.
  Future<Directory> stageGuide() async {
    final folder = Directory('${_guides.path}${Platform.pathSeparator}.fetching-${_randomId()}');
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
  ///
  /// Replacing an installed edition (P10) keeps each item's place where the new edition has an
  /// item of the same id, and drops the old edition's other items with their places.
  Future<void> addWorld(LibraryWorld world, List<LibraryItem> worldItems, Directory staged) => _serial(() async {
    final folder = worldDirectory(world.id);
    if (await folder.exists()) await folder.delete(recursive: true);
    await staged.rename(folder.path);
    final before = {
      for (final item in _cache)
        if (item.worldId == world.id) item.id: item,
    };
    final carried = [
      for (final item in worldItems)
        if (before[item.id]?.place case final place?) item.copyWith(place: place, finished: before[item.id]!.finished) else item,
    ];
    final ids = {for (final item in carried) item.id};
    _cache = List.unmodifiable([...carried, ..._cache.where((existing) => existing.worldId != world.id && !ids.contains(existing.id))]);
    _worldCache = List.unmodifiable([world, ..._worldCache.where((existing) => existing.id != world.id)]);
    // A package that carries the guide supersedes the guide fetched alone (SPEC-059 R-10).
    final superseded = world.guide != null && _guideCache.any((guide) => guide.worldId == world.id);
    if (superseded) _guideCache = List.unmodifiable(_guideCache.where((guide) => guide.worldId != world.id));
    await _write();
    if (superseded && await guideDirectory(world.id).exists()) await guideDirectory(world.id).delete(recursive: true);
  });

  /// Adds a part to an installed world (SPEC-058 R-51): moves its checked files from [staged] into
  /// the world's folder at [part]'s folder, then names the world as it now is and the items the part
  /// changed or brought in one write of the index. Nothing playing is touched: an item keeps the
  /// place the caller gives it.
  Future<void> addPart(LibraryWorld world, LibraryPart part, List<LibraryItem> changed, Directory staged) => _serial(() async {
    final folder = Directory(resolve(part.folder));
    if (await folder.exists()) await folder.delete(recursive: true);
    await folder.parent.create(recursive: true);
    await staged.rename(folder.path);
    final ids = {for (final item in changed) item.id};
    _cache = List.unmodifiable([
      ..._cache.map((item) => ids.contains(item.id) ? changed.firstWhere((next) => next.id == item.id) : item),
      ...changed.where((item) => !_cache.any((existing) => existing.id == item.id)),
    ]);
    _worldCache = List.unmodifiable([for (final existing in _worldCache) existing.id == world.id ? world : existing]);
    await _write();
  });

  /// Keeps a world's guide fetched on its own, whose checked files are in [staged], replacing an
  /// earlier one.
  Future<void> addGuide(LibraryGuide guide, Directory staged) => _serial(() async {
    final folder = guideDirectory(guide.worldId);
    if (await folder.exists()) await folder.delete(recursive: true);
    await folder.parent.create(recursive: true);
    await staged.rename(folder.path);
    _guideCache = List.unmodifiable([guide, ..._guideCache.where((existing) => existing.worldId != guide.worldId)]);
    await _write();
  });

  /// Reveals everything in a production of a world up to and including chapter [number]; what is
  /// revealed stays revealed (SPEC-059 R-20).
  Future<void> reveal(String worldId, String productionId, int number) => _serial(() async {
    final world = _revealed[worldId] ?? const <String, int>{};
    if ((world[productionId] ?? 0) >= number) return;
    _revealed = Map.unmodifiable({
      ..._revealed,
      worldId: Map<String, int>.unmodifiable({...world, productionId: number}),
    });
    await _write();
  });

  /// Removes an item and deletes its files and its place.
  Future<void> remove(String id) => _serial(() async {
    _cache = List.unmodifiable(_cache.where((item) => item.id != id));
    await _write();
    final folder = itemDirectory(id);
    if (await folder.exists()) await folder.delete(recursive: true);
  });

  /// Removes an installed world, its items, their places and what was revealed, and deletes its
  /// files (P9 rule 6).
  Future<void> removeWorld(String id) => _serial(() async {
    _cache = List.unmodifiable(_cache.where((item) => item.worldId != id));
    _worldCache = List.unmodifiable(_worldCache.where((world) => world.id != id));
    _revealed = Map.unmodifiable({..._revealed}..remove(id));
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
        if (_guideCache.isNotEmpty) 'guides': [for (final guide in _guideCache) guide.toJson()],
        if (_revealed.isNotEmpty) 'revealed': _revealed,
      }),
      flush: true,
    );
    await temporary.rename(_index.path);
    _changes.add(_cache);
    _worldChanges.add(_worldCache);
    _guideChanges.add(null);
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> close() async {
    await _changes.close();
    await _worldChanges.close();
    await _guideChanges.close();
  }
}
