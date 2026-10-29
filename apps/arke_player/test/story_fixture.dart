// The Undersong with its stories, as P18 draws them: Low Water (a 16:9 movie), Ring Once (a 9:16
// movie) and The Lantern Road (a visual novel), each read from the story fixtures that ArkeStudio's
// contracts write (SPEC-058 R-81), installed beside the edition; a clip shown as a still picture,
// since tests never play. Shared by story_test.dart, shoot_p18_test.dart and shoot_p19_test.dart; not a
// test of its own.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/parts/application/parts.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/stories/application/stories.dart';
import 'package:arke_player/features/worlds/application/discover.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design's pictures, which the shots show and the tests point at.
final designAssets =
    '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}design${Platform.pathSeparator}assets';
String designAsset(String name) => '$designAssets${Platform.pathSeparator}$name';

/// The shared story fixtures (SPEC-058 R-81).
final storyFixtures = '${Directory.current.path}/../../packages/arke_world/test/fixtures/story';
Map<String, Object?> storyJson(String name) => jsonDecode(File('$storyFixtures/$name').readAsStringSync()) as Map<String, Object?>;

const worldId = 'the-undersong';
const lowWaterId = 'low-water';
const ringOnceId = 'ring-once';
const lanternId = 'the-lantern-road';

/// Every asset a story document names, typed by its role, as the package's inventory gives them.
Map<String, WorldAsset> _assetsOf(Map<String, Object?> json) {
  final assets = <String, WorldAsset>{};
  WorldAsset asset(String id, String mediaType) => WorldAsset(path: 'story/$id', mediaType: mediaType, byteLength: 1, sha256: '0' * 64);
  for (final scene in (json['scenes']! as List<Object?>).cast<Map<String, Object?>>()) {
    for (final clip in (scene['clips'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) {
      assets[clip['asset']! as String] = asset(clip['asset']! as String, 'video/mp4');
    }
    for (final beat in (scene['beats'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) {
      for (final key in ['picture', 'tall']) {
        if (beat[key] case final String id) assets[id] = asset(id, 'image/jpeg');
      }
      if (beat['voice'] case final String id) assets[id] = asset(id, 'audio/mp4');
    }
  }
  return assets;
}

/// A story document read as the Player reads one.
StoryDocument readStoryJson(Map<String, Object?> json) => switch (readStory(jsonEncode(json), _assetsOf(json))) {
  StoryOk(:final document) => document,
  StoryRefused(:final reason) => throw StateError(reason),
};

/// A movie that runs straight through [scenes], `(id, title, length in ms)`, each taking the next by
/// the label in [labels]; [extra] more scenes after them, unreached, so the document has its count.
/// Every step offers a second way on, `Another way`, so it is a choice of two, except the steps
/// [lone] names by index, whose one way on is a lone way (P19 rule 4).
Map<String, Object?> chainStory(
  List<(String, String, int)> scenes,
  List<String> labels, {
  String shape = '9:16',
  int extra = 0,
  String kind = 'movie',
  Set<int> lone = const {},
}) => {
  'format': 'arke-story',
  'version': 1,
  'kind': kind,
  'shape': shape,
  'start': scenes.first.$1,
  'fingerprint': 'sha256:${'a' * 64}',
  'facts': <Object?>[],
  'scenes': [
    for (final (id, title, length) in [...scenes, for (var n = 1; n <= extra; n++) ('sc_more-$n', 'Scene $n', 1000)])
      {
        'id': id,
        'title': title,
        if (kind == 'movie')
          'clips': [
            {'asset': 'clip-$id', 'from': 0, 'to': length},
          ]
        else
          'beats': [
            {'picture': 'pic-$id'},
          ],
      },
  ],
  'presentation': <Object?>[],
  'choices': [
    for (var i = 0; i + 1 < scenes.length; i++) ...[
      {'id': 'ch_step-$i', 'from': scenes[i].$1, 'to': scenes[i + 1].$1, 'label': labels[i], 'effects': <Object?>[]},
      if (!lone.contains(i)) {'id': 'ch_other-$i', 'from': scenes[i].$1, 'to': scenes[i + 1].$1, 'label': 'Another way', 'effects': <Object?>[]},
    ],
  ],
  'endings': <Object?>[],
};

/// The production a story document is installed as.
LibraryProduction storyProduction(String id, String title, StoryDocument document, {String? picture, int bytes = 1200000000}) => LibraryProduction(
  id: id,
  title: title,
  picture: picture,
  story: LibraryStory(
    document: 'worlds/$worldId/_productions/$id/$id/story.json',
    kind: document.kind.name,
    shape: document.shape.label,
    scenes: document.scenes.length,
    fingerprint: document.fingerprint,
  ),
  package: LibraryProductionPackage(
    edition: '2026-10-28',
    fingerprint: 'd' * 64,
    byteLength: bytes,
    installedAt: DateTime.utc(2026, 10, 28),
    folder: 'worlds/$worldId/_productions/$id',
  ),
);

/// A story installed, its files the design's pictures: [pictures] by asset id, the rest [fallback].
LoadedStory loadedStory(
  LibraryProduction production,
  StoryDocument document, {
  Map<String, String> pictures = const {},
  String fallback = 'drowned-quarter.jpg',
}) => LoadedStory(
  worldId: worldId,
  worldName: 'The Undersong',
  production: production,
  document: document,
  pathOf: (assetId) => designAsset(pictures[assetId] ?? fallback),
  cover: production.picture == null ? null : designAsset(production.picture!),
);

/// The installed world: The Ledger of Nights and [stories].
LibraryWorld storyWorld(List<LibraryProduction> stories) => LibraryWorld(
  id: worldId,
  edition: '2026-10-22',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
  keyArt: 'world-undersong.jpg',
  byteLength: 386000000,
  installedAt: DateTime.utc(2026, 10, 22),
  fingerprint: 'e' * 64,
  productions: [
    const LibraryProduction(id: 'the-ledger-of-nights', title: 'The Ledger of Nights', picture: 'ledger-of-nights.jpg'),
    ...stories,
  ],
);

CatalogueStory storyPin(String id, {int version = 1, String fingerprint = 'd'}) => CatalogueStory(
  url: Uri.parse('https://example.org/$id.zip'),
  byteLength: 1200000000,
  sha256: 'c' * 64,
  edition: '2026-10-28',
  fingerprint: fingerprint * 64,
  version: version,
);

/// Arke's list: the edition, and each of [stories] as `(id, title, kind line, version)`.
CatalogueWorld listedStoryWorld(List<(String, String, String, int)> stories) => CatalogueWorld(
  id: worldId,
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
  keyArt: 'assets/worlds/undersong/key-art.jpg',
  productions: [
    const CatalogueProduction(id: 'the-ledger-of-nights', title: 'The Ledger of Nights', kind: 'Audiobook · Book · 23 chapters'),
    for (final (id, title, kind, version) in stories)
      CatalogueProduction(
        id: id,
        title: title,
        kind: kind,
        story: storyPin(id, version: version),
      ),
  ],
  package: CataloguePackage(
    url: Uri.parse('https://example.org/undersong.zip'),
    byteLength: 386000000,
    sha256: 'b' * 64,
    edition: '2026-10-22',
    fingerprint: 'e' * 64,
  ),
);

class _Ticks extends ChangeNotifier {
  void tick() => notifyListeners();
}

/// A clip as a still picture: the file it is opened on, shown whole. [instant] plays it through at
/// once, as a test needs to reach the choices; otherwise it holds where it is.
class PictureReel extends StoryReel {
  PictureReel({this.instant = false, this.shape = const Size(1920, 1080)});
  final bool instant;
  final Size shape;
  final opened = <String>[];
  String? _path;
  Duration _position = Duration.zero;
  bool _playing = false;
  final _ticks = _Ticks();

  @override
  Future<void> open(String path) async {
    _path = path;
    opened.add(path);
  }

  @override
  Future<void> seek(Duration at) async => _position = at;

  @override
  Future<void> play() async {
    _playing = true;
    if (instant) {
      Timer(Duration.zero, () {
        _position = const Duration(hours: 9);
        _playing = false;
        _ticks.tick();
      });
    }
  }

  @override
  Future<void> pause() async => _playing = false;
  @override
  Duration get position => _position;
  @override
  bool get playing => _playing;
  @override
  Duration get length => const Duration(hours: 9);
  @override
  Size get size => shape;
  @override
  Listenable get changes => _ticks;
  @override
  Widget view() => _path == null ? const SizedBox.shrink() : Image.file(File(_path!), key: const ValueKey('reel'), fit: BoxFit.cover);
  @override
  Future<void> dispose() async {}
}

/// Saves kept in memory, every one written heard.
class MemorySaves extends StorySaves {
  MemorySaves([this.initial = const {}]);
  final Map<String, Map<String, Object?>> initial;
  final kept = <Map<String, Object?>?>[];

  @override
  Future<Map<String, Map<String, Object?>>> build() async => initial;

  @override
  Future<void> keep(LoadedStory story, StorySave? save) async {
    final json = save?.toJson();
    kept.add(json);
    if (!ref.mounted) return;
    state = AsyncData({
      for (final MapEntry(:key, :value) in (state.value ?? const <String, Map<String, Object?>>{}).entries)
        if (key != story.key) key: value,
      story.key: ?json,
    });
  }
}

/// A novel's voices, heard by a test: a line speaks until the test [end]s it, as a real one speaks
/// for as long as it lasts, so nothing moves on behind a test's back.
class HeardVoice implements StoryVoice {
  final played = <String>[];
  Completer<void>? _line;

  /// Paused mid-line.
  bool paused = false;

  /// A line is speaking, or paused mid-line.
  bool get speaking => _line != null;

  /// The line speaking ends: it has been heard through.
  void end() {
    final line = _line;
    _line = null;
    line?.complete();
  }

  @override
  Future<void> play(String path) {
    end();
    played.add(path);
    paused = false;
    return (_line = Completer<void>()).future;
  }

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<void> resume() async => paused = false;

  // A stopped line completes, as the platform's does.
  @override
  Future<void> stop() async {
    paused = false;
    end();
  }
}

class _Kept extends KeptPictures {
  @override
  Future<Map<String, File>> build() async => const {};

  @override
  Future<void> keepFor(Iterable<CatalogueWorld> worlds) async {}
}

class _Settings extends SettingsController {
  @override
  Future<DeviceSettings> build() async => const DeviceSettings();
}

class _Quiet extends PartsController {
  @override
  Map<String, PartArrival> build() => const {};

  @override
  Future<void> check() async {}
}

/// A save at [route] of [document], at [place].
Map<String, Object?> saveAt(StoryDocument document, List<String> route, {StoryPlace place = const StoryAtChoice(), String? fingerprint}) {
  final step = evaluateStory(document, route);
  return StorySave(
    route: route,
    scene: step.scene,
    place: place,
    fingerprint: fingerprint ?? document.fingerprint,
    updatedAt: DateTime.utc(2026, 10, 28),
  ).toJson();
}

/// Pumps the app at [location] over The Undersong and [stories], installed unless [installed] is
/// false. [stills] names each scene's still by scene id.
Future<void> pumpStories(
  WidgetTester tester,
  String location, {
  required List<LoadedStory> stories,
  Size size = const Size(390, 844),
  double ratio = 1,
  Brightness brightness = Brightness.light,
  bool installed = true,
  CatalogueWorld? listed,
  MemorySaves? saves,
  PictureReel Function()? reel,
  HeardVoice? voice,
  Map<String, String> stills = const {},
  Key? key,
}) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  if (ratio > 1) tester.view.padding = FakeViewPadding(top: (size.width > size.height ? 0 : 47) * ratio, bottom: (size.width > size.height ? 21 : 34) * ratio);
  addTearDown(tester.view.reset);
  final world = storyWorld([for (final story in stories) story.production]);
  await tester.pumpWidget(
    ProviderScope(
      // A test may pump twice: each pump is a fresh app, its saves and its route its own.
      key: UniqueKey(),
      overrides: [
        libraryStoreProvider.overrideWith((ref) async => LibraryStore(Directory(designAssets))),
        libraryItemsProvider.overrideWith((ref) => Stream.value(const [])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value(installed ? [world] : const [])),
        volumeProvider.overrideWith((ref) async => (free: 40000000000, total: 128000000000)),
        catalogueProvider.overrideWith(
          (ref) async => [
            listed ??
                listedStoryWorld([
                  for (final story in stories)
                    (
                      story.production.id,
                      story.production.title,
                      '${storyKindLabel(story.document.kind.name)} · ${sceneCount(story.document.scenes.length)}',
                      1,
                    ),
                ]),
          ],
        ),
        catalogueRefreshProvider.overrideWith((ref) async {}),
        listPicksProvider.overrideWith((ref) async => (feature: null, band: null)),
        keptPicturesProvider.overrideWith(_Kept.new),
        worldGuideProvider.overrideWith((ref, id) async => null),
        guideFetchProvider.overrideWith((ref, id) async {}),
        guideReachProvider.overrideWith((ref, id) async => GuideReach.none),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 28, 9)),
        partsProvider.overrideWith(_Quiet.new),
        settingsProvider.overrideWith(_Settings.new),
        audioEngineProvider.overrideWithValue(null),
        placeKeeperProvider.overrideWithValue((id, place, {finished}) async {}),
        loadedStoryProvider.overrideWith((ref, key) async => stories.where((story) => story.worldId == key.$1 && story.production.id == key.$2).firstOrNull),
        storySavesProvider.overrideWith(() => saves ?? MemorySaves()),
        storyReelProvider.overrideWithValue(reel ?? PictureReel.new),
        storyVoiceProvider.overrideWithValue(voice ?? HeardVoice()),
        storyStillProvider.overrideWith((ref, key) async => FileImage(File(designAsset(stills[key.$3] ?? 'drowned-quarter.jpg')))),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: arkeTheme(brightness),
          routerConfig: buildRouter(initialLocation: location),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
