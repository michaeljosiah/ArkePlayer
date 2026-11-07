import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// Someone new (P23e, P23 rule 5): when the chapter playing brings an entry out of waiting, one card comes
/// over the player for five seconds. It never pauses what plays. A press opens the entry, and the chapter
/// keeps playing in the dock. Place it in the player's Stack.
class SomeoneNew extends ConsumerStatefulWidget {
  const SomeoneNew({required this.item, required this.chapter, super.key});

  final LibraryItem item;

  /// The chapter playing.
  final ListeningChapter? chapter;

  /// How long a card stays.
  static const stays = Duration(seconds: 5);

  @override
  ConsumerState<SomeoneNew> createState() => _SomeoneNewState();
}

class _SomeoneNewState extends ConsumerState<SomeoneNew> {
  /// What the reader had when this player opened: only what comes after that is news.
  GuideReach? _before;
  String? _looked;
  final _carded = <String>{};
  final _waiting = <GuideEntry>[];
  GuideEntry? _card;
  Timer? _timer;

  void _look(WorldGuide guide, GuideReach before, ListeningChapter chapter, String productionId) {
    final numbered = guide.guide.productions.where((production) => production.id == productionId).firstOrNull;
    final number = numbered?.chapters.where((known) => known.id == chapter.id).firstOrNull?.number ?? chapter.order;
    for (final entry in [...guide.guide.characters, ...guide.guide.places]) {
      final after = entry.after;
      if (after == null || after.production != productionId || after.number > number || before.shows(after) || !_carded.add(entry.id)) continue;
      _waiting.add(entry);
    }
    if (_card == null) _next();
  }

  void _next() {
    _timer?.cancel();
    _card = _waiting.isEmpty ? null : _waiting.removeAt(0);
    if (_card != null) {
      _timer = Timer(SomeoneNew.stays, () {
        if (mounted) setState(_next);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worldId = widget.item.worldId;
    if (worldId == null) return const SizedBox.shrink();
    final guide = ref.watch(worldGuideProvider(worldId)).value;
    // Watched only until it has answered: it works over the chapter's whole listening document, and a
    // place is saved every few seconds.
    if (_before == null && guide != null) _before = ref.watch(guideReachProvider(worldId)).value;
    final before = _before;
    final chapter = widget.chapter;
    final world = ref.watch(libraryWorldsProvider).value?.where((world) => world.id == worldId).firstOrNull;
    final productionId = world?.productions.where((production) => production.narration == widget.item.id).firstOrNull?.id;
    if (guide != null && before != null && chapter != null && productionId != null && chapter.id != _looked) {
      _looked = chapter.id;
      _look(guide, before, chapter, productionId);
    }
    final card = _card;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.wide;
    return Positioned(
      left: wide ? 40 : 12,
      right: wide ? null : 12,
      width: wide ? 400 : null,
      top: MediaQuery.paddingOf(context).top + 8,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: card == null || guide == null
            ? const SizedBox.shrink()
            : _Card(
                key: ValueKey(card.id),
                entry: card,
                picture: guidePicture(guide, card),
                onOpen: () => context.go(Routes.guideEntry(Routes.worldsWorld(worldId), card.id)),
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.entry, required this.picture, required this.onOpen, super.key});

  final GuideEntry entry;
  final ImageProvider? picture;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kind = entry is GuidePlace ? placeKind(entry as GuidePlace) : 'Character';
    final name = entryName(entry);
    return Semantics(
      button: true,
      label: 'New, $kind, $name',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 72,
                padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                color: _bg.withValues(alpha: 0.6),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 48,
                        height: 56,
                        child: picture == null
                            ? const ColoredBox(color: ArkeColors.neutral800)
                            : Image(
                                image: picture!,
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -0.64),
                                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const NewTag(onMedia: true),
                              const SizedBox(width: 7),
                              Text(kind, style: text.labelMedium?.copyWith(color: _fg.withValues(alpha: 0.74))),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: _fg, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: _fg.withValues(alpha: 0.74)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
