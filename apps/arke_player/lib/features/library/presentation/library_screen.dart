import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/widgets/frame_placeholder.dart';

/// Every world, All · Shared · Added, then Files; + adds a file.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: 'Library',
    frames: const ['P1c', 'P2g', 'P7b'],
    actions: [
      OutlinedButton(onPressed: () => context.push(Routes.add), child: const Text('+')),
      FilledButton(onPressed: () => context.go(Routes.world('the-undersong')), child: const Text('The Undersong')),
    ],
  );
}
