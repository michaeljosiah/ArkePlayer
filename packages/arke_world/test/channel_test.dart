import 'dart:convert';
import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:test/test.dart';

void main() {
  test('only named HTTPS authorities are accepted and every persistent scope is separate', () {
    final production = CatalogueChannel.parse('production');
    final dev = CatalogueChannel.parse('development');
    expect(production.url.host, 'github.com');
    expect(dev.url.path, '/publishing/channels/arke-worlds-dev/catalogue.json');
    expect(dev.url.scheme, 'https');
    expect(dev.storageFolder, isNot(production.storageFolder));
    expect(dev.bundledCatalogue, isNot(production.bundledCatalogue));
    expect(dev.preferencePrefix, isNot(production.preferencePrefix));
    expect(dev.dailyCheck, isNot(production.dailyCheck));
    for (final value in ['', 'dev', 'https://example.com/feed', 'Production']) {
      expect(() => CatalogueChannel.parse(value), throwsArgumentError);
    }
  });

  test('dev refresh keeps a higher serial and offline cache independently of production', () async {
    final root = await Directory.systemTemp.createTemp('arke-channels-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var serial = 1;
    var status = 200;
    var invalid = false;
    var calls = 0;
    var forced = false;
    server.listen((request) async {
      calls++;
      forced = request.uri.queryParameters.containsKey('_arke_check') && request.headers.value(HttpHeaders.cacheControlHeader) == 'no-cache';
      request.response.statusCode = status;
      request.response.write(invalid ? '{}' : jsonEncode({'version': 2, 'serial': serial, 'worlds': <Object?>[]}));
      await request.response.close();
    });
    final production = File('${root.path}/catalogue.json');
    await production.writeAsString(
      jsonEncode({
        'list': {'version': 2, 'serial': 49, 'worlds': <Object?>[]},
      }),
    );
    final before = await production.readAsBytes();
    final hosted = HostedCatalogue(
      url: Uri.parse('http://127.0.0.1:${server.port}/catalogue.json'),
      kept: File('${root.path}/${CatalogueChannel.development.storageFolder}/catalogue.json'),
    );
    try {
      final baseline = parseCatalogue('{"version":2,"serial":0,"worlds":[]}');
      expect(newestCatalogue(baseline, await hosted.refresh()).serial, 1);
      await hosted.refresh();
      expect(calls, 1, reason: 'automatic refresh retains the daily bound');
      for (final candidate in [1, 0]) {
        serial = candidate;
        expect((await hosted.refresh(force: true))?.serial, 1);
        expect(forced, isTrue);
      }
      serial = 2;
      expect((await hosted.refresh(force: true))?.serial, 2);
      invalid = true;
      await expectLater(hosted.refresh(force: true), throwsFormatException);
      invalid = false;
      status = 503;
      await expectLater(hosted.refresh(force: true), throwsA(isA<HttpException>()));
      expect((await hosted.keptList())?.serial, 2);
      expect(await production.readAsBytes(), before);
    } finally {
      await server.close(force: true);
      await root.delete(recursive: true);
    }
  });
}
