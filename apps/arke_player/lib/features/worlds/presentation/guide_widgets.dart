import 'dart:io';

import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../settings/application/settings_controller.dart';
import '../application/found.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'row_widgets.dart';
import 'world_widgets.dart';

/// The word a lore entry's kind shows as (P11f): Lore, Rule, Timeline, and canon's other types.
String loreKindLabel(LoreKind kind) => switch (kind) {
  LoreKind.lore => 'Lore',
  LoreKind.rule => 'Rule',
  LoreKind.timeline => 'Timeline',
  LoreKind.location => 'Location',
  LoreKind.faction => 'Faction',
  LoreKind.tone => 'Tone',
  LoreKind.thread => 'Thread',
};

/// `After Chapter 6`.
String afterLabel(GuideAfter after) => 'After Chapter ${after.number}';

/// What a place is: `Place`, or `Faction` for a faction, which the Studio files with the places
/// under that role.
String placeKind(GuidePlace place) => place.role == 'Faction' ? 'Faction' : 'Place';

/// The author's words as the guide carries them: plain text, paragraphs apart by a blank line, a
/// line break kept where a list puts its items one to a line. No markup is read from it.
class GuideText extends StatelessWidget {
  const GuideText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    final paragraphs = text.split(RegExp(r'\n\s*\n')).map((paragraph) => paragraph.trim()).where((paragraph) => paragraph.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, paragraph) in paragraphs.indexed) ...[if (i > 0) const SizedBox(height: 10), Text(paragraph, style: style)],
      ],
    );
  }
}

/// An entry's picture as a file, if it has one.
ImageProvider? guidePicture(WorldGuide guide, GuideEntry entry) => switch (guide.pictureOf(entry)) {
  final String path => FileImage(File(path)),
  null => null,
};

/// The initials a character with no portrait shows (P11 rule 4): `PT` for Perrin Tallow.
String initials(String name) {
  final words = name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty && word != 'The').toList();
  return words.take(2).map((word) => word.characters.first.toUpperCase()).join();
}

/// A section's head with its count at the end (P11 rule 4): `Characters · 5`. With [onOpen], the
/// head opens the whole list.
class CountHead extends StatelessWidget {
  const CountHead({required this.title, required this.count, this.onOpen, super.key});

  final String title;
  final int count;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.surface.mutedForeground;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: text.titleMedium)),
          ),
          Text(
            '$count',
            style: text.bodyMedium?.copyWith(color: muted, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          if (onOpen != null) Icon(Icons.chevron_right_rounded, size: 18, color: muted),
        ],
      ),
    );
    return onOpen == null ? row : InkWell(onTap: onOpen, child: row);
  }
}

/// A character among the characters (P11 rule 4): 120 wide, or 160 on a Fold, its portrait at
/// 4:5 or its initials, the name and role under it.
class CharacterCard extends StatelessWidget {
  const CharacterCard({required this.name, required this.width, required this.onOpen, this.role, this.picture, super.key});

  final String name;
  final String? role;
  final ImageProvider? picture;
  final double width;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return _Card(
      width: width,
      label: [name, ?role].join(', '),
      onOpen: onOpen,
      picture: picture != null
          ? Image(image: picture!, fit: BoxFit.cover, alignment: const Alignment(0, -0.6))
          : ColoredBox(
              color: surface.secondary,
              child: Center(
                child: Text(initials(name), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: surface.mutedForeground)),
              ),
            ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
      meta: role,
    );
  }
}

/// What waits for a chapter, among cards (P11 rule 7): no picture, the hidden mark, `After
/// Chapter 9`, and what it is.
class GatedCard extends StatelessWidget {
  const GatedCard({required this.after, required this.what, required this.width, required this.onReveal, this.aspectRatio = 4 / 5, super.key});

