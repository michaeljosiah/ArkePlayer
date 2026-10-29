import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/players/application/audio_engine.dart';
import 'package:arke_player/features/players/application/listening_plan.dart';
import 'package:arke_player/features/players/application/music.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/players/presentation/audio_player_screen.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// The real AudioEngine still owns selection and queue reuse. Only the device codec is replaced.
class _NativePlayer implements AudioPlayer {
  @override
  int? currentIndex = 0;
  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  List<AudioSource> sources = [];
  int loads = 0;
  final seeks = <(int?, Duration)>[];

  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => const Stream.empty();
  @override
  Stream<ProcessingState> get processingStateStream => const Stream.empty();
  @override
  Duration get bufferedPosition => position;
  @override
  Duration get duration => const Duration(seconds: 60);
  @override
  double get speed => 1;

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    sources = audioSources;
    loads++;
    currentIndex = initialIndex ?? 0;
    position = initialPosition ?? Duration.zero;
    return duration;
  }

  @override
  Future<Duration?> setFilePath(String path, {Duration? initialPosition, bool preload = true, dynamic tag}) async {
    loads++;
    position = initialPosition ?? Duration.zero;
    return duration;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    if (index != null) currentIndex = index;
    this.position = position ?? Duration.zero;
    seeks.add((index, this.position));
  }

  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ListeningPlan _plan([int count = 3]) => ListeningPlan(
  document: ListeningDocument(
    title: 'The Ledger of Nights',
    chapters: [
      for (var i = 0; i < count; i++)
        ListeningChapter(id: 'ch${i + 1}', order: i + 1, title: 'Chapter ${i + 1}', duration: const Duration(seconds: 60), audio: 'audio${i + 1}'),
    ],
  ),
  pathOf: (id) => '/world/$id.m4a',
);

LibraryItem _item([int count = 3]) => LibraryItem(
  id: 'undersong.ledger-of-nights.listening',
  format: FileFormat.listening,
  title: 'The Ledger of Nights',
  byteLength: count * 1000,
  addedAt: DateTime.utc(2026, 10, 26),
  file: 'worlds/undersong/listening.json',
  worldId: 'undersong',
  duration: Duration(seconds: count * 60),
  chapters: [
    for (var i = 0; i < count; i++)
      Chapter(
        id: 'ch${i + 1}',
        title: 'Chapter ${i + 1}',
        start: Duration(seconds: i * 60),
      ),
  ],
);

