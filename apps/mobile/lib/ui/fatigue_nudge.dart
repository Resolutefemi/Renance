/// Fatigue nudge (ROADMAP #6), the Stitch fatigue_nudge_light overlay.
///
/// A soft veil over the exam with the RenanceMark anchor and a gentle
/// card: "Your pace is dipping", one Take 5 button (pauses the exam clock
/// for five minutes) and a quiet "Keep going" dismissal. Presentation
/// only, every decision lives in ExamController's pure signal.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'renance_logo.dart';
import 'theme.dart';

/// Shows the nudge card over [child] when [visible] is true.
class FatigueNudgeOverlay extends StatelessWidget {
  const FatigueNudgeOverlay({
    super.key,
    required this.visible,
    required this.child,
    required this.reasons,
    required this.onTakeBreak,
    required this.onKeepGoing,
  });

  final bool visible;
  final Widget child;
  final List<String> reasons;
  final VoidCallback onTakeBreak;
  final VoidCallback onKeepGoing;

  /// First reason the signal offers, else the design's default line.
  String get _reason =>
      reasons.isNotEmpty ? reasons.first : 'Your pace is dipping';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        if (visible)
          Positioned.fill(
            child: ColoredBox(
              // Light veil in light/mixed (the Stitch fatigue_nudge_light
              // look); a dark veil in the dark tier so the pause reads as
              // a dim, not a flash-bang.
              color: context.isDarkTier
                  ? Colors.black.withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.92),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                // The veil paints above the exam scaffold, outside any
                // Material; give the card its own so text and buttons
                // keep their ink/splash behavior.
                child: Material(
                  type: MaterialType.transparency,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const RenanceMark(size: 64),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(24),
                            constraints: const BoxConstraints(maxWidth: 340),
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x14141C2D),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text('Your pace is dipping',
                                    textAlign: TextAlign.center,
                                    style: RenanceText.sectionTitle
                                        .copyWith(color: context.ink)),
                                const SizedBox(height: 8),
                                Text(
                                  '$_reason. A 5-minute break now protects '
                                  'your streak and helps you retain what '
                                  'you\'ve learned.',
                                  textAlign: TextAlign.center,
                                  style: RenanceText.bodySecondary.copyWith(
                                    height: 1.5,
                                    color: context.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: onTakeBreak,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Take 5'),
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: TextButton(
                                    onPressed: onKeepGoing,
                                    child: Text('Keep going',
                                        style: RenanceText.bodyBase.copyWith(
                                            color: context.textSecondary)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
