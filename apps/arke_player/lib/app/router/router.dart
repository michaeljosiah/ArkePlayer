import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/add_file/presentation/add_screen.dart';
import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/onboarding/presentation/first_open_screen.dart';
import '../../features/players/presentation/open_file_screen.dart';
import '../../features/players/presentation/player_screen.dart';
import '../../features/production/presentation/production_screen.dart';
import '../../features/settings/presentation/you_screen.dart';
import '../../features/sharing/presentation/share_link_screen.dart';
import '../../features/world/presentation/world_screen.dart';
import '../shell/adaptive_shell.dart';
import 'routes.dart';

/// The tabs are one stateful shell, so each keeps its own stack (a world opened in Library stays
/// open while Home is visited). Players, the Add sheet and share links sit outside it, over the
/// tabs and the dock.
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
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'world/:worldId',
                    builder: (context, state) => WorldScreen(worldId: state.pathParameters['worldId']!),
                    routes: [
                      GoRoute(
                        path: 'production/:productionId',
                        builder: (context, state) =>
                            ProductionScreen(worldId: state.pathParameters['worldId']!, productionId: state.pathParameters['productionId']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
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
        path: Routes.add,
        parentNavigatorKey: root,
        pageBuilder: (context, state) => const MaterialPage(fullscreenDialog: true, child: AddScreen()),
      ),
      GoRoute(
        path: '/share/:token',
        parentNavigatorKey: root,
        builder: (context, state) => ShareLinkScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/play/:productionId',
        parentNavigatorKey: root,
        builder: (context, state) => PlayerScreen(productionId: state.pathParameters['productionId']!),
      ),
      GoRoute(
        path: '/open/:fileId',
        parentNavigatorKey: root,
        builder: (context, state) => OpenFileScreen(fileId: state.pathParameters['fileId']!),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) => buildRouter());
