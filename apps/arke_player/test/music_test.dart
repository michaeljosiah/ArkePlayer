import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/widgets/shelf.dart';
import 'package:arke_player/features/parts/application/parts.dart';
import 'package:arke_player/features/players/application/music.dart';
import 'package:arke_player/features/players/application/players.dart';
import 'package:arke_player/features/players/presentation/music_widgets.dart';
import 'package:arke_player/features/production/domain/production_kind.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_player/features/worlds/presentation/row_widgets.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'music_fixture.dart';

// SPEC-058 R-72 – R-78 and SPEC-059 R-38 on the Player (P17): the Music group, an album's page,
// playing music, lyrics, Heard in, Theme and the Song teaser, and a production package arriving.

final _world = Routes.discoverWorld(worldId);
final _album = Routes.production(_world, albumId);
const _fold = Size(984, 1092);

/// The page's own list: the rows inside it scroll across.
Finder get _page => find.byWidgetPredicate((widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down).first;

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200, scrollable: _page);
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder.first).dy;

class _Installer extends WorldInstaller {
  _Installer() : super(store: LibraryStore(Directory.systemTemp), freeBytes: (_) async => null);
  final installed = <String>[];
  final swaps = <bool>[];

  @override
  Future<LibraryWorld> installProduction(
    CatalogueWorld world,
    CatalogueProduction listed, {
    void Function(InstallStep step)? onStep,
    InstallCancel? cancel,
    Future<void> Function()? beforeSwap,
    File? from,
  }) async {
    onStep?.call(const Downloading(9000000, 36000000));
    if (beforeSwap != null) {
      await beforeSwap();
      swaps.add(true);
    }
    installed.add(listed.id!);
    return undersong();
  }
}

class _Store extends LibraryStore {
  _Store(this.world) : super(Directory.systemTemp);
  final LibraryWorld world;

  @override
  List<LibraryWorld> get worlds => [world];
}

