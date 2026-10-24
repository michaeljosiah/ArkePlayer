import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

// SPEC-058 rev 10: pictures published beside Arke's list, pinned as a package is, fetched with the
// list and kept by their digest, so a new or changed picture needs no new app.

final _jpeg = [0xff, 0xd8, 0xff, 0xe0, ...List.generate(300, (index) => index % 251)];
final _png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...List.generate(40, (index) => index)];
final _webp = [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, ...List.generate(40, (index) => index)];
String _digestOf(List<int> bytes) => sha256.convert(bytes).toString();

Map<String, Object> _pin(String name, {List<int>? bytes, String? url}) {
  final of = bytes ?? _jpeg;
  return {'url': url ?? 'https://example.org/$name.jpg', 'byteLength': of.length, 'sha256': _digestOf(of)};
}

String _list({required int serial, Object? worldPins, Object? productionPins, String picture = 'assets/worlds/juju/cover.jpg'}) => jsonEncode({
  'version': 2,
  'serial': serial,
  'worlds': [
    {
      'id': 'na-love-or-juju',
      'name': 'Na Love or Juju',
      'keyArt': 'assets/worlds/juju/key-art.jpg',
      'pins': ?worldPins,
      'productions': [
        {'title': 'Na love or Juju', 'kind': 'Audiobook', 'picture': picture, 'tall': 'assets/worlds/juju/cover-tall.jpg', 'pins': ?productionPins},
      ],
      'package': {'url': 'https://example.org/juju.zip', 'byteLength': 10, 'sha256': 'a' * 64},
    },
  ],
});

