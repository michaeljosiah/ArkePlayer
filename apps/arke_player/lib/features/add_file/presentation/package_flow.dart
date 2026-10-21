import 'dart:io';
import 'dart:typed_data';

import 'package:arke_library/arke_library.dart';
import 'package:arke_publication/arke_publication.dart';
import 'package:arke_world/arke_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../settings/application/settings_controller.dart';
import '../../worlds/application/worlds.dart';
import '../../worlds/presentation/world_widgets.dart';
import '../domain/added_file.dart';

/// Whether a picked file is a world package, from its first bytes and name: it takes its own way
/// in (P2d–P2f, P10) rather than the files' sheet (P7a).
Future<bool> isWorldPackage(PickedFile file) async {
  final head = BytesBuilder(copy: false);
  try {
    await for (final chunk in file.open()) {
      head.add(chunk);
      if (head.length >= 256) break;
    }
  } on Object {
    return false;
  }
  final probe = probeFile(head.takeBytes(), name: file.name);
  return probe is ProbeFormat && probe.format == FileFormat.arkePackage;
}

/// A world package added from a file (SPEC-058 R-17 – R-21): copied and checked in full while
/// Checking shows (P2d), then Ready with Add to library (P2e) — or Replace for another edition of a
/// world in Library (P10a), Already in Library for the same one (P10b), or refused in one clause
/// (P2f). Nothing joins the library before the press, and closing deletes the copy.
Future<PackageOutcome> addPackage(BuildContext context, WidgetRef ref, PickedFile file) async {
  final installer = await ref.read(worldInstallerProvider.future);
  if (!context.mounted) return PackageOutcome.none;
  final step = ValueNotifier<InstallStep?>(null);
  final cancel = InstallCancel();
  // The outcome is caught as it is made: a package refused on its first bytes fails before the
  // sheet that shows it has subscribed, and would otherwise be an uncaught error.
  final work = installer
      .prepareFile(size: file.size, open: file.open, onStep: (value) => step.value = value, cancel: cancel)
      .then<Object>((prepared) => prepared, onError: (Object error) => error);
  final Object outcome =
      await showModalBottomSheet<Object>(
        context: context,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => _CheckingSheet(file: file, step: step, work: work, onCancel: cancel.cancel),
      ) ??
      const InstallCancelled();
  step.dispose();
  if (!context.mounted) {
    if (outcome is PreparedWorld) await installer.discard(outcome);
    return PackageOutcome.none;
  }

  switch (outcome) {
    case PreparedWorld(sameEdition: true):
      await installer.discard(outcome);
      if (context.mounted) await _alreadyInLibrary(context, outcome);
      return PackageOutcome.none;
    case final PreparedWorld prepared:
      final add = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (context) => _ReadyScreen(prepared: prepared)));
      if (add != true) {
        await installer.discard(prepared);
        return PackageOutcome.none;
      }
      final world = await installer.commit(prepared);
      // Once anything is in the library, later opens land on Home rather than first open (P8a).
      await ref.read(settingsProvider.notifier).change((settings) => settings.copyWith(seenFirstOpen: true));
      if (context.mounted) context.go(Routes.libraryWorld(world.id));
      return PackageOutcome.added;
    case InstallCancelled():
      return PackageOutcome.none;
    case final InstallRefusal refusal:
      return await _refused(context, file, refusal) ? PackageOutcome.chooseAnother : PackageOutcome.none;
    default:
      return await _refused(context, file, const NotAPackage()) ? PackageOutcome.chooseAnother : PackageOutcome.none;
  }
}

/// How adding a package ended: added, not added, or refused with Choose another file pressed.
enum PackageOutcome { added, none, chooseAnother }

/// Checking (P2d): the file, a bar, and what is happening as data; Cancel deletes what came.
class _CheckingSheet extends StatefulWidget {
  const _CheckingSheet({required this.file, required this.step, required this.work, required this.onCancel});

  final PickedFile file;
  final ValueNotifier<InstallStep?> step;

  /// The prepared world, or what refused it.
  final Future<Object> work;
  final VoidCallback onCancel;

  @override
  State<_CheckingSheet> createState() => _CheckingSheetState();
}