  final GuideAfter after;
  final String what;
  final double width;
  final double aspectRatio;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return _Card(
      width: width,
      aspectRatio: aspectRatio,
      label: '${afterLabel(after)}, $what',
      onOpen: onReveal,
      picture: ColoredBox(
        color: surface.secondary,
        child: Center(child: Icon(Icons.visibility_off_outlined, size: 26, color: surface.mutedForeground)),
      ),
      title: Text(
        afterLabel(after),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: surface.mutedForeground),
      ),
      meta: what,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.label,
    required this.onOpen,
    required this.picture,
    required this.title,
    this.meta,
    this.aspectRatio = 4 / 5,
  });

  final double width;
  final double aspectRatio;
  final String label;
  final VoidCallback onOpen;
  final Widget picture;
  final Widget title;
  final String? meta;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: ExcludeSemantics(
      child: GestureDetector(
        onTap: onOpen,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                // A 16:9 card sits in a row of tiles, so it takes their corner (P15 rule 10).
                borderRadius: BorderRadius.circular(aspectRatio > 1 ? ArkeRadius.lg : ArkeRadius.xl),
                child: AspectRatio(aspectRatio: aspectRatio, child: picture),
              ),
              const SizedBox(height: 8),
              title,
              if (meta != null)
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.surface.mutedForeground),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A row of cards that scrolls across, 12 apart.
class CardRow extends StatelessWidget {
  const CardRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(width: 12), child],
      ],
    ),
  );
}

/// A lore row (P11f): the kind over the title, and the way in.
class LoreRow extends StatelessWidget {
  const LoreRow({required this.lore, required this.onOpen, this.fresh = false, super.key});

  final GuideLore lore;
  final VoidCallback onOpen;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return _Ruled(
      child: Semantics(
        button: true,
        label: ['${loreKindLabel(lore.kind)}, ${lore.title}', if (fresh) 'New'].join(', '),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GuideLabel(loreKindLabel(lore.kind)),
                        const SizedBox(height: 1),
                        Text(
                          lore.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                        ),
                      ],
                    ),
                  ),
                  if (fresh) ...[const NewTag(), const SizedBox(width: 6)],
                  Icon(Icons.chevron_right_rounded, size: 18, color: surface.mutedForeground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What waits for a chapter, as a row (P11 rule 7): the hidden mark, `After Chapter 6`, Reveal.
class GateRow extends StatelessWidget {
  const GateRow({required this.after, required this.onReveal, super.key});

  final GuideAfter after;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return _Ruled(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, size: 20, color: surface.mutedForeground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                afterLabel(after),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: surface.mutedForeground),
              ),
            ),
            FilledButton(
              onPressed: onReveal,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                backgroundColor: surface.secondary,
                foregroundColor: surface.foreground,
                textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeSm, fontWeight: FontWeight.w600),
              ),
              child: const Text('Reveal'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline above, as the lists in P11 draw them.
class _Ruled extends StatelessWidget {
  const _Ruled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.surface.border)),
    ),
    child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 56), child: child),
  );
}

/// A small label in capitals: a lore entry's kind, a section's heading.
class GuideLabel extends StatelessWidget {
  const GuideLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.6, color: context.surface.mutedForeground),
  );
}

/// The author's sections, in their order and words (P11 rule 5), each section that waits for a
/// chapter a row in its place.
class GuideProse extends StatelessWidget {
  const GuideProse({required this.sections, required this.reach, required this.onReveal, super.key});

  final List<GuideSection> sections;
  final GuideReach reach;
  final ValueChanged<GuideAfter> onReveal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in sections)
          if (reach.shows(section.after))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [GuideLabel(section.heading), const SizedBox(height: 6), GuideText(section.text)],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GateRow(after: section.after!, onReveal: () => onReveal(section.after!)),
            ),
      ],
    );
  }
}

/// `With` and `Here` (P11d, P11e): the entries linked, each a chip opening its page.
class WithChips extends StatelessWidget {
  const WithChips({required this.guide, required this.entries, required this.onOpen, super.key});

