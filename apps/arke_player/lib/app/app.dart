import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../features/add_file/domain/added_file.dart';
import '../features/add_file/presentation/add_flow.dart';
import 'router/router.dart';
import 'router/routes.dart';
import 'theme/arke_theme.dart';

/// The app: the router and the two themes (the shelves follow the phone's light or dark), and the
/// files the system hands over through Share to Arke Player and Open in, which go through the same
/// reading as Add a file (P7 rule 3).
class ArkePlayerApp extends ConsumerStatefulWidget {
  const ArkePlayerApp({this.receiveShares = true, super.key});

  /// Off in tests, which have no platform to hand files over.
  final bool receiveShares;

  @override
  ConsumerState<ArkePlayerApp> createState() => _ArkePlayerAppState();
}

class _ArkePlayerAppState extends ConsumerState<ArkePlayerApp> {
  StreamSubscription<List<SharedMediaFile>>? _shares;

  @override
  void initState() {
    super.initState();
    if (!widget.receiveShares) return;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Arke Player',
    debugShowCheckedModeBanner: false,
    theme: arkeTheme(Brightness.light),
    darkTheme: arkeTheme(Brightness.dark),
    routerConfig: ref.watch(routerProvider),
  );
}
