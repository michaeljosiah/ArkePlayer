import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/parts/application/notices.dart';
import 'package:arke_player/features/parts/application/parts.dart';
import 'package:arke_player/features/settings/application/settings_controller.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_player/features/worlds/application/discover.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/discover_screen.dart';
import 'package:arke_player/features/worlds/presentation/production_screen.dart';
import 'package:arke_player/features/worlds/presentation/row_widgets.dart';
import 'package:arke_player/features/worlds/presentation/world_widgets.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Player P15, SPEC-058 R-49 – R-55 and SPEC-059 R-30 – R-34: Discover, a world's kinds, one tile,
// a world released a chapter at a time, and Notify.
final _now = DateTime.utc(2026, 10, 24, 9);
final _assets = Directory('../../design/assets').absolute.path;
String _pathOf(String assetId) => '$_assets${Platform.pathSeparator}$assetId';

final _part = CataloguePart(
  url: Uri.parse('https://example.org/dumah-part-1.zip'),
  byteLength: 18000000,
  sha256: 'c' * 64,
  edition: '2026-10-23',
  fingerprint: 'd' * 64,
  released: DateTime.utc(2026, 10, 23),
  production: 'whispers',
  chapters: const [CataloguePartChapter(id: 'ch3', number: 3, title: 'Chapter 3')],
);

final _dumah = CatalogueWorld(
  id: 'legend-of-dumah',
  name: 'Legend of Dumah',
  keyArt: 'assets/worlds/legend-of-dumah/key-art.jpg',
  productions: [
    CatalogueProduction(
      id: 'whispers',
      title: 'Whispers from the Void',
      kind: 'Audiobook · 4 chapters',
      picture: 'assets/worlds/legend-of-dumah/whispers-from-the-void.jpg',
      schedule: WorldSchedule(day: ScheduleDay.friday, next: DateTime.utc(2026, 10, 30)),
    ),
  ],
  package: CatalogueEdition(
    url: Uri.parse('https://example.org/dumah.zip'),
    byteLength: 88000000,
    sha256: 'a' * 64,
    edition: '2026-10-09',
    fingerprint: 'e' * 64,
    parts: [_part],
  ),
);

final _undersong = CatalogueWorld(
  id: 'the-undersong',
  name: 'The Undersong',
  keyArt: 'assets/worlds/undersong/key-art.jpg',
  productions: const [
    CatalogueProduction(
      id: 'the-ledger-of-nights',
      title: 'The Ledger of Nights',
      kind: 'Audiobook · Book · 23 chapters',
      picture: 'assets/worlds/undersong/ledger-of-nights.jpg',
      tall: 'assets/worlds/na-love-or-juju/cover-tall.jpg',
    ),
    CatalogueProduction(id: 'undertow', title: 'Undertow', kind: 'Audio drama · 8 episodes'),
    CatalogueProduction(id: 'the-bell-watch', title: 'The Bell Watch', kind: 'Micro drama · 45 episodes'),
    CatalogueProduction(id: 'saltlight', title: 'Saltlight', kind: 'Film · 1 h 32 m'),
  ],
  package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 1900000000, sha256: 'b' * 64),
  guide: CataloguePackage(url: Uri.parse('https://example.org/undersong-guide.zip'), byteLength: 3600000, sha256: 'f' * 64),
);

const _maren = GuideCharacter(
  id: 'maren-kest',
  name: 'Maren Kest',
  role: 'Tide-caller',
  portrait: 'char-maren.jpg',
  sections: [GuideSection(heading: 'Essence', text: 'Tide-caller.')],
);
const _guide = Guide(
  productions: [
    GuideProduction(
      id: 'the-ledger-of-nights',
      title: 'The Ledger of Nights',
      chapters: [GuideChapter(id: 'neap', number: 1)],
    ),
  ],
  characters: [_maren],
  places: [],
  lore: [],
  teasers: [
    EntryTeaser(_maren),
    ClipTeaser(
      title: 'Saltmouth bells',
      picture: 'scene4-shot14b.jpg',
      from: GuideAfter(production: 'the-ledger-of-nights', chapter: 'neap', number: 1),
      audio: 'bells.m4a',
      duration: Duration(seconds: 24),
    ),
  ],
);