void main() {
  group('words', () {
    test('a tile names its kind, and a single its length (R-73)', () {
      expect(musicTileKind('album', tracks: 9, length: const Duration(minutes: 34)), 'Album · 9 tracks');
      expect(musicTileKind('single', tracks: 1, length: const Duration(minutes: 3, seconds: 42)), 'Single · 3:42');
      expect(musicTileKind('soundtrack', tracks: 14, length: const Duration(minutes: 47)), 'Soundtrack · 14 tracks');
      expect(musicMeta('album', of: 'The Undersong', tracks: 9, length: const Duration(minutes: 34, seconds: 26)), 'Album · The Undersong · 9 tracks · 34 min');
      expect(musicMeta('single', of: 'The Undersong', tracks: 1, length: const Duration(minutes: 3, seconds: 42)), 'Single · The Undersong · 3:42');
    });

    test('music is its own group, after Listen, but never a chip (P17 rule 2)', () {
      expect(TakenAs.values.take(3), [TakenAs.listen, TakenAs.music, TakenAs.watch]);
      expect(TakenAs.chips, isNot(contains(TakenAs.music)));
      expect(TakenAs.music.chip, TakenAs.listen);
      expect([
        for (final kind in ['album', 'single', 'soundtrack']) ProductionKind.ofMusic(kind).takenAs,
      ], everyElement(TakenAs.music));
      expect(ProductionKind.ofLine('Soundtrack · 14 tracks'), ProductionKind.soundtrack);
    });

    test('lyrics are the words as written, by stanza, without their structure tags (R-76)', () {
      expect(lyricStanzas(lyrics), [
        'Under the harbour the old bells turn,\nsalt in the ledger, the lamps that burn.\nCount me the tides that the city forgot,\nsing me the name that the water has not.',
        'Hold the verse, hold it low,\ndown where the drowned ones go.',
      ]);
      expect(lyricStanzas('[intro]\n\n  \n'), isEmpty);
    });
  });

  group('the queue', () {
    final album = musicAlbum(undersong().productions.firstWhere((production) => production.id == albumId));

    test('the tracks play back to back on one clock, as a narration’s chapters do (R-75)', () {
      expect(album.starts.take(3), [Duration.zero, const Duration(minutes: 4, seconds: 12), const Duration(minutes: 7, seconds: 17)]);
      expect(album.locate(const Duration(minutes: 5)), (1, const Duration(seconds: 48)));
      expect(album.length, const Duration(minutes: 34, seconds: 26));
      expect(album.meta, 'Album · The Undersong · 9 tracks · 34 min');
    });

    test('a song keeps no place: the album is no library item (call 20)', () {
      final item = album.asItem;
      expect((item.id, item.place, item.chapters.length), ('music:$worldId/$albumId', null, 9));
    });

    test('Previous goes to the start of the track, or the one before in its first three seconds', () {
      expect(previousTrack(3, const Duration(seconds: 40)), 3);
      expect(previousTrack(3, const Duration(seconds: 2)), 2);
      expect(previousTrack(0, const Duration(seconds: 1)), 0);
    });

    test('repeat goes off, the album, the track, off', () {
      expect([MusicRepeat.off.next, MusicRepeat.all.next, MusicRepeat.one.next], [MusicRepeat.all, MusicRepeat.one, MusicRepeat.off]);
    });
  });

  group('Heard in and Theme', () {
    final album = musicAlbum(undersong().productions.firstWhere((production) => production.id == albumId));

    test('a track’s theme is the guide’s entry, which follows its gate (SPEC-059 R-35)', () {
      expect((themeEntry(guide, GuideReach.none, albumId, 'the-drowned-verse') as GuideCharacter?)?.name, 'The Chorister');
      expect(themeEntry(guide, GuideReach.none, albumId, 'slack-water'), isNull);
      final gated = Guide(
        productions: guide.productions,
        characters: const [
          GuideCharacter(
            id: 'ines',
            name: 'Ines',
            after: GuideAfter(production: ledgerId, chapter: 'ch9', number: 9),
            theme: drownedVerse,
            sections: [],
          ),
        ],
        places: const [],
        lore: const [],
      );
      expect(themeEntry(gated, GuideReach.none, albumId, 'the-drowned-verse'), isNull);
    });

    test('a Heard in row names the chapter and opens it once the production is installed (R-77)', () {
      final heard = album.tracks.first.heardIn.single;
      final place = heardPlace(heard, world: undersong(), items: {narrationId: narration}, guide: guide)!;
      expect((place.line, place.opens, place.chapter?.id), ('Heard in · The Ledger of Nights, Chapter 9', true, 'ch9'));
      final away = heardPlace(heard, listed: listedUndersong())!;
      expect((away.line, away.opens), ('Heard in · The Ledger of Nights', false));
      expect(heardPlace(const MusicHeardIn(production: 'gone', chapter: 'a', at: Duration.zero)), isNull);
    });

    test('a production’s music is every track heard in it, in album order', () {
      final heard = tracksHeardIn(worldMusic(), ledgerId);
      expect(
        [for (final song in heard) (song.album.production.id, song.track, song.heard.chapter)],
        [(albumId, 0, 'ch9'), (albumId, 2, 'ch8'), (singleId, 0, 'ch8')],
      );
    });
  });

  group('the Music group', () {
    testWidgets('a world to install shows Listen, Music, Watch, each with its count (P17a)', (tester) async {
      await pumpMusic(tester, _world, installed: false);
      final heads = ['Listen', 'Music', 'Watch'];
      for (final head in heads) {
        await _reveal(tester, find.text(head));
      }
      await tester.scrollUntilVisible(find.text('Listen'), -200, scrollable: _page);
      await tester.pumpAndSettle();
      expect(_top(tester, find.text('Listen')) < _top(tester, find.text('Music')), isTrue);
      await _reveal(tester, find.text('Soundtrack · 14 tracks'));
      expect(find.text('Album · 9 tracks'), findsOneWidget);
      expect(find.text('Single · 3:42'), findsOneWidget);
      expect(_top(tester, find.text('Music')) < _top(tester, find.text('Watch')), isTrue);
      // The squares are 160 on a phone (P17 rule 3).
      expect(tester.getSize(find.byType(SquareTile).first).width, 160);
    });

    testWidgets('installed, a tile opens its album; one listed and not yet here still shows (R-72, R-73)', (tester) async {
      await pumpMusic(tester, _world, listed: listedUndersong(lantern: true));
      await _reveal(tester, find.text('Lantern Songs'));
      expect(find.text('Album · 6 tracks'), findsOneWidget);
      await tester.tap(find.text('Lantern Songs'));
      await tester.pumpAndSettle();
      expect(find.text('Lantern Songs'), findsOneWidget, reason: 'it opens nothing until it arrives');
      await tester.ensureVisible(find.text('Songs of the Drowned Quarter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Songs of the Drowned Quarter'));
      await tester.pumpAndSettle();
      expect(find.text('Play all'), findsOneWidget);
    });

    testWidgets('a changed package is its Update, on the tile and the page (R-72)', (tester) async {
      await pumpMusic(tester, _world, listed: listedUndersong(albumFingerprint: 'b'));
      await _reveal(tester, find.text('Songs of the Drowned Quarter'));
      expect(find.bySemanticsLabel(RegExp('Songs of the Drowned Quarter, Album · 9 tracks, Update')), findsOneWidget);
      await tester.tap(find.text('Songs of the Drowned Quarter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Update'), findsOneWidget);
    });

    testWidgets('Discover has a Music row after Stories, under All and Listen (P17b)', (tester) async {
      // Tall enough that every row is built, so their order can be read.
      await pumpMusic(tester, Routes.discover, size: const Size(390, 2600));
      final heads = [for (final head in tester.widgetList<SectionHead>(find.byType(SectionHead))) head.title];
      expect(heads.indexOf('Music'), heads.indexOf('Stories') + 1);
      expect(find.text('Album · The Undersong'), findsOneWidget);
      // Arke's list does not say what a soundtrack is for; its installed document does.
      expect(find.text('Soundtrack · The Bell Watch'), findsOneWidget, reason: 'a soundtrack names what it is for');
      // Music is not a story, and has no chip of its own.
      expect(find.text('Album · The Undersong'), findsOneWidget);
      expect(find.byType(PosterTile).evaluate().where((element) => (element.widget as PosterTile).title == 'Saltmouth Bells'), isEmpty);
      expect(find.text('Music'), findsOneWidget);

      await tester.tap(find.text('Listen'));
      await tester.pumpAndSettle();
      expect(find.text('Album · The Undersong'), findsOneWidget);
      await tester.tap(find.text('Watch'));
      await tester.pumpAndSettle();
      expect(find.text('Album · The Undersong'), findsNothing);
    });

    testWidgets('a song is a teaser, a small poster with a note; opened, it plays its excerpt (R-78)', (tester) async {
      final teaser = HeardTeaser();
      await pumpMusic(tester, Routes.discover, teaser: teaser);
      await _reveal(tester, find.text('Song · 0:24'));
      expect(teaser.played, isEmpty, reason: 'nothing plays in the row');
      await tester.tap(find.text('Song · 0:24'));
      await tester.pumpAndSettle();
      expect(teaser.played, [designAsset('verse-excerpt.m4a')]);
      expect(find.text('Song · 0:24 · The Undersong'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(teaser.stopped, 1);
    });
  });

  group('an album’s page', () {
    testWidgets('the cover, the meta, Play all and Shuffle, and the numbered tracks with one line each (P17c)', (tester) async {
      final engine = MusicEngine();
      await pumpMusic(tester, _album, engine: engine);
      expect(find.text('Album · The Undersong · 9 tracks · 34 min'), findsOneWidget);
      expect(find.text('Theme · The Chorister'), findsOneWidget);
      expect(find.text('Heard in · The Ledger of Nights, Chapter 8'), findsOneWidget);
      expect(find.text('Theme · Maren Kest'), findsOneWidget);
      expect(find.text('4:12'), findsOneWidget);

      // A track pressed plays where it is, from its start.
      await tester.tap(find.text('Slack Water'));
      await tester.pumpAndSettle();
      expect(engine.opened.last, (albumId, 1, null));
      expect(find.bySemanticsLabel(RegExp(r'^Slack Water, 3:05, Playing$')), findsOneWidget, reason: 'the one playing shows bars');
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      // The dock names the track over its album, with Next where back 15 was (R-75).
      expect(find.byTooltip('Next'), findsOneWidget);
      expect(find.byTooltip('Back 15 seconds'), findsNothing);
      expect(find.text('Songs of the Drowned Quarter'), findsNWidgets(2));
    });

    testWidgets('Play all opens the player at track 1 in order; Shuffle in a shuffled order', (tester) async {
      final engine = MusicEngine();
      await pumpMusic(tester, _album, engine: engine);
      await tester.tap(find.text('Play all'));
      await tester.pumpAndSettle();
      expect(engine.opened.last, (albumId, 0, false));
      expect(find.text('1 of 9'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();
      expect(engine.opened.last.$3, isTrue);
    });

    testWidgets('on a Fold the tracks run in two columns, and More from the world follows (P17h)', (tester) async {
      await pumpMusic(tester, _album, size: _fold, engine: MusicEngine());
      Offset row(String title) => tester.getTopLeft(find.ancestor(of: find.text(title), matching: find.byType(TrackRow)));
      final first = row('The Drowned Verse');
      final sixth = row('Lantern Road');
      expect(sixth.dx > first.dx + 300, isTrue, reason: 'the second half in the right column');
      expect((sixth.dy - first.dy).abs() < 1, isTrue);
      await _reveal(tester, find.text('More from The Undersong'));
      expect(find.text('Single · 3:42'), findsOneWidget);
      expect(tester.getSize(find.byType(SquareTile).first).width, 200);
    });

    testWidgets('a soundtrack names what it is for (P17 rule 1)', (tester) async {
      await pumpMusic(tester, Routes.production(_world, scoreId), engine: MusicEngine());
      expect(find.text('Soundtrack · The Bell Watch · 14 tracks · 46 min'), findsOneWidget);
    });
  });

  group('playing', () {
    MusicAlbum album() => musicAlbum(undersong().productions.firstWhere((production) => production.id == albumId));

    testWidgets('the player: the track, whose theme it is, and shuffle, previous, next and repeat (P17d)', (tester) async {
      final engine = MusicEngine(album: album(), now: const Duration(seconds: 48));
      await pumpMusic(tester, Routes.music(worldId, albumId), engine: engine);
      expect(find.text('The Drowned Verse'), findsOneWidget);
      expect(find.text('Theme · The Chorister'), findsOneWidget);
      expect(find.text('1 of 9'), findsOneWidget);
      expect(engine.opened, isEmpty, reason: 'from the dock it shows what plays');

      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(engine.nexts, 1);
      expect(find.text('2 of 9'), findsOneWidget);
      expect(find.text('Slack Water'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous'));
      await tester.pumpAndSettle();
      expect(engine.track, 1, reason: '48 seconds in, Previous is the start of the track');

      await tester.tap(find.byTooltip('Shuffle'));
      await tester.tap(find.byTooltip('Repeat off'));
      await tester.pumpAndSettle();
      expect((engine.shuffling, engine.repeat), (true, MusicRepeat.all));
      await tester.tap(find.byTooltip('Repeat album'));
      await tester.pumpAndSettle();
      expect(engine.repeat, MusicRepeat.one);
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
    });

    testWidgets('Lyrics: the words as written over the dimmed cover, only for a track with words (P17e)', (tester) async {
      final engine = MusicEngine(album: album());
      await pumpMusic(tester, Routes.music(worldId, albumId), engine: engine);
      await tester.tap(find.text('Lyrics'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Under the harbour the old bells turn,'), findsOneWidget);
      expect(find.textContaining('Hold the verse, hold it low,'), findsOneWidget);
      expect(find.textContaining('[verse]'), findsNothing);
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Lyrics'), findsNothing, reason: 'Slack Water has no words');
    });

    testWidgets('Tracks lists the album; one pressed plays', (tester) async {
      final engine = MusicEngine(album: album());
      await pumpMusic(tester, Routes.music(worldId, albumId), engine: engine);
      await tester.tap(find.text('Tracks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undersong').last);
      await tester.pumpAndSettle();
      expect(engine.opened.last, (albumId, 8, null));
    });

    testWidgets('the Heard in chapter opens the narration there, at its moment (R-77)', (tester) async {
      final kept = <(String, Place)>[];
      await pumpMusic(
        tester,
        Routes.music(worldId, albumId),
        engine: MusicEngine(album: album()),
        kept: kept,
      );
      await tester.tap(find.text('Chapter 9'));
      await tester.pumpAndSettle();
      expect(kept.single.$1, narrationId);
      expect((kept.single.$2.locator, kept.single.$2.position), ('ch9', const Duration(minutes: 12, seconds: 10)));
    });
  });

  group('elsewhere in the world', () {
    testWidgets('a production’s page lists its Music, and a chapter holding a song carries a note (P17g)', (tester) async {
      final engine = MusicEngine();
      // Tall enough for all 23 chapters and the music under them.
      await pumpMusic(tester, Routes.production(_world, ledgerId), engine: engine, size: const Size(390, 2400));
      expect(find.bySemanticsLabel(RegExp(r'^Chapter 8, 38:00, Music, Heard$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Chapter 9, 44:00, Music$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Chapter 7, 32:00, Heard$')), findsOneWidget);
      expect(find.text('Chapter 8 · Single'), findsOneWidget);
      expect(find.text('Chapter 9 · Songs of the Drowned Quarter'), findsOneWidget);
      await tester.tap(find.byTooltip('Play Saltmouth Bells').last);
      expect(engine.opened.last, (singleId, 0, null));
    });

    testWidgets('a character’s Theme, under its Voice, plays once its music is installed (R-77)', (tester) async {
      final engine = MusicEngine();
      await pumpMusic(tester, Routes.guideEntry(_world, 'the-chorister'), engine: engine);
      expect(find.text('Theme'), findsOneWidget);
      expect(_top(tester, find.textContaining('Voice', findRichText: true)) < _top(tester, find.text('Theme')), isTrue);
      expect(find.text('Songs of the Drowned Quarter · 4:12'), findsOneWidget);
      await tester.tap(find.byTooltip('Play The Drowned Verse'));
      expect(engine.opened.single, (albumId, 0, null));
    });

    testWidgets('before its music is installed, a Theme shows its title and length, with no play', (tester) async {
      await pumpMusic(tester, Routes.guideEntry(_world, 'the-chorister'), installed: false, engine: MusicEngine());
      expect(find.text('The Drowned Verse'), findsOneWidget);
      expect(find.text('Songs of the Drowned Quarter · 4:12'), findsOneWidget);
      expect(find.byTooltip('Play The Drowned Verse'), findsNothing);
    });
  });

  group('a production package arriving', () {
    final world = undersong(music: false);

    ProviderContainer container({required bool wifi, required _Installer installer, CatalogueWorld? listed}) {
      final made = ProviderContainer(
        overrides: [
          catalogueProvider.overrideWith((ref) async => [listed ?? listedUndersong()]),
          libraryStoreProvider.overrideWith((ref) async => _Store(world)),
          libraryRootProvider.overrideWith((ref) async => Directory.systemTemp.createTempSync('arke-music-')),
          worldInstallerProvider.overrideWith((ref) async => installer),
          onWifiProvider.overrideWithValue(() async => wifi),
        ],
      );
      addTearDown(made.dispose);
      return made;
    }

    test('listed after install, each comes on its own over Wi-Fi, shown in Downloads as it comes (R-72)', () async {
      final installer = _Installer();
      final parts = container(wifi: true, installer: installer);
      final seen = <String>[];
      parts.listen(partsProvider, (_, next) => seen.addAll([for (final arrival in next.values) arrival.line()]));
      await parts.read(partsProvider.notifier).check();
      expect(installer.installed, [albumId, singleId, scoreId]);
      expect(seen, contains('Songs of the Drowned Quarter · 9 MB of 36 MB'));
      expect(parts.read(partsProvider), isEmpty);
    });

    test('Wi-Fi only, on mobile data, it waits', () async {
      final installer = _Installer();
      final parts = container(wifi: false, installer: installer);
      await parts.read(partsProvider.notifier).check();
      expect(installer.installed, isEmpty);
      final waiting = parts.read(partsProvider)[worldId]!;
      expect((waiting.waiting, waiting.line()), (true, 'Songs of the Drowned Quarter · 36 MB · Waiting'));
    });

    test('a changed one waits for its Update to be pressed, then lets go of what plays', () async {
      final installer = _Installer();
      final listed = listedUndersong(albumFingerprint: 'b');
      final engine = MusicEngine(album: musicAlbum(undersong().productions.firstWhere((production) => production.id == albumId)), playing: false);
      final made = ProviderContainer(
        overrides: [
          catalogueProvider.overrideWith((ref) async => [listed]),
          libraryWorldsProvider.overrideWith((ref) => Stream.value([undersong()])),
          worldInstallerProvider.overrideWith((ref) async => installer),
          audioEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(made.dispose);
      // Held open, as a page holds them, so neither is let go while it loads.
      made.listen(catalogueProvider, (_, _) {});
      made.listen(libraryWorldsProvider, (_, _) {});
      await made.read(catalogueProvider.future);
      await made.read(libraryWorldsProvider.future);
      final update = made.read(productionUpdateProvider((worldId, albumId)));
      expect(update?.id, albumId);
      expect(made.read(productionUpdateProvider((worldId, singleId))), isNull);
      await made.read(productionInstallProvider((worldId, albumId)).notifier).start(listed, update!);
      expect(installer.installed, [albumId]);
      expect(installer.swaps, [true]);
      expect(engine.music, isNull, reason: 'the album that played let go, so its next play opens the new files');
      expect(made.read(productionInstallProvider((worldId, albumId))), isA<NotInstalling>());
    });
  });
}
