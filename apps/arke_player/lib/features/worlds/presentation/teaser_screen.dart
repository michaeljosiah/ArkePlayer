import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../application/discover.dart';
import '../application/guides.dart';
import 'row_widgets.dart';
import 'world_widgets.dart';

/// A picture or clip teaser, full screen (SPEC-059 R-32): a clip plays with sound; either leads to
/// its world, opened in the tab it was found in.
Future<void> openTeaser(BuildContext context, CatalogueWorld world, WorldGuide guide, GuideTeaser teaser, {required String worldPage}) async {
  final toWorld = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => TeaserScreen(world: world, guide: guide, teaser: teaser),
    ),
  );
  if (toWorld == true && context.mounted) await context.push(worldPage);
}

class TeaserScreen extends ConsumerStatefulWidget {
  const TeaserScreen({required this.world, required this.guide, required this.teaser, super.key});

  final CatalogueWorld world;
  final WorldGuide guide;
  final GuideTeaser teaser;

  @override
  ConsumerState<TeaserScreen> createState() => _TeaserScreenState();
}

class _TeaserScreenState extends ConsumerState<TeaserScreen> {
  late final TeaserAudio _audio = ref.read(teaserAudioProvider);

  @override
  void initState() {
    super.initState();
    // A clip's narration and a song's excerpt play with sound once opened, never in the row (R-78).
    final audio = switch (widget.teaser) {
      ClipTeaser(:final audio) || SongTeaser(:final audio) => audio,
      _ => null,
    };
    if (audio != null) _audio.play(widget.guide.pathOf(audio)).catchError((Object _) {});
  }

  @override
  void dispose() {
    _audio.stop().catchError((Object _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fg = ArkeColors.mediaOverlayForeground;
    final text = Theme.of(context).textTheme;
    final (title, picture, line) = switch (widget.teaser) {
      // A song's square cover, whole over its blur as its poster shows it (P17b).
      SongTeaser(:final title, :final picture, :final duration) => (title, picture, ['Song · ${formatClock(duration)}', widget.world.name].join(' · ')),
      final PictureTeaser teaser => (
        teaser.title,
        teaser.picture,
        [if (teaser is ClipTeaser) 'Clip · ${formatClock(teaser.duration)}' else 'Picture', 'Chapter ${teaser.from.number}', widget.world.name].join(' · '),
      ),
      EntryTeaser() => throw StateError('an entry teaser opens its page'),
    };
    final image = FileImage(File(widget.guide.pathOf(picture)));
    return Scaffold(
      backgroundColor: ArkeColors.mediaOverlayBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.teaser is SongTeaser)
            Padding(
              padding: const EdgeInsets.only(bottom: 160),
              child: WholeOverBlur(picture: image),
            )
          else
            InteractiveViewer(
              child: Image(image: image, fit: BoxFit.contain),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassPress(icon: Icons.close_rounded, label: 'Close', onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleLarge?.copyWith(color: fg)),
                        const SizedBox(height: 2),
                        Text(line, style: text.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.78))),
                        const SizedBox(height: 14),
                        HeroSecondPress(icon: Icons.public, label: widget.world.name, onPressed: () => Navigator.of(context).pop(true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
