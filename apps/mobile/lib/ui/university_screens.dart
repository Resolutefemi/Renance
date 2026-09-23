/// University desks - the school picker and the per-school course desk,
/// mirroring the website's `/university`, `/university/<school>` and
/// `/university/<school>/<course>` experience.
///
/// The manifest's University Modules shelf is one flat list of
/// `uni-<school>-<course>-bank` packs (34 schools today). The picker
/// groups them by school; the desk lists a school's course banks with
/// the Post-UTME past questions as their own section, and every course
/// opens the same practice sheet the web ships: Random Mode (25/50/100
/// seeded picks) or Part pages (Q1-50, Q51-100, … contiguous slices) -
/// both real `jamb-pick-…` papers the server composes and grades.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers.dart';
import '../models.dart';
import '../papers.dart';
import '../storage.dart';
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
  'mountain-top': ('MOUNTAIN', 'Mountain University'),
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

/// SharedPreferences key of the School Desk school pick (the same key the
/// website uses, so the two surfaces read one choice). The pick is made
/// ONCE from the desk's Pick School button; afterwards only the profile
/// edit can change it (founder rule).
const String kSchoolPickKey = 'renance.uni.school.v1';

/// SharedPreferences key of the Post UTME desk's school pick.
const String kPostUtmeSchoolPickKey = 'renance.postutme.school.v1';

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

/// The Post UTME shelf: `uni-<school>-pq-<subject>-bank` packs grouped by
/// school. The Post UTME desk's own entity, separate from the School Desk
/// course banks (founder rule: Post UTME sits beside JAMB/WAEC/NECO).
Map<String, List<UniCourse>> postUtmeCourses(List<ExamMeta> exams) {
  final Map<String, List<UniCourse>> schools = <String, List<UniCourse>>{};
  for (final ExamMeta e in exams) {
    final RegExpMatch? m =
        RegExp(r'^uni-([a-z0-9-]+)-pq-(.+)-bank$').firstMatch(e.code);
    if (m == null) continue;
    (schools[m.group(1)!] ??= <UniCourse>[]).add(
      UniCourse(exam: e, school: m.group(1)!, slug: 'pq-${m.group(2)}'),
    );
  }
  for (final List<UniCourse> list in schools.values) {
    list.sort((UniCourse a, UniCourse b) => a.slug.compareTo(b.slug));
  }
  return schools;
}

/// The stored School Desk pick, when it is still a banked school.
String? storedSchoolPick(Set<String> bankedSlugs, SharedPreferences prefs) {
  final String? slug = prefs.getString(kSchoolPickKey);
  if (slug != null && bankedSlugs.contains(slug)) return slug;
  return null;
}

// ------------------------------------------------------------------ picker

/// School picker: search + the banked schools with live pack counts.
/// Schools whose only banked past questions are Post-UTME (no course
/// banks) wait in the unavailable list, their content lives on the Post
/// UTME desk. Tapping an available school stores the pick (once, the
/// founder rule) and opens the desk.
class UniversityPickerScreen extends StatelessWidget {
  const UniversityPickerScreen({super.key, required this.exams});

  final List<ExamMeta> exams;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<UniCourse>> schools = universityCourses(exams);
    final Map<String, List<UniCourse>> pqSchools = postUtmeCourses(exams);
    // Available = real semester course banks; Post-UTME-only shelves are
    // listed unavailable, never as School Desk candidates.
    final List<String> available = schools.keys
        .where((String s) => schools[s]!.any((UniCourse c) => !c.isPostUtme))
        .toList()
      ..sort();
    final List<String> postUtmeOnly = pqSchools.keys
        .where((String s) => !available.contains(s))
        .toList()
      ..sort();

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
                  child: Text('School Desk',
                      style: RenanceText.displayLg),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${available.length} schools ship real course banks. Pick yours to practise semester quizzes. This pick sticks; it changes later only from your profile.',
                    style: RenanceText.bodyBase
                        .copyWith(color: context.textSecondary),
                  ),
                ),
                Expanded(
                  child: available.isEmpty
                      ? const Center(child: LogoActivityIndicator(label: 'Loading schools…', size: 34))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: available.length + postUtmeOnly.length,
                          itemBuilder: (BuildContext context, int i) {
                            if (i < available.length) {
                              final String slug = available[i];
                              final (String short, String full) =
                                  kUniversitySchools[slug] ?? (slug.toUpperCase(), slug);
                              final List<UniCourse> courses = schools[slug]!
                                  .where((UniCourse c) => !c.isPostUtme)
                                  .toList();
                              return _PickerCard(
                                slug: slug,
                                short: short,
                                full: full,
                                trailing: '${courses.length} packs',
                                onTap: () async {
                                  // The once-only pick (founder rule).
                                  await context
                                      .read<SessionStore>()
                                      .prefs
                                      .setString(kSchoolPickKey, slug);
                                  if (!context.mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => UniversityDeskScreen(
                                          schoolSlug: slug, courses: courses),
                                    ),
                                  );
                                },
                              );
                            }
                            final String slug = postUtmeOnly[i - available.length];
                            final (String short, String full) =
                                kUniversitySchools[slug] ?? (slug.toUpperCase(), slug);
                            return _PickerCard(
                              slug: slug,
                              short: short,
                              full: full,
                              trailing: 'Post-UTME only',
                              locked: true,
                              onTap: null,
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

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.slug,
    required this.short,
    required this.full,
    required this.trailing,
    required this.onTap,
    this.locked = false,
  });

  final String slug;
  final String short;
  final String full;
  final String trailing;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: locked ? context.cardLow : context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        enabled: onTap != null,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: locked
                ? context.surfaceContainer
                : context.selectionBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            short.length <= 5 ? short : short.substring(0, 4),
            style: RenanceText.labelMono.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: locked ? context.textSecondary : context.ink),
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
        trailing: Text(trailing,
            style: RenanceText.labelMono.copyWith(
                fontSize: 11,
                color: context.textSecondary)),
      ),
    );
  }
}

// ------------------------------------------------------------------ desk

/// One school's course desk: the semester course banks, each with
/// on-device download state and the Part/Random practice sheet. (Post-
/// UTME prep banks moved to their own desk, the founder's fourth focus.)
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
  List<UniCourse> get _courses =>
      widget.courses.where((UniCourse c) => !c.isPostUtme).toList();

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
                      if (_courses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                                'No course banks for this school yet.',
                                style: RenanceText.bodySecondary),
                          ),
                        ),
                      if (_courses.isNotEmpty) ...<Widget>[
                        _sectionHeader(context, 'Course Quizzes'),
                        for (final UniCourse c in _courses)
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
    showPracticeSheet(context, c);
  }
}

/// Opens the Part/Random practice sheet for a banked course. Public so
/// the Post UTME desk reuses the exact same sheet.
void showPracticeSheet(BuildContext context, UniCourse course) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext sheetContext) => _PracticeSheet(course: course),
  );
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
    // navigator - re-looking-up from a popped sheet context is unsafe.
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
