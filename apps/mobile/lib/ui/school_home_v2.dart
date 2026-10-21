/// The school workspace, rebuilt (Task MOB-SCHOOL, founder directive
/// 2026-10-04): "there's nothing in school workspace on the mobile app
/// just a download pack, so let's rebuild the school workspace make sure
/// every pages on the website is on the mobile app".
///
/// A role-aware shell: MANAGEMENT gets the full desk (dashboard,
/// classes, students, results, attendance, syllabus & notes, curriculum
/// bank, ID cards, teachers, subscription, profile), TEACHERS get the
/// same pages minus teacher management and billing - and their class
/// pickers only ever offer the classes management assigned to them.
///
/// Responsive by width (tested at 360 / 600 / 900): phones get a
/// NavigationBar + drawer, tablets and landscape get a NavigationRail
/// with every destination.
///
/// Design language: the app's black & white ink look with the GGSA
/// purple ramp (#7e22ce base, #4c1d95 deep) + gold #d97706 as the
/// school chrome accent (result sheets, ID cards, chips) - the mobile
/// twin of the web's .school-bw tokens.
///
/// Attendance works offline (lib/school_offline.dart): rosters cache on
/// the device, saves queue locally and a connectivity listener replays
/// them to the database automatically.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers.dart';
import '../models.dart';
import '../nerdc_schemes.dart';
import 'msymbols.dart';
import '../school_offline.dart' show AttendanceAutoSync;
import '../storage.dart' show SessionStore;
import 'corpus_screens.dart' show CorpusBrowserScreen;
import 'renance_logo.dart' show LogoActivityIndicator;
import 'school_chrome.dart' show SchoolShellScope, schoolWorkspaceAppBar;
import 'school_screens.dart'
    show
        SchoolAttendanceScreen,
        SchoolNoteReaderScreen,
        SchoolStudentDetailsScreen,
        SchoolTermCard;
import 'theme.dart';

// --------------------------------------------------------------- GGSA chrome

/// The GGSA brand ramp (ggsa-result-portal globals.css), the school
/// chrome accent: purple base + deep purple + gold.
abstract final class SchoolInk {
  static const Color purple = Color(0xFF7E22CE); // brand-600
  static const Color purpleDeep = Color(0xFF4C1D95); // --ggsa-purple
  static const Color purple900 = Color(0xFF3B0764); // brand-900
  static const Color purple50 = Color(0xFFFAF5FF); // brand-50
  static const Color purple100 = Color(0xFFF3E8FF); // brand-100
  static const Color purple300 = Color(0xFFD8B4FE); // brand-300
  static const Color gold = Color(0xFFD97706); // --ggsa-gold
  static const Color zebra = Color(0xFFFCFAFF); // table zebra row
}

/// GGSA grade scale remarks (A 70+, B 60-69, C 50-59, D 45-49, E 40-44,
/// F 0-39 - the server's internal/school/grade.go computes the letters).
const Map<String, String> kSchoolGradeRemarks = <String, String>{
  'A': 'Excellent',
  'B': 'Very Good',
  'C': 'Good',
  'D': 'Pass',
  'E': 'Fair',
  'F': 'Fail',
};

/// GGSA paper-card trait lists (founder directive 2026-10-04): the A-E
/// rated skills + behaviour rows on the report card. Order matches the
/// web's SKILL_TRAITS / BEHAVIOUR_TRAITS exactly.
const List<String> kSkillTraitNames = <String>[
  'Handwriting',
  'Fluency',
  'Spelling',
  'Drawing',
  'Painting & Craft',
  'Music',
  'Drama',
];

const List<String> kBehaviourTraitNames = <String>[
  'Attentiveness',
  'Punctuality',
  'Neatness',
  'Politeness',
  'Honesty',
  'Reliability',
  'Obedience',
];

/// The current Nigerian academic session (flips in September).
String schoolCurrentSession() {
  final DateTime now = DateTime.now();
  final int start = now.month >= 9 ? now.year : now.year - 1;
  return '$start/${start + 1}';
}

/// The session choices the pickers offer (last, current, next).
List<String> schoolSessionChoices() {
  final int start = int.parse(schoolCurrentSession().split('/').first);
  return <String>[
    '${start - 1}/$start',
    '$start/${start + 1}',
    '${start + 1}/${start + 2}',
  ];
}

/// "First Term" for 1..3.
String schoolTermName(int term) => switch (term) {
      1 => 'First Term',
      2 => 'Second Term',
      3 => 'Third Term',
      _ => 'Term $term',
    };

