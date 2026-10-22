/// Examination Performance - the score report, rebuilt 1:1 from the
/// founder's reference screenshots
/// (uploads/Screenshot_20260925-17434*.png for the full JAMB simulation
/// report, uploads/Screenshot_20260929-2131*.png for the other
/// examinations report) and improved:
///
///   * cream header banner with the amber shards and the page title,
///   * JAMB mocks: "Your JAMB score" + the big /400 aggregate, then the
///     passed-questions line and the big percentage (every other paper
///     leads with the percentage),
///   * the "You spent" teal pill + Hour/Min duration,
///   * the light-blue Start/End time card,
///   * the lavender "Score breakdown" card - per subject for JAMB mocks
///     ("61 · 60 of 60 Attempted"), per topic for the other papers,
///   * "Focus next" weak-topic chips (tap deep-links the syllabus map),
///   * the XP + streak pill,
///   * actions: **View Corrections** (filled), **Send to Online
///     Ranking** (outline), **Go Back** (text).
///
/// The reference's red action buttons are ink-black here - Renance's
/// black & white language (founder rule: "those red buttons in the
/// picture change it to black for renance"). One report serves every
/// score band; weak topics surface as chips instead of a separate
/// low-score screen.
///
/// Two consumers: the exam player's graded phase embeds [ExamReportView]
/// directly, and the Exam History page replays a stored attempt through
/// [ExamReportScreen].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'leaderboard_screen.dart';
import 'msymbols.dart';
import 'review_screen.dart' show ReviewDetailScreen;
import 'tactile.dart';
import 'theme.dart';

/// The report body. Embeds in the exam player (graded phase) and inside
/// [ExamReportScreen]; scrolling content above, the pinned action row
/// below.
class ExamReportView extends StatelessWidget {
  const ExamReportView({
    super.key,
    required this.result,
    required this.title,
    required this.code,
    required this.body,
    this.startedAt,
    this.durationMs,
    this.attemptId,
    this.delta,
    this.xpEarned = 0,
    this.streak = 0,
    this.onRetry,
    this.onGoBack,
    this.onBack,
    this.extra,
  });

  /// The graded result. [ExamResult.subjects] non-empty marks a composite
  /// JAMB mock paper (the full simulation score report).
  final ExamResult result;
  final String title;
  final String code;
  final String body;

  /// Sitting timing. [durationMs] wins over start/end arithmetic.
  final DateTime? startedAt;
  final int? durationMs;

  /// The server attempt id; null (or offline-) disables the corrections
  /// and ranking actions - there is nothing graded to open yet.
  final String? attemptId;

  /// Percentage delta vs the previous graded attempt on the same pack.
  final int? delta;
  final int xpEarned;
  final int streak;

  /// Post-exam only: restart the paper (adaptive, weak topics first).
  final VoidCallback? onRetry;
  final VoidCallback? onGoBack;

  /// The back circle at the banner's top LHS (founder directive: every
  /// result page answers a back button at the top left). Null pops the
  /// navigator - the embedded player and the history replay both sit on
  /// a route that pops.
  final VoidCallback? onBack;

  /// Extra section under the breakdown (the exam player mounts the
  /// pacing forensics card here).
  final Widget? extra;

  bool get _isJamb => result.subjects.isNotEmpty;
  bool get _hasServerAttempt =>
      attemptId != null && !attemptId!.startsWith('offline-');

