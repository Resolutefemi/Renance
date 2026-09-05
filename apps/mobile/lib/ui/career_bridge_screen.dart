/// Career bridge, the Stitch career_bridge_light screen, 1:1.
///
/// The "Where can Biology take you?" hero, the Scholarships open now
/// list, the Course cut-off explorer with its search field and filter
/// chips. The LAYOUT stays the Stitch design; the VALUES go live when
/// the student is signed in (ROADMAP #18):
///
///   GET /career         curated scholarships + course paths, committed
///                       data boot-validated server-side (topic join:
///                       every path links real syllabus topics)
///   weakest subject     from GET /syllabus/{body}, same derivation as
///                       the study plan, names the hero question
///
/// Scholarship rows open the provider's official page. Course rows open
/// the syllabus map the path's topics live in. Signed out, or when a
/// call fails, the screen quietly falls back to the exact Stitch copy.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../models.dart';
import 'syllabus_screen.dart';
import 'theme.dart';

class CareerBridgeScreen extends StatefulWidget {
  const CareerBridgeScreen({super.key});

  @override
  State<CareerBridgeScreen> createState() => _CareerBridgeScreenState();
}

class _CareerBridgeScreenState extends State<CareerBridgeScreen> {
  // Live slices; null = unknown, fall back to the Stitch copy.
  CareerData? _career;
  String? _weakestSubject;
  String _search = '';
  final Set<String> _filters = <String>{'Health'};

  static const List<String> _kFilterOptions = <String>[
    'Health',
    'Research',
    'Ecology',
  ];

