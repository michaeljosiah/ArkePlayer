// Renders Discover, a world's kinds, a production released a chapter at a time, Home, Library,
// Notify and Downloads (P15) with the real fonts and pictures, to compare with the design's frames.
// Not a gate — pixels differ by platform — so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_discover_test.dart        (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/parts/application/parts.dart';
import 'package:arke_player/features/worlds/application/discover.dart';
import 'package:arke_player/features/worlds/application/guides.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _shoot = Platform.environment['SHOOT'] == '1';
final _now = DateTime.utc(2026, 10, 24, 9);

CataloguePart _part(String production, int number, String title, DateTime released, {int bytes = 18000000}) => CataloguePart(
  url: Uri.parse('https://example.org/$production-$number.zip'),
  byteLength: bytes,
  sha256: '$number'.padLeft(64, 'c'),
  edition: '2026-10-${released.day}',
  fingerprint: '$number'.padLeft(64, 'd'),
  released: released,
  production: production,
  chapters: [CataloguePartChapter(id: 'ch$number', number: number, title: title)],
);

final _dumahPart = _part('whispers', 3, 'Chapter 3', DateTime.utc(2026, 10, 23));

final _dumah = CatalogueWorld(
  id: 'legend-of-dumah',
  name: 'Legend of Dumah',
  logline: 'Twice the world has stood at the edge of ending. The third time begins with a thief in the City of Light.',
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
    parts: [_dumahPart],
  ),
);

final _undersong = CatalogueWorld(
  id: 'the-undersong',
  name: 'The Undersong',
  logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
  keyArt: 'assets/worlds/undersong/key-art.jpg',
  productions: const [
    CatalogueProduction(id: 'the-ledger-of-nights', title: 'The Ledger of Nights', kind: 'Audiobook · Book · 23 chapters', picture: 'assets/worlds/undersong/ledger-of-nights.jpg'),
    CatalogueProduction(id: 'undertow', title: 'Undertow', kind: 'Audio drama · 8 episodes'),
    CatalogueProduction(id: 'the-bell-watch', title: 'The Bell Watch', kind: 'Micro drama · 45 episodes'),
    CatalogueProduction(id: 'saltlight', title: 'Saltlight', kind: 'Film · 1 h 32 m'),
    CatalogueProduction(id: 'low-water', title: 'Low Water', kind: 'Interactive movie · 14 scenes'),
    CatalogueProduction(id: 'the-lantern-road', title: 'The Lantern Road', kind: 'Visual novel · 9 scenes'),
  ],
  package: CatalogueEdition(
    url: Uri.parse('https://example.org/undersong.zip'),
    byteLength: 1900000000,
    sha256: 'b' * 64,
    edition: '2026-10-22',
    parts: [_part('the-ledger-of-nights', 24, 'The Bell Ropes', DateTime.utc(2026, 10, 20), bytes: 24000000)],
  ),
  guide: CataloguePackage(url: Uri.parse('https://example.org/undersong-guide.zip'), byteLength: 3600000, sha256: 'f' * 64),
);

final _quiet = CatalogueWorld(
  id: 'the-red-quiet',
  name: 'The Red Quiet',
  keyArt: 'assets/worlds/the-red-quiet/key-art.jpg',
  productions: const [CatalogueProduction(title: 'The Red Quiet', kind: 'Audiobook · 4 chapters', picture: 'assets/worlds/the-red-quiet/cover.jpg')],
  package: CataloguePackage(url: Uri.parse('https://example.org/quiet.zip'), byteLength: 23000000, sha256: 'c' * 64),
);

final _embers = CatalogueWorld(
  id: 'embers-of-the-fallen',
  name: 'Embers of the Fallen',
  keyArt: 'assets/worlds/embers-of-the-fallen/key-art.jpg',
  productions: const [CatalogueProduction(title: 'Threshold — Book One', kind: 'Audiobook · 6 chapters', picture: 'assets/worlds/embers-of-the-fallen/cover.jpg')],
  package: CataloguePackage(url: Uri.parse('https://example.org/embers.zip'), byteLength: 127000000, sha256: 'd' * 64),
);

GuideCharacter _character(String id, String name, String role, String portrait) =>
    GuideCharacter(id: id, name: name, role: role, portrait: portrait, sections: [GuideSection(heading: 'Essence', text: role)]);

