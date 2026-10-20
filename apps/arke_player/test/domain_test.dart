import 'package:arke_player/features/add_file/domain/added_file.dart';
import 'package:arke_player/features/players/domain/player_kind.dart';
import 'package:arke_player/features/production/domain/production_kind.dart';
import 'package:arke_player/features/settings/domain/device_settings.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a world groups its productions by what a person does (P1 rule 6)', () {
    test('in Watch, Play, Listen, Read order, with empty groups absent', () {
      final groups = groupByTakenAs([ProductionKind.audiobook, ProductionKind.film, ProductionKind.visualNovel, ProductionKind.microDrama], (kind) => kind);
      expect(groups.keys, [TakenAs.watch, TakenAs.play, TakenAs.listen]);
      expect(groups[TakenAs.watch], [ProductionKind.film, ProductionKind.microDrama]);
    });
  });

  group('each file opens in a player already drawn (P7 rule 2)', () {
    test('books, pages, audio and video', () {
      expect(playerForFile(FileFormat.epub), PlayerKind.reader);
      expect(playerForFile(FileFormat.pdf), PlayerKind.pageViewer);
      expect(playerForFile(FileFormat.cbz), PlayerKind.pageViewer);
      expect(playerForFile(FileFormat.m4b), PlayerKind.audiobook);
      expect(playerForFile(FileFormat.mov), PlayerKind.film);
    });
    test('a package becomes a world and captions ride beside their video', () {
      expect(playerForFile(FileFormat.arkePackage), isNull);
      expect(playerForFile(FileFormat.srt), isNull);
    });
  });

  group('the Add press counts only what will be added (P7 rule 3)', () {
    test('a refused file is left out', () {
      const candidates = [
        Readable('almanac.epub', format: FileFormat.epub, title: 'The Salt Almanac', byteLength: 2100000),
        Readable('boards.pdf', format: FileFormat.pdf, title: 'Saltlight boards', byteLength: 18000000),
        Refused('dune-road.epub', ProbeRefusal.protectedFile),
      ];
      expect(addLabel(candidates), 'Add 2');
      expect((candidates.last as Refused).clause, 'Protected file');
    });
  });

  group('device settings (P6 rule 3)', () {
    test('defaults: slow push, autoplay and Wi-Fi only on; text and adult content off', () {
      const settings = DeviceSettings();
      expect([settings.slowPush, settings.autoplayNext, settings.wifiOnly], everyElement(isTrue));
      expect([settings.text, settings.adultContent], everyElement(isFalse));
      expect(settings.captionsLanguage, isNull);
    });
    test('reduced motion always wins over slow push (Studio 211)', () {
      expect(const DeviceSettings().slowPushIn(reducedMotion: true), isFalse);
    });
  });
}
