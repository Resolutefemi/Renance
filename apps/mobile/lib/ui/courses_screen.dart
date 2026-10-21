/// The Courses hub - the Flutter twin of the web's app/courses page:
/// the "MY COURSES" list + selection catalog for secondary desks, the
/// tertiary institution/department gates + "MY SEMESTER" desk, the
/// manage mode with desk search, the "Find my courses with AI" panel
/// and the course-request sheet, plus the pushed course PATH screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../controllers.dart';
import '../learn_controller.dart';
import '../learn_models.dart';
import '../models.dart' show Profile;
import 'celebrations.dart';
import 'learn_bits.dart';
import 'learn_path_view.dart';
import 'lesson_overlay.dart';
import 'msymbols.dart';
import 'renance_logo.dart';
import 'tactile.dart';
import 'theme.dart';

// ------------------------------------------------------------------ hub

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, this.onNeedsResync});

  /// Fired when the course list changes enough that the home shell
  /// should re-pull the learner profile.
  final VoidCallback? onNeedsResync;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

enum _Face { list, select, itype, dept, desk, manage }

class _CoursesScreenState extends State<CoursesScreen> {
  _Face _face = _Face.list;
  bool _loading = true;
  String? _error;

  List<MyCourse> _myCourses = <MyCourse>[];
  LearnProfile? _wallet;
  // The focus signature the last load ran under - the hub sits inside
  // the shell's IndexedStack, so initState runs long before the student
  // profile lands. Without this guard a tertiary student tapping the
  // desk's Courses tile could open the stale pre-profile face (the
  // "wrong route" bug) instead of their semester gate/desk.
  String _loadedFocusSig = '';

  bool get _tertiary => context.read<StudentController>().isTertiaryFocus;

