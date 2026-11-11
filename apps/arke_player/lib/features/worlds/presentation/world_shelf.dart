import 'dart:ui' show ImageFilter;

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../../settings/presentation/adult_ask.dart';
import '../application/guides.dart';
import '../application/worlds.dart';
import 'guide_widgets.dart';
import 'world_widgets.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// A page's colour (P22 rule 6, call 45): its own picture's blur on the media colours, whatever the
/// theme, fading into the page's ground at its foot. Nothing is computed or stored.
class PictureGlow extends StatelessWidget {
  const PictureGlow({required this.picture, super.key});

  final ImageProvider? picture;

  @override
  Widget build(BuildContext context) {
    final ground = context.surface.background;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _bg),
        if (picture != null) BlurOf(picture: picture!),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // The white words stay on the media colours until the press has passed.
              stops: const [0, 0.24, 0.84, 1],
              colors: [_bg.withValues(alpha: 0.30), _bg.withValues(alpha: 0), ground.withValues(alpha: 0), ground],
            ),
          ),
        ),
      ],
    );
  }
}

/// A picture's own blur, darkened: the colour under a world's page and a teaser. Clipped, because at this
/// sigma it spreads some 130 past its box, over whatever the page has there.
class BlurOf extends StatelessWidget {
  const BlurOf({required this.picture, super.key});

  final ImageProvider picture;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 44, sigmaY: 44, tileMode: TileMode.clamp),
            child: Image(image: picture, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
          ),
          ColoredBox(color: _bg.withValues(alpha: 0.44)),
        ],
      ),
    ),
  );
}

/// The left of a page on a tablet sideways (P26h, P26n): its picture melting into its own blur, and what
/// must never leave the screen. What the page holds scrolls beside it.
class WorldPane extends StatelessWidget {
  const WorldPane({required this.picture, required this.child, this.pictureAlignment = const Alignment(0.2, 0), this.onMore, super.key});

  final ImageProvider? picture;
  final Widget child;
  final Alignment pictureAlignment;
  final VoidCallback? onMore;

