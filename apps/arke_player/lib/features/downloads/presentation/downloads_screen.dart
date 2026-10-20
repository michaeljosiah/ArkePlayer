import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import '../../library/presentation/item_menu.dart';

/// What is on the phone (P6a, before an account): the space Arke Player takes against the rest and
/// what is free, then everything added, largest first, each with ⋯ to remove it.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final volume = ref.watch(volumeProvider).value;
    final used = bytesUsed(items);
    final rows = [...items]..sort((a, b) => b.byteLength.compareTo(a.byteLength));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShelfHeader(title: 'Downloads'),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SpaceBar(used: used, free: volume?.free, total: volume?.total),
            ),
          Expanded(
            child: items.isEmpty
                ? EmptyShelf(onAdd: () => addFiles(context, ref))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const SectionHead('Added'),
                      for (final item in rows)
                        FileRow(item: item, cover: coverOf(store, item), onOpen: () => openItem(context, item), onMore: () => showItemMenu(context, ref, item)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Arke Player's share of the volume, the rest, and what is free (P6a).
class _SpaceBar extends StatelessWidget {
  const _SpaceBar({required this.used, required this.free, required this.total});

  final int used;
  final int? free;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final text = Theme.of(context).textTheme.labelSmall?.copyWith(color: surface.mutedForeground);
    final whole = total ?? (used + (free ?? 0));
    final other = whole - used - (free ?? 0);
    int flex(int bytes) => whole <= 0 ? 0 : (bytes / whole * 1000).round().clamp(bytes > 0 ? 6 : 0, 1000);
    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: text),
      ],
    );
    final otherColor = surface.foreground.withValues(alpha: 0.24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: flex(used),
                  child: ColoredBox(color: surface.foreground),
                ),
                if (other > 0)
                  Expanded(
                    flex: flex(other),
                    child: ColoredBox(color: otherColor),
                  ),
                Expanded(
                  flex: flex(free ?? 0),
                  child: ColoredBox(color: surface.secondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            legend(surface.foreground, 'Arke Player ${formatBytes(used)}'),
            if (other > 0) legend(otherColor, 'Other ${formatBytes(other)}'),
            if (free != null) legend(surface.secondary, '${formatBytes(free!)} free'),
          ],
        ),
      ],
    );
  }
}
