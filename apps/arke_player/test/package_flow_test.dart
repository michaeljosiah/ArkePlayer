import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/add_file/domain/added_file.dart';
import 'package:arke_player/features/add_file/presentation/package_flow.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryWorld _world(String edition, String fingerprint, int bytes) => LibraryWorld(
  id: 'undersong',
  edition: edition,
  name: 'The Undersong',
  byteLength: bytes,
  installedAt: DateTime.utc(2026, 10, 20),
  fingerprint: fingerprint,
  productions: const [LibraryProduction(id: 'ledger-of-nights', title: 'The Ledger of Nights', narration: 'undersong.ledger-of-nights.listening')],
);

PreparedWorld _prepared({LibraryWorld? installed}) => PreparedWorld(
  manifest: const WorldManifest(
    id: 'undersong',
    edition: '2026-10-21',
    name: 'The Undersong',
    productions: [WorldProduction(id: 'ledger-of-nights', title: 'The Ledger of Nights', listening: 'listening')],
    assets: {},
  ),
  world: _world('2026-10-21', 'b', 228000000),
  items: [
    LibraryItem(
      id: 'undersong.ledger-of-nights.listening',
      format: FileFormat.listening,
      title: 'The Ledger of Nights',
      byteLength: 1,
      addedAt: DateTime.utc(2026, 10, 21),
      file: 'worlds/undersong/listening.json',
      duration: const Duration(hours: 3, minutes: 49),
      worldId: 'undersong',
    ),
  ],
  content: Directory.systemTemp,
  staging: Directory.systemTemp,
  installed: installed,
);

/// Reports a copy and a check, then answers with [result] or throws [refusal].
class _FakeInstaller extends WorldInstaller {
  _FakeInstaller({this.result, this.refusal}) : super(store: LibraryStore(Directory.systemTemp), freeBytes: (_) async => null);

  final PreparedWorld? result;
  final InstallRefusal? refusal;
  bool discarded = false;

  @override
  Future<PreparedWorld> prepareFile({
    required int size,
    required Stream<List<int>> Function() open,
    void Function(InstallStep step)? onStep,
    InstallCancel? cancel,
  }) async {
    onStep?.call(Copying(size, size));
    onStep?.call(const Checking(4, 4));
    if (refusal != null) throw refusal!;
    return result!;
  }

  @override
  Future<void> discard(PreparedWorld prepared) async => discarded = true;
}

final _file = PickedFile(name: 'the-undersong-player-2026-10-21.zip', size: 228000000, open: () => const Stream.empty());

Future<void> _start(WidgetTester tester, _FakeInstaller installer) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        worldInstallerProvider.overrideWith((ref) async => installer),
        volumeProvider.overrideWith((ref) async => (free: 41000000000, total: 128000000000)),
      ],
      child: MaterialApp(
        theme: arkeTheme(Brightness.light),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => unawaited(addPackage(context, ref, _file)), child: const Text('Add')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

void main() {
  test('an edition reads as data: a dated label as made 21 Oct 2026, anything else as itself', () {
    expect(editionLine('2026-10-21'), 'made 21 Oct 2026');
    expect(editionLine('2026-10-20', made: false), '20 Oct 2026');
    expect(editionLine('Second printing'), 'Second printing');
  });

  testWidgets('a new world: Ready, with Inside, Space and Add to library (P2e)', (tester) async {
    await _start(tester, _FakeInstaller(result: _prepared()));
    expect(find.text('PACKAGE'), findsOneWidget);
    expect(find.text('made 21 Oct 2026 · 1 production · 228 MB'), findsOneWidget);
    expect(find.text('Inside'), findsOneWidget);
    expect(find.text('Audiobook · 3 h 49 m'), findsOneWidget);
    expect(find.text('228 MB of 41 GB free'), findsOneWidget);
    expect(find.text('Add to library'), findsOneWidget);
    expect(find.text('Replace'), findsNothing);
  });

  testWidgets('another edition of a world in Library: Replace, with In Library and the difference (P10a)', (tester) async {
    final installer = _FakeInstaller(result: _prepared(installed: _world('2026-10-20', 'a', 182000000)));
    await _start(tester, installer);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('In Library'), findsOneWidget);
    expect(find.text('20 Oct 2026 · 182 MB'), findsOneWidget);
    expect(find.text('+46 MB of 41 GB free'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(installer.discarded, isTrue);
  });

  testWidgets('the same edition: Already in Library, and the copy is deleted (P10b)', (tester) async {
    final installer = _FakeInstaller(result: _prepared(installed: _world('2026-10-21', 'b', 228000000)));
    await _start(tester, installer);
    expect(find.text('Already in Library'), findsOneWidget);
    expect(find.text('The Undersong · 21 Oct 2026'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(installer.discarded, isTrue);
  });

  testWidgets('a refused package: one clause, the file and its size, Choose another file (P2f)', (tester) async {
    await _start(tester, _FakeInstaller(refusal: const FilesDoNotMatch(3)));
    expect(find.text('3 files do not match'), findsOneWidget);
    expect(find.text('the-undersong-player-2026-10-21.zip · 228 MB'), findsOneWidget);
    expect(find.text('Choose another file'), findsOneWidget);
  });
}
