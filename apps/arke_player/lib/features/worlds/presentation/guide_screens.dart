import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/guides.dart';
import 'guide_widgets.dart';
import 'world_widgets.dart';

/// `0:08`.
String _length(Duration duration) => '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

/// An entry of a world's guide, under the world's page it was opened from: a character (P11d), a
/// place (P11e) or a lore entry (P11g). One that waits for a chapter not reached shows its gate.
class GuideEntryScreen extends ConsumerWidget {
  const GuideEntryScreen({required this.worldId, required this.entryId, required this.worldLocation, super.key});

  final String worldId;
  final String entryId;

  /// The world page's own path, which every guide page is pushed under.
  final String worldLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(worldGuideProvider(worldId)).value;
    final reach = ref.watch(guideReachProvider(worldId)).value ?? GuideReach.none;
    final entry = guide?.guide.entry(entryId);
    if (guide == null || entry == null) return const Scaffold(body: _Bare(child: SizedBox.shrink()));
    if (!reach.shows(entry.after)) {
      return Scaffold(
        body: _Bare(
          child: Align(
            alignment: Alignment.topCenter,
            child: GateRow(after: entry.after!, onReveal: () => askReveal(context, ref, worldId, guide, reach, entry.after!)),
          ),
        ),
      );
    }
    final world = ref.watch(worldNameProvider(worldId));
    void open(GuideEntry other) => context.push(Routes.guideEntry(worldLocation, other.id));
    void ask(GuideAfter after) => askReveal(context, ref, worldId, guide, reach, after);
    // Only what shows is linked: a chip never opens a page that waits for a chapter.
    List<GuideEntry> linked(Iterable<String> ids) => [
      for (final other in [for (final id in ids) ?guide.guide.entry(id)])
        if (reach.shows(other.after) && other is! GuideLore) other,
    ];

    return Scaffold(
      body: switch (entry) {
        GuideCharacter() => ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            WorldHero(
              picture: guidePicture(guide, entry),
              pictureAlignment: const Alignment(0, -0.7),
              title: entry.name,
              meta: [?entry.role, ?world].join(' · '),
              child: switch (entry.voice) {
                final voice? => HeroSecondPress(
                  icon: Icons.volume_up_outlined,
                  label: 'Voice',
                  detail: _length(voice.duration),
                  onPressed: () => ref.read(voiceLineProvider)(guide.pathOf(voice.audio)),
                ),
                null => null,
              },
            ),
            GuideProse(sections: entry.sections, reach: reach, onReveal: ask),
            if (linked(entry.links) case final withs when withs.isNotEmpty) ...[
              const SectionHead('With'),
              WithChips(guide: guide, entries: withs, onOpen: open),
            ],
            const SizedBox(height: 24),
          ],
        ),
        GuidePlace() => ListView(
          padding: EdgeInsets.only(bottom: footRoom(context)),
          children: [
            WorldHero(picture: guidePicture(guide, entry), title: entry.name, meta: [placeKind(entry), ?world].join(' · ')),
            GuideProse(sections: entry.sections, reach: reach, onReveal: ask),
            // Here: the characters linked to the place, either way round.
            if ([
                  for (final character in guide.guide.characters)
                    if ((character.links.contains(entry.id) || entry.links.contains(character.id)) && reach.shows(character.after)) character,
                ]
                case final here when here.isNotEmpty) ...[
              const SectionHead('Here'),
              CardRow(
                children: [
                  for (final character in here)
                    CharacterCard(
                      name: character.name,
                      role: character.role,
                      picture: guidePicture(guide, character),
                      width: 96,
                      onOpen: () => open(character),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
        GuideLore() => _Bare(
          child: ListView(
            padding: EdgeInsets.only(bottom: 24 + footRoom(context)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuideLabel(loreKindLabel(entry.kind)),
                    const SizedBox(height: 6),
                    Semantics(header: true, child: Text(entry.title, style: Theme.of(context).textTheme.headlineLarge)),
                    const SizedBox(height: 14),
                    GuideText(entry.text),
                  ],
                ),
              ),
              if (linked(entry.links) case final withs when withs.isNotEmpty) ...[
                const SectionHead('With'),
                WithChips(guide: guide, entries: withs, onOpen: open),
              ],
            ],
          ),
        ),
      },
    );
  }
}

/// A guide page with no picture: back at the top, then its content (P11f, P11g).
class _Bare extends StatelessWidget {
  const _Bare({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfHeader(
          title: title ?? '',
          leading: context.canPop() ? RoundPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()) : null,
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// A world's lore (P11f): rows under `All · Lore · Rules · Timeline`, what waits for a chapter
/// after what shows. Canon's other types show under All.
class LoreScreen extends ConsumerStatefulWidget {
  const LoreScreen({required this.worldId, required this.worldLocation, super.key});

  final String worldId;
  final String worldLocation;

  @override
  ConsumerState<LoreScreen> createState() => _LoreScreenState();
}

class _LoreScreenState extends ConsumerState<LoreScreen> {
  LoreKind? _kind;

  static const _chips = [(LoreKind.lore, 'Lore'), (LoreKind.rule, 'Rules'), (LoreKind.timeline, 'Timeline')];

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(worldGuideProvider(widget.worldId)).value;
    final reach = ref.watch(guideReachProvider(widget.worldId)).value ?? GuideReach.none;
    final lore = guide?.guide.lore ?? const <GuideLore>[];
    final kinds = [
      for (final chip in _chips)
        if (lore.any((entry) => entry.kind == chip.$1)) chip,
    ];
    final chosen = lore.where((entry) => _kind == null || entry.kind == _kind);
    final shown = chosen.where((entry) => reach.shows(entry.after));
    final waiting = chosen.where((entry) => !reach.shows(entry.after));
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Scaffold(
      body: _Bare(
        title: 'Lore',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kinds.isNotEmpty) _Chips(chips: kinds, selected: _kind, onSelect: (kind) => setState(() => _kind = kind)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: 24 + footRoom(context)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 672 : double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in shown) LoreRow(lore: entry, onOpen: () => context.push(Routes.guideEntry(widget.worldLocation, entry.id))),
                          for (final entry in waiting)
                            GateRow(after: entry.after!, onReveal: () => askReveal(context, ref, widget.worldId, guide!, reach, entry.after!)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `All` and a chip for each kind present, as Library's chips draw them (P8 rule 4).
class _Chips extends StatelessWidget {
  const _Chips({required this.chips, required this.selected, required this.onSelect});

  final List<(LoreKind, String)> chips;
  final LoreKind? selected;
  final ValueChanged<LoreKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    Widget chip(String label, bool on, VoidCallback onTap) => Padding(
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Row(
        children: [chip('All', selected == null, () => onSelect(null)), for (final (kind, label) in chips) chip(label, selected == kind, () => onSelect(kind))],
      ),
    );
  }
}
