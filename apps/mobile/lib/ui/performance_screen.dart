/// Performance Analysis — the Myschool page the founder called
/// beautiful, rebuilt in Renance's black & white language.
///
/// General Overview card (Total Average Performance + Tests Taken),
/// the soft-tinted per-exam cards (JAMB green / University orange /
/// WAEC blue / NECO lime / Challenge teal — the school app's exact
/// grammar), the Overall Performance section with the time-window
/// chips and the per-topic score bars, and the Performance Chart — a
/// hand-drawn line chart of the last papers, axis and grid included.
///
/// All data is real: the student's attempt rows, plus the graded
/// reviews of the ten most recent papers for the topic split.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'theme.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  String _window = 'all'; // all | week | month | year
  final Map<String, AttemptReview> _reviews = <String, AttemptReview>{};
  bool _analysing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyse());
  }

  /// Pulls the graded reviews for the ten most recent papers so the
  /// topic bars carry real per-question correctness.
  Future<void> _analyse() async {
    final StudentController student = context.read<StudentController>();
    final graded = student.attempts
        .where((AttemptRow a) => a.isGraded)
        .toList(growable: false);
    if (graded.isEmpty || _analysing) return;
    _analysing = true;
    final ApiClient? api = student.api;
    if (api == null) {
      _analysing = false;
      return;
    }
    for (final AttemptRow a in graded.take(10)) {
      if (_reviews.containsKey(a.attemptId)) continue;
      try {
        final AttemptReview review = await api.attemptReview(a.attemptId);
        _reviews[a.attemptId] = review;
      } on ApiException {
        break; // one refusal means the batch is refused; stop quietly
      } on NetworkException {
        break;
      }
      if (!mounted) return;
      setState(() {});
    }
    _analysing = false;
    if (mounted) setState(() {});
  }

  List<AttemptRow> _gradedInWindow() {
    final StudentController student = context.read<StudentController>();
    final DateTime now = DateTime.now();
    return student.attempts.where((AttemptRow a) {
      if (!a.isGraded) return false;
      final DateTime at = a.submittedAt ?? a.startedAt;
      switch (_window) {
        case 'week':
          return now.difference(at).inDays < 7;
        case 'month':
          return now.difference(at).inDays < 30;
        case 'year':
          return now.difference(at).inDays < 365;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.read<StudentController>();
    final List<AttemptRow> gradedAll = student.attempts
        .where((AttemptRow a) => a.isGraded)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.outlineVariant),
                          color: context.card,
                        ),
                        child: Icon(Icons.arrow_back,
                            size: 19, color: context.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await student.refresh();
                  await _analyse();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: <Widget>[
                    Text('Performance Analysis',
                        style: RenanceText.displayLg.copyWith(fontSize: 26)),
                    const SizedBox(height: 16),
                    _OverviewCard(graded: gradedAll),
                    const SizedBox(height: 14),
                    ..._bodyCards(),
                    const SizedBox(height: 14),
                    _OverallCard(
                      window: _window,
                      onWindow: (String w) => setState(() => _window = w),
                      graded: _gradedInWindow(),
                      reviews: _reviews,
                      analysing: _analysing,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The soft-tinted per-exam cards, the school app's exact grammar:
  /// icon bubble + "Ave. Performance" + "{body} Test" + N-tests pill +
  /// the big percentage.
  List<Widget> _bodyCards() {
    final StudentController student = context.read<StudentController>();
    final List<AttemptRow> all =
        student.attempts.where((AttemptRow a) => a.isGraded).toList();

    String bodyOf(AttemptRow a) {
      final String code = a.code;
      if (code.startsWith('daily-')) return 'challenge';
      if (code.startsWith('jamb-mock') || code.startsWith('jamb-custom') ||
          code.startsWith('jamb-pick')) {
        return 'jamb';
      }
      if (code.startsWith('waec-')) return 'waec';
      if (code.startsWith('neco-')) return 'neco';
      return 'cbt'; // university modules & everything else ride CBT
    }

    final Map<String, List<AttemptRow>> buckets = <String, List<AttemptRow>>{};
    for (final AttemptRow a in all) {
      buckets.putIfAbsent(bodyOf(a), () => <AttemptRow>[]).add(a);
    }

    const List<(String, String, Color, Color, IconData)> cards =
        <(String, String, Color, Color, IconData)>[
      ('jamb', 'JAMB Test', Color(0xFFE7F5EC), Color(0xFF1F7A4D), Icons.school),
      ('cbt', 'University Test', Color(0xFFFDF0E7), Color(0xFFC2410C), Icons.computer),
      ('waec', 'WAEC Test', Color(0xFFE5F0FB), Color(0xFF1D4ED8), Icons.workspace_premium),
      ('neco', 'NECO Test', Color(0xFFF2F7E2), Color(0xFF4D7C0F), Icons.verified),
      ('challenge', 'Challenge Test', Color(0xFFE0F5F1), Color(0xFF0F766E), Icons.bolt),
    ];

    final List<Widget> out = <Widget>[];
    for (final (String key, String label, Color tint, Color accent, IconData icon)
        in cards) {
      final List<AttemptRow>? rows = buckets[key];
      if (rows == null || rows.isEmpty) continue;
      final double avg = rows.fold<double>(
              0, (double s, AttemptRow a) => s + (a.pct ?? 0)) /
          rows.length;
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _BodyCard(
            label: label,
            tint: tint,
            accent: accent,
            icon: icon,
            avg: avg.round(),
            taken: rows.length,
          ),
        ),
      );
    }
    return out;
  }
}

// ------------------------------------------------------------- overview

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.graded});

  final List<AttemptRow> graded;

  @override
  Widget build(BuildContext context) {
    final int avg = graded.isEmpty
        ? 0
        : graded.fold<double>(0, (double s, AttemptRow a) => s + (a.pct ?? 0)) ~/
            graded.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: context.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('General Overview', style: RenanceText.sectionTitle),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Total Average\nPerformance',
                  style: RenanceText.bodyMedium,
                ),
              ),
              Text(
                '$avg%',
                style: RenanceText.displayLg.copyWith(fontSize: 38),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: context.cardLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${graded.length} Tests Taken',
              style: RenanceText.bodyMedium.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyCard extends StatelessWidget {
  const _BodyCard({
    required this.label,
    required this.tint,
    required this.accent,
    required this.icon,
    required this.avg,
    required this.taken,
  });

  final String label;
  final Color tint;
  final Color accent;
  final IconData icon;
  final int avg;
  final int taken;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Ave. Performance',
                      style: RenanceText.bodyMedium.copyWith(
                        fontSize: 17,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: RenanceText.bodySecondary.copyWith(
                        fontSize: 15,
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$taken Tests Taken',
                  style: RenanceText.labelMono.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$avg%',
                style: RenanceText.displayLg.copyWith(
                  fontSize: 34,
                  color: context.isDarkTier ? null : context.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- overall

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.window,
    required this.onWindow,
    required this.graded,
    required this.reviews,
    required this.analysing,
  });

  final String window;
  final ValueChanged<String> onWindow;
  final List<AttemptRow> graded;
  final Map<String, AttemptReview> reviews;
  final bool analysing;

  @override
  Widget build(BuildContext context) {
    // Topic split from the fetched reviews: % correct per topic, the
    // top six topics by question count.
    final Map<String, (int, int)> topics = <String, (int, int)>{};
    for (final AttemptRow a in graded) {
      final AttemptReview? review = reviews[a.attemptId];
      if (review == null) continue;
      for (final ReviewQuestion q in review.questions) {
        final String topic = q.topic.isEmpty ? 'General' : q.topic;
        final (int, int) cur = topics[topic] ?? (0, 0);
        topics[topic] = (
          cur.$1 + (q.correctly ? 1 : 0),
          cur.$2 + 1,
        );
      }
    }
    final List<(String, double)> bars = <(String, double)>[
      for (final MapEntry<String, (int, int)> e in topics.entries)
        (
          e.key,
          e.value.$2 == 0 ? 0.0 : e.value.$1 * 100 / e.value.$2,
        ),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final List<(String, double)> topBars = bars.take(6).toList();

    // The chart series: chronological scores of the window's papers.
    final List<int> series = <int>[
      for (final AttemptRow a in graded)
        if (a.pct != null) a.pct!,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: context.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Overall Performance', style: RenanceText.sectionTitle),
          const SizedBox(height: 12),
          // Window chips — All time / This Week / This Month / This Year.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                for (final (String key, String label) in const <(String, String)>[
                  ('all', 'All time'),
                  ('week', 'This Week'),
                  ('month', 'This Month'),
                  ('year', 'This Year'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: () => onWindow(key),
                      child: Text(
                        label,
                        style: RenanceText.bodyMedium.copyWith(
                          fontSize: 14,
                          color: window == key
                              ? context.ink
                              : context.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (graded.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No graded papers in this window yet.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary),
              ),
            )
          else ...<Widget>[
            if (analysing && topBars.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (topBars.isEmpty)
              Text(
                'Topic breakdown arrives with the analysed papers.',
                style: RenanceText.caption.copyWith(
                    color: context.textSecondary),
              )
            else
              for (final (String topic, double pct) in topBars)
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: _TopicBar(topic: topic, pct: pct),
                ),
            const SizedBox(height: 6),
            Text('Performance Chart', style: RenanceText.sectionTitle),
            const SizedBox(height: 12),
            _ScoreChart(series: series),
          ],
        ],
      ),
    );
  }
}

/// One horizontal score bar, Myschool's coloured bar over its track.
class _TopicBar extends StatelessWidget {
  const _TopicBar({required this.topic, required this.pct});

  final String topic;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RenanceText.bodyBase.copyWith(fontSize: 14.5),
              ),
            ),
            Text(
              '${pct.round()}%',
              style: RenanceText.bodyMedium.copyWith(fontSize: 14.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 22,
            child: Stack(
              children: <Widget>[
                Container(color: context.cardLow),
                FractionallySizedBox(
                  widthFactor: (pct / 100).clamp(0.0, 1.0),
                  child: Container(color: _barColor(pct)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _barColor(double pct) {
    if (pct >= 70) return const Color(0xFF2F6F8F); // steady blue
    if (pct >= 50) return const Color(0xFF7C3AED); // violet
    return const Color(0xFFE23A3A); // needs work red
  }
}

/// The line chart of the last papers' scores, drawn like the school
/// app's: light grid, dotted axes, the ink line with dot joints.
class _ScoreChart extends StatelessWidget {
  const _ScoreChart({required this.series});

  final List<int> series;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'One more paper and the score line starts drawing itself.',
          style:
              RenanceText.caption.copyWith(color: context.textSecondary),
        ),
      );
    }
    return SizedBox(
      height: 190,
      child: CustomPaint(
        painter: _ChartPainter(
          series: series,
          line: context.isDarkTier
              ? RenanceColors.darkTextPrimary
              : const Color(0xFF14B8A6),
          grid: context.outlineVariant.withValues(alpha: 0.5),
          label: context.textSecondary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.line,
    required this.grid,
    required this.label,
  });

  final List<int> series;
  final Color line;
  final Color grid;
  final Color label;

  static const int _maxPoints = 12;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 34, right = 34, top = 10, bottom = 26;
    final Rect plot = Rect.fromLTRB(
        left, top, size.width - right, size.height - bottom);

    // grid: 5 horizontal bands + dotted verticals per point
    final Paint gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (var i = 0; i <= 5; i++) {
      final double y = plot.top + plot.height * i / 5;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    // y labels 0..100
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 5; i++) {
      final int v = 100 - i * 20;
      tp.text = TextSpan(
        text: '$v',
        style: TextStyle(fontSize: 10, color: label),
      );
      tp.layout();
      tp.paint(canvas,
          Offset(2, plot.top + plot.height * i / 5 - tp.height / 2));
    }

    final List<int> pts = series.length > _maxPoints
        ? series.sublist(series.length - _maxPoints)
        : series;
    final double dx = plot.width / (pts.length - 1);
    double px(int i) => plot.left + dx * i;
    double py(int v) =>
        plot.bottom - (v / 100).clamp(0.0, 1.0) * plot.height;

    // verticals per point
    for (var i = 0; i < pts.length; i++) {
      canvas.drawLine(
        Offset(px(i), plot.top),
        Offset(px(i), plot.bottom),
        gridPaint,
      );
      tp.text = TextSpan(
        text: '${i + 1}',
        style: TextStyle(fontSize: 10, color: label),
      );
      tp.layout();
      tp.paint(canvas, Offset(px(i) - tp.width / 2, plot.bottom + 6));
    }

    // the score line
    final Path path = Path();
    for (var i = 0; i < pts.length; i++) {
      final Offset o = Offset(px(i), py(pts[i]));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = line;
    canvas.drawPath(path, linePaint);

    // dot joints
    final Paint dot = Paint()..color = line;
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(Offset(px(i), py(pts[i])), 3.4, dot);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.line != line;
}