/// Initials for the avatar circles ("Adaeze Okafor" -> "AO").
String schoolInitials(String name) {
  final List<String> parts =
      name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.length <= 2
        ? parts.first.toUpperCase()
        : parts.first.substring(0, 2).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// School chrome colors that stay readable in both tiers.
extension SchoolChrome on BuildContext {
  /// Purple-700 in light, purple-300 in dark - selected nav, chips, links.
  Color get schoolAccent =>
      isDarkTier ? SchoolInk.purple300 : const Color(0xFF6B21A8);

  /// The deep GGSA purple for headers and card banners.
  Color get schoolAccentDeep =>
      isDarkTier ? SchoolInk.purple300 : SchoolInk.purpleDeep;

  /// A tinted purple well (selected chips, table total cells).
  Color get schoolAccentContainer =>
      isDarkTier ? const Color(0xFF3A2A55) : SchoolInk.purple100;

  /// GGSA gold - grade column headers, serial chips, highlight strokes.
  Color get schoolGold => isDarkTier ? const Color(0xFFFFC800) : SchoolInk.gold;

  /// The result-sheet table zebra row.
  Color get schoolZebra =>
      isDarkTier ? Colors.white.withValues(alpha: 0.03) : SchoolInk.zebra;

  /// The paper ground for the result sheet / ID card face (light tier
  /// stays pure white; dark tier keeps the sheet readable on ink).
  Color get schoolPaper => isDarkTier ? const Color(0xFF11151C) : Colors.white;
}

// ---------------------------------------------------------------- arguments

/// Arguments for the deep-linkable school screens (main.dart routes).
class SchoolRouteArgs {
  const SchoolRouteArgs({required this.schoolId, this.isManager = false});

  final String schoolId;
  final bool isManager;
}

// -------------------------------------------------------------------- shell

/// One destination of the workspace (nav bar / rail / drawer share it).
class _SchoolDest {
  // The Material Symbols ligature name (web parity) - rendered via MsIcon.
  const _SchoolDest(this.label, this.msIcon, this.builder);

  final String label;
  final String msIcon;
  final WidgetBuilder builder;
}

/// The rebuilt school workspace home: role-aware shell + every page of
/// the web portal, responsive bottom bar / rail + drawer.
class SchoolWorkspaceScreen extends StatefulWidget {
  const SchoolWorkspaceScreen({super.key});

  @override
  State<SchoolWorkspaceScreen> createState() => _SchoolWorkspaceScreenState();
}

class _SchoolWorkspaceScreenState extends State<SchoolWorkspaceScreen> {
  bool _booted = false;
  String? _error;
  int _index = 0;
  AttendanceAutoSync? _autoSync;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _autoSync?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadContexts();
    final SchoolContextModel? ctx = school.activeContext;
    if (ctx == null) {
      if (!mounted) return;
      setState(() {
        _error =
            'No school membership found for this account. Sign in with the account your school created, or register the school on the web.';
        _booted = true;
      });
      return;
    }
    final String schoolId = ctx.school.id;
    // The syllabus tab reads the school's syllabus straight from online
    // (founder directive 2026-10-05: no download-pack gate) and the
    // national scheme ships inside the app - so the workspace boots
    // without pulling megabytes of pack data first.

    // The pickers' shared data: classes, subjects and (for teachers)
    // the assignment map that gates every class picker.
    await school.loadRoster(schoolId);
    await school.loadSubjects(schoolId);
    if (!ctx.member.isManagement) {
      await school.loadAssignments(schoolId, ctx.member.id);
    }
    await school.refreshPendingAttendance();
    if (!mounted) return;

    // Offline attendance auto-sync (founder directive 2026-10-04): the
    // moment any usable connection returns, queued registers replay to
    // the database. The controller is captured - it outlives this
    // screen inside the provider tree.
    final SchoolController controller = context.read<SchoolController>();
    _autoSync = AttendanceAutoSync(
      flush: controller.flushOfflineAttendance,
    )..start();
    // Also try once immediately (a queue may predate this session).
    _autoSync!.tick();

    if (!mounted) return;
    setState(() => _booted = true);
  }

  List<_SchoolDest> _destinations(bool isManager, String schoolId,
      Set<String>? allowedClassIds) {
    return <_SchoolDest>[
      _SchoolDest('Dashboard', 'dashboard',
          (BuildContext c) => _SchoolDashboardTab(
              schoolId: schoolId,
              isManager: isManager,
              onOpenTab: (int i) => setState(() => _index = i))),
      _SchoolDest(
          isManager ? 'Classes' : 'My Classes',
          'school',
          (BuildContext c) => SchoolClassesScreen(
              schoolId: schoolId,
              isManager: isManager,
              allowedClassIds: allowedClassIds)),
      _SchoolDest(
          'Students',
          'groups',
          (BuildContext c) => SchoolStudentDetailsScreen(schoolId: schoolId)),
      _SchoolDest(
          'Results',
          'workspace_premium',
          (BuildContext c) => SchoolResultsScreen(
              schoolId: schoolId,
              isManager: isManager,
              allowedClassIds: allowedClassIds)),
      _SchoolDest(
          'Attendance',
          'fact_check',
          (BuildContext c) => SchoolAttendanceScreen(schoolId: schoolId)),
      _SchoolDest(
          'Syllabus & Notes',
          'auto_stories',
          (BuildContext c) => _SyllabusTab(
              schoolId: schoolId,
              onOpenTab: (int i) => setState(() => _index = i))),
      _SchoolDest('Curriculum Bank', 'account_balance',
          (BuildContext c) => const CorpusBrowserScreen()),
      _SchoolDest(
          'ID Cards',
          'badge',
          (BuildContext c) => SchoolIdCardsScreen(
              schoolId: schoolId,
              isManager: isManager,
              allowedClassIds: allowedClassIds)),
      if (isManager)
        _SchoolDest('Teachers', 'co_present',
            (BuildContext c) => SchoolTeachersScreen(schoolId: schoolId)),
      if (isManager)
        _SchoolDest('Billing', 'payments',
            (BuildContext c) => SchoolBillingScreen(schoolId: schoolId)),
      _SchoolDest('Profile', 'person',
          (BuildContext c) => const _SchoolProfileTab()),
    ];
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();

    if (!_booted || school.loadingContexts) {
      return Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(title: const Text('School workspace')),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const MsIcon('school', size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: RenanceText.bodyBase
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () async {
                          await context.read<SessionStore>().clear();
                          if (!context.mounted) return;
                          await Navigator.of(context)
                              .pushReplacementNamed('/login');
                        },
                        child: const Text('Sign in with another account'),
                      ),
                    ],
                  ),
                )
              : const LogoActivityIndicator(label: 'Opening your school…'),
        ),
      );
    }

    final SchoolContextModel? ctx = school.activeContext;
    if (ctx == null) {
      return Scaffold(
        backgroundColor: context.pageBg,
        appBar: AppBar(title: const Text('School workspace')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              _error ?? 'No school membership found for this account.',
              textAlign: TextAlign.center,
              style:
                  RenanceText.bodyBase.copyWith(color: context.textSecondary),
            ),
          ),
        ),
      );
    }

    final bool isManager = ctx.member.isManagement;
    final String schoolId = ctx.school.id;
    final Set<String>? allowedClassIds = school.allowedClassIds();
    final List<_SchoolDest> dests =
        _destinations(isManager, schoolId, allowedClassIds);
    final int index = _index < dests.length ? _index : 0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool wide = width >= 760;
        final bool extended = width >= 1080;

        final Widget body = SchoolShellScope(
          openDrawer: _openDrawer,
          // The phone layout carries the menu at the right of the top
          // navbar; the tablet rail carries every destination itself.
          showMenu: !wide,
          child: IndexedStack(
            index: index,
            children: <Widget>[
              for (int i = 0; i < dests.length; i++)
                _LazyTab(
                  active: i == index,
                  builder: dests[i].builder,
                ),
            ],
          ),
        );

        if (wide) {
          // Tablet / landscape / desktop: the rail carries everything.
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: context.pageBg,
            body: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (int i) =>
                      setState(() => _index = i),
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.selected,
                  selectedIconTheme: IconThemeData(color: context.schoolAccent),
                  selectedLabelTextStyle:
                      TextStyle(color: context.schoolAccent),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: context.schoolAccentDeep,
                          foregroundColor: Colors.white,
                          child: Text(
                            schoolInitials(ctx.school.name),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (school.pendingAttendance > 0) ...<Widget>[
                          const SizedBox(height: 8),
                          Tooltip(
                            message:
                                '${school.pendingAttendance} offline register(s) waiting to sync',
                            child: Badge(
                              label: Text('${school.pendingAttendance}'),
                              child: const MsIcon('cloud_sync',
                                  size: 20),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  destinations: <NavigationRailDestination>[
                    for (final _SchoolDest d in dests)
                      NavigationRailDestination(
                        icon: MsIcon(d.msIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        // Phone: bottom bar with the four most-used pages; the full
        // page list (Menu) lives at the right of the top navbar.
        final List<int> barDests = isManager
            ? <int>[0, 1, 2, 3] // Dashboard, Classes, Students, Results
            : <int>[0, 1, 4, 3]; // Dashboard, My Classes, Attendance, Results
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: context.pageBg,
          drawer: _SchoolDrawer(
            dests: dests,
            selectedIndex: index,
            onPick: (int i) {
              setState(() => _index = i);
              Navigator.of(context).pop();
            },
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomSelected(barDests),
            onDestinationSelected: (int i) =>
                setState(() => _index = barDests[i]),
            destinations: <Widget>[
              for (final int d in barDests)
                NavigationDestination(
                  icon: MsIcon(dests[d].msIcon),
                  label: dests[d].label,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Which bottom-bar slot is highlighted (Menu never sticks).
  int _bottomSelected(List<int> barDests) {
    final int i = barDests.indexOf(_index);
    return i < 0 ? 0 : i;
  }
}

/// Builds its child the first time it becomes active, then keeps it
/// alive (IndexedStack keeps it mounted) so pickers and half-filled
/// registers survive tab switches without every tab booting at once.
class _LazyTab extends StatefulWidget {
  const _LazyTab({required this.active, required this.builder});

  final bool active;
  final WidgetBuilder builder;

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  bool _built = false;

  @override
  void didUpdateWidget(_LazyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      _built = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active) {
      _built = true;
    }
    if (!_built) {
      return const SizedBox.shrink();
    }
    return widget.builder(context);
  }
}

/// The phone drawer: school identity, every destination, sign-out.
class _SchoolDrawer extends StatelessWidget {
  const _SchoolDrawer({
    required this.dests,
    required this.selectedIndex,
    required this.onPick,
  });

  final List<_SchoolDest> dests;
  final int selectedIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final SchoolContextModel? ctx = school.activeContext;

    return Drawer(
      backgroundColor: context.pageBg,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // Identity band - GGSA purple.
            Container(
              width: double.infinity,
              color: context.schoolAccentDeep,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ctx?.school.name ?? 'School workspace',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          ctx?.member.isManagement == true
                              ? 'MANAGEMENT'
                              : 'TEACHER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ctx?.member.fullName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: <Widget>[
                  for (int i = 0; i < dests.length; i++)
                    ListTile(
                      selected: i == selectedIndex,
                      selectedColor: context.schoolAccent,
                      selectedTileColor: context.schoolAccentContainer,
                      leading: MsIcon(dests[i].msIcon, size: 22),
                      title: Text(
                        dests[i].label,
                        style: RenanceText.bodyBase.copyWith(fontSize: 14),
                      ),
                      onTap: () => onPick(i),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const MsIcon('logout', fill: true, size: 22),
              title: Text('Sign out',
                  style: RenanceText.bodyBase.copyWith(fontSize: 14)),
              onTap: () async {
                final SessionStore session = context.read<SessionStore>();
                await SchoolController.forgetSchoolSession(session.prefs);
                await session.clear();
                if (!context.mounted) return;
                await Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- dashboard

/// The school home desk, mirroring the web /school page: identity band,
/// live stats, quick actions, the offline queue card.
class _SchoolDashboardTab extends StatefulWidget {
  const _SchoolDashboardTab({
    required this.schoolId,
    required this.isManager,
    required this.onOpenTab,
  });

  final String schoolId;
  final bool isManager;
  final ValueChanged<int> onOpenTab;

  @override
  State<_SchoolDashboardTab> createState() => _SchoolDashboardTabState();
}

class _SchoolDashboardTabState extends State<_SchoolDashboardTab> {
  int _studentCount = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    if (widget.isManager) {
      // School-wide student count for the stat band (the roster state is
      // shared; other tabs re-point it at their own class on open).
      await school.loadRoster(widget.schoolId);
      if (!mounted) return;
      setState(() => _studentCount = school.roster.length);
      await school.loadPlan(widget.schoolId);
    } else {
      final SchoolContextModel? ctx = school.activeContext;
      if (ctx != null && school.assignments.isEmpty) {
        await school.loadAssignments(widget.schoolId, ctx.member.id);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final SchoolContextModel? ctx = school.activeContext;
    if (ctx == null) {
      return const SizedBox.shrink();
    }
    final bool isManager = widget.isManager;
    final Set<String> assignedClasses = <String>{
      for (final SchoolAssignmentModel a in school.assignments) a.classId,
    };
    final Set<String> assignedSubjects = <String>{
      for (final SchoolAssignmentModel a in school.assignments) a.subjectId,
    };

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(
        context,
        pageTitle: 'Dashboard',
        actions: <Widget>[
          if (school.pendingAttendance > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ActionChip(
                avatar: const MsIcon('cloud_sync', size: 16),
                label: Text('${school.pendingAttendance}'),
                onPressed: () => _syncNow(context),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Identity band - GGSA purple ground, like the web heading.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.schoolAccentDeep,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Welcome, ${ctx.member.fullName.isEmpty ? (isManager ? 'Management' : 'Teacher') : ctx.member.fullName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isManager
                      ? 'Run the whole school from one desk: curriculum, syllabuses with notes, attendance, students, staff and results.'
                      : 'Your assigned classes, the syllabus and notes you teach from, the register and the results you fill.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stat band - responsive grid.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int columns = c.maxWidth >= 900
                  ? 4
                  : c.maxWidth >= 560
                      ? 2
                      : 2;
              final List<({String label, String value})> stats = isManager
                  ? <({String label, String value})>[
                      (label: 'Classes', value: '${school.classes.length}'),
                      (label: 'Students enrolled',
                          value: _studentCount < 0
                              ? '…'
                              : '$_studentCount'),
                      (label: 'Subjects', value: '${school.subjects.length}'),
                      (label: 'My assignments',
                          value: '${school.assignments.length}'),
                    ]
                  : <({String label, String value})>[
                      (label: 'My assignments',
                          value: '${school.assignments.length}'),
                      (label: 'Classes I cover',
                          value: '${assignedClasses.length}'),
                      (label: 'Subjects I cover',
                          value: '${assignedSubjects.length}'),
                      (label: 'Offline sheets',
                          value: '${school.pendingAttendance}'),
                    ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.4,
                children: <Widget>[
                  for (final ({String label, String value}) s in stats)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: context.outlineVariant),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.value,
                            style: RenanceText.statNumber.copyWith(
                                color: context.schoolAccent, fontSize: 22),
                          ),
                          Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RenanceText.caption
                                .copyWith(color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Teacher's assignment chips (the founder's "only the classes
          // the admin gives them" made visible).
          if (!isManager) ...<Widget>[
            if (school.assignments.isEmpty)
              _InfoCard(
                icon: 'info',
                child: Text(
                  'No assignments yet. Management will grant you classes and subjects from the Teachers page.',
                  style: RenanceText.bodySecondary
                      .copyWith(color: context.textSecondary, fontSize: 13.5),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final SchoolAssignmentModel a in school.assignments)
                    Chip(
                      avatar: MsIcon('school',
                          size: 15, color: context.schoolAccent),
                      label: Text('${a.className} · ${a.subjectName}'),
                      labelStyle: RenanceText.caption,
                    ),
                ],
              ),
            const SizedBox(height: 16),
          ],

          // Offline queue card (attendance auto-sync).
          _InfoCard(
            icon: 'cloud_sync',
            color: context.schoolAccentContainer,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    school.pendingAttendance > 0
                        ? '${school.pendingAttendance} register sheet(s) saved on this phone - they sync automatically when the network returns.'
                        : 'Attendance works offline: rosters cache on this phone and marked registers sync the moment the network returns.',
                    style: RenanceText.bodySecondary
                        .copyWith(color: context.textSecondary, fontSize: 13.5),
                  ),
                ),
                if (school.pendingAttendance > 0)
                  TextButton(
                    onPressed: () => _syncNow(context),
                    child: const Text('Sync now'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions.
          Text('QUICK ACTIONS',
              style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int columns = c.maxWidth >= 900
                  ? 3
                  : c.maxWidth >= 560
                      ? 2
                      : 1;
              final List<({String icon, String title, String body, int tab})>
                  actions = isManager
                      ? <({String icon, String title, String body, int tab})>[
                          (icon: 'auto_stories', title: 'Syllabus & Notes', body: 'Term syllabuses, topics and the national scheme, live from online.', tab: 5),
                          (icon: 'fact_check', title: 'Attendance', body: 'Mark the daily register - works offline.', tab: 4),
                          (icon: 'groups', title: 'Students', body: 'Enroll pupils with full details.', tab: 2),
                          (icon: 'workspace_premium', title: 'Results', body: 'The broadsheet, score entry and report sheets.', tab: 3),
                          (icon: 'co_present', title: 'Teachers', body: 'Create staff accounts and hand out class subjects.', tab: 8),
                          (icon: 'badge', title: 'ID Cards', body: 'Serial-numbered student cards with previews.', tab: 7),
                          (icon: 'payments', title: 'Billing', body: 'The subscription plan and its countdown.', tab: 9),
                          (icon: 'account_balance', title: 'Curriculum Bank', body: 'National scheme of work and lesson notes.', tab: 6),
                        ]
                      : <({String icon, String title, String body, int tab})>[
                          (icon: 'auto_stories', title: 'My Syllabus & Notes', body: 'The classes and subjects assigned to you.', tab: 5),
                          (icon: 'fact_check', title: 'Attendance', body: 'Take the register for a class you cover.', tab: 4),
                          (icon: 'workspace_premium', title: 'Fill Results', body: 'Your assigned class + subject score cells.', tab: 3),
                          (icon: 'badge', title: 'ID Cards', body: 'Preview and share student cards.', tab: 7),
                          (icon: 'account_balance', title: 'Curriculum Bank', body: 'National scheme of work and lesson notes.', tab: 6),
                        ];
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: <Widget>[
                  for (final a in actions)
                    Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onOpenTab(a.tab),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: <Widget>[
                              Container(alignment: Alignment.center,
                                
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: context.schoolAccentContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: MsIcon(a.icon,
                                    size: 20, color: context.schoolAccent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      a.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RenanceText.bodyBase.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      a.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: RenanceText.caption.copyWith(
                                          color: context.textSecondary,
                                          fontSize: 11.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Plan mini-card (management).
          if (isManager) ...<Widget>[
            if (school.plan != null) _PlanCard(plan: school.plan!),
            const SizedBox(height: 12),
          ],

          Text(
            'The syllabus and scheme of work open straight from online, the national NERDC scheme ships inside the app itself, and attendance marks cache on this phone until the network returns.',
            style: RenanceText.caption.copyWith(
                color: context.textSecondary, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    final SchoolController school = context.read<SchoolController>();
    final int synced = await school.flushOfflineAttendance();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(synced > 0
            ? 'Synced $synced offline register(s) to the database.'
            : 'Nothing to sync right now.'),
      ),
    );
  }
}

/// A soft info card.
class _InfoCard extends StatelessWidget {
  // The Material Symbols ligature name (web parity).
  const _InfoCard({required this.icon, required this.child, this.color});

  final String icon;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? context.cardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MsIcon(icon, size: 20, color: context.schoolAccent),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The subscription plan card (management, mirrors GET /school/plan).
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final SchoolPlanModel plan;

  @override
  Widget build(BuildContext context) {
    final bool trial = plan.plan == 'trial';
    return Container(alignment: Alignment.center,
      
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(alignment: Alignment.center,
            
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.schoolAccentContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: MsIcon('workspace_premium',
                size: 22, color: context.schoolAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plan.plan.toUpperCase(),
                  style: RenanceText.bodyBase
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  trial
                      ? (plan.trialDaysLeft != null
                          ? 'Trial - ${plan.trialDaysLeft} day(s) left'
                          : 'Trial')
                      : (plan.daysLeft != null
                          ? '${plan.daysLeft} day(s) left'
                          : 'Active'),
                  style: RenanceText.caption
                      .copyWith(color: context.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openSubscription(context),
            child: const Text('Billing'),
          ),
        ],
      ),
    );
  }
}

void _openSubscription(BuildContext context) {
  // The plans/checkout flow lives on the web portal; the app reads the
  // summary and hands off.
  launchUrl(
    Uri.parse('https://renance.app/school/subscription'),
    mode: LaunchMode.externalApplication,
  ).catchError((Object _) => false);
}

// ------------------------------------------------------------- syllabus tab

/// The syllabus + scheme of work tab, ONLINE-FIRST (founder directive
/// 2026-10-05): the school's own terms read straight from the API -
/// the same fetch the web portal makes, no download-pack button
/// anywhere - and, when the school has not written a class + subject
/// yet, the NERDC national scheme of work carried inside the app
/// itself (assets/nerdc_schemes.json, zero network).
class _SyllabusTab extends StatefulWidget {
  const _SyllabusTab({required this.schoolId, required this.onOpenTab});

  final String schoolId;
  final ValueChanged<int> onOpenTab;

  @override
  State<_SyllabusTab> createState() => _SyllabusTabState();
}

class _SyllabusTabState extends State<_SyllabusTab> {
  List<SchoolClassSubjectPair> _pairs = const <SchoolClassSubjectPair>[];
  String? _classId;
  String? _subjectId;
  int _term = 1;
  int _nationalTerm = 1;
  bool _booted = false;
  bool _loadingTerms = false;
  List<SchoolSyllabusTerm> _terms = const <SchoolSyllabusTerm>[];
  NerdcSchemes? _national;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    final SchoolContextModel? ctx = school.activeContext;
    List<SchoolClassSubjectPair> pairs = const <SchoolClassSubjectPair>[];
    if (ctx != null && !ctx.member.isManagement) {
      // Teachers see exactly their assigned class+subject pairs - the
      // web portal's rule.
      if (school.assignments.isEmpty) {
        await school.loadAssignments(widget.schoolId, ctx.member.id);
      }
      pairs = <SchoolClassSubjectPair>[
        for (final SchoolAssignmentModel a in school.assignments)
          SchoolClassSubjectPair(
            classId: a.classId,
            className: a.className,
            subjectId: a.subjectId,
            subjectName: a.subjectName,
          ),
      ];
    } else {
      pairs = await school.loadClassSubjects(widget.schoolId);
    }
    NerdcSchemes? national;
    try {
      national = await NerdcSchemes.load();
    } catch (_) {
      national = null; // the asset ships with the app; this never fires
    }
    if (!mounted) return;
    setState(() {
      _pairs = pairs;
      _national = national;
      _booted = true;
      if (pairs.isNotEmpty) {
        _classId = pairs.first.classId;
        _subjectId = pairs.first.subjectId;
      }
    });
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    final String? classId = _classId;
    final String? subjectId = _subjectId;
    if (classId == null || subjectId == null) return;
    setState(() {
      _loadingTerms = true;
      _terms = const <SchoolSyllabusTerm>[];
    });
    final List<SchoolSyllabusTerm> terms = await context
        .read<SchoolController>()
        .loadSchoolSyllabus(widget.schoolId, classId, subjectId);
    if (!mounted) return;
    setState(() {
      _terms = terms;
      _loadingTerms = false;
      _term = terms.any((SchoolSyllabusTerm t) => t.term == 1) || terms.isEmpty
          ? 1
          : terms.first.term;
    });
  }

  String _termName(int t) => switch (t) {
        1 => 'First Term',
        2 => 'Second Term',
        _ => 'Third Term',
      };

  @override
  Widget build(BuildContext context) {
    final Map<String, String> classes = <String, String>{
      for (final SchoolClassSubjectPair p in _pairs) p.classId: p.className,
    };
    final Map<String, String> subjects = <String, String>{
      for (final SchoolClassSubjectPair p in _pairs)
        if (p.classId == _classId) p.subjectId: p.subjectName,
    };
    final String className = classes[_classId] ?? '';
    final String subjectName = subjects[_subjectId] ?? '';

    // The national fallback, matched by name like the web portal does.
    final NerdcClass? nationalClass =
        _national?.classForSchoolName(className);
    final NerdcSubject? nationalSubject =
        nationalClass == null || subjectName.isEmpty
            ? null
            : _national!.subjectForSchoolName(nationalClass, subjectName);
    final NerdcTermScheme? nationalScheme =
        nationalSubject?.term(_nationalTerm);
    final SchoolSyllabusTerm? term =
        _terms.where((SchoolSyllabusTerm t) => t.term == _term).firstOrNull;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(context, pageTitle: 'Syllabus & Notes'),
      body: !_booted
          ? Center(
              child: const LogoActivityIndicator(label: 'Opening the syllabus…'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // The head-start banner (the web portal's): the bank
                // carries a ready scheme for every class.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.cardLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'The national curriculum bank carries a NERDC-aligned scheme of work for every class.',
                          style: RenanceText.bodySecondary.copyWith(
                              color: context.textSecondary, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => widget.onOpenTab(6),
                        child: const Text('Curriculum bank'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _picker(
                  value: _classId,
                  items: classes,
                  label: 'Class',
                  onChanged: (String? v) => setState(() {
                    _classId = v;
                    _subjectId = _pairs
                        .where((SchoolClassSubjectPair p) => p.classId == v)
                        .map((SchoolClassSubjectPair p) => p.subjectId)
                        .firstOrNull;
                  }),
                ),
                const SizedBox(height: 10),
                _picker(
                  value: _subjectId,
                  items: subjects,
                  label: 'Subject',
                  onChanged: (String? v) => setState(() => _subjectId = v),
                ),
                const SizedBox(height: 16),
                if (_loadingTerms)
                  const Center(
                      child: LogoActivityIndicator(label: 'Loading the term…'))
                else if (_terms.isNotEmpty) ...<Widget>[
                  if (_terms.length > 1) ...<Widget>[
                    SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        for (final SchoolSyllabusTerm t in _terms)
                          ButtonSegment<int>(
                              value: t.term, label: Text(_termName(t.term))),
                      ],
                      selected: <int>{_term},
                      onSelectionChanged: (Set<int> s) =>
                          setState(() => _term = s.first),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (term != null)
                    SchoolTermCard(
                      term: term,
                      className: className,
                      subject: subjectName,
                    ),
                ] else if (nationalSubject != null &&
                    nationalSubject.terms.isNotEmpty) ...<Widget>[
                  // The national scheme of work, read off the app itself.
                  Text(
                    'National curriculum · $className · $subjectName',
                    style: RenanceText.sectionTitle.copyWith(color: context.ink),
                  ),
                  const SizedBox(height: 8),
                  if (nationalSubject.terms.length > 1) ...<Widget>[
                    SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        for (final NerdcTermScheme t in nationalSubject.terms)
                          ButtonSegment<int>(
                              value: t.term, label: Text(_termName(t.term))),
                      ],
                      selected: <int>{_nationalTerm},
                      onSelectionChanged: (Set<int> s) =>
                          setState(() => _nationalTerm = s.first),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (nationalScheme == null ||
                      nationalScheme.weeks.isEmpty)
                    Text(
                      'No scheme of work for ${_termName(_nationalTerm)} yet.',
                      style: RenanceText.bodySecondary
                          .copyWith(color: context.textSecondary),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${_termName(_nationalTerm)} scheme of work',
                              style: RenanceText.sectionTitle
                                  .copyWith(color: context.ink),
                            ),
                            const SizedBox(height: 10),
                            for (final NerdcWeek w in nationalScheme.weeks)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.schoolAccentContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${w.week}',
                                    style: RenanceText.caption.copyWith(
                                        color: context.schoolAccent,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Text(
                                  w.topic,
                                  style: RenanceText.bodyBase.copyWith(
                                      color: context.ink,
                                      fontWeight: FontWeight.w500),
                                ),
                                trailing: const MsIcon('chevron_right', fill: true,
                                    size: 18),
                                onTap: () => _openNationalWeek(
                                    className, subjectName, w),
                              ),
                          ],
                        ),
                      ),
                    ),
                ] else
                  Text(
                    'No syllabus for this class + subject yet. Management can build it on the web portal - anything the school writes appears here.',
                    style: RenanceText.bodySecondary
                        .copyWith(color: context.textSecondary),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  void _openNationalWeek(String className, String subjectName, NerdcWeek w) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SchoolNoteReaderScreen(
        topic: SchoolTopicInfo(
          id: 'national-$className-$subjectName-w${w.week}',
          title: w.topic,
          seq: w.week,
          week: w.week,
          content: w.content,
          source: 'renance-corpus',
        ),
        schoolName: 'Renance national curriculum',
        className: className,
        subject: subjectName,
        termName: _termName(_nationalTerm),
      ),
    ));
  }

  Widget _picker({
    required String? value,
    required Map<String, String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        fillColor: context.card,
      ),
      items: <DropdownMenuItem<String>>[
        for (final MapEntry<String, String> e in items.entries)
          DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
      ],
      onChanged: onChanged,
    );
  }
}

// ------------------------------------------------------------------ classes

/// The Classes page: every class (teacher: only the assigned ones) with
/// a detail view of students, subjects and the term syllabus.
class SchoolClassesScreen extends StatefulWidget {
  const SchoolClassesScreen({
    super.key,
    required this.schoolId,
    required this.isManager,
    this.allowedClassIds,
  });

  final String schoolId;
  final bool isManager;
  final Set<String>? allowedClassIds;

  @override
  State<SchoolClassesScreen> createState() => _SchoolClassesScreenState();
}

class _SchoolClassesScreenState extends State<SchoolClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    if (school.classes.isEmpty) {
      await school.loadRoster(widget.schoolId);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final Set<String>? allowed = widget.allowedClassIds;
    final List<SchoolClassInfo> classes = school.classes
        .where((SchoolClassInfo c) =>
            allowed == null || allowed.contains(c.id))
        .toList(growable: false)
      ..sort((SchoolClassInfo a, SchoolClassInfo b) => a.seq.compareTo(b.seq));

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(
          context, pageTitle: widget.isManager ? 'Classes' : 'My Classes'),
      body: school.rosterLoading && school.classes.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : classes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      widget.isManager
                          ? 'No classes yet. Management seeds the Nigerian curriculum on the web portal.'
                          : 'No classes assigned to you yet. Your school management grants them from the Teachers page.',
                      textAlign: TextAlign.center,
                      style: RenanceText.bodyBase
                          .copyWith(color: context.textSecondary),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    if (school.offlineMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: <Widget>[
                            MsIcon('cloud_off',
                                size: 16, color: context.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Offline - showing this phone\'s cached roster.',
                                style: RenanceText.caption
                                    .copyWith(color: context.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        final int columns = c.maxWidth >= 900
                            ? 3
                            : c.maxWidth >= 560
                                ? 2
                                : 1;
                        return GridView.count(
                          crossAxisCount: columns,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.9,
                          children: <Widget>[
                            for (final SchoolClassInfo cls in classes)
                              Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => _SchoolClassDetailScreen(
                                        schoolId: widget.schoolId,
                                        cls: cls,
                                        isManager: widget.isManager,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: context
                                                    .schoolAccentContainer,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                cls.level.toUpperCase(),
                                                style: TextStyle(
                                                  color:
                                                      context.schoolAccent,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          cls.name,
                                          style: RenanceText.sectionTitle,
                                        ),
                                        Text(
                                          'Students, subjects and syllabus',
                                          style: RenanceText.caption.copyWith(
                                              color: context.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}

/// One class: students grid, subjects, term/session picker + the
/// syllabus branches of the downloaded pack for that term.
class _SchoolClassDetailScreen extends StatefulWidget {
  const _SchoolClassDetailScreen({
    required this.schoolId,
    required this.cls,
    required this.isManager,
  });

  final String schoolId;
  final SchoolClassInfo cls;
  final bool isManager;

  @override
  State<_SchoolClassDetailScreen> createState() =>
      _SchoolClassDetailScreenState();
}

class _SchoolClassDetailScreenState extends State<_SchoolClassDetailScreen> {
  int _term = 1;
  String _session = schoolCurrentSession();
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadRoster(widget.schoolId, classId: widget.cls.id);
    if (mounted) setState(() => _booted = true);
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final List<SchoolStudentModel> roster = school.roster
        .where((SchoolStudentModel s) =>
            s.classId == widget.cls.id && s.status == 'active')
        .toList(growable: false);
    final List<SchoolSubjectInfo> subjects = school.subjects
        .where((SchoolSubjectInfo s) =>
            s.level == 'both' || s.level == widget.cls.level)
        .toList(growable: false);

    // The downloaded pack's branches for this class + term + session.
    final SchoolPack? pack = school.packs[widget.schoolId];
    final List<SchoolPackSyllabus> branches = pack == null
        ? <SchoolPackSyllabus>[]
        : pack.syllabus
            .where((SchoolPackSyllabus b) =>
                b.classId == widget.cls.id &&
                b.terms.any((SchoolSyllabusTerm t) =>
                    t.term == _term &&
                    (_session.isEmpty || t.session.isEmpty || t.session == _session)))
            .toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar:
          schoolWorkspaceAppBar(context, pageTitle: widget.cls.name),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Term + session picker.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 1, label: Text('Term 1')),
                  ButtonSegment<int>(value: 2, label: Text('Term 2')),
                  ButtonSegment<int>(value: 3, label: Text('Term 3')),
                ],
                selected: <int>{_term},
                onSelectionChanged: (Set<int> s) =>
                    setState(() => _term = s.first),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  initialValue: _session,
                  decoration: const InputDecoration(
                    labelText: 'Session',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String s in schoolSessionChoices())
                      DropdownMenuItem<String>(value: s, child: Text(s)),
                  ],
                  onChanged: (String? v) =>
                      setState(() => _session = v ?? _session),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Students.
          Text('STUDENTS (${roster.length})',
              style:
                  RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          if (school.rosterLoading && !_booted)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (roster.isEmpty)
            Text(
              'No active pupils enrolled in this class yet.',
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final int columns = c.maxWidth >= 900
                    ? 4
                    : c.maxWidth >= 600
                        ? 3
                        : c.maxWidth >= 400
                            ? 2
                            : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: <Widget>[
                    for (final SchoolStudentModel s in roster)
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showStudent(context, s),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      s.sex == 'F'
                                          ? const Color(0xFFFCE7F3)
                                          : const Color(0xFFDBEAFE),
                                  foregroundColor: s.sex == 'F'
                                      ? const Color(0xFF9D174D)
                                      : const Color(0xFF1E40AF),
                                  child: Text(
                                    schoolInitials(s.fullName),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: RenanceText.bodyBase.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                Text(
                                  s.admissionNo,
                                  style: RenanceText.caption.copyWith(
                                      color: context.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),

          // Subjects offered at this level.
          Text('SUBJECTS (${subjects.length})',
              style:
                  RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SchoolSubjectInfo s in subjects)
                Chip(
                  label: Text(s.name),
                  labelStyle: RenanceText.caption,
                  backgroundColor: context.card,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Term syllabus (from the offline pack).
          Text('TERM $_term SYLLABUS',
              style:
                  RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          if (branches.isEmpty)
            Text(
              pack == null
                  ? 'Download the school pack from Syllabus & Notes to read topics offline.'
                  : 'No syllabus content for this class/term in the pack yet.',
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            )
          else
            for (final SchoolPackSyllabus b in branches)
              Card(
                child: ListTile(
                  leading: const MsIcon('menu_book', size: 20),
                  title: Text(b.subject,
                      style: RenanceText.bodyBase
                          .copyWith(fontWeight: FontWeight.w600)),
                  trailing: const MsIcon('chevron_right', fill: true, size: 18),
                  onTap: () => _showBranchTopics(context, b),
                ),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showBranchTopics(BuildContext context, SchoolPackSyllabus branch) {
    final SchoolSyllabusTerm term = branch.terms.firstWhere(
      (SchoolSyllabusTerm t) => t.term == _term,
      orElse: () => branch.terms.first,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (BuildContext _, ScrollController scroll) => Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              Text(
                '${branch.subject} · ${schoolTermName(_term)}',
                style: RenanceText.sectionTitle,
              ),
              const SizedBox(height: 4),
              Text(
                'Scheme of work + topics (offline pack)',
                style: RenanceText.caption
                    .copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final SchemeWeek w in term.schemeOfWork)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 44,
                        child: Text('W${w.week}',
                            style: RenanceText.labelMono.copyWith(
                                color: context.schoolAccent, fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          w.topic,
                          style: RenanceText.bodySecondary.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              if (term.topics.isNotEmpty) ...<Widget>[
                const Divider(height: 24),
                for (final SchoolTopicInfo t in term.topics)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const MsIcon('description', size: 20),
                    title: Text(
                      t.title,
                      style: RenanceText.bodyBase.copyWith(
                          fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    trailing: const MsIcon('chevron_right', fill: true, size: 18),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => SchoolNoteReaderScreen(
                          topic: t,
                          schoolName: '',
                          className: widget.cls.name,
                          subject: branch.subject,
                          termName: schoolTermName(_term),
                        ),
                      ));
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showStudent(BuildContext context, SchoolStudentModel s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: context.schoolAccentContainer,
                  foregroundColor: context.schoolAccent,
                  child: Text(schoolInitials(s.fullName)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.fullName,
                    style: RenanceText.sectionTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow('Admission no', s.admissionNo),
            _DetailRow('Class', widget.cls.name),
            _DetailRow('Sex', s.sex.isEmpty ? '-' : s.sex),
            if (s.dob.isNotEmpty) _DetailRow('Date of birth', s.dob),
            if (s.guardianName.isNotEmpty)
              _DetailRow('Guardian', s.guardianName),
            if (s.guardianPhone.isNotEmpty)
              _DetailRow('Guardian phone', s.guardianPhone),
            if (s.address.isNotEmpty) _DetailRow('Home address', s.address),
            const SizedBox(height: 12),
            if (widget.isManager)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const MsIcon('edit', fill: true, size: 18),
                  label: const Text('Edit details'),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => SchoolStudentDetailsScreen(
                          schoolId: widget.schoolId),
                    ));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style:
                  RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: RenanceText.bodyBase.copyWith(fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ results

/// The Results page (role-gated): class broadsheet per subject with
/// CA1/CA2/Exam/Total columns, score entry and the report-sheet preview
/// with GGSA grade chips + share.
class SchoolResultsScreen extends StatefulWidget {
  const SchoolResultsScreen({
    super.key,
    required this.schoolId,
    required this.isManager,
    this.allowedClassIds,
  });

  final String schoolId;
  final bool isManager;
  final Set<String>? allowedClassIds;

  @override
  State<SchoolResultsScreen> createState() => _SchoolResultsScreenState();
}

class _SchoolResultsScreenState extends State<SchoolResultsScreen> {
  String? _classId;
  int _term = 1;
  String _session = schoolCurrentSession();
  String? _subjectId; // null = overview
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  List<SchoolClassInfo> _visibleClasses(SchoolController school) {
    final Set<String>? allowed = widget.allowedClassIds;
    return school.classes
        .where((SchoolClassInfo c) =>
            allowed == null || allowed.contains(c.id))
        .toList(growable: false)
      ..sort((SchoolClassInfo a, SchoolClassInfo b) => a.seq.compareTo(b.seq));
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    if (school.classes.isEmpty) {
      await school.loadRoster(widget.schoolId);
    }
    if (school.subjects.isEmpty) {
      await school.loadSubjects(widget.schoolId);
    }
    if (!mounted) return;
    final List<SchoolClassInfo> classes = _visibleClasses(school);
    if (classes.isNotEmpty && _classId == null) {
      _classId = classes.first.id;
      await _load();
    }
    if (mounted) setState(() => _booted = true);
  }

  Future<void> _load() async {
    if (_classId == null) return;
    await context.read<SchoolController>().loadResults(
          widget.schoolId,
          classId: _classId!,
          term: _term,
          session: _session,
        );
  }

  /// The subjects selectable for the broadsheet: the class's subject
  /// list (so fresh scores can be entered) plus any subject that
  /// already carries scores in the grid.
  List<SchoolSubjectInfo> _gridSubjects(
      SchoolController school, SchoolClassInfo? cls) {
    if (cls == null) return <SchoolSubjectInfo>[];
    final Set<String> seen = <String>{
      for (final SchoolResultModel r in school.results)
        for (final SchoolResultItemModel i in r.items) i.subjectId,
    };
    final List<SchoolSubjectInfo> levelSubjects = school.subjects
        .where((SchoolSubjectInfo s) =>
            s.level == 'both' || s.level == cls.level)
        .toList(growable: false);
    final List<SchoolSubjectInfo> extra = school.subjects
        .where((SchoolSubjectInfo s) =>
            seen.contains(s.id) &&
            !levelSubjects.any((SchoolSubjectInfo x) => x.id == s.id))
        .toList(growable: false);
    return <SchoolSubjectInfo>[
      for (final SchoolSubjectInfo s in levelSubjects)
        if (seen.isEmpty || seen.contains(s.id) || levelSubjects.length <= 12)
          s,
      ...extra,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final List<SchoolClassInfo> classes = _visibleClasses(school);
    final SchoolClassInfo? cls = classes
        .where((SchoolClassInfo c) => c.id == _classId)
        .firstOrNull;
    final List<SchoolSubjectInfo> subjects = _gridSubjects(school, cls);
    final SchoolSubjectInfo? subject = subjects
        .where((SchoolSubjectInfo s) => s.id == _subjectId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(context, pageTitle: 'Results'),
      // First boot: the roster + subjects land, then the desk fills.
      body: !_booted && school.classes.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Pickers: class, term, session, subject.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _classId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final SchoolClassInfo c in classes)
                      DropdownMenuItem<String>(
                          value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (String? v) async {
                    setState(() => _classId = v);
                    await _load();
                  },
                ),
              ),
              SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 1, label: Text('T1')),
                  ButtonSegment<int>(value: 2, label: Text('T2')),
                  ButtonSegment<int>(value: 3, label: Text('T3')),
                ],
                selected: <int>{_term},
                onSelectionChanged: (Set<int> s) async {
                  setState(() => _term = s.first);
                  await _load();
                },
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _session,
                  decoration: const InputDecoration(
                    labelText: 'Session',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String s in schoolSessionChoices())
                      DropdownMenuItem<String>(value: s, child: Text(s)),
                  ],
                  onChanged: (String? v) async {
                    setState(() => _session = v ?? _session);
                    await _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (subjects.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _subjectId,
              decoration: const InputDecoration(
                labelText: 'Subject broadsheet',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Overview (all subjects)')),
                for (final SchoolSubjectInfo s in subjects)
                  DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (String? v) => setState(() => _subjectId = v),
            ),
          if (school.lastError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              school.lastError!,
              style: RenanceText.bodySecondary.copyWith(color: context.error),
            ),
          ],
          const SizedBox(height: 12),

          if (school.resultsLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (cls == null)
            Text(
              widget.isManager
                  ? 'No classes yet.'
                  : 'No classes assigned to you yet.',
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            )
          else if (school.results.isEmpty)
            _InfoCard(
              icon: 'grid_on',
              child: Text(
                'No results yet for ${cls.name} · ${schoolTermName(_term)} · $_session. '
                'Pick a subject above and tap a pupil to enter scores.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary, fontSize: 13.5),
              ),
            )
          else if (subject != null)
            _Broadsheet(
              schoolId: widget.schoolId,
              classId: cls.id,
              className: cls.name,
              subject: subject,
              term: _term,
              session: _session,
              canEditAny: widget.isManager,
            )
          else
            _OverviewTable(results: school.results),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The per-subject broadsheet: one row per pupil with CA1 (20), CA2 (20),
/// Exam (60), Total (100) and the GGSA grade chip. Tap a row to enter
/// scores; the trailing sheet icon opens the report card preview.
class _Broadsheet extends StatelessWidget {
  const _Broadsheet({
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.subject,
    required this.term,
    required this.session,
    required this.canEditAny,
  });

  final String schoolId;
  final String classId;
  final String className;
  final SchoolSubjectInfo subject;
  final int term;
  final String session;
  final bool canEditAny;

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();

    // Teacher gate: a teacher may only fill the class+subject rows they
    // are assigned (the server re-checks every write anyway).
    final bool canEdit = canEditAny ||
        school.assignments.any((SchoolAssignmentModel a) =>
            a.classId == classId && a.subjectId == subject.id);

    final List<({SchoolResultModel row, SchoolResultItemModel? item})> rows =
        <({SchoolResultModel row, SchoolResultItemModel? item})>[
      for (final SchoolResultModel r in school.results)
        (
          row: r,
          item: r.items
              .where((SchoolResultItemModel i) => i.subjectId == subject.id)
              .firstOrNull,
        ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                defaultVerticalAlignment:
                    TableCellVerticalAlignment.middle,
                border: TableBorder.all(
                  color: context.outlineVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                columnWidths: const <int, TableColumnWidth>{
                  0: FixedColumnWidth(40),
                  1: FlexColumnWidth(2.6),
                  2: FixedColumnWidth(52),
                  3: FixedColumnWidth(52),
                  4: FixedColumnWidth(52),
                  5: FixedColumnWidth(56),
                  6: FixedColumnWidth(52),
                  7: FixedColumnWidth(48),
                },
                children: <TableRow>[
                  // Header - black ground, the ink table look.
                  TableRow(
                    decoration: BoxDecoration(color: context.isDarkTier
                        ? Colors.white.withValues(alpha: 0.08)
                        : context.ink),
                    children: <Widget>[
                      _headCell(context, '#', bold: true),
                      _headCell(context, 'Pupil', bold: true),
                      _headCell(context, 'CA1\n(20)', center: true),
                      _headCell(context, 'CA2\n(20)', center: true),
                      _headCell(context, 'Exam\n(60)', center: true),
                      _headCell(context, 'Total\n(100)', center: true),
                      _headCell(context, 'Grade', center: true),
                      const SizedBox(height: 40),
                    ],
                  ),
                  for (int i = 0; i < rows.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? context.schoolZebra
                            : Colors.transparent,
                      ),
                      children: <Widget>[
                        _bodyCell(context, '${i + 1}',
                            mono: true, secondary: true, center: true),
                        InkWell(
                          onTap: () => _openSheet(context, rows[i].row),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Text(
                              rows[i].row.studentName,
                              style: RenanceText.bodyBase.copyWith(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: canEdit
                              ? () => _editScores(
                                  context, rows[i].row, rows[i].item)
                              : null,
                          child: _bodyCell(
                              context, _score(rows[i].item?.ca1), center: true),
                        ),
                        InkWell(
                          onTap: canEdit
                              ? () => _editScores(
                                  context, rows[i].row, rows[i].item)
                              : null,
                          child: _bodyCell(
                              context, _score(rows[i].item?.ca2), center: true),
                        ),
                        InkWell(
                          onTap: canEdit
                              ? () => _editScores(
                                  context, rows[i].row, rows[i].item)
                              : null,
                          child: _bodyCell(
                              context, _score(rows[i].item?.exam), center: true),
                        ),
                        _bodyCell(
                            context, _score(rows[i].item?.total),
                            center: true,
                            bold: true,
                            color: context.schoolAccent),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Center(
                            child: rows[i].item == null
                                ? const Text('-',
                                    style: TextStyle(fontSize: 12))
                                : _GradeChip(grade: rows[i].item!.grade),
                          ),
                        ),
                        IconButton(
                          icon: const MsIcon('receipt_long',
                              size: 18),
                          tooltip: 'Report sheet',
                          onPressed: () => _openSheet(context, rows[i].row),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _score(num? v) =>
      v == null || v == 0 ? '-' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  static Widget _headCell(BuildContext context, String text,
      {bool bold = false, bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        // The header ground is ink black in light tier (the ink table
        // look) - white text; the dark tier keeps a light translucent
        // ground so the ink text stays.
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          height: 1.3,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0.2,
          color: context.isDarkTier ? context.ink : Colors.white,
        ),
      ),
    );
  }

  static Widget _bodyCell(BuildContext context, String text,
      {bool center = false, bool bold = false, bool mono = false,
       bool secondary = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontFamily: mono ? 'JetBrainsMono' : 'Inter',
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ??
              (secondary ? context.textSecondary : context.ink),
        ),
      ),
    );
  }

  void _editScores(BuildContext context, SchoolResultModel row,
      SchoolResultItemModel? item) {
    if (row.status == 'final') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'This result is finalized - unfinalize it on the web portal first.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ScoreEntryScreen(
        schoolId: schoolId,
        classId: classId,
        className: className,
        subject: subject,
        term: term,
        session: session,
        student: row,
        initial: item,
      ),
    ));
  }

  void _openSheet(BuildContext context, SchoolResultModel row) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ResultSheetScreen(
        schoolId: schoolId,
        term: term,
        session: session,
        result: row,
      ),
    ));
  }
}

/// The overview table: one row per pupil with subjects offered, total
/// and average - the class digest.
class _OverviewTable extends StatelessWidget {
  const _OverviewTable({required this.results});

  final List<SchoolResultModel> results;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(
                    color: context.outlineVariant,
                    borderRadius: BorderRadius.circular(12)),
                columnWidths: const <int, TableColumnWidth>{
                  0: FixedColumnWidth(40),
                  1: FlexColumnWidth(2.6),
                  2: FixedColumnWidth(70),
                  3: FixedColumnWidth(70),
                  4: FixedColumnWidth(90),
                  5: FixedColumnWidth(60),
                },
                children: <TableRow>[
                  TableRow(
                    decoration: BoxDecoration(
                        color: context.isDarkTier
                            ? Colors.white.withValues(alpha: 0.08)
                            : context.ink),
                    children: <Widget>[
                      _OverviewTable._head(context, '#'),
                      _OverviewTable._head(context, 'Pupil', bold: true),
                      _OverviewTable._head(context, 'Subjects', center: true),
                      _OverviewTable._head(context, 'Total', center: true),
                      _OverviewTable._head(context, 'Average', center: true),
                      _OverviewTable._head(context, 'Status', center: true),
                    ],
                  ),
                  for (int i = 0; i < results.length; i++)
                    TableRow(
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? context.schoolZebra
                            : Colors.transparent,
                      ),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          child: Text('${i + 1}',
                              style: RenanceText.labelMono
                                  .copyWith(fontSize: 12)),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => _ResultSheetScreen(
                              schoolId: '',
                              term: results[i].term,
                              session: results[i].session,
                              result: results[i],
                            ),
                          )),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  results[i].studentName,
                                  style: RenanceText.bodyBase.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                                Text(
                                  results[i].admissionNo,
                                  style: RenanceText.caption.copyWith(
                                      color: context.textSecondary,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _cell(context, '${results[i].items.length}'),
                        _cell(context,
                            results[i].totalScore.toInt().toString()),
                        _cell(context,
                            results[i].average.toStringAsFixed(1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Center(
                            child: results[i].status == 'final'
                                ? const MsIcon('lock',
                                    size: 14, color: Color(0xFF059669))
                                : const MsIcon('edit_note',
                                    size: 16),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _head(BuildContext context, String text,
      {bool bold = false, bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: context.isDarkTier ? context.ink : Colors.white,
        ),
      ),
    );
  }

  static Widget _cell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: context.ink),
      ),
    );
  }
}

/// The GGSA grade chip (A emerald, B purple, C slate, D sky, E amber,
/// F red - the result-sheet legend, 1:1).
class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDarkTier;
    final (Color, Color) colors = switch (grade) {
      'A' => (dark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
              dark ? const Color(0x2E10B981) : const Color(0xFFD1FAE5)),
      'B' => (dark ? SchoolInk.purple300 : const Color(0xFF4C1D95),
              dark ? const Color(0x2E8B5CF6) : const Color(0xFFF3E8FF)),
      'C' => (dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              dark ? const Color(0x2E94A3B8) : const Color(0xFFF1F5F9)),
      'D' => (dark ? const Color(0xFF7DD3FC) : const Color(0xFF075985),
              dark ? const Color(0x2E0EA5E9) : const Color(0xFFE0F2FE)),
      'E' => (dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
              dark ? const Color(0x2EF59E0B) : const Color(0xFFFEF3C7)),
      _ => (dark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
              dark ? const Color(0x2EEF4444) : const Color(0xFFFEE2E2)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.$2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: colors.$1,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Score entry for one pupil + subject: CA1 / CA2 / Exam with the
/// 20-20-60 caps, saved through PUT /school/result-item.
class _ScoreEntryScreen extends StatefulWidget {
  const _ScoreEntryScreen({
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.subject,
    required this.term,
    required this.session,
    required this.student,
    required this.initial,
  });

  final String schoolId;
  final String classId;
  final String className;
  final SchoolSubjectInfo subject;
  final int term;
  final String session;
  final SchoolResultModel student;
  final SchoolResultItemModel? initial;

  @override
  State<_ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<_ScoreEntryScreen> {
  late final TextEditingController _ca1 = TextEditingController(
      text: widget.initial?.ca1 == null || widget.initial!.ca1 == 0
          ? ''
          : _fmt(widget.initial!.ca1));
  late final TextEditingController _ca2 = TextEditingController(
      text: widget.initial?.ca2 == null || widget.initial!.ca2 == 0
          ? ''
          : _fmt(widget.initial!.ca2));
  late final TextEditingController _exam = TextEditingController(
      text: widget.initial?.exam == null || widget.initial!.exam == 0
          ? ''
          : _fmt(widget.initial!.exam));
  bool _saving = false;

  static String _fmt(num v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _ca1.dispose();
    _ca2.dispose();
    _exam.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double ca1 = double.tryParse(_ca1.text.trim()) ?? 0;
    final double ca2 = double.tryParse(_ca2.text.trim()) ?? 0;
    final double exam = double.tryParse(_exam.text.trim()) ?? 0;
    if (ca1 < 0 || ca1 > 20 || ca2 < 0 || ca2 > 20 || exam < 0 || exam > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('CA1 and CA2 are out of 20 each; the exam is out of 60.')),
      );
      return;
    }
    setState(() => _saving = true);
    final SchoolController school = context.read<SchoolController>();
    final SchoolResultItemModel? saved = await school.saveResultItem(
      widget.schoolId,
      studentId: widget.student.studentId,
      classId: widget.classId,
      subjectId: widget.subject.id,
      term: widget.term,
      session: widget.session,
      ca1: ca1,
      ca2: ca2,
      exam: exam,
    );
    if (!mounted) return;
    if (saved == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(school.lastError ?? 'Could not save the scores.')),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(
          context, pageTitle: '${widget.subject.name} scores'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            widget.student.studentName,
            style: RenanceText.sectionTitle,
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.className} · ${widget.student.admissionNo} · '
            '${schoolTermName(widget.term)} · ${widget.session}',
            style:
                RenanceText.caption.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 20),
          _scoreField('CA1 (out of 20)', _ca1),
          const SizedBox(height: 12),
          _scoreField('CA2 (out of 20)', _ca2),
          const SizedBox(height: 12),
          _scoreField('Exam (out of 60)', _exam),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const MsIcon('save', fill: true, size: 18),
            label: const Text('Save scores'),
          ),
        ],
      ),
    );
  }

  Widget _scoreField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

/// The report-sheet preview - the GGSA "Stitch" A4 card, mobile: header
/// band, bio grid, subject rows with grade chips, reports + grading key,
/// and a share-as-text hook (share_plus).
class _ResultSheetScreen extends StatelessWidget {
  const _ResultSheetScreen({
    required this.schoolId,
    required this.term,
    required this.session,
    required this.result,
  });

  final String schoolId;
  final int term;
  final String session;
  final SchoolResultModel result;

  String get _sheetTitle =>
      result.schoolName.isNotEmpty ? result.schoolName : 'Renance School';

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.read<SchoolController>();
    final String schoolName =
        school.activeContext?.school.name ?? _sheetTitle;
    final bool final_ = result.status == 'final';
    // GGSA header lines (founder directive 2026-10-04): address / phone /
    // email printed under the school name on the report card.
    final String schoolContact = <String>[
      if (result.schoolAddress.isNotEmpty) result.schoolAddress,
      if (result.schoolPhone.isNotEmpty) 'Tel: ${result.schoolPhone}',
      if (result.schoolEmail.isNotEmpty) result.schoolEmail,
    ].join('  ·  ');
    final String motto = result.schoolMotto;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(
        context,
        pageTitle: 'Report sheet',
        actions: <Widget>[
          IconButton(
            icon: const MsIcon('ios_share', fill: true, size: 22),
            tooltip: 'Share',
            onPressed: () => _share(schoolName),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // The paper card.
          Container(
            decoration: BoxDecoration(
              color: context.schoolPaper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.outlineVariant),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                    color: Color(0x14141C2D),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: <Widget>[
                // Header - deep purple, gold motto stripe (GGSA).
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.schoolAccentDeep,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13)),
                  ),
                  child: Column(
                    children: <Widget>[
                      // Cinzel-style serif school title.
                      Text(
                        schoolName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      // GGSA header lines (founder directive 2026-10-04):
                      // address / phone / email under the school name.
                      if (schoolContact.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            schoolContact,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                        ),
                      if (motto.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            motto,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.amber.shade200,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.schoolGold.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'REPORT CARD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: <Widget>[
                      // Bio grid.
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.isDarkTier
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: <Widget>[
                            _bioRow('Name', result.studentName, strong: true),
                            _bioRow('Class', result.className),
                            _bioRow(
                'Term / Session',
                '${schoolTermName(result.term)} · ${result.session}'),
                            _bioRow('Admission no', result.admissionNo),
                            if (result.sex.isNotEmpty)
                              _bioRow(
                                  'Sex', result.sex == 'M' ? 'Male' : 'Female'),
                            if (result.noInClass > 0)
                              _bioRow('No. in class', '${result.noInClass}'),
                            if (result.attendancePresent != null &&
                                result.attendanceOpened != null)
                              _bioRow(
                                  'Attendance',
                                  '${result.attendancePresent}'
                                  ' / ${result.attendanceOpened} Times'),
                            _bioRow('Subjects offered', '${result.items.length}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Totals band.
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _TotalTile(
                              label: 'TOTAL SCORE',
                              value:
                                  '${result.totalScore.toInt()}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TotalTile(
                              label: 'AVERAGE',
                              value: result.average.toStringAsFixed(1),
                              accent: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TotalTile(
                              label: 'STATUS',
                              value: final_ ? 'FINAL' : 'DRAFT',
                              accent: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Subject rows.
                      if (result.items.isEmpty)
                        Text(
                          'No scores recorded yet for this term.',
                          style: RenanceText.bodySecondary.copyWith(
                              color: context.textSecondary, fontSize: 13),
                        )
                      else
                        for (final SchoolResultItemModel i in result.items)
                          _SubjectRow(item: i),
                      const SizedBox(height: 6),
                      // Grading key.
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final MapEntry<String, String> e
                              in kSchoolGradeRemarks.entries)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _GradeChip(grade: e.key),
                                const SizedBox(width: 4),
                                Text(
                                  e.value,
                                  style: RenanceText.caption.copyWith(
                                      fontSize: 10.5,
                                      color: context.textSecondary),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                        ],
                      ),
                      if (result.traits.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        _TraitCard(
                          title: 'DEVELOPMENT (Skills)',
                          rows: result.traitRows(kSkillTraitNames),
                        ),
                        const SizedBox(height: 10),
                        _TraitCard(
                          title: 'BEHAVIOUR (Character)',
                          rows: result.traitRows(kBehaviourTraitNames),
                        ),
                      ],
                      if (result.teacherReport.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        _ReportBox(
                            title: "Teacher's report",
                            body: result.teacherReport),
                      ],
                      if (result.principalReport.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        _ReportBox(
                            title: "Principal's report",
                            body: result.principalReport),
                      ],
                      if (result.nextTermBegins.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.isDarkTier
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: context.schoolAccentDeep
                                    .withValues(alpha: 0.25),
                                width: 2),
                          ),
                          child: Text(
                            'Next term begins: ${result.nextTermBegins}',
                            textAlign: TextAlign.center,
                            style: RenanceText.bodyMedium.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.ink),
                          ),
                        ),
                      ],
                      if (final_ && result.pin.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.schoolAccentContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                'Result-check PIN: ',
                                style: RenanceText.bodyBase
                                    .copyWith(fontSize: 13),
                              ),
                              Text(
                                result.pin,
                                style: RenanceText.labelMono.copyWith(
                                    fontSize: 16,
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Generated by Renance · ${DateTime.now().year}',
                        style: RenanceText.caption.copyWith(
                            fontSize: 10.5,
                            color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const MsIcon('ios_share', fill: true, size: 18),
            label: const Text('Share result summary'),
            onPressed: () => _share(schoolName),
          ),
          // TODO(founder): print hook - the printing package already
          // ships in pubspec; wire ShareIt as a rendered PDF later.
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _bioRow(String label, String value, {bool strong = false}) {
    return Builder(
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: RenanceText.caption.copyWith(
                    fontSize: 11.5, color: context.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: RenanceText.bodyBase.copyWith(
                  fontSize: 12.5,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(String schoolName) async {
    final StringBuffer b = StringBuffer()
      ..writeln(schoolName)
      ..writeln('REPORT CARD - ${schoolTermName(result.term)} ${result.session}')
      ..writeln('Name: ${result.studentName}')
      ..writeln('Class: ${result.className} (${result.admissionNo})')
      ..writeln('');
    for (final SchoolResultItemModel i in result.items) {
      b.writeln('${i.subjectName}: CA1 ${_n(i.ca1)} · CA2 ${_n(i.ca2)} · '
          'Exam ${_n(i.exam)} · Total ${_n(i.total)} · ${i.grade} '
          '(${kSchoolGradeRemarks[i.grade] ?? ''})');
    }
    b..writeln('')..writeln(
        result.items.isEmpty
            ? 'No scores recorded yet.'
            : 'Total: ${result.totalScore.toInt()} · Average: ${result.average.toStringAsFixed(1)}');
    if (result.status == 'final' && result.pin.isNotEmpty) {
      b.writeln('Result-check PIN: ${result.pin}');
    }
    b..writeln('')..writeln('Generated by Renance');
    await Share.share(b.toString(), subject: 'Result - ${result.studentName}');
  }

  static String _n(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: accent
            ? context.schoolAccentContainer
            : (context.isDarkTier
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: RenanceText.statNumber.copyWith(
                fontSize: 18,
                color: accent ? context.schoolAccentDeep : context.ink),
          ),
          Text(
            label,
            style: RenanceText.caption.copyWith(
                fontSize: 9.5,
                letterSpacing: 0.8,
                color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.item});

  final SchoolResultItemModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: context.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.subjectName,
                  style: RenanceText.bodyBase.copyWith(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                if (item.remark.isNotEmpty)
                  Text(
                    item.remark,
                    style: RenanceText.caption.copyWith(
                        fontSize: 10.5, color: context.textSecondary),
                  ),
              ],
            ),
          ),
          _scoreCell(context, item.ca1, 20),
          _scoreCell(context, item.ca2, 20),
          _scoreCell(context, item.exam, 60),
          SizedBox(
            width: 42,
            child: Text(
              item.total % 1 == 0
                  ? item.total.toInt().toString()
                  : item.total.toString(),
              textAlign: TextAlign.center,
              style: RenanceText.bodyBase.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: context.schoolAccentDeep),
            ),
          ),
          const SizedBox(width: 6),
          _GradeChip(grade: item.grade),
        ],
      ),
    );
  }

  Widget _scoreCell(BuildContext context, num v, int max) {
    return SizedBox(
      width: 34,
      child: Text(
        v % 1 == 0 ? v.toInt().toString() : v.toString(),
        textAlign: TextAlign.center,
        style: RenanceText.bodyBase.copyWith(
            fontSize: 12,
            color: v == 0 ? context.textSecondary : context.ink),
      ),
    );
  }
}

class _ReportBox extends StatelessWidget {
  const _ReportBox({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDarkTier
            ? Colors.white.withValues(alpha: 0.04)
            : SchoolInk.purple50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: context.schoolAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: RenanceText.overline.copyWith(
                color: context.schoolAccentDeep, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: RenanceText.bodySecondary.copyWith(
                fontSize: 12.5, fontStyle: FontStyle.italic, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// One GGSA trait card (DEVELOPMENT / BEHAVIOUR): deep-purple header bar
/// with the gold GRADE tag, then the A-E rated rows (founder directive
/// 2026-10-04). Unrated rows show a dash, exactly like the paper card.
class _TraitCard extends StatelessWidget {
  const _TraitCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: context.schoolAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.schoolAccentDeep,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.schoolGold.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'GRADE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: context.isDarkTier
                ? Colors.white.withValues(alpha: 0.03)
                : SchoolInk.purple50,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              children: <Widget>[
                for (final (String, String) row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            row.$1,
                            style: RenanceText.bodySecondary.copyWith(
                                fontSize: 12.5),
                          ),
                        ),
                        Text(
                          row.$2.isEmpty ? '-' : row.$2,
                          style: RenanceText.bodyMedium.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: context.schoolAccentDeep,
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------- teachers

/// The Teachers page (management only): staff list, create teacher
/// (name/email/password/staff code) and the class+subject assignment
/// editor - wired to POST /school/teachers + /school/assignments.
class SchoolTeachersScreen extends StatefulWidget {
  const SchoolTeachersScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<SchoolTeachersScreen> createState() => _SchoolTeachersScreenState();
}

class _SchoolTeachersScreenState extends State<SchoolTeachersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    await school.loadMembers(widget.schoolId);
    if (school.classes.isEmpty) {
      await school.loadRoster(widget.schoolId);
    }
    if (school.subjects.isEmpty) {
      await school.loadSubjects(widget.schoolId);
    }
  }

  Future<void> _addTeacher() async {
    final SchoolMemberSummaryModel? created =
        await showModalBottomSheet<SchoolMemberSummaryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTeacherSheet(schoolId: widget.schoolId),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${created.member.fullName} created. Username: ${created.username} - share the email + password you set.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final List<SchoolMemberSummaryModel> members = school.members.toList()
      ..sort((SchoolMemberSummaryModel a, SchoolMemberSummaryModel b) {
        final int byRole = a.member.role == b.member.role
            ? 0
            : (a.member.isManagement ? -1 : 1);
        if (byRole != 0) return byRole;
        return a.member.fullName.compareTo(b.member.fullName);
      });

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar:
          schoolWorkspaceAppBar(context, pageTitle: 'Teachers & Classes'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.schoolAccentDeep,
        foregroundColor: Colors.white,
        icon: const MsIcon('person_add', fill: true),
        label: const Text('Add teacher'),
        onPressed: _addTeacher,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (school.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                school.lastError!,
                style:
                    RenanceText.bodySecondary.copyWith(color: context.error),
              ),
            ),
          if (school.membersLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (members.isEmpty)
            _InfoCard(
              icon: 'group_add',
              child: Text(
                'No staff yet. Create teacher accounts - each teacher signs in '
                'under For Schools with the email + password you set, and only '
                'sees the classes you assign.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary, fontSize: 13.5),
              ),
            )
          else
            for (final SchoolMemberSummaryModel m in members)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: m.member.isManagement
                        ? context.schoolAccentDeep
                        : context.schoolAccentContainer,
                    foregroundColor: m.member.isManagement
                        ? Colors.white
                        : context.schoolAccent,
                    child: Text(
                      schoolInitials(m.member.fullName),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(
                    m.member.fullName,
                    style: RenanceText.bodyBase.copyWith(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${m.member.isManagement ? 'Management' : 'Teacher'}'
                    '${m.member.staffCode.isEmpty ? '' : ' · ${m.member.staffCode}'}'
                    '\n${m.email.isEmpty ? m.username : m.email}',
                    style: RenanceText.caption.copyWith(
                        color: context.textSecondary, fontSize: 11.5),
                  ),
                  isThreeLine: true,
                  trailing: m.member.isManagement
                      ? null
                      : TextButton(
                          onPressed: () => _openAssignments(context, m),
                          child: const Text('Classes'),
                        ),
                  onTap: m.member.isManagement
                      ? null
                      : () => _openAssignments(context, m),
                ),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _openAssignments(
      BuildContext context, SchoolMemberSummaryModel member) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentSheet(
        schoolId: widget.schoolId,
        member: member,
      ),
    );
  }
}

/// The create-teacher form: full name, email, password (8-72), staff
/// code. POSTs /school/teachers; the server creates the account, the
/// membership and marks the email verified.
class _AddTeacherSheet extends StatefulWidget {
  const _AddTeacherSheet({required this.schoolId});

  final String schoolId;

  @override
  State<_AddTeacherSheet> createState() => _AddTeacherSheetState();
}

class _AddTeacherSheetState extends State<_AddTeacherSheet> {
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _staffCode = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _staffCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _fullName.text.trim();
    final String email = _email.text.trim().toLowerCase();
    if (name.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Full name and a valid email address are required.')),
      );
      return;
    }
    if (_password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('The password must be at least 8 characters.')),
      );
      return;
    }
    setState(() => _saving = true);
    final SchoolController school = context.read<SchoolController>();
    final SchoolMemberSummaryModel? created = await school.createTeacher(
      widget.schoolId,
      fullName: name,
      email: email,
      password: _password.text,
      staffCode: _staffCode.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(school.lastError ?? 'Could not create the teacher.')),
      );
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Create a teacher account',
                style: RenanceText.bodyBase.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'The teacher signs in under For Schools with this email + password.',
              style: RenanceText.caption
                  .copyWith(color: context.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (at least 8 characters)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _staffCode,
              decoration: const InputDecoration(
                labelText: 'Staff code (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const MsIcon('person_add', fill: true, size: 18),
              label: const Text('Create teacher'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// The assignment editor: pick a class, toggle the subject chips - each
/// toggle grants/revokes that class+subject instantly.
class _AssignmentSheet extends StatefulWidget {
  const _AssignmentSheet({required this.schoolId, required this.member});

  final String schoolId;
  final SchoolMemberSummaryModel member;

  @override
  State<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends State<_AssignmentSheet> {
  String? _classId;
  bool _loading = true;
  Set<String> _assigned = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final SchoolController school = context.read<SchoolController>();
    if (school.classes.isEmpty) {
      await school.loadRoster(widget.schoolId);
    }
    if (school.subjects.isEmpty) {
      await school.loadSubjects(widget.schoolId);
    }
    // Management reads any member's assignments.
    final List<SchoolAssignmentModel> rows = await school.loadAssignments(
        widget.schoolId, widget.member.member.id);
    if (!mounted) return;
    setState(() {
      _assigned = <String>{
        for (final SchoolAssignmentModel a in rows) a.subjectId,
      };
      _classId = school.classes.firstOrNull?.id;
      _loading = false;
    });
  }

  Future<void> _toggle(String subjectId, bool on) async {
    final String classId = _classId ?? '';
    if (classId.isEmpty) return;
    final SchoolController school = context.read<SchoolController>();
    final bool ok = await school.setAssignment(
      widget.schoolId,
      memberId: widget.member.member.id,
      classId: classId,
      subjectId: subjectId,
      remove: !on,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(school.lastError ?? 'Could not update the class.')),
      );
      return;
    }
    setState(() {
      if (on) {
        _assigned.add(subjectId);
      } else {
        _assigned.remove(subjectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final SchoolClassInfo? cls = school.classes
        .where((SchoolClassInfo c) => c.id == _classId)
        .firstOrNull;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('${widget.member.member.fullName} - classes & subjects',
              style: RenanceText.bodyBase.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Toggling a subject hands the teacher that class + subject: '
            'results entry, the register and the syllabus.',
            style:
                RenanceText.caption.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: _classId,
              decoration: const InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: <DropdownMenuItem<String>>[
                for (final SchoolClassInfo c in school.classes)
                  DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (String? v) async {
                final SchoolController s = context.read<SchoolController>();
                setState(() => _classId = v);
                if (v != null) {
                  final List<SchoolAssignmentModel> rows =
                      await s.loadAssignments(
                          widget.schoolId, widget.member.member.id);
                  if (!mounted) return;
                  setState(() {
                    _assigned = <String>{
                      for (final SchoolAssignmentModel a in rows
                          .where((SchoolAssignmentModel a) => a.classId == v))
                        a.subjectId,
                    };
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            if (cls != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final SchoolSubjectInfo s in school.subjects
                      .where((SchoolSubjectInfo s) =>
                          s.level == 'both' || s.level == cls.level))
                    FilterChip(
                      selected: _assigned.contains(s.id),
                      label: Text(s.name),
                      labelStyle: RenanceText.caption,
                      onSelected: (bool on) => _toggle(s.id, on),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- id cards

/// The ID Cards page: student card previews (GGSA purple face, initials
/// avatar, serial) with share; management also batch-issues the
/// serial-numbered ledger (GET/POST /school/id-cards). Teachers read a
/// roster-built preview - the server keeps the ledger management-only.
class SchoolIdCardsScreen extends StatefulWidget {
  const SchoolIdCardsScreen({
    super.key,
    required this.schoolId,
    required this.isManager,
    this.allowedClassIds,
  });

  final String schoolId;
  final bool isManager;
  final Set<String>? allowedClassIds;

  @override
  State<SchoolIdCardsScreen> createState() => _SchoolIdCardsScreenState();
}

class _SchoolIdCardsScreenState extends State<SchoolIdCardsScreen> {
  String? _classId;
  String _session = schoolCurrentSession();
  bool _booted = false;
  bool _issuing = false;
  final Map<String, SchoolStudentModel> _rosterById =
      <String, SchoolStudentModel>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await _load();
    if (mounted) setState(() => _booted = true);
  }

  Future<void> _load() async {
    final SchoolController school = context.read<SchoolController>();
    if (school.classes.isEmpty) {
      await school.loadRoster(widget.schoolId);
    }
    if (_classId == null) {
      final Set<String>? allowed = widget.allowedClassIds;
      final List<SchoolClassInfo> classes = school.classes
          .where((SchoolClassInfo c) =>
              allowed == null || allowed.contains(c.id))
          .toList(growable: false);
      if (classes.isEmpty) return;
      _classId = classes.first.id;
    }
    if (widget.isManager) {
      await school.loadIdCards(widget.schoolId,
          classId: _classId!, session: _session);
    }
    // The roster supplies the card faces for teachers (and student
    // detail for issued cards).
    await school.loadRoster(widget.schoolId, classId: _classId!);
    _rosterById
      ..clear()
      ..addEntries(
          school.roster.map((SchoolStudentModel s) => MapEntry(s.id, s)));
    if (mounted) setState(() {});
  }

  Future<void> _issue() async {
    if (_classId == null || _issuing) return;
    setState(() => _issuing = true);
    final SchoolController school = context.read<SchoolController>();
    final int? issued = await school.issueIdCards(
      widget.schoolId,
      classId: _classId!,
      session: _session,
    );
    if (!mounted) return;
    setState(() => _issuing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: issued == null
            ? Text(school.lastError ?? 'Could not issue the cards.')
            : Text('$issued card(s) issued for $_session.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final Set<String>? allowed = widget.allowedClassIds;
    final List<SchoolClassInfo> classes = school.classes
        .where((SchoolClassInfo c) =>
            allowed == null || allowed.contains(c.id))
        .toList(growable: false)
      ..sort((SchoolClassInfo a, SchoolClassInfo b) => a.seq.compareTo(b.seq));
    final SchoolClassInfo? cls =
        classes.where((SchoolClassInfo c) => c.id == _classId).firstOrNull;

    // Management: the issued ledger joined to the roster. Teacher: the
    // roster itself becomes the preview list.
    final List<SchoolIdCardModel> cards = school.idCards
        .where((SchoolIdCardModel c) => c.classId == _classId)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(context, pageTitle: 'ID Cards'),
      floatingActionButton: widget.isManager && _classId != null
          ? FloatingActionButton.extended(
              backgroundColor: context.schoolAccentDeep,
              foregroundColor: Colors.white,
              icon: _issuing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const MsIcon('badge', fill: true),
              label: Text(_issuing ? 'Issuing…' : 'Issue cards'),
              onPressed: _issuing ? null : _issue,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _classId,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final SchoolClassInfo c in classes)
                      DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (String? v) async {
                    setState(() => _classId = v);
                    await _load();
                  },
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _session,
                  decoration: const InputDecoration(
                    labelText: 'Session',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String s in schoolSessionChoices())
                      DropdownMenuItem<String>(value: s, child: Text(s)),
                  ],
                  onChanged: (String? v) async {
                    setState(() => _session = v ?? _session);
                    await _load();
                  },
                ),
              ),
            ],
          ),
          if (school.lastError != null && widget.isManager) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              school.lastError!,
              style: RenanceText.bodySecondary.copyWith(color: context.error),
            ),
          ],
          if (!widget.isManager) ...<Widget>[
            const SizedBox(height: 8),
            _InfoCard(
              icon: 'lock',
              child: Text(
                'Card issuing is management-only. You can preview and share '
                'your pupils\' cards here.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 14),

          if (!_booted)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (cls == null)
            Text(
              widget.isManager
                  ? 'No classes yet.'
                  : 'No classes assigned to you yet.',
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            )
          else if (widget.isManager && cards.isEmpty)
            _InfoCard(
              icon: 'badge',
              child: Text(
                'No cards issued for ${cls.name} · $_session yet. Tap Issue '
                'cards to mint a serial for every active pupil.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary, fontSize: 13.5),
              ),
            )
          else if (!widget.isManager && _rosterById.isEmpty)
            Text(
              'No pupils enrolled in this class yet.',
              style: RenanceText.bodySecondary
                  .copyWith(color: context.textSecondary),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final int columns = c.maxWidth >= 1000
                    ? 3
                    : c.maxWidth >= 640
                        ? 2
                        : 1;
                final List<_CardFace> faces = widget.isManager
                    ? <_CardFace>[
                        for (final SchoolIdCardModel card in cards)
                          _CardFace(
                            studentName: card.studentName.isNotEmpty
                                ? card.studentName
                                : (_rosterById[card.studentId]?.fullName ??
                                    'Pupil'),
                            admissionNo: card.admissionNo.isNotEmpty
                                ? card.admissionNo
                                : (_rosterById[card.studentId]?.admissionNo ??
                                    ''),
                            className: card.className.isNotEmpty
                                ? card.className
                                : cls.name,
                            sex: card.sex,
                            session: card.session.isNotEmpty
                                ? card.session
                                : _session,
                            serial: card.serial,
                            revoked: card.status == 'revoked',
                          ),
                      ]
                    : <_CardFace>[
                        for (final SchoolStudentModel s
                            in _rosterById.values)
                          _CardFace(
                            studentName: s.fullName,
                            admissionNo: s.admissionNo,
                            className: cls.name,
                            sex: s.sex,
                            session: _session,
                            serial: '',
                            revoked: false,
                          ),
                      ];
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.585, // ID-1 card ratio (85.6 x 54mm)
                  children: <Widget>[
                    for (final _CardFace f in faces) _IdCardWidget(face: f),
                  ],
                );
              },
            ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

/// The printable card face data.
class _CardFace {
  const _CardFace({
    required this.studentName,
    required this.admissionNo,
    required this.className,
    required this.sex,
    required this.session,
    required this.serial,
    required this.revoked,
  });

  final String studentName;
  final String admissionNo;
  final String className;
  final String sex;
  final String session;
  final String serial;
  final bool revoked;
}

/// One ID card: GGSA purple band with the school name, initials photo
/// placeholder, gold serial chip, share button.
class _IdCardWidget extends StatelessWidget {
  const _IdCardWidget({required this.face});

  final _CardFace face;

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.read<SchoolController>();
    final String schoolName =
        school.activeContext?.school.name ?? 'Renance School';

    return Container(alignment: Alignment.center,
      
      decoration: BoxDecoration(
        color: context.schoolPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x14141C2D), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header band.
            Container(
              color: context.schoolAccentDeep,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: <Widget>[
                  const MsIcon('school', fill: true, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    'STUDENT ID',
                    style: TextStyle(
                      color: context.schoolGold,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Body.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: face.sex == 'F'
                              ? const Color(0xFFFCE7F3)
                              : const Color(0xFFDBEAFE),
                          foregroundColor: face.sex == 'F'
                              ? const Color(0xFF9D174D)
                              : const Color(0xFF1E40AF),
                          child: Text(
                            schoolInitials(face.studentName),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _share(context, schoolName),
                          child: MsIcon('ios_share', fill: true,
                              size: 16, color: context.schoolAccent),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            face.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RenanceText.bodyBase.copyWith(
                                fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No. ${face.admissionNo}',
                            style: RenanceText.labelMono.copyWith(
                                fontSize: 10.5,
                                color: context.textSecondary),
                          ),
                          Text(
                            '${face.className} · ${face.session}',
                            style: RenanceText.caption.copyWith(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (face.serial.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.schoolGold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                face.serial,
                                style: RenanceText.labelMono.copyWith(
                                    fontSize: 10,
                                    color: context.schoolGold,
                                    fontWeight: FontWeight.w700),
                              ),
                            )
                          else
                            Text(
                              'Not issued yet',
                              style: RenanceText.caption.copyWith(
                                  fontSize: 10,
                                  color: context.textSecondary,
                                  fontStyle: FontStyle.italic),
                            ),
                          if (face.revoked)
                            const Text(
                              'REVOKED',
                              style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer stripe.
            Container(
              height: 4,
              color: context.schoolGold.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, String schoolName) async {
    await Share.share(
      '$schoolName - STUDENT ID CARD\n'
      'Name: ${face.studentName}\n'
      'Admission no: ${face.admissionNo}\n'
      'Class: ${face.className}\n'
      'Session: ${face.session}\n'
      '${face.serial.isEmpty ? '' : 'Serial: ${face.serial}\n'}'
      'Generated by Renance',
      subject: 'ID Card - ${face.studentName}',
    );
  }
}

// ------------------------------------------------------------------ billing

/// The Billing page (management only - the teacher workspace hides
/// subscription pages by founder directive): the plan summary from
/// GET /school/plan + a hand-off to the web portal's checkout.
class SchoolBillingScreen extends StatefulWidget {
  const SchoolBillingScreen({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<SchoolBillingScreen> createState() => _SchoolBillingScreenState();
}

class _SchoolBillingScreenState extends State<SchoolBillingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SchoolController>().loadPlan(widget.schoolId));
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final SchoolPlanModel? plan = school.plan;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(context, pageTitle: 'Billing'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (plan == null)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...<Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.schoolAccentDeep,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'CURRENT PLAN',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.plan.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.plan == 'trial'
                        ? (plan.trialDaysLeft != null
                            ? 'Trial - ${plan.trialDaysLeft} day(s) left'
                            : 'Trial')
                        : (plan.daysLeft != null
                            ? '${plan.daysLeft} day(s) left'
                            : 'Active'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (plan.planSource.isNotEmpty)
              _DetailRow('Plan source', plan.planSource),
            if (plan.expiresAt.isNotEmpty)
              _DetailRow('Expires', plan.expiresAt.substring(0, 10)),
            if (plan.trialEndsAt.isNotEmpty)
              _DetailRow('Trial ends', plan.trialEndsAt.substring(0, 10)),
            const SizedBox(height: 14),
            _InfoCard(
              icon: 'info',
              child: Text(
                'Plans, invoices and the checkout live on the web portal. '
                'Teachers never see this page.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: const MsIcon('open_in_new', fill: true, size: 18),
              label: const Text('Manage subscription on the web'),
              onPressed: () => _openSubscription(context),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ profile

/// The profile tab: member identity, the Appearance section (mode +
/// seed palette - the exact control students get, wired to the same
/// ThemeController), offline sync status and sign out.
class _SchoolProfileTab extends StatelessWidget {
  const _SchoolProfileTab();

  @override
  Widget build(BuildContext context) {
    final SchoolController school = context.watch<SchoolController>();
    final ThemeController theme = context.watch<ThemeController>();
    final SchoolContextModel? ctx = school.activeContext;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: schoolWorkspaceAppBar(context, pageTitle: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Identity card.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: context.schoolAccentDeep,
                  foregroundColor: Colors.white,
                  child: Text(
                    schoolInitials(ctx?.member.fullName ?? 'Staff'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        ctx?.member.fullName ?? 'School staff',
                        style: RenanceText.sectionTitle,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.schoolAccentContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              ctx?.member.isManagement == true
                                  ? 'MANAGEMENT'
                                  : 'TEACHER',
                              style: TextStyle(
                                color: context.schoolAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (ctx?.member.staffCode.isNotEmpty == true)
                            Text(
                              ctx!.member.staffCode,
                              style: RenanceText.caption.copyWith(
                                  color: context.textSecondary,
                                  fontSize: 11),
                            ),
                        ],
                      ),
                      Text(
                        ctx?.school.name ?? '',
                        style: RenanceText.caption
                            .copyWith(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Appearance - the same control students get (founder
          // directive: managers + teachers change appearance too).
          Text('APPEARANCE',
              style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          SegmentedButton<RenanceThemeMode>(
            // Light / Dark only - web parity (Mixed is retired from the
            // appearance setup; the tier stays internal for exam chrome).
            // A manager still parked on a persisted mixed tier maps the
            // pill to Light so the selection set never holds a segment
            // that no longer exists; picking a side rewrites it.
            segments: const <ButtonSegment<RenanceThemeMode>>[
              ButtonSegment<RenanceThemeMode>(
                  value: RenanceThemeMode.light, label: Text('Light')),
              ButtonSegment<RenanceThemeMode>(
                  value: RenanceThemeMode.dark, label: Text('Dark')),
            ],
            selected: <RenanceThemeMode>{
              theme.mode == RenanceThemeMode.mixed
                  ? RenanceThemeMode.light
                  : theme.mode
            },
            onSelectionChanged: (Set<RenanceThemeMode> s) =>
                theme.setMode(s.first),
          ),
          const SizedBox(height: 12),
          Text('SEED COLOR',
              style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _DefaultSeedDot(
                selected: theme.seed == null,
                onTap: () => theme.setSeed(null),
              ),
              for (final ({String hex, String name}) p in kSeedPresets)
                _SeedDot(
                  hex: p.hex,
                  name: p.name,
                  selected:
                      theme.seed?.toLowerCase() == p.hex.toLowerCase(),
                  onTap: () => theme.setSeed(p.hex),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            theme.seed == null
                ? 'The classic ink & paper look.'
                : 'Re-tints every surface, like Chrome appearance.',
            style: RenanceText.caption
                .copyWith(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Offline sync.
          Text('OFFLINE SYNC',
              style: RenanceText.overline.copyWith(color: context.textSecondary)),
          const SizedBox(height: 8),
          _InfoCard(
            icon: 'cloud_sync',
            color: context.card,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${school.pendingAttendance} register sheet(s) queued on this phone.',
                    style: RenanceText.bodySecondary.copyWith(fontSize: 13.5),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final int synced = await context
                        .read<SchoolController>()
                        .flushOfflineAttendance();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(synced > 0
                            ? 'Synced $synced sheet(s) to the database.'
                            : 'Nothing to sync right now.'),
                      ),
                    );
                  },
                  child: const Text('Sync now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign out.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const MsIcon('logout', fill: true, size: 18),
              label: const Text('Sign out of the school workspace'),
              onPressed: () async {
                final SessionStore session = context.read<SessionStore>();
                await SchoolController.forgetSchoolSession(session.prefs);
                await session.clear();
                if (!context.mounted) return;
                await Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The default ink & paper swatch (no seed).
class _DefaultSeedDot extends StatelessWidget {
  const _DefaultSeedDot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Default',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.isDarkTier ? Colors.white : Colors.black,
            border: Border.all(
              color: selected ? context.schoolAccent : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? MsIcon('check', fill: true,
                  size: 18,
                  color: context.isDarkTier ? Colors.black : Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// One preset seed dot.
class _SeedDot extends StatelessWidget {
  const _SeedDot({
    required this.hex,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(int.parse(hex.replaceFirst('#', '0xff')));
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.schoolAccent : Colors.transparent,
              width: 3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: selected ? 9 : 3,
                spreadRadius: selected ? 2 : 0,
              ),
            ],
          ),
          child: selected
              ? const MsIcon('check', fill: true, size: 19, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
