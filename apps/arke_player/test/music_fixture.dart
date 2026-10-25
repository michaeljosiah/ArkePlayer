// The Undersong with its music, as P17 draws it: The Ledger of Nights narrated, an album, a single
// and a soundtrack installed beside the edition, a guide whose Chorister and Maren have themes and
// whose teasers hold a song, and an engine held still. Shared by music_test.dart and
// shoot_p17_test.dart; not a test of its own.
import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/parts/application/parts.dart';
import 'package:arke_player/features/players/application/audio_engine.dart';
import 'package:arke_player/features/players/application/listening_plan.dart';
import 'package:arke_player/features/players/application/music.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/discover.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// The design's pictures, which the shots show and the tests point at.
final designAssets =
    '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}..${Platform.pathSeparator}design${Platform.pathSeparator}assets';
String designAsset(String name) => '$designAssets${Platform.pathSeparator}$name';

const worldId = 'the-undersong';
const ledgerId = 'the-ledger-of-nights';
const albumId = 'songs-of-the-drowned-quarter';
const singleId = 'saltmouth-bells';
const scoreId = 'the-bell-watch-soundtrack';
const narrationId = 'the-undersong.the-ledger-of-nights.listening';

Duration _length(String clock) {
  final [minutes, seconds] = clock.split(':').map(int.parse).toList();
  return Duration(minutes: minutes, seconds: seconds);
}

/// The Ledger's chapters: 23, with P17g's 7 to 10 at their drawn lengths.
final chapterLengths = [
  for (var n = 1; n <= 23; n++) Duration(minutes: const {7: 32, 8: 38, 9: 44, 10: 36}[n] ?? 35),
];
final chapters = [for (var n = 1, at = Duration.zero; n <= 23; at += chapterLengths[n - 1], n++) Chapter(title: 'Chapter $n', start: at, id: 'ch$n')];
Duration get ledgerLength => chapterLengths.fold(Duration.zero, (sum, length) => sum + length);

/// P17's nine tracks, the words of the first as the Studio wrote them, with its structure tags.
const lyrics =
    '[verse]\nUnder the harbour the old bells turn,\nsalt in the ledger, the lamps that burn.\nCount me the tides that the city forgot,\nsing me the name that the water has not.\n\n[chorus]\nHold the verse, hold it low,\ndown where the drowned ones go.';
final albumTracks = [
  MusicTrack(
    id: 'the-drowned-verse',
    title: 'The Drowned Verse',
    audio: 'the-drowned-verse',
    duration: _length('4:12'),
    lyrics: const MusicLyrics(
      text: lyrics,
      sections: [MusicSection(label: 'Verse', at: Duration(seconds: 14))],
    ),
    heardIn: const [MusicHeardIn(production: ledgerId, chapter: 'ch9', at: Duration(minutes: 12, seconds: 10))],
  ),
  MusicTrack(id: 'slack-water', title: 'Slack Water', audio: 'slack-water', duration: _length('3:05')),
  MusicTrack(
    id: 'saltmouth-bells',
    title: 'Saltmouth Bells',
    audio: 'saltmouth-bells',
    duration: _length('3:42'),
    heardIn: const [MusicHeardIn(production: ledgerId, chapter: 'ch8', at: Duration(minutes: 3))],
  ),
  MusicTrack(id: 'tide-caller', title: 'Tide-caller', audio: 'tide-caller', duration: _length('3:58')),
  MusicTrack(id: 'the-vigil', title: 'The Vigil', audio: 'the-vigil', duration: _length('4:40')),
  MusicTrack(id: 'lantern-road', title: 'Lantern Road', audio: 'lantern-road', duration: _length('3:20')),
  MusicTrack(id: 'ledger-hymn', title: 'Ledger Hymn', audio: 'ledger-hymn', duration: _length('2:55')),
  MusicTrack(id: 'low-water', title: 'Low Water', audio: 'low-water', duration: _length('3:33')),
  MusicTrack(id: 'undersong', title: 'Undersong', audio: 'undersong', duration: _length('5:01')),
];
final singleTrack = MusicTrack(
  id: 'saltmouth-bells',
  title: 'Saltmouth Bells',
  audio: 'saltmouth-bells',
  duration: _length('3:42'),
  heardIn: const [MusicHeardIn(production: ledgerId, chapter: 'ch8', at: Duration(minutes: 3))],
);
final scoreTracks = [
  for (var n = 1; n <= 14; n++) MusicTrack(id: 'cue-$n', title: 'Cue $n', audio: 'cue-$n', duration: const Duration(minutes: 3, seconds: 20)),
];

