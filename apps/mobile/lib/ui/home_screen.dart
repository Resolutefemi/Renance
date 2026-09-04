/// Root shell + launcher home, the Stitch home_dashboard_jamb_light and
/// more_features_sheet_light screens, 1:1.
///
/// Shell: 5-tab bottom nav (Home / Practice / Review / Progress / Profile).
/// Launcher: brand header with streak pill, hero progress card (Next
/// Target / Countdown / Syllabus Completion / Continue Practice), the
/// Practice and Grow icon grids, and the recent-activity feed, all fed
/// by real data (StudentController + SyncController).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'downloads_screen.dart';
import 'flashcards_screen.dart';
import 'lessons_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'tutor_screen.dart';
import 'exam_screen.dart';
import 'library_screen.dart';
import 'onboarding_sheet.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'renance_logo.dart';
import 'review_screen.dart';
import 'syllabus_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final StudentController student = context.read<StudentController>();
    final SyncController sync = context.read<SyncController>();
    final SessionStore session = context.read<SessionStore>();
    await student.refresh();
    if (!mounted) return;
    final MeResult? me = student.me;
    if (me == null) {
      // 401 handled inside refresh() via error; on network error stay and
      // let the user pull-to-refresh.
      if (student.error != null) {
        await session.clear();
        if (!mounted) return;
        await Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
    }
    if (!student.hasProfile) {
      _showOnboarding();
      return;
    }
    await _startSync(student, sync);
  }

  Future<void> _startSync(
    StudentController student,
    SyncController sync,
  ) async {
    final exams = student.me?.profile?.exams ?? const <String>[];
    student.cacheManifestTitles(sync.exams);
    if (sync.exams.isEmpty) {
      await sync.bootstrap(profileExams: exams);
      student.cacheManifestTitles(sync.exams);
    }
    await student.refreshDownloaded();
    if (mounted) {
      setState(() => _bootstrapped = true);
    }
  }

  void _showOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bool? completed = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const OnboardingSheet(),
      );
      if (completed != true || !mounted) return;
      final StudentController student = context.read<StudentController>();
      final SyncController sync = context.read<SyncController>();
      await student.refresh();
      await _startSync(student, sync);
    });
  }

  void _openExam(BuildContext context, ExamMeta exam) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ExamScreen(exam: exam)));
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final bool firstSyncUnderway =
        !_bootstrapped && sync.exams.isEmpty && sync.isSyncing;

    final bodies = <Widget>[
      _LauncherTab(
        student: student,
        sync: sync,
        firstSyncUnderway: firstSyncUnderway,
        onOpenExam: _openExam,
        onGoTab: (int t) => setState(() => _tab = t),
        onOnboarding: _showOnboarding,
      ),
      LibraryScreen(onOpenExam: _openExam),
      const ReviewScreen(),
      const ProgressScreen(),
      ProfileScreen(
        onGoTab: (int t) => setState(() => _tab = t),
        onFocusChanged: () async {
          final StudentController fresh = context.read<StudentController>();
          final SyncController freshSync = context.read<SyncController>();
          await _startSync(fresh, freshSync);
        },
      ),
    ];

    final Widget shellBody = Stack(
      children: <Widget>[
        // Body sits UNDER the header (which paints its own background).
        Positioned.fill(
          top: 0,
          child: ColoredBox(
            color: RenanceColors.card,
            child: IndexedStack(index: _tab, children: bodies),
          ),
        ),
        // Brand header, bg-surface/80 + hairline shadow (Stitch header).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: HomeHeader(
            streak: student.gamification?.state.currentStreak ?? 0,
            name: student.me?.profile?.fullName ?? '',
            onBrand: () => setState(() => _tab = 0),
            onAvatar: () => setState(() => _tab = 4),
            onBackPressed: _tab == 0 ? null : () => setState(() => _tab = 0),
            onSearch: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            ),
            onNotifications: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => NotificationsScreen(
                  onGoTab: (int t) => setState(() => _tab = t),
                ),
              ),
            ),
            alert: student.dueTopics > 0,
          ),
        ),
      ],
    );

    // Adaptive shell (founder directive: the app runs on phones AND
    // desktops). Narrow form factors keep the Stitch bottom nav; at
    // >=1000 logical pixels a side rail replaces it and the content is
    // centred at reading width, the way a real desktop app behaves.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 1000;
        if (!wide) {
          return Scaffold(
            backgroundColor: RenanceColors.background,
            body: shellBody,
            bottomNavigationBar: HomeNav(
              active: _tab,
              reviewBadge: student.dueTopics,
              onTap: (int t) => setState(() => _tab = t),
            ),
          );
        }
        return Scaffold(
          backgroundColor: RenanceColors.background,
          body: Row(
            children: <Widget>[
              _WideRail(
                active: _tab,
                reviewBadge: student.dueTopics,
                onTap: (int t) => setState(() => _tab = t),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: RenanceColors.outlineVariant,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: shellBody,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Desktop navigation rail: same five destinations as HomeNav, drawn as
/// a vertical Stitch-style launcher with the brand mark on top.
class _WideRail extends StatelessWidget {
  const _WideRail({
    required this.active,
    required this.reviewBadge,
    required this.onTap,
  });

  final int active;
  final int reviewBadge;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.edit_note, Icons.edit_note, 'Practice'),
    (Icons.history_edu, Icons.history_edu, 'Review'),
    (Icons.leaderboard_outlined, Icons.leaderboard, 'Progress'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 16),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Text(
                'R',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == active
                          ? RenanceColors.surfaceContainerLow
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: <Widget>[
                        Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Icon(
                              i == active ? _items[i].$2 : _items[i].$1,
                              size: 24,
                              color: i == active
                                  ? Colors.black
                                  : RenanceColors.textSecondary,
                            ),
                            if (i == 2 && reviewBadge > 0)
                              Positioned(
                                top: -5,
                                right: -7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RenanceColors.emerald,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$reviewBadge',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _items[i].$3,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: i == active
                                ? Colors.black
                                : RenanceColors.textSecondary,
                            fontWeight: i == active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Text(
              'Renance',
              style: RenanceText.labelMono.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- header

/// The fixed brand header: black R tile + wordmark, streak pill, avatar.
/// The brand mark jumps back to Home and the avatar opens Profile, the
/// founder's navigation rule for the top bar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.streak,
    required this.name,
    this.onBrand,
    this.onAvatar,
    this.onBackPressed,
    this.onSearch,
    this.onNotifications,
    this.alert = false,
  });

  final int streak;
  final String name;
  final VoidCallback? onBrand;
  final VoidCallback? onAvatar;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;

  /// Emerald dot on the bell when something needs attention (review due).
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RenanceColors.background,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              _Tappable(onTap: onBrand, child: const _BrandMark()),
              const Spacer(),
              if (onSearch != null)
                _HeaderIcon(
                  icon: Icons.search,
                  onTap: onSearch,
                ),
              if (onNotifications != null) ...<Widget>[
                const SizedBox(width: 2),
                _HeaderIcon(
                  icon: Icons.notifications_none,
                  onTap: onNotifications,
                  alert: alert,
                ),
              ],
              const SizedBox(width: 6),
              StreakPill(streak: streak),
              const SizedBox(width: 16),
              _Tappable(
                onTap: onAvatar,
                child: AvatarCircle(name: name, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pointer-cursor tap wrapper used for header affordances so the brand
/// mark and avatar feel clickable on desktop too.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

/// Black rounded square with the white R, matches the web header.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Text(
            'R',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Renance', style: RenanceText.displayMd),
      ],
    );
  }
}

/// One round icon button in the header (search, bell) with the optional
/// emerald attention dot.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.alert = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 22),
          color: RenanceColors.ink,
          visualDensity: VisualDensity.compact,
          tooltip: icon == Icons.search
              ? 'Search'
              : 'Notifications',
        ),
        if (alert)
          const Positioned(
            top: 6,
            right: 6,
            child: SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: RenanceColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The amber-flame streak pill in the header.
class StreakPill extends StatelessWidget {
  const StreakPill({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: RenanceColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.local_fire_department,
            size: 20,
            color: RenanceColors.amber,
          ),
          const SizedBox(width: 4),
          Text('$streak', style: RenanceText.labelMono),
        ],
      ),
    );
  }
}

/// Initials avatar with the outline ring from the designs.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.size = 32});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String initials = name.trim().isEmpty
        ? 'R'
        : name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RenanceColors.surfaceContainerHigh,
        border: Border.all(color: RenanceColors.outlineLight),
      ),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: RenanceColors.ink,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ bottom nav

