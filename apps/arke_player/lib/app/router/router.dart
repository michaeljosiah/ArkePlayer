import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/comics/presentation/comic_reader_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/players/presentation/music_player_screen.dart';
import '../../features/players/presentation/open_item_screen.dart';
import '../../features/settings/presentation/you_screen.dart';
import '../../features/stories/presentation/story_player_screen.dart';
import '../../features/worlds/presentation/adult_gate.dart';
import '../../features/worlds/presentation/guide_screens.dart';
import '../../features/worlds/presentation/production_screen.dart';
import '../../features/worlds/presentation/search_screen.dart';
import '../../features/worlds/presentation/world_screen.dart';
import '../../features/worlds/presentation/worlds_screen.dart';
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen(), routes: [_worldRoute()]),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.worlds,
                builder: (context, state) => WorldsScreen(genre: state.uri.queryParameters['genre']),
                routes: [
                  GoRoute(path: 'search', builder: (context, state) => const SearchScreen()),
                  _worldRoute(),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (context, state) => LibraryScreen(show: state.uri.queryParameters['show']),
                routes: [_worldRoute()],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.you, builder: (context, state) => const YouScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/open/:itemId',
        parentNavigatorKey: root,
        builder: (context, state) {
          final at = int.tryParse(state.uri.queryParameters['at'] ?? '');
          final itemId = state.pathParameters['itemId']!;
          return AdultGate(
            itemId: itemId,
            child: OpenItemScreen(
              itemId: itemId,
              startAt: at == null || at < 0 ? null : Duration(milliseconds: at),
            ),
          );
        },
      ),
      GoRoute(
        path: '/music/:worldId/:productionId',
        parentNavigatorKey: root,
        builder: (context, state) => AdultGate(
          worldId: state.pathParameters['worldId'],
          child: MusicPlayerScreen(
            worldId: state.pathParameters['worldId']!,
            productionId: state.pathParameters['productionId']!,
            track: int.tryParse(state.uri.queryParameters['track'] ?? ''),
            shuffle: state.uri.queryParameters['shuffle'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/story/:worldId/:productionId',
        parentNavigatorKey: root,
        builder: (context, state) => AdultGate(
          worldId: state.pathParameters['worldId'],
          child: StoryPlayerScreen(worldId: state.pathParameters['worldId']!, productionId: state.pathParameters['productionId']!),
        ),
      ),
      GoRoute(
        path: '/comic/:worldId/:productionId',
        parentNavigatorKey: root,
        builder: (context, state) => AdultGate(
          worldId: state.pathParameters['worldId'],
          press: 'Read',
          child: ComicReaderScreen(worldId: state.pathParameters['worldId']!, productionId: state.pathParameters['productionId']!),
        ),
      ),
    ],
  );
}

/// A world's page, its guide's pages and its productions, under the tab it was opened from. The
/// guide's routes come first, so `_guide` is never read as a production.
GoRoute _worldRoute() => GoRoute(
  path: 'world/:worldId',
  builder: (context, state) => WorldScreen(worldId: state.pathParameters['worldId']!, location: state.uri.path),
  routes: [
    GoRoute(
      path: '_guide',
      builder: (context, state) => LoreScreen(worldId: state.pathParameters['worldId']!, worldLocation: _worldOf(state.uri.path)),
      routes: [
        GoRoute(
          path: ':entryId',
          builder: (context, state) =>
              GuideEntryScreen(worldId: state.pathParameters['worldId']!, entryId: state.pathParameters['entryId']!, worldLocation: _worldOf(state.uri.path)),
        ),
      ],
    ),
    GoRoute(
      path: ':productionId',
      builder: (context, state) => ProductionScreen(
        worldId: state.pathParameters['worldId']!,
        productionId: state.pathParameters['productionId']!,
        worldLocation: _parentOf(state.uri.path),
      ),
    ),
  ],
);

/// The world page's own path, from a guide page's.
String _worldOf(String path) => path.substring(0, path.indexOf('/_guide'));

/// The world page's own path, from a production's.
String _parentOf(String path) => path.substring(0, path.lastIndexOf('/'));

/// The router; main overrides it with the one a notification can open a page on.
final routerProvider = Provider<GoRouter>((ref) => buildRouter());