final _installedAt = DateTime.utc(2026, 10, 10);
final _installed = LibraryWorld(
  id: 'legend-of-dumah',
  edition: '2026-10-09',
  name: 'Legend of Dumah',
  byteLength: 106000000,
  installedAt: _installedAt,
  fingerprint: 'e' * 64,
  productions: const [LibraryProduction(id: 'whispers', title: 'Whispers from the Void', narration: 'legend-of-dumah.whispers.listening')],
  parts: [
    LibraryPart(
      number: 1,
      edition: '2026-10-23',
      fingerprint: 'd' * 64,
      production: 'whispers',
      chapters: const ['ch3'],
      byteLength: 18000000,
      installedAt: DateTime.utc(2026, 10, 23, 6),
      folder: 'worlds/legend-of-dumah/_parts/1',
    ),
  ],
);

LibraryItem _narration({Place? place}) => LibraryItem(
  id: 'legend-of-dumah.whispers.listening',
  format: FileFormat.listening,
  title: 'Whispers from the Void',
  byteLength: 106000000,
  addedAt: _installedAt,
  file: 'worlds/legend-of-dumah/whispers/listening.json',
  duration: const Duration(minutes: 78),
  chapters: const [
    Chapter(title: 'Prologue', start: Duration.zero, id: 'prologue'),
    Chapter(title: 'Chapter 1', start: Duration(minutes: 12), id: 'ch1'),
    Chapter(title: 'Chapter 2', start: Duration(minutes: 34), id: 'ch2'),
    Chapter(title: 'Chapter 3', start: Duration(minutes: 60), id: 'ch3'),
  ],
  place: place ?? Place(locator: 'ch3', position: Duration.zero, progress: 60 / 78, updatedAt: DateTime.utc(2026, 10, 23, 6)),
  worldId: 'legend-of-dumah',
);

class _Audio implements TeaserAudio {
  final played = <String>[];
  var stopped = 0;

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async => stopped++;
}

class _Notices implements Notices {
  final told = <String>[];
  var asked = 0;
  bool allow = true;

  @override
  Future<bool> ask() async {
    asked++;
    return allow;
  }

  @override
  Future<void> chapterArrived(LibraryStore? store, CatalogueWorld world, CataloguePart part, {List<LibraryWorld>? installed}) async => told.add(world.id);

  @override
  Future<void> init({void Function(String route)? onOpen}) async {}

  @override
  Future<String?> launchRoute() async => null;
}

/// Installs a part by saying how far it got, then waiting.
class _Installer extends WorldInstaller {
  _Installer() : super(store: LibraryStore(Directory.systemTemp), freeBytes: (_) async => null);
  final added = <String>[];

  @override
  Future<LibraryWorld> installPart(
    CatalogueWorld world,
    CataloguePart pin, {
    void Function(InstallStep step)? onStep,
    InstallCancel? cancel,
    File? from,
  }) async {
    onStep?.call(const Downloading(9000000, 18000000));
    added.add(pin.fingerprint!);
    return _installed;
  }
}

