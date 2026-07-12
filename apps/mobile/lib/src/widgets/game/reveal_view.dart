import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'leaderboard_list.dart';

/// Between-question reveal, did you get it, how many points, where you stand.
class RevealView extends StatelessWidget {
  const RevealView({
    super.key,
    required this.correctChoice,
    required this.myChoice,
    required this.options,
    required this.board,
    required this.myWallet,
  });
  final int? correctChoice;
  final int? myChoice;
  final List<String> options;
  final List<LeaderboardEntry> board;
  final String myWallet;

  @override
  Widget build(BuildContext context) {
    final answered = myChoice != null;
    final correct = answered && myChoice == correctChoice;
    final myRow = board.where((e) => e.wallet == myWallet).cast<LeaderboardEntry?>().firstWhere((_) => true, orElse: () => null);
    final delta = myRow?.delta ?? 0;

    final Color verdictColor = correct ? QC.winGreen : (answered ? QC.danger : QC.muted);
    final String verdictText = correct ? 'Correct!' : (answered ? 'Not quite' : 'Time’s up');
    final IconData verdictIcon = correct ? FluentIcons.checkmark_24_filled : (answered ? FluentIcons.dismiss_24_filled : FluentIcons.timer_off_24_filled);
    final correctAns = (correctChoice != null && correctChoice! < kAnswers.length) ? kAnswers[correctChoice!] : null;
    final correctLabel = (correctChoice != null && correctChoice! < options.length) ? options[correctChoice!] : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: verdictColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(verdictIcon, color: verdictColor, size: 40),
              ).animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              Text(verdictText, style: QText.h1(context).copyWith(color: verdictColor)),
              if (correct && delta > 0)
                Text('+$delta', style: QText.h2(context).copyWith(color: QC.coinB))
                    .animate().fadeIn(delay: 250.ms).slideY(begin: 0.5, end: 0),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (correctAns != null && !correct)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: ShapeDecoration(gradient: correctAns.gradient, shape: QC.squircle(QC.rBig)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(correctAns.glyph, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(correctLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 22),
        Text('Leaderboard', style: QText.title(context)),
        const SizedBox(height: 12),
        Expanded(child: LeaderboardList(board: board, myWallet: myWallet)),
      ],
    );
  }
}
