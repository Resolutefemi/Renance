/// Progress report, the Stitch progress_dashboard_light screen, 1:1.
///
/// The three stat tiles (questions answered, accuracy, time spent), the
/// 7-day Accuracy Trend bar chart drawn from real graded attempts, the
/// Subject Mastery rails (per-pack accuracy from history) and the Focus
/// Areas list that hands the worst topics straight to practice, plus the
/// streak chip. Opened from the Progress tab and the More sheet.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'theme.dart';

class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final List<AttemptRow> graded = student.attempts
        .where((AttemptRow a) => a.isGraded && a.pct != null)
        .toList(growable: false);

    final int questions = graded.fold<int>(0, (int s, AttemptRow a) => s + (a.total ?? 0));
    final int correct = graded.fold<int>(0, (int s, AttemptRow a) => s + (a.score ?? 0));
    final int accuracy = questions == 0 ? 0 : (correct * 100 ~/ questions);
    final Duration spent = graded.fold<Duration>(
      Duration.zero,
      (Duration d, AttemptRow a) =>
          d + Duration(milliseconds: a.durationMs ?? 0),
    );

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.cardLow,
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: context.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Progress report', style: RenanceText.sectionTitle),
              ],
            ),
            const SizedBox(height: 12),
            // Stat tiles -------------------------------------------------
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    value: '$questions',
                    label: 'Questions',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: '$accuracy%',
                    label: 'Accuracy',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: _hours(spent),
                    label: 'Time Spent',
                    icon: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            // Accuracy trend ----------------------------------------------
            const SizedBox(height: 16),
            _TrendCard(attempts: graded),
            // Subject mastery ----------------------------------------------
            const SizedBox(height: 16),
            _MasteryCard(attempts: graded),
            // Focus areas ---------------------------------------------------
            const SizedBox(height: 16),
            _FocusCard(attempts: graded),
            // Streak chip ------------------------------------------------------
            const SizedBox(height: 16),
            _StreakChip(student: student),
          ],
        ),
      ),
    );
  }

  static String _hours(Duration d) {
    final int h = d.inHours;
    if (h >= 1) return '${h}h';
    return '${d.inMinutes}m';
  }
}

// ----------------------------------------------------------------- tiles

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null)
            Icon(icon, size: 18, color: context.textSecondary),
          Text(value,
              style: RenanceText.statNumber.copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RenanceText.caption.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Accuracy Trend, Last 7 Days: one bar per day, the day's mean accuracy
/// across graded attempts; a dim baseline bar when the day had none.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.attempts});

  final List<AttemptRow> attempts;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now().toUtc();
    final List<double> values = List<double>.filled(7, 0);
    final List<bool> has = List<bool>.filled(7, false);
    for (int i = 0; i < 7; i++) {
      final DateTime day = now.subtract(Duration(days: 6 - i));
      final List<AttemptRow> dayRows = attempts
          .where((AttemptRow a) =>
              a.submittedAt != null &&
              a.submittedAt!.year == day.year &&
              a.submittedAt!.month == day.month &&
              a.submittedAt!.day == day.day)
          .toList(growable: false);
      if (dayRows.isNotEmpty) {
        has[i] = true;
        values[i] =
            dayRows.fold<int>(0, (int s, AttemptRow a) => s + a.pct!) /
                dayRows.length;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Accuracy Trend', style: RenanceText.sectionTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text('Last 7 Days',
              style: RenanceText.caption.copyWith(color: context.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          if (has[i])
                            Text('${values[i].round()}%',
                                style: RenanceText.labelMono.copyWith(
                                    fontSize: 9,
                                    color: context.textSecondary)),
                          const SizedBox(height: 4),
                          Container(
                            height: has[i]
                                ? 60 * (values[i] / 100).clamp(0.15, 1.0)
                                : 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: has[i]
                                  ? context.ink
                                  : context.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'D-${6 - i}',
                            style: RenanceText.labelMono.copyWith(
                                fontSize: 9, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subject Mastery: mean accuracy per pack code across graded attempts.
class _MasteryCard extends StatelessWidget {
  const _MasteryCard({required this.attempts});

  final List<AttemptRow> attempts;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<int>> byCode = <String, List<int>>{};
    for (final AttemptRow a in attempts) {
      byCode.putIfAbsent(a.code, () => <int>[]).add(a.pct!);
    }
    final List<MapEntry<String, double>> rows = byCode.entries
        .map((MapEntry<String, List<int>> e) => MapEntry(
            e.key, e.value.fold<int>(0, (int s, int p) => s + p) / e.value.length))
        .toList(growable: false)
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Subject Mastery', style: RenanceText.sectionTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              'Run a graded paper and mastery fills in here.',
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
            )
          else
            ...rows.take(4).map<Widget>((MapEntry<String, double> e) {
              final int pct = e.value.round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(e.key, style: RenanceText.bodyMedium.copyWith(fontSize: 14)),
                        Text('$pct%',
                            style: RenanceText.labelMono.copyWith(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: context.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct >= 70
                              ? RenanceColors.emerald
                              : pct >= 50
                                  ? RenanceColors.amber
                                  : context.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Focus Areas: the packs with the lowest accuracy, straight from the
/// graded history, with a direct practice jump.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.attempts});

  final List<AttemptRow> attempts;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<int>> byCode = <String, List<int>>{};
    for (final AttemptRow a in attempts) {
      byCode.putIfAbsent(a.code, () => <int>[]).add(a.pct!);
    }
    final List<MapEntry<String, double>> ranked = byCode.entries
        .map((MapEntry<String, List<int>> e) => MapEntry(
            e.key, e.value.fold<int>(0, (int s, int p) => s + p) / e.value.length))
        .toList(growable: false)
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          a.value.compareTo(b.value));
    final List<String> weak =
        ranked.map((MapEntry<String, double> e) => e.key).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: RenanceColors.amber),
              const SizedBox(width: 8),
              Text('Focus Areas', style: RenanceText.sectionTitle.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          if (weak.isEmpty)
            Text(
              'No weak spots detected yet. Keep practicing!',
              style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
            )
          else
            ...weak.take(3).map<Widget>(
              (String code) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              RenanceText.bodyMedium.copyWith(fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.cardLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Practice',
                          style: RenanceText.labelMono.copyWith(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.student});

  final StudentController student;

  @override
  Widget build(BuildContext context) {
    final int streak = student.gamification?.state.currentStreak ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: RenanceColors.amber,
            ),
            child: const Icon(Icons.local_fire_department,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text('$streak Day Streak',
              style: RenanceText.bodyMedium.copyWith(fontSize: 15)),
          const Spacer(),
          const Icon(Icons.check_circle,
              size: 20, color: RenanceColors.emerald),
        ],
      ),
    );
  }
}
