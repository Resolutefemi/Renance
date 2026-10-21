/// Exam History - rebuilt from the founder's reference screenshot
/// (uploads/Screenshot_20260929-213704.png): the bold "Exam History"
/// title with the "Clear all Exam History" outlined chip on the right,
/// then the numbered rows - subjects (comma-separated), the
/// "CBT · Sep 05, 2026" meta line, the bold "Score 48%" on the right
/// (JAMB rows add their raw ledger line) - separated by hairlines.
///
/// Tapping a row replays the full Examination Performance report for
/// that sitting. "Clear all" hides every paper currently on the list on
/// this device; new papers taken after the clear appear normally
/// (server records, XP and leaderboard entries are untouched).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers.dart';
import '../models.dart';
import 'exam_report_screen.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

/// SharedPreferences key holding the epoch-ms watermark of the last
/// "Clear all Exam History" tap.
const String kHistoryClearedAtKey = 'renance.examHistory.clearedAt';

class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  int _clearedAt = 0;

  @override
  void initState() {
    super.initState();
    _loadClearedAt();
  }

  Future<void> _loadClearedAt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _clearedAt = prefs.getInt(kHistoryClearedAtKey) ?? 0;
    });
  }

  Future<void> _confirmClearAll(int count) async {
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Clear all exam history?'),
        content: Text(
          'This hides the $count paper${count == 1 ? '' : 's'} currently on '
          'this list on this device. New papers you take afterwards will '
          'still appear, and your XP, streak and leaderboard entries are '
          'not affected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear != true) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        kHistoryClearedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() {
      _clearedAt = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final DateTime clearedMarker = DateTime.fromMillisecondsSinceEpoch(
        _clearedAt, isUtc: false);

    final List<AttemptRow> papers = student.attempts
        .where((AttemptRow a) =>
            a.isGraded &&
            (_clearedAt == 0 || a.startedAt.isAfter(clearedMarker)))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: <Widget>[
                    TactileBackKey(
                      onTap: () => Navigator.of(context).pop(),
                      size: 42,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            // Title row + the Clear all chip (reference layout).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Exam History',
                      style: RenanceText.displayMd.copyWith(
                        fontSize: 26,
                        color: context.ink,
                      ),
                    ),
                  ),
                  if (papers.isNotEmpty)
                    TactileButton(
                      onPressed: () => _confirmClearAll(papers.length),
                      outline: context.outlineVariant,
                      edge: context.outlineVariant,
                      edgeWidth: 3,
                      height: 36,
                      radius: BorderRadius.circular(10),
                      fontSize: 12.5,
                      expand: false,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: const Text('Clear all Exam History'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: papers.isEmpty
                  ? ListView( // still scrollable: pull-to-refresh works
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 72),
                          child: Column(
                            children: <Widget>[
                              const RenanceMark(size: 44),
                              const SizedBox(height: 14),
                              Text(
                                _clearedAt == 0
                                    ? 'No exam history yet - every paper you '
                                        'finish lands here with its score.'
                                    : 'History cleared. New papers you take '
                                        'will appear here.',
                                textAlign: TextAlign.center,
                                style: RenanceText.bodyBase.copyWith(
                                    color: context.textSecondary,
                                    height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: student.refresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        itemCount: papers.length,
                        separatorBuilder: (_, __) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            height: 1,
                            color: context.isDarkTier
                                ? RenanceColors.darkOutline
                                : const Color(0xFFEEEEEE),
                          ),
                        ),
                        itemBuilder: (BuildContext context, int i) {
                          return _HistoryRow(
                            index: i + 1,
                            attempt: papers[i],
                            title: student.titleForCode(papers[i].code),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One numbered history row. Left: index, subjects, "CBT · Sep 05, 2026".
/// Right: "Score 48%" (+ the raw JAMB ledger line for JAMB papers).
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.index,
    required this.attempt,
    required this.title,
  });

  final int index;
  final AttemptRow attempt;
  final String title;

  @override
  Widget build(BuildContext context) {
    final List<String> subjects = subjectsFromCode(attempt.code);
    final String nameLine = subjects.isNotEmpty
        ? subjects.join(', ')
        : (title.isEmpty || title == attempt.code
            ? _friendlyFallback(attempt.code)
            : title);
    final bool isJamb = examTypeOf(attempt.code) == 'JAMB';

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExamReportScreen(attempt: attempt),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 30,
              child: Text(
                '$index',
                style: RenanceText.statNumber.copyWith(
                  fontSize: 20,
                  color: context.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    nameLine,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodyMedium.copyWith(
                      fontSize: 17,
                      height: 1.35,
                      color: context.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${examTypeOf(attempt.code)} · ${_shortDate(
                        attempt.submittedAt ?? attempt.startedAt)}',
                    style: RenanceText.bodyBase.copyWith(
                      fontSize: 14.5,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'Score ${attempt.pct ?? 0}%',
                  style: RenanceText.statNumber.copyWith(
                    fontSize: 21,
                    color: context.ink,
                  ),
                ),
                if (isJamb)
                  Text(
                    'JAMB (${attempt.score ?? 0}/${attempt.total ?? 0})',
                    style: RenanceText.bodyBase.copyWith(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "Sep 05, 2026" - the reference's date format.
  static String _shortDate(DateTime t) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String dd = t.day.toString().padLeft(2, '0');
    return '${months[t.month - 1]} $dd, ${t.year}';
  }

  /// Composed codes that carry no subject slugs (pick papers) fall back
  /// to a readable name instead of the raw code.
  static String _friendlyFallback(String code) {
    if (code.startsWith('daily-')) return 'Daily Challenge';
    return 'Practice Paper';
  }
}
