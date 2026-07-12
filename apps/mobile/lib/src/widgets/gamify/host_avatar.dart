import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../theme/tokens.dart';

/// Q - the host persona. Defaults to a procedural spotlight-gradient disc (no art dependency);
/// pass [imagePath] once real host art exists and it takes over entirely. See docs/DESIGN.md §4.
class HostAvatar extends StatelessWidget {
  const HostAvatar({super.key, this.size = 44, this.imagePath, this.live = true});
  final double size;
  final String? imagePath;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: QC.primaryGrad,
        boxShadow: [BoxShadow(color: QC.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
        image: imagePath == null ? null : DecorationImage(image: AssetImage(imagePath!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: imagePath != null
          ? null
          : Icon(FluentIcons.person_voice_24_filled, color: Colors.white, size: size * 0.5),
    );
    if (!live) return disc;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        disc,
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(color: QC.winGreen, shape: BoxShape.circle, border: Border.all(color: QC.night, width: 2)),
          ),
        ),
      ],
    );
  }
}
