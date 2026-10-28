import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../parts/application/notices.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/device_settings.dart';
import '../application/guides.dart';
import '../application/worlds.dart';

const _fg = ArkeColors.mediaOverlayForeground;
const _bg = ArkeColors.mediaOverlayBackground;

/// `1 production`, `3 productions`.
String productionCount(int count) => count == 1 ? '1 production' : '$count productions';

/// An edition as the page says it (P12): `20 Oct 2026` for the Studio's dated labels, else the
/// label as it is.
String editionLabel(String edition) {
  final dated = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:-\d+)?$').firstMatch(edition);
  final month = dated == null ? 0 : int.parse(dated[2]!);
  if (dated == null || month < 1 || month > 12) return edition;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${int.parse(dated[3]!)} ${months[month - 1]} ${dated[1]}';
}

/// `1 character`, `5 characters` (P11a).
String characterCount(int count) => count == 1 ? '1 character' : '$count characters';

/// A wide tile's width (P16 rule 4): 16:9, as wide as a world's card in a row, 240 on a phone and
/// 300 on a Fold — New chapters, Home's rows, a world's Watch, Play and Places. The other row sizes
/// are `RowSizes`'.
double rowTileWidth(BuildContext context) => MediaQuery.sizeOf(context).width >= WindowBands.fold ? 300 : 240;

/// A row of tiles that scrolls across, 12 apart.
class TileRow extends StatelessWidget {
  const TileRow({required this.children, super.key});

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

/// A picture named relative to the library's root.
ImageProvider? libraryPicture(LibraryStore? store, String? relative) => store == null || relative == null ? null : FileImage(File(store.resolve(relative)));

/// A picture bundled with the app, for a world not installed yet.
ImageProvider? bundledPicture(String? asset) => asset == null ? null : AssetImage(asset);

/// A picture Arke's list names (SPEC-058 rev 10): the file its pin brought, once kept and checked;
/// else the one bundled with the app; else none, and the row's own fallback shows.
ImageProvider? listPicture(Map<String, File> kept, String? bundled, PicturePin? pin) {
  final file = pin == null ? null : kept[pin.sha256];
  return file != null ? FileImage(file) : bundledPicture(bundled);
}

/// The pictures of Arke's list as rows show them, watching what is kept, so a picture that arrives
/// replaces the bundled one where it is shown.
extension ListPictures on WidgetRef {
  Map<String, File> get _kept => watch(keptPicturesProvider).value ?? const {};

  /// A world's key art.
  ImageProvider? keyArtOf(CatalogueWorld world) => listPicture(_kept, world.keyArt, world.keyArtPin);

  /// A production's wide picture, or its world's key art when it has none.
  ImageProvider? pictureOf(CatalogueWorld world, CatalogueProduction? production) =>
      (production == null ? null : listPicture(_kept, production.picture, production.picturePin)) ?? keyArtOf(world);

  /// A production's Tall cover (P16 call 14): what a poster and a phone's feature show.
  ImageProvider? tallOf(CatalogueProduction? production) => production == null ? null : listPicture(_kept, production.tall, production.tallPin);
}

/// A world as a card: 358 × 190 in Discover's Worlds and in Library (P15b, P15h), and in a row
/// the width of the row's tile (P9g, P15g, P15l). While it installs, its meta line is
/// `Installing · 42%` over a line of progress (P9 rule 4); a world with a newer edition carries
/// `Update` (P12a), one with a chapter not yet opened `New` (P15h).
class WorldCard extends StatelessWidget {
  const WorldCard({
    required this.name,
    required this.meta,
    required this.picture,
    required this.onOpen,
    this.mini = false,
    this.progress,
    this.tag,
    this.fresh = false,
    this.width,
    super.key,
  });

  final String name;
  final String meta;
  final ImageProvider? picture;
  final VoidCallback onOpen;
  final bool mini;
  final double? progress;

  /// One word in a pill at the card's top left.
  final String? tag;

  /// `New`, filled, before the tag.
  final bool fresh;

