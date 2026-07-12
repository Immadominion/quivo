import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// The live question, countdown ring, prompt, and four candy answer tiles.
class QuestionView extends StatefulWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.deadline,
    required this.myChoice,
    required this.totalQuestions,
    required this.onPick,
  });
  final QuestionPublic question;
  final DateTime? deadline;
  final int? myChoice;
  final int? totalQuestions;
  final void Function(int choice) onPick;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  Timer? _ticker;
  double _fraction = 1; // 1 → full time left, 0 → expired
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
    _tick();
  }

  @override
  void didUpdateWidget(QuestionView old) {
    super.didUpdateWidget(old);
    if (old.question.index != widget.question.index) _tick();
  }

  void _tick() {
    final dl = widget.deadline;
    if (dl == null) return;
    final total = widget.question.durationMs;
    final remain = dl.difference(DateTime.now()).inMilliseconds.clamp(0, total);
    final f = total == 0 ? 0.0 : remain / total;
    if (mounted) {
      setState(() {
        _fraction = f.toDouble();
        _secondsLeft = (remain / 1000).ceil();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final answered = widget.myChoice != null;
    final urgent = _secondsLeft <= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QChip(index: q.index, total: widget.totalQuestions),
            _CountdownRing(fraction: _fraction, seconds: _secondsLeft, urgent: urgent),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              child: Text(
                q.prompt,
                textAlign: TextAlign.center,
                style: QText.h1(context).copyWith(height: 1.15),
              ),
            ),
          ).animate(key: ValueKey(q.index)).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 4,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (var i = 0; i < q.options.length; i++)
                _AnswerTile(
                  answer: kAnswers[i % kAnswers.length],
                  label: q.options[i],
                  selected: widget.myChoice == i,
                  dimmed: answered && widget.myChoice != i,
                  onTap: answered ? null : () => widget.onPick(i),
                ).animate().fadeIn(delay: (60 * i).ms, duration: 300.ms).scale(begin: const Offset(0.9, 0.9)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: answered ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Text('Locked in - hang tight ⚡', style: QText.body(context).copyWith(fontWeight: FontWeight.w800, color: QC.primaryText)),
          ),
        ),
      ],
    );
  }
}

class _QChip extends StatelessWidget {
  const _QChip({required this.index, this.total});
  final int index;
  final int? total;
  @override
  Widget build(BuildContext context) {
    final label = total != null ? 'Q${index + 1} / $total' : 'Q${index + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(color: Colors.white.withValues(alpha: 0.65), shape: QC.squircle(QC.rBig)),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: QC.ink, fontSize: 15)),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.fraction, required this.seconds, required this.urgent});
  final double fraction;
  final int seconds;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final color = urgent ? QC.danger : QC.primary;
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(
        painter: _RingPainter(fraction: fraction, color: color),
        child: Center(
          child: Text(
            '$seconds',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color),
          ),
        ),
      ),
    ).animate(target: urgent ? 1 : 0).scaleXY(end: 1.12, duration: 400.ms, curve: Curves.easeInOut);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 3;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = Colors.white.withValues(alpha: 0.5);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

class _AnswerTile extends StatefulWidget {
  const _AnswerTile({required this.answer, required this.label, required this.selected, required this.dimmed, this.onTap});
  final QAnswer answer;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  State<_AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<_AnswerTile> {
  double _s = 1;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Answer: ${widget.label}',
      child: GestureDetector(
      onTapDown: on ? (_) => setState(() => _s = 0.94) : null,
      onTapUp: on ? (_) => setState(() => _s = 1) : null,
      onTapCancel: on ? () => setState(() => _s = 1) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: widget.selected ? 1.03 : _s,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: widget.dimmed ? 0.4 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            decoration: ShapeDecoration(
              gradient: widget.answer.gradient,
              shadows: [BoxShadow(color: widget.answer.solid.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))],
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(cornerRadius: QC.rTile, cornerSmoothing: 0.6),
                side: widget.selected ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.answer.glyph, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    if (widget.selected) const Icon(FluentIcons.checkmark_circle_24_filled, color: Colors.white, size: 24),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1.1),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
