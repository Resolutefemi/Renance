/// Practice tab, the Stitch practice_library_light screen, 1:1.
///
/// Filter chips (All / Downloaded / In progress / Completed), the amber
/// Daily Quest card (real progress: questions answered today), and the
/// 2-column pack grid with per-pack download state and progress rails.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'exam_mode_setup_screen.dart';
import 'msymbols.dart';
import 'pack_detail_screen.dart';
import 'renance_logo.dart';
import 'quests_screen.dart';
import 'tactile.dart';
import 'theme.dart';
import 'university_screens.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.onOpenExam});

  final void Function(
    BuildContext,
    ExamMeta, {
    int? durationOverrideMinutes,
    bool untimed,
    bool shuffleQuestions,
  }) onOpenExam;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryFilter { all, downloaded, inProgress, completed }

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;

  /// Body shelf shown ("JAMB" | "WAEC" | "NECO" | "University Modules").
  /// null = the student's own exam body - the default, so a JAMBite's
  /// library no longer lists all 664 manifest packs including every
  /// university course bank.
  String? _bodyFilter;

  List<String> _shelves(List<String> bodies, String ownBody) =>
      <String>[if (ownBody.isNotEmpty) ownBody, ...bodies.where((String b) => b != ownBody)];

  String _iconFor(ExamMeta exam) {
    final String t = '${exam.title} ${exam.category}'.toLowerCase();
    if (t.contains('biolog') || t.contains('microb')) return 'biotech';
    if (t.contains('chem')) return 'science';
    if (t.contains('math') || t.contains('calcul')) return 'calculate';
    if (t.contains('histor') || t.contains('english')) return 'history_edu';
    if (t.contains('physic')) return 'bolt';
    if (t.contains('econom')) return 'trending_up';
    return 'description';
  }

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    final StudentController student = context.watch<StudentController>();

    final List<ExamMeta> exams = sync.exams;
    final Set<String> downloaded = student.downloaded;
    final String ownBody = student.me?.profile?.exams.isNotEmpty ?? false
        ? student.me!.profile!.exams.first
        : '';
    final String shelf = _bodyFilter ?? ownBody;

    // School Desk scoping (founder directive 2026-10-04): a tertiary
    // student's University shelf lists ONLY the picked school's packs -
    // never every school's banks. The founder keeps the full shelf (his
    // switch-school right).
    final bool founder =
        (student.me?.email ?? '').trim().toLowerCase() ==
            'ariyooluwafemi487@gmail.com';
    final String? schoolPick =
        context.read<SessionStore>().prefs.getString(kSchoolPickKey);
    final String schoolPrefix =
        (!founder && shelf == 'University Modules' && schoolPick != null)
            ? 'uni-$schoolPick-'
            : '';

    bool matches(ExamMeta e) {
      if (shelf.isNotEmpty && e.body != shelf) return false;
      if (schoolPrefix.isNotEmpty && !e.code.startsWith(schoolPrefix)) {
        return false;
      }
      return switch (_filter) {
            _LibraryFilter.all => true,
            _LibraryFilter.downloaded => downloaded.contains(e.code),
            _LibraryFilter.inProgress =>
              sync.isSyncing && !downloaded.contains(e.code),
            _LibraryFilter.completed => student.attempts
                .any((AttemptRow a) => a.isGraded && a.code == e.code),
          };
    }
    final List<ExamMeta> visible =
        exams.where(matches).toList(growable: false);

    final int today = student.todayQuestions.clamp(0, 20);

    return RefreshIndicator(
      onRefresh: () async {
        await student.refresh();
        await student.refreshDownloaded();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.paddingOf(context).top + 64 + 8, 16, 24),
        children: <Widget>[
          // Body shelves ---------------------------------------------------
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: <Widget>[
                for (final String shelfId
                    in _shelves(sync.shelfBodies.toList(), ownBody)) ...<Widget>[
                  _Chip(
                    switch (shelfId) {
                      'JAMB' => 'JAMB',
                      'WAEC' => 'WASSCE',
                      'NECO' => 'NECO',
                      // A scoped student reads their school's short name,
                      // not the generic "University".
                      'University Modules' => schoolPrefix.isNotEmpty
                          ? (kUniversitySchools[schoolPick]?.$1 ?? 'University')
                          : 'University',
                      _ => shelfId,
                    },
                    shelf == shelfId,
                    () => setState(() => _bodyFilter = shelfId),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          // Filter chips ---------------------------------------------------
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: <Widget>[
                _Chip('All', _filter == _LibraryFilter.all,
                    () => setState(() => _filter = _LibraryFilter.all)),
                const SizedBox(width: 8),
                _Chip('Downloaded', _filter == _LibraryFilter.downloaded,
                    () => setState(() => _filter = _LibraryFilter.downloaded)),
                const SizedBox(width: 8),
                _Chip('In progress', _filter == _LibraryFilter.inProgress,
                    () => setState(() => _filter = _LibraryFilter.inProgress)),
                const SizedBox(width: 8),
                _Chip('Completed', _filter == _LibraryFilter.completed,
                    () => setState(() => _filter = _LibraryFilter.completed)),
              ],
            ),
          ),
          // Daily quest ----------------------------------------------------
          const SizedBox(height: 12),
          _DailyQuestCard(done: today, goal: 20),
          // Mock exam simulator entry (JAMBites only) ----------------------
          if (student.isJambFocus) ...<Widget>[
            const SizedBox(height: 12),
            _MockExamCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExamModeSetupScreen(
                    exams: exams,
                    downloaded: downloaded,
                    onBegin: widget.onOpenExam,
                  ),
                ),
              ),
            ),
          ],
          // Packs grid -----------------------------------------------------
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Recommended Packs',
                  style: RenanceText.sectionTitle.copyWith(fontSize: 16)),
              TextButton(
                onPressed: () => setState(() => _filter = _LibraryFilter.all),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('See all',
                        style: RenanceText.labelMono.copyWith(
                            fontSize: 12, color: context.ink)),
                    MsIcon('arrow_forward',
                        size: 14, color: context.ink),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sync.exams.isEmpty && !sync.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: LogoActivityIndicator(label: 'Loading your library…', size: 34),
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  switch (_filter) {
                    _LibraryFilter.downloaded =>
                      'Nothing downloaded yet, tap the arrow on any pack.',
                    _LibraryFilter.inProgress =>
                      'Nothing downloading right now.',
                    _LibraryFilter.completed =>
                      'No graded papers yet. Run a pack to unlock review.',
                    _LibraryFilter.all => 'No packs yet.',
                  },
                  style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemCount: visible.length,
              itemBuilder: (BuildContext context, int i) {
                final ExamMeta exam = visible[i];
                return _PackCard(
                  exam: exam,
                  icon: _iconFor(exam),
                  downloaded: downloaded.contains(exam.code),
                  attempted: student.attempts
                      .any((AttemptRow a) => a.isGraded && a.code == exam.code),
                  downloading: sync.isSyncing &&
                      !downloaded.contains(exam.code),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PackDetailScreen(
                        exam: exam,
                        // Start hands straight back to the shell's fast path.
                        onStart: widget.onOpenExam,
                      ),
                    ),
                  ),
                  onDownload: () => sync.downloadExam(exam),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ chips

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      onPressed: onTap,
      face: selected ? context.selectionBlue : context.cardLow,
      onFace: selected ? context.ink : context.textSecondary,
      height: 36,
      radius: RenanceRadius.chip,
      fontSize: 12.5,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(label),
    );
  }
}