  /// A card in a row: 240 unless given, 16:9.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(mini ? ArkeRadius.xl : 16),
      child: SizedBox(
        width: mini ? (width ?? 240) : double.infinity,
        height: mini ? (width ?? 240) * 9 / 16 : 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (picture != null) Image(image: picture!, fit: BoxFit.cover) else const ColoredBox(color: ArkeColors.neutral800),
            const _Shade(),
            if (tag != null || fresh)
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
            Positioned(
              left: mini ? 12 : 14,
              right: mini ? 12 : 14,
              bottom: mini ? 11 : 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (mini ? text.titleMedium : text.titleMedium?.copyWith(fontSize: ArkeType.sizeXl))?.copyWith(color: _fg),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.8)),
                  ),
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
        ),
      ),
    );
    return Semantics(
      button: true,
      label: [name, if (fresh) 'New', ?tag, meta].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(onTap: onOpen, child: card),
      ),
    );
  }
}

class _Shade extends StatelessWidget {
  const _Shade();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xE00A0A0A), Color(0x4D0A0A0A), Color(0x000A0A0A)],
        stops: [0.06, 0.52, 0.74],
      ),
    ),
  );
}

/// A round glass press on a picture: back, ⋯.
class GlassPress extends StatelessWidget {
  const GlassPress({required this.icon, required this.label, required this.onPressed, super.key});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: ArkeSizes.press,
        height: ArkeSizes.press,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _bg.withValues(alpha: 0.42),
          border: Border.all(color: _fg.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, color: _fg, size: 22),
      ),
    ),
  );
}

/// A world's or a production's hero (P1d, P9c): the picture under the status bar fading into the
/// overlay colour, back and ⋯ at the top, the title in text-3xl, one meta line, the logline in at
/// most two lines — the author's words or nothing — and what goes under them. On a Fold the
/// picture is 400 high and the words keep to 640 at the left (P9h).
class WorldHero extends StatelessWidget {
  const WorldHero({
    required this.picture,
    required this.title,
    required this.meta,
    this.logline,
    this.onMore,
    this.child,
    this.pictureAlignment = const Alignment(0.2, 0),
    super.key,
  });

  final ImageProvider? picture;

  /// Where the picture is cropped to: a character's portrait keeps the face (P11d).
  final Alignment pictureAlignment;
  final String title;
  final String meta;
  final String? logline;
  final VoidCallback? onMore;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    final pictureHeight = wide ? 400.0 : 290.0;
    final side = wide ? 32.0 : 16.0;
    return ColoredBox(
      color: _bg,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: pictureHeight,
            child: picture == null ? const SizedBox() : Image(image: picture!, fit: BoxFit.cover, alignment: pictureAlignment),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: pictureHeight - 200,
            height: 201,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x000A0A0A), _bg]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(side, (wide ? 300.0 : 218.0).clamp(top + 120, double.infinity), side, wide ? 28 : 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: text.headlineLarge?.copyWith(color: _fg)),
                  ),
                  const SizedBox(height: 6),
                  Text(meta, style: text.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.74))),
                  if (logline != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      logline!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(color: _fg.withValues(alpha: 0.86)),
                    ),
                  ],
                  ?child,
                ],
              ),
            ),
          ),
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

