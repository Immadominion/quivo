import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'host_avatar.dart';
import 'night_card.dart';

/// The host commentary card - Q hypes/teases the player. Short (1-2 sentences), never mean.
/// Reference: Touchline's "Gaffer" persona card, reskinned. See docs/DESIGN.md §2.1.
class HostCard extends StatelessWidget {
  const HostCard({super.key, required this.line, this.ctaLabel, this.onTap, this.hostImagePath});
  final String line;
  final String? ctaLabel;
  final VoidCallback? onTap;
  final String? hostImagePath;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      glow: QC.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HostAvatar(size: 46, imagePath: hostImagePath),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Q', style: QText.overline(context, color: const Color(0xFFCDB8FF)).copyWith(letterSpacing: 1.4)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        // Chip is a full pill (radius exceeds half its height) - stays circular
                        // per docs/DESIGN.md §1: "a pill has no corner for a squircle to smooth".
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.flash_16_filled, size: 11, color: Color(0xFF8FE7B0)),
                            const SizedBox(width: 3),
                            Text('on Solana', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('your host', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            line,
            style: const TextStyle(fontFamily: 'Satoshi', fontSize: 15.5, height: 1.42, fontWeight: FontWeight.w500, color: Color(0xFFEDE6FA)),
          ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                // Full pill CTA (radius exceeds half its height) - stays circular, same
                // exemption as PillButton in atoms.dart.
                decoration: BoxDecoration(gradient: QC.primaryGrad, borderRadius: BorderRadius.circular(30)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ctaLabel!, style: const TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Icon(FluentIcons.arrow_up_right_16_filled, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }
}
