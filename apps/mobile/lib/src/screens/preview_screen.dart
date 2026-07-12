import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/game_controller.dart';
import '../data/wallet.dart';
import '../debug/previews.dart';
import '../theme/app_theme.dart';
import '../widgets/atoms.dart';

/// Debug-only harness: pushes fabricated game states through the real GameController + views so
/// every phase can be reviewed and screenshotted without the live stack. Not linked in release.
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myWallet = ref.watch(walletProvider).value?.address ?? 'ME';
    final previews = buildPreviews(myWallet);

    return GroundScaffold(
      child: ListView(
        children: [
          Text('Preview', style: QText.h1(context)),
          Text('Debug-only - render each game phase.', style: QText.muted(context)),
          const SizedBox(height: 20),
          for (final entry in previews.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PillButton(
                label: entry.value.label,
                onTap: () {
                  ref.read(gameControllerProvider.notifier).debugLoad(entry.value.state, myWallet: myWallet);
                  context.push('/play');
                },
              ),
            ),
        ],
      ),
    );
  }
}
