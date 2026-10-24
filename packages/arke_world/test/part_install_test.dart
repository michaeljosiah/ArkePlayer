import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 R-46 – R-55: a world released a chapter at a time. An installed world is its edition and
// every part since; a part comes on its own and only adds; a new edition gathers the parts.
final _media = '${Directory.current.path}/../arke_media/test/fixtures';

/// Serves a file per path.
class _Server {
  _Server._(this._server);
  final HttpServer _server;
  final files = <String, List<int>>{};
  int hits = 0;

  Uri url(String path) => Uri.parse('http://127.0.0.1:${_server.port}/$path');

  static Future<_Server> start() async {
    final server = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen((request) async {
      server.hits++;
      final body = server.files[request.uri.path.substring(1)];
      final response = request.response;
      if (body == null) {
        response.statusCode = HttpStatus.notFound;
      } else {
        response.contentLength = body.length;
        response.add(body);
      }
      await response.close();
    });
    return server;
  }

  Future<void> close() => _server.close(force: true);
}

Map<String, Object?> _chapter(Directory dir, String id, String title, int order) {
  File('$_media/chapters.m4b').copySync('${dir.path}/$id.m4a');
  File('${dir.path}/$id.jpg').writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, order, 0xFF, 0xD9]);
  return {
    'id': id,
    'order': order,
    'title': title,
    'audio': '${dir.path}/$id.m4a',
    'pictures': [
      {'at': 0, 'picture': '${dir.path}/$id.jpg'},
    ],
  };
}

