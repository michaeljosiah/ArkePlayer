import 'package:arke_library/arke_library.dart';
import 'package:arke_player/features/add_file/domain/added_file.dart';
import 'package:arke_player/features/players/domain/player_kind.dart';
import 'package:arke_player/features/production/domain/production_kind.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryItem _item(FileFormat format, String title) =>
    LibraryItem(id: title, format: format, title: title, byteLength: 1000, addedAt: DateTime.utc(2026, 10, 20), file: 'items/$title/media');

void main() {
  group('a world groups its productions by what a person does (P1 rule 6, P15 rule 3)', () {
    test('in Listen, Watch, Play, Read order, with empty groups absent', () {
      final groups = groupByTakenAs([ProductionKind.audiobook, ProductionKind.film, ProductionKind.visualNovel, ProductionKind.microDrama], (kind) => kind);
      expect(groups.keys, [TakenAs.listen, TakenAs.watch, TakenAs.play]);
      expect(groups[TakenAs.watch], [ProductionKind.film, ProductionKind.microDrama]);
    });

    test('a list’s kind line names its kind first; one this build does not know is a book’s', () {
      expect(ProductionKind.ofLine('Audiobook · Book · 8 h 2 m'), ProductionKind.audiobook);
      expect(ProductionKind.ofLine('Micro drama · 45 episodes'), ProductionKind.microDrama);
      expect(ProductionKind.ofLine('Interactive movie · 14 scenes'), ProductionKind.interactiveMovie);
      expect(ProductionKind.ofLine('Hologram'), ProductionKind.book);
    });
  });

  group('each file opens in a player already drawn (P7 rule 2)', () {
    test('books, pages, audio and video', () {
      expect(playerForFile(FileFormat.epub), PlayerKind.reader);
      expect(playerForFile(FileFormat.pdf), PlayerKind.pageViewer);
      expect(playerForFile(FileFormat.m4b), PlayerKind.audiobook);
      expect(playerForFile(FileFormat.mov), PlayerKind.film);
    });
    test('a package becomes a world and captions ride beside their video', () {
      expect(playerForFile(FileFormat.arkePackage), isNull);
      expect(playerForFile(FileFormat.srt), isNull);
    });
  });

  group('the Add press counts only what will be added (P7 rule 3)', () {
    test('a refused file is left out, its clause one line', () {
      final candidates = [
        Readable('almanac.epub', _item(FileFormat.epub, 'The Salt Almanac')),
        Readable('boards.pdf', _item(FileFormat.pdf, 'Saltlight boards')),
        const Refused('dune-road.epub', Refused.protectedFile),
      ];
      expect(addLabel(candidates), 'Add 2');
      expect((candidates.last as Refused).clause, 'Protected file');
    });
    test('a file too large names both numbers', () {
      expect(Refused.needsSpace(4100000000, 2000000000), 'Needs 4.1 GB · 2 GB free');
    });
  });

  group('device settings (P6 rule 3, P8 rule 7)', () {
    test('defaults: captions off, speed 1.0, sleep off, the reader at its own size on paper', () {
      const settings = DeviceSettings();
      expect(settings.captions, isFalse);
      expect(settings.speed, 1.0);
      expect(settings.sleep, SleepTimer.off);
      expect(settings.readerScale, 1.0);
      expect(settings.readerPaper, ReaderPaper.paper);
      expect(settings.seenFirstOpen, isFalse);
    });
    test('what is saved comes back, and a bad value falls back', () {
      final saved = const DeviceSettings().copyWith(captions: true, speed: 1.5, sleep: SleepTimer.endOfChapter, readerPaper: ReaderPaper.night).toPrefs();
      final back = DeviceSettings.fromPrefs((key) => saved[key]);
      expect([back.captions, back.speed, back.sleep, back.readerPaper], [true, 1.5, SleepTimer.endOfChapter, ReaderPaper.night]);
      expect(DeviceSettings.fromPrefs((key) => key == 'speed' ? 9.0 : 'nonsense').speed, 2.0);
    });
    test('reduced motion always wins over slow push (Studio 211)', () {
      expect(const DeviceSettings().slowPushIn(reducedMotion: true), isFalse);
    });
  });
}
