import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../add_file/presentation/add_flow.dart';
import '../../library/presentation/item_menu.dart';

/// Home before an account (P8b, P8d): Continue, then Added; with nothing added, the state line
/// and Add a file. No picture in the head: there is no account to show (P8 rule 1).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).value ?? const [];
    final store = ref.watch(libraryStoreProvider).value;
    final going = continueShelf(items);
    final added = addedShelf(items);
    final cardWidth = MediaQuery.sizeOf(context).width >= WindowBands.fold ? 420.0 : 300.0;
    // The Added row is as tall as a square and its two lines at the reader's text size (acceptance 9).
    final scaler = MediaQuery.textScalerOf(context);
    final addedHeight = 120 + 7 + scaler.scale(ArkeType.sizeSm) * 1.4 + scaler.scale(ArkeType.size2xs) * 1.4 + 6;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShelfHeader(title: 'Home'),
          Expanded(
            child: items.isEmpty
                ? EmptyShelf(onAdd: () => addFiles(context, ref))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (going.isNotEmpty) ...[
                        const SectionHead('Continue'),
                        SizedBox(
                          height: cardWidth * 9 / 16,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: going.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) => ContinueCard(
                              item: going[index],
                              cover: coverOf(store, going[index]),
                              width: cardWidth,
                              onOpen: () => openItem(context, going[index]),
                            ),
                          ),
                        ),
                      ],
                      const SectionHead('Added'),
                      SizedBox(
                        height: addedHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: added.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) =>
                              AddedSquare(item: added[index], cover: coverOf(store, added[index]), onOpen: () => openItem(context, added[index])),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
