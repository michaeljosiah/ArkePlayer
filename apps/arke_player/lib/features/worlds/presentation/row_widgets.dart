import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// The sizes a row takes (Arke Player P16 rule 1). Each row is one size and one shape, whatever it
/// holds, and a page mixes rows, the size saying how much a row matters — as Netflix's Home does.
/// P15's first draw mixed sizes inside one row, which is what looked unkempt.
abstract final class RowSizes {
  static bool _fold(BuildContext context) => MediaQuery.sizeOf(context).width >= WindowBands.fold;

  /// A poster, 2:3: Stories, and a world's Listen and Read.
  static double poster(BuildContext context) => _fold(context) ? 260 : 172;

  /// A small poster, 2:3: Teasers, a world's Characters, and a band's row.
  static double small(BuildContext context) => _fold(context) ? 160 : 112;

  /// The feature's height: upright on a phone, wide on a Fold.
  static double feature(BuildContext context) => _fold(context) ? 424 : 476;
}

/// A picture shown whole over a blurred, darkened copy of itself: a poster's or the feature's
/// fallback when a production has no Tall cover (P16 rule 3, call 14). The owner chose making
/// shapes over cropping in P14, so a wide picture in an upright frame is never cut.
class WholeOverBlur extends StatelessWidget {
  const WholeOverBlur({required this.picture, super.key});

  final ImageProvider picture;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: _bg),
      ClipRect(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16, tileMode: TileMode.clamp),
          child: Transform.scale(
            scale: 1.35,
            child: Image(image: picture, fit: BoxFit.cover),
          ),
        ),
      ),
      ColoredBox(color: _bg.withValues(alpha: 0.38)),
      Image(image: picture, fit: BoxFit.contain),
    ],
  );
}

/// A poster (P16 rules 3 and 5): 2:3 with its title and kind under it. [tall] fills it; without one,
/// [wide] shows whole over its own blur. A character's portrait is its [tall] (uncut, where P15 cut
/// faces to 16:9); a character with none shows its initials. `New` at its top left, a glyph at its
/// middle (a clip's play). On a band's media colours its words take the overlay's ink.
class PosterTile extends StatelessWidget {
  const PosterTile({
    required this.title,
    required this.kind,
    required this.width,
    required this.onOpen,
    this.tall,
    this.wide,
    this.fresh = false,
    this.glyph,
    this.initials,
    this.pictureAlignment = Alignment.center,
    this.onMedia = false,
    super.key,
  });