Duration _sum(List<MusicTrack> tracks) => tracks.fold(Duration.zero, (sum, track) => sum + track.duration);

LibraryProduction _music(String id, String title, String kind, List<MusicTrack> tracks, String picture, {String? forProduction, String fingerprint = 'a'}) =>
    LibraryProduction(
      id: id,
      title: title,
      picture: picture,
      music: LibraryMusic(
        document: 'worlds/$worldId/_productions/$id/$id/music.json',
        kind: kind,
        tracks: tracks.length,
        duration: _sum(tracks),
        forProduction: forProduction,
      ),
      package: LibraryProductionPackage(
        edition: '2026-10-24',
        fingerprint: fingerprint * 64,
        byteLength: tracks.length * 4000000,
        installedAt: DateTime.utc(2026, 10, 24),
        folder: 'worlds/$worldId/_productions/$id',
      ),
    );

/// The installed world; its pictures are the design's, relative to [pictures] as a library's root.
LibraryWorld undersong({bool music = true, String albumFingerprint = 'a'}) => LibraryWorld(
  id: worldId,
  edition: '2026-10-22',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
  keyArt: 'world-undersong.jpg',
  byteLength: 386000000,
  installedAt: DateTime.utc(2026, 10, 22),
  fingerprint: 'e' * 64,
  productions: [
    const LibraryProduction(id: ledgerId, title: 'The Ledger of Nights', picture: 'ledger-of-nights.jpg', narration: narrationId),
    if (music) ...[
      _music(albumId, 'Songs of the Drowned Quarter', 'album', albumTracks, 'scene4-shot15.jpg', fingerprint: albumFingerprint),
      _music(singleId, 'Saltmouth Bells', 'single', [singleTrack], 'launch-harbour.jpg'),
      _music(scoreId, 'The Bell Watch — Soundtrack', 'soundtrack', scoreTracks, 'scene4-shot14b.jpg', forProduction: 'the-bell-watch'),
    ],
  ],
);

/// The narration, at chapter 9, 12 minutes in: 7 and 8 heard (P17g).
final narration = LibraryItem(
  id: narrationId,
  format: FileFormat.listening,
  title: 'The Ledger of Nights',
  byteLength: 300000000,
  addedAt: DateTime.utc(2026, 10, 22),
  file: 'worlds/$worldId/$ledgerId/listening.json',
  cover: 'ledger-of-nights.jpg',
  duration: ledgerLength,
  chapters: chapters,
  place: Place(locator: 'ch9', position: const Duration(minutes: 12), progress: 0.35, updatedAt: DateTime.utc(2026, 10, 23)),
  worldId: worldId,
);

/// The world's music, read, its files the design's.
MusicAlbum musicAlbum(LibraryProduction production) {
  final kind = MusicKind.values.byName(production.music!.kind);
  final tracks = switch (kind) {
    MusicKind.album => albumTracks,
    MusicKind.single => [singleTrack],
    MusicKind.soundtrack => scoreTracks,
  };
  return MusicAlbum(
    worldId: worldId,
    worldName: 'The Undersong',
    production: production,
    document: MusicDocument(kind: kind, tracks: tracks, forProduction: production.music!.forProduction),
    pathOf: (asset) => designAsset('$asset.m4a'),
    cover: designAsset(production.picture!),
  );
}

List<MusicAlbum> worldMusic([LibraryWorld? world]) => [
  for (final production in (world ?? undersong()).productions)
    if (production.music != null) musicAlbum(production),
];

PicturePin _pin(String name) =>
    PicturePin(url: Uri.parse('https://example.org/$name'), byteLength: 1000, sha256: name.hashCode.toRadixString(16).padLeft(64, '0'));