/// 5-tab nav: white/95, rounded top corners, active tab fills its icon and
/// grows a 4px dot, the Stitch nav pattern.
class HomeNav extends StatelessWidget {
  const HomeNav({
    super.key,
    required this.active,
    required this.reviewBadge,
    required this.onTap,
  });

  final int active;
  final int reviewBadge;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.edit_note, Icons.edit_note, 'Practice'),
    (Icons.history_edu, Icons.history_edu, 'Review'),
    (Icons.leaderboard_outlined, Icons.leaderboard, 'Progress'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, -1),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: 64,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Icon(
                            i == active ? _items[i].$2 : _items[i].$1,
                            size: 24,
                            color: i == active
                                ? Colors.black
                                : RenanceColors.textSecondary,
                          ),
                          if (i == 2 && reviewBadge > 0)
                            Positioned(
                              top: -6,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: RenanceColors.emerald,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$reviewBadge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[i].$3,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.0,
                          color: i == active
                              ? Colors.black
                              : RenanceColors.textSecondary,
                          fontWeight: i == active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == active
                              ? Colors.black
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ launcher tab

class _LauncherTab extends StatelessWidget {
  const _LauncherTab({
    required this.student,
    required this.sync,
    required this.firstSyncUnderway,
    required this.onOpenExam,
    required this.onGoTab,
    required this.onOnboarding,
  });

  final StudentController student;
  final SyncController sync;
  final bool firstSyncUnderway;
  final void Function(BuildContext, ExamMeta) onOpenExam;
  final ValueChanged<int> onGoTab;
  final VoidCallback onOnboarding;


  @override
  Widget build(BuildContext context) {
    final AttemptRow? recent = student.latestAttempt;
    final int pending = sync.pendingCount;

    return RefreshIndicator(
      onRefresh: student.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 64 + 16,
          16,
          24,
        ),
        children: <Widget>[
          // Hero progress card -------------------------------------------
          _HeroCard(
            student: student,
            onContinue: () {
              final syncExams = sync.exams;
              if (syncExams.isNotEmpty) {
                onOpenExam(context, syncExams.first);
              } else {
                onGoTab(1); // library
              }
            },
          ),
          if (pending > 0) ...<Widget>[
            const SizedBox(height: 12),
            _PendingBanner(count: pending, onRetry: sync.retryPending),
          ],
          if (sync.phase == SyncPhase.error) ...<Widget>[
            const SizedBox(height: 12),
            _SyncErrorBanner(sync: sync),
          ],
          if (student.fatigue?.suggestBreak ?? false) ...<Widget>[
            const SizedBox(height: 12),
            _FatigueBanner(state: student.fatigue!),
          ],
          // Practice grid -------------------------------------------------
          const SizedBox(height: 8),
          Text(
            'Practice',
            style: RenanceText.sectionTitle.copyWith(
              color: RenanceColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  icon: Icons.description,
                  label: 'Exams',
                  onTap: () => onGoTab(1),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.history,
                  label: 'Review Due',
                  badge: student.dueTopics > 0 ? '${student.dueTopics}' : null,
                  badgeColor: RenanceColors.emerald,
                  onTap: () => onGoTab(2),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.style,
                  label: 'Flashcards',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FlashcardsScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.menu_book,
                  label: 'Syllabus',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SyllabusScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Grow grid -----------------------------------------------------
          const SizedBox(height: 16),
          Text(
            'Grow',
            style: RenanceText.sectionTitle.copyWith(
              color: RenanceColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  icon: Icons.trending_up,
                  label: 'Progress',
                  onTap: () => onGoTab(3),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.military_tech,
                  iconColor: RenanceColors.amber,
                  label: 'Badges',
                  onTap: () => onGoTab(3),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.smart_toy,
                  iconColor: Colors.white,
                  highlight: true,
                  label: 'Tutor',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TutorEntryScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.more_horiz,
                  iconColor: RenanceColors.textSecondary,
                  muted: true,
                  label: 'More',
                  onTap: () => showMoreSheet(context, onGoTab: onGoTab),
                ),
              ),
            ],
          ),
          // Recent activity ------------------------------------------------
          const SizedBox(height: 24),
          if (firstSyncUnderway)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: LogoActivityIndicator(
                  label: 'Syncing your packs…',
                  size: 34,
                ),
              ),
            )
          else if (recent != null)
            _RecentActivityCard(
              attempt: recent,
              title: student.titleForCode(recent.code),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ReviewDetailScreen(attemptId: recent.attemptId),
                  ),
                );
              },
            )
          else
            _EmptyActivityCard(onTap: () => onGoTab(1)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ hero

/// Hero progress card, NEXT TARGET / countdown / syllabus completion bar
/// / black Continue Practice button, with the two soft corner blobs.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.student, required this.onContinue});

  final StudentController student;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final int? days = student.daysToTarget;
    final int coverage = student.coveragePct;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RenanceColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33141C2D),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: <Widget>[
            // decorative blobs
            Positioned(
              top: -64,
              right: -42,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -48,
              left: -32,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RenanceColors.violet.withValues(alpha: 0.05),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'NEXT TARGET',
                            style: RenanceText.overline,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.targetTitle,
                            style: RenanceText.displayMd,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        const Text('COUNTDOWN', style: RenanceText.overline),
                        const SizedBox(height: 4),
                        Text(
                          days == null
                              ? 'Set a year'
                              : days <= 0
                              ? 'This month'
                              : '$days Days',
                          style: RenanceText.bodyMedium.copyWith(
                            color: RenanceColors.violet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Syllabus Completion',
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 12,
                        color: RenanceColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$coverage%',
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: coverage / 100,
                    minHeight: 8,
                    backgroundColor: RenanceColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text(
                      'Continue Practice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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

// ----------------------------------------------------------------- tiles

/// 56px rounded-[18px] launcher tile with the 11px caption underneath.
class LauncherTile extends StatelessWidget {
  const LauncherTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.highlight = false,
    this.muted = false,
    this.badge,
    this.badgeColor = RenanceColors.emerald,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool highlight; // violet AI tile
  final bool muted; // More tile: tinted bg + hairline border
  final String? badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration box = highlight
        ? BoxDecoration(
            color: RenanceColors.violet,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x408B5CF6),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          )
        : muted
        ? BoxDecoration(
            color: RenanceColors.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: RenanceColors.outlineLight.withValues(alpha: 0.3),
            ),
          )
        : BoxDecoration(
            color: RenanceColors.card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14141C2D),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: box,
                child: highlight
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: <Color>[
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                        child: Icon(icon, size: 24, color: iconColor),
                      )
                    : Icon(
                        icon,
                        size: 24,
                        color: iconColor ?? RenanceColors.ink,
                      ),
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x1A000000), blurRadius: 2),
                      ],
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RenanceText.caption.copyWith(
              fontSize: 11,
              color: highlight
                  ? RenanceColors.violet
                  : RenanceColors.textSecondary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- recent activity

/// The most recent graded paper, in the design's mini-feed card.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.attempt,
    required this.title,
    required this.onTap,
  });

  final AttemptRow attempt;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int? pct = attempt.pct;
    final String verdict = switch (pct) {
      null => 'Not marked yet',
      < 50 => 'Focus needed',
      < 75 => 'Keep pushing',
      _ => 'Strong work',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RenanceColors.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14141C2D),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: RenanceColors.errorContainer,
              ),
              child: const Icon(
                Icons.science,
                size: 20,
                color: RenanceColors.error,
              ),
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
                    style: RenanceText.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pct == null ? verdict : 'Score: $pct% • $verdict',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: RenanceColors.outlineDark),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: RenanceColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            const RenanceMark(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No papers yet. Open a pack and run your first diagnostic.',
                style: RenanceText.bodySecondary,
              ),
            ),
            const Icon(Icons.chevron_right, color: RenanceColors.outlineDark),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onRetry});

  final int count;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RenanceColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.schedule, size: 18, color: RenanceColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count finished paper(s) waiting to sync',
              style: RenanceText.caption.copyWith(color: RenanceColors.ink),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('Retry now'),
          ),
        ],
      ),
    );
  }
}

