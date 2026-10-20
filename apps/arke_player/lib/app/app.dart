import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';
import 'theme/arke_theme.dart';

/// The app: the router and the two themes. The shelves follow the phone's light or dark.
class ArkePlayerApp extends ConsumerWidget {
  const ArkePlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Arke Player',
    debugShowCheckedModeBanner: false,
    theme: arkeTheme(Brightness.light),
    darkTheme: arkeTheme(Brightness.dark),
    routerConfig: ref.watch(routerProvider),
  );
}
