// Renders the Worlds tab and a world's guide (P11) with the real fonts and pictures, to compare
// with the design's frames. Not a gate — pixels differ by platform — so it runs only when asked:
//
//   SHOOT=1 flutter test test/shoot_guide_test.dart        (from apps/arke_player; PNGs in build/shots)
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
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
const _ledger = 'the-ledger-of-nights';

GuideAfter _after(int number) => GuideAfter(production: _ledger, chapter: 'ch$number', number: number);
GuideSection _section(String heading, String text, {int? after}) => GuideSection(heading: heading, text: text, after: after == null ? null : _after(after));

/// The Undersong's guide as P11 draws it: the fixture world's cast, places and canon (Studio 234).
final _guide = Guide(
  productions: [
    GuideProduction(
      id: _ledger,
      title: 'The Ledger of Nights',
      chapters: [for (var n = 1; n <= 12; n++) GuideChapter(id: 'ch$n', number: n)],
    ),
  ],
  characters: [
    GuideCharacter(
      id: 'maren-kest',
      name: 'Maren Kest',
      role: 'Tide-caller',
      portrait: 'char-maren.jpg',
      sections: [
        _section(
          'Essence',
          'Tide-caller. She hears the verse under the harbour and pulls the water where it needs to go. She has paid for it: her left ear is done, and she knows the right is next.',
        ),
        _section('Appearance', 'Salt-crusted braids, pale grey eyes, oilskin coat with a bioluminescent thread at the collar.'),
        _section('Relationships', 'Trusts Bray with her life, not her secrets.', after: 6),
      ],
      voice: const GuideVoice(audio: 'voice', text: 'I hear it. I always hear it.', duration: Duration(seconds: 8), production: _ledger, chapter: 'ch2'),
      links: const ['bray-half-hitch', 'the-vigil'],
    ),
    GuideCharacter(
      id: 'bray-half-hitch',
      name: 'Bray Half-Hitch',
      role: 'Rigger',
      portrait: 'char-bray.jpg',
      sections: [_section('Essence', 'Rigger on the Vigil’s night crew.')],
      links: const ['maren-kest', 'the-vigil'],
    ),
    GuideCharacter(
      id: 'the-chorister',
      name: 'The Chorister',
      role: 'Keeper of the drowned verse',
      portrait: 'char-chorister.jpg',
      sections: [_section('Essence', 'Keeper of the drowned verse.')],
    ),
    GuideCharacter(id: 'perrin-tallow', name: 'Perrin Tallow', role: 'Council actuary', sections: [_section('Essence', 'Council actuary.')]),
    GuideCharacter(id: 'ines-half-hitch', name: 'Ines Half-Hitch', role: 'Council clerk, retired', after: _after(9), sections: const []),
  ],
  places: [
    GuidePlace(
      id: 'the-vigil',
      name: 'The Vigil',
      role: 'Harbour mouth',
      picture: 'scene4-shot13.jpg',
      sections: [
        _section(
          'Look',
          'A watchtower of black stone at the harbour mouth, ringed by a rail worn smooth by two hundred years of gripping hands. Lamps burn green-white.',
        ),
        _section('Sound', 'Bells under the water on the worst nights. The rail hums a fifth below the wind.'),
      ],
      links: const ['maren-kest'],
    ),
    GuidePlace(
      id: 'the-saltmarket',
      name: 'The Saltmarket',
      role: 'Market',
      picture: 'launch-harbour.jpg',
      sections: [_section('Look', 'Stalls under sailcloth.')],
    ),
    GuidePlace(
      id: 'the-drowned-chapel',
      name: 'The Drowned Chapel',
      role: 'Chapel',
      picture: 'drowned-quarter.jpg',
      sections: [_section('Look', 'Half under water.')],
    ),
    GuidePlace(id: 'the-quiet-ward', name: 'The Quiet Ward', role: 'Ward', after: _after(11), sections: const []),
  ],
  lore: [
    const GuideLore(
      id: 'canon-001',
      kind: LoreKind.lore,
      title: 'The Undersong',
      text:
          'Beneath the harbour lies a drowned god, and it is still singing. The song is slow — one verse a season — and the harbour’s luck rises and falls with the verse. Most people have never heard it. Everyone has felt it.',
      links: ['maren-kest', 'the-chorister', 'the-vigil'],
    ),
    const GuideLore(id: 'canon-002', kind: LoreKind.rule, title: 'Tide-calling', text: 'A caller pays with her hearing.'),
    const GuideLore(id: 'canon-031', kind: LoreKind.timeline, title: 'The drowning of the god', text: 'The god went under.'),
    const GuideLore(id: 'canon-045', kind: LoreKind.rule, title: 'The ledger is never wrong', text: 'What the ledger says is so.'),
    const GuideLore(id: 'canon-053', kind: LoreKind.lore, title: 'The Departure', text: 'They left by the north channel.'),
    const GuideLore(id: 'canon-057', kind: LoreKind.rule, title: 'The Seven Anchors', text: 'Seven hold the harbour.'),
    GuideLore(id: 'canon-052', kind: LoreKind.lore, title: 'What was left to hold the harbour', text: 'Something stayed.', after: _after(6)),
    GuideLore(id: 'canon-049', kind: LoreKind.rule, title: 'What the tithe buys', text: 'Notice.', after: _after(11)),
  ],
);