  final WorldGuide guide;
  final List<GuideEntry> entries;
  final ValueChanged<GuideEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in entries)
            Semantics(
              button: true,
              label: entryName(entry),
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => onOpen(entry),
                  borderRadius: BorderRadius.circular(ArkeRadius.pill),
                  child: Container(
                    height: 36,
                    padding: EdgeInsets.fromLTRB(guidePicture(guide, entry) == null ? 15 : 6, 0, 15, 0),
                    decoration: BoxDecoration(color: surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.pill)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (guidePicture(guide, entry) case final picture?) ...[
                          ClipOval(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: Image(image: picture, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(entryName(entry), style: text.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An entry's name: a character's or a place's, a lore entry's title.
String entryName(GuideEntry entry) => switch (entry) {
  GuideCharacter(:final name) || GuidePlace(:final name) => name,
  GuideLore(:final title) => title,
};

/// Reveal, asked once (P11h): the chapter, the production and where this phone is in it, then
/// Reveal or Not now. Reveal shows everything in the production up to that chapter.
Future<void> askReveal(BuildContext context, WidgetRef ref, String worldId, WorldGuide guide, GuideReach reach, GuideAfter after) async {
  final production = guide.guide.productions.where((production) => production.id == after.production).firstOrNull;
  final at = reach.at(after.production);
  final line = [?production?.title, if (at != null) 'you are at Chapter $at'].join(' · ');
  final revealed = await showArkeSheet<bool>(
    context,
    title: null,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final surface = context.surface;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.visibility_off_outlined, size: 34, color: surface.mutedForeground),
            const SizedBox(height: 12),
            Text(afterLabel(after), textAlign: TextAlign.center, style: text.titleMedium),
            if (line.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                line,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: surface.mutedForeground),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
              child: const Text('Reveal'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: surface.foreground),
              child: const Text('Not now'),
            ),
          ],
        ),
      );
    },
  );
  if (revealed == true) await reveal(ref, worldId, after);
}

/// A world's People (P22j, P26k): upright portraits in a grid, three across on a phone, what waits for
/// a chapter after what shows, each with its chapter. A guide never fetched draws nothing (R-22).
class PeoplePanel extends ConsumerWidget {
  const PeoplePanel({required this.worldId, required this.location, super.key});