class _Settings extends SettingsController {
  @override
  Future<DeviceSettings> build() async => const DeviceSettings();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => null,
    );
  });

  group('explicit chapter selection in the real audio engine', () {
    late _NativePlayer native;
    late AudioEngine engine;
    final kept = <(Place, bool?)>[];
    setUp(() {
      native = _NativePlayer();
      engine = AudioEngine(player: native);
      kept.clear();
    });
    tearDown(() => engine.stop());
    void keep(Place place, {bool? finished}) => kept.add((place, finished));

    test('a loaded book seeks to Chapters 2 and 3 instead of continuing Chapter 1', () async {
      final item = _item(), plan = _plan();
      await engine.open(item, plan: plan, speed: 1, keep: keep);
      native.position = const Duration(seconds: 17);
      await engine.open(item, plan: plan, startAt: plan.starts[1], speed: 1, keep: keep);
      expect((native.currentIndex, native.position), (1, Duration.zero));
      expect(kept.last.$1.locator, 'ch2');
      await engine.open(item, plan: plan, startAt: plan.starts[2], speed: 1, keep: keep);
      expect((native.currentIndex, native.position), (2, Duration.zero));
      expect(kept.last.$1.locator, 'ch3');
      expect(native.loads, 1, reason: 'an unchanged queue only needs a seek');
    });

    test('a cold chapter press overrides a stale saved place and finished flag', () async {
      final item = _item().copyWith(
        place: Place(locator: 'ch1', position: const Duration(seconds: 59), progress: 1, updatedAt: DateTime.utc(2026)),
        finished: true,
      );
      await engine.open(item, plan: _plan(), startAt: const Duration(minutes: 1), speed: 1, keep: keep);
      expect((native.currentIndex, native.position), (1, Duration.zero));
      expect((kept.last.$1.locator, kept.last.$2), ('ch2', false));
    });

    test('an old one-chapter queue is rebuilt after more chapters arrive under the same id', () async {
      await engine.open(_item(1), plan: _plan(1), speed: 1, keep: keep);
      await engine.open(_item(), plan: _plan(), startAt: const Duration(minutes: 2), speed: 1, keep: keep);
      expect(native.loads, 2);
      expect(native.sources, hasLength(3));
      expect(native.currentIndex, 2);
      expect(engine.plan!.chapters, hasLength(3));
    });

    test('opening from the dock keeps the current position without another seek', () async {
      await engine.open(_item(), plan: _plan(), startAt: const Duration(seconds: 65), speed: 1, keep: keep);
      native.position = const Duration(seconds: 19);
      final seeks = native.seeks.length;
      await engine.pause();
      await engine.open(_item(), plan: _plan(), speed: 1, keep: keep);
      expect((native.currentIndex, native.position), (1, const Duration(seconds: 19)));
      expect(native.seeks, hasLength(seeks));
      expect(native.loads, 1);
      expect(native.playing, isTrue);
    });

    test('standard audiobook chapter presses also seek a loaded file', () async {
      final item = LibraryItem(id: 'file', format: FileFormat.m4b, title: 'A book', byteLength: 10, addedAt: DateTime.utc(2026), file: 'book.m4b');
      await engine.open(item, path: '/book.m4b', speed: 1, keep: keep);
      await engine.open(item, path: '/book.m4b', startAt: const Duration(seconds: 30), speed: 1, keep: keep);
      expect(native.position, const Duration(seconds: 30));
      expect(native.loads, 1);
    });
  });

  test('an open item follows saved places and appended chapter metadata without a new store', () async {
    final root = await Directory.systemTemp.createTemp('arke-open-item-');
    final store = LibraryStore(root);
    await store.load();
    final container = ProviderContainer(overrides: [libraryStoreProvider.overrideWith((ref) async => store)]);
    final item = _item(1);
    await store.add(item);
    final subscription = container.listen(openItemProvider(item.id), (_, _) {});
    try {
      expect((await container.read(openItemProvider(item.id).future))!.item.chapters, hasLength(1));
      final changed = Completer<void>();
      final watch = container.listen(openItemProvider(item.id), (_, value) {
        if (value.value?.item.chapters.length == 3 && !changed.isCompleted) changed.complete();
      });
      await store.add(_item());
      await changed.future;
      expect(container.read(openItemProvider(item.id)).value!.item.chapters, hasLength(3));
      final moved = Completer<void>();
      final placeWatch = container.listen(openItemProvider(item.id), (_, value) {
        if (value.value?.item.place?.locator == 'ch3' && !moved.isCompleted) moved.complete();
      });
      await store.keepPlace(item.id, Place(locator: 'ch3', position: Duration.zero, progress: 0.67, updatedAt: DateTime.utc(2026)));
      await moved.future;
      expect(container.read(openItemProvider(item.id)).value!.item.place!.locator, 'ch3');
      placeWatch.close();
      watch.close();
    } finally {
      subscription.close();
      container.dispose();
      await store.close();
      await root.delete(recursive: true);
    }
  });

  testWidgets('world chapter rows carry the selected start through the real router to playback', (tester) async {
    final (root, store, item) = (await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('arke-chapter-press-');
      final source = Directory('${root.path}/source')..createSync();
      final audio = File('../../packages/arke_media/test/fixtures/chapters.m4b');
      final zip = File('${source.path}/world.zip');
      await packWorld(
        WorldSpec(
          id: 'undersong',
          edition: '2026-10-26',
          name: 'The Undersong',
          productions: [
            ProductionSpec(
              id: 'ledger-of-nights',
              title: 'The Ledger of Nights',
              listening: {
                'title': 'The Ledger of Nights',
                'chapters': [
                  for (var i = 1; i <= 3; i++)
                    {
                      'id': 'ch$i',
                      'title': ['Neap', 'Slack water', 'Warning slip'][i - 1],
                      'audio': audio.path,
                    },
                ],
              },
            ),
          ],
        ),
        zip.path,
      );
      final store = LibraryStore(Directory('${root.path}/library'));
      await store.load();
      final installer = WorldInstaller(store: store, freeBytes: (_) async => null);
      await installer.commit(await installer.prepareFile(size: await zip.length(), open: zip.openRead));
      final item = store.items.single;
      return (root, store, item);
    }))!;
    final native = _NativePlayer();
    // Use the same native fake for the engine and assertions below.
    final player = AudioEngine(player: native);
    final router = buildRouter(initialLocation: Routes.production(Routes.world('undersong'), 'ledger-of-nights'));
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryStoreProvider.overrideWith((ref) async => store),
            catalogueProvider.overrideWith((ref) async => []),
            catalogueRefreshProvider.overrideWith((ref) async {}),
            worldMusicProvider.overrideWith((ref, id) async => []),
            worldGuideProvider.overrideWith((ref, id) async => null),
            volumeProvider.overrideWith((ref) async => (free: 1000000000, total: 2000000000)),
            settingsProvider.overrideWith(_Settings.new),
            audioEngineProvider.overrideWithValue(player),
          ],
          child: MaterialApp.router(theme: arkeTheme(Brightness.light), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      for (final index in [1, 2]) {
        final title = ['Neap', 'Slack water', 'Warning slip'][index];
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        // Filesystem reads run outside the widget fake clock.
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 50 && native.currentIndex != index; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
          }
        });
        await tester.pumpAndSettle();
        expect(find.byType(AudioPlayerScreen), findsOneWidget);
        expect(native.currentIndex, index);
        expect(native.position, Duration.zero);
        expect(tester.widget<AudioPlayerScreen>(find.byType(AudioPlayerScreen)).startAt, item.chapters[index].start);
        router.pop();
        await tester.pumpAndSettle();
      }
    } finally {
      await tester.runAsync(() async {
        await player.stop();
        // Drain the serialized writes made by the engine before disposing its provider scope.
        final place = store.items.single.place;
        if (place != null) await store.keepPlace(item.id, place);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    }
  });
}
