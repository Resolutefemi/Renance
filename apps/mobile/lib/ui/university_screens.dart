/// University desks — the school picker and the per-school course desk,
/// mirroring the website's `/university`, `/university/<school>` and
/// `/university/<school>/<course>` experience.
///
/// The manifest's University Modules shelf is one flat list of
/// `uni-<school>-<course>-bank` packs (34 schools today). The picker
/// groups them by school; the desk lists a school's course banks with
/// the Post-UTME past questions as their own section, and every course
/// opens the same practice sheet the web ships: Random Mode (25/50/100
/// seeded picks) or Part pages (Q1-50, Q51-100, … contiguous slices) —
/// both real `jamb-pick-…` papers the server composes and grades.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../papers.dart';
import 'exam_screen.dart';
import 'renance_logo.dart';
import 'theme.dart';

/// slug -> (short name, full name) for every school whose banks ship.
const Map<String, (String, String)> kUniversitySchools = <String, (String, String)>{
  'aaua': ('AAUA', 'Adekunle Ajasin University, Akungba-Akoko'),
  'abu': ('ABU', 'Ahmadu Bello University'),
  'abuad': ('ABUAD', 'Afe Babalola University'),
  'achievers': ('ACHIEVERS', 'Achievers University'),
  'babcock': ('BABCOCK', 'Babcock University'),
  'bowen': ('BOWEN', 'Bowen University'),
  'bsu': ('BSU', 'Benue State University'),
  'caleb': ('CALEB', 'Caleb University'),
  'covenant': ('COVENANT', 'Covenant University'),
  'delsu': ('DELSU', 'Delta State University, Abraka'),
  'eksu': ('EKSU', 'Ekiti State University'),
  'elizade': ('ELIZADE', 'Elizade University'),
  'esut': ('ESUT', 'Enugu State University of Science and Technology'),
  'futa': ('FUTA', 'Federal University of Technology, Akure'),
  'futo': ('FUTO', 'Federal University of Technology, Owerri'),
  'greenfield': ('GREENFIELD', 'Greenfield University'),
  'igbinedion': ('IGBINEDION', 'Igbinedion University'),
  'jabu': ('JABU', 'Joseph Ayo Babalola University'),
  'ksu': ('KSU', 'Prince Abubakar Audu University, Anyigba'),
  'lasu': ('LASU', 'Lagos State University'),
  'lautech': ('LAUTECH', 'Ladoke Akintola University of Technology'),
  'leadcity': ('LEADCITY', 'Lead City University'),
  'mountain': ('MOUNTAIN', 'Mountain University'),
  'noun': ('NOUN', 'National Open University of Nigeria'),
  'oau': ('OAU', 'Obafemi Awolowo University'),
  'rsu': ('RSU', 'Rivers State University'),
  'ui': ('UI', 'University of Ibadan'),
  'uniben': ('UNIBEN', 'University of Benin'),
  'unilag': ('UNILAG', 'University of Lagos'),
  'unilorin': ('UNILORIN', 'University of Ilorin'),
  'uniosun': ('UNIOSUN', 'Osun State University'),
  'uniport': ('UNIPORT', 'University of Port Harcourt'),
  'unn': ('UNN', 'University of Nigeria, Nsukka'),
  'veritas': ('VERITAS', 'Veritas University'),
};

/// One banked course: the manifest pack plus the parsed display bits.
class UniCourse {
  const UniCourse({required this.exam, required this.school, required this.slug});

  final ExamMeta exam;
  final String school;
  final String slug;

  bool get isPostUtme => slug.startsWith('pq-');