  final String worldId;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(worldGuideProvider(worldId)).value;
    if (guide == null) return const SizedBox.shrink();
    final reach = ref.watch(guideReachProvider(worldId)).value ?? GuideReach.none;
    final characters = guide.guide.characters;
    final opened = _openedIn(ref);
    bool fresh(GuideEntry entry) => isNewEntry(worldId, entry, reach, opened);
    final here = ref.watch(installedWorldProvider(worldId)) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (here && hasWaiting(guide.guide))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: FoundLine(found: foundIn(characters, reach), ink: context.surface.mutedForeground),
          ),
        LayoutBuilder(
          builder: (context, box) {
            // Five across from a Fold up, whatever room there is (P26 rules 7, 11).
            final width = MediaQuery.sizeOf(context).width >= WindowBands.fold ? ((box.maxWidth - 32 - 4 * 11) / 5).floorToDouble() : RowSizes.small(context);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Wrap(
                spacing: 11,
                runSpacing: 14,
                children: [
                  // New comes first (P23 rule 7), then the rest as the guide has them.
                  for (final character in [
                    ...characters.where((entry) => reach.shows(entry.after) && fresh(entry)),
                    ...characters.where((entry) => reach.shows(entry.after) && !fresh(entry)),
                  ])
                    PosterTile(
                      title: character.name,
                      kind: character.role ?? 'Character',
                      tall: guidePicture(guide, character),
                      initials: initials(character.name),
                      pictureAlignment: const Alignment(0, -0.6),
                      width: width,
                      fresh: fresh(character),
                      onOpen: () => context.push(Routes.guideEntry(location, character.id)),
                    ),
                  for (final character in characters.where((entry) => !reach.shows(entry.after)))
                    GatedCard(
                      after: character.after!,
                      what: 'Character',
                      width: width,
                      aspectRatio: 2 / 3,
                      onReveal: () => askReveal(context, ref, worldId, guide, reach, character.after!),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

Set<String> _openedIn(WidgetRef ref) => ref.watch(settingsProvider).value?.opened ?? const {};

/// `8 of 14 found` and its bar (P23f, P23g): a measure of the world, never a score (call 47).
class FoundLine extends StatelessWidget {
  const FoundLine({required this.found, required this.ink, this.top = 0, super.key});

  final ({int got, int of}) found;
  final Color ink;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Row(
      children: [
        Text(
          '${found.got} of ${found.of} found',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ink, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ArkeRadius.pill),
            child: LinearProgressIndicator(
              value: found.of == 0 ? 0 : found.got / found.of,
              minHeight: 3,
              color: ink,
              backgroundColor: ink.withValues(alpha: 0.2),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A world's Places (P22k, P26l): wide tiles, one across on a phone, two from a Fold up.
class PlacesPanel extends ConsumerWidget {
  const PlacesPanel({required this.worldId, required this.location, super.key});

  final String worldId;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(worldGuideProvider(worldId)).value;
    if (guide == null) return const SizedBox.shrink();
    final reach = ref.watch(guideReachProvider(worldId)).value ?? GuideReach.none;
    final places = guide.guide.places;
    return LayoutBuilder(
      builder: (context, box) {
        final across = MediaQuery.sizeOf(context).width >= WindowBands.fold ? 2 : 1;
        final width = (box.maxWidth - 32 - (across - 1) * 12) / across;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 14,
            children: [
              for (final place in places.where((entry) => reach.shows(entry.after)))
                ProductionTile(
                  title: place.name,
                  kind: placeKind(place),
                  picture: guidePicture(guide, place),
                  width: width,
                  fresh: isNewEntry(worldId, place, reach, _openedIn(ref)),
                  onOpen: () => context.push(Routes.guideEntry(location, place.id)),
                ),
              for (final place in places.where((entry) => !reach.shows(entry.after)))
                GatedCard(
                  after: place.after!,
                  what: placeKind(place),
                  width: width,
                  aspectRatio: 16 / 9,
                  onReveal: () => askReveal(context, ref, worldId, guide, reach, place.after!),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A world's Lore (P26m, as P11f): `All` and a chip for each kind present, then rows.
class LorePanel extends ConsumerStatefulWidget {
  const LorePanel({required this.worldId, required this.location, super.key});

  final String worldId;
  final String location;

  @override
  ConsumerState<LorePanel> createState() => _LorePanelState();
}

class _LorePanelState extends ConsumerState<LorePanel> {
  LoreKind? _kind;

  static const _chips = [(LoreKind.lore, 'Lore'), (LoreKind.rule, 'Rules'), (LoreKind.timeline, 'Timeline')];

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(worldGuideProvider(widget.worldId)).value;
    if (guide == null) return const SizedBox.shrink();
    final reach = ref.watch(guideReachProvider(widget.worldId)).value ?? GuideReach.none;
    final lore = guide.guide.lore;
    final kinds = [
      for (final chip in _chips)
        if (lore.any((entry) => entry.kind == chip.$1)) chip,
    ];
    final chosen = lore.where((entry) => _kind == null || entry.kind == _kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        if (kinds.isNotEmpty) LabelChips<LoreKind>(options: kinds, selected: _kind, onSelect: (kind) => setState(() => _kind = kind)),
        const SizedBox(height: 8),
        for (final entry in chosen.where((entry) => reach.shows(entry.after)))
          LoreRow(
            lore: entry,
            fresh: isNewEntry(widget.worldId, entry, reach, _openedIn(ref)),
            onOpen: () => context.push(Routes.guideEntry(widget.location, entry.id)),
          ),
        for (final entry in chosen.where((entry) => !reach.shows(entry.after)))
          GateRow(after: entry.after!, onReveal: () => askReveal(context, ref, widget.worldId, guide, reach, entry.after!)),
        const SizedBox(height: 24),
      ],
    );
  }
}