/// The hero's primary press: full width and 50 high on a phone, 320 on a Fold (P9c, P9h).
class HeroPress extends StatelessWidget {
  const HeroPress({required this.icon, required this.label, required this.onPressed, this.detail, super.key});

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: wide ? 320 : double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (detail != null)
                  TextSpan(
                    text: ' · $detail',
                    style: TextStyle(fontWeight: FontWeight.w400, color: _bg.withValues(alpha: 0.72)),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(ArkeSizes.widePress),
            backgroundColor: _fg,
            foregroundColor: _bg,
            // A button's textStyle replaces the theme's rather than merging, so it names the family.
            textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// A second press on a hero, in the overlay's quiet fill: Read beside Continue (P1e), a character's
/// `Voice · 0:08` (P11d).
class HeroSecondPress extends StatelessWidget {
  const HeroSecondPress({required this.icon, required this.label, required this.onPressed, this.detail, super.key});

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: wide ? 320 : double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text.rich(
            TextSpan(
              text: label,
              children: [
                if (detail != null)
                  TextSpan(
                    text: ' · $detail',
                    style: TextStyle(fontWeight: FontWeight.w400, color: _fg.withValues(alpha: 0.6)),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(ArkeSizes.press),
            backgroundColor: _fg.withValues(alpha: 0.16),
            foregroundColor: _fg,
            textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

/// Install's progress in its place (P9d): the line, what is happening as data, and Cancel.
class InstallProgress extends StatelessWidget {
  const InstallProgress({required this.state, required this.onCancel, super.key});

  final Installing state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= WindowBands.fold;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        width: wide ? 320 : double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ArkeRadius.pill),
              child: LinearProgressIndicator(value: state.fraction, minHeight: 4, backgroundColor: _fg.withValues(alpha: 0.22), color: _fg),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(state.line, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _fg.withValues(alpha: 0.72))),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onCancel,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: _fg.withValues(alpha: 0.16),
                    foregroundColor: _fg,
                    textStyle: const TextStyle(fontFamily: ArkeType.family, fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of Inside (P9c, as P2e): the picture at 128 × 72, the title, the kind and length.
class InsideRow extends StatelessWidget {
  const InsideRow({required this.title, required this.kind, required this.picture, super.key});

  final String title;
  final String kind;
  final ImageProvider? picture;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ArkeRadius.md),
            child: SizedBox(
              width: 128,
              height: 72,
              child: picture == null ? ColoredBox(color: context.surface.secondary) : Image(image: picture!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                ),
                const SizedBox(height: 3),
                Text(
                  kind,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: context.surface.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One setting-like row of data in a group: `Space · 386 MB of 41 GB free` (P9c).
/// Rows in one group, a line between each (P12b's New edition and Space).
class GroupRows extends StatelessWidget {
  const GroupRows({required this.rows, super.key});

  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: context.surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
    child: Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: context.surface.border),
          GroupRow(label: row.label, value: row.value, grouped: true),
        ],
      ],
    ),
  );
}

class GroupRow extends StatelessWidget {
  const GroupRow({required this.label, required this.value, this.grouped = false, super.key});

  final String label;
  final String value;

  /// Inside [GroupRows], which draws the group around it.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: grouped ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      constraints: const BoxConstraints(minHeight: 50),
      decoration: grouped ? null : BoxDecoration(color: context.surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
      child: Row(
        children: [
          Text(label, style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: context.surface.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A wide tile (P1d, P9f, P16 rule 4): 16:9 with its title and kind under it, the width of the
/// row's tile, or the full width when a world has only the one production (P9 rule 6). `New` at its
/// top left (P15a); a glyph at its middle, a clip's play.
class ProductionTile extends StatelessWidget {
  const ProductionTile({
    required this.title,
    required this.kind,
    required this.picture,
    required this.width,
    required this.onOpen,
    this.fresh = false,
    this.glyph,
    this.initials,
    this.tag,
    this.pictureAlignment = Alignment.center,
    super.key,
  });

  final String title;
  final String kind;
  final ImageProvider? picture;
  final double width;

  /// Null where nothing opens yet: a production before its world is installed (P15c), or a story this
  /// Player cannot play (P18 rule 7).
  final VoidCallback? onOpen;
  final bool fresh;

  /// A word at its top left in place of `New`: `Update`, or `Update app` (P18 rule 7).
  final String? tag;
  final IconData? glyph;

  /// For a character with no portrait (P15 rule 10).
  final String? initials;
  final Alignment pictureAlignment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return Semantics(
      button: onOpen != null,
      label: [title, if (fresh) 'New', kind, ?tag].join(', '),
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
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (picture != null)
                          Image(image: picture!, fit: BoxFit.cover, alignment: pictureAlignment)
                        else
                          ColoredBox(
                            color: surface.secondary,
                            child: initials == null
                                ? null
                                : Center(
                                    child: Text(initials!, style: text.titleLarge?.copyWith(color: surface.mutedForeground)),
                                  ),
                          ),
                        if (fresh && tag == null) const Positioned(left: 6, top: 6, child: NewTag(onMedia: true)),
                        if (tag != null)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: _bg.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(ArkeRadius.pill)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                child: Text(
                                  tag!,
                                  style: text.labelMedium?.copyWith(color: _fg, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
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
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                Text(
                  kind,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: context.surface.mutedForeground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A refusal (P9e, as P2f): the clause, the world and its size, then Try again and Close.
///
/// With [production], the refusal is that production's Update (SPEC-058 R-72), which Try again
/// presses again.
Future<void> showInstallRefusal(
  BuildContext context,
  WidgetRef ref,
  CatalogueWorld world,
  InstallRefusal refusal, {
  bool updating = false,
  CatalogueProduction? production,
}) async {
  final package = production?.alone ?? world.package;
  final again = await showArkeSheet<bool>(
    context,
    title: null,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final network = refusal is NoConnection || refusal is DownloadStopped;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              network ? Icons.wifi_off_rounded : Icons.warning_amber_rounded,
              size: 34,
              color: network ? context.surface.mutedForeground : ArkeColors.warning,
            ),
            const SizedBox(height: 12),
            Text(refusal.clause, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              // An update names the edition it would have brought (P12f); an install its size.
              [
                production?.title ?? world.name,
                if (updating && package?.edition != null) editionLabel(package!.edition!) else if (package != null) formatBytes(package.byteLength),
              ].join(' · '),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: context.surface.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: context.surface.foreground),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
  if (production != null) {
    final controller = ref.read(productionInstallProvider((world.id, production.id ?? '')).notifier);
    controller.dismiss();
    if (again == true) await controller.start(world, production);
    return;
  }
  final controller = ref.read(installProvider(world.id).notifier);
  controller.dismiss();
  if (again == true) await controller.start(world);
}

/// A world to install as a card, showing its install while one runs (P9 rule 4). Its characters
/// count once its guide is on the phone (P11a).
class AvailableCard extends ConsumerWidget {
  const AvailableCard({required this.world, required this.onOpen, this.mini = false, this.width, super.key});

  final CatalogueWorld world;
  final VoidCallback onOpen;
  final bool mini;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(installProvider(world.id));
    final package = world.package;
    final card = WorldCard(
      name: world.name,
      meta: state is Installing
          ? state.short
          : [
              productionCount(world.productions.length),
              if (ref.watch(worldGuideProvider(world.id)).value?.guide.characters.length case final count? when count > 0) characterCount(count),
              if (package != null) formatBytes(package.byteLength + package.parts.fold<int>(0, (sum, part) => sum + part.byteLength)),
            ].join(' · '),
      picture: ref.keyArtOf(world),
      progress: state is Installing ? state.fraction : null,
      mini: mini,
      width: width,
      onOpen: onOpen,
    );
    return mini ? card : Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: card);
  }
}

/// Turns a world's Notify on or off (P15j): the first time it is turned on, the phone asks its
/// permission; refused, it stays off.
Future<void> setNotify(WidgetRef ref, String worldId, bool on) async {
  final settings = ref.read(settingsProvider.notifier);
  if (on && !await ref.read(noticesProvider).ask().catchError((Object _) => false)) return;
  await settings.change((current) => current.copyWith(notify: on ? {...current.notify, worldId} : ({...current.notify}..remove(worldId))));
}

/// ⋯ on an installed world (P9 rule 6, P15j): Notify of its new chapters, its edition and space,
/// then Details and Remove.
Future<void> showWorldMenu(BuildContext context, WidgetRef ref, LibraryWorld world) async {
  final choice = await showArkeSheet<String>(
    context,
    title: world.name,
    scrollable: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final text = Theme.of(context).textTheme;
        final notify = (ref.watch(settingsProvider).value ?? const DeviceSettings()).notify.contains(world.id);
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Text(
                  'Notify',
                  style: text.labelSmall?.copyWith(color: context.surface.mutedForeground, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
                decoration: BoxDecoration(color: context.surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('New chapters', style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase)),
                      ),
                      Switch(value: notify, onChanged: (on) => setNotify(ref, world.id, on)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GroupRows(rows: [(label: 'Edition', value: editionLabel(world.edition)), (label: 'Space', value: formatBytes(world.byteLength))]),
              const SizedBox(height: 8),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () => Navigator.of(context).pop('details')),
              ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Remove'), onTap: () => Navigator.of(context).pop('remove')),
            ],
          ),
        );
      },
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'details') {
    await showArkeSheet<void>(
      context,
      title: 'Details',
      builder: (context) {
        final text = Theme.of(context).textTheme;
        final muted = context.surface.mutedForeground;
        final installed = world.installedAt.toLocal();
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('Name', world.name),
            row('Edition', world.edition),
            row('Productions', '${world.productions.length}'),
            row('Size', formatBytes(world.byteLength)),
            row('Installed', '${installed.day} ${_months[installed.month - 1]} ${installed.year}'),
          ],
        );
      },
    );
  } else if (choice == 'remove') {
    final confirmed = await showArkeSheet<bool>(
      context,
      title: null,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Remove ${world.name}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              formatBytes(world.byteLength),
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
    await store.removeWorld(world.id);
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