void main() {
  group('pins in the list', () {
    test('a world’s key art and a production’s picture and Tall cover, beside their bundle paths', () {
      final list = parseCatalogue(
        _list(
          serial: 1,
          worldPins: {'keyArt': _pin('key-art')},
          productionPins: {
            'picture': _pin('cover', bytes: _png),
            'tall': _pin('cover-tall', bytes: _webp),
          },
        ),
      );
      final world = list.worlds.single;
      final production = world.productions.single;
      expect(world.keyArt, 'assets/worlds/juju/key-art.jpg', reason: 'the bundle path is untouched');
      expect(world.keyArtPin?.url, Uri.parse('https://example.org/key-art.jpg'));
      expect(world.keyArtPin?.sha256, _digestOf(_jpeg));
      expect(production.picture, 'assets/worlds/juju/cover.jpg');
      expect(production.tall, 'assets/worlds/juju/cover-tall.jpg');
      expect(production.picturePin?.byteLength, _png.length);
      expect(production.tallPin?.sha256, _digestOf(_webp));
    });

    test('a list without pins reads as before', () {
      final world = parseCatalogue(_list(serial: 1)).worlds.single;
      expect(world.keyArtPin, isNull);
      expect(world.productions.single.picturePin, isNull);
      expect(world.productions.single.tallPin, isNull);
    });

    test('a key it does not know is left for a newer reader', () {
      final world = parseCatalogue(_list(serial: 1, worldPins: {'banner': 'anything'}, productionPins: {'poster': 3})).worlds.single;
      expect(world.keyArtPin, isNull);
      expect(world.productions.single.picturePin, isNull);
    });

    test('a pin that is not one is not a list', () {
      for (final bad in <Object>[
        'https://example.org/a.jpg',
        {'url': 'http://example.org/a.jpg', 'byteLength': 10, 'sha256': 'a' * 64},
        {'url': 'https://example.org/a.jpg', 'byteLength': 0, 'sha256': 'a' * 64},
        {'url': 'https://example.org/a.jpg', 'byteLength': PicturePin.maxBytes + 1, 'sha256': 'a' * 64},
        {'url': 'https://example.org/a.jpg', 'byteLength': 10, 'sha256': 'A' * 64},
        {'url': 'https://example.org/a.jpg', 'byteLength': '10', 'sha256': 'a' * 64},
        {'byteLength': 10, 'sha256': 'a' * 64},
      ]) {
        expect(() => parseCatalogue(_list(serial: 1, worldPins: {'keyArt': bad})), throwsFormatException, reason: '$bad');
        expect(() => parseCatalogue(_list(serial: 1, productionPins: {'tall': bad})), throwsFormatException, reason: '$bad');
      }
      expect(() => parseCatalogue(_list(serial: 1, worldPins: ['keyArt'])), throwsFormatException);
      expect(() => parseCatalogue(_list(serial: 1, productionPins: 'tall')), throwsFormatException);
    });

    test('the newer list’s pins, the shipped list’s bundle paths', () {
      final shipped = parseCatalogue(_list(serial: 2, worldPins: {'keyArt': _pin('old-key-art')}));
      final kept = parseCatalogue(
        _list(
          serial: 3,
          picture: 'assets/remote/cover.jpg',
          worldPins: {'keyArt': _pin('key-art', bytes: _png)},
          productionPins: {'tall': _pin('tall')},
        ),
      );
      final world = newestCatalogue(shipped, kept).worlds.single;
      expect(world.keyArt, 'assets/worlds/juju/key-art.jpg');
      expect(world.keyArtPin?.url, Uri.parse('https://example.org/key-art.jpg'));
      expect(world.productions.single.picture, 'assets/worlds/juju/cover.jpg');
      expect(world.productions.single.tallPin?.url, Uri.parse('https://example.org/tall.jpg'));
      // An older fetched list leaves the shipped one, pins and all.
      expect(newestCatalogue(kept, shipped).worlds.single.keyArtPin?.url, Uri.parse('https://example.org/key-art.jpg'));
    });

    test('a world the app does not ship has its pictures by its pins alone', () {
      final shipped = parseCatalogue(jsonEncode({'version': 2, 'serial': 1, 'worlds': <Object>[]}));
      final kept = parseCatalogue(_list(serial: 2, worldPins: {'keyArt': _pin('key-art')}));
      final world = newestCatalogue(shipped, kept).worlds.single;
      expect(world.keyArt, isNull);
      expect(world.keyArtPin, isNotNull);
    });

    test('every picture the list names, once each', () {
      final list = parseCatalogue(
        _list(
          serial: 1,
          worldPins: {'keyArt': _pin('key-art')},
          productionPins: {
            'picture': _pin('same-bytes'),
            'tall': _pin('tall', bytes: _png),
          },
        ),
      );
      expect(pinsOf(list.worlds).map((pin) => pin.sha256).toList(), [_digestOf(_jpeg), _digestOf(_png)]);
    });
  });

  group('a picture by its first bytes', () {
    test('JPEG, PNG and WebP, and nothing else', () {
      expect(pictureTypeOf(_jpeg), PictureType.jpeg);
      expect(pictureTypeOf(_png), PictureType.png);
      expect(pictureTypeOf(_webp), PictureType.webp);
      expect(pictureTypeOf(utf8.encode('<html>not a picture</html>')), isNull);
      expect(pictureTypeOf(const [0xff, 0xd8]), isNull);
      expect(pictureTypeOf([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]), isNull);
    });
  });

  group('pin_picture', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('arke-pin-picture-'));
    tearDown(() => root.deleteSync(recursive: true));

    File write(String name, List<int> bytes) => File('${root.path}${Platform.pathSeparator}$name')..writeAsBytesSync(bytes);

    test('prints the address, length and digest the list pins', () async {
      final pin = await pinPicture(write('cover.jpg', _jpeg), Uri.parse('https://example.org/cover.jpg'));
      expect(pin, {'url': 'https://example.org/cover.jpg', 'byteLength': _jpeg.length, 'sha256': _digestOf(_jpeg)});
    });

    test('refuses what is not a picture, one too large, and an address that is not HTTPS', () async {
      await expectLater(pinPicture(write('page.html', utf8.encode('<html></html>')), Uri.parse('https://example.org/a')), throwsA(isA<PictureRefused>()));
      await expectLater(
        pinPicture(write('big.jpg', [..._jpeg, ...List.filled(PicturePin.maxBytes, 0)]), Uri.parse('https://example.org/a')),
        throwsA(isA<PictureRefused>()),
      );
      await expectLater(pinPicture(write('cover.jpg', _jpeg), Uri.parse('http://example.org/a')), throwsA(isA<PictureRefused>()));
    });
  });

  group('keeping the pictures', () {
    late Directory root;
    late Directory folder;
    late HttpServer server;
    final served = <String, List<int>>{};
    final asked = <String>[];

    setUp(() async {
      root = Directory.systemTemp.createTempSync('arke-pictures-');
      folder = Directory('${root.path}${Platform.pathSeparator}pictures');
      served.clear();
      asked.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        asked.add(request.uri.path);
        final bytes = served[request.uri.path];
        if (bytes == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.add(bytes);
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      root.deleteSync(recursive: true);
    });

    // Pins are HTTPS in a list; the keeper fetches whatever address it is given, here the loopback.
    PicturePin serve(String path, List<int> bytes, {List<int>? pinned}) {
      served[path] = bytes;
      final of = pinned ?? bytes;
      return PicturePin(url: Uri.parse('http://127.0.0.1:${server.port}$path'), byteLength: of.length, sha256: _digestOf(of));
    }

    List<String> names() => folder.existsSync() ? [for (final file in folder.listSync()) file.uri.pathSegments.last] : const [];

    test('a picture is kept by its digest once its length, digest and first bytes check', () async {
      final pin = serve('/cover.jpg', _jpeg);
      final kept = await PictureKeeper(folder: folder).fetch(pin);
      expect(kept, isNotNull);
      expect(kept!.readAsBytesSync(), _jpeg);
      expect(names(), ['${pin.sha256}.jpg']);
      expect((await PictureKeeper(folder: folder).kept()).keys, [pin.sha256]);
    });

    test('a PNG and a WebP are kept under their own extensions', () async {
      final keeper = PictureKeeper(folder: folder);
      final png = serve('/a.png', _png);
      final webp = serve('/a.webp', _webp);
      await keeper.fetch(png);
      await keeper.fetch(webp);
      expect(names()..sort(), ['${png.sha256}.png', '${webp.sha256}.webp']..sort());
    });

    test('other bytes, a short or long answer, a page that is not a picture, or no answer keep nothing', () async {
      final keeper = PictureKeeper(folder: folder);
      final page = utf8.encode('<html>moved</html>');
      for (final pin in [
        serve('/other.jpg', _jpeg, pinned: [..._jpeg.take(_jpeg.length - 1), 7]),
        serve('/short.jpg', _jpeg.sublist(0, 100), pinned: _jpeg),
        serve('/long.jpg', [..._jpeg, 1, 2, 3], pinned: _jpeg),
        serve('/page.html', page),
        PicturePin(url: Uri.parse('http://127.0.0.1:${server.port}/missing.jpg'), byteLength: _jpeg.length, sha256: _digestOf(_jpeg)),
      ]) {
        expect(await keeper.fetch(pin), isNull, reason: '${pin.url}');
        expect(names(), isEmpty, reason: 'nothing of ${pin.url} is left behind');
      }
    });

    test('keep fetches only what is not kept, one at a time, and says as each arrives', () async {
      final keeper = PictureKeeper(folder: folder);
      final cover = serve('/cover.jpg', _jpeg);
      final tall = serve('/tall.png', _png);
      await keeper.fetch(cover);
      asked.clear();
      final arrived = <String>[];
      await keeper.keep([cover, tall], onKept: (pin, file) => arrived.add(pin.sha256));
      expect(asked, ['/tall.png']);
      expect(arrived, [tall.sha256]);
    });

    test('a list that no longer names a picture deletes it, and nothing outside the folder', () async {
      final keeper = PictureKeeper(folder: folder);
      final cover = serve('/cover.jpg', _jpeg);
      final tall = serve('/tall.png', _png);
      await keeper.keep([cover, tall]);
      File('${folder.path}${Platform.pathSeparator}${'b' * 64}.part').writeAsBytesSync([1]);
      File('${folder.path}${Platform.pathSeparator}notes.txt').writeAsStringSync('not the keeper’s');
      final beside = File('${root.path}${Platform.pathSeparator}${cover.sha256}.jpg')..writeAsBytesSync(_jpeg);
      await keeper.keep([tall]);
      expect(names()..sort(), ['${tall.sha256}.png', 'notes.txt']..sort());
      expect(beside.existsSync(), isTrue);
    });

    test('stopped ends it between pictures', () async {
      final keeper = PictureKeeper(folder: folder);
      final cover = serve('/cover.jpg', _jpeg);
      final tall = serve('/tall.png', _png);
      var arrivals = 0;
      await keeper.keep([cover, tall], onKept: (_, _) => arrivals++, stopped: () => arrivals > 0);
      expect(asked, ['/cover.jpg']);
    });
  });
}
