import 'dart:async';
import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/services.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:arke_player/features/worlds/application/worlds.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Catalogue _list(String fingerprint) => Catalogue(
  serial: fingerprint == 'old' ? 100 : 101,
  worlds: [
    CatalogueWorld(
      id: 'undersong',
      name: 'The Undersong',
      productions: const [],
      package: CataloguePackage(
        url: Uri.parse('https://example.org/world.zip'),
        byteLength: 10,
        sha256: 'a' * 64,
        edition: fingerprint,
        fingerprint: fingerprint,
      ),
    ),
  ],
);

final _installed = LibraryWorld(
  id: 'undersong',
  edition: 'old',
  fingerprint: 'old',
  name: 'The Undersong',
  byteLength: 10,
  installedAt: DateTime.utc(2026),
  productions: const [],
);

class _Hosted extends HostedCatalogue {
  _Hosted() : super(url: Uri.parse('https://example.org/catalogue.json'), kept: File('unused'));
  Catalogue list = _list('old');
  Completer<Catalogue?>? pending;
  bool fail = false;
  final calls = <bool>[];
  @override
  Future<Catalogue?> keptList() async => list;
  @override
  Future<Catalogue?> refresh({bool force = false}) async {
    calls.add(force);
    if (fail) throw const SocketException('offline');
    list = (await pending?.future) ?? _list('new');
    return list;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Hosted hosted, {
  Size size = const Size(390, 844),
  double scale = 1,
  Brightness brightness = Brightness.light,
  Future<void>? automatic,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hostedCatalogueProvider.overrideWith((ref) async => hosted),
        catalogueProvider.overrideWith((ref) async => hosted.list.worlds),
        if (automatic != null) catalogueRefreshProvider.overrideWith((ref) => automatic),
        libraryItemsProvider.overrideWith((ref) => Stream.value(const <LibraryItem>[])),
        libraryWorldsProvider.overrideWith((ref) => Stream.value([_installed])),
      ],
      child: MaterialApp.router(
        theme: arkeTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: buildRouter(initialLocation: Routes.worlds),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the real catalogue provider publishes a forced refresh in the same container', () async {
    final hosted = _Hosted();
    final container = ProviderContainer(
      overrides: [hostedCatalogueProvider.overrideWith((ref) async => hosted), catalogueRefreshProvider.overrideWith((ref) async {})],
    );
    addTearDown(container.dispose);
    expect((await container.read(catalogueProvider.future)).single.package!.fingerprint, 'old');
    await container.read(catalogueCheckProvider.notifier).check();
    expect(container.read(catalogueCheckProvider), CatalogueCheck.checked);
    expect((await container.read(catalogueProvider.future)).single.package!.fingerprint, 'new');
  });

  testWidgets('manual check updates cards without restart, disables repeats and re-enables', (tester) async {
    final hosted = _Hosted()..pending = Completer<Catalogue?>();
    await _pump(tester, hosted);
    expect(find.text('Update'), findsNothing);
    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pump();
    expect(find.text('Checking for updates'), findsOneWidget);
    final button = tester.widget<IconButton>(find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Check for updates'));
    expect(button.onPressed, isNull);
    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pump();
    expect(hosted.calls, [true]);
    hosted.pending!.complete(_list('new'));
    await tester.pumpAndSettle();
    expect(find.text('Checked'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Check for updates')).onPressed, isNotNull);
  });

  testWidgets('failure keeps worlds visible and retries immediately', (tester) async {
    final hosted = _Hosted()..fail = true;
    await _pump(tester, hosted);
    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t check for updates'), findsOneWidget);
    expect(find.text('The Undersong'), findsOneWidget);
    expect(find.text('Checked'), findsNothing);
    hosted.fail = false;
    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pumpAndSettle();
    expect(hosted.calls, [true, true]);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('manual check waits for startup and survives navigation', (tester) async {
    final automatic = Completer<void>();
    final hosted = _Hosted()..pending = Completer<Catalogue?>();
    await _pump(tester, hosted, automatic: automatic.future);
    await tester.tap(find.byTooltip('Check for updates'));
    await tester.pump();
    expect(hosted.calls, isEmpty);
    automatic.complete();
    await tester.pump();
    expect(hosted.calls, [true]);
    await tester.tap(find.text('Home').last);
    await tester.pump();
    hosted.pending!.complete(_list('new'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worlds').last);
    await tester.pumpAndSettle();
    expect(find.text('Checked'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('keyboard can activate the check', (tester) async {
    final hosted = _Hosted();
    await _pump(tester, hosted);
    final buttonContext = tester.element(find.byTooltip('Check for updates'));
    Focus.of(tester.element(find.byIcon(Icons.refresh))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(buttonContext.mounted, isTrue);
    expect(hosted.calls, [true]);
  });

  for (final size in [const Size(390, 844), const Size(984, 1092), const Size(1440, 900)]) {
    for (final brightness in Brightness.values) {
      testWidgets('P13 refresh reachable at 200% text, $size $brightness', (tester) async {
        final hosted = _Hosted()..fail = true;
        await _pump(tester, hosted, size: size, scale: 2, brightness: brightness);
        final control = find.byTooltip('Check for updates');
        expect(tester.getSize(control).width, greaterThanOrEqualTo(44));
        expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(find.text('Couldn’t check for updates'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(control).right, lessThanOrEqualTo(size.width));
      });
    }
  }
}
