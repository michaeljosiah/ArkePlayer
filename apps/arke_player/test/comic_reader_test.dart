import 'dart:convert';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/features/comics/application/comics.dart';
import 'package:arke_player/features/players/domain/player_kind.dart';
import 'package:arke_player/features/production/domain/production_kind.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'story_fixture.dart';

// SPEC-064 R-50, Player P20: a graphic novel installed beside its world, under Read with its page
// count, its page with Read or Continue and its chapters, and its reader — a page whole on black, a
// tap that shows the controls and never turns, a swipe that turns the way the book reads, the page
// kept. The document is the shared fixture ArkeStudio's contracts write.
void main() {
  final fixtures = '${Directory.current.path}/../../packages/arke_world/test/fixtures/comic';
  final assets = {
    for (final MapEntry(:key, value: raw) in (jsonDecode(File('$fixtures/assets.json').readAsStringSync()) as Map<String, Object?>).entries)
      if (raw case {'path': final String path, 'mediaType': final String mediaType, 'byteLength': final int byteLength, 'sha256': final String sha256})
        key: WorldAsset(path: path, mediaType: mediaType, byteLength: byteLength, sha256: sha256),
  };
  ComicDocument read(String name) => switch (readComic(File('$fixtures/$name').readAsStringSync(), assets)) {
    ComicOk(:final document) => document,
    ComicRefused(:final reason) => throw StateError(reason),
  };

  const id = 'low-water-drawn';
  LoadedComic loaded(ComicDocument document) => LoadedComic(
    worldId: worldId,
    worldName: 'The Undersong',
    production: LibraryProduction(
      id: id,
      title: 'Low Water',
      picture: 'drowned-quarter.jpg',
      comic: LibraryComic(
        document: 'worlds/$worldId/_productions/$id/$id/comic.json',
        reading: document.reading.name,
        aspect: document.aspect,
        chapters: document.chapters.length,
        pages: document.pages.length,
      ),
      package: LibraryProductionPackage(
        edition: '2026-10-29',
        fingerprint: 'd' * 64,
        byteLength: 48000000,
        installedAt: DateTime.utc(2026, 10, 29),
        folder: 'worlds/$worldId/_productions/$id',
      ),
    ),
    document: document,
    pathOf: (_) => designAsset('drowned-quarter.jpg'),
  );

  final ltr = loaded(read('low-water-drawn.json'));
  final rtl = loaded(read('right-to-left.json'));
  final world = Routes.libraryWorld(worldId);
  final page = Routes.production(world, id);
  final reader = Routes.comic(worldId, id);
  MemorySaves at(int page) => MemorySaves({
    LibraryStore.storyKey(worldId, id): {'comicPage': page},
  });

  test('a graphic novel is read, in the page viewer', () {
    expect(ProductionKind.graphicNovel.takenAs.label, 'Read');
    expect(ProductionKind.ofLine('Graphic novel · 24 pages'), ProductionKind.graphicNovel);
    expect(playerForProduction(ProductionKind.graphicNovel), PlayerKind.pageViewer);
  });

  testWidgets('an installed graphic novel sits under Read with its page count, and opens its page', (tester) async {
    await pumpStories(tester, world, stories: const [], comics: [ltr]);
    expect(find.text('Graphic novel · 4 pages'), findsOneWidget);
    await tester.tap(find.text('Low Water'));
    await tester.pumpAndSettle();
    expect(find.text('Graphic novel · The Undersong · 4 pages'), findsOneWidget);
    expect(find.text('Read'), findsWidgets);
  });

  testWidgets('a graphic novel in a version this Player does not read shows Update app (P20h)', (tester) async {
    final listed = listedStoryWorld(const []);
    final newer = CatalogueWorld(
      id: listed.id,
      name: listed.name,
      logline: listed.logline,
      keyArt: listed.keyArt,
      package: listed.package,
      productions: [
        ...listed.productions,
        CatalogueProduction(id: 'the-tide', title: 'The Tide', kind: 'Graphic novel · 24 pages', comic: storyPin('the-tide', version: 2)),
      ],
    );
    await pumpStories(tester, world, stories: const [], listed: newer);
    expect(find.text('Update app'), findsOneWidget);
  });

  testWidgets('its page: Continue at the page kept, and its chapters', (tester) async {
    await pumpStories(tester, page, stories: const [], comics: [ltr], saves: at(2));
    expect(find.text('Continue · Page 3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('2 · Salt'), 200);
    expect(find.text('Chapters'), findsOneWidget);
    expect(find.text('1 · The tide'), findsOneWidget);
    // A chapter opens the reader at its first page.
    await tester.tap(find.text('2 · Salt'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('The empty water. Hsssh.'), findsOneWidget);
  });

  double chrome(WidgetTester tester) => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets('it opens with its controls showing, and they rest (P21 rule 5)', (tester) async {
    await pumpStories(tester, reader, stories: const [], comics: [ltr]);
    // The page has the whole screen, not the controls' height.
    expect(tester.getSize(find.byType(PageView)), const Size(390, 844));
    // The top bar's buttons are at the top, not over the page.
    expect(tester.getCenter(find.byTooltip('Close')).dy, lessThan(80));
    expect(chrome(tester), 1);
    expect(find.text('Chapter 1 · The tide'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.byTooltip('Next page'), findsOneWidget);
    expect(find.byTooltip('Pages'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(chrome(tester), 0, reason: 'resting, nothing over the page');
  });

  testWidgets('a tap at an edge turns at once; the middle shows the controls; a swipe turns (rules 6, 7)', (tester) async {
    final saves = MemorySaves();
    await pumpStories(tester, reader, stories: const [], comics: [ltr], saves: saves);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // The middle: the controls, and never a turn.
    await tester.tapAt(const Offset(195, 422));
    await tester.pump(const Duration(milliseconds: 200));
    expect(chrome(tester), 1);
    expect(find.text('1 of 4'), findsOneWidget, reason: 'the middle never turns');
    // The right edge: the next page, with no wait for a second tap.
    await tester.tapAt(const Offset(370, 422));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4'), findsOneWidget);
    expect(saves.kept.last, {'comicPage': 1});
    // The left edge: back.
    await tester.tapAt(const Offset(20, 422));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4'), findsOneWidget);
    // A swipe still turns.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 4'), findsOneWidget);
  });

  testWidgets('back and next at the foot turn the page', (tester) async {
    await pumpStories(tester, reader, stories: const [], comics: [ltr]);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4'), findsOneWidget);
  });

  testWidgets('right to left: the next page comes from the left, and the left edge turns on', (tester) async {
    await pumpStories(tester, reader, stories: const [], comics: [rtl]);
    expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 4'), findsOneWidget);
    await tester.tapAt(const Offset(20, 422));
    await tester.pumpAndSettle();
    expect(find.text('3 of 4'), findsOneWidget);
  });

  testWidgets('Pages opens a page; Chapters goes to a chapter (rule 8)', (tester) async {
    await pumpStories(tester, reader, stories: const [], comics: [ltr]);
    await tester.tap(find.byTooltip('Pages'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Page 4'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Page 4'));
    await tester.pumpAndSettle();
    expect(find.text('4 of 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Chapters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 · Salt'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 4'), findsOneWidget);
  });

  testWidgets('a Fold open shows two facing pages, and a turn moves two (rule 9)', (tester) async {
    final saves = MemorySaves();
    await pumpStories(tester, reader, stories: const [], comics: [ltr], saves: saves, size: const Size(984, 1092));
    expect(find.text('1 – 2 of 4'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('3 – 4 of 4'), findsOneWidget);
    expect(saves.kept.last, {'comicPage': 2});
  });

  test('spreads pair pages as a book opens, an odd last page alone', () {
    expect(comicSpreads(5), [(0, 1), (2, 3), (4, null)]);
    expect(pageOf(1, 2, 11), '2 – 3 of 11');
    expect(pageOf(2, null, 11), '3 of 11');
    expect(listedPages('Graphic novel · 11 pages'), 11);
  });

  testWidgets('not on the phone, its page opens with Get and its size (rule 3, call 35)', (tester) async {
    final listed = listedStoryWorld(const []);
    final withComic = CatalogueWorld(
      id: listed.id,
      name: listed.name,
      logline: listed.logline,
      keyArt: listed.keyArt,
      package: listed.package,
      productions: [
        ...listed.productions,
        CatalogueProduction(id: id, title: 'Low Water', kind: 'Graphic novel · 4 pages', comic: storyPin(id)),
      ],
    );
    await pumpStories(tester, page, stories: const [], listed: withComic);
    expect(find.text('Graphic novel · The Undersong · 4 pages'), findsOneWidget);
    expect(find.text('Get · 1.2 GB', findRichText: true), findsOneWidget, reason: 'a Get with its size, not a page that says Removed');
  });
}