void main() {
  late Directory dir;
  late LibraryStore store;
  late _Server server;
  late WorldInstaller installer;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('arke_parts_');
    store = LibraryStore(Directory('${dir.path}/library'));
    await store.load();
    server = await _Server.start();
    installer = WorldInstaller(store: store, freeBytes: (_) async => null);
  });
  tearDown(() async {
    await server.close();
    await store.close();
    await dir.delete(recursive: true);
  });

  /// Packs [spec] and serves it as [name], returning its pin and its manifest.
  Future<(CataloguePackage, WorldManifest)> serve(WorldSpec spec, String name) async {
    final zip = '${dir.path}/$name';
    await packWorld(spec, zip);
    final bytes = await File(zip).readAsBytes();
    server.files[name] = bytes;
    final manifest = readWorldPackage(zip);
    return (
      CataloguePackage(
        url: server.url(name),
        byteLength: bytes.length,
        sha256: sha256.convert(bytes).toString(),
        edition: spec.edition,
        fingerprint: editionFingerprint(manifest),
      ),
      manifest,
    );
  }

  Future<(CataloguePackage, WorldManifest)> edition(String label) {
    final made = Directory('${dir.path}/edition-$label')..createSync();
    return serve(
      WorldSpec(
        id: 'undersong',
        edition: label,
        name: 'The Undersong',
        productions: [
          ProductionSpec(
            id: 'ledger',
            title: 'The Ledger of Nights',
            listening: {
              'title': 'The Ledger of Nights',
              'chapters': [_chapter(made, 'neap', 'Neap', 1), _chapter(made, 'the-rail-book', 'The rail book', 2)],
            },
          ),
        ],
      ),
      'edition-$label.zip',
    );
  }

  Future<CataloguePart> part(String fingerprint, int number, List<(String, String, int)> chapters, {bool book = false, String follows = '2026-10-22'}) async {
    final made = Directory('${dir.path}/part-$number-${chapters.first.$1}')..createSync();
    final label = '2026-10-${29 + number}';
    final (pin, manifest) = await serve(
      WorldSpec(
        id: 'undersong',
        edition: label,
        name: 'The Undersong',
        part: WorldPart(
          follows: follows,
          fingerprint: fingerprint,
          number: number,
          schedule: const WorldSchedule(day: ScheduleDay.friday),
        ),
        productions: [
          ProductionSpec(
            id: 'ledger',
            title: 'The Ledger of Nights',
            book: book ? '$_media/book.epub' : null,
            listening: {
              'title': 'The Ledger of Nights',
              'chapters': [for (final (id, title, order) in chapters) _chapter(made, id, title, order)],
            },
          ),
        ],
      ),
      'part-$number-${chapters.first.$1}.zip',
    );
    return CataloguePart(
      url: pin.url,
      byteLength: pin.byteLength,
      sha256: pin.sha256,
      edition: label,
      fingerprint: editionFingerprint(manifest),
      released: parseDay(label)!,
      production: 'ledger',
      chapters: [for (final (id, title, order) in chapters) CataloguePartChapter(id: id, number: order, title: title)],
    );
  }

  CatalogueWorld listed(CataloguePackage pin, [List<CataloguePart> parts = const []]) => CatalogueWorld(
    id: 'undersong',
    name: 'The Undersong',
    productions: const [],
    package: CatalogueEdition(url: pin.url, byteLength: pin.byteLength, sha256: pin.sha256, edition: pin.edition, fingerprint: pin.fingerprint, parts: parts),
  );

  LibraryItem narration() => store.items.singleWhere((item) => item.id == 'undersong.ledger.listening');

  test('a part adds its chapters after the edition’s, beside what is there (R-50, R-51)', () async {
    final (pin, _) = await edition('2026-10-22');
    await installer.install(listed(pin));
    final before = narration();
    final low = await part(pin.fingerprint!, 1, [('low-water', 'Low water', 3)], book: true);
    expect(missingParts(listed(pin, [low]), store.worlds.single), [low]);

    await installer.installPart(listed(pin, [low]), low);
    final world = store.worlds.single;
    expect(world.parts.single.chapters, ['low-water']);
    expect(world.edition, '2026-10-22', reason: 'a part does not change the edition');
    final after = narration();
    expect(after.chapters.map((chapter) => chapter.title), ['Neap', 'The rail book', 'Low water']);
    expect(after.chapters.last.start, before.duration);
    expect(after.duration! > before.duration!, isTrue);
    expect(world.productions.single.bookParts, ['undersong.ledger.book.1']);
    expect(store.items.any((item) => item.id == 'undersong.ledger.book.1' && item.format == FileFormat.epub), isTrue);
    expect(missingParts(listed(pin, [low]), world), isEmpty);
    // Played as one: the edition's document, then the part's, each with its own folder.
    final sources = await installedListening(store, world, 'ledger');
    expect(sources.map((source) => source.document.chapters.map((chapter) => chapter.id).join(',')), ['neap,the-rail-book', 'low-water']);
    expect(File('${sources.last.folder}/world.json').existsSync(), isTrue);
    // The same part again changes nothing.
    await installer.installPart(listed(pin, [low]), low);
    expect(store.worlds.single.parts, hasLength(1));
  });

  test('a finished narration moves to the new chapter, which is New until it plays (R-52, P15g)', () async {
    final (pin, _) = await edition('2026-10-22');
    await installer.install(listed(pin));
    await store.keepPlace(
      narration().id,
      Place(locator: 'the-rail-book', position: const Duration(seconds: 1), progress: 1, updatedAt: DateTime.utc(2026, 10, 23)),
      finished: true,
    );
    final low = await part(pin.fingerprint!, 1, [('low-water', 'Low water', 3)]);
    await installer.installPart(listed(pin, [low]), low);
    final moved = narration();
    expect((moved.finished, moved.place?.locator, moved.inProgress), (false, 'low-water', true));
    expect(newChapters(store.worlds.single, 'ledger', moved), {2});
    expect(worldHasNew(store.worlds.single, store.items), isTrue);
    await store.keepPlace(moved.id, Place(locator: 'low-water', position: const Duration(seconds: 1), progress: 0.7, updatedAt: DateTime.now().toUtc()));
    expect(newChapters(store.worlds.single, 'ledger', narration()), isEmpty);
  });

  test('a world installed with its parts has them all, none of it New (R-50)', () async {
    final (pin, _) = await edition('2026-10-22');
    final low = await part(pin.fingerprint!, 1, [('low-water', 'Low water', 3)]);
    final bells = await part(pin.fingerprint!, 2, [('the-bell-ropes', 'The bell ropes', 4)]);
    await installer.install(listed(pin, [low, bells]));
    final world = store.worlds.single;
    expect(world.parts.map((part) => part.number), [1, 2]);
    expect(narration().chapters.map((chapter) => chapter.title), ['Neap', 'The rail book', 'Low water', 'The bell ropes']);
    expect(newChapters(world, 'ledger', narration()), isEmpty);
    expect(Directory('${store.worldDirectory('undersong').path}/_parts/2').existsSync(), isTrue);
  });

  test('a part made after another edition, out of order, or naming a chapter already out is refused, nothing added', () async {
    final (pin, _) = await edition('2026-10-22');
    await installer.install(listed(pin));
    final other = await part('b' * 64, 1, [('low-water', 'Low water', 3)]);
    await expectLater(installer.installPart(listed(pin, [other]), other), throwsA(isA<NotAPackage>()));
    final second = await part(pin.fingerprint!, 2, [('the-bell-ropes', 'The bell ropes', 4)]);
    await expectLater(installer.installPart(listed(pin, [second]), second), throwsA(isA<NotAPackage>()));
    final again = await part(pin.fingerprint!, 1, [('neap', 'Neap', 3)]);
    await expectLater(installer.installPart(listed(pin, [again]), again), throwsA(isA<NotAPackage>()));
    expect(store.worlds.single.parts, isEmpty);
    expect(narration().chapters, hasLength(2));
    expect(Directory('${store.worldDirectory('undersong').path}/_parts').existsSync(), isFalse);
  });

  test('a part is never a world of its own', () async {
    final (pin, _) = await edition('2026-10-22');
    final low = await part(pin.fingerprint!, 1, [('low-water', 'Low water', 3)]);
    await expectLater(installer.install(listed(low)), throwsA(isA<NotAPackage>()));
    expect(store.worlds, isEmpty);
  });

  test('a new edition gathers the parts: they fall away, places kept by chapter (R-55)', () async {
    final (pin, _) = await edition('2026-10-22');
    await installer.install(listed(pin));
    final low = await part(pin.fingerprint!, 1, [('low-water', 'Low water', 3)]);
    await installer.installPart(listed(pin, [low]), low);
    final (newer, _) = await edition('2026-11-06');
    expect(missingParts(listed(newer, [low]), store.worlds.single), isEmpty, reason: 'a newer edition waits for Update');
    await installer.update(listed(newer));
    final world = store.worlds.single;
    expect((world.edition, world.parts.length), ('2026-11-06', 0));
    expect(store.items.any((item) => item.id == 'undersong.ledger.book.1'), isFalse);
    expect(Directory('${store.worldDirectory('undersong').path}/_parts').existsSync(), isFalse);
  });

  group('parts in Arke’s list (R-49)', () {
    Map<String, Object?> entry({Object? parts, Object? schedule}) => {
      'version': 2,
      'serial': 9,
      'worlds': [
        {
          'id': 'undersong',
          'name': 'The Undersong',
          'productions': [
            {'title': 'The Ledger of Nights', 'kind': 'Audiobook', 'id': 'ledger', 'schedule': ?schedule},
          ],
          'package': {
            'url': 'https://example.org/e.zip',
            'byteLength': 10,
            'sha256': 'a' * 64,
            'edition': '2026-10-22',
            'fingerprint': 'a' * 64,
            'parts': ?parts,
          },
        },
      ],
    };
    final good = {
      'url': 'https://example.org/p.zip',
      'byteLength': 9,
      'sha256': 'b' * 64,
      'edition': '2026-10-30',
      'fingerprint': 'c' * 64,
      'released': '2026-10-30',
      'production': 'ledger',
      'chapters': [
        {'id': 'the-bell-ropes', 'number': 24, 'title': 'The Bell Ropes'},
      ],
    };

    test('a part names its day, production and chapters; a production its id and schedule', () {
      final world = parseCatalogue(jsonEncode(entry(parts: [good], schedule: {'day': 'friday', 'next': '2026-11-06'}))).worlds.single;
      final part = world.package!.parts.single;
      expect((part.released, part.production, part.chapters.single.number), (DateTime.utc(2026, 10, 30), 'ledger', 24));
      final production = world.productions.single;
      expect((production.id, production.schedule?.day, production.schedule?.next), ('ledger', ScheduleDay.friday, DateTime.utc(2026, 11, 6)));
    });

    test('a list without parts reads as before', () => expect(parseCatalogue(jsonEncode(entry())).worlds.single.package!.parts, isEmpty));

    for (final (what, broken) in [
      ('no day', {...good}..remove('released')),
      ('not https', {...good, 'url': 'http://example.org/p.zip'}),
      ('no fingerprint', {...good}..remove('fingerprint')),
      (
        'a chapter with no title',
        {
          ...good,
          'chapters': [
            {'id': 'x', 'number': 1},
          ],
        },
      ),
    ]) {
      test('a part with $what is not a list', () => expect(() => parseCatalogue(jsonEncode(entry(parts: [broken]))), throwsFormatException));
    }

    test('a schedule naming no day is not a list', () {
      expect(() => parseCatalogue(jsonEncode(entry(schedule: {'day': 'someday'}))), throwsFormatException);
    });
  });
}