/// The Undersong's guide with the three teasers P15a draws: Maren, a clip and the Vigil.
final _guide = () {
  const ledger = GuideProduction(id: 'the-ledger-of-nights', title: 'The Ledger of Nights', chapters: [GuideChapter(id: 'neap', number: 1)]);
  final maren = _character('maren-kest', 'Maren Kest', 'Tide-caller', 'char-maren.jpg');
  const vigil = GuidePlace(id: 'the-vigil', name: 'The Vigil', role: 'Harbour mouth', picture: 'scene4-shot13.jpg', sections: [GuideSection(heading: 'Look', text: 'A watchtower.')]);
  return Guide(
    productions: [ledger],
    characters: [
      maren,
      _character('bray-half-hitch', 'Bray Half-Hitch', 'Rigger', 'char-bray.jpg'),
      _character('the-chorister', 'The Chorister', 'Keeper of the drowned verse', 'char-chorister.jpg'),
      const GuideCharacter(id: 'perrin-tallow', name: 'Perrin Tallow', role: 'Council actuary', sections: [GuideSection(heading: 'Essence', text: 'Actuary.')]),
      const GuideCharacter(
        id: 'ines',
        name: 'Ines',
        after: GuideAfter(production: 'the-ledger-of-nights', chapter: 'neap', number: 9),
        sections: [],
      ),
    ],
    places: [vigil],
    lore: const [],
    teasers: [
      EntryTeaser(maren),
      const ClipTeaser(
        title: 'Saltmouth bells',
        picture: 'scene4-shot14b.jpg',
        from: GuideAfter(production: 'the-ledger-of-nights', chapter: 'neap', number: 1),
        audio: 'bells.m4a',
        duration: Duration(seconds: 24),
      ),
      const EntryTeaser(vigil),
    ],
  );
}();

/// Arrivals fixed for Downloads (P15k).
class _Arriving extends PartsController {
  _Arriving(this.fixed);
  final Map<String, PartArrival> fixed;

  @override
  Map<String, PartArrival> build() => fixed;

  @override
  Future<void> check() async {}
}

Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Geist Sans', ['GeistSans-400', 'GeistSans-500', 'GeistSans-600', 'GeistSans-700']),
    ('Jost', ['Jost-200', 'Jost-300', 'Jost-400']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$file.ttf').readAsBytesSync())));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons');
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent.path;
  final iconFont = File('$artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconFont.existsSync()) {
    icons.addFont(Future.value(ByteData.sublistView(iconFont.readAsBytesSync())));
    await icons.load();
  }
}