  @override
  Widget build(BuildContext context) {
    final int pct =
        result.total == 0 ? 0 : (result.score * 100 ~/ result.total);
    final double aggregate =
        result.subjects.fold<double>(0, (double s, UtmeSubjectRow r) => s + r.score);
    final int totalQ = result.subjects.fold<int>(
        0, (int s, UtmeSubjectRow r) => s + r.total);

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              _ReportBanner(
                dark: context.isDarkTier,
                title: title,
                onBack: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_isJamb) ...<Widget>[
                      Text(
                        'Your JAMB score',
                        style: RenanceText.bodyBase.copyWith(
                          fontSize: 16,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        aggregate == aggregate.roundToDouble()
                            ? aggregate.toInt().toString()
                            : aggregate.toStringAsFixed(1),
                        style: RenanceText.statNumber.copyWith(
                          fontSize: 68,
                          height: 1.02,
                          letterSpacing: -2.2,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'You passed ${result.score} of '
                      '${_isJamb && totalQ > 0 ? totalQ : result.total} '
                      'questions',
                      style: RenanceText.bodyBase.copyWith(
                        fontSize: 15,
                        color: context.isDarkTier
                            ? RenanceColors.darkTextSecondary
                            : const Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '$pct',
                          style: RenanceText.statNumber.copyWith(
                            fontSize: _isJamb ? 52 : 68,
                            height: 1.02,
                            letterSpacing: _isJamb ? -1.6 : -2.2,
                            color: context.ink,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '%',
                            style: RenanceText.statNumber.copyWith(
                              fontSize: _isJamb ? 24 : 30,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        if (delta != null) ...<Widget>[
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _DeltaPill(delta: delta!),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 26),
                    _YouSpentRow(durationMs: durationMs),
                    const SizedBox(height: 16),
                    _TimeCard(
                      startedAt: startedAt,
                      durationMs: durationMs,
                    ),
                    const SizedBox(height: 24),
                    _BreakdownCard(result: result),
                    if (result.weakTopics().isNotEmpty)
                      _FocusNextChips(
                        weak: result.weakTopics(),
                        body: body,
                      ),
                    if (xpEarned > 0) ...<Widget>[
                      const SizedBox(height: 16),
                      _XpPill(xpEarned: xpEarned, streak: streak),
                    ],
                    if (extra != null) ...<Widget>[
                      const SizedBox(height: 20),
                      extra!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _ReportActions(
          hasServerAttempt: _hasServerAttempt,
          attemptId: attemptId,
          onRetry: onRetry,
          onGoBack: onGoBack ??
              () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// The standalone replay: Exam History rows land here. Fetches the
/// stored attempt (GET /attempts/{id}), falls back to the row's own
/// score when the paper predates server-side result storage.
class ExamReportScreen extends StatefulWidget {
  const ExamReportScreen({super.key, required this.attempt});

  final AttemptRow attempt;

  @override
  State<ExamReportScreen> createState() => _ExamReportScreenState();
}

class _ExamReportScreenState extends State<ExamReportScreen> {
  bool _loading = true;
  String? _error;
  ExamResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final ApiClient api = context.read<ApiClient>();
      final AttemptView view = await api.attempt(widget.attempt.attemptId);
      if (!mounted) return;
      setState(() {
        _result = view.result;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on NetworkException {
      if (!mounted) return;
      setState(() {
        _error =
            'No connection to Renance servers. Check your internet and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AttemptRow a = widget.attempt;
    final StudentController student = context.read<StudentController>();
    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        // The banner's own back circle (top LHS) is the page's back
        // affordance - no separate header row above the report anymore.
        child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                      ? _ErrorPane(message: _error!, onRetry: _load)
                      : ExamReportView(
                          result: _result ??
                              ExamResult(
                                score: a.score ?? 0,
                                total: a.total ?? 0,
                                breakdown: const <TopicRow>[],
                              ),
                          title: student.titleForCode(a.code),
                          code: a.code,
                          body: bodyOfAttempt(a),
                          startedAt: a.startedAt,
                          durationMs: a.durationMs,
                          attemptId: a.attemptId,
                        ),
        ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MsIcon('cloud_off',
                size: 40, color: context.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: RenanceText.bodyBase.copyWith(
                    color: context.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            TactileButton(
              onPressed: onRetry,
              outline: context.outlineVariant,
              edge: context.outlineVariant,
              edgeWidth: 3,
              height: 46,
              fontSize: 14,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- banner

/// Cream hero banner with the amber shard cluster, the reference's
/// "Examination Performance" masthead.
class _ReportBanner extends StatelessWidget {
  const _ReportBanner({
    required this.dark,
    required this.title,
    required this.onBack,
  });

  final bool dark;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 22),
      color: dark ? RenanceColors.darkSurface : const Color(0xFFFFF8E1),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _ShardsPainter(dark: dark),
            ),
          ),
          Row(
            children: <Widget>[
              TactileBackKey(
                onTap: onBack,
                size: 44,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Examination Performance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.displayMd.copyWith(
                    fontSize: 24,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The amber shard cluster - overlapping flat triangles peeking from the
/// banner's top-right corner, like the reference art.
class _ShardsPainter extends CustomPainter {
  _ShardsPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Path> shards = <Path>[
      Path()
        ..moveTo(size.width * 0.78, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.92)
        ..close(),
      Path()
        ..moveTo(size.width * 0.88, 0)
        ..lineTo(size.width, size.height * 0.34)
        ..lineTo(size.width * 0.80, 0)
        ..close(),
      Path()
        ..moveTo(size.width * 0.92, size.height)
        ..lineTo(size.width, size.height * 0.62)
        ..lineTo(size.width, size.height)
        ..close(),
    ];
    final List<Color> colors = dark
        ? const <Color>[
            Color(0x4DFFB74D),
            Color(0x66FFE0B2),
            Color(0x33FFB74D),
          ]
        : const <Color>[
            Color(0xFFFFCC80),
            Color(0xFFFFE0B2),
            Color(0xFFFFB74D),
          ];
    for (var i = 0; i < shards.length; i++) {
      final Paint p = Paint()..color = colors[i];
      canvas.drawPath(shards[i], p);
    }
  }

  @override
  bool shouldRepaint(_ShardsPainter oldDelegate) => oldDelegate.dark != dark;
}

// ------------------------------------------------------------- score bits

/// "+5 vs last attempt" - green up / red down, mono label.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final bool up = delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: up
            ? RenanceColors.emerald.withValues(alpha: 0.12)
            : context.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MsIcon(
            up ? 'trending_up' : 'trending_down',
            size: 14,
            color: up ? RenanceColors.emerald : context.error,
          ),
          const SizedBox(width: 5),
          Text(
            up ? '+$delta' : '$delta',
            style: RenanceText.labelMono.copyWith(
              fontSize: 12,
              color: up ? RenanceColors.emerald : context.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// "You spent" teal pill + "1 Hour 44 Min" in the reference's baseline
/// rhythm. Papers with no recorded duration print a dash instead.
class _YouSpentRow extends StatelessWidget {
  const _YouSpentRow({required this.durationMs});

  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDarkTier;
    final int totalMin = (durationMs ?? 0) ~/ 60000;
    final int hours = totalMin ~/ 60;
    final int mins = totalMin % 60;

    final List<Widget> timeWidgets;
    if (durationMs == null || durationMs! <= 0) {
      timeWidgets = <Widget>[
        Text('-', style: RenanceText.statNumber.copyWith(
          fontSize: 34, color: context.ink)),
      ];
    } else {
      timeWidgets = <Widget>[
        _DurationUnit(value: hours, unit: 'Hour'),
        const SizedBox(width: 18),
        _DurationUnit(value: mins, unit: 'Min'),
      ];
    }

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: dark ? RenanceColors.darkSurfaceLow : const Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'You spent',
            style: RenanceText.bodyMedium.copyWith(
              fontSize: 16,
              color: dark ? const Color(0xFF80DEEA) : const Color(0xFF00695C),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ...timeWidgets,
      ],
    );
  }
}

class _DurationUnit extends StatelessWidget {
  const _DurationUnit({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              '$value',
              style: RenanceText.statNumber.copyWith(
                fontSize: 36,
                height: 1.05,
                color: context.ink,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: RenanceText.bodyBase.copyWith(
                  fontSize: 13,
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Light-blue Start/End time card: "Start Time: 12:22pm / End Time: 2:06pm".
class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.startedAt, required this.durationMs});

  final DateTime? startedAt;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDarkTier;
    final DateTime? end = startedAt?.add(Duration(milliseconds: durationMs ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: dark ? RenanceColors.darkSurfaceLow : const Color(0xFFE1F5FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Start Time:',
                style: RenanceText.bodyMedium.copyWith(
                    fontSize: 16,
                    color: context.ink),
              ),
              Text(
                startedAt == null ? '-' : _clock(startedAt!),
                style: RenanceText.bodyBase.copyWith(
                    fontSize: 16,
                    color: context.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'End Time:',
                style: RenanceText.bodyMedium.copyWith(
                    fontSize: 16,
                    color: context.ink),
              ),
              Text(
                end == null ? '-' : _clock(end),
                style: RenanceText.bodyBase.copyWith(
                    fontSize: 16,
                    color: context.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "2:06pm" - the reference's 12-hour lowercase clock.
  static String _clock(DateTime t) {
    final int h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final String mm = t.minute.toString().padLeft(2, '0');
    final String ap = t.hour < 12 ? 'am' : 'pm';
    return '$h12:$mm$ap';
  }
}

// ------------------------------------------------------------ breakdown

/// Lavender "Score breakdown" card. JAMB mocks print the per-subject
/// ledger (marks out of 100); every other paper prints the per-topic
/// split; papers with neither print one honest overall row.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.result});

  final ExamResult result;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDarkTier;
    final bool jamb = result.subjects.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? RenanceColors.darkCard : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              MsIcon('grid_view',
                  size: 21,
                  color: dark ? const Color(0xFFB39DDB) : const Color(0xFF673AB7)),
              const SizedBox(width: 9),
              Text(
                'Score breakdown',
                style: RenanceText.sectionTitle.copyWith(
                  fontSize: 19,
                  color: context.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            jamb
                ? 'Below is a breakdown of your scores per subject with the '
                    'number of questions attempted'
                : 'Below is a breakdown of your scores per topic with the '
                    'number of questions attempted',
            style: RenanceText.bodyBase.copyWith(
              fontSize: 14.5,
              height: 1.45,
              color: dark
                  ? RenanceColors.darkTextSecondary
                  : const Color(0xFF616161),
            ),
          ),
          const SizedBox(height: 10),
          if (jamb)
            ..._subjectRows(context, dark)
          else if (result.breakdown.isNotEmpty)
            ..._topicRows(context, dark)
          else
            _Row(
              name: 'This paper',
              attempted:
                  '${result.score} of ${result.total} Attempted',
              score: '${result.score}',
              trailing: null,
              dark: dark,
              divider: false,
            ),
        ],
      ),
    );
  }

  List<Widget> _subjectRows(BuildContext context, bool dark) {
    final List<Widget> out = <Widget>[];
    final List<UtmeSubjectRow> rows = result.subjects;
    for (var i = 0; i < rows.length; i++) {
      final UtmeSubjectRow r = rows[i];
      final String score = r.score == r.score.roundToDouble()
          ? r.score.toInt().toString()
          : r.score.toStringAsFixed(1);
      out.add(_Row(
        name: humanizeSubject(r.subject),
        attempted: '${r.attempted} of ${r.total} Attempted',
        score: score,
        trailing: 'of 100',
        dark: dark,
        divider: i < rows.length - 1,
      ));
    }
    return out;
  }

  List<Widget> _topicRows(BuildContext context, bool dark) {
    final List<Widget> out = <Widget>[];
    final List<TopicRow> rows = result.breakdown;
    for (var i = 0; i < rows.length; i++) {
      final TopicRow r = rows[i];
      final int pct = r.total == 0 ? 0 : (r.correct * 100 ~/ r.total);
      out.add(_Row(
        name: r.topic,
        attempted: '${r.correct} of ${r.total} Attempted',
        score: '${r.correct}',
        trailing: '$pct%',
        dark: dark,
        divider: i < rows.length - 1,
      ));
    }
    return out;
  }
}

/// One breakdown row: name + "X of Y Attempted" left, score (+ small
/// suffix) right, hairline divider below.
class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.attempted,
    required this.score,
    required this.trailing,
    required this.dark,
    required this.divider,
  });

  final String name;
  final String attempted;
  final String score;
  final String? trailing;
  final bool dark;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final Color ink = context.ink;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RenanceText.bodyMedium.copyWith(
                        fontSize: 17,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attempted,
                      style: RenanceText.caption.copyWith(
                        fontSize: 13.5,
                        color: dark
                            ? RenanceColors.darkMuted
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    score,
                    style: RenanceText.statNumber.copyWith(
                      fontSize: 19,
                      color: ink,
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 4),
                    Text(
                      trailing!,
                      style: RenanceText.bodyBase.copyWith(
                        fontSize: 12.5,
                        color: dark
                            ? RenanceColors.darkMuted
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (divider)
          Container(
            height: 1,
            color: dark ? RenanceColors.darkOutline : const Color(0xFFE0E0E0),
          ),
      ],
    );
  }
}

/// "Focus next" - weak topics (accuracy under 60%) as passive chips.
/// The syllabus-map tap is gone with the Syllabus Map feature (founder
/// 2026-10-21: useless) - the chips stay as a read-only signal.
class _FocusNextChips extends StatelessWidget {
  const _FocusNextChips({required this.weak, required this.body});

  final List<TopicRow> weak;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 20),
        Text('Focus next',
            style: RenanceText.sectionTitle.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final TopicRow row in weak.take(4))
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: RenanceColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: RenanceColors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const MsIcon('local_fire_department',
                        size: 14, color: RenanceColors.amber),
                    const SizedBox(width: 4),
                    Text('${row.topic} · ${row.correct}/${row.total}',
                        style: RenanceText.labelMono.copyWith(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Slim XP + streak pill.
class _XpPill extends StatelessWidget {
  const _XpPill({required this.xpEarned, required this.streak});

  final int xpEarned;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MsIcon('stars', size: 15, color: RenanceColors.amber),
          const SizedBox(width: 5),
          Text('+$xpEarned XP',
              style: RenanceText.bodyMedium.copyWith(fontSize: 13.5)),
          const SizedBox(width: 10),
          const MsIcon('local_fire_department',
              size: 15, color: RenanceColors.amber),
          const SizedBox(width: 5),
          Text('Streak Day $streak',
              style: RenanceText.labelMono.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- actions

/// The pinned action row: View Corrections (filled ink), Send to Online
/// Ranking (outline), Go Back (text) - the reference's red buttons in
/// Renance black.
class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.hasServerAttempt,
    required this.attemptId,
    required this.onRetry,
    required this.onGoBack,
  });

  final bool hasServerAttempt;
  final String? attemptId;
  final VoidCallback? onRetry;
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDarkTier;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            context.pageBg.withValues(alpha: 0),
            context.pageBg,
          ],
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TactileButton(
              height: 52,
              radius: BorderRadius.circular(12),
              face: context.primary,
              onFace: context.onPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              onPressed: !hasServerAttempt
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReviewDetailScreen(attemptId: attemptId!),
                        ),
                      ),
              child: const Text('View Corrections'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.ink,
                  side: BorderSide(
                      color: dark ? RenanceColors.darkOutline : context.ink,
                      width: 1.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: !hasServerAttempt
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const LeaderboardScreen()),
                        ),
                icon: MsIcon('leaderboard', size: 19),
                label: const Text('Send to Online Ranking',
                    style:
                        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextButton(
                  onPressed: onGoBack,
                  style: TextButton.styleFrom(foregroundColor: context.ink),
                  child: const Text('Go Back',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text('·', style: RenanceText.bodyBase
                      .copyWith(color: context.textSecondary)),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onRetry,
                    style:
                        TextButton.styleFrom(foregroundColor: context.ink),
                    child: const Text('Retry Weak Topics',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

/// Subject slugs embedded in a composed paper code, humanized:
/// "jamb-mock-english-physics-biology~n=100" → English, Physics, Biology.
List<String> subjectsFromCode(String code) {
  const List<String> prefixes = <String>[
    'jamb-mock-',
    'jamb-custom-',
    'waec-custom-',
    'neco-custom-',
  ];
  for (final String p in prefixes) {
    if (!code.startsWith(p) || code.length <= p.length) continue;
    String body = code.substring(p.length);
    final int tilde = body.indexOf('~');
    if (tilde >= 0) body = body.substring(0, tilde);
    return body
        .split('-')
        .where((String s) => s.isNotEmpty)
        .map(humanizeSubject)
        .toList();
  }
  return const <String>[];
}

/// "english" → "English", "english language" → "English Language".
String humanizeSubject(String slug) => slug
    .split(RegExp(r'[\s_]+'))
    .where((String w) => w.isNotEmpty)
    .map((String w) =>
        '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
    .join(' ');

/// The history row's exam-type tag: JAMB / WAEC / NECO / Challenge / CBT.
String examTypeOf(String code) {
  if (code.startsWith('jamb-')) return 'JAMB';
  if (code.startsWith('waec-')) return 'WAEC';
  if (code.startsWith('neco-')) return 'NECO';
  if (code.startsWith('daily-')) return 'Challenge';
  return 'CBT';
}

/// The body slug of an attempt code, for the report's syllabus links.
String bodyOfAttempt(AttemptRow a) {
  switch (examTypeOf(a.code)) {
    case 'JAMB':
      return 'JAMB';
    case 'WAEC':
      return 'WAEC';
    case 'NECO':
      return 'NECO';
    default:
      return '';
  }
}
