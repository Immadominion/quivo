import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../atoms.dart';
import '../gamify/gamify_atoms.dart';
import '../gamify/night_card.dart';
import '../gamify/podium.dart';

/// The money moment, podium, your winnings counting up, and the on-chain receipt.
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.board,
    required this.settlement,
    required this.myWallet,
    required this.onShare,
    required this.onHome,
  });
  final List<LeaderboardEntry> board;
  final Settlement? settlement;
  final String myWallet;
  final VoidCallback onShare;
  final VoidCallback onHome;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (_iWon) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !MediaQuery.disableAnimationsOf(context)) _confetti.play();
      });
    }
  }

  bool get _iWon => _myPayout != null;

  WinnerPayout? get _myPayout {
    final s = widget.settlement;
    if (s == null) return null;
    for (final w in s.winners) {
      if (w.wallet == widget.myWallet) return w;
    }
    return null;
  }

  LeaderboardEntry? get _myEntry {
    final i = widget.board.indexWhere((e) => e.wallet == widget.myWallet);
    return i >= 0 ? widget.board[i] : null;
  }

  int get _myRank => _myEntry?.rank ?? widget.board.length;
  int get _myScore => _myEntry?.score ?? 0;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top3 = widget.board.take(3).toList();
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: math.pi / 2,
            emissionFrequency: 0.05,
            numberOfParticles: 24,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            colors: const [QC.coinA, QC.coinB, QC.primary, QC.winGreen, QC.winPurpleA],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // The verdict, dark "money moment" card, glow color-coded by outcome.
                    NightCard(
                      glow: _iWon ? QC.coinB : QC.danger,
                      glowAlignment: Alignment.topRight,
                      child: _iWon ? _WinningsBlock(payout: _myPayout!, rank: _myRank, score: _myScore) : _PlacementBlock(rank: _myRank, total: widget.board.length, score: _myScore),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
                    if (top3.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      NightCard(
                        glow: QC.coinB,
                        glowAlignment: Alignment.topLeft,
                        child: Podium(top3: top3, myWallet: widget.myWallet),
                      ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: 0.06, end: 0),
                    ],
                    const SizedBox(height: 14),
                    if (widget.settlement != null) _ProofRow(settlement: widget.settlement!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Share',
                    gradient: QC.winPurpleGrad,
                    rgb: QC.winPurpleB,
                    leading: const Icon(FluentIcons.share_ios_24_filled, color: Colors.white, size: 20),
                    onTap: widget.onShare,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: PillButton(label: 'Home', onTap: widget.onHome)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The big score/prize block inside the verdict NightCard, win case. Reference: the "Verdict"
/// card's big score + host one-liner + stat trio. See docs/DESIGN.md §2.6.
class _WinningsBlock extends StatelessWidget {
  const _WinningsBlock({required this.payout, required this.rank, required this.score});
  final WinnerPayout payout;
  final int rank;
  final int score;

  @override
  Widget build(BuildContext context) {
    final mutedOnDark = QText.muted(context).copyWith(color: Colors.white.withValues(alpha: 0.6));
    return Column(
      children: [
        Text('You won! 🎉', style: QText.h1(context).copyWith(color: Colors.white)),
        const SizedBox(height: 16),
        const Coin(size: 44),
        const SizedBox(height: 10),
        Text('Your prize', style: mutedOnDark),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: payout.usdc),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            '${v.toStringAsFixed(2)} USDC',
            style: QText.mono(context, size: 40, weight: FontWeight.w800, color: QC.coinA),
          ),
        ),
        const SizedBox(height: 4),
        Text('Paid straight to your wallet', style: mutedOnDark),
        const SizedBox(height: 20),
        StatTrio(
          dark: true,
          items: [
            ('RANK', '#$rank', null),
            ('PTS', '$score', null),
            ('PRIZE', payout.usdc.toStringAsFixed(2), QC.coinA),
          ],
        ),
      ],
    );
  }
}

/// The big score block inside the verdict NightCard, placed-outside-the-money case.
class _PlacementBlock extends StatelessWidget {
  const _PlacementBlock({required this.rank, required this.total, required this.score});
  final int rank;
  final int total;
  final int score;

  @override
  Widget build(BuildContext context) {
    final mutedOnDark = QText.muted(context).copyWith(color: Colors.white.withValues(alpha: 0.6));
    return Column(
      children: [
        Text('Good game!', style: QText.h1(context).copyWith(color: Colors.white)),
        const SizedBox(height: 10),
        Text('You placed', style: mutedOnDark),
        const SizedBox(height: 2),
        Text('#$rank', style: QText.mono(context, size: 44, weight: FontWeight.w800, color: Colors.white)),
        Text('of $total players', style: mutedOnDark),
        const SizedBox(height: 10),
        Text(
          'So close, get the next one 💪',
          style: QText.body(context).copyWith(color: Colors.white.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 20),
        StatTrio(
          dark: true,
          items: [
            ('RANK', '#$rank', null),
            ('PTS', '$score', null),
          ],
        ),
      ],
    );
  }
}

/// The receipt, proves the payout happened on-chain, linking to Solana Explorer.
class _ProofRow extends StatelessWidget {
  const _ProofRow({required this.settlement});
  final Settlement settlement;

  Future<void> _open() async {
    final uri = Uri.parse('$kExplorerTx${settlement.txSig}$kCluster');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final real = settlement.isReal;
    final sig = settlement.txSig;
    final shortSig = sig.length > 14 ? '${sig.substring(0, 6)}…${sig.substring(sig.length - 6)}' : sig;
    return GestureDetector(
      onTap: real ? _open : () => Clipboard.setData(ClipboardData(text: sig)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: ShapeDecoration(
          color: QC.winGreen.withValues(alpha: 0.10),
          shape: QC.squircle(QC.rTile),
        ),
        child: Row(
          children: [
            const Icon(FluentIcons.shield_checkmark_24_filled, color: QC.winGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settled on Solana', style: QText.body(context).copyWith(fontWeight: FontWeight.w900, color: QC.winGreen)),
                  Text(shortSig, style: QText.mono(context).copyWith(fontSize: 13, color: QC.body)),
                ],
              ),
            ),
            Icon(real ? FluentIcons.open_24_regular : FluentIcons.copy_24_regular, color: QC.winGreen, size: 18),
          ],
        ),
      ),
    );
  }
}