  /// "cos101" -> "COS101"; "pq-accounting" -> "Accounting".
  String get label {
    if (isPostUtme) {
      final String tail = slug.substring(3);
      return tail
          .split('-')
          .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return slug.toUpperCase();
  }
}

/// Parses the manifest's University Modules shelf into per-school course
/// lists ("uni-futa-cos101-bank" -> school "futa", course "cos101").
Map<String, List<UniCourse>> universityCourses(List<ExamMeta> exams) {
  final Map<String, List<UniCourse>> schools = <String, List<UniCourse>>{};
  for (final ExamMeta e in exams) {
    if (!e.code.startsWith('uni-') || !e.code.endsWith('-bank')) continue;
    final String tail = e.code.substring(4, e.code.length - 5);
    final int dash = tail.indexOf('-');
    if (dash <= 0) continue;
    final String school = tail.substring(0, dash);
    final String course = tail.substring(dash + 1);
    if (course.isEmpty) continue;
    (schools[school] ??= <UniCourse>[]).add(
      UniCourse(exam: e, school: school, slug: course),
    );
  }
  for (final List<UniCourse> list in schools.values) {
    list.sort((UniCourse a, UniCourse b) => a.slug.compareTo(b.slug));
  }
  return schools;
}

// ------------------------------------------------------------------ picker

/// School picker: search + the banked schools with live pack counts.
class UniversityPickerScreen extends StatelessWidget {
  const UniversityPickerScreen({super.key, required this.exams});

  final List<ExamMeta> exams;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<UniCourse>> schools = universityCourses(exams);
    final List<String> slugs = schools.keys.toList()..sort();

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: context.ink,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('University Desk',
                      style: RenanceText.displayLg),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${schools.length} schools ship real course banks. Pick yours to practise quizzes and Post-UTME past questions.',
                    style: RenanceText.bodyBase
                        .copyWith(color: context.textSecondary),
                  ),
                ),
                Expanded(
                  child: slugs.isEmpty
                      ? const Center(child: LogoActivityIndicator(label: 'Loading schools…', size: 34))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: slugs.length,
                          itemBuilder: (BuildContext context, int i) {
                            final String slug = slugs[i];
                            final (String short, String full) =
                                kUniversitySchools[slug] ?? (slug.toUpperCase(), slug);
                            final List<UniCourse> courses = schools[slug]!;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              color: context.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.selectionBlue
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    short.length <= 5 ? short : short.substring(0, 4),
                                    style: RenanceText.labelMono.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: context.ink),
                                  ),
                                ),
                                title: Text(short,
                                    style: RenanceText.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Text(full,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RenanceText.caption.copyWith(
                                        color: context.textSecondary)),
                                trailing: Text('${courses.length} packs',
                                    style: RenanceText.labelMono.copyWith(
                                        fontSize: 11,
                                        color: context.textSecondary)),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => UniversityDeskScreen(
                                        schoolSlug: slug, courses: courses),
                                  ),
                                ),
                              ),
                            );
                          },
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

// ------------------------------------------------------------------ desk

/// One school's course desk: semester course banks plus the Post-UTME
/// past-question section, each with on-device download state and the
/// Part/Random practice sheet.
class UniversityDeskScreen extends StatefulWidget {
  const UniversityDeskScreen({
    super.key,
    required this.schoolSlug,
    required this.courses,
  });

  final String schoolSlug;
  final List<UniCourse> courses;

  @override
  State<UniversityDeskScreen> createState() => _UniversityDeskScreenState();
}

class _UniversityDeskScreenState extends State<UniversityDeskScreen> {
  List<UniCourse> get _courses => widget.courses;
  List<UniCourse> get _semesterCourses =>
      _courses.where((UniCourse c) => !c.isPostUtme).toList();
  List<UniCourse> get _postUtmeCourses =>
      _courses.where((UniCourse c) => c.isPostUtme).toList();