/// The pictures the list pins, kept: what [keptPictures] hands a row.
final pinned = {
  for (final name in ['scene4-shot15.jpg', 'launch-harbour.jpg', 'scene4-shot14b.jpg']) _pin(name).sha256: File(designAsset(name)),
};

CatalogueProduction _listedMusic(String id, String title, String kind, MusicKind music, String picture, {String fingerprint = 'a', int bytes = 36000000}) =>
    CatalogueProduction(
      id: id,
      title: title,
      kind: kind,
      picturePin: _pin(picture),
      music: music,
      package: CataloguePackage(
        url: Uri.parse('https://example.org/$id.zip'),
        byteLength: bytes,
        sha256: 'c' * 64,
        edition: '2026-10-24',
        fingerprint: fingerprint * 64,
      ),
    );

/// Arke's list: P17a's world, its music published on its own.
CatalogueWorld listedUndersong({String albumFingerprint = 'a', bool lantern = false}) => CatalogueWorld(
  id: worldId,
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
  keyArt: 'assets/worlds/undersong/key-art.jpg',
  productions: [
    const CatalogueProduction(
      id: ledgerId,
      title: 'The Ledger of Nights',
      kind: 'Audiobook · Book · 23 chapters',
      picture: 'assets/worlds/undersong/ledger-of-nights.jpg',
    ),
    const CatalogueProduction(id: 'undertow', title: 'Undertow', kind: 'Audio drama · 8 episodes'),
    _listedMusic(albumId, 'Songs of the Drowned Quarter', 'Album · 9 tracks', MusicKind.album, 'scene4-shot15.jpg', fingerprint: albumFingerprint),
    _listedMusic(singleId, 'Saltmouth Bells', 'Single · 3:42', MusicKind.single, 'launch-harbour.jpg'),
    _listedMusic(scoreId, 'The Bell Watch — Soundtrack', 'Soundtrack · 14 tracks', MusicKind.soundtrack, 'scene4-shot14b.jpg'),
    if (lantern) _listedMusic('lantern-songs', 'Lantern Songs', 'Album · 6 tracks', MusicKind.album, 'scene4-shot14b.jpg', bytes: 18000000),
    const CatalogueProduction(id: 'the-bell-watch', title: 'The Bell Watch', kind: 'Micro drama · 45 episodes'),
    const CatalogueProduction(id: 'saltlight', title: 'Saltlight', kind: 'Film · 1 h 32 m'),
  ],
  package: CataloguePackage(
    url: Uri.parse('https://example.org/undersong.zip'),
    byteLength: 386000000,
    sha256: 'b' * 64,
    edition: '2026-10-22',
    fingerprint: 'e' * 64,
  ),
  guide: CataloguePackage(url: Uri.parse('https://example.org/undersong-guide.zip'), byteLength: 3600000, sha256: 'f' * 64),
);

const drownedVerse = GuideTheme(production: albumId, track: 'the-drowned-verse', title: 'The Drowned Verse', duration: Duration(minutes: 4, seconds: 12));

