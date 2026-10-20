import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/widgets/shelf.dart';
import '../application/worlds.dart';
import 'world_widgets.dart';

/// Available (P9b): the worlds a person can install, as cards with their count and size. Reached
/// from first open's `Install a world`, before the tabs exist.
class AvailableScreen extends ConsumerWidget {
  const AvailableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShelfHeader(
              title: 'Available',
              leading: context.canPop() ? RoundPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()) : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                children: [for (final world in available) AvailableCard(world: world, onOpen: () => context.push(Routes.welcomeWorld(world.id)))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A world to install as a card, showing its install while one runs (P9 rule 4).
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
      meta: state is Installing ? state.short : [productionCount(world.productions.length), if (package != null) formatBytes(package.byteLength)].join(' · '),
      picture: bundledPicture(world.keyArt),
      progress: state is Installing ? state.fraction : null,
      mini: mini,
      onOpen: onOpen,
    );
    return mini ? card : Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: card);
  }
}
