import 'dart:io';

import 'package:arke_library/arke_library.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/shelf.dart';
import '../../settings/application/settings_controller.dart';
import '../application/file_importer.dart';
import '../application/pdfrx_peek.dart';
import '../application/video_poster.dart';
import '../domain/added_file.dart';
import 'package_flow.dart';

final fileImporterProvider = FutureProvider<FileImporter>((ref) async {
  final store = await ref.watch(libraryStoreProvider.future);
  final storage = ref.watch(storageInfoProvider);
  return FileImporter(store: store, freeBytes: storage.freeBytes, pdf: const PdfrxPeek(), poster: const NativeVideoPoster());
});

/// Add a file (P8 rule 2): the system's picker straight away, several at once, then the sheet
/// that reads them (P7a). [files] skips the picker when the system handed files over (Share to,
/// Open in). Returns how many joined the library.
Future<int> addFiles(BuildContext context, WidgetRef ref, {List<PickedFile>? files}) async {
  var picked = files;
  if (picked == null) {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty) return 0;
    picked = [for (final file in result) PickedFile(name: file.name, size: file.lengthSync() ?? await file.length() ?? 0, open: file.readAsByteStream)];
  }
  if (picked.isEmpty || !context.mounted) return 0;

  // A world package takes its own way in (P2d–P2f, P10); the other files are read on the sheet.
  final packages = <PickedFile>[];
  final rest = <PickedFile>[];
  for (final file in picked) {
    (await isWorldPackage(file) ? packages : rest).add(file);
  }
  var added = 0;
  var another = false;
  for (final package in packages) {
    if (!context.mounted) break;
    final outcome = await addPackage(context, ref, package);
    if (outcome == PackageOutcome.added) added++;
    if (outcome == PackageOutcome.chooseAnother) another = true;
  }

  if (rest.isNotEmpty && context.mounted) {
    final importer = await ref.read(fileImporterProvider.future);
    if (context.mounted) {
      added +=
          await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            useRootNavigator: true,
            isDismissible: false,
            enableDrag: false,
            builder: (context) => _AddSheet(importer: importer, files: rest, resolve: importer.store.resolve),
          ) ??
          0;
    }
  }
  // The picker's own temporary copies are no longer needed once the library holds its own.
  if (files == null && Platform.isAndroid) await FilePicker.clearTemporaryFiles();
  // Once anything is in the library, later opens land on Home rather than first open (P8a).
  if (added > 0) await ref.read(settingsProvider.notifier).change((settings) => settings.copyWith(seenFirstOpen: true));
  // Choose another file (P2f) is the picker again.
  if (another && context.mounted) return added + await addFiles(context, ref);
  return added;
}

class _AddSheet extends StatefulWidget {
  const _AddSheet({required this.importer, required this.files, required this.resolve});

  final FileImporter importer;
  final List<PickedFile> files;
  final String Function(String relative) resolve;

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  List<AddCandidate>? _candidates;
  int _done = 0;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    widget.importer.read(widget.files, onProgress: (done, total) => mounted ? setState(() => _done = done) : null).then((candidates) {
      if (mounted) {
        setState(() => _candidates = candidates);
      } else {
        widget.importer.discard(candidates);
      }
    });
  }

  Future<void> _close({required bool add}) async {
    final candidates = _candidates;
    if (candidates == null) return;
    setState(() => _adding = true);
    final count = add ? await widget.importer.add(candidates) : 0;
    if (!add) await widget.importer.discard(candidates);
    if (mounted) Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    final candidates = _candidates;
    final readable = candidates?.whereType<Readable>().length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('Add', style: text.titleMedium)),
                Text(
                  candidates == null ? '$_done of ${widget.files.length}' : '${widget.files.length} ${widget.files.length == 1 ? 'file' : 'files'}',
                  style: text.bodyMedium?.copyWith(color: surface.mutedForeground),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (candidates == null)
                  for (final file in widget.files) _row(context, title: file.name, line: formatBytes(file.size), trailing: const _Spinner())
                else
                  for (final candidate in candidates)
                    switch (candidate) {
                      Readable(:final item) => _row(
                        context,
                        title: item.title,
                        line: rowLine(item),
                        cover: item.cover == null ? null : File(widget.resolve(item.cover!)),
                        item: item,
                        trailing: Icon(Icons.check, size: 20, color: surface.foreground),
                      ),
                      Refused(:final name, :final clause) => _row(
                        context,
                        title: name,
                        line: clause,
                        dim: true,
                        trailing: const Icon(Icons.warning_amber_rounded, size: 20, color: ArkeColors.warning),
                      ),
                    },
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (readable > 0)
                  FilledButton(
                    onPressed: _adding ? null : () => _close(add: true),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress)),
                    child: Text(addLabel(candidates!)),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _adding || candidates == null ? null : () => _close(add: false),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(ArkeSizes.widePress), foregroundColor: surface.foreground),
                  child: Text(readable > 0 ? 'Cancel' : 'Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, {required String title, required String line, required Widget trailing, File? cover, LibraryItem? item, bool dim = false}) {
    final text = Theme.of(context).textTheme;
    final surface = context.surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (item != null)
            FileThumb(item: item, cover: cover, width: 52, height: 52)
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: surface.secondary, borderRadius: BorderRadius.circular(ArkeRadius.md)),
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
                  style: text.bodyMedium?.copyWith(fontSize: ArkeType.sizeBase, color: dim ? surface.mutedForeground : null),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: surface.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
