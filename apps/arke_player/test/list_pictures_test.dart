import 'dart:io';

import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/world_widgets.dart';
import 'package:arke_world/arke_world.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// SPEC-058 rev 10: the pictures Arke's list pins come with the list. A row shows the file a pin
// brought once it is kept and checked, else the bundled picture, else its own fallback; the app
// keeps what the list it shows names and lets go of the rest.

final _jpeg = [0xff, 0xd8, 0xff, 0xe0, ...List.generate(200, (index) => index % 251)];

void main() {
  group('a list picture', () {
    final pin = PicturePin(url: Uri.parse('https://example.org/cover.jpg'), byteLength: 10, sha256: 'a' * 64);
    final file = File('kept.jpg');

    test('the kept file before the bundled one', () {
      expect(listPicture({pin.sha256: file}, 'assets/worlds/cover.jpg', pin), isA<FileImage>().having((image) => image.file.path, 'file', file.path));
    });

    test('the bundled one while the file has not come', () {
      expect(listPicture(const {}, 'assets/worlds/cover.jpg', pin), isA<AssetImage>().having((image) => image.assetName, 'asset', 'assets/worlds/cover.jpg'));
      expect(listPicture({pin.sha256: file}, 'assets/worlds/cover.jpg', null), isA<AssetImage>());
    });

    test('nothing when there is neither, so the row’s own fallback shows', () {
      expect(listPicture(const {}, null, pin), isNull);
      expect(listPicture(const {}, null, null), isNull);
    });
  });

  group('keeping what the list pins', () {
    late Directory root;
    late HttpServer server;
    late ProviderContainer container;

    setUp(() async {
      root = Directory.systemTemp.createTempSync('arke-kept-pictures-');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/cover.jpg') request.response.add(_jpeg);
        if (request.uri.path != '/cover.jpg') request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      container = ProviderContainer(
        overrides: [pictureKeeperProvider.overrideWith((ref) async => PictureKeeper(folder: Directory('${root.path}${Platform.pathSeparator}pictures')))],
      );
    });

    tearDown(() async {
      container.dispose();
      await server.close(force: true);
      root.deleteSync(recursive: true);
    });

    CatalogueWorld world(PicturePin pin) => CatalogueWorld(
      id: 'the-red-quiet',
      name: 'The Red Quiet',
      productions: [CatalogueProduction(title: 'The Red Quiet', kind: 'Audiobook', tallPin: pin)],
    );

    test('a picture arrives into what is kept, and goes when no list names it', () async {
      // Pins are HTTPS in a list; the keeper fetches the address it is given, here the loopback.
      final pin = PicturePin(url: Uri.parse('http://127.0.0.1:${server.port}/cover.jpg'), byteLength: _jpeg.length, sha256: sha256.convert(_jpeg).toString());
      expect(await container.read(keptPicturesProvider.future), isEmpty);
      await container.read(keptPicturesProvider.notifier).keepFor([world(pin)]);
      final kept = container.read(keptPicturesProvider).value!;
      expect(kept.keys, [pin.sha256]);
      expect(kept[pin.sha256]!.readAsBytesSync(), _jpeg);
      await container.read(keptPicturesProvider.notifier).keepFor(const []);
      expect(container.read(keptPicturesProvider).value, isEmpty);
      expect(kept[pin.sha256]!.existsSync(), isFalse);
    });

    test('one that does not come is not there, and nothing else changes', () async {
      final pin = PicturePin(url: Uri.parse('http://127.0.0.1:${server.port}/missing.jpg'), byteLength: _jpeg.length, sha256: sha256.convert(_jpeg).toString());
      await container.read(keptPicturesProvider.notifier).keepFor([world(pin)]);
      expect(container.read(keptPicturesProvider).value, isEmpty);
    });
  });
}
