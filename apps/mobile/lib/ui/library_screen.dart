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
import 'pack_detail_screen.dart';
import 'renance_logo.dart';
import 'theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.onOpenExam});

  final void Function(BuildContext, ExamMeta) onOpenExam;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryFilter { all, downloaded, inProgress, completed }

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;

  IconData _iconFor(ExamMeta exam) {
    final String t = '${exam.title} ${exam.category}'.toLowerCase();
    if (t.contains('biolog') || t.contains('microb')) return Icons.biotech;
    if (t.contains('chem')) return Icons.science;
    if (t.contains('math') || t.contains('calcul')) return Icons.calculate;
    if (t.contains('histor') || t.contains('english')) return Icons.history_edu;
    if (t.contains('physic')) return Icons.bolt;
    if (t.contains('econom')) return Icons.trending_up;
    return Icons.description;
  }

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    final StudentController student = context.watch<StudentController>();

    final List<ExamMeta> exams = sync.exams;
    final Set<String> downloaded = student.downloaded;

    bool matches(ExamMeta e) => switch (_filter) {
          _LibraryFilter.all => true,
          _LibraryFilter.downloaded => downloaded.contains(e.code),
          _LibraryFilter.inProgress =>
            sync.isSyncing && !downloaded.contains(e.code),
          _LibraryFilter.completed => student.attempts
              .any((AttemptRow a) => a.isGraded && a.code == e.code),
        };
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
          // Filter chips ---------------------------------------------------
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
                            fontSize: 12, color: Colors.black)),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: Colors.black),
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
                  style: RenanceText.bodySecondary,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? RenanceColors.selectionBlue
              : RenanceColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: RenanceText.bodyMedium.copyWith(
            fontSize: 13,
            color: selected ? RenanceColors.ink : RenanceColors.textSecondary,
          ),
        ),
      ),
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
    return Container(
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
                    const Icon(Icons.local_fire_department,
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
                  style: RenanceText.caption.copyWith(height: 1.35),
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
                          .copyWith(color: RenanceColors.textSecondary)),
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
  final IconData icon;
  final bool downloaded;
  final bool attempted;
  final bool downloading;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final double progress = downloaded ? 1.0 : 0.0;
    final Color railColor = downloaded ? RenanceColors.emerald : Colors.black;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RenanceColors.card,
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
                    color: RenanceColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 22, color: RenanceColors.ink),
                ),
                const Spacer(),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: downloading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : downloaded
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: RenanceColors.emerald
                                    .withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.check,
                                  size: 16, color: RenanceColors.emerald),
                            )
                          : InkWell(
                              onTap: onDownload,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: RenanceColors.surfaceContainerLow,
                                ),
                                child: const Icon(Icons.download,
                                    size: 16, color: RenanceColors.textSecondary),
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
              style: RenanceText.caption,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: RenanceColors.surfaceVariant,
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
