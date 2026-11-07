import 'dart:io';

import 'package:arke_player/app/catalogue_channel.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/features/parts/application/notices.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('foreground, daily worker, shipped baseline and preferences use the same build channel', () async {
    final dev = catalogueChannel == CatalogueChannel.development;
    final support = channelSupportDirectory(Directory.systemTemp);
    final container = ProviderContainer(overrides: [libraryRootProvider.overrideWith((ref) async => Directory('${support.path}/library'))]);
    addTearDown(container.dispose);
    final hosted = await container.read(hostedCatalogueProvider.future);
    expect(hosted.url, catalogueChannel.url);
    expect(dailyCheck, catalogueChannel.dailyCheck);
    expect(hosted.kept.parent.path, support.path);
    expect(support.path.endsWith('arke-worlds-dev'), dev);
    final baseline = parseCatalogue(await rootBundle.loadString(catalogueChannel.bundledCatalogue));
    if (dev) {
      expect(baseline.serial, 0);
      expect(baseline.worlds, isEmpty);
    } else {
      expect(baseline.serial, greaterThan(0));
      expect(baseline.worlds, isNotEmpty);
    }
    SharedPreferences.setMockInitialValues({'arke.wifiOnly': false, 'arke.dev.wifiOnly': true});
    expect((await container.read(settingsProvider.future)).wifiOnly, dev);
  });
}