Future<_Audio> _pump(
  WidgetTester tester, {
  required String location,
  List<LibraryWorld>? worlds,
  List<LibraryItem>? items,
  _Notices? notices,
  Size size = const Size(390, 844),
  ({CatalogueFeature? feature, String? band}) picks = (feature: null, band: null),
  List<CatalogueWorld>? catalogue,
  Map<String, File>? kept,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final audio = _Audio();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryItemsProvider.overrideWith((ref) => Stream.value(items ?? [_narration()])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value(worlds ?? [_installed])),
        volumeProvider.overrideWith((ref) async => (free: 40000000000, total: 128000000000)),
        catalogueProvider.overrideWith((ref) async => catalogue ?? [_dumah, _undersong]),
        catalogueRefreshProvider.overrideWith((ref) async {}),
        listPicksProvider.overrideWith((ref) async => picks),
        if (kept != null) keptPicturesProvider.overrideWith(() => _Kept(kept)),
        worldGuideProvider.overrideWith((ref, worldId) async => worldId == 'the-undersong' ? const WorldGuide(guide: _guide, pathOf: _pathOf) : null),
        guideFetchProvider.overrideWith((ref, worldId) async {}),
        guideReachProvider.overrideWith((ref, worldId) async => GuideReach.none),
        clockProvider.overrideWithValue(() => _now),
        teaserAudioProvider.overrideWithValue(audio),
        noticesProvider.overrideWithValue(notices ?? _Notices()),
        // Settings kept in memory: the phone's storage is a platform channel no widget test has.
        settingsProvider.overrideWith(() => _Settings(const DeviceSettings())),
      ],
      child: MaterialApp.router(
        theme: arkeTheme(Brightness.light),
        routerConfig: buildRouter(initialLocation: location),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return audio;
}

/// Scrolls the page until [target] is in its middle, clear of the tabs' pill floating at the foot
/// (P16 rule 9).
Future<void> _reveal(WidgetTester tester, Finder target) async {
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  await tester.scrollUntilVisible(target, 300, scrollable: page);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// The asset an [Image] under [of] shows, for the pictures that are bundled.
Set<String> _assetsUnder(WidgetTester tester, Finder of) => {
  for (final image in tester.widgetList<Image>(find.descendant(of: of, matching: find.byType(Image))))
    if (image.image case AssetImage(:final assetName)) assetName,
};

/// The files an [Image] under [of] shows, for the pictures fetched with the list.
Set<String> _filesUnder(WidgetTester tester, Finder of) => {
  for (final image in tester.widgetList<Image>(find.descendant(of: of, matching: find.byType(Image))))
    if (image.image case FileImage(:final file)) file.path,
};

/// The pictures kept, as a test names them.
class _Kept extends KeptPictures {
  _Kept(this.files);
  final Map<String, File> files;

  @override
  Future<Map<String, File>> build() async => files;
}

PicturePin _picturePin(String digit) => PicturePin(url: Uri.parse('https://example.org/$digit.jpg'), byteLength: 10, sha256: digit * 64);

// SPEC-058 rev 10: a world whose pictures come with the list. A cover with no bundle path at all, a
// Tall cover whose fetched file replaces the bundled one, and one still waiting for its file.
final _pinned = CatalogueWorld(
  id: 'the-red-quiet',
  name: 'The Red Quiet',
  keyArt: 'assets/worlds/the-red-quiet/key-art.jpg',
  productions: [
    CatalogueProduction(id: 'only-pinned', title: 'Only pinned', kind: 'Audiobook', picturePin: _picturePin('1')),
    CatalogueProduction(id: 'fetched', title: 'Fetched', kind: 'Audiobook', tall: 'assets/worlds/the-red-quiet/cover-tall.jpg', tallPin: _picturePin('2')),
    CatalogueProduction(
      id: 'waiting',
      title: 'Waiting',
      kind: 'Audiobook',
      tall: 'assets/worlds/embers-of-the-fallen/cover-tall.jpg',
      tallPin: _picturePin('3'),
    ),
  ],
  package: CataloguePackage(url: Uri.parse('https://example.org/quiet.zip'), byteLength: 23000000, sha256: 'd' * 64),
);

void main() {
  group('choosing the feature and the band (P16 call 15)', () {
    final dumahPart = FreshPart(world: _dumah, part: _part, production: _dumah.productions.single);

    test('the production the list names, or its world’s first', () {
      final named = discoverFeature([_dumah, _undersong], const CatalogueFeature(world: 'the-undersong', production: 'saltlight'), [dumahPart]);
      expect(named?.production.title, 'Saltlight');
      final worldAlone = discoverFeature([_dumah, _undersong], const CatalogueFeature(world: 'the-undersong'), [dumahPart]);
      expect(worldAlone?.production.title, 'The Ledger of Nights');
    });

    test('a name no listed world answers to falls to the newest part, then the first world', () {
      expect(discoverFeature([_dumah, _undersong], const CatalogueFeature(world: 'not-yet'), [dumahPart])?.production.title, 'Whispers from the Void');
      expect(discoverFeature([_undersong, _dumah], null, const [])?.production.title, 'The Ledger of Nights');
      expect(discoverFeature(const [], null, const []), isNull);
    });

    test('the band the list names, else the last world that is not the feature’s', () {
      expect(discoverBand([_dumah, _undersong], 'legend-of-dumah', _dumah)?.id, 'legend-of-dumah');
      expect(discoverBand([_dumah, _undersong], null, _undersong)?.id, 'legend-of-dumah');
      expect(discoverBand([_dumah, _undersong], 'not-yet', _dumah)?.id, 'the-undersong');
      expect(discoverBand([_dumah], null, _dumah), isNull);
    });
  });

  group('Discover (P15a, P15b, P16a – P16c; SPEC-059 R-30, R-31)', () {
    testWidgets('the feature first, then New chapters, Stories, Teasers, a world’s band and Worlds', (tester) async {
      await _pump(tester, location: Routes.discover);
      // With nothing named, the newest part's production; installed, so Play at its chapter.
      final feature = find.byType(FeatureCard);
      expect(find.descendant(of: feature, matching: find.text('Whispers from the Void')), findsOneWidget);
      expect(find.descendant(of: feature, matching: find.text('Audiobook · Legend of Dumah')), findsOneWidget);
      expect(find.descendant(of: feature, matching: find.text('Play · Chapter 3', findRichText: true)), findsOneWidget);
      expect(find.text('New chapters'), findsOneWidget);
      await _reveal(tester, find.text('Stories'));
      expect(find.text('Audio drama · The Undersong'), findsOneWidget);
      await _reveal(tester, find.text('Teasers'));
      expect(find.text('Clip · 0:24'), findsOneWidget);
      expect(find.ancestor(of: find.text('Saltmouth bells'), matching: find.byType(PosterTile)), findsOneWidget);
      await _reveal(tester, find.byType(WorldBand));
      final band = find.byType(WorldBand);
      expect(find.descendant(of: band, matching: find.text('The Undersong')), findsOneWidget);
      expect(find.descendant(of: band, matching: find.text('4 productions · 1.9 GB')), findsOneWidget);
      expect(find.descendant(of: band, matching: find.text('Install')), findsOneWidget);
      expect(find.descendant(of: band, matching: find.text('Maren Kest')), findsOneWidget);
      await _reveal(tester, find.text('Worlds'));
      expect(find.text('In Library · 1 production'), findsOneWidget);
    });

    testWidgets('a chip keeps what is taken that way, and leaves out the feature, Teasers, the band and Worlds', (tester) async {
      await _pump(tester, location: Routes.discover);
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(find.text('Micro drama · The Undersong'), findsOneWidget);
      expect(find.text('Audiobook · Legend of Dumah'), findsNothing);
      expect(find.byType(FeatureCard), findsNothing);
      expect(find.byType(WorldBand), findsNothing);
      expect(find.text('Teasers'), findsNothing);
      expect(find.text('Worlds'), findsNothing);
    });

    testWidgets('each row is one size: the feature 358 × 476, wide tiles 240, posters 172, small posters 112 (P16 rule 1)', (tester) async {
      await _pump(tester, location: Routes.discover);
      // 358 × 476 inside the page's 16 at each side and 12 above.
      expect(tester.getSize(find.byType(FeatureCard)), const Size(16 + 358 + 16, 12 + 476));
      expect({for (final tile in find.byType(ProductionTile).evaluate()) tile.size!.width}, {240.0});
      await _reveal(tester, find.text('Stories'));
      final stories = find.ancestor(of: find.text('Audio drama · The Undersong'), matching: find.byType(PosterTile));
      expect(tester.getSize(stories).width, 172);
      await _reveal(tester, find.text('Teasers'));
      expect(tester.getSize(find.ancestor(of: find.text('Saltmouth bells'), matching: find.byType(PosterTile))).width, 112);
    });

    testWidgets('a poster is its Tall cover; without one, its Wide whole over its own blur (P16 rule 3)', (tester) async {
      await _pump(
        tester,
        location: Routes.discover,
        picks: (feature: const CatalogueFeature(world: 'the-undersong'), band: 'legend-of-dumah'),
      );
      await _reveal(tester, find.text('Stories'));
      final ledger = find.ancestor(of: find.text('Audiobook · The Undersong'), matching: find.byType(PosterTile));
      expect(_assetsUnder(tester, ledger), {'assets/worlds/na-love-or-juju/cover-tall.jpg'});
      expect(find.descendant(of: ledger, matching: find.byType(WholeOverBlur)), findsNothing);
      final whispers = find.ancestor(of: find.text('Audiobook · Legend of Dumah'), matching: find.byType(PosterTile));
      expect(find.descendant(of: whispers, matching: find.byType(WholeOverBlur)), findsOneWidget);
      expect(
        tester.widget<Image>(find.descendant(of: whispers, matching: find.byType(Image)).last).fit,
        BoxFit.contain,
        reason: 'the Wide is shown whole, never cut',
      );
    });

    testWidgets('a picture fetched with the list is shown in place of the bundled one (SPEC-058 rev 10)', (tester) async {
      final only = File(_pathOf('char-maren.jpg'));
      final fetched = File(_pathOf('char-bray.jpg'));
      await _pump(
        tester,
        location: Routes.discover,
        catalogue: [_pinned],
        kept: {'1' * 64: only, '2' * 64: fetched},
        picks: (feature: const CatalogueFeature(world: 'the-red-quiet', production: 'waiting'), band: 'not-listed'),
      );
      await _reveal(tester, find.text('Stories'));
      Finder poster(String title) => find.ancestor(of: find.text(title), matching: find.byType(PosterTile));
      // A cover the app never bundled: its file, whole over its blur.
      expect(_filesUnder(tester, poster('Only pinned')), {only.path});
      expect(find.descendant(of: poster('Only pinned'), matching: find.byType(WholeOverBlur)), findsOneWidget);
      // A Tall cover whose file came: the file, not the bundled one.
      expect(_filesUnder(tester, poster('Fetched')), {fetched.path});
      expect(_assetsUnder(tester, poster('Fetched')), isEmpty);
      // One still waiting for its file: the bundled one meanwhile.
      expect(_assetsUnder(tester, poster('Waiting')), {'assets/worlds/embers-of-the-fallen/cover-tall.jpg'});
      expect(_filesUnder(tester, poster('Waiting')), isEmpty);
    });

    testWidgets('the list names the feature and the band: not installed, Install with its size (P16a)', (tester) async {
      await _pump(
        tester,
        location: Routes.discover,
        picks: (feature: const CatalogueFeature(world: 'the-undersong'), band: 'legend-of-dumah'),
      );
      final feature = find.byType(FeatureCard);
      expect(find.descendant(of: feature, matching: find.text('The Ledger of Nights')), findsOneWidget);
      expect(find.descendant(of: feature, matching: find.text('Audiobook · Book · The Undersong')), findsOneWidget);
      expect(find.descendant(of: feature, matching: find.text('Install · 1.9 GB', findRichText: true)), findsOneWidget);
      // Upright on a phone, from its Tall cover.
      expect(_assetsUnder(tester, feature), {'assets/worlds/na-love-or-juju/cover-tall.jpg'});
      await _reveal(tester, find.byType(WorldBand));
      // An installed world's band says so and has no press.
      final band = find.byType(WorldBand);
      expect(find.descendant(of: band, matching: find.text('In Library · 1 production')), findsOneWidget);
      expect(find.descendant(of: band, matching: find.byType(BandPress)), findsNothing);
    });

    testWidgets('on a Fold the feature is wide, from its Wide, its words at the left (P16f)', (tester) async {
      await _pump(
        tester,
        location: Routes.discover,
        size: const Size(984, 1092),
        picks: (feature: const CatalogueFeature(world: 'the-undersong'), band: null),
      );
      final feature = find.byType(FeatureCard);
      expect(tester.getSize(feature), const Size(984, 12 + 424));
      expect(_assetsUnder(tester, feature), {'assets/worlds/undersong/ledger-of-nights.jpg'});
      // 36 in from the card's edge, inside its 1 border.
      expect(tester.getTopLeft(find.descendant(of: feature, matching: find.text('The Ledger of Nights'))).dx, 16 + 1 + 36);
    });

    testWidgets('a clip opens full screen with sound, and stops when closed (SPEC-059 R-32)', (tester) async {
      final audio = await _pump(tester, location: Routes.discover);
      await _reveal(tester, find.text('Saltmouth bells'));
      await tester.tap(find.text('Saltmouth bells'));
      await tester.pumpAndSettle();
      expect(find.byType(TeaserScreen), findsOneWidget);
      expect(find.text('Clip · 0:24 · Chapter 1 · The Undersong'), findsOneWidget);
      expect(audio.played, [_pathOf('bells.m4a')]);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(TeaserScreen), findsNothing);
      expect(audio.stopped, 1);
    });
  });

  testWidgets('a world’s page groups its productions by how they are taken, each counted (P15c, R-33)', (tester) async {
    await _pump(tester, location: Routes.discoverWorld('the-undersong'));
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Inside'), findsNothing);
  });

  testWidgets('a world’s page: Listen as posters, Watch as wide tiles, its characters as small posters (P16d, P16e)', (tester) async {
    await _pump(tester, location: Routes.discoverWorld('the-undersong'));
    await _reveal(tester, find.text('Undertow'));
    for (final listen in ['The Ledger of Nights', 'Undertow']) {
      expect(tester.getSize(find.ancestor(of: find.text(listen), matching: find.byType(PosterTile))).width, 172);
    }
    await _reveal(tester, find.text('Maren Kest'));
    expect(find.ancestor(of: find.text('Saltlight'), matching: find.byType(ProductionTile)), findsOneWidget);
    expect(tester.getSize(find.ancestor(of: find.text('Maren Kest'), matching: find.byType(PosterTile))).width, 112);
  });

  group('a production released a chapter at a time (P15e; SPEC-058 R-52, R-53)', () {
    final whispers = Routes.production(Routes.libraryWorld('legend-of-dumah'), 'whispers');

    testWidgets('its schedule, the new chapter New with its day, the next as a dashed row', (tester) async {
      await _pump(tester, location: whispers);
      expect(find.text('Fridays · Next 30 Oct'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('18:00 · 23 Oct'), findsOneWidget);
      expect(find.text('Chapter 4'), findsOneWidget);
      expect(find.text('30 Oct'), findsOneWidget);
    });

    test('scheduleLine drops a passed date, and the day stays', () {
      final schedule = WorldSchedule(day: ScheduleDay.monday, next: DateTime.utc(2026, 10, 26));
      expect(scheduleLine(schedule, _now), 'Mondays · Next 26 Oct');
      expect(scheduleLine(schedule, DateTime.utc(2026, 10, 27)), 'Mondays');
      expect(scheduleLine(WorldSchedule(next: DateTime.utc(2026, 10, 20)), _now), isNull);
      expect(scheduleLine(const WorldSchedule(day: ScheduleDay.daily), _now), 'Daily');
    });

    testWidgets('once it plays, it is no longer New', (tester) async {
      await _pump(
        tester,
        location: whispers,
        items: [
          _narration(
            place: Place(locator: 'ch3', position: const Duration(minutes: 2), progress: 0.8, updatedAt: DateTime.utc(2026, 10, 24, 8)),
          ),
        ],
      );
      expect(find.text('New'), findsNothing);
    });
  });

  testWidgets('Library marks a world with a chapter not yet opened New (P15h)', (tester) async {
    await _pump(tester, location: Routes.library);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Worlds'), findsWidgets);
  });

  testWidgets('Home: Continue leads with New, then New chapters (P15g)', (tester) async {
    await _pump(tester, location: Routes.home);
    expect(find.text('New chapters'), findsOneWidget);
    expect(find.text('Chapter 3 · Legend of Dumah'), findsOneWidget);
    // Continue's card, New chapters' tile and the world's card.
    expect(find.text('New'), findsNWidgets(3));
  });

  testWidgets('Notify is per world, in its ⋯, off until turned on, asking the phone first (P15j, R-54)', (tester) async {
    final notices = _Notices();
    await _pump(tester, location: Routes.libraryWorld('legend-of-dumah'), notices: notices);
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    expect(find.text('Notify'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.text('Notify')));
    expect(container.read(settingsProvider).value?.notify, isEmpty);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(notices.asked, 1);
    expect(container.read(settingsProvider).value?.notify, {'legend-of-dumah'});
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('refused by the phone, Notify stays off', (tester) async {
    final notices = _Notices()..allow = false;
    await _pump(tester, location: Routes.libraryWorld('legend-of-dumah'), notices: notices);
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  group('a part arriving on its own (R-51)', () {
    final missing = LibraryWorld(
      id: 'legend-of-dumah',
      edition: '2026-10-09',
      name: 'Legend of Dumah',
      byteLength: 88000000,
      installedAt: _installedAt,
      fingerprint: 'e' * 64,
      productions: const [LibraryProduction(id: 'whispers', title: 'Whispers from the Void', narration: 'legend-of-dumah.whispers.listening')],
    );

    ProviderContainer container({required bool wifi, required DeviceSettings settings, required _Installer installer, required _Notices notices}) {
      final made = ProviderContainer(
        overrides: [
          catalogueProvider.overrideWith((ref) async => [_dumah]),
          libraryStoreProvider.overrideWith((ref) async => _MissingStore(missing)),
          libraryRootProvider.overrideWith((ref) async => Directory.systemTemp.createTempSync('arke-parts-')),
          worldInstallerProvider.overrideWith((ref) async => installer),
          settingsProvider.overrideWith(() => _Settings(settings)),
          onWifiProvider.overrideWithValue(() async => wifi),
          noticesProvider.overrideWithValue(notices),
        ],
      );
      addTearDown(made.dispose);
      return made;
    }

    test('over Wi-Fi it comes, and a world whose Notify is on is told', () async {
      final installer = _Installer();
      final notices = _Notices();
      final parts = container(
        wifi: true,
        settings: const DeviceSettings(notify: {'legend-of-dumah'}),
        installer: installer,
        notices: notices,
      );
      final seen = <Map<String, PartArrival>>[];
      parts.listen(partsProvider, (_, next) => seen.add(next));
      await parts.read(partsProvider.notifier).check();
      expect(installer.added, ['d' * 64]);
      expect(seen.any((state) => state['legend-of-dumah']?.line() == 'Chapter 3 · 9 MB of 18 MB'), isTrue);
      expect(parts.read(partsProvider), isEmpty);
      expect(notices.told, ['legend-of-dumah']);
    });

    test('Wi-Fi only, on mobile data, it waits', () async {
      final installer = _Installer();
      final parts = container(wifi: false, settings: const DeviceSettings(), installer: installer, notices: _Notices());
      await parts.read(partsProvider.notifier).check();
      expect(installer.added, isEmpty);
      final waiting = parts.read(partsProvider)['legend-of-dumah']!;
      expect((waiting.waiting, waiting.line()), (true, 'Chapter 3 · 18 MB · Waiting'));
    });

    test('with Wi-Fi only off it comes over any network', () async {
      final installer = _Installer();
      final parts = container(wifi: false, settings: const DeviceSettings(wifiOnly: false), installer: installer, notices: _Notices());
      await parts.read(partsProvider.notifier).check();
      expect(installer.added, ['d' * 64]);
    });
  });

  test('chaptersLabel names one chapter, a run, or episodes', () {
    const one = CataloguePartChapter(id: 'a', number: 24, title: 'The Bell Ropes');
    const two = CataloguePartChapter(id: 'b', number: 25, title: 'Low Water');
    expect(chaptersLabel([one]), 'Chapter 24');
    expect(chaptersLabel([one, two]), 'Chapters 24–25');
    expect(chaptersLabel([one, two], episodes: true), 'Episodes 24–25');
  });
}

class _MissingStore extends LibraryStore {
  _MissingStore(this.world) : super(Directory.systemTemp);
  final LibraryWorld world;

  @override
  List<LibraryWorld> get worlds => [world];
}

class _Settings extends SettingsController {
  _Settings(this.fixed);
  final DeviceSettings fixed;

  @override
  Future<DeviceSettings> build() async => fixed;

  @override
  Future<void> change(DeviceSettings Function(DeviceSettings current) edit) async => state = AsyncData(edit(state.value ?? fixed));
}