  (String, String) get _schoolNames =>
      kUniversitySchools[widget.schoolSlug] ??
      (widget.schoolSlug.toUpperCase(), widget.schoolSlug);

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final (String short, String full) = _schoolNames;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: context.ink,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: <Widget>[
                      Text(short, style: RenanceText.displayLg),
                      const SizedBox(height: 4),
                      Text(full,
                          style: RenanceText.bodyBase
                              .copyWith(color: context.textSecondary)),
                      const SizedBox(height: 20),
                      if (_semesterCourses.isEmpty &&
                          _postUtmeCourses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                                'No course banks for this school yet.',
                                style: RenanceText.bodySecondary),
                          ),
                        ),
                      if (_semesterCourses.isNotEmpty) ...<Widget>[
                        _sectionHeader(context, 'Course Quizzes'),
                        for (final UniCourse c in _semesterCourses)
                          _CourseTile(
                            course: c,
                            downloaded:
                                student.downloaded.contains(c.exam.code),
                            onOpen: () => _openPractice(c),
                            onDownload: () => sync.downloadExam(c.exam),
                          ),
                      ],
                      if (_postUtmeCourses.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 20),
                        _sectionHeader(context, 'Post-UTME Past Questions'),
                        for (final UniCourse c in _postUtmeCourses)
                          _CourseTile(
                            course: c,
                            downloaded:
                                student.downloaded.contains(c.exam.code),
                            onOpen: () => _openPractice(c),
                            onDownload: () => sync.downloadExam(c.exam),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: RenanceText.sectionTitle
                .copyWith(color: context.textSecondary, fontSize: 14)),
      );

  void _openPractice(UniCourse c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) => _PracticeSheet(course: c),
    );
  }
}

/// One course row: icon, label, question count, download state.
class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.course,
    required this.downloaded,
    required this.onOpen,
    required this.onDownload,
  });

  final UniCourse course;
  final bool downloaded;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onOpen,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.cardHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            course.isPostUtme ? Icons.history_edu : Icons.quiz,
            size: 22,
            color: context.ink,
          ),
        ),
        title: Text(course.label, style: RenanceText.bodyMedium),
        subtitle: Text(
          '${course.exam.questionCount} questions'
          '${downloaded ? ' · on device' : ''}',
          style: RenanceText.caption.copyWith(color: context.textSecondary),
        ),
        trailing: downloaded
            ? const Icon(Icons.check_circle,
                size: 20, color: RenanceColors.emerald)
            : IconButton(
                icon: Icon(Icons.download, size: 20,
                    color: context.textSecondary),
                onPressed: onDownload,
                tooltip: 'Download for offline',
              ),
      ),
    );
  }
}

/// The practice sheet: Random Mode + contiguous Part pages, all served
/// as real jamb-pick-… papers by the server.
class _PracticeSheet extends StatelessWidget {
  const _PracticeSheet({required this.course});

  final UniCourse course;

  static const List<int> _randomSizes = <int>[25, 50, 100];
  static const int _partSize = 50;

  void _start(BuildContext context, ExamMeta target) {
    // Close the sheet first, then open the player on the SAME root
    // navigator — re-looking-up from a popped sheet context is unsafe.
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    nav.push<void>(
      MaterialPageRoute<void>(builder: (_) => ExamScreen(exam: target)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = course.exam.questionCount;
    final int parts = () {
      final int p = (total / _partSize).ceil();
      return p < 1 ? 1 : p;
    }();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(course.label, style: RenanceText.displayMd),
            const SizedBox(height: 4),
            Text('${course.exam.title} · $total questions',
                style: RenanceText.caption
                    .copyWith(color: context.textSecondary)),
            const SizedBox(height: 16),
            Text('Random Mode',
                style: RenanceText.sectionTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (final int n in _randomSizes) ...<Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _start(
                        context,
                        pickExamMeta(
                          buildPickCode(course.exam.code, count: n),
                          course.exam,
                          count: n,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('$n Q'),
                    ),
                  ),
                  if (n != _randomSizes.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text('Part pages (original order)',
                style: RenanceText.sectionTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: <Widget>[
                  for (int p = 0; p < parts; p++)
                    OutlinedButton(
                      onPressed: () {
                        final int from = p * _partSize + 1;
                        _start(
                          context,
                          pickExamMeta(
                            buildPickCode(
                              course.exam.code,
                              count: _partSize,
                              from: from,
                            ),
                            course.exam,
                            count: _partSize,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Q${p * _partSize + 1}-'
                        '${(p + 1) * _partSize > total ? total : (p + 1) * _partSize}',
                        style: RenanceText.labelMono.copyWith(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
