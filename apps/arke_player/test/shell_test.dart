import 'package:arke_player/app/router/router.dart';
import 'package:arke_player/app/router/routes.dart';
import 'package:arke_player/app/theme/arke_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpAt(WidgetTester tester, Size size, {String location = Routes.home}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: arkeTheme(Brightness.light),
      routerConfig: buildRouter(initialLocation: location),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a phone has the tabs as a bar (P1 rule 3)', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['Home', 'Library', 'Downloads', 'You']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('a Fold7 open has them as a rail (P6 rule 5)', (tester) async {
    await _pumpAt(tester, const Size(984, 1092));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a world opens inside Library and keeps the tabs', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.world('the-undersong'));
    expect(find.text('the-undersong'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a player covers the tabs', (tester) async {
    await _pumpAt(tester, const Size(390, 844), location: Routes.play('saltlight'));
    expect(find.text('saltlight'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
