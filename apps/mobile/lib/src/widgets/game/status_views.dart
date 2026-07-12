import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../atoms.dart';

/// Centered status with a spinning coin, used for "Joining…" and "Paying winners…".
class StatusView extends StatelessWidget {
  const StatusView({super.key, required this.title, this.subtitle, this.spinCoin = true});
  final String title;
  final String? subtitle;
  final bool spinCoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Coin(size: 56, spin: spinCoin),
          const SizedBox(height: 22),
          Text(title, style: QText.h2(context), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: QText.muted(context), textAlign: TextAlign.center),
          ],
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

/// Terminal error card with retry / leave.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, required this.onLeave});
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: QCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: QC.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(FluentIcons.wifi_off_24_filled, color: QC.danger, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Couldn’t connect', style: QText.title(context)),
            const SizedBox(height: 8),
            Text(message, style: QText.muted(context), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (onRetry != null) ...[
              PillButton(label: 'Try again', big: true, onTap: onRetry),
              const SizedBox(height: 10),
            ],
            TextButton(onPressed: onLeave, child: Text('Leave', style: QText.muted(context))),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.94, 0.94)),
    );
  }
}

/// Slim banner shown over live play while the socket is re-establishing.
class ReconnectBanner extends StatelessWidget {
  const ReconnectBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(color: QC.night.withValues(alpha: 0.85), shape: QC.squircle(QC.rBig)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text('Reconnecting…', style: QText.body(context).copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 700.ms);
  }
}
