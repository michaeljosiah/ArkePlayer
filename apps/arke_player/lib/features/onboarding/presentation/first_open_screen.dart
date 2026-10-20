import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/widgets/frame_placeholder.dart';

/// First open: the wordmark over a world's picture and two presses; no tour.
class FirstOpenScreen extends StatelessWidget {
  const FirstOpenScreen({super.key});

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: 'Arke Player',
    frames: const ['P1a'],
    media: true,
    actions: [
      FilledButton(onPressed: () => context.go(Routes.home), child: const Text('Sign in with Arke ↗')),
      OutlinedButton(onPressed: () => context.push(Routes.add), child: const Text('Add a file')),
    ],
  );
}
