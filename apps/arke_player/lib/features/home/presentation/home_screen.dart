import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/widgets/frame_placeholder.dart';

/// Home is for going on: Continue, New, Worlds; offline, what is on the phone.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => FramePlaceholder(
    title: 'Home',
    frames: const ['P1b', 'P6d'],
    actions: [FilledButton(onPressed: () => context.push(Routes.play('saltlight')), child: const Text('Continue'))],
  );
}