class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.sync});

  final SyncController sync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RenanceColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: RenanceColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sync.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.caption.copyWith(color: RenanceColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- more sheet

/// The "All Features" bottom sheet, more_features_sheet_light, 1:1.
///
/// [onGoTab] routes feed rows back into the shell's tabs when the caller
/// lives inside the shell (launcher); null keeps notifications self-contained.
Future<void> showMoreSheet(
  BuildContext context, {
  void Function(int tab)? onGoTab,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => Container(
      decoration: const BoxDecoration(
        color: RenanceColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x1F111C2D),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: RenanceColors.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('All Features', style: RenanceText.sectionTitle),
                  const SizedBox(height: 2),
                  Text(
                    'Explore everything Renance has to offer',
                    style: RenanceText.bodySecondary.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                  children: <Widget>[
                    _MoreTile(
                      icon: Icons.search,
                      label: 'Search',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.notifications_none,
                      label: 'Notifications',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NotificationsScreen(
                              onGoTab: onGoTab,
                            ),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.download,
                      label: 'Downloads',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DownloadsScreen(),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.menu_book,
                      label: 'Lessons',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LessonsScreen(),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.wifi_off,
                      label: 'Offline Share',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Offline share ships with peer packs in an upcoming release.',
                            ),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.workspace_premium,
                      label: 'Certificates',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'The certificate wallet is designed, it lands with the exam board.',
                            ),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.cases,
                      label: 'Career Bridge',
                      soon: true,
                      soonColor: RenanceColors.violetDeep,
                      onTap: () {},
                    ),
                    _MoreTile(
                      icon: Icons.groups,
                      label: 'Patron Portal',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Patron portal opens once sponsor accounts go live.',
                            ),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.smart_toy,
                      label: 'AI Generator',
                      soon: true,
                      soonColor: RenanceColors.violet,
                      onTap: () {},
                    ),
                    _MoreTile(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _MoreTile(
                      icon: Icons.help_center,
                      label: 'Help',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showLicensePage(
                          context: context,
                          applicationName: 'Renance',
                          applicationLegalese: 'Learn. Practice. Rise.',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One square feature tile of the More sheet (Soon badge supported).
/// Gentle take-a-break banner (ROADMAP #6), appears after the student's
/// recent sittings trip the server's fatigue thresholds.
class _FatigueBanner extends StatelessWidget {
  const _FatigueBanner({required this.state});

  final FatigueState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RenanceColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RenanceColors.selectionBlue),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.self_improvement,
            size: 22,
            color: RenanceColors.violet,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Time for a short break?',
                  style: RenanceText.bodyMedium.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  state.reason.isNotEmpty
                      ? state.reason
                      : 'You have been studying a while today.',
                  style: RenanceText.caption.copyWith(
                    color: RenanceColors.textSecondary,
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

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.soon = false,
    this.soonColor = RenanceColors.violetDeep,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool soon;
  final Color soonColor;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: RenanceColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33141C2D),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: RenanceColors.surfaceContainerLow,
            ),
            child: Icon(icon, size: 20, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RenanceText.labelMono.copyWith(fontSize: 11),
          ),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Opacity(
          opacity: soon ? 0.4 : 1,
          child: InkWell(
            onTap: soon ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: tile,
          ),
        ),
        if (soon)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: soonColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
