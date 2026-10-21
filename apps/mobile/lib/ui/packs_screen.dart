/// Question Pack - the Flutter twin of the web's app/packs/page.tsx,
/// the focus-aware pack shelf ("Every pack, ready offline"). The
/// founder's 2026-10-20 directive retired the old black Stitch
/// practice-library screen (ui/library_screen.dart) - this page is its
/// replacement: PageBar header, the focus line, packs grouped by shelf
/// (university students get their school's banks pinned first) and the
/// web's exact row card (icon well, title, mono count line, chevron).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'courses_screen.dart' show LearnPageBar;
import 'exam_mode_setup_screen.dart';
import 'msymbols.dart';
import 'pack_detail_screen.dart';
import 'theme.dart';
import 'university_screens.dart';

class PacksScreen extends StatelessWidget {
  const PacksScreen({super.key, required this.onOpenExam});

  final void Function(
    BuildContext,
    ExamMeta, {
    int? durationOverrideMinutes,
    bool untimed,
    bool shuffleQuestions,
  }) onOpenExam;

  @override
  Widget build(BuildContext context) {
    final SyncController sync = context.watch<SyncController>();
    final StudentController student = context.watch<StudentController>();

    // The learning focus (the web's focusOf): the profile's first target
    // exam body. null = show everything (no focus picked yet).
    final String ownBody =
        student.me?.profile?.exams.isNotEmpty ?? false
            ? student.me!.profile!.exams.first
            : '';
    final bool isUni = ownBody == 'University Modules';

    // University students: group by school with THEIR school pinned
    // first (the web's uniSchool ordering). Reuses the manifest parser
    // the desks already share (universityCourses / postUtmeCourses).
    final String? schoolPick =
        context.read<SessionStore>().prefs.getString(kSchoolPickKey);

    final List<(String, String, List<ExamMeta>)> groups =
        <(String, String, List<ExamMeta>)>[];
    if (ownBody.isEmpty) {
      if (sync.exams.isNotEmpty) {
        groups.add(('all', 'All packs', sync.exams));
      }
    } else if (!isUni) {
      final List<ExamMeta> pool = sync.exams
          .where((ExamMeta e) => e.body == ownBody)
          .toList(growable: false);
      if (pool.isNotEmpty) groups.add((ownBody, ownBody, pool));
    } else {
      final Map<String, List<ExamMeta>> bySchool = <String, List<ExamMeta>>{};
      universityCourses(sync.exams).forEach(
        (String slug, List<UniCourse> courses) => bySchool[slug] =
            courses.map((UniCourse c) => c.exam).toList(growable: false),
      );
      postUtmeCourses(sync.exams).forEach(
        (String slug, List<UniCourse> courses) {
          final List<ExamMeta> exams =
              courses.map((UniCourse c) => c.exam).toList(growable: false);
          bySchool[slug] = <ExamMeta>[...?bySchool[slug], ...exams];
        },
      );
      final List<String> order = bySchool.keys.toList()..sort();
      if (schoolPick != null && order.remove(schoolPick)) {
        order.insert(0, schoolPick);
      }
      for (final String slug in order) {
        final (String short, String full) = kUniversitySchools[slug] ??
            (slug.toUpperCase(), slug);
        groups.add((slug, '$full ($short)', bySchool[slug]!));
      }
    }

    final String focusLabel = ownBody.isEmpty
        ? ''
        : isUni
            ? schoolPick != null
                ? (kUniversitySchools[schoolPick]?.$2 ?? 'your university')
                : 'your university'
            : ownBody;
    final Set<String> downloaded = student.downloaded;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: Column(
        children: <Widget>[
          LearnPageBar(title: 'Question Pack'),
          Expanded(
            child: sync.exams.isEmpty
                ? Center(
                    child: Text(
                      'No packs yet. Set your target exam and sync to get '
                      'your first pack.',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodySecondary
                          .copyWith(color: context.textSecondary),
                    ),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: <Widget>[
                      // The web's h1 + focus lines.
                      Text('Question Pack',
                          style: RenanceText.displayLg.copyWith(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        focusLabel.isEmpty
                            ? 'Every past question pack on this device, '
                                'ready to practice.'
                            : 'Your $focusLabel past questions, ready to '
                                'practice.',
                        style: RenanceText.bodyBase
                            .copyWith(color: context.textSecondary),
                      ),
                      if (focusLabel.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Following your learning focus - change it in '
                          'Profile.',
                          style: RenanceText.caption
                              .copyWith(color: context.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 24),
                      for (final (String, String, List<ExamMeta>) g in groups)
                        _PackGroup(
                          slug: g.$1,
                          label: g.$2,
                          packs: g.$3,
                          focus: ownBody,
                          allExams: sync.exams,
                          downloaded: downloaded,
                          onOpenExam: onOpenExam,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PackGroup extends StatelessWidget {
  const _PackGroup({
    required this.slug,
    required this.label,
    required this.packs,
    required this.focus,
    required this.allExams,
    required this.downloaded,
    required this.onOpenExam,
  });

  final String slug;
  final String label;
  final List<ExamMeta> packs;
  final String focus;
  final List<ExamMeta> allExams;
  final Set<String> downloaded;
  final void Function(
    BuildContext,
    ExamMeta, {
    int? durationOverrideMinutes,
    bool untimed,
    bool shuffleQuestions,
  }) onOpenExam;

  @override
  Widget build(BuildContext context) {
    final int questions =
        packs.fold<int>(0, (int n, ExamMeta p) => n + p.questionCount);
    final bool customisable =
        focus == 'JAMB' || focus == 'WAEC' || focus == 'NECO';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${label.toUpperCase()} \u00b7 $questions questions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.labelMono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: context.textSecondary,
                  ),
                ),
              ),
              if (customisable) ...<Widget>[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExamModeSetupScreen(
                        exams: allExams,
                        downloaded: downloaded,
                        onBegin: onOpenExam,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        MsIcon('tune',
                            size: 14, color: context.ink),
                        const SizedBox(width: 4),
                        Text('Customise',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.ink,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final ExamMeta exam in packs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PackRow(
                exam: exam,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PackDetailScreen(
                      exam: exam,
                      onStart: onOpenExam,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The web's pack row: rounded-[12px] bg-card p-4 with the 48px
/// inventory well, the 15px title, the mono count line and the chevron.
class _PackRow extends StatelessWidget {
  const _PackRow({required this.exam, required this.onOpen});

  final ExamMeta exam;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.cardHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MsIcon('inventory_2', size: 24, color: context.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      exam.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exam.questionCount} Q'
                      '${exam.durationMinutes != null ? ' \u00b7 ${exam.durationMinutes} min' : ''}'
                      ' \u00b7 ${exam.totalMarks} marks',
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MsIcon('chevron_right', size: 20, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