  String get _body =>
      context.read<StudentController>().me?.profile?.exams.firstOrNull ==
              'WAEC'
          ? 'WAEC'
          : context.read<StudentController>().me?.profile?.exams.firstOrNull ==
                  'NECO'
              ? 'NECO'
              : 'JAMB';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The student profile landed (or the focus switched) after the first
    // load - re-run the face routing so the desk always matches the
    // student's CURRENT focus, exactly like the web's /courses.
    final String sig = _focusSignature();
    if (sig != _loadedFocusSig) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && sig == _focusSignature()) _load();
      });
    }
  }

  String _focusSignature() {
    final StudentController student = context.read<StudentController>();
    final Profile? profile = student.me?.profile;
    return '${student.isTertiaryFocus}:'
        '${profile?.exams.join(',') ?? ''}:'
        '${profile?.institution ?? ''}';
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadedFocusSig = _focusSignature();
    final ApiClient api = context.read<ApiClient>();
    try {
      final LearnProfile wallet = await api.learnProfile();
      final List<MyCourse> courses = await api.learnMyCourses();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _myCourses = courses;
        _loading = false;
        // Face routing: tertiary desks without an institutionType answer
        // the gate first; everyone else starts on their course list.
        if (_tertiary) {
          _face = wallet.institutionType.isEmpty ? _Face.itype : _Face.desk;
        } else {
          _face = _Face.list;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      // The catch-all (the broken-desk fix): an unexpected payload or
      // state error lands on the quiet syncing card - never a frozen
      // blank pane on the tab. _SyncingCard keeps polling.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reloadCourses() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<MyCourse> courses = await api.learnMyCourses();
      if (!mounted) return;
      setState(() => _myCourses = courses);
    } catch (_) {}
  }

  void _openCourse(MyCourse course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoursePathScreen(
          courseId: course.id,
          onManage: () {
            setState(() => _face = _tertiary ? _Face.manage : _Face.select);
          },
          onProgressChanged: () {
            _reloadCourses();
            widget.onNeedsResync?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const RenanceMark(size: 40, busy: true),
            const SizedBox(height: 14),
            Text(
              'Loading your courses…',
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return _SyncingCard(message: _error!);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_face) {
        _Face.list => _ListFace(
            key: const ValueKey<String>('list'),
            body: _body,
            courses: _myCourses,
            onOpen: _openCourse,
            onChoose: () => setState(() => _face = _Face.select),
            onManage: () => setState(() => _face = _Face.select),
          ),
        _Face.select => _SelectFace(
            key: const ValueKey<String>('select'),
            body: _body,
            courses: _myCourses,
            onChanged: () {
              _reloadCourses();
              widget.onNeedsResync?.call();
            },
            onDone: () => setState(() => _face = _Face.list),
          ),
        _Face.itype => _ItypeGate(
            key: const ValueKey<String>('itype'),
            wallet: _wallet,
            onSaved: _load,
            onChangeKind: () {},
          ),
        _Face.dept => _DeptGate(
            key: const ValueKey<String>('dept'),
            onSaved: _load,
            onChangeKind: () => setState(() => _face = _Face.itype),
          ),
        _Face.desk => _DeskFace(
            key: const ValueKey<String>('desk'),
            wallet: _wallet,
            courses: _myCourses,
            onOpen: _openCourse,
            onManage: () => setState(() => _face = _Face.manage),
          ),
        _Face.manage => _ManageFace(
            key: const ValueKey<String>('manage'),
            courses: _myCourses,
            onChanged: () {
              _reloadCourses();
              widget.onNeedsResync?.call();
            },
            onDone: () => setState(() => _face = _Face.desk),
            onChangeDesk: () => setState(() => _face = _Face.itype),
            onOpenCourse: _openCourse,
          ),
      },
    );
  }
}

/// Read-only focus helper (unused placeholder removed - the hub reads
/// StudentController directly).

 // ------------------------------------------------------------- shared

/// The offline / error stand-in every learn surface uses: quiet, no
/// retry buttons (founder rule), live poll.
class _SyncingCard extends StatefulWidget {
  const _SyncingCard({required this.message});

  final String message;

  @override
  State<_SyncingCard> createState() => _SyncingCardState();
}

class _SyncingCardState extends State<_SyncingCard> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const RenanceMark(size: 40, busy: true),
            const SizedBox(height: 14),
            Text(
              'Your courses are syncing…',
              style: RenanceText.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: RenanceText.caption.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page bar the pushed learn screens share: round back key + title.
class LearnPageBar extends StatelessWidget {
  const LearnPageBar({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // The web PageBar recipe (components/page-bar.tsx): `border-b-2
    // border-outline-variant`, ONE compact 48px bar at every
    // breakpoint, a calm 15px w800 tracking-tight title. The founder's
    // 2026-10-20 pass: the 40%-alpha hairline read as no border at all -
    // the rule is now the full-strength 2px swan line.
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      decoration: BoxDecoration(
        color: context.pageBg,
        border: Border(
          bottom: BorderSide(color: context.outlineVariant, width: 2),
        ),
        boxShadow: <BoxShadow>[
          // shadow-sm under the crisp rule, exactly like the home header
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 8),
            _RoundBack(onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The web PageBar title: text-on-surface - the token, so
                // dark mode lifts it to #F0F3F6 (never light-ink-in-dark).
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.15,
                  color: context.ink,
                ),
              ),
            ),
            if (action != null) ...<Widget>[const SizedBox(width: 8), action!],
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The web PageBar key: the FLAT 36px rounded-xl arrow - no circle,
    // no border, no ledge (founder directive 2026-10-20, the back-key
    // parity sweep). TactileBackKey now IS that key.
    return TactileBackKey(onTap: onTap ?? () => Navigator.of(context).maybePop());
  }
}

// ------------------------------------------------------------ list face

class _ListFace extends StatelessWidget {
  const _ListFace({
    super.key,
    required this.body,
    required this.courses,
    required this.onOpen,
    required this.onChoose,
    required this.onManage,
  });

  final String body;
  final List<MyCourse> courses;
  final void Function(MyCourse) onOpen;
  final VoidCallback onChoose;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top +66 + 16, 16, 112),
        children: <Widget>[
          const SizedBox(height: 24),
          Container(alignment: Alignment.center,
            
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.outlineVariant, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: mixTowardBlack(context.outlineVariant, 0.62),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                Container(alignment: Alignment.center,
                  
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: MsIcon('menu_book', size: 32, color: context.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Build your course list',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mark every course you want on your desk - each one becomes '
                  'a long roadmap of topics, notes with real drawings, and '
                  'your actual past questions.',
                  textAlign: TextAlign.center,
                  style: RenanceText.bodySecondary.copyWith(
                    color: context.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 18),
                TactileButton(
                  onPressed: onChoose,
                  height: 48,
                  child: const Text('Choose courses'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, MediaQuery.paddingOf(context).top +66 + 16, 16, 24),
      children: <Widget>[
        Text(
          'Your $body desk courses - tap one to open its roadmap.',
          style: RenanceText.bodySecondary.copyWith(
            color: context.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 14),
        for (final MyCourse c in courses)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CourseCard(course: c, onTap: () => onOpen(c)),
          ),
        const SizedBox(height: 6),
        Center(
          child: TactileButton(
            // The web's single management doorway: `key-btn mx-auto
            // bg-card text-on-surface` - the WHITE tactile key, not a
            // flat text link.
            onPressed: onManage,
            outline: context.outlineVariant,
            expand: false,
            height: 40,
            fontSize: 13.5,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('Add / remove courses'),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Your courses and department can be changed anytime.',
            style: RenanceText.caption.copyWith(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap, this.onRemove});

  final MyCourse course;
  final VoidCallback onTap;

  /// The remove key for the manage face's YOUR COURSES section (founder
  /// 2026-10-21: "the cancel button on the course card is not well
  /// positioned - only the x button should be on the RHS"). It rides as
  /// an inline flex sibling - vertically centred on the right-hand side
  /// - never the old floating corner overlay, and the '>' chevron is
  /// GONE from every card: only the × sits on the right.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final double pct = course.topicCount == 0
        ? 0
        : course.completedTopics / course.topicCount;
    return TactileCard(
      onTap: onTap,
      // Web CourseCard: p-4 (16px) rounded-2xl border-2 outline-variant.
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          // the web's icon well: h-11 w-11 (44px) rounded-xl
          // bg-primary/15 with the 22px primary-ink book
          Container(alignment: Alignment.center,
            
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: MsIcon(
              'menu_book',
              size: 22,
              color: mixTowardBlack(context.primary, 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Web CourseCard title: text-on-surface token - adapts
                  // to the dark tier (founded bug: #3C3C46 on #131720).
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${course.completedTopics}/${course.topicCount} topics done',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Web ProgressBar: h-3.5 = 14px tall, tone green / gold.
                LearnProgressBar(value: pct, height: 14, gold: pct >= 1),
              ],
            ),
          ),
          // The one RHS control: the remove × (inline, centred). The old
          // chevron_right and the floating top-right overlay are gone.
          if (onRemove != null) ...<Widget>[
            const SizedBox(width: 10),
            // Own gesture - a tap here must NOT also open the course.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RenanceColors.cardinal.withValues(alpha: 0.10),
                  border: Border.all(
                    color: RenanceColors.cardinal.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const MsIcon(
                  'close',
                  size: 16,
                  color: RenanceColors.cardinal,
                  wght: 700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- select face

/// The YOUR COURSES section (founder 2026-10-21): every course the
/// student already takes rides at the TOP of both add/remove faces -
/// exactly like the web manage page - each card carrying its own ×.
/// No searching, no hunting through shelves: one tap removes a course.
class _YourCoursesSection extends StatelessWidget {
  const _YourCoursesSection({
    required this.courses,
    required this.enrolledIds,
    required this.onOpen,
    required this.onRemove,
  });

  final List<MyCourse> courses;
  final Set<String> enrolledIds;
  final void Function(MyCourse course)? onOpen;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    // Optimistic: a just-tapped × hides the card at once - the parent's
    // reload confirms it a beat later.
    final List<MyCourse> mine = courses
        .where((MyCourse c) => enrolledIds.contains(c.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            text: 'YOUR COURSES',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: context.textSecondary,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: '  - tap the × to remove one',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color:
                      context.textSecondary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final MyCourse c in mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CourseCard(
              course: c,
              onTap: onOpen == null ? () {} : () => onOpen!(c),
              onRemove: () => onRemove(c.id),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _SelectFace extends StatefulWidget {
  const _SelectFace({
    super.key,
    required this.body,
    required this.courses,
    required this.onChanged,
    required this.onDone,
  });

  final String body;

  /// The student's FULL enrolled list (every desk body) - the payload
  /// source of truth for the picker. The old flag-only mirror dropped
  /// every enrolled course living beyond the first catalog page, so one
  /// toggle silently wiped it on the next save.
  final List<MyCourse> courses;
  final VoidCallback onChanged;
  final VoidCallback onDone;

  @override
  State<_SelectFace> createState() => _SelectFaceState();
}

class _SelectFaceState extends State<_SelectFace> {
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<CatalogItem> _all = <CatalogItem>[];
  // Optimistic enrolled mirror (the web's ref flip): the full
  // my-courses list first, catalog/shelf flags folded on top.
  Set<String> _enrolledIds = <String>{};

  @override
  void initState() {
    super.initState();
    _enrolledIds = <String>{for (final MyCourse c in widget.courses) c.id};
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final (List<CatalogItem> items, _) = await api.learnCatalog(
        body: widget.body,
        pageSize: 100,
      );
      if (!mounted) return;
      setState(() {
        _all = items;
        _enrolledIds = <String>{
          ..._enrolledIds,
          for (final CatalogItem i in items)
            if (i.inList) i.id,
        };
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  Future<void> _toggleId(String id) async {
    final bool nowIn = !_enrolledIds.contains(id);
    // Optimistic flip; rollback + notice on failure (web parity).
    setState(() {
      if (nowIn) {
        _enrolledIds.add(id);
      } else {
        _enrolledIds.remove(id);
      }
    });
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.learnSetMyCourses(_enrolledIds.toList());
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (nowIn) {
          _enrolledIds.remove(id);
        } else {
          _enrolledIds.add(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'That change did not stick - check your connection and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String q = _search.text.trim().toLowerCase();
    final List<CatalogItem> shown = q.isEmpty
        ? _all
        : _all
            .where(
              (CatalogItem i) =>
                  i.title.toLowerCase().contains(q) ||
                  i.id.toLowerCase().contains(q),
            )
            .toList();
    return Column(
      children: <Widget>[
        SizedBox(height: MediaQuery.paddingOf(context).top +66),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.body} subjects…',
                    prefixIcon: const MsIcon('search', size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TactileButton(
                onPressed: widget.onDone,
                expand: false,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                fontSize: 14,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: RenanceMark(size: 40, busy: true))
              : _error != null
                  ? _SyncingCard(message: _error!)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: shown.length + (widget.courses.isEmpty ? 0 : 1),
                      itemBuilder: (BuildContext context, int i) {
                        // YOUR COURSES first (founder 2026-10-21): the
                        // student's picked courses ride ABOVE the catalog
                        // with their own × - no hunting through search to
                        // remove one, exactly like the web manage page.
                        if (i == 0 && widget.courses.isNotEmpty) {
                          return _YourCoursesSection(
                            courses: widget.courses,
                            enrolledIds: _enrolledIds,
                            onOpen: null,
                            onRemove: _toggleId,
                          );
                        }
                        final int index =
                            i - (widget.courses.isEmpty ? 0 : 1);
                        final CatalogItem item = shown[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CatalogRow(
                            title: item.title,
                            sub: '${item.topicCount} topics · in your list',
                            subBold: _enrolledIds.contains(item.id),
                            checked: _enrolledIds.contains(item.id),
                            onTap: () => _toggleId(item.id),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.title,
    required this.sub,
    required this.checked,
    required this.onTap,
    this.subBold = false,
  });

  final String title;
  final String sub;
  final bool checked;
  final bool subBold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: checked ? context.primary.withValues(alpha: 0.08) : context.card,
      outline: checked ? context.primary : context.outlineVariant,
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: checked ? context.primary : context.cardLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checked ? context.primary : context.outlineVariant,
                width: 2,
              ),
            ),
            child: checked
                ? const MsIcon('check', size: 18, color: Colors.white, fill: true)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: RenanceText.caption.copyWith(
                    fontSize: 12,
                    color: subBold ? context.ink : context.textSecondary,
                    fontWeight: subBold ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Founder 2026-10-21: the red cancel ❌ is GONE from the
          // selection rows - the checkbox already adds/removes, so the
          // red key was a duplicate that cluttered every taken row.
          // Removal now lives in YOUR COURSES at the top of the page.
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- itype gate

class _ItypeGate extends StatelessWidget {
  const _ItypeGate({super.key, this.wallet, required this.onSaved, required this.onChangeKind});

  final LearnProfile? wallet;
  final VoidCallback onSaved;
  final VoidCallback onChangeKind;

  static const List<(String, String, String, String)> _kinds =
      <(String, String, String, String)>[
    (
      'University',
      'account_balance',
      'University',
      'Degree programmes - BSc, BEng, BA and friends',
    ),
    (
      'Polytechnic',
      'precision_manufacturing',
      'Polytechnic',
      'ND and HND technical programmes',
    ),
    (
      'College of Education',
      'history_edu',
      'College of Education',
      'NCE and degree education programmes',
    ),
  ];

  Future<void> _pick(BuildContext context, String itype) async {
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.learnPatchProfile(
        institutionType: itype,
        department: '',
        setDesk: true,
      );
    } catch (_) {}
    onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.paddingOf(context).top +66 + 16, 16, 24),
      children: <Widget>[
        Text('Step 1 of 2', style: RenanceText.overline.copyWith(color: context.textSecondary)),
        const SizedBox(height: 4),
        const Text(
          'What kind of tertiary institution?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your department list depends on this - we ask once and remember it.',
          style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
        ),
        const SizedBox(height: 18),
        for (final (String id, String icon, String title, String sub) in _kinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TactileCard(
              onTap: () => _pick(context, id),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(alignment: Alignment.center,
                    
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: MsIcon(icon, size: 23, color: context.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: RenanceText.caption.copyWith(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------- dept gate

class _DeptGate extends StatefulWidget {
  const _DeptGate({super.key, required this.onSaved, required this.onChangeKind});

  final VoidCallback onSaved;
  final VoidCallback onChangeKind;

  @override
  State<_DeptGate> createState() => _DeptGateState();
}

class _DeptGateState extends State<_DeptGate> {
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<DeskDepartment> _all = <DeskDepartment>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    final LearnProfile wallet;
    try {
      wallet = await api.learnProfile();
      final List<DeskDepartment> deps =
          await api.learnDepartments(wallet.institutionType);
      if (!mounted) return;
      setState(() {
        _all = deps;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  Future<void> _pick(DeskDepartment d) async {
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.learnPatchProfile(setDesk: true, department: d.id);
    } catch (_) {}
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final String q = _search.text.trim().toLowerCase();
    final List<DeskDepartment> shown = q.isEmpty
        ? _all
        : _all
            .where((DeskDepartment d) =>
                d.name.toLowerCase().contains(q) ||
                d.faculty.toLowerCase().contains(q))
            .toList();
    return Column(
      children: <Widget>[
        SizedBox(height: MediaQuery.paddingOf(context).top +66),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Step 2 of 2',
                  style: RenanceText.overline.copyWith(color: context.textSecondary)),
              const SizedBox(height: 4),
              const Text(
                'Which department are you in?',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Real departments for your institution - pick yours and your '
                'course list appears.',
                style: RenanceText.bodySecondary
                    .copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search departments…',
                  prefixIcon: MsIcon('search', size: 20),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onChangeKind,
                  child: const Text('Change institution kind'),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: RenanceMark(size: 40, busy: true))
              : _error != null
                  ? _SyncingCard(message: _error!)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: shown.length,
                      itemBuilder: (BuildContext context, int i) {
                        final DeskDepartment d = shown[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CatalogRow(
                            title: d.name,
                            sub: '${d.faculty} · ${d.courseCount} courses',
                            checked: false,
                            onTap: () => _pick(d),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- desk face

class _DeskFace extends StatelessWidget {
  const _DeskFace({
    super.key,
    required this.wallet,
    required this.courses,
    required this.onOpen,
    required this.onManage,
  });

  final LearnProfile? wallet;
  final List<MyCourse> courses;
  final void Function(MyCourse) onOpen;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final int done = courses.fold<int>(
        0, (int s, MyCourse c) => s + c.completedTopics);
    final int total = courses.fold<int>(
        0, (int s, MyCourse c) => s + c.topicCount);
    return ListView(
      padding: EdgeInsets.fromLTRB(
          0, MediaQuery.paddingOf(context).top +66, 0, 24),
      children: <Widget>[
        // The web's MY SEMESTER banner: learn-tile rounded-2xl
        // border-2 border-primary/40, the 135deg primary->deep gradient,
        // the white/20 school icon key and the white/15 stats pill.
        Container(alignment: Alignment.center,
          
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                context.primary,
                mixTowardBlack(context.primary, 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.primary.withValues(alpha: 0.40),
              width: 2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.outlineVariant.withValues(alpha: 0.55),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(alignment: Alignment.center,
                    
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const MsIcon('school',
                        size: 22, color: Colors.white, fill: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'My Semester',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${wallet?.institutionType ?? ''} · ${wallet?.departmentName ?? 'Your department'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${courses.length} course${courses.length == 1 ? '' : 's'}'
                  ' · $done / $total topics done',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Your courses',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '- tap one to open its roadmap',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              for (final MyCourse c in courses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CourseCard(course: c, onTap: () => onOpen(c)),
                ),
              Center(
                child: TactileButton(
                  // Web: `key-btn mx-auto bg-card text-on-surface` - the
                  // white tactile key, centered, not a full-width green bar.
                  onPressed: onManage,
                  outline: context.outlineVariant,
                  expand: false,
                  height: 40,
                  fontSize: 13.5,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text('Add / remove courses'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Your courses and department can be changed anytime.',
                  style: RenanceText.caption.copyWith(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------- manage face

class _ManageFace extends StatefulWidget {
  const _ManageFace({
    super.key,
    required this.courses,
    required this.onChanged,
    required this.onDone,
    required this.onChangeDesk,
    this.onOpenCourse,
  });

  /// The student's FULL enrolled list - renders the YOUR COURSES
  /// section at the top (founder 2026-10-21: "the mobile app course
  /// additions/remove page should list the courses a user is already
  /// doing at the top like the website own - users don't need to
  /// search for their course to remove it") and guarantees the save
  /// payload never drops courses living beyond the loaded shelves.
  final List<MyCourse> courses;
  final VoidCallback onChanged;
  final VoidCallback onDone;
  final VoidCallback onChangeDesk;
  final void Function(MyCourse course)? onOpenCourse;

  @override
  State<_ManageFace> createState() => _ManageFaceState();
}

class _ManageFaceState extends State<_ManageFace> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  DeskShelves? _shelves;
  List<DeskCourse> _others = <DeskCourse>[];
  int _othersTotal = 0;
  // Optimistic enrolled mirror: the full my-courses list first, then
  // every shelf/search inList flag folded on top (web mineRef parity -
  // the payload is always the WHOLE list, so a shelf that loads late
  // can never wipe a picked course again).
  Set<String> _enrolledIds = <String>{};
  List<DeskCourse> _results = <DeskCourse>[];
  bool _searching = false;
  String _query = '';

  // AI finder state
  final TextEditingController _aiText = TextEditingController();
  bool _aiBusy = false;
  List<AIMatchLine> _aiLines = <AIMatchLine>[];
  final Set<String> _aiPicked = <String>{};

  @override
  void initState() {
    super.initState();
    _enrolledIds = <String>{for (final MyCourse c in widget.courses) c.id};
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    _aiText.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final DeskShelves shelves = await api.learnCourseDesk();
      if (!mounted) return;
      setState(() {
        _shelves = shelves;
        _enrolledIds = <String>{
          ..._enrolledIds,
          for (final DeskCourse c in shelves.general)
            if (c.inList) c.id,
          for (final DeskCourse c in shelves.departmental)
            if (c.inList) c.id,
        };
        _loading = false;
      });
      _loadOthers(0);
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    }
  }

  Future<void> _loadOthers(int offset) async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final (List<DeskCourse> items, int total) =
          await api.learnCourseDeskOthers(offset: offset, limit: 100);
      if (!mounted) return;
      setState(() {
        if (offset == 0) {
          _others = items;
        } else {
          _others.addAll(items);
        }
        _othersTotal = total;
        for (final DeskCourse c in items) {
          if (c.inList) _enrolledIds.add(c.id);
        }
      });
    } catch (_) {}
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    setState(() => _query = q);
    if (q.trim().length < 2) {
      setState(() {
        _results = <DeskCourse>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final ApiClient api = context.read<ApiClient>();
      try {
        final List<DeskCourse> res = await api.learnSearch(q.trim());
        if (!mounted || _query != q) return;
        setState(() {
          _results = res;
          _searching = false;
          for (final DeskCourse c in res) {
            if (c.inList) _enrolledIds.add(c.id);
          }
        });
      } catch (_) {
        // Founder 2026-10-21 - the search must NEVER look dead: the
        // local shelf filter below already shows instant matches, so a
        // failed/slow server search just means "local results only".
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  /// Instant client-side matches over every ALREADY-LOADED course
  /// (general shelf + departmental shelf + borrowed pages), matched on
  /// code / title / department. This is what makes the search feel
  /// alive the moment two characters land, even offline.
  List<DeskCourse> _localMatches() {
    final String needle = _query.trim().toLowerCase();
    final DeskShelves? shelves = _shelves;
    if (needle.length < 2 || shelves == null) return const <DeskCourse>[];
    final Map<String, DeskCourse> seen = <String, DeskCourse>{};
    for (final DeskCourse c in <DeskCourse>[
      ...shelves.general,
      ...shelves.departmental,
      ..._others,
    ]) {
      if (seen.containsKey(c.id)) continue;
      final String hay =
          '${c.code} ${c.title} ${c.department}'.toLowerCase();
      if (hay.contains(needle)) seen[c.id] = c;
    }
    return seen.values.toList();
  }

  /// Server hits first (they rank across the whole catalogue), then the
  /// local matches the server missed - deduped by id.
  List<DeskCourse> _mergedResults() {
    final List<DeskCourse> local = _localMatches()
        .where((DeskCourse c) => !_results.any((DeskCourse r) => r.id == c.id))
        .toList();
    return <DeskCourse>[..._results, ...local];
  }

  Future<void> _toggleId(String id) async {
    final bool nowIn = !_enrolledIds.contains(id);
    setState(() {
      if (nowIn) {
        _enrolledIds.add(id);
      } else {
        _enrolledIds.remove(id);
      }
    });
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.learnSetMyCourses(_enrolledIds.toList());
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (nowIn) {
          _enrolledIds.remove(id);
        } else {
          _enrolledIds.add(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'That change did not stick - check your connection and try again.'),
        ),
      );
    }
  }

  Future<void> _runAiFinder() async {
    if (_aiBusy) return;
    final String text = _aiText.text.trim();
    if (text.isEmpty) return;
    setState(() => _aiBusy = true);
    final ApiClient api = context.read<ApiClient>();
    try {
      final List<AIMatchLine> lines = await api.learnAiMatch(text);
      if (!mounted) return;
      setState(() {
        _aiLines = lines;
        _aiPicked.clear();
        for (final AIMatchLine l in lines) {
          if (l.matches.isNotEmpty) _aiPicked.add(l.matches.first.id);
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        // 5xx means the silent client retry already ran (learnAiMatch
        // retries server faults once) - the copy asks for one more tap
        // instead of blaming the student's connection.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.statusCode >= 500
              ? 'The AI finder stumbled on our servers - tap Find my '
                  'courses again in a few seconds.'
              : e.message),
        ));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _saveAiPicks() async {
    if (_aiPicked.isEmpty) return;
    final ApiClient api = context.read<ApiClient>();
    final Set<String> merged = <String>{..._enrolledIds, ..._aiPicked};
    try {
      await api.learnSetMyCourses(merged.toList());
      widget.onChanged();
      widget.onDone();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'That change did not stick - check your connection and try again.'),
          ),
        );
      }
    }
  }

  void _openRequestSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CourseRequestSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: RenanceMark(size: 40, busy: true));
    }
    if (_error != null) {
      return _SyncingCard(message: _error!);
    }
    final DeskShelves? shelves = _shelves;
    if (shelves == null) return const SizedBox.shrink();

    // Founder 2026-10-21 - the search finally WORKS: two characters
    // flip the list into a merged results view (instant local shelf
    // matches + the ranked server hits), and the AI panel / request /
    // shelves step aside until the query clears.
    final bool isSearching = _query.trim().length >= 2;
    final List<DeskCourse> merged = isSearching ? _mergedResults() : const <DeskCourse>[];

    return Column(
      children: <Widget>[
        SizedBox(height: MediaQuery.paddingOf(context).top +66),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  MsIcon('tune', size: 22, color: context.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Add / remove courses',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TactileButton(
                    onPressed: widget.onDone,
                    expand: false,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    fontSize: 13,
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Search by code (CSC, MTH…), title or topic',
                  prefixIcon: MsIcon('search', size: 20),
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Searching the whole catalogue…',
                    style: RenanceText.caption
                        .copyWith(color: context.textSecondary, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              // YOUR COURSES first (founder 2026-10-21): every course the
              // student already takes, listed at the top like the web
              // manage page - the × removes it, no searching required.
              if (widget.courses.isNotEmpty)
                _YourCoursesSection(
                  courses: widget.courses,
                  enrolledIds: _enrolledIds,
                  onOpen: widget.onOpenCourse,
                  onRemove: _toggleId,
                ),
              // search results (live, merged: server + local shelves)
              if (isSearching) ...<Widget>[
                if (merged.isEmpty && !_searching)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Nothing matches "${_query.trim()}". Try a course '
                      'code (three letters) or a topic.',
                      textAlign: TextAlign.center,
                      style: RenanceText.caption.copyWith(
                        fontSize: 12.5,
                        color: context.textSecondary,
                      ),
                    ),
                  )
                else ...<Widget>[
                  for (final DeskCourse c in merged)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DeskRow(
                        course: c,
                        inList: _enrolledIds.contains(c.id),
                        onTap: () => _toggleId(c.id),
                      ),
                    ),
                ],
              ] else ...<Widget>[
                // AI finder
                _AiFinderPanel(
                  controller: _aiText,
                  busy: _aiBusy,
                  lines: _aiLines,
                  picked: _aiPicked,
                  onRun: _runAiFinder,
                  onTogglePick: (String id) => setState(() {
                    if (_aiPicked.contains(id)) {
                      _aiPicked.remove(id);
                    } else {
                      _aiPicked.add(id);
                    }
                  }),
                  onSave: _saveAiPicks,
                ),
                const SizedBox(height: 12),
                // course request
                _RequestCard(onOpen: _openRequestSheet),
                const SizedBox(height: 16),
                // shelves
                Text(
                  _shelfGeneralTitle(shelves.institutionType),
                  style: RenanceText.bodyMedium,
                ),
                const SizedBox(height: 10),
                for (final DeskCourse c in shelves.general)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeskRow(
                      course: c,
                      inList: _enrolledIds.contains(c.id),
                      onTap: () => _toggleId(c.id),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${shelves.departmentName} courses',
                  style: RenanceText.bodyMedium,
                ),
                const SizedBox(height: 10),
                for (final DeskCourse c in shelves.departmental)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeskRow(
                      course: c,
                      inList: _enrolledIds.contains(c.id),
                      onTap: () => _toggleId(c.id),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  "Other departments' courses - $_othersTotal borrowable",
                  style: RenanceText.bodyMedium,
                ),
                const SizedBox(height: 10),
                for (final DeskCourse c in _others)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeskRow(
                      course: c,
                      inList: _enrolledIds.contains(c.id),
                      onTap: () => _toggleId(c.id),
                    ),
                  ),
                if (_othersTotal > _others.length)
                  Center(
                    child: TextButton(
                      onPressed: () => _loadOthers(_others.length),
                      child: Text(
                        'Show more (${_othersTotal - _others.length} more)'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: widget.onChangeDesk,
                    child: const Text('Change department or institution kind'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _shelfGeneralTitle(String itype) {
    return switch (itype) {
      'Polytechnic' => 'ND I general courses - everyone takes these',
      'College of Education' => 'NCE I general courses - everyone takes these',
      _ => '100 Level general courses - everyone takes these',
    };
  }
}

/// One desk course row: checkbox + code badge + title + meta. Founder
/// 2026-10-21: the small cancel ❌ that used to ride the right-hand tip
/// is REMOVED - the checkbox already toggles, and removal lives in the
/// YOUR COURSES section at the top of the manage page (one obvious
/// place to delete a course, no red clutter on every taken row).
/// The selected style stays the calm wash (seed 8% face + seed border)
/// so the title and meta stay readable in EVERY appearance colour.
class _DeskRow extends StatelessWidget {
  const _DeskRow({
    required this.course,
    required this.inList,
    required this.onTap,
  });

  final DeskCourse course;
  final bool inList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TactileCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: inList ? context.primary.withValues(alpha: 0.08) : context.card,
      outline: inList ? context.primary : context.outlineVariant,
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: inList ? context.primary : context.cardLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: inList ? context.primary : context.outlineVariant,
                width: 2,
              ),
            ),
            child: inList
                ? const MsIcon('check', size: 18, color: Colors.white, fill: true)
                : null,
          ),
          const SizedBox(width: 12),
          if (course.code.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                course.code,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: mixTowardBlack(context.primary, 0.6),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${course.department} · ${course.topicCount} topics'
                  '${inList ? ' · in your list' : ''}',
                  style: RenanceText.caption.copyWith(
                    fontSize: 11.5,
                    color: context.textSecondary,
                    fontWeight: inList ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // (the old right-tip ❌ removed - founder 2026-10-21)
        ],
      ),
    );
  }
}

/// The "Find my courses with AI" collapsible panel.
class _AiFinderPanel extends StatelessWidget {
  const _AiFinderPanel({
    required this.controller,
    required this.busy,
    required this.lines,
    required this.picked,
    required this.onRun,
    required this.onTogglePick,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool busy;
  final List<AIMatchLine> lines;
  final Set<String> picked;
  final VoidCallback onRun;
  final ValueChanged<String> onTogglePick;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.outlineVariant, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: mixTowardBlack(context.outlineVariant, 0.62),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              MsIcon('auto_awesome', size: 20, color: context.primary),
              const SizedBox(width: 8),
              Text(
                'Find my courses with AI',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type all your course titles - the AI finds them in the catalogue '
            'and sets up your list.',
            style: RenanceText.caption.copyWith(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'One course per line, e.g.\nCSC 101 Introduction to '
                  'Computing\nGeneral Mathematics\nUse of English',
            ),
          ),
          const SizedBox(height: 10),
          TactileButton(
            onPressed: busy ? null : onRun,
            height: 44,
            child: Text(busy ? 'Finding your courses…' : 'Find my courses'),
          ),
          for (final AIMatchLine line in lines) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              line.input,
              style: RenanceText.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            if (line.matches.isEmpty)
              Text(
                'No match in the catalogue yet.',
                style: RenanceText.caption.copyWith(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              )
            else
              for (final DeskCourse m in line.matches.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DeskRow(
                    course: m,
                    inList: picked.contains(m.id),
                    onTap: () => onTogglePick(m.id),
                  ),
                ),
          ],
          if (lines.isNotEmpty && picked.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            TactileButton(
              onPressed: onSave,
              height: 44,
              face: RenanceColors.bee,
              onFace: Colors.white,
              edge: RenanceColors.beeDark,
              child: Text('Add ${picked.length} courses to my list'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The dashed "Can't find your course?" card.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.outlineVariant,
            width: 2,
          ),
          color: context.cardLow,
        ),
        child: Row(
          children: <Widget>[
            MsIcon('add', size: 20, color: context.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Can't find your course?",
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The course-request bottom sheet (CourseRequestModal).
class CourseRequestSheet extends StatefulWidget {
  const CourseRequestSheet({super.key});

  @override
  State<CourseRequestSheet> createState() => _CourseRequestSheetState();
}

class _CourseRequestSheetState extends State<CourseRequestSheet> {
  final TextEditingController _school = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  String _itype = 'university';
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _school.dispose();
    _department.dispose();
    _code.dispose();
    _title.dispose();
    _topics.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_school.text.trim().isEmpty ||
        (_code.text.trim().isEmpty && _title.text.trim().isEmpty)) {
      return;
    }
    setState(() => _busy = true);
    final ApiClient api = context.read<ApiClient>();
    try {
      await api.learnRequestCourse(
        institutionType: _itype,
        schoolName: _school.text.trim(),
        department: _department.text.trim(),
        code: _code.text.trim(),
        title: _title.text.trim(),
        topics: _topics.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    } on NetworkException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.pageBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      MsIcon('check_circle',
                          size: 44, color: context.primary, fill: true),
                      const SizedBox(height: 12),
                      const Text(
                        'Course submitted',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The desk has your course and its topics. It lands in '
                        'the review queue with your name on it - watch the app '
                        'for the update.',
                        textAlign: TextAlign.center,
                        style: RenanceText.bodySecondary
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TactileButton(
                        onPressed: () => Navigator.of(context).pop(),
                        height: 46,
                        child: const Text('Close'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        "Can't find your course?",
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Tell us the course and some of its topics - we'll "
                        "build the question bank.",
                        style: RenanceText.bodySecondary
                            .copyWith(color: context.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _itype,
                        decoration: const InputDecoration(labelText: 'Institution type'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(value: 'university', child: Text('University')),
                          DropdownMenuItem<String>(value: 'polytechnic', child: Text('Polytechnic')),
                          DropdownMenuItem<String>(value: 'college-of-education', child: Text('College of Education')),
                          DropdownMenuItem<String>(value: 'college-of-nursing', child: Text('College of Nursing')),
                          DropdownMenuItem<String>(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (String? v) =>
                            setState(() => _itype = v ?? 'university'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _school,
                        decoration: const InputDecoration(
                          labelText: 'School name (e.g. FUTA)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _department,
                        decoration: const InputDecoration(
                          labelText: 'Department (e.g. Computer Science)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'Course code (e.g. CSC 101)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(
                          labelText: 'Course title (e.g. Introduction to Computing)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _topics,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText:
                              'Some topics you expect in this course (one per line)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TactileButton(
                              onPressed: () => Navigator.of(context).pop(),
                              height: 46,
                              face: context.card,
                              onFace: context.ink,
                              edge: mixTowardBlack(context.outlineVariant, 0.62),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TactileButton(
                              onPressed: _busy ? null : _submit,
                              height: 46,
                              child: Text(_busy ? 'Sending…' : 'Send'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- path screen

/// The pushed course PATH screen: page bar + the zig-zag ladder.
class CoursePathScreen extends StatefulWidget {
  const CoursePathScreen({
    super.key,
    required this.courseId,
    required this.onManage,
    required this.onProgressChanged,
  });

  final String courseId;
  final VoidCallback onManage;
  final VoidCallback onProgressChanged;

  @override
  State<CoursePathScreen> createState() => _CoursePathScreenState();
}

class _CoursePathScreenState extends State<CoursePathScreen> {
  bool _loading = true;
  String? _error;
  CoursePathModel? _path;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final ApiClient api = context.read<ApiClient>();
    try {
      final CoursePathModel path = await api.learnCoursePath(widget.courseId);
      if (!mounted) return;
      setState(() {
        _path = path;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } on NetworkException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      // The catch-all: a malformed path payload shows its message on
      // the page bar screen - never a blank pane under a pushed route.
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _openChest(UnitNode unit) async {
    final ApiClient api = context.read<ApiClient>();
    final LearnController learn = context.read<LearnController>();
    try {
      final ChestOpenResult res = await api.learnOpenChest('${widget.courseId}#${unit.index}');
      learn.apply(null);
      await learn.refresh();
      if (!mounted) return;
      await showChestCelebration(
        context,
        kind: 'gems',
        amount: res.gems,
        label: '${res.gems} gems',
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      body: Column(
        children: <Widget>[
          LearnPageBar(title: _path?.title ?? 'Course path'),
          Expanded(
            child: _loading
                ? const Center(child: RenanceMark(size: 40, busy: true))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: RenanceText.bodySecondary
                                .copyWith(color: context.textSecondary),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        // LearnPathView is itself a CustomScrollView
                        // whose unit banners PIN at the top (the web's
                        // sticky sub-navbar); no outer scroll view.
                        child: LearnPathView(
                            path: _path!,
                            onOpenTopic: (TopicNode t) {
                              LessonOverlay.open(
                                context,
                                mode: LessonMode.lesson,
                                topicId: t.id,
                                courseCode: _path?.title ?? '',
                                onFinished: () {
                                  _load();
                                  widget.onProgressChanged();
                                },
                              );
                            },
                            onOpenChest: _openChest,
                            onOpenRevision: (UnitNode unit) {
                              LessonOverlay.open(
                                context,
                                mode: LessonMode.revision,
                                courseId: widget.courseId,
                                unit: unit.index,
                                courseCode: _path?.title ?? '',
                                onFinished: () {
                                  _load();
                                  widget.onProgressChanged();
                                },
                              );
                            },
                            onManageCourses: () {
                              Navigator.of(context).pop();
                              widget.onManage();
                            },
                          ),
                        ),
                      ),
        ],
      ),
    );
  }
}