/// The guide (SPEC-059 version 3): the Chorister's and Maren's themes, a song among the teasers.
final guide = Guide(
  productions: [
    GuideProduction(
      id: ledgerId,
      title: 'The Ledger of Nights',
      chapters: [for (var n = 1; n <= 23; n++) GuideChapter(id: 'ch$n', number: n)],
    ),
  ],
  characters: const [
    GuideCharacter(
      id: 'the-chorister',
      name: 'The Chorister',
      role: 'Keeper of the drowned verse',
      portrait: 'char-chorister.jpg',
      voice: GuideVoice(audio: 'chorister.m4a', text: 'Hold the verse.', duration: Duration(seconds: 8), production: ledgerId, chapter: 'ch9'),
      theme: drownedVerse,
      sections: [
        GuideSection(
          heading: 'Essence',
          text:
              'The voice the harbour keeps. Nobody has seen the Chorister’s face: the verse comes up through the water at slack tide, and every tide-caller learns it by ear.',
        ),
      ],
    ),
    GuideCharacter(
      id: 'maren-kest',
      name: 'Maren Kest',
      role: 'Tide-caller',
      portrait: 'char-maren.jpg',
      theme: GuideTheme(production: albumId, track: 'tide-caller', title: 'Tide-caller', duration: Duration(minutes: 3, seconds: 58)),
      sections: [GuideSection(heading: 'Essence', text: 'Tide-caller.')],
    ),
  ],
  places: const [
    GuidePlace(
      id: 'the-vigil',
      name: 'The Vigil',
      role: 'Harbour mouth',
      picture: 'scene4-shot13.jpg',
      sections: [GuideSection(heading: 'Look', text: 'A watchtower.')],
    ),
  ],
  lore: const [],
  teasers: const [
    SongTeaser(
      title: 'The Drowned Verse',
      picture: 'scene4-shot15.jpg',
      audio: 'verse-excerpt.m4a',
      duration: Duration(seconds: 24),
      production: albumId,
      track: 'the-drowned-verse',
    ),
    PictureTeaser(
      title: 'The Vigil at slack tide',
      picture: 'scene4-shot13.jpg',
      from: GuideAfter(production: ledgerId, chapter: 'ch1', number: 1),
    ),
  ],
);

/// An engine held still, as tests never play: it says what was asked of it, and moves between
/// tracks as Next and a pressed track ask.
class MusicEngine implements AudioEngine {
  MusicEngine({MusicAlbum? album, int track = 0, this.now = Duration.zero, this.playing = true}) : _music = album, _track = track;

  MusicAlbum? _music;
  int _track;
  bool _shuffling = false;
  MusicRepeat _repeat = MusicRepeat.off;
  final _tracks = StreamController<int?>.broadcast();
  final _shuffles = StreamController<bool>.broadcast();
  final _loops = StreamController<LoopMode>.broadcast();
  final _plays = StreamController<bool>.broadcast();

  /// `openMusic` as it was called: the album, the track, and shuffle.
  final opened = <(String, int, bool?)>[];
  var nexts = 0;
  var previouses = 0;

  @override
  Duration now;
  @override
  bool playing;
  @override
  final artwork = ValueNotifier<String?>(null);

  @override
  MusicAlbum? get music => _music;
  @override
  LibraryItem? get item => _music?.asItem;
  @override
  int get track => _track;
  @override
  Stream<int?> get trackStream => _tracks.stream;
  @override
  bool get shuffling => _shuffling;
  @override
  Stream<bool> get shuffleStream => _shuffles.stream;
  @override
  MusicRepeat get repeat => _repeat;
  @override
  Stream<LoopMode> get repeatStream => _loops.stream;
  @override
  Stream<Duration> get position => Stream.value(_music == null ? now : _music!.starts[_track] + now);

  /// What plays changing, as the dock hears of it: an album opened, played or paused.
  @override
  Stream<bool> get playingStream => _plays.stream;
  @override
  Duration get length => _music?.length ?? Duration.zero;
  @override
  double get speed => 1;
  @override
  SleepTimer get sleep => SleepTimer.off;

  @override
  int chapterAt(Duration position) => _music?.locate(position).$1 ?? 0;

  @override
  (Duration, Duration) chapterBounds(Duration position) {
    final album = _music!;
    final index = chapterAt(position);
    return (album.starts[index], album.starts[index] + album.tracks[index].duration);
  }

  @override
  Future<void> openMusic(MusicAlbum album, {int index = 0, bool? shuffle}) async {
    opened.add((album.production.id, index, shuffle));
    _music = album;
    _track = index;
    if (shuffle != null) _shuffling = shuffle;
    playing = true;
    _tracks.add(_track);
    _plays.add(true);
  }

  @override
  Future<void> skipToNext() async {
    nexts++;
    final album = _music;
    if (album == null) return;
    _track = (_track + 1).clamp(0, album.tracks.length - 1);
    _tracks.add(_track);
  }

  @override
  Future<void> skipToPrevious() async {
    previouses++;
    _track = previousTrack(_track, now);
    _tracks.add(_track);
  }

  @override
  Future<void> toggleShuffle() async {
    _shuffling = !_shuffling;
    _shuffles.add(_shuffling);
  }

