// Opt-in native rehearsal for the exact original Motion Garden dev publication.
// No publishing writes, account credentials, provider overrides or fake video engine.
import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/app.dart';
import 'package:arke_player/app/catalogue_channel.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/features/players/presentation/chrome.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

const _world = 'motion-garden-dev-403-2';
const _production = 'paper-lights-movie';
const _archive = '9dd5e6f1d4f072d717dbb7479d67017a605c2db25651e59bb87c0c54683c9180';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('live native movie, both choices and cold offline saved progress', (tester) async {
    expect(const bool.fromEnvironment('ARKE_LIVE_MOVIE_REHEARSAL'), isTrue);
    expect(Platform.isAndroid, isTrue);
    expect(catalogueChannel.storageFolder, 'arke-worlds-dev');
    expect(catalogueChannel.url.host, 'aonik-dev-api.delightfulisland-9fd7c1e7.uksouth.azurecontainerapps.io');
    await app.main();
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(ArkePlayerApp)));
    final router = container.read(routerProvider);
    final store = await container.read(libraryStoreProvider.future);
    final root = await container.read(libraryRootProvider.future);
    // External test control only; never a saved place. Reuse one APK across cold restarts.
    final phaseFile = File('${root.parent.path}/movie-rehearsal-phase.txt');
    final phase = await phaseFile.exists() ? (await phaseFile.readAsString()).trim() : 'install';
    expect(['install', 'offline', 'refresh', 'replay', 'withdrawn'], contains(phase));
    final proof = Directory('${root.parent.path}/movie-evidence')..createSync(recursive: true);
    final evidence = <String, Object?>{'phase': phase, 'checkedAtUtc': DateTime.now().toUtc().toIso8601String(), 'world': _world};
    final saveKey = LibraryStore.storyKey(_world, _production);
    final unrelated = [
      for (final world in store.worlds)
        if (world.id != _world) world.toJson(),
    ];
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      // Android's image surface can still hold the prior raster frame on the first read.
      await binding.takeScreenshot('movie-$phase-$name-frame');
      await tester.pump(const Duration(milliseconds: 100));
      final bytes = await binding.takeScreenshot('movie-$phase-$name');
      await File('${proof.path}/$phase-$name.png').writeAsBytes(bytes, flush: true);
    }

    Future<VideoPlayerController> playing(String clip, {VideoPlayerController? previous}) async {
      await _until(tester, () {
        final widgets = tester.widgetList<VideoPlayer>(find.byType(VideoPlayer));
        return widgets.any(
          (widget) =>
              widget.controller != previous &&
              widget.controller.dataSource.endsWith(clip) &&
              widget.controller.value.isInitialized &&
              widget.controller.value.isPlaying,
        );
      });
      return tester
          .widgetList<VideoPlayer>(find.byType(VideoPlayer))
          .firstWhere((widget) => widget.controller != previous && widget.controller.dataSource.endsWith(clip))
          .controller;
    }

    Future<void> leavePaused(VideoPlayerController video, {String? captureName}) async {
      await tester.pump();
      if (find.byType(PlayPause).hitTestable().evaluate().isEmpty) {
        await tester.tap(find.byType(VideoPlayer).first);
        await tester.pump();
      }
      // No route-transition delay here: the visible controls may be about to rest.
      await _until(tester, () => find.byType(PlayPause).hitTestable().evaluate().isNotEmpty);
      await tester.tap(find.byType(PlayPause).hitTestable().first);
      await tester.pump();
      await _until(tester, () => !video.value.isPlaying);
      final position = video.value.position.inMilliseconds;
      expect(position, inInclusiveRange(1000, 11000));
      evidence['pausedAtMs'] = position;
      if (captureName != null) await capture(captureName);
      router.go(Routes.libraryWorld(_world));
      await _until(tester, () => (store.stories[saveKey]?['at'] as int? ?? 0) >= position - 250);
      await tester.pump(const Duration(milliseconds: 500));
    }

    if (phase == 'install') {
      await container.read(catalogueCheckProvider.notifier).check();
      expect(container.read(catalogueCheckProvider), CatalogueCheck.checked);
      final catalogue = await container.read(catalogueProvider.future);
      final listed = catalogue.singleWhere((world) => world.id == _world);
      expect(listed.package, isNull);
      expect(listed.productions.single.story!.sha256, _archive);
      // A harness interrupted after download can resume the same verified installation.
      // Never clear a real library or manufacture a story save to make a rehearsal repeatable.
      final priorSave = store.stories[saveKey];
      evidence['saveBeforePlaybackPhase'] = priorSave;
      evidence['installedBeforePlaybackPhase'] = store.worlds.any((world) => world.id == _world);
      await _until(tester, () => find.text('Motion Garden Dev 403').evaluate().isNotEmpty);
      await capture('discovery');
      router.go(Routes.world(_world));
      if (!store.worlds.any((world) => world.id == _world)) {
        await _tap(tester, find.textContaining('Start ·', findRichText: true));
        await _until(tester, () => store.worlds.any((world) => world.id == _world));
      }
      final installed = store.worlds.singleWhere((world) => world.id == _world);
      expect(installed.productions.single.package!.fingerprint, '6a3becceacd341d81ee2d5b43c23a6f60cb5fb81157641b26e4755daef106e54');
      await capture('installed');
      router.go(Routes.production(Routes.libraryWorld(_world), _production));
      await _tap(tester, find.textContaining(priorSave == null ? 'Play' : 'Continue', findRichText: true));
      if (priorSave != null) {
        // Retry a completed branch through the ordinary ending's Start again control.
        await _tap(tester, find.text('Start again'));
      }
      final seed = await playing('c001.mp4');
      expect(seed.value.size.width, 640);
      expect(seed.value.size.height, 360);
      expect(seed.value.duration.inMilliseconds, inInclusiveRange(11900, 12100));
      await _until(tester, () => seed.value.position.inMilliseconds >= 600);
      final before = seed.value.position.inMilliseconds;
      await capture('seed-frame-a');
      await _until(tester, () => seed.value.position.inMilliseconds > before + 1000);
      evidence['seedNativePositionsMs'] = [before, seed.value.position.inMilliseconds];
      await capture('seed-frame-b');
      await _until(tester, () => find.text('Plant it in the sun').evaluate().isNotEmpty);
      expect(find.text('Share it with a friend'), findsOneWidget);
      await capture('choices');
      await _tap(tester, find.text('Plant it in the sun'));
      final sun = await playing('c002.mp4');
      await _until(tester, () => sun.value.position.inMilliseconds >= 1200);
      evidence['sunNativePositionMs'] = sun.value.position.inMilliseconds;
      await capture('sun-playing');
      await _until(tester, () => find.text('Back to last choice').hitTestable().evaluate().isNotEmpty);
      expect(store.stories[saveKey]!['route'], ['ch_sun']);
      await capture('sun-ending');
      await _tap(tester, find.text('Back to last choice'));
      await _tap(tester, find.text('Share it with a friend'));
      final friend = await playing('c003.mp4');
      await _until(tester, () => friend.value.position.inMilliseconds >= 1200);
      evidence['friendNativePositionMs'] = friend.value.position.inMilliseconds;
      await capture('friend-playing');
      await _until(tester, () => find.text('Back to last choice').hitTestable().evaluate().isNotEmpty);
      expect(store.stories[saveKey]!['route'], ['ch_friend']);
      await capture('friend-ending');
      // Leave a real mid-scene save for the separate process, with radios off.
      await _tap(tester, find.text('Back to last choice'));
      await _tap(tester, find.text('Share it with a friend'));
      final resumedFriend = await playing('c003.mp4', previous: friend);
      await _until(tester, () => resumedFriend.value.position.inMilliseconds >= 1500);
      await leavePaused(resumedFriend);
      evidence['bothEndings'] = true;
    } else if (phase == 'replay') {
      // Recover an interrupted test through ordinary controls; never inject progress.
      expect(store.stories[saveKey]!['choosing'], isTrue);
      router.go(Routes.production(Routes.libraryWorld(_world), _production));
      await _tap(tester, find.textContaining('Continue'));
      await _tap(tester, find.text('Back to last choice'));
      await _tap(tester, find.text('Share it with a friend'));
      final video = await playing('c003.mp4');
      await _until(tester, () => video.value.position.inMilliseconds >= 1500);
      await leavePaused(video, captureName: 'prepared-frame');
    } else if (phase == 'refresh') {
      await container.read(catalogueCheckProvider.notifier).check();
      expect(container.read(catalogueCheckProvider), CatalogueCheck.checked);
      final hosted = await container.read(hostedCatalogueProvider.future);
      final kept = (await hosted.keptList())!;
      expect(kept.serial, greaterThan(25));
      expect(kept.worlds.where((world) => world.id == _world), isEmpty);
      evidence['withdrawnSerial'] = kept.serial;
    } else {
      expect(store.worlds.any((world) => world.id == _world), isTrue);
      final before = Map<String, Object?>.from(store.stories[saveKey]!);
      expect(before['scene'], 'sc_friend');
      expect(before['route'], ['ch_friend']);
      expect(before['at'], inInclusiveRange(1000, 11000));
      evidence['savedBeforeRestart'] = before;
      if (phase == 'withdrawn') {
        final hosted = await container.read(hostedCatalogueProvider.future);
        final kept = await hosted.keptList();
        expect(kept!.serial, greaterThan(25));
        expect(kept.worlds.where((world) => world.id == _world), isEmpty);
        evidence['withdrawnSerial'] = kept.serial;
      }
      router.go(Routes.production(Routes.libraryWorld(_world), _production));
      await _tap(tester, find.textContaining('Continue'));
      final video = await playing('c003.mp4');
      final first = video.value.position.inMilliseconds;
      expect(first, greaterThanOrEqualTo((before['at']! as int) - 250));
      expect(first, lessThan((before['at']! as int) + 2000));
      await _until(tester, () => video.value.position.inMilliseconds > first + 700);
      evidence['resumedNativePositionsMs'] = [first, video.value.position.inMilliseconds];
      await leavePaused(video, captureName: 'resumed-frame');
    }
    final reloaded = LibraryStore(root);
    await reloaded.load();
    try {
      expect(reloaded.stories[saveKey]!['route'], ['ch_friend']);
      expect(reloaded.stories[saveKey]!['scene'], 'sc_friend');
      expect([
        for (final world in reloaded.worlds)
          if (world.id != _world) world.toJson(),
      ], unrelated);
      evidence['persistedSave'] = reloaded.stories[saveKey];
      evidence['installedWorld'] = reloaded.worlds.singleWhere((world) => world.id == _world).toJson();
      await File('${proof.path}/$phase.json').writeAsString(const JsonEncoder.withIndent('  ').convert(evidence), flush: true);
      // A pass file is written only after every assertion, and contains no credentials or media bytes.
      debugPrint('LIVE_MOVIE_EVIDENCE ${jsonEncode(evidence)}');
    } finally {
      await reloaded.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  // Let a route's previous page leave before matching its identical Start press.
  await tester.pump(const Duration(milliseconds: 400));
  await _until(tester, () => finder.hitTestable().evaluate().isNotEmpty);
  await tester.tap(finder.hitTestable().first);
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() ready, {int seconds = 40}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: 'Timed out waiting for real native movie state.');
}
