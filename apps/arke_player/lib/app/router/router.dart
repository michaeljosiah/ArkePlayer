import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/onboarding/presentation/first_open_screen.dart';
import '../../features/players/presentation/open_item_screen.dart';
import '../../features/settings/presentation/you_screen.dart';
import '../shell/adaptive_shell.dart';
import 'routes.dart';

/// The tabs are one stateful shell, so each keeps its own place. Players sit outside it, over
/// the tabs.
GoRouter buildRouter({String initialLocation = Routes.home}) {
  final root = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.welcome, builder: (context, state) => const FirstOpenScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.library, builder: (context, state) => const LibraryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.downloads, builder: (context, state) => const DownloadsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.you, builder: (context, state) => const YouScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/open/:itemId',
        parentNavigatorKey: root,
        builder: (context, state) => OpenItemScreen(itemId: state.pathParameters['itemId']!),
      ),
    ],
  );
}

/// The router; main overrides it with the start the device calls for (first open, or Home).
final routerProvider = Provider<GoRouter>((ref) => buildRouter());
