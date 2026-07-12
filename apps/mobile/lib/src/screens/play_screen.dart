import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../data/game_controller.dart';
import '../data/history.dart';
import '../data/models.dart';
import '../data/prefs.dart';
import '../data/wallet.dart';
import '../util/feedback.dart';
import '../widgets/atoms.dart';
import '../widgets/game/lobby_view.dart';
import '../widgets/game/question_view.dart';
import '../widgets/game/reveal_view.dart';
import '../widgets/game/results_view.dart';
import '../widgets/game/status_views.dart';

/// Single host screen for the whole live session - swaps sub-views by game phase, keeps one
/// gateway connection alive across the whole loop, and drives haptics on the transitions.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});
  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  GamePhase? _lastPhase;
  int? _lastRevealIndex;

  void _onPick(int choice) {
    buzz(ref, Buzz.select);
    ref.read(gameControllerProvider.notifier).answer(choice);
  }

  void _leave() {
    ref.read(gameControllerProvider.notifier).leave();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _reactToTransitions(GameState s) {
    // Reveal: buzz correct/wrong once per question.
    if (s.phase == GamePhase.reveal && s.question?.index != _lastRevealIndex) {
      _lastRevealIndex = s.question?.index;
      final correct = s.myChoice != null && s.myChoice == s.correctChoice;
      buzz(ref, correct ? Buzz.correct : Buzz.wrong);
    }
    if (s.phase == GamePhase.complete && _lastPhase != GamePhase.complete) {
      buzz(ref, Buzz.win);
      _recordHistory(s);
    }
    _lastPhase = s.phase;
  }

  void _recordHistory(GameState s) {
    if (s.demo) return; // preview games don't count
    final myWallet = ref.read(walletProvider).value?.address ?? '';
    double amount = 0;
    var won = false;
    for (final w in s.settlement?.winners ?? const <WinnerPayout>[]) {
      if (w.wallet == myWallet) {
        won = true;
        amount = w.usdc;
        break;
      }
    }
    ref.read(historyProvider.notifier).add(HistoryEntry(
          code: s.code ?? '',
          playedAtMs: DateTime.now().millisecondsSinceEpoch,
          rank: s.me?.rank ?? s.board.length,
          players: s.board.length,
          score: s.me?.score ?? 0,
          won: won,
          amountUsdc: amount,
          txSig: s.settlement?.txSig ?? '',
        ));
  }

  Future<void> _share(GameState s) async {
    final me = s.me;
    final line = me != null
        ? 'I placed #${me.rank} with ${me.score} pts on Quivo - live trivia, real crypto payouts ⚡'
        : 'Just played Quivo - live trivia with real crypto payouts ⚡';
    await Share.share(line);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reactToTransitions(s));
    final wallet = ref.watch(walletProvider).value;
    final myWallet = wallet?.address ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: GroundScaffold(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: KeyedSubtree(key: ValueKey(_viewKey(s)), child: _body(s, myWallet)),
            ),
            if (s.reconnecting)
              const Positioned(top: 8, left: 0, right: 0, child: Center(child: ReconnectBanner())),
          ],
        ),
      ),
    );
  }

  String _viewKey(GameState s) {
    if (s.phase == GamePhase.question) return 'q${s.question?.index}';
    if (s.phase == GamePhase.reveal) return 'r${s.question?.index}';
    return s.phase.name;
  }

  Widget _body(GameState s, String myWallet) {
    switch (s.phase) {
      case GamePhase.idle:
      case GamePhase.connecting:
        return const StatusView(title: 'Joining the game…', subtitle: 'Finding your seat');
      case GamePhase.lobby:
        return LobbyView(code: s.code, players: s.players, myName: _myName);
      case GamePhase.question:
        final q = s.question;
        if (q == null) return const StatusView(title: 'Get ready…', subtitle: 'Next question incoming');
        return QuestionView(
          question: q,
          deadline: s.questionDeadline,
          myChoice: s.myChoice,
          totalQuestions: null,
          onPick: _onPick,
        );
      case GamePhase.reveal:
        return RevealView(
          correctChoice: s.correctChoice,
          myChoice: s.myChoice,
          options: s.question?.options ?? const [],
          board: s.board,
          myWallet: myWallet,
        );
      case GamePhase.settling:
        return const StatusView(title: 'Paying out winners…', subtitle: 'Settling the pot on Solana');
      case GamePhase.complete:
        return ResultsView(
          board: s.board,
          settlement: s.settlement,
          myWallet: myWallet,
          onShare: () => _share(s),
          onHome: _leave,
        );
      case GamePhase.error:
        return ErrorView(message: s.error ?? 'Something went wrong.', onLeave: _leave);
    }
  }

  // The lite player payload carries no wallet, so the lobby marks "You" by matching this name.
  String get _myName {
    final n = ref.read(prefsProvider).value?.name ?? '';
    return n.isNotEmpty ? n : 'player';
  }
}