class _CheckingSheetState extends State<_CheckingSheet> {
  @override
  void initState() {
    super.initState();
    widget.work.then<void>((outcome) => mounted ? Navigator.of(context).pop(outcome) : null);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Checking', style: text.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
                child: Icon(Icons.inventory_2_outlined, color: surface.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase),
                    ),
                    Text(formatBytes(widget.file.size), style: text.labelSmall?.copyWith(color: surface.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder(
            valueListenable: widget.step,
            builder: (context, step, _) {
              final (fraction, line) = switch (step) {
                Copying(:final copied, :final total) => (total <= 0 ? null : 0.5 * copied / total, '${formatBytes(copied)} of ${formatBytes(total)}'),
                Checking(:final checked, :final total) => (total <= 0 ? 0.5 : 0.5 + 0.5 * checked / total, '$checked of $total files'),
                _ => (null, ''),
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ArkeRadius.pill),
                    child: LinearProgressIndicator(value: fraction, minHeight: 4, backgroundColor: surface.secondary, color: surface.foreground),
                  ),
                  const SizedBox(height: 8),
                  Text(line, style: text.labelSmall?.copyWith(color: surface.mutedForeground)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: widget.onCancel,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(ArkeSizes.widePress),
              backgroundColor: surface.secondary,
              foregroundColor: surface.foreground,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Ready (P2e), or Replace for another edition of a world in Library (P10a): the package's picture
/// and name, its line, Inside, then In Library and Space, and the press.
class _ReadyScreen extends ConsumerWidget {
  const _ReadyScreen({required this.prepared});

  final PreparedWorld prepared;

  File? _staged(String? assetId) {
    if (assetId == null) return null;
    final asset = prepared.manifest.assets[assetId];
    return asset == null ? null : File('${prepared.content.path}${Platform.pathSeparator}${asset.path.replaceAll('/', Platform.pathSeparator)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    final manifest = prepared.manifest;
    final world = prepared.world;
    final installed = prepared.installed;
    final free = ref.watch(volumeProvider).value?.free;
    final items = {for (final item in prepared.items) item.id: item};
    final keyArt = _staged(manifest.keyArt);
    const fg = ArkeColors.mediaOverlayForeground;

    final space = switch ((installed, free)) {
      (final LibraryWorld before?, final int free) =>
        '${world.byteLength >= before.byteLength ? '+' : '−'}${formatBytes((world.byteLength - before.byteLength).abs())} of ${formatBytes(free)} free',
      (null, final int free) => '${formatBytes(world.byteLength)} of ${formatBytes(free)} free',
      _ => null,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RoundPress(icon: Icons.close, label: 'Close', onPressed: () => Navigator.of(context).pop(false)),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (keyArt != null) Image.file(keyArt, fit: BoxFit.cover) else const ColoredBox(color: ArkeColors.neutral800),
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
                              left: 16,
                              right: 16,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PACKAGE',
                                    style: text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.72), letterSpacing: 0.55, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(world.name, style: text.titleLarge?.copyWith(color: fg)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      [editionLine(world.edition), productionCount(world.productions.length), formatBytes(world.byteLength)].join(' · '),
                      style: text.bodyMedium?.copyWith(color: surface.mutedForeground),
                    ),
                  ),
                  const SectionHead('Inside'),
                  for (final production in world.productions)
                    InsideRow(
                      title: production.title,
                      kind: productionKind(
                        book: production.book != null,
                        narration: production.narration != null,
                        length: items[production.narration]?.duration,
                      ),
                      picture: switch (_staged(manifest.productions.firstWhere((p) => p.id == production.id).picture) ?? keyArt) {
                        final File file => FileImage(file),
                        null => null,
                      },
                    ),
                  const SizedBox(height: 14),
                  _Group(
                    rows: [
                      if (installed != null) ('In Library', '${editionLine(installed.edition, made: false)} · ${formatBytes(installed.byteLength)}'),
                      if (space != null) ('Space', space),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
                    child: Text(installed == null ? 'Add to library' : 'Replace'),
                  ),
                  if (installed != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: surface.foreground),
                      child: const Text('Cancel'),
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

/// Rows of data in one group, as P2e and P10a draw them.
class _Group extends StatelessWidget {
  const _Group({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.xl)),
      child: Column(
        children: [
          for (final (i, (label, value)) in rows.indexed)
            Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: surface.foreground.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  Text(label, style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: surface.mutedForeground),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// An edition as data: `made 21 Oct 2026` for a dated label, else the label.
String editionLine(String edition, {bool made = true}) {
  final date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(edition);
  if (date == null) return edition;
  final month = int.parse(date[2]!);
  if (month < 1 || month > 12) return edition;
  final day = '${int.parse(date[3]!)} ${_months[month - 1]} ${date[1]}';
  return made ? 'made $day' : day;
}

/// The same edition (P10b): one clause, the world and its edition, Open and Close.
Future<void> _alreadyInLibrary(BuildContext context, PreparedWorld prepared) async {
  final open = await showArkeSheet<bool>(
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
            Icon(Icons.collections_bookmark_outlined, size: 34, color: surface.mutedForeground),
            const SizedBox(height: 12),
            Text('Already in Library', textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${prepared.world.name} · ${editionLine(prepared.world.edition, made: false)}',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: surface.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
              child: const Text('Open'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: surface.foreground),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
  if (open == true && context.mounted) context.go(Routes.libraryWorld(prepared.world.id));
}

/// Refused in one clause (P2f): the file and its size under it, then Choose another file and Close.
/// Returns whether another file was chosen.
Future<bool> _refused(BuildContext context, PickedFile file, InstallRefusal refusal) async {
  final again = await showArkeSheet<bool>(
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
            const Icon(Icons.warning_amber_rounded, size: 34, color: ArkeColors.warning),
            const SizedBox(height: 12),
            Text(refusal.clause, textAlign: TextAlign.center, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${file.name} · ${formatBytes(file.size)}',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: surface.mutedForeground),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
              child: const Text('Choose another file'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: surface.foreground),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
  return again == true;
}
