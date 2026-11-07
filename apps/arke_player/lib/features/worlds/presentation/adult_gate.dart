import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../settings/application/settings_controller.dart';
import '../application/worlds.dart';
import 'world_shelf.dart';

/// The door to every player (P22 rule 9, call 42). A world's press asks before it opens anything, but a
/// title is also reached from its own page, a chapter's row, a kept place and a notification, and asking
/// at each of those is how one gets missed. So the route asks: the player is not built, and nothing plays,
/// until the question is answered. Not now goes back to where it came from.
class AdultGate extends ConsumerStatefulWidget {
  const AdultGate({required this.child, this.worldId, this.itemId, this.press = 'Play', super.key});

  final Widget child;

  /// The world a story, comic or album belongs to.
  final String? worldId;

  /// A chapter or a book, whose world is on its item. One from a file has none, and no list says its age.
  final String? itemId;
  final String press;

  @override
  ConsumerState<AdultGate> createState() => _AdultGateState();
}

class _AdultGateState extends ConsumerState<AdultGate> {
  bool _open = false;
  bool _asked = false;

  Future<void> _ask(CatalogueWorld world, String press) async {
    final allowed = await mayOpen(context, ref, world, press: press);
    if (!mounted) return;
    if (allowed) {
      setState(() => _open = true);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_open) return widget.child;
    // Watched, not read: Riverpod pauses a provider nothing listens to, and a read of its future then
    // never answers, which held a player black when the app was opened straight at it.
    final settings = ref.watch(settingsProvider);
    final catalogue = ref.watch(catalogueProvider);
    final items = widget.itemId == null ? null : ref.watch(libraryItemsProvider);
    bool settled(AsyncValue<Object?>? value) => value == null || value.hasValue || value.hasError;
    if (!settled(settings) || !settled(catalogue) || !settled(items)) return const ColoredBox(color: ArkeColors.mediaOverlayBackground);

    final item = items?.value?.where((item) => item.id == widget.itemId).firstOrNull;
    final worldId = widget.worldId ?? item?.worldId;
    // A list that cannot be read names no age, so it cannot be the reason a title on the phone stops opening.
    final listed = worldId == null ? null : listedFor(catalogue.value ?? const [], worldId);
    if (settings.value?.adultContent == true || listed == null || !listed.adult) {
      _open = true;
      return widget.child;
    }
    if (!_asked) {
      _asked = true;
      final press = item?.kind == LibraryKind.read ? 'Read' : widget.press;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ask(listed, press);
      });
    }
    return const ColoredBox(color: ArkeColors.mediaOverlayBackground);
  }
}
