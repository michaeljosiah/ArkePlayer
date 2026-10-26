import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../application/players.dart';
import 'audio_player_screen.dart';
import 'film_screen.dart';
import 'pdf_screen.dart';
import 'reader_screen.dart';

/// An added file in the player its format opens in (P7 rule 2).
class OpenItemScreen extends ConsumerWidget {
  const OpenItemScreen({required this.itemId, this.startAt, super.key});

  final String itemId;
  final Duration? startAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = ref.watch(openItemProvider(itemId));
    return opened.when(
      loading: () => const Scaffold(backgroundColor: ArkeColors.mediaOverlayBackground),
      error: (error, _) => const _Gone(),
      data: (found) {
        if (found == null) return const _Gone();
        final (:item, :store) = found;
        return switch (item.kind) {
          LibraryKind.listen => AudioPlayerScreen(item: item, store: store, startAt: startAt),
          LibraryKind.read when item.format == FileFormat.pdf => PdfScreen(item: item, store: store),
          LibraryKind.read => ReaderScreen(item: item, store: store),
          LibraryKind.watch => FilmScreen(item: item, store: store),
        };
      },
    );
  }
}

/// The item was removed while its link was open.
class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('Removed')),
  );
}
