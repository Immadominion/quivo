import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Plays a bundled .riv asset with the current (0.14) Rive runtime. Uses the Flutter renderer so
/// there's no platform-view/texture setup, and auto-plays the default artboard + state machine.
/// The 0.13 runtime is not an option here: it crashes on newer editor fill rules (see fast.riv).
class RiveIllustration extends StatefulWidget {
  const RiveIllustration(this.asset, {super.key, this.fit = Fit.contain});
  final String asset;
  final Fit fit;

  @override
  State<RiveIllustration> createState() => _RiveIllustrationState();
}

class _RiveIllustrationState extends State<RiveIllustration> {
  late final FileLoader _loader = FileLoader.fromAsset(widget.asset, riveFactory: Factory.flutter);

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RiveWidgetBuilder(
      fileLoader: _loader,
      builder: (context, state) {
        if (state is RiveLoaded) {
          return RiveWidget(controller: state.controller, fit: widget.fit);
        }
        // Loading or failed: take up the same space silently, no spinner or error box.
        return const SizedBox.expand();
      },
    );
  }
}
