import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/widgets/shelf.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'world_widgets.dart';

/// Worlds (P11a), the second tab: the worlds In Library, then those Available, as cards whose meta
/// line counts productions and characters and, before install, the size. It takes the place of
/// P9b's Available page; first open's `Install a world` opens it.
class WorldsScreen extends ConsumerWidget {
  const WorldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(libraryWorldsProvider).value ?? const <LibraryWorld>[];
    final available = ref.watch(availableProvider);
    // Opening Worlds asks Arke's address for its list, at most once a day (P12 rule 1).
    ref.watch(catalogueRefreshProvider);
    final store = ref.watch(libraryStoreProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShelfHeader(title: 'Worlds'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (installed.isNotEmpty) ...[
                    const SectionHead('In Library'),
                    for (final world in installed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: switch (ref.watch(installProvider(ref.watch(worldUpdateProvider(world.id))?.id ?? world.id))) {
                          // A world updating shows it as an install does (P9 rule 4, P12 rule 4).
                          final Installing state => WorldCard(
                            name: world.name,
                            meta: state.short,
                            progress: state.fraction,
                            picture: libraryPicture(store, world.keyArt),
                            onOpen: () => context.push(Routes.worldsWorld(world.id)),
                          ),
                          _ => WorldCard(
                            name: world.name,
                            meta: [
                              'In Library',
                              productionCount(world.productions.length),
                              if (ref.watch(worldGuideProvider(world.id)).value?.guide.characters.length case final count? when count > 0)
                                characterCount(count),
                            ].join(' · '),
                            tag: ref.watch(worldUpdateProvider(world.id)) != null ? 'Update' : null,
                            picture: libraryPicture(store, world.keyArt),
                            onOpen: () => context.push(Routes.worldsWorld(world.id)),
                          ),
                        },
                      ),
                  ],
                  if (available.isNotEmpty) ...[
                    const SectionHead('Available'),
                    for (final world in available) AvailableCard(world: world, onOpen: () => context.push(Routes.worldsWorld(world.id))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A world to install as a card, showing its install while one runs (P9 rule 4). Its characters
/// count once its guide is on the phone (P11a).
class AvailableCard extends ConsumerWidget {
  const AvailableCard({required this.world, required this.onOpen, this.mini = false, super.key});

  final CatalogueWorld world;
  final VoidCallback onOpen;
  final bool mini;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(installProvider(world.id));
    final package = world.package;
    final card = WorldCard(
      name: world.name,
      meta: state is Installing
          ? state.short
          : [
              productionCount(world.productions.length),
              if (ref.watch(worldGuideProvider(world.id)).value?.guide.characters.length case final count? when count > 0) characterCount(count),
              if (package != null) formatBytes(package.byteLength),
            ].join(' · '),
      picture: bundledPicture(world.keyArt),
      progress: state is Installing ? state.fraction : null,
      mini: mini,
      onOpen: onOpen,
    );
    return mini ? card : Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: card);
  }
}