  // The Stitch demo rows, kept verbatim for the signed-out render.
  static const List<({IconData icon, String title, String meta, bool urgent})>
  _kStitchScholarships = <({IconData icon, String title, String meta, bool urgent})>[
    (
      icon: Icons.school_outlined,
      title: 'National STEM Grant',
      meta: 'Closes in 12 days • \$5,000',
      urgent: true,
    ),
    (
      icon: Icons.biotech_outlined,
      title: 'Future Biotech Leaders',
      meta: 'Nov 15 Deadline • Full Tuition',
      urgent: false,
    ),
    (
      icon: Icons.eco_outlined,
      title: 'Conservation Initiative',
      meta: 'Dec 01 Deadline • \$2,500',
      urgent: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final StudentController student = context.read<StudentController>();
    if (student.me == null) return; // signed out: pure design copy
    final ApiClient? api = student.api;
    if (api == null || !mounted) return;

    try {
      final CareerData career = await api.career();
      if (!mounted) return;
      setState(() {
        _career = career;
        final Set<String> fields = <String>{
          for (final CareerPath p in career.paths) p.field,
        };
        // Keep the Stitch default selection where the data supports it.
        _filters.removeWhere((String f) => !fields.contains(f));
      });
    } on ApiException catch (_) {
      // design fallback
    } on NetworkException catch (_) {
      // design fallback
    }

    // Hero subject: the student's weakest topic's subject, the same
    // derivation the study plan uses for its practice block.
    try {
      final SyllabusTree tree = await api.syllabus(_bodySlugFor(student));
      final String topic = tree.weakest.isEmpty ? '' : tree.weakest.first.topic;
      if (!mounted) return;
      setState(() => _weakestSubject = _subjectOf(tree, topic));
    } on ApiException catch (_) {
      // design fallback
    } on NetworkException catch (_) {
      // design fallback
    }
  }

  String _bodySlugFor(StudentController student) {
    final List<String> exams = student.me?.profile?.exams ?? const <String>[];
    final String exam = exams.isEmpty ? '' : exams.first;
    if (exam.contains('WAEC')) return 'waec';
    if (exam.contains('University')) return 'university-modules';
    return 'jamb';
  }

  String? _subjectOf(SyllabusTree tree, String topic) {
    if (topic.isEmpty) return null;
    for (final SyllabusSubject s in tree.subjects) {
      for (final SyllabusSection section in s.sections) {
        for (final SyllabusTopic t in section.topics) {
          if (t.topic == topic) return s.subject;
        }
      }
    }
    return null;
  }

  List<({IconData icon, String title, String meta, bool urgent})>
  get _scholarshipRows {
    final CareerData? career = _career;
    if (career == null || career.scholarships.isEmpty) {
      return _kStitchScholarships;
    }
    return <({IconData icon, String title, String meta, bool urgent})>[
      for (final CareerScholarship s in career.scholarships)
        (
          icon: _scholarshipIcon(s.tags),
          title: s.name,
          meta: '${_levelLabel(s.level)} • ${s.coverage}',
          urgent: false, // honest windows only; never a fake countdown
        ),
    ];
  }

  IconData _scholarshipIcon(List<String> tags) => switch (
        tags.isEmpty ? '' : tags.first
      ) {
        'Health' => Icons.healing_outlined,
        'Engineering' => Icons.precision_manufacturing_outlined,
        'Tech' => Icons.computer_outlined,
        'Research' => Icons.biotech_outlined,
        _ => Icons.school_outlined,
      };

  String _levelLabel(String level) => switch (level) {
        'postgraduate' => 'Postgraduate',
        'both' => 'Undergrad & postgrad',
        _ => 'Undergraduate',
      };

  IconData _fieldIcon(String field) => switch (field) {
        'Health' => Icons.healing_outlined,
        'Research' => Icons.biotech_outlined,
        'Ecology' => Icons.eco_outlined,
        'Engineering' => Icons.precision_manufacturing_outlined,
        'Tech' => Icons.computer_outlined,
        _ => Icons.trending_up_outlined,
      };

  List<String> get _filterOptions {
    final CareerData? career = _career;
    if (career == null || career.paths.isEmpty) return _kFilterOptions;
    final Set<String> seen = <String>{};
    return <String>[
      for (final CareerPath p in career.paths)
        if (seen.add(p.field)) p.field,
    ];
  }

  List<CareerPath> get _visiblePaths {
    final CareerData? career = _career;
    if (career == null) return const <CareerPath>[];
    final String q = _search.trim().toLowerCase();
    return <CareerPath>[
      for (final CareerPath p in career.paths)
        if ((_filters.isEmpty || _filters.contains(p.field)))
          if (q.isEmpty ||
              p.course.toLowerCase().contains(q) ||
              p.universities.any(
                (String u) => u.toLowerCase().contains(q),
              ))
            p,
    ];
  }

  Future<void> _openScholarship(CareerScholarship? s) async {
    if (s == null || s.url.isEmpty) return;
    final Uri uri = Uri.tryParse(s.url) ?? Uri();
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Nothing sensible to do in-app; ignore a bad link silently.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPaths = _career != null && _career!.paths.isNotEmpty;

    return Scaffold(
      backgroundColor: context.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      color: context.ink,
                    ),
                    const SizedBox(width: 4),
                    const Text('Career Bridge',
                        style: RenanceText.sectionTitle),
                  ],
                ),
                const SizedBox(height: 16),
                // hero ------------------------------------------------------
                Container(
                  height: 190,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: context.isDarkTier
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              RenanceColors.darkSurface,
                              RenanceColors.darkSurfaceLow,
                              Color(0xFF223252),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFFEAF1FE),
                              Color(0xFFD8E3FB),
                              Color(0xFFC7D9F7),
                            ],
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Career Bridge',
                          style: RenanceText.overline
                              .copyWith(color: context.textSecondary)),
                      const Spacer(),
                      Text(
                        _weakestSubject == null
                            ? 'Where can Biology take you?'
                            : 'Where can $_weakestSubject take you?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          height: 32 / 24,
                          fontWeight: FontWeight.w700,
                          color: context.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Explore pathways and funding',
                          style: RenanceText.bodySecondary
                              .copyWith(color: context.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Scholarships open now ------------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Scholarships open now',
                      style: RenanceText.sectionTitle),
                ),
                SizedBox(height: 14),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                          color: Color(0x14141C2D),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < _scholarshipRows.length; i++) ...<Widget>[
                        if (i > 0) Divider(height: 1, color: context.outlineLight),
                        _ScholarshipRow(
                          row: _scholarshipRows[i],
                          onTap: () => _openScholarship(
                            _career == null || _career!.scholarships.isEmpty
                                ? null
                                : _career!.scholarships[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Course cut-off explorer ----------------------------------
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Course cut-off explorer',
                      style: RenanceText.sectionTitle),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                          color: Color(0x14141C2D),
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.cardLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (String v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText:
                                'Search degrees (e.g. B.Sc Marine Biology)',
                            icon: Icon(Icons.search,
                                color: context.textSecondary),
                            border: InputBorder.none,
                            filled: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final String f in _filterOptions)
                            FilterChip(
                              label: Text(f),
                              selected: _filters.contains(f),
                              onSelected: (bool v) => setState(() {
                                v ? _filters.add(f) : _filters.remove(f);
                              }),
                            ),
                        ],
                      ),
                      if (hasPaths) ...<Widget>[
                        const SizedBox(height: 6),
                        for (final CareerPath p in _visiblePaths)
                          _PathRow(
                            path: p,
                            icon: _fieldIcon(p.field),
                            onOpen: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SyllabusScreen(
                                  initialBody: _bodySlugFor(
                                    context.read<StudentController>(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_visiblePaths.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'No course matches that search yet.',
                              style: RenanceText.bodySecondary.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
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
}

/// The row shape the Stitch scholarship list uses, parameterised so both
/// the demo rows and the live rows render identically.
class _ScholarshipRow extends StatelessWidget {
  const _ScholarshipRow({required this.row, this.onTap});

  final ({IconData icon, String title, String meta, bool urgent}) row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.cardHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(row.icon, size: 24, color: context.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(row.title,
                            overflow: TextOverflow.ellipsis,
                            style:
                                RenanceText.bodyMedium.copyWith(fontSize: 17)),
                      ),
                      if (row.urgent) ...<Widget>[
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('URGENT',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: context.error,
                              )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(row.meta,
                      style: RenanceText.bodySecondary
                          .copyWith(color: context.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// One course destination row inside the explorer card: the typical
/// competitive aggregate, the subject combination and the syllabus
/// topics that decide admission. Tapping opens the syllabus map.
class _PathRow extends StatelessWidget {
  const _PathRow({required this.path, required this.icon, this.onOpen});

  final CareerPath path;
  final IconData icon;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.cardHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: context.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          path.course,
                          overflow: TextOverflow.ellipsis,
                          style: RenanceText.bodyMedium.copyWith(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.selectionBlue,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          path.cutoff,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path.subjects.join(' • '),
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodySecondary
                        .copyWith(color: context.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path.universities.join(' • '),
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.bodySecondary
                        .copyWith(color: context.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: context.textSecondary),
          ],
        ),
      ),
    );
  }
}
