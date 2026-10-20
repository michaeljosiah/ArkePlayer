import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';

/// The file's picture, if it has one.
File? coverOf(LibraryStore? store, LibraryItem item) => store == null || item.cover == null ? null : File(store.resolve(item.cover!));

/// Opens an item in its player.
void openItem(BuildContext context, LibraryItem item) => context.push(Routes.open(item.id));

/// ⋯ on a row: Details and Remove (P8 rule 4).
Future<void> showItemMenu(BuildContext context, WidgetRef ref, LibraryItem item) async {
  final choice = await showArkeSheet<String>(
    context,
    title: item.title,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () => Navigator.of(context).pop('details')),
        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove'), onTap: () => Navigator.of(context).pop('remove')),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'details') {
    await _details(context, item);
  } else if (choice == 'remove') {
    await _remove(context, ref, item);
  }
}

Future<void> _details(BuildContext context, LibraryItem item) => showArkeSheet<void>(
  context,
  title: 'Details',
  builder: (context) {
    final text = Theme.of(context).textTheme;
    final muted = context.surface.mutedForeground;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: text.bodyMedium?.copyWith(color: muted)),
          ),
          Expanded(child: Text(value, style: text.bodyLarge)),
        ],
      ),
    );
    final added = item.addedAt.toLocal();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row('Title', item.title),
        if (item.author != null) row('Author', item.author!),
        row('Format', item.format.label),
        if (item.duration != null) row('Length', formatLength(item.duration!)),
        if (item.pages != null) row('Pages', '${item.pages}'),
        if (item.chapters.length > 1) row('Chapters', '${item.chapters.length}'),
        if (item.captions != null) row('Captions', 'Yes'),
        row('Size', formatBytes(item.byteLength)),
        row('Added', '${added.day} ${_months[added.month - 1]} ${added.year}'),
      ],
    );
  },
);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Remove deletes the Player's copy and its place (acceptance 8). The fact, then the press.
Future<void> _remove(BuildContext context, WidgetRef ref, LibraryItem item) async {
  final confirmed = await showArkeSheet<bool>(
    context,
    title: null,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Remove ${item.title}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            formatBytes(item.byteLength),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.surface.mutedForeground),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), backgroundColor: context.surface.destructive),
            child: const Text('Remove'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: context.surface.foreground),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  final store = await ref.read(libraryStoreProvider.future);
  await store.remove(item.id);
}