void main() {
  if (!_shoot) {
    test('shots are taken only with SHOOT=1', () {}, skip: 'set SHOOT=1 to render the screens');
    return;
  }

  late Directory root;
  late LibraryStore store;
  late LibraryWorld dumah;
  late List<LibraryItem> items;
  final assets = Directory('../../design/assets').absolute.path;
  String pathOf(String assetId) => '$assets${Platform.pathSeparator}$assetId';

  setUpAll(() async {
    await _loadFonts();
    root = Directory.systemTemp.createTempSync('arke-player-discover-shots-');
    store = LibraryStore(root);
    String place(String relative, String picture) {
      final file = File(store.resolve(relative))..parent.createSync(recursive: true);
      File('$assets/$picture').copySync(file.path);
      return relative;
    }

    final installedAt = DateTime.utc(2026, 10, 10);
    dumah = LibraryWorld(
      id: 'legend-of-dumah',
      edition: '2026-10-09',
      name: 'Legend of Dumah',
      logline: _dumah.logline,
      keyArt: place('worlds/legend-of-dumah/key-art.jpg', 'dumah-key-art.jpg'),
      byteLength: 106000000,
      installedAt: installedAt,
      fingerprint: 'e' * 64,
      productions: [
        LibraryProduction(
          id: 'whispers',
          title: 'Whispers from the Void',
          picture: place('worlds/legend-of-dumah/whispers.jpg', 'dumah-whispers.jpg'),
          narration: 'legend-of-dumah.whispers.listening',
        ),
      ],
      parts: [
        LibraryPart(
          number: 1,
          edition: '2026-10-23',
          fingerprint: '3'.padLeft(64, 'd'),
          production: 'whispers',
          chapters: const ['ch3'],
          byteLength: 18000000,
          installedAt: DateTime.utc(2026, 10, 23, 6),
          folder: 'worlds/legend-of-dumah/_parts/1',
        ),
      ],
    );
    items = [
      LibraryItem(
        id: 'legend-of-dumah.whispers.listening',
        format: FileFormat.listening,
        title: 'Whispers from the Void',
        byteLength: 106000000,
        addedAt: installedAt,
        file: 'worlds/legend-of-dumah/whispers/listening.json',
        cover: dumah.productions.single.picture,
        duration: const Duration(minutes: 78),
        chapters: const [
          Chapter(title: 'Prologue', start: Duration.zero, id: 'prologue'),
          Chapter(title: 'Chapter 1', start: Duration(minutes: 12), id: 'ch1'),
          Chapter(title: 'Chapter 2', start: Duration(minutes: 34), id: 'ch2'),
          Chapter(title: 'Chapter 3', start: Duration(minutes: 60), id: 'ch3'),
        ],
        // Chapter 2 finished; the part moved the place to Chapter 3's start (P15g).
        place: Place(locator: 'ch3', position: Duration.zero, progress: 60 / 78, updatedAt: DateTime.utc(2026, 10, 23, 6)),
        worldId: 'legend-of-dumah',
      ),
    ];
  });

  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a picture open; the temporary folder is the system's to clear.
    }
  });

  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    for (final provider in <ImageProvider>[
      for (final asset in [
        'assets/worlds/undersong/key-art.jpg',
        'assets/worlds/undersong/ledger-of-nights.jpg',
        'assets/worlds/legend-of-dumah/key-art.jpg',
        'assets/worlds/legend-of-dumah/whispers-from-the-void.jpg',
        'assets/worlds/the-red-quiet/key-art.jpg',
        'assets/worlds/the-red-quiet/cover.jpg',
        'assets/worlds/embers-of-the-fallen/key-art.jpg',
        'assets/worlds/embers-of-the-fallen/cover.jpg',
      ])
        AssetImage(asset),
      FileImage(File(store.resolve(dumah.keyArt!))),
      FileImage(File(store.resolve(dumah.productions.single.picture!))),
      for (final name in ['char-maren.jpg', 'char-bray.jpg', 'char-chorister.jpg', 'scene4-shot13.jpg', 'scene4-shot14b.jpg']) FileImage(File(pathOf(name))),
    ]) {
      final loaded = Completer<void>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((_, _) => loaded.isCompleted ? null : loaded.complete(), onError: (_, _) => loaded.isCompleted ? null : loaded.complete()),
          );
      await loaded.future;
    }
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Size size,
    String location, {
    Brightness brightness = Brightness.dark,
    Future<void> Function(WidgetTester tester)? act,
    Map<String, PartArrival> arriving = const {},
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    addTearDown(tester.view.reset);
    await preload(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
          libraryStoreProvider.overrideWith((ref) async => store),
          volumeProvider.overrideWith((ref) async => (free: 40000000000, total: 128000000000)),
          catalogueProvider.overrideWith((ref) async => [_dumah, _undersong, _quiet, _embers]),
          catalogueRefreshProvider.overrideWith((ref) async {}),
          libraryWorldsProvider.overrideWith((ref) => Stream.value([dumah])),
          worldGuideProvider.overrideWith((ref, worldId) async => worldId == 'the-undersong' ? WorldGuide(guide: _guide, pathOf: pathOf) : null),
          guideFetchProvider.overrideWith((ref, worldId) async {}),
          guideReachProvider.overrideWith((ref, worldId) async => GuideReach.none),
          clockProvider.overrideWithValue(() => _now),
          partsProvider.overrideWith(() => _Arriving(arriving)),
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
    if (act != null) {
      await act(tester);
      await tester.pumpAndSettle();
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory('build/shots').createSync(recursive: true);
    File('build/shots/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  const phone = Size(390, 844);
  const fold = Size(984, 1092);
  final undersong = Routes.discoverWorld('the-undersong');
  final whispers = Routes.production(Routes.libraryWorld('legend-of-dumah'), 'whispers');
  // The page's own list: the rows inside it scroll across.
  Future<void> down(WidgetTester tester, double by) =>
      tester.drag(find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).first, Offset(0, -by));

  testWidgets('P15a discover', (t) => shoot(t, 'P15a-discover', phone, Routes.discover));
  testWidgets('P15a discover, light', (t) => shoot(t, 'P15a-discover-light', phone, Routes.discover, brightness: Brightness.light));
  testWidgets('P15b discover, further down', (t) => shoot(t, 'P15b-discover-down', phone, Routes.discover, act: (tester) => down(tester, 420)));
  testWidgets('P15c a world of several kinds', (t) => shoot(t, 'P15c-kinds', phone, undersong));
  testWidgets('P15d the same world, further down', (t) => shoot(t, 'P15d-kinds-down', phone, undersong, act: (tester) => down(tester, 440)));
  testWidgets('P15e released a chapter at a time', (t) => shoot(t, 'P15e-chapters', phone, whispers));
  testWidgets('P15e light', (t) => shoot(t, 'P15e-chapters-light', phone, whispers, brightness: Brightness.light));
  testWidgets('P15g home', (t) => shoot(t, 'P15g-home', phone, Routes.home));
  testWidgets('P15h library', (t) => shoot(t, 'P15h-library', phone, Routes.library));
  testWidgets(
    'P15j notify',
    (t) => shoot(t, 'P15j-notify', phone, Routes.libraryWorld('legend-of-dumah'), act: (tester) => tester.tap(find.byIcon(Icons.more_horiz).first)),
  );
  testWidgets(
    'P15k downloads',
    (t) => shoot(
      t,
      'P15k-downloads',
      phone,
      Routes.downloads,
      arriving: {
        'legend-of-dumah': PartArrival(world: _dumah, part: _dumahPart, step: const Downloading(9000000, 18000000)),
      },
    ),
  );
  testWidgets('P15l discover on a fold', (t) => shoot(t, 'P15l-discover-fold', fold, Routes.discover));
}