  @override
  Future<void> cycleRepeat() async {
    _repeat = _repeat.next;
    _loops.add(LoopMode.values[_repeat.index]);
  }

  @override
  Future<void> seek(Duration position) async {
    final album = _music;
    if (album == null) return;
    _track = album.locate(position).$1;
    _tracks.add(_track);
  }

  @override
  Future<void> play() async => _plays.add(playing = true);
  @override
  Future<void> pause() async => _plays.add(playing = false);
  @override
  Future<void> stop() async {
    _music = null;
    _plays.add(playing = false);
  }

  @override
  Future<void> open(
    LibraryItem item, {
    String? path,
    ListeningPlan? plan,
    String? artPath,
    required double speed,
    required void Function(Place place, {bool? finished}) keep,
  }) async => _music = null;

  @override
  void setSleep(SleepTimer timer) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A teaser's sound, heard by a test.
class HeardTeaser implements TeaserAudio {
  final played = <String>[];
  var stopped = 0;

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async => stopped++;
}

class _Kept extends KeptPictures {
  @override
  Future<Map<String, File>> build() async => pinned;

  @override
  Future<void> keepFor(Iterable<CatalogueWorld> worlds) async {}
}

class _Settings extends SettingsController {
  @override
  Future<DeviceSettings> build() async => const DeviceSettings();

  @override
  Future<void> change(DeviceSettings Function(DeviceSettings current) edit) async => state = AsyncData(edit(state.value ?? const DeviceSettings()));
}

/// Nothing arriving.
class _Quiet extends PartsController {
  @override
  Map<String, PartArrival> build() => const {};

  @override
  Future<void> check() async {}
}

/// Pumps the app at [location] over The Undersong and its music: installed unless [installed] is
/// false, playing what [engine] holds. [kept] hears every place kept, as a Heard in row keeps one.
Future<void> pumpMusic(
  WidgetTester tester,
  String location, {
  Size size = const Size(390, 844),
  double ratio = 1,
  Brightness brightness = Brightness.light,
  LibraryWorld? world,
  bool installed = true,
  List<MusicAlbum>? music,
  CatalogueWorld? listed,
  MusicEngine? engine,
  HeardTeaser? teaser,
  List<(String, Place)>? kept,
  Key? key,
}) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  if (ratio > 1) tester.view.padding = FakeViewPadding(top: 47 * ratio, bottom: 34 * ratio);
  addTearDown(tester.view.reset);
  final held = world ?? undersong();
  final albums = installed ? music ?? worldMusic(held) : const <MusicAlbum>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryStoreProvider.overrideWith((ref) async => LibraryStore(Directory(designAssets))),
        libraryItemsProvider.overrideWith((ref) => Stream.value(installed ? [narration] : const [])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value(installed ? [held] : const [])),
        volumeProvider.overrideWith((ref) async => (free: 40000000000, total: 128000000000)),
        catalogueProvider.overrideWith((ref) async => [listed ?? listedUndersong()]),
        catalogueRefreshProvider.overrideWith((ref) async {}),
        listPicksProvider.overrideWith((ref) async => (feature: null, band: null)),
        keptPicturesProvider.overrideWith(_Kept.new),
        worldGuideProvider.overrideWith((ref, id) async => WorldGuide(guide: guide, pathOf: designAsset)),
        guideFetchProvider.overrideWith((ref, id) async {}),
        guideReachProvider.overrideWith((ref, id) async => GuideReach.none),
        musicAlbumProvider.overrideWith((ref, key) async => albums.where((album) => album.worldId == key.$1 && album.production.id == key.$2).firstOrNull),
        worldMusicProvider.overrideWith((ref, id) async => albums),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 25, 9)),
        partsProvider.overrideWith(_Quiet.new),
        settingsProvider.overrideWith(_Settings.new),
        audioEngineProvider.overrideWithValue(engine),
        teaserAudioProvider.overrideWithValue(teaser ?? HeardTeaser()),
        placeKeeperProvider.overrideWithValue((id, place, {finished}) async => kept?.add((id, place))),
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
