import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The theme's semantic colours, light or dark.
extension ArkeColorsOf on BuildContext {
  ArkeSurface get surface => Theme.of(this).brightness == Brightness.dark ? ArkeSurface.dark : ArkeSurface.light;
}

/// A shelf's large title, with what sits at its end (P1 rule 3; P8b–P8f).
class ShelfHeader extends StatelessWidget {
  const ShelfHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineLarge)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A round 40 press on a shelf, e.g. Library's `+`.
class RoundPress extends StatelessWidget {
  const RoundPress({required this.icon, required this.label, required this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    onPressed: onPressed,
    tooltip: label,
    style: IconButton.styleFrom(minimumSize: const Size(44, 44), backgroundColor: context.surface.secondary, foregroundColor: context.surface.foreground),
    icon: Icon(icon, size: 22),
  );
}

/// A section's head on a shelf: Continue, Added (P8d).
class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
    child: Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
  );
}

/// What a person does — `All · Listen · Read · Watch` — shown only when two or more kinds are
/// present (P8 rule 4).
class KindChips extends StatelessWidget {
  const KindChips({required this.kinds, required this.selected, required this.onSelect, super.key});

  final List<LibraryKind> kinds;
  final LibraryKind? selected;
  final ValueChanged<LibraryKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool on, VoidCallback onTap) {
      final surface = context.surface;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ArkeRadius.pill),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? surface.foreground : surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.pill)),
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: on ? surface.background : surface.foreground)),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Row(
        children: [chip('All', selected == null, () => onSelect(null)), for (final kind in kinds) chip(kind.label, selected == kind, () => onSelect(kind))],
      ),
    );
  }
}

/// A shelf with nothing on it: one state line over `Add a file` (P8 rule 3).
class EmptyShelf extends StatelessWidget {
  const EmptyShelf({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Nothing added', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.surface.mutedForeground)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add a file'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 18)),
        ),
      ],
    ),
  );
}

/// A file's picture: its cover or first page, else its format on a plain tile.
class FileThumb extends StatelessWidget {
  const FileThumb({required this.item, required this.cover, required this.width, required this.height, this.radius = 8, super.key});

  final LibraryItem item;
  final File? cover;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: cover != null
            ? Image.file(
                cover!,
                fit: BoxFit.cover,
                alignment: item.format.name == 'pdf' ? Alignment.topCenter : Alignment.center,
                cacheWidth: (width * 3).round(),
              )
            : ColoredBox(
                color: surface.secondary,
                child: Center(
                  child: Text(item.format.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: surface.mutedForeground, letterSpacing: 0.55)),
                ),
              ),
      ),
    );
  }
}

/// A library row (P7b, P8c): the picture at 52, the title, the data line, and ⋯.
class FileRow extends StatelessWidget {
  const FileRow({required this.item, required this.cover, required this.onOpen, required this.onMore, super.key});

  final LibraryItem item;
  final File? cover;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            FileThumb(item: item, cover: cover, width: 52, height: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rowLine(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: context.surface.mutedForeground),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onMore,
              tooltip: 'More',
              icon: Icon(Icons.more_horiz, color: context.surface.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Continue card (P1 rule 4, P8d): the picture, the kind, the title, where you are, a line of
/// progress, and the round press that resumes.
class ContinueCard extends StatelessWidget {
  const ContinueCard({required this.item, required this.cover, required this.onOpen, this.width = 300, super.key});

  final LibraryItem item;
  final File? cover;
  final VoidCallback onOpen;
  final double width;

  static String kindWord(LibraryItem item) => switch (item.kind) {
    LibraryKind.listen => item.chapters.length > 1 ? 'Audiobook' : 'Audio',
    LibraryKind.read => item.format.label == 'PDF' ? 'Document' : 'Book',
    LibraryKind.watch => 'Film',
  };

  @override
  Widget build(BuildContext context) {
    const fg = ArkeColors.mediaOverlayForeground;
    final height = width * 9 / 16;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${item.title}, ${whereLine(item)}',
      child: GestureDetector(
        onTap: onOpen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ArkeRadius.xl),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null) Image.file(cover!, fit: BoxFit.cover, cacheWidth: (width * 3).round()) else const ColoredBox(color: ArkeColors.neutral800),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE00A0A0A), Color(0x4D0A0A0A), Color(0x000A0A0A)],
                      stops: [0.06, 0.52, 0.74],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: fg, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: ArkeColors.mediaOverlayBackground, size: 22),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kindWord(item).toUpperCase(),
                        style: text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.72), letterSpacing: 0.55, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(color: fg),
                      ),
                      Text(whereLine(item), style: text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 3,
                  child: LinearProgressIndicator(value: item.place?.progress ?? 0, backgroundColor: fg.withValues(alpha: 0.26), color: fg, minHeight: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An Added square (P8d): 120, with the title and the format under it.
class AddedSquare extends StatelessWidget {
  const AddedSquare({required this.item, required this.cover, required this.onOpen, super.key});

  final LibraryItem item;
  final File? cover;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(ArkeRadius.lg),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FileThumb(item: item, cover: cover, width: 120, height: 120, radius: 12),
            const SizedBox(height: 7),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
            Text(
              tileLine(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: context.surface.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet from the foot on the theme: the grip, a title with its close, then its content.
Future<T?> showArkeSheet<T>(BuildContext context, {required String? title, required WidgetBuilder builder, bool scrollable = false}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: scrollable,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(onPressed: () => Navigator.of(context).pop(), tooltip: 'Close', icon: const Icon(Icons.close, size: 18)),
              ],
            ),
          ),
        Flexible(child: builder(context)),
      ],
    ),
  ),
);
