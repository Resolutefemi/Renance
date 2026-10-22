/// The celebration stack - the Flutter twins of the web's
/// components/learn/celebrations.tsx + bits.tsx ConfettiBurst:
/// the confetti burst, the full-screen chest opening (shake -> open ->
/// spin -> reward), the streak celebration flame and the shareable
/// milestone card. Timing constants match the web exactly.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../learn_models.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'tactile.dart';
import 'theme.dart';

// ------------------------------------------------------------- confetti

/// 26 falling confetti pieces over a fixed band near the top, 2.4s
/// fall with random horizontal drift and a 540-degree tumble
/// (bits.tsx ConfettiBurst).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final List<_Confetto> _pieces;

  @override
  void initState() {
    super.initState();
    final math.Random rnd = math.Random();
    _pieces = List<_Confetto>.generate(26, (_) {
      return _Confetto(
        left: rnd.nextDouble(),
        delay: Duration(milliseconds: (rnd.nextDouble() * 350).round()),
        dx: (rnd.nextDouble() * 2 - 1) * 40,
        color: kConfettiColors[rnd.nextInt(kConfettiColors.length)],
        size: 6 + rnd.nextDouble() * 6,
        round: rnd.nextBool(),
      );
    });
    _ctl.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (BuildContext context, Widget? _) {
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final _Confetto p in _pieces)
                AnimatedBuilder(
                  animation: _ctl,
                  builder: (BuildContext context, Widget? _) {
                    final double t =
                        (( _ctl.value * 2400 - p.delay.inMilliseconds) / 2050)
                            .clamp(0.0, 1.0);
                    if (t <= 0) return const SizedBox.shrink();
                    return Positioned(
                      left: p.left * MediaQuery.sizeOf(context).width,
                      top: 90 + t * 260,
                      child: Transform.translate(
                        offset: Offset(p.dx * t, 0),
                        child: Transform.rotate(
                          angle: t * 540 * math.pi / 180,
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              color: p.color,
                              borderRadius: p.round
                                  ? BorderRadius.circular(p.size / 2)
                                  : BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Confetto {
  const _Confetto({
    required this.left,
    required this.delay,
    required this.dx,
    required this.color,
    required this.size,
    required this.round,
  });

  final double left;
  final Duration delay;
  final double dx;
  final Color color;
  final double size;
  final bool round;
}

/// Fires a [ConfettiBurst] as an overlay above everything for 2.4s.
void showConfetti(BuildContext context) {
  final OverlayState? overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext ctx) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ConfettiBurst(onDone: () => entry.remove()),
    ),
  );
  overlay.insert(entry);
}

// --------------------------------------------------------- chest opening

/// The chest reward stages; timings are the web's exactly.
enum _ChestStage { shake, open, spin, reward }

/// Full-screen chest celebration: black/60 blurred scrim, the golden
/// chest shakes (0-900ms), the lid swings open (900-1500ms), the whole
/// chest spins and grows (1500-2600ms), then the reward chip pops with
/// confetti (2600ms+) and auto-closes at 4200ms.
class ChestOpening extends StatefulWidget {
  const ChestOpening({
    super.key,
    required this.kind,
    required this.amount,
    required this.label,
    this.onDone,
  });

  /// gems | freeze | boost
  final String kind;
  final int amount;
  final String label;
  final VoidCallback? onDone;

  @override
  State<ChestOpening> createState() => _ChestOpeningState();
}

class _ChestOpeningState extends State<ChestOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  _ChestStage _stage = _ChestStage.shake;
  bool _confettiFired = false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() {
      final int ms = (_ctl.value * 4200).round();
      _ChestStage next = _ChestStage.shake;
      if (ms >= 2600) {
        next = _ChestStage.reward;
      } else if (ms >= 1500) {
        next = _ChestStage.spin;
      } else if (ms >= 900) {
        next = _ChestStage.open;
      }
      if (next != _stage) {
        setState(() => _stage = next);
        if (next == _ChestStage.reward && !_confettiFired) {
          _confettiFired = true;
          showConfetti(context);
        }
      }
    });
    _ctl.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reward = _stage == _ChestStage.reward;
    final bool open = _stage != _ChestStage.shake;
    final bool spin = _stage == _ChestStage.spin || reward;

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // eyebrow
                Text(
                  'CHEST REWARD',
                  style: RenanceText.overline.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 18),
                // the chest
                AnimatedScale(
                  scale: spin ? 1.12 : 1,
                  duration: const Duration(milliseconds: 1050),
                  curve: Curves.easeOutBack,
                  child: AnimatedRotation(
                    turns: spin ? 1 : 0,
                    duration: const Duration(milliseconds: 1050),
                    curve: Curves.easeInOut,
                    child: _ShakingChest(
                      shaking: _stage == _ChestStage.shake,
                      lidOpen: open,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                // reward chip or the pulsing hint
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: reward
                      ? _RewardChip(
                          key: const ValueKey<String>('reward'),
                          kind: widget.kind,
                          amount: widget.amount,
                          label: widget.label,
                        )
                      : Text(
                          'Your chest is opening…',
                          key: const ValueKey<String>('hint'),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

/// The CSS chest: 118x88 golden box with the hinged lid.
class _ShakingChest extends StatefulWidget {
  const _ShakingChest({required this.shaking, required this.lidOpen});

  final bool shaking;
  final bool lidOpen;

  @override
  State<_ShakingChest> createState() => _ShakingChestState();
}

class _ShakingChestState extends State<_ShakingChest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    if (widget.shaking) _shake.repeat();
  }

  @override
  void didUpdateWidget(_ShakingChest old) {
    super.didUpdateWidget(old);
    if (widget.shaking && !old.shaking) _shake.repeat();
    if (!widget.shaking && old.shaking) _shake.stop();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (BuildContext context, Widget? child) {
        final double t = _shake.value;
        // rotate +-4deg, translateY -3px, three cycles per repeat
        final double angle = math.sin(t * math.pi * 6) * 4 * math.pi / 180;
        final double dy = widget.shaking
            ? -3 * (0.5 - 0.5 * math.cos(t * math.pi * 6))
            : 0.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: SizedBox(
        width: 118,
        height: 88,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: <Widget>[
            // body
            Positioned(
              top: 30,
              child: Container(
                width: 118,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFC8891F), Color(0xFF9A6410)],
                  ),
                  border: Border.all(color: const Color(0xFF7A4C08), width: 3),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
            // the lid, hinged at the back
            AnimatedContainer(
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, widget.lidOpen ? -4.0 : 0.0, 0.0, 0.0)
                ..rotateX(widget.lidOpen ? -104 * math.pi / 180 : 0),
              alignment: Alignment.topCenter,
              child: Container(
                width: 118,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFD99A2B), Color(0xFFB47614)],
                  ),
                  border: Border.all(color: const Color(0xFF7A4C08), width: 3),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            // the lock plate
            Positioned(
              top: 24,
              child: Container(
                width: 20,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFFFFE08A), Color(0xFFD99A2B)],
                  ),
                  border: Border.all(color: const Color(0xFF7A4C08), width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatefulWidget {
  const _RewardChip({
    super.key,
    required this.kind,
    required this.amount,
    required this.label,
  });

  final String kind;
  final int amount;
  final String label;

  @override
  State<_RewardChip> createState() => _RewardChipState();
}

class _RewardChipState extends State<_RewardChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _pop.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String icon, String sub) = switch (widget.kind) {
      'freeze' => (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
        'ac_unit',
        'Saves your streak on a rest day',
      ),
      'boost' => (
        const Color(0xFFFFF4E0),
        const Color(0xFFF59E0B),
        'bolt',
        'Every correct answer pays double',
      ),
      _ => (
        const Color(0xFFDDF4FF),
        const Color(0xFF1899D6),
        'diamond',
        'Added to your gem wallet',
      ),
    };
    return AnimatedBuilder(
      animation: _pop,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutBack.transform(_pop.value);
        return Transform.translate(
          offset: Offset(0, 26 * (1 - t)),
          child: Transform.scale(
            scale: 0.4 + 0.6 * t,
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fg.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: icon == 'diamond'
                  ? const GemIcon(size: 30)
                  : MsIcon(icon, size: 30, color: fg, fill: true),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- streak celebration

/// The Duolingo-style streak popup (founder pass VIII screenshots): a
/// full-screen dim with a centred card - the beating amber flame disc,
/// the huge count-up streak number with the 'day streak' label, the
/// 7-day week row (orange checks inside the current streak window, a
/// blue snowflake on the day a Streak Freeze saved, hollow gray dots
/// for the misses), the Perfect Streak / freeze message, and the
/// full-width blue CONTINUE key that pops the route. Confetti still
/// bursts on open (the lesson fires one too - it keeps).
class StreakCelebration extends StatefulWidget {
  const StreakCelebration({
    super.key,
    required this.streak,
    this.forgiven = false,
    this.forgivesLeft = 0,
    this.onDone,
  });

  final int streak;
  final bool forgiven;

  /// Kept for the existing call signature (lesson_overlay passes it);
  /// the new visual speaks in freezes, not restore counts.
  final int forgivesLeft;
  final VoidCallback? onDone;

  @override
  State<StreakCelebration> createState() => _StreakCelebrationState();
}

class _StreakCelebrationState extends State<StreakCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 90 * math.min(5, widget.streak)),
  );

  @override
  void initState() {
    super.initState();
    _count.forward();
    // The confetti inserts an OverlayEntry - scheduling it post-frame
    // keeps the insert out of the current build phase (an in-build
    // insert throws markNeedsBuild-during-build and would kill the
    // celebration outright).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showConfetti(context);
    });
  }

  @override
  void dispose() {
    _beat.dispose();
    _count.dispose();
    super.dispose();
  }

  /// Mo..Su initials; the row shows the LAST 7 days, oldest -> today.
  static const List<String> _weekdayLabels = <String>[
    'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su',
  ];

  @override
  Widget build(BuildContext context) {
    // The current streak window: today counts as done (the popup fires
    // right after activity), and day offset o sits inside the window
    // when o < streak. A forgiven streak paints YESTERDAY blue - the
    // day the freeze saved - instead of a check.
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final String message = widget.forgiven
        ? 'Streak Freeze saves it for you.'
        : widget.streak >= 7
            ? 'Way to earn your Perfect Streak! Can you keep it next week?'
            : 'You can get a perfect week next time by not using any Streak '
                'Freezes!';

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFF9600).withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33111C2D),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // the flame disc, beating exactly like the old cut
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                    CurvedAnimation(parent: _beat, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFFF9600), Color(0xFFFF4B4B)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFFF9600)
                              .withValues(alpha: 0.45),
                          blurRadius: 44,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: MsIcon(
                        'local_fire_department',
                        size: 54,
                        color: Colors.white,
                        fill: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // the count-up number + 'day streak' label - the founder
                // screenshots: the huge ORANGE number with 'day streak'
                // UNDER it, not beside it
                AnimatedBuilder(
                  animation: _count,
                  builder: (BuildContext context, Widget? _) {
                    final int n = (_count.value * widget.streak).round();
                    return Column(
                      children: <Widget>[
                        Text(
                          '$n',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: Color(0xFFFF9600),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'day streak',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF9600),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                // the 7-day week row, oldest -> today
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (int offset = 6; offset >= 0; offset--)
                      _WeekDay(
                        label: _weekdayLabels[
                            today.subtract(Duration(days: offset)).weekday - 1],
                        state: widget.forgiven && offset == 1
                            ? _WeekDayState.frozen
                            : offset < widget.streak
                                ? _WeekDayState.done
                                : _WeekDayState.empty,
                        isToday: offset == 0,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                TactileButton(
                  onPressed: widget.onDone,
                  height: 48,
                  // the full-width blue CONTINUE key (Duolingo #1899d6)
                  face: const Color(0xFF1899D6),
                  onFace: Colors.white,
                  child: const Text('CONTINUE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One day dot of the week row: the label over a 34px circle that is
/// either an orange check (inside the streak window), the blue
/// snowflake (saved by a Streak Freeze) or a hollow gray dot.
enum _WeekDayState { done, frozen, empty }

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.label,
    required this.state,
    this.isToday = false,
  });

  final String label;
  final _WeekDayState state;

  /// The founder screenshots: the CURRENT day carries the amber ring
  /// no matter its fill state, so the eye always lands on today.
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final Color hollow = context.outlineVariant;
    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isToday
                ? const Color(0xFFFF9600)
                : state == _WeekDayState.empty
                    ? context.textSecondary
                    : state == _WeekDayState.frozen
                        ? const Color(0xFF1899D6)
                        : const Color(0xFFFF9600),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _WeekDayState.empty
                ? Colors.transparent
                : state == _WeekDayState.frozen
                    ? const Color(0xFF1899D6)
                    : const Color(0xFFFF9600),
            border: isToday
                ? Border.all(color: const Color(0xFFFF9600), width: 2.5)
                : state == _WeekDayState.empty
                    ? Border.all(color: hollow, width: 2)
                    : null,
          ),
          child: state == _WeekDayState.empty && !isToday
              ? null
              : state == _WeekDayState.empty
                  // today, not yet studied: a hollow amber dot
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF9600),
                      ),
                    )
                  : MsIcon(
                      state == _WeekDayState.frozen ? 'ac_unit' : 'check',
                      size: 18,
                      color: Colors.white,
                      fill: true,
                    ),
        ),
        // The Duolingo 'today' caret: a small amber bar under the
        // current day (transparent spacer keeps every column aligned).
        const SizedBox(height: 4),
        Container(
          width: 16,
          height: 3.5,
          decoration: BoxDecoration(
            color: isToday ? const Color(0xFFFF9600) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------- milestone celebration

/// The shareable milestone card: achievement unlocked, the label, the
/// "posted to the feed" note, and the native share sheet.
class MilestoneCelebration extends StatefulWidget {
  const MilestoneCelebration({
    super.key,
    required this.milestone,
    this.onViewFeed,
    this.onDone,
  });

  final MilestoneInfo milestone;
  final VoidCallback? onViewFeed;
  final VoidCallback? onDone;

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration> {
  bool _shared = false;

  Future<void> _share() async {
    final String text =
        'I just earned "${widget.milestone.label}" on Renance - my study '
        'streak lives on renance.app';
    try {
      await Share.share(text, subject: 'Renance achievement');
    } catch (_) {
      // Share-sheet failures fall back quietly; the button still
      // flips to Shared! so the flow always ends.
    }
    if (mounted) setState(() => _shared = true);
  }

  @override
  Widget build(BuildContext context) {
    final String code = widget.milestone.code;
    final String icon = code.startsWith('streak')
        ? 'local_fire_department'
        : code.startsWith('course')
            ? 'school'
            : code.startsWith('league')
                ? 'emoji_events'
                : 'military_tech';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(alignment: Alignment.center,
          
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.primary.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x33111C2D),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(alignment: Alignment.center,
                
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MsIcon(icon, size: 38, color: context.primary, fill: true),
              ),
              const SizedBox(height: 16),
              Text(
                'Achievement unlocked',
                style: RenanceText.overline.copyWith(
                  color: context.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.milestone.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF131B2E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This milestone just posted to the Renance feed for your '
                'followers to see.',
                textAlign: TextAlign.center,
                style: RenanceText.bodySecondary.copyWith(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TactileButton(
                onPressed: _share,
                height: 48,
                radius: BorderRadius.circular(999),
                child: Text(_shared ? 'Shared!' : 'Share this achievement'),
              ),
              const SizedBox(height: 10),
              TactileButton(
                onPressed: widget.onViewFeed,
                height: 44,
                face: context.card,
                onFace: context.ink,
                edge: mixTowardBlack(context.outlineVariant, 0.62),
                radius: BorderRadius.circular(999),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                child: const Text('View it in the feed'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onDone,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- route helpers

/// Full-screen, non-opaque route for a celebration overlay.
Future<void> _pushCelebration(BuildContext context, Widget child) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Plays the chest celebration (auto-closes at 4.2s like the web).
Future<void> showChestCelebration(
  BuildContext context, {
  required String kind,
  required int amount,
  required String label,
}) {
  return _pushCelebration(
    context,
    ChestOpening(
      kind: kind,
      amount: amount,
      label: label,
      onDone: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// Plays the Duolingo-style streak popup; the student taps the blue
/// CONTINUE key to dismiss it.
Future<void> showStreakCelebration(
  BuildContext context, {
  required int streak,
  bool forgiven = false,
  int forgivesLeft = 0,
}) {
  return _pushCelebration(
    context,
    StreakCelebration(
      streak: streak,
      forgiven: forgiven,
      forgivesLeft: forgivesLeft,
      onDone: () => Navigator.of(context).maybePop(),
    ),
  );
}

// ------------------------------------------------------- streak page

/// The full Renance STREAK PAGE (founder pass IX, the founder
/// screenshots): the same Duolingo cut as the celebration but as a
/// real page - beating flame disc, the huge orange count-up number
/// over 'day streak', the 7-day week row (orange checks inside the
/// streak window, a BLUE snowflake on the day a Streak Freeze saved,
/// the amber ring marking today) and the blue CONTINUE key. Opened
/// from the home header streak pill.
class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key, required this.streak, this.forgiven = false});

  final int streak;
  final bool forgiven;

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen>
    with TickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 90 * math.min(5, widget.streak)),
  );

  @override
  void initState() {
    super.initState();
    _count.forward();
  }

  @override
  void dispose() {
    _beat.dispose();
    _count.dispose();
    super.dispose();
  }

  static const List<String> _weekdayLabels = <String>[
    'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su',
  ];

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final String message = widget.forgiven
        ? 'Streak Freeze saves it for you.'
        : widget.streak >= 7
            ? 'Way to earn your Perfect Streak! Can you keep it next week?'
            : 'You can get a perfect week next time by not using any Streak '
                'Freezes!';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.08).animate(
                    CurvedAnimation(parent: _beat, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFFF9600), Color(0xFFFF4B4B)],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFFF9600)
                              .withValues(alpha: 0.45),
                          blurRadius: 52,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: MsIcon(
                        'local_fire_department',
                        size: 64,
                        color: Colors.white,
                        fill: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _count,
                  builder: (BuildContext context, Widget? _) {
                    final int n = (_count.value * widget.streak).round();
                    return Column(
                      children: <Widget>[
                        Text(
                          '$n',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 84,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: Color(0xFFFF9600),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'day streak',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF9600),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (int offset = 6; offset >= 0; offset--)
                      _WeekDay(
                        label: _weekdayLabels[
                            today.subtract(Duration(days: offset)).weekday - 1],
                        state: widget.forgiven && offset == 1
                            ? _WeekDayState.frozen
                            : offset < widget.streak
                                ? _WeekDayState.done
                                : _WeekDayState.empty,
                        isToday: offset == 0,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TactileButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    height: 50,
                    // the full-width blue CONTINUE key (Duolingo #1899d6)
                    face: const Color(0xFF1899D6),
                    onFace: Colors.white,
                    child: const Text('CONTINUE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the full streak page from the home header streak pill.
Future<void> showStreakScreen(
  BuildContext context, {
  required int streak,
  bool forgiven = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => StreakScreen(streak: streak, forgiven: forgiven),
    ),
  );
}

/// Plays the milestone card (Share / View in feed / Continue).
Future<void> showMilestoneCelebration(
  BuildContext context, {
  required MilestoneInfo milestone,
  VoidCallback? onViewFeed,
}) {
  return _pushCelebration(
    context,
    Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: MilestoneCelebration(
        milestone: milestone,
        onViewFeed: onViewFeed,
        onDone: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}