  final String title;
  final String kind;
  final double width;
  final VoidCallback? onOpen;
  final ImageProvider? tall;
  final ImageProvider? wide;
  final bool fresh;
  final IconData? glyph;
  final String? initials;
  final Alignment pictureAlignment;
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    final picture = switch ((tall, wide)) {
      (final ImageProvider tall, _) => Image(image: tall, fit: BoxFit.cover, alignment: pictureAlignment),
      (null, final ImageProvider wide) => WholeOverBlur(picture: wide),
      _ => ColoredBox(
        color: surface.secondary,
        child: initials == null
            ? null
            : Center(
                child: Text(initials!, style: text.titleLarge?.copyWith(color: surface.mutedForeground)),
              ),
      ),
    };
    return Semantics(
      button: onOpen != null,
      label: [title, if (fresh) 'New', kind].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onOpen,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ArkeRadius.lg),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        picture,
                        if (fresh) const Positioned(left: 6, top: 6, child: NewTag(onMedia: true)),
                        if (glyph != null)
                          Center(
                            child: Container(
                              width: ArkeSizes.press,
                              height: ArkeSizes.press,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _bg.withValues(alpha: 0.42),
                                border: Border.all(color: _fg.withValues(alpha: 0.16)),
                              ),
                              child: Icon(glyph, color: _fg, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: onMedia ? _fg : null),
                ),
                Text(
                  kind,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: onMedia ? _fg.withValues(alpha: 0.7) : surface.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The feature (P16 rule 2): the one production Discover opens on, under `All`. On a phone it is
/// 358 × 476 and upright, from its Tall cover or its Wide whole over its blur; on a Fold it is 424
/// high and wide, from its Wide, its words at the left. `New` and the chapter, the title, the kind
/// and world, then one press. The card opens the world's page at the production.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.title,
    required this.meta,
    required this.onOpen,
    this.tall,
    this.wide,
    this.fresh = false,
    this.chapter,
    this.press,
    super.key,
  });

  final String title;
  final String meta;
  final VoidCallback onOpen;
  final ImageProvider? tall;
  final ImageProvider? wide;
  final bool fresh;

  /// What is new, `Chapter 24`, beside `New`.
  final String? chapter;

  /// Install, Play, or the install's progress in the press's place.
  final Widget? press;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fold = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    // The Fold's feature is wider than 16:9, so its Wide loses about a fifth of its height. It is all
    // taken from the foot: a cover's title sits at its very top, and Na Love or Juju's lost its first
    // letters when the cut was shared with the top.
    final picture = fold
        ? (wide == null ? null : Image(image: wide!, fit: BoxFit.cover, alignment: Alignment.topCenter))
        : switch ((tall, wide)) {
            (final ImageProvider tall, _) => Image(image: tall, fit: BoxFit.cover, alignment: const Alignment(0, -0.4)),
            (null, final ImageProvider wide) => WholeOverBlur(picture: wide),
            _ => null,
          };
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fresh || chapter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                if (fresh) const NewTag(onMedia: true),
                if (fresh && chapter != null) const SizedBox(width: 8),
                if (chapter != null)
                  Flexible(
                    child: Text(
                      chapter!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.86)),
                    ),
                  ),
              ],
            ),
          ),
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (fold ? text.headlineLarge?.copyWith(fontSize: ArkeType.size4xl) : text.headlineLarge)?.copyWith(color: _fg),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.74)),
        ),
        if (press != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: fold ? 240 : double.infinity),
            child: press,
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          height: RowSizes.feature(context),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(ArkeRadius.xxl),
            border: Border.all(color: _fg.withValues(alpha: 0.14)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ?picture,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: fold
                      ? const LinearGradient(colors: [Color(0xE60A0A0A), Color(0x940A0A0A), Color(0x000A0A0A)], stops: [0, 0.34, 0.62])
                      : const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xEB0A0A0A), Color(0x660A0A0A), Color(0x000A0A0A)],
                          stops: [0.08, 0.42, 0.62],
                        ),
                ),
              ),
              if (fold)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x990A0A0A), Color(0x000A0A0A)],
                      stops: [0, 0.4],
                    ),
                  ),
                ),
              if (fold) Positioned(left: 36, bottom: 36, width: 380, child: words) else Positioned(left: 18, right: 18, bottom: 18, child: words),
            ],
          ),
        ),
      ),
    );
  }
}

/// A band (P16 rule 6): one world across the page, its key art blurred behind on the media colours
/// whatever the theme; its key art small, its name and data, a round press, its logline in two
/// lines, then its productions and characters as small posters.
class WorldBand extends StatelessWidget {
  const WorldBand({
    required this.name,
    required this.meta,
    required this.keyArt,
    required this.onOpen,
    required this.posters,
    this.logline,
    this.press,
    super.key,
  });

  final String name;
  final String meta;
  final ImageProvider? keyArt;
  final String? logline;
  final VoidCallback onOpen;

  /// The round Install with its label under it, or its progress; none once installed.
  final Widget? press;
  final List<Widget> posters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: ClipRect(
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: _bg)),
            if (keyArt != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                  child: Transform.scale(
                    scale: 1.3,
                    child: Image(image: keyArt!, fit: BoxFit.cover),
                  ),
                ),
              ),
            Positioned.fill(child: ColoredBox(color: _bg.withValues(alpha: 0.52))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: [name, meta].join(', '),
                            child: ExcludeSemantics(
                              child: GestureDetector(
                                onTap: onOpen,
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(ArkeRadius.xl),
                                      child: SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: keyArt == null ? const ColoredBox(color: ArkeColors.neutral800) : Image(image: keyArt!, fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: text.titleMedium?.copyWith(fontSize: ArkeType.sizeXl, color: _fg),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            meta,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.76)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (press != null) ...[const SizedBox(width: 12), press!],
                      ],
                    ),
                  ),
                  if (logline != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        logline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(color: _fg.withValues(alpha: 0.86)),
                      ),
                    ),
                  if (posters.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, poster) in posters.indexed) ...[if (i > 0) const SizedBox(width: 12), poster],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The band's round press, its label under it (P16c): Install, or the install's progress.
class BandPress extends StatelessWidget {
  const BandPress({required this.label, required this.onPressed, this.progress, super.key});

  final String label;
  final VoidCallback onPressed;

  /// While it installs, how far.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: progress == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _fg),
                        child: Icon(Icons.download_rounded, color: _bg, size: 22),
                      )
                    : CircularProgressIndicator(value: progress, strokeWidth: 3, color: _fg, backgroundColor: _fg.withValues(alpha: 0.22)),
              ),
              const SizedBox(height: 4),
              Text(label, style: text.labelMedium?.copyWith(color: _fg)),
            ],
          ),
        ),
      ),
    );
  }
}
