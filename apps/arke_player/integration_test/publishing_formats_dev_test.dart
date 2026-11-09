// Opt-in live acceptance test. It reads the isolated dev catalogue and adds only the
// Paper Garden synthetic rehearsal world to this Android dev app's existing library.
// It never publishes, approves, removes a world, or signs into AONIK.
import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/app.dart';
import 'package:arke_player/app/catalogue_channel.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/features/comics/presentation/comic_reader_screen.dart';
import 'package:arke_player/features/stories/presentation/story_player_screen.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _world = 'paper-garden-dev-403';
const _story = 'garden-choices';
const _comic = 'garden-comic';
const _phase = String.fromEnvironment('ARKE_REHEARSAL_PHASE', defaultValue: 'install');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('live dev story and comic downloads, reader saves and offline reopening', (tester) async {
    // Fail closed before main starts, including in a production APK or an ordinary CI run.
    expect(const bool.fromEnvironment('ARKE_LIVE_PUBLISHING_REHEARSAL'), isTrue);
    expect(Platform.isAndroid, isTrue);
    expect(catalogueChannel.storageFolder, 'arke-worlds-dev');
    expect(catalogueChannel.url.host, 'aonik-dev-api.delightfulisland-9fd7c1e7.uksouth.azurecontainerapps.io');
    expect(['install', 'withdrawn'], contains(_phase));
    await app.main();
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(ArkePlayerApp)));
    final router = container.read(routerProvider);
    final store = await container.read(libraryStoreProvider.future);
    final root = await container.read(libraryRootProvider.future);
    final unrelatedBefore = [
      for (final world in store.worlds)
        if (world.id != _world) world.toJson(),
    ];
    final audioBefore = store.items.where((item) => item.worldId == _world).map((item) => item.toJson()).toList();
    expect(store.worlds.any((world) => world.id == _world), isTrue, reason: 'Install and rehearse the live base and audio part first.');
    final installedAtStart = {
      for (final id in [_story, _comic]) id: _installed(store, id),
    };

    await container.read(catalogueCheckProvider.notifier).check();
    expect(container.read(catalogueCheckProvider), CatalogueCheck.checked);
    final catalogue = await container.read(catalogueProvider.future);
    final hosted = await container.read(hostedCatalogueProvider.future);
    final serial = (await hosted.keptList())!.serial;
    if (_phase == 'install') {
      expect(serial, greaterThanOrEqualTo(12));
      final listed = catalogue.singleWhere((world) => world.id == _world);
      for (final id in [_story, _comic]) {
        final production = listed.productions.singleWhere((production) => production.id == id);
        expect(production.package, isNull, reason: 'Standalone formats must never fall back to a generic package.');
      }
      // New standalone productions arrive through the normal foreground parts check.
      // Update is reserved for replacing an already installed edition.
      router.go(Routes.libraryWorld(_world));
      await _until(tester, () => _installed(store, _story) && _installed(store, _comic), seconds: 90);
    } else {
      expect(serial, greaterThanOrEqualTo(15));
      expect(catalogue.where((world) => world.id == _world), isEmpty);
      expect(_installed(store, _story) && _installed(store, _comic), isTrue);
    }

    // Reader actions use real widgets and the on-device store; no provider or media fakes.
    router.go(Routes.story(_world, _story));
    await _until(tester, () => find.byType(StoryPlayerScreen).evaluate().isNotEmpty);
    if (_phase == 'install' && (store.stories[LibraryStore.storyKey(_world, _story)]?['route'] as List?)?.isNotEmpty != true) {
      await _until(tester, () => find.text('Share it with a friend').evaluate().isNotEmpty, seconds: 25);
      expect(find.text('Plant it in the sun'), findsOneWidget);
      await _tap(tester, find.text('Share it with a friend'));
    }
    await _until(tester, () => store.stories[LibraryStore.storyKey(_world, _story)]?['scene'] == 'sc_friend', seconds: 25);
    await _until(tester, () => find.text('Lights together').evaluate().isNotEmpty);
    expect(store.stories[LibraryStore.storyKey(_world, _story)]!['route'], ['ch_friend']);
    router.go(Routes.comic(_world, _comic));
    await _until(tester, () => find.byType(ComicReaderScreen).evaluate().isNotEmpty && find.byTooltip('Next page').evaluate().isNotEmpty);
    if (_phase == 'install' && store.stories[LibraryStore.storyKey(_world, _comic)]?['comicPage'] != 1) {
      expect(find.text('1 of 3'), findsOneWidget);
      await _tap(tester, find.byTooltip('Next page'));
    }
    await _until(tester, () => store.stories[LibraryStore.storyKey(_world, _comic)]?['comicPage'] == 1);
    expect(find.text('2 of 3'), findsOneWidget);
    router.go(Routes.libraryWorld(_world));
    await tester.pump(const Duration(seconds: 1));

    final saved = jsonDecode(jsonEncode(store.stories)) as Map<String, dynamic>;
    final previous = HttpOverrides.current;
    final offline = _Offline();
    HttpOverrides.global = offline;
    try {
      router.go(Routes.production(Routes.libraryWorld(_world), _story));
      await _until(tester, () => find.textContaining('Continue').evaluate().isNotEmpty);
      expect(find.textContaining('Lights together'), findsWidgets);
      await _tap(tester, find.textContaining('Continue'));
      await _until(tester, () => find.text('Lights together').evaluate().isNotEmpty && find.byType(StoryPlayerScreen).evaluate().isNotEmpty);
      router.go(Routes.production(Routes.libraryWorld(_world), _comic));
      await _until(tester, () => find.text('Continue · Page 2').evaluate().isNotEmpty);
      await _tap(tester, find.text('Continue · Page 2'));
      await _until(tester, () => find.text('2 of 3').evaluate().isNotEmpty && find.byType(ComicReaderScreen).evaluate().isNotEmpty);
      router.go(Routes.libraryWorld(_world));
      await tester.pump(const Duration(seconds: 1));
    } finally {
      HttpOverrides.global = previous;
    }
    expect(offline.attempts, 0, reason: 'Installed readers must not need a network client.');
    final reloaded = LibraryStore(root);
    await reloaded.load();
    try {
      expect(reloaded.stories[LibraryStore.storyKey(_world, _story)]!['route'], saved[LibraryStore.storyKey(_world, _story)]['route']);
      expect(reloaded.stories[LibraryStore.storyKey(_world, _comic)]!['comicPage'], 1);
      expect([
        for (final world in reloaded.worlds)
          if (world.id != _world) world.toJson(),
      ], unrelatedBefore);
      expect(reloaded.items.where((item) => item.worldId == _world).map((item) => item.toJson()).toList(), audioBefore);
      final evidence = {
        'checkedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'phase': _phase,
        'catalogueSerial': serial,
        'world': _world,
        'installedAtStart': installedAtStart,
        'storyRoute': reloaded.stories[LibraryStore.storyKey(_world, _story)]!['route'],
        'storyScene': reloaded.stories[LibraryStore.storyKey(_world, _story)]!['scene'],
        'comicPage': reloaded.stories[LibraryStore.storyKey(_world, _comic)]!['comicPage'],
        'offlineNetworkClients': offline.attempts,
        'audioAndUnrelatedWorldsUnchanged': true,
        'device': Platform.operatingSystemVersion,
      };
      await File('${root.parent.path}/publishing-formats-$_phase.json').writeAsString(const JsonEncoder.withIndent('  ').convert(evidence), flush: true);
      debugPrint('LIVE_FORMATS_EVIDENCE ${jsonEncode(evidence)}');
    } finally {
      await reloaded.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

bool _installed(LibraryStore store, String id) => store.worlds.singleWhere((world) => world.id == _world).productions.any((production) => production.id == id);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  // A route's text exists during the slide transition, before it can receive a tap.
  await _until(tester, () => finder.hitTestable().evaluate().isNotEmpty);
  await tester.tap(finder.hitTestable().first);
}

Future<void> _until(WidgetTester tester, bool Function() ready, {int seconds = 30}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: 'Timed out waiting for the real app state.');
  await tester.pump(const Duration(milliseconds: 200));
}

class _Offline extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const SocketException('Offline reader acceptance test');
  }
}
