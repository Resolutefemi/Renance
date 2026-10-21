/// University desks - the school picker and the per-school course desk,
/// mirroring the website's `/university`, `/university/<school>` and
/// `/university/<school>/<course>` experience.
///
/// The manifest's University Modules shelf is one flat list of
/// `uni-<school>-<course>-bank` packs (36 schools today). The picker
/// groups them by school; the desk lists a school's course banks with
/// the Post-UTME past questions as their own section, and every course
/// opens the same practice sheet the web ships: Random Mode (25/50/100
/// seeded picks) or Part pages (Q1-50, Q51-100, … contiguous slices) -
/// both real `jamb-pick-…` papers the server composes and grades.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers.dart';
import '../models.dart';
import '../university_catalog.dart';
import '../papers.dart';
import '../storage.dart';
import 'exam_screen.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';



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
      // Alphabetical, with "others" (the merged general-course desk for
      // unlisted schools, founder directive 2026-10-04) pinned last -
      // the same rule as the website's selection list.
      ..sort((String a, String b) {
        if (a == 'others') return 1;
        if (b == 'others') return -1;
        return a.compareTo(b);
      });
    final List<String> postUtmeOnly = pqSchools.keys
        .where((String s) => !available.contains(s))
        .toList()
      ..sort();
    // Listed schools exclude the pinned Others row from the count.
    final int listedCount = available.where((String s) => s != 'others').length;

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
                      TactileBackKey(icon: 'arrow_back', onTap: () => Navigator.of(context).pop()),
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
                    '$listedCount schools ship real course banks. Pick yours to practise semester quizzes - or pick Other Schools for the merged general courses (every school\'s BIO 101 in one). This pick sticks; it changes later only from your profile.',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TactileCard(
        color: locked ? context.cardLow : context.card,
        radius: BorderRadius.circular(12),
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // Course search (founder directive 2026-10-11): the desk can hold a
  // school's whole catalogue, so a search field sits above the list -
  // type a code (GST 112, PHY 102) or a word and the rows filter live.
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UniCourse> get _filtered {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return _courses;
    // Course codes search without the space too ("gst112" finds
    // "GST 112"), the way students actually type them.
    final String squashed = q.replaceAll(RegExp(r'\s+'), '');
    return _courses
        .where((UniCourse c) =>
            c.label.toLowerCase().contains(q) ||
            c.label.toLowerCase().replaceAll(' ', '').contains(squashed) ||
            c.exam.title.toLowerCase().contains(q))
        .toList();
  }

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
                      TactileBackKey(icon: 'arrow_back', onTap: () => Navigator.of(context).pop()),
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
                      const SizedBox(height: 16),
                      // The course search bar ---------------------------------
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (String v) =>
                            setState(() => _query = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search courses - try "GST 112"',
                          // Founder bug (screenshot 4, 2026-10-20): the
                          // default prefixIcon constraints pinned the
                          // glyph ON the field's left border. The web
                          // field insets the icon 10px inside a 36px
                          // hit area - reproduce exactly that.
                          prefixIcon: MsFieldIcon('search',
                              size: 18, color: context.textSecondary,
                              box: 36, leftInset: 10),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const MsIcon('close', size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                        ),
                        style: RenanceText.bodyBase,
                      ),
                      const SizedBox(height: 12),
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
                        _sectionHeader(
                            context,
                            _query.trim().isEmpty
                                ? 'Course Quizzes'
                                : 'Course Quizzes · ${_filtered.length} match'
                                    '${_filtered.length == 1 ? '' : 'es'}'),
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Text(
                                  'No course matches "${_query.trim()}".',
                                  style: RenanceText.bodySecondary),
                            ),
                          ),
                        for (final UniCourse c in _filtered)
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TactileCard(
        color: context.card,
        radius: BorderRadius.circular(12),
        padding: EdgeInsets.zero,
        onTap: onOpen,
        child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.cardHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: MsIcon(
            course.isPostUtme ? 'history_edu' : 'quiz',
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
            ? const MsIcon('check_circle',
                size: 20, color: RenanceColors.emerald)
            : IconButton(
                icon: MsIcon('download', size: 20,
                    color: context.textSecondary),
                onPressed: onDownload,
                tooltip: 'Download for offline',
              ),
      ),
      ),
    );
  }
}

