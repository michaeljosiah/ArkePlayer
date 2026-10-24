import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../features/add_file/domain/added_file.dart';
import '../features/add_file/presentation/add_flow.dart';
import '../features/parts/application/notices.dart';
import '../features/parts/application/parts.dart';
import '../features/settings/application/settings_controller.dart';
import '../features/worlds/application/worlds.dart';
import 'router/router.dart';
import 'router/routes.dart';
import 'theme/arke_theme.dart';

/// The app: the router and the two themes (the shelves follow the phone's light or dark), and the
/// files the system hands over through Share to Arke Player and Open in, which go through the same
/// reading as Add a file (P7 rule 3). It brings a world's new chapters when it opens or comes back,
/// and when Arke's list changes (SPEC-058 R-51), and keeps the daily check scheduled while any
/// world's Notify is on (R-54).
class ArkePlayerApp extends ConsumerStatefulWidget {
  const ArkePlayerApp({this.receiveShares = true, super.key});

  /// Off in tests, which have no platform to hand files over, nor parts to bring.
  final bool receiveShares;

  @override
  ConsumerState<ArkePlayerApp> createState() => _ArkePlayerAppState();
}

class _ArkePlayerAppState extends ConsumerState<ArkePlayerApp> {
  StreamSubscription<List<SharedMediaFile>>? _shares;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    if (!widget.receiveShares) return;
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(partsProvider.notifier).check());
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(partsProvider.notifier).check());
    final intake = ReceiveSharingIntent.instance;
    _shares = intake.getMediaStream().listen(_received, onError: (Object _) {});
    intake.getInitialMedia().then((files) {
      _received(files);
      intake.reset();
    });
  }

  Future<void> _received(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final router = ref.read(routerProvider);
    // Files arrive over whatever is showing; they are read on Home, never over a player.
    router.go(Routes.home);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await addFiles(context, ref, files: [for (final file in files) PickedFile.path(file.path)]);
  }

  @override
  void dispose() {
    _shares?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.receiveShares) {
      ref.listen(catalogueProvider, (previous, next) {
        if (next.hasValue && previous?.value != next.value) ref.read(partsProvider.notifier).check();
      });
      ref.listen(settingsProvider, (previous, next) {
        final (before, after) = (previous?.value, next.value);
        if (after == null || (before != null && before.wifiOnly == after.wifiOnly && setEquals(before.notify, after.notify))) return;
        scheduleDailyCheck(after).catchError((Object _) {});
        // Wi-Fi only turned off lets what waited come now.
        if (before != null && before.wifiOnly && !after.wifiOnly) ref.read(partsProvider.notifier).check();
      });
    }
    return _app();
  }

  Widget _app() => MaterialApp.router(
    title: 'Arke Player',
    debugShowCheckedModeBanner: false,
    theme: arkeTheme(Brightness.light),
    darkTheme: arkeTheme(Brightness.dark),
    routerConfig: ref.watch(routerProvider),
  );
}