// ------------------------------------------------------------ daily quest

/// Amber-tinted quest card with the giant count and reward chip.
class _DailyQuestCard extends StatelessWidget {
  const _DailyQuestCard({required this.done, required this.goal});

  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final bool complete = done >= goal;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QuestsScreen(standalone: true)),
      ),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RenanceColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const MsIcon('local_fire_department',
                        size: 18, color: RenanceColors.amber),
                    const SizedBox(width: 6),
                    Text('DAILY QUEST',
                        style: RenanceText.labelMono.copyWith(
                            color: RenanceColors.amber,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Mock Exam Master',
                    style: RenanceText.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  'Complete 20 practice questions across any subject.',
                  style: RenanceText.caption.copyWith(color: context.textSecondary, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text('$done',
                      style: RenanceText.displayLg.copyWith(
                          color: RenanceColors.amber, letterSpacing: -1)),
                  Text(' / $goal',
                      style: RenanceText.bodyMedium
                          .copyWith(color: context.textSecondary)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: complete
                      ? RenanceColors.emerald.withValues(alpha: 0.2)
                      : RenanceColors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  complete ? 'Complete' : '+50 XP',
                  style: RenanceText.labelMono.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: complete
                        ? RenanceColors.emerald
                        : RenanceColors.amber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------- mock exam card

/// Black simulator launcher on the Practice tab: opens the Stitch
/// exam_mode_setup_light flow (format, subjects, years, then the run).
class _MockExamCard extends StatelessWidget {
  const _MockExamCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.primary,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: MsIcon('timer',
                    size: 22, color: context.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Mock Exam Setup',
                        style: RenanceText.bodyMedium
                            .copyWith(color: context.onPrimary)),
                    const SizedBox(height: 2),
                    Text('Official JAMB conditions, 2 hours, 4 subjects',
                        style: RenanceText.caption
                            .copyWith(
                                color: context.onPrimary.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              MsIcon('arrow_forward',
                  size: 20,
                  color: context.onPrimary.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- pack card

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.exam,
    required this.icon,
    required this.downloaded,
    required this.attempted,
    required this.downloading,
    required this.onTap,
    required this.onDownload,
  });

  final ExamMeta exam;
  final String icon;
  final bool downloaded;
  final bool attempted;
  final bool downloading;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final double progress = downloaded ? 1.0 : 0.0;
    final Color railColor = downloaded ? RenanceColors.emerald : context.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x14141C2D), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.cardHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MsIcon(icon, size: 22, color: context.ink),
                ),
                const Spacer(),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: downloading
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.primary),
                        )
                      : downloaded
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: RenanceColors.emerald
                                    .withValues(alpha: 0.1),
                              ),
                              child: const MsIcon('check',
                                  size: 16, color: RenanceColors.emerald),
                            )
                          : InkWell(
                              onTap: onDownload,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.cardLow,
                                ),
                                child: MsIcon('download',
                                    size: 16, color: context.textSecondary),
                              ),
                            ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              exam.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.bodyMedium.copyWith(height: 1.25),
            ),
            const SizedBox(height: 4),
            Text(
              '${exam.questionCount} Q'
              '${exam.durationMinutes != null ? ' · ${exam.durationMinutes} min' : ''}',
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: context.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(railColor),
              ),
            ),
            if (attempted) ...<Widget>[
              const SizedBox(height: 6),
              Text('Attempted',
                  style: RenanceText.labelMono.copyWith(
                      fontSize: 10, color: RenanceColors.emerald)),
            ],
          ],
        ),
      ),
    );
  }
}

