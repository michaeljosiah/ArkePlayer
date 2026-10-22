import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:test/test.dart';

LibraryItem _item(String id, {FileFormat format = FileFormat.m4b, DateTime? addedAt}) => LibraryItem(
  id: id,
  format: format,
  title: 'Tidewater Sessions',
  byteLength: 288000000,
  addedAt: addedAt ?? DateTime.utc(2026, 10, 20),
  file: 'items/$id/book.m4b',
);

void main() {
  late Directory root;
  setUp(() async => root = await Directory.systemTemp.createTemp('arke-library-'));
  tearDown(() async => root.delete(recursive: true));

  test('an added item survives a reload with its place', () async {
    final store = LibraryStore(root);
    final id = await store.reserve();
    await store.add(_item(id));
    await store.keepPlace(id, Place(progress: 0.4, position: const Duration(minutes: 13), updatedAt: DateTime.utc(2026, 10, 20, 9)));

    final reloaded = await LibraryStore(root).load();
    expect(reloaded.single.id, id);
    expect(reloaded.single.place!.position, const Duration(minutes: 13));
    expect(reloaded.single.inProgress, isTrue);
  });

  test('remove deletes the files and the place', () async {
    final store = LibraryStore(root);
    final id = await store.reserve();
    await File('${store.itemDirectory(id).path}/book.m4b').writeAsString('audio');
    await store.add(_item(id));
    await store.remove(id);
    expect(store.items, isEmpty);
    expect(await store.itemDirectory(id).exists(), isFalse);
  });

  test('a folder the index does not name is an unfinished add, and load clears it', () async {
    final store = LibraryStore(root);
    final kept = await store.reserve();
    await store.add(_item(kept));
    final orphan = await store.reserve();
    await File('${store.itemDirectory(orphan).path}/half.mp4').writeAsString('partial');

    await LibraryStore(root).load();
    expect(await store.itemDirectory(orphan).exists(), isFalse);
    expect(await store.itemDirectory(kept).exists(), isTrue);
  });

  group('a world\'s guide (SPEC-059 R-10, R-18, R-20)', () {
    LibraryWorld world({String? guide}) => LibraryWorld(
      id: 'undersong',
      edition: '2026-10-22',
      name: 'The Undersong',
      byteLength: 10,
      installedAt: DateTime.utc(2026, 10, 22),
      productions: const [],
      guide: guide,
    );
    LibraryGuide alone() => LibraryGuide(
      worldId: 'undersong',
      edition: '2026-10-22',
      sha256: 'a' * 64,
      guide: 'guides/undersong/guide/guide.json',
      fetchedAt: DateTime.utc(2026, 10, 22),
    );
    Future<Directory> staged(Future<Directory> Function() stage) async {
      final folder = await stage();
      final content = Directory('${folder.path}/world');
      await File('${content.path}/guide/guide.json').create(recursive: true);
      return content;
    }

    test('a guide fetched alone is kept, and survives a reload', () async {
      final store = LibraryStore(root);
      await store.addGuide(alone(), await staged(store.stageGuide));
      final reloaded = LibraryStore(root);
      await reloaded.load();
      expect(reloaded.guides.single.guide, 'guides/undersong/guide/guide.json');
      expect(await File(reloaded.resolve(reloaded.guides.single.guide)).exists(), isTrue);
    });

    test('installing a package that carries the guide supersedes the one fetched alone', () async {
      final store = LibraryStore(root);
      await store.addGuide(alone(), await staged(store.stageGuide));
      await store.addWorld(world(guide: 'worlds/undersong/guide/guide.json'), const [], await staged(store.stageWorld));
      expect(store.guides, isEmpty);
      expect(await store.guideDirectory('undersong').exists(), isFalse);
    });

    test('a package with no guide leaves the one fetched alone', () async {
      final store = LibraryStore(root);
      await store.addGuide(alone(), await staged(store.stageGuide));
      await store.addWorld(world(), const [], await staged(store.stageWorld));
      expect(store.guides, hasLength(1));
    });

    test('what is revealed stays revealed, through the furthest chapter, until the world is removed', () async {
      final store = LibraryStore(root);
      await store.reveal('undersong', 'ledger', 6);
      await store.reveal('undersong', 'ledger', 3);
      final reloaded = LibraryStore(root);
      await reloaded.load();
      expect(reloaded.revealed, {
        'undersong': {'ledger': 6},
      });
      await reloaded.addWorld(world(), const [], await staged(reloaded.stageWorld));
      await reloaded.removeWorld('undersong');
      expect(reloaded.revealed, isEmpty);
    });

    test('a guide fetch a crash interrupted is cleared on the next load', () async {
      final store = LibraryStore(root);
      final folder = await store.stageGuide();
      await LibraryStore(root).load();
      expect(await folder.exists(), isFalse);
    });
  });

  test('writes queue rather than interleave', () async {
    final store = LibraryStore(root);
    final ids = [for (var i = 0; i < 5; i++) await store.reserve()];
    await Future.wait([for (final id in ids) store.add(_item(id))]);
    expect((await LibraryStore(root).load()).length, 5);
  });

  group('shelves', () {
    test('Continue is what is in progress, last played first', () {
      final items = [
        _item('a').copyWith(place: Place(progress: 0.2, updatedAt: DateTime.utc(2026, 10, 19))),
        _item('b').copyWith(place: Place(progress: 0.5, updatedAt: DateTime.utc(2026, 10, 20))),
        _item('c').copyWith(place: Place(progress: 1, updatedAt: DateTime.utc(2026, 10, 21)), finished: true),
        _item('d'),
      ];
      expect([for (final item in continueShelf(items)) item.id], ['b', 'a']);
    });

    test('Added is newest first, ten at most', () {
      final items = [for (var i = 0; i < 12; i++) _item('$i', addedAt: DateTime.utc(2026, 10, 1 + i))];
      final added = addedShelf(items);
      expect(added.length, 10);
      expect(added.first.id, '11');
    });

    test('kinds present, in chip order', () {
      final items = [_item('a', format: FileFormat.mp4), _item('b', format: FileFormat.epub)];
      expect(kindsPresent(items), [LibraryKind.read, LibraryKind.watch]);
    });
  });

  group('words', () {
    test('sizes', () {
      expect(formatBytes(8000000), '8 MB');
      expect(formatBytes(2100000), '2.1 MB');
      expect(formatBytes(410000000), '410 MB');
      expect(formatBytes(2400000000), '2.4 GB');
    });

    test('lengths', () {
      expect(formatLength(const Duration(minutes: 3, seconds: 42)), '3:42');
      expect(formatLength(const Duration(minutes: 12)), '12 min');
      expect(formatLength(const Duration(hours: 6, minutes: 12)), '6 h 12 m');
    });

    test('a row line is format, author or extent, size', () {
      final book = LibraryItem(
        id: 'x',
        format: FileFormat.epub,
        title: 'The Salt Almanac',
        author: 'Ines Varga',
        byteLength: 2100000,
        addedAt: DateTime.utc(2026),
        file: 'f',
      );
      expect(rowLine(book), 'EPUB · Ines Varga · 2.1 MB');
      final boards = LibraryItem(
        id: 'y',
        format: FileFormat.pdf,
        title: 'Saltlight boards',
        pages: 24,
        byteLength: 18000000,
        addedAt: DateTime.utc(2026),
        file: 'f',
      );
      expect(rowLine(boards), 'PDF · 24 pages · 18 MB');
    });

    test('where you are: the chapter and the time left in it', () {
      final book = _item('a').copyWith(
        place: Place(progress: 0.6, position: const Duration(minutes: 50), updatedAt: DateTime.utc(2026)),
      );
      final chaptered = LibraryItem(
        id: 'a',
        format: FileFormat.m4b,
        title: 't',
        byteLength: 1,
        addedAt: DateTime.utc(2026),
        file: 'f',
        duration: const Duration(minutes: 90),
        chapters: const [
          Chapter(title: 'One', start: Duration.zero),
          Chapter(title: 'Two', start: Duration(minutes: 30)),
          Chapter(title: 'Three', start: Duration(minutes: 66)),
        ],
        place: book.place,
      );
      expect(whereLine(chaptered), 'Chapter 2 · 16 min left');
    });
  });
}
