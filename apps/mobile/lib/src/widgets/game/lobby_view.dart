import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../atoms.dart';
import '../gamify/host_card.dart';

/// Pre-game lobby, the code, who's here, and a gentle "waiting for the host" state.
class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.code, required this.players, required this.myName});
  final String? code;
  final List<PlayerLite> players;
  final String myName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Center(child: Text('You’re in!', style: QText.h1(context))),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'GAME ${code ?? ''}',
            style: QText.mono(context).copyWith(fontWeight: FontWeight.w900, letterSpacing: 3, color: QC.primaryText),
          ),
        ),
        const SizedBox(height: 20),
        HostCard(line: _lobbyHypeLine(players.length), live: true),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Waiting for the host - the game starts on the big screen.',
            textAlign: TextAlign.center,
            style: QText.muted(context),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text('Players', style: QText.title(context)),
            const SizedBox(width: 8),
            _CountPill(players.length),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: players.isEmpty
              ? Center(child: Text('Gathering players…', style: QText.muted(context)))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: players.length,
                  itemBuilder: (context, i) {
                    final p = players[i];
                    final me = p.name == myName;
                    return Column(
                      children: [
                        PlayerAvatar(seed: '${p.name}$i', size: 52, initial: p.name),
                        const SizedBox(height: 6),
                        Text(
                          me ? 'You' : p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: QText.body(context).copyWith(
                            fontWeight: me ? FontWeight.w900 : FontWeight.w700,
                            color: me ? QC.primaryText : QC.body,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: (40 * i).ms, duration: 260.ms).scale(begin: const Offset(0.8, 0.8));
                  },
                ),
        ),
      ],
    );
  }
}

/// Q's pre-game hype line, references the live player count when it reads naturally.
String _lobbyHypeLine(int n) {
  if (n <= 0) return "Seats are open, mic's hot. First one in gets the front row.";
  if (n == 1) return "One player in already - somebody's eager. Don't blink, questions come fast.";
  if (n < 6) return "$n players in and counting. Don't blink - questions come fast.";
  if (n < 15) return "$n players warming up in here. Get your thumbs ready, it's about to get loud.";
  return "$n players packed in and buzzing. Biggest lobby I've seen all night - let's give them a show.";
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.n);
  final int n;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: ShapeDecoration(gradient: QC.primaryGrad, shape: QC.squircle(QC.rBig)),
      child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
    );
  }
}