/// A world to come, with nine characters and no pictures (P11a's Available).
final _copperGuide = Guide(
  productions: const [],
  characters: [for (var i = 0; i < 9; i++) GuideCharacter(id: 'c$i', name: 'Saint $i', sections: const [])],
  places: const [],
  lore: const [],
);

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
  late LibraryWorld installed;
  late List<LibraryItem> worldItems;
  final assets = Directory('../../design/assets').absolute.path;
  String pathOf(String assetId) => '$assets${Platform.pathSeparator}$assetId';

  final undersong = CatalogueWorld(
    id: 'undersong',
    name: 'The Undersong',
    logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
    keyArt: 'assets/worlds/undersong/key-art.jpg',
    productions: const [
      CatalogueProduction(title: 'The Ledger of Nights', kind: 'Audiobook · Book · 3 h 49 m', picture: 'assets/worlds/undersong/ledger-of-nights.jpg'),
    ],
    package: CataloguePackage(url: Uri.parse('https://example.org/undersong.zip'), byteLength: 386000000, sha256: 'a' * 64),
  );
  final copper = CatalogueWorld(
    id: 'copper-saints',
    name: 'Copper Saints',
    productions: const [
      CatalogueProduction(title: 'One', kind: 'Book'),
      CatalogueProduction(title: 'Two', kind: 'Book'),
    ],
    package: CataloguePackage(url: Uri.parse('https://example.org/copper.zip'), byteLength: 240000000, sha256: 'b' * 64),
  );

  setUpAll(() async {
    await _loadFonts();
    root = Directory.systemTemp.createTempSync('arke-player-guide-shots-');
    store = LibraryStore(root);
    String place(String relative, String picture) {
      final file = File(store.resolve(relative))..parent.createSync(recursive: true);
      File('$assets/$picture').copySync(file.path);
      return relative;
    }

    installed = LibraryWorld(
      id: 'undersong',
      edition: '2026-10-22',
      name: 'The Undersong',
      logline: 'A drowned god still sings beneath the harbour of Saltmouth.',
      keyArt: place('worlds/undersong/key-art.jpg', 'world-undersong.jpg'),
      byteLength: 386000000,
      installedAt: DateTime.utc(2026, 10, 22),
      productions: [
        LibraryProduction(
          id: _ledger,
          title: 'The Ledger of Nights',
          picture: place('worlds/undersong/ledger/picture.jpg', 'banner-story.jpg'),
          book: 'undersong.ledger.book',
          narration: 'undersong.ledger.listening',
        ),
      ],
    );
    worldItems = [
      LibraryItem(
        id: 'undersong.ledger.listening',
        format: FileFormat.listening,
        title: 'The Ledger of Nights',
        byteLength: 120000000,
        addedAt: DateTime.utc(2026, 10, 22),
        file: 'worlds/undersong/ledger/listening.json',
        duration: const Duration(hours: 3, minutes: 49),
        worldId: 'undersong',
      ),
      LibraryItem(
        id: 'undersong.ledger.book',
        format: FileFormat.epub,
        title: 'The Ledger of Nights',
        byteLength: 400000,
        addedAt: DateTime.utc(2026, 10, 22),
        file: 'worlds/undersong/ledger/book.epub',
        worldId: 'undersong',
      ),
    ];
  });

  tearDownAll(() => root.deleteSync(recursive: true));

  /// Decodes every picture on the real clock, so the screens find them ready.
  Future<void> preload(WidgetTester tester) => tester.runAsync(() async {
    for (final provider in <ImageProvider>[
      const AssetImage('assets/worlds/undersong/key-art.jpg'),
      const AssetImage('assets/worlds/undersong/ledger-of-nights.jpg'),
      FileImage(File(store.resolve(installed.keyArt!))),
      FileImage(File(store.resolve(installed.productions.single.picture!))),
      for (final name in ['char-maren.jpg', 'char-bray.jpg', 'char-chorister.jpg', 'scene4-shot13.jpg', 'launch-harbour.jpg', 'drowned-quarter.jpg'])
        FileImage(File(pathOf(name))),
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
    bool isInstalled = true,
    Brightness brightness = Brightness.dark,
    Future<void> Function(WidgetTester tester)? act,
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
          libraryItemsProvider.overrideWith((ref) => Stream.value(isInstalled ? worldItems : const [])),
          libraryStoreProvider.overrideWith((ref) async => store),
          volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
          catalogueProvider.overrideWith((ref) async => [undersong, copper]),
          libraryWorldsProvider.overrideWith((ref) => Stream.value(isInstalled ? [installed] : const [])),
          worldGuideProvider.overrideWith(
            (ref, worldId) async => switch (worldId) {
              'undersong' => WorldGuide(guide: _guide, pathOf: pathOf),
              'copper-saints' => WorldGuide(guide: _copperGuide, pathOf: pathOf),
              _ => null,
            },
          ),
          guideFetchProvider.overrideWith((ref, worldId) async {}),
          guideReachProvider.overrideWith((ref, worldId) async => GuideReach(reached: isInstalled ? const {_ledger: (at: 3, through: 3)} : const {})),
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
  final world = Routes.discoverWorld('undersong');
  Future<void> toGuide(WidgetTester tester) => tester.scrollUntilVisible(find.text('Characters'), 400, scrollable: find.byType(Scrollable).last);
  Future<void> scrolled(WidgetTester tester) async {
    await toGuide(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
  }

  testWidgets('P11a worlds', (t) => shoot(t, 'P11a-worlds', phone, Routes.discover));
  testWidgets('P11a worlds, light', (t) => shoot(t, 'P11a-worlds-light', phone, Routes.discover, brightness: Brightness.light));
  testWidgets('P11b before install', (t) => shoot(t, 'P11b-before-install', phone, world, isInstalled: false));
  testWidgets('P11b before install, its guide', (t) => shoot(t, 'P11b-before-install-guide', phone, world, isInstalled: false, act: scrolled));
  testWidgets('P11c installed, its guide', (t) => shoot(t, 'P11c-installed-guide', phone, world, act: scrolled));
  testWidgets('P11c installed, light', (t) => shoot(t, 'P11c-installed-guide-light', phone, world, act: scrolled, brightness: Brightness.light));
  testWidgets('P11d a character', (t) => shoot(t, 'P11d-character', phone, Routes.guideEntry(world, 'maren-kest')));
  testWidgets('P11d a character, light', (t) => shoot(t, 'P11d-character-light', phone, Routes.guideEntry(world, 'maren-kest'), brightness: Brightness.light));
  testWidgets('P11e a place', (t) => shoot(t, 'P11e-place', phone, Routes.guideEntry(world, 'the-vigil')));
  testWidgets('P11f lore', (t) => shoot(t, 'P11f-lore', phone, Routes.lore(world)));
  testWidgets('P11g a lore entry', (t) => shoot(t, 'P11g-lore-entry', phone, Routes.guideEntry(world, 'canon-001')));
  testWidgets(
    'P11h reveal',
    (t) => shoot(t, 'P11h-reveal', phone, Routes.guideEntry(world, 'maren-kest'), act: (tester) => tester.tap(find.text('Reveal').first)),
  );
  testWidgets('P11i on a fold', (t) => shoot(t, 'P11i-fold', fold, world, act: toGuide));
}