/// The practice sheet: Random Mode + contiguous Part pages, all served
/// as real jamb-pick-… papers by the server. A Time selector rides
/// EVERY launch - Untimed (count-up clock), a preset, or any custom
/// minute count the student types (founder directive 2026-10-05: "for
/// uni quiz add time to the quiz and allow user to be able to manually
/// set their time"). The Post UTME desk reuses the exact same sheet.
class _PracticeSheet extends StatefulWidget {
  const _PracticeSheet({required this.course});

  final UniCourse course;

  @override
  State<_PracticeSheet> createState() => _PracticeSheetState();
}

class _PracticeSheetState extends State<_PracticeSheet> {
  static const List<int> _randomSizes = <int>[25, 50, 100];
  static const int _partSize = 50;
  static const List<(String, int?)> _timePresets = <(String, int?)>[
    ('Untimed', null),
    ('15m', 15),
    ('30m', 30),
    ('60m', 60),
  ];

  /// null = Untimed (count-up clock). Default 30 - the quiz is a
  /// timed paper from now on, not a silent inherit.
  int? _chipMinutes = 30;
  final TextEditingController _customCtrl = TextEditingController();

  /// The launch timer: a filled custom field always wins over the
  /// preset chips; anything unparseable falls back to the chips.
  int? get _effectiveMinutes {
    final int? custom = int.tryParse(_customCtrl.text.trim());
    if (custom != null && custom > 0) return custom.clamp(1, 300);
    return _chipMinutes;
  }

  bool _chipSelected(int? value) {
    final int? custom = int.tryParse(_customCtrl.text.trim());
    if (custom != null && custom > 0) return false;
    return _chipMinutes == value;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _start(BuildContext context, ExamMeta target) {
    // Close the sheet first, then open the player on the SAME root
    // navigator - re-looking-up from a popped sheet context is unsafe.
    final int? minutes = _effectiveMinutes;
    final NavigatorState nav = Navigator.of(context);
    nav.pop();
    nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExamScreen(
          exam: target,
          durationOverrideMinutes: minutes,
          untimed: minutes == null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UniCourse course = widget.course;
    final int total = course.exam.questionCount;
    final int parts = () {
      final int p = (total / _partSize).ceil();
      return p < 1 ? 1 : p;
    }();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
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
              // Time selector -------------------------------------
              Text('Time',
                  style: RenanceText.sectionTitle.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  for (int i = 0; i < _timePresets.length; i++) ...<Widget>[
                    Expanded(
                      child: _TimeChip(
                        label: _timePresets[i].$1,
                        selected: _chipSelected(_timePresets[i].$2),
                        onTap: () => setState(() {
                          _chipMinutes = _timePresets[i].$2;
                          _customCtrl.clear();
                        }),
                      ),
                    ),
                    if (i != _timePresets.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  hintText: 'Custom minutes - set your own time',
                  isDense: true,
                  suffixText:
                      _customCtrl.text.trim().isEmpty ? null : 'min',
                ),
              ),
              const SizedBox(height: 16),
              Text('Random Mode',
                  style: RenanceText.sectionTitle.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  for (final int n in _randomSizes) ...<Widget>[
                    Expanded(
                      child: TactileButton(
                        onPressed: () => _start(
                          context,
                          pickExamMeta(
                            buildPickCode(course.exam.code, count: n),
                            course.exam,
                            count: n,
                          ),
                        ),
                        outline: context.outlineVariant,
                        edge: context.outlineVariant,
                        edgeWidth: 3,
                        height: 46,
                        fontSize: 14,
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
                      Center(
                        child: TactileButton(
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
                          outline: context.outlineVariant,
                          edge: context.outlineVariant,
                          edgeWidth: 3,
                          height: 44,
                          radius: BorderRadius.circular(12),
                          fontSize: 12.5,
                          expand: false,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'Q${p * _partSize + 1}-'
                            '${(p + 1) * _partSize > total ? total : (p + 1) * _partSize}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pill of the practice sheet's Time row - the setup screen's
/// selected = selection-blue tint + border, mono label.
class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? context.selectionBlue.withValues(alpha: 0.25)
              : context.cardLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? context.selectionBlue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: RenanceText.labelMono.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? context.ink : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