  static const width = 460.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: _bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (picture != null) BlurOf(picture: picture!),
          if (picture != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 470,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.52, 1],
                  colors: [Colors.black, Colors.transparent],
                ).createShader(bounds),
                child: Image(image: picture!, fit: BoxFit.cover, alignment: pictureAlignment, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
              ),
            ),
          SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 330, 24, 24), child: child),
          Positioned(
            left: 12,
            right: 12,
            top: top + 8,
            child: Row(
              children: [
                if (context.canPop()) GlassPress(icon: Icons.chevron_left_rounded, label: 'Back', onPressed: () => context.pop()),
                const Spacer(),
                if (onMore != null) GlassPress(icon: Icons.more_horiz, label: 'More', onPressed: onMore!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A world's age (P22 rule 9, call 42), from Arke's list: a small outlined mark, in the ink it sits on.
class AgeTag extends StatelessWidget {
  const AgeTag(this.age, {this.color, super.key});

  final String age;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.surface.foreground;
    return Semantics(
      label: 'Age $age',
      child: ExcludeSemantics(
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: ink.withValues(alpha: 0.42)),
          ),
          child: Text(
            age,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: ink, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    );
  }
}

/// Three of a world's people (P22 rule 2): those its guide shows from the start with a portrait. A
/// guide that has not landed draws nothing, with no placeholder (P25 rule 3), and no [gap] either, so
/// the words beside it stay at the margin.
class WorldFaces extends ConsumerWidget {
  const WorldFaces({required this.worldId, this.ring = _bg, this.gap = 0, super.key});

  final String worldId;
  final Color ring;
  final double gap;

  static const _size = 28.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(guideFetchProvider(worldId));
    final guide = ref.watch(worldGuideProvider(worldId)).value;
    final faces = [
      for (final character in guide?.guide.characters ?? const <GuideCharacter>[])
        if (character.after == null && character.portrait != null) guidePicture(guide!, character),
    ].nonNulls.take(3).toList();
    if (faces.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.only(right: gap),
        child: SizedBox(
          width: _size + (faces.length - 1) * (_size - _overlap),
          height: _size,
          child: Stack(
            children: [
              for (final (i, face) in faces.indexed)
                Positioned(
                  left: i * (_size - _overlap),
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ring.withValues(alpha: 0.72), width: 2),
                      image: DecorationImage(image: face, fit: BoxFit.cover, alignment: const Alignment(0, -0.6)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The world's Notify (P22 rule 4), brought forward from ⋯: round beside the press, filled when on.
class NotifyBell extends ConsumerWidget {
  const NotifyBell({required this.worldId, this.size = ArkeSizes.widePress, this.onMedia = true, super.key});

  final String worldId;
  final double size;

  /// On a picture or its blur. Off them, as under Continue, it takes the theme's colours.
  final bool onMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = (ref.watch(settingsProvider).value ?? const DeviceSettings()).notify.contains(worldId);
    final fg = onMedia ? _fg : context.surface.foreground;
    final bg = onMedia ? _bg : context.surface.background;
    return Semantics(
      button: true,
      toggled: on,
      label: 'Notify',
      child: ExcludeSemantics(
        // Its own Material: an Ink paints on the nearest one, and the Scaffold's lies under an opaque
        // page, which is where its circle went.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => setNotify(ref, worldId, !on),
            customBorder: const CircleBorder(),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? fg : fg.withValues(alpha: 0.16)),
              child: Icon(on ? Icons.notifications_rounded : Icons.notifications_none_rounded, size: 22, color: on ? bg : fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a world's press does once it is here (P22 rule 3): the title it starts at, and whether this
/// phone holds a place in it.
class WorldStart {
  const WorldStart({required this.production, required this.first, this.book, this.where});

  final LibraryProduction production;

  /// What the press opens, unless the production plays by its own route (a story, a comic, an album).
  final LibraryItem? first;

  /// The book beside a narration: `Read`.
  final LibraryItem? book;

  /// `Chapter 3`, once a place is kept.
  final String? where;

  bool get read => first != null && production.narration == null;

  /// Begun, whether or not it can say where: a book's place is a position in its text.
  bool get begun => first?.inProgress ?? false;
}

/// The production a world's press opens: the list's start, else the place kept most lately, else the
/// first story (call 39).
WorldStart? worldStart(LibraryWorld world, CatalogueWorld? listed, Map<String, LibraryItem> items) {
  final stories = world.productions.where((production) => production.music == null).toList();
  if (stories.isEmpty) return null;
  LibraryItem? firstOf(LibraryProduction production) => items[production.narration] ?? bookNow(production, items);
  final going = stories.map((production) => (production, firstOf(production))).where((pair) => pair.$2?.inProgress ?? false).toList()
    ..sort((a, b) => b.$2!.place!.updatedAt.compareTo(a.$2!.place!.updatedAt));
  final named = listed?.startsAt == null ? null : stories.where((production) => production.id == listed!.startsAt!.id).firstOrNull;
  final production = going.firstOrNull?.$1 ?? named ?? stories.first;
  final first = firstOf(production);
  return WorldStart(production: production, first: first, book: production.narration == null ? null : bookNow(production, items), where: _whereIn(first));
}

String? _whereIn(LibraryItem? item) {
  if (item == null || !item.inProgress) return null;
  final position = item.position;
  if (position == null || item.chapters.isEmpty) return null;
  var index = 0;
  for (final (i, chapter) in item.chapters.indexed) {
    if (chapter.start <= position) index = i;
  }
  return chapterName(item.chapters, index);
}

/// Asks once on an 18+ world (P22e, call 42), before anything downloads or plays.
Future<bool> mayOpen(BuildContext context, WidgetRef ref, CatalogueWorld? listed, {required String press}) async {
  if (listed == null || !listed.adult) return true;
  final size = listed.installable ? formatBytes(worldBytes(listed)) : null;
  return askAdult(context, ref, title: listed.name, line: [...listed.genres.take(1), ?size].join(' · '), press: 'I am 18 or older · $press');
}

/// All a world's download comes to: its edition, every part since (SPEC-058 R-50) and the productions
/// published alone beside it, as the installer adds them up.
int worldBytes(CatalogueWorld world) => world.downloadBytes;

/// A song played from where it is listed: no player's route opens for it, so nothing else would ask.
Future<void> playSong(BuildContext context, WidgetRef ref, String worldId, VoidCallback play) async {
  final listed = listedFor(ref.read(catalogueProvider).value ?? const [], worldId);
  if (await mayOpen(context, ref, listed, press: 'Play') && context.mounted) play();
}

/// The route of a world's title in its player.
String? startRoute(LibraryWorld world, WorldStart start) {
  final production = start.production;
  if (start.first case final item?) return Routes.open(item.id);
  if (production.story != null) return Routes.story(world.id, production.id);
  if (production.comic != null) return Routes.comic(world.id, production.id);
  return null;
}

/// A world's one press (P22 rule 3, call 39), wherever it shows: `Start · 1.1 GB` before it is here,
/// which downloads it; the download in its place, with Cancel (P25d); `Play` once it arrived (P25e);
/// `Continue · Chapter 3` once begun, with Read beside a narration's book. With no connection, it says
/// so and asks nothing (P25h). The bell sits at its end.
class WorldPress extends ConsumerWidget {
  const WorldPress({required this.worldId, this.top = 10, this.bell = true, this.hug = false, this.onMedia = true, this.onGo, super.key});

  final String worldId;
  final double top;
  final bool bell;

  /// In a teaser's strip (P23 rule 3): as wide as its words and lower, the verb alone once it is here.
  final bool hug;

  /// On a picture or its blur. Off them, as under Continue, it takes the theme's colours.
  final bool onMedia;

  /// Goes to a title's player itself: the feed leaves first, or its sound and the title's play together.
  final ValueChanged<String>? onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(catalogueProvider).value ?? const <CatalogueWorld>[];
    final held = ref.watch(installedWorldProvider(worldId));
    final listed = listedFor(catalogue, held?.id ?? worldId);
    final state = ref.watch(installProvider(listed?.id ?? worldId));
    ref.listen(installProvider(listed?.id ?? worldId), (previous, next) {
      if (next is InstallFailed && previous is! InstallFailed && listed != null) showInstallRefusal(context, ref, listed, next.refusal);
    });
    final fg = onMedia ? _fg : context.surface.foreground;
    final bg = onMedia ? _bg : context.surface.background;
    if (state is Installing) {
      return InstallProgress(state: state, top: top + 6, ink: fg, onCancel: () => ref.read(installProvider(listed?.id ?? worldId).notifier).cancel());
    }
    final items = {for (final item in ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]) item.id: item};
    final start = held == null ? null : worldStart(held, listed, items);
    final online = ref.watch(onlineProvider).value ?? true;

    final List<Widget> presses;
    if (held != null) {
      if (start == null) return const SizedBox.shrink();
      final verb = start.begun ? 'Continue' : (start.read ? 'Read' : 'Play');
      Future<void> open(LibraryItem? item, String press) async {
        if (!await mayOpen(context, ref, listed, press: press) || !context.mounted) return;
        final route = item != null ? Routes.open(item.id) : startRoute(held, start);
        if (route == null) return;
        if (onGo case final go?) {
          go(route);
        } else {
          await context.push(route);
        }
      }

      final press = _Press(
        primary: true,
        icon: Icons.play_arrow_rounded,
        label: verb,
        detail: hug ? null : start.where,
        height: hug ? _hugHeight : ArkeSizes.widePress,
        fg: fg,
        bg: bg,
        onPressed: () => open(start.first, verb),
      );
      presses = [
        if (hug) press else Expanded(child: press),
        if (start.book case final book? when !hug) ...[
          const SizedBox(width: 8),
          _Press(icon: Icons.menu_book_rounded, label: 'Read', fg: fg, bg: bg, onPressed: () => open(book, 'Read')),
        ],
      ];
    } else {
      if (listed == null || !listed.installable) return const SizedBox.shrink();
      final press = online
          ? _Press(
              primary: true,
              icon: hug ? null : Icons.play_arrow_rounded,
              label: 'Start',
              detail: formatBytes(worldBytes(listed)),
              height: hug ? _hugHeight : ArkeSizes.widePress,
              fg: fg,
              bg: bg,
              onPressed: () async {
                if (!await mayOpen(context, ref, listed, press: 'Start') || !context.mounted) return;
                await ref.read(installProvider(listed.id).notifier).start(listed);
              },
            )
          : _Press(primary: true, label: 'Start', detail: 'No connection', height: hug ? _hugHeight : ArkeSizes.widePress, fg: fg, bg: bg);
      presses = [if (hug) press else Expanded(child: press)];
    }
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Row(
        mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
        children: [
          ...presses,
          if (bell) ...[const SizedBox(width: 8), NotifyBell(worldId: held?.id ?? worldId, onMedia: onMedia)],
        ],
      ),
    );
  }
}

const _hugHeight = 40.0;

class _Press extends StatelessWidget {
  const _Press({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.detail,
    this.onPressed,
    this.primary = false,
    this.height = ArkeSizes.widePress,
  });

  final double height;
  final Color fg;
  final Color bg;

  final String label;
  final IconData? icon;
  final String? detail;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final words = Text.rich(
      TextSpan(
        text: label,
        children: [
          if (detail != null)
            TextSpan(
              text: ' · $detail',
              style: TextStyle(fontWeight: FontWeight.w400, color: (primary ? bg : fg).withValues(alpha: 0.72)),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final style = FilledButton.styleFrom(
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      backgroundColor: primary ? fg : fg.withValues(alpha: 0.16),
      foregroundColor: primary ? bg : fg,
      disabledBackgroundColor: fg.withValues(alpha: 0.42),
      disabledForegroundColor: bg,
      // A button's textStyle replaces the theme's rather than merging, so it names the family.
      textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
    );
    return icon == null
        ? FilledButton(onPressed: onPressed, style: style, child: words)
        : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: words, style: style);
  }
}

/// A world on Home (P22 rule 2, call 38): its Tall cover whole, lettered with its name, so nothing is
/// set over it; under it three of its people, its genre, its age and its press. A world with no Tall
/// cover shows its key art with its name. 300 × 450 at every size: more fit, and none grows (P26 rule 2).
class WorldCover extends ConsumerWidget {
  const WorldCover({required this.world, required this.onOpen, this.onGlow = true, super.key});

  final CatalogueWorld world;
  final VoidCallback onOpen;

  /// On Home's colour, in the overlay's ink. Coming back they sit under Continue, on the page's own
  /// ground, where that ink and a white press would vanish in the light theme.
  final bool onGlow;

  static const width = 300.0;
  static const height = 450.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final ink = onGlow ? _fg : context.surface.foreground;
    final tall = ref.tallOf(world.startsAt);
    final art = tall ?? ref.keyArtOf(world);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: world.name,
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onOpen,
                child: Container(
                  height: height,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: ArkeColors.neutral800,
                    borderRadius: BorderRadius.circular(ArkeRadius.xl),
                    boxShadow: const [BoxShadow(color: Color(0x6B000000), blurRadius: 34, offset: Offset(0, 14))],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (art != null) Image(image: art, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink()),
                      if (tall == null) ...[
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xE00A0A0A), Color(0x000A0A0A)]),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Text(world.name, style: text.headlineLarge?.copyWith(color: _fg)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                WorldFaces(worldId: world.id, gap: 8, ring: onGlow ? _bg : context.surface.background),
                if (world.genres.isNotEmpty)
                  Expanded(
                    child: Text(
                      world.genres.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: ink.withValues(alpha: 0.84)),
                    ),
                  )
                else
                  const Spacer(),
                if (world.age case final age?) AgeTag(age, color: ink),
              ],
            ),
          ),
          WorldPress(worldId: world.id, onMedia: onGlow),
        ],
      ),
    );
  }
}

/// A world as a card (P22d, P26d): its key art, name, a line of data, three of its people and its age.
/// 358 × 202 down a phone, or 16:9 in a grid; `New` or `Update` at its top left.
class WorldShelfCard extends ConsumerWidget {
  const WorldShelfCard({
    required this.worldId,
    required this.name,
    required this.line,
    required this.picture,
    required this.onOpen,
    this.age,
    this.fresh = false,
    this.tag,
    this.progress,
    this.grid = false,
    super.key,
  });

  final String worldId;
  final String name;
  final String line;
  final ImageProvider? picture;
  final VoidCallback onOpen;
  final String? age;
  final bool fresh;
  final String? tag;
  final double? progress;

  /// In a grid the card is 16:9, as wide as its column.
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final card = Stack(
      fit: StackFit.expand,
      children: [
        if (picture != null)
          Image(image: picture!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink())
        else
          const ColoredBox(color: ArkeColors.neutral800),
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
        if (fresh || tag != null)
          Positioned(
            left: 12,
            top: 12,
            child: Row(
              children: [
                if (fresh) const NewTag(onMedia: true),
                if (fresh && tag != null) const SizedBox(width: 6),
                if (tag != null)
                  DecoratedBox(
                    decoration: BoxDecoration(color: _fg.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      child: Text(
                        tag!,
                        style: text.labelMedium?.copyWith(color: _fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (age != null)
          Positioned(
            right: 12,
            top: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(color: _bg.withValues(alpha: 0.46), borderRadius: BorderRadius.circular(7)),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: AgeTag(age!, color: _fg),
              ),
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 13,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              WorldFaces(worldId: worldId),
            ],
          ),
        ),
        if (progress != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: LinearProgressIndicator(value: progress, backgroundColor: _fg.withValues(alpha: 0.26), color: _fg, minHeight: 3),
          ),
      ],
    );
    return Semantics(
      button: true,
      label: [name, if (fresh) 'New', ?tag, line, if (age != null) 'Age $age'].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: grid ? AspectRatio(aspectRatio: 16 / 9, child: card) : SizedBox(height: 202, child: card),
          ),
        ),
      ),
    );
  }
}
