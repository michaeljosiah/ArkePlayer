import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../add_file/presentation/add_flow.dart';

/// First open, before sign-in exists (P8a): the wordmark over the app's own picture and one press,
/// Add a file. No tour, no sentence, no Sign in (P8 rules 1–2).
class FirstOpenScreen extends ConsumerWidget {
  const FirstOpenScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await addFiles(context, ref);
    if (added == 0 || !context.mounted) return;
    if (context.mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fg = ArkeColors.mediaOverlayForeground;
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: ArkeColors.mediaOverlayBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height * 0.66,
            child: Image.asset('assets/images/first-open.jpg', fit: BoxFit.cover, alignment: const Alignment(0, -0.2)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [ArkeColors.mediaOverlayBackground, ArkeColors.mediaOverlayBackground, Color(0x000A0A0A)],
                stops: [0, 0.34, 0.72],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.12),
            child: Semantics(
              label: 'Arke Player',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The wordmark is Jost at 200 with wide tracking, as on the Studio's launch surface.
                    const Padding(
                      padding: EdgeInsets.only(left: ArkeType.size4xl * 0.52),
                      child: Text(
                        'ARKE',
                        style: TextStyle(
                          fontFamily: ArkeType.wordmarkFamily,
                          fontWeight: FontWeight.w200,
                          fontSize: ArkeType.size4xl,
                          letterSpacing: ArkeType.size4xl * 0.52,
                          color: fg,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: ArkeType.sizeXs * 0.42),
                      child: Text(
                        'PLAYER',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: ArkeType.sizeXs,
                          letterSpacing: ArkeType.sizeXs * 0.42,
                          color: fg.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20 + MediaQuery.paddingOf(context).bottom,
            child: FilledButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a file'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(ArkeSizes.widePress),
                backgroundColor: fg,
                foregroundColor: ArkeColors.mediaOverlayBackground,
                textStyle: const TextStyle(fontSize: ArkeType.sizeBase, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
