import 'package:flutter/material.dart';

import '../../../app/widgets/frame_placeholder.dart';

/// A share link: the world, who shared it, Open or Sign in with Arke ↗.
class ShareLinkScreen extends StatelessWidget {
  const ShareLinkScreen({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context) => const FramePlaceholder(title: 'Shared with you', frames: ['P2a', 'P2b']);
}
