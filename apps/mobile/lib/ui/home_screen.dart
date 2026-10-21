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
import '../learn_controller.dart';
import '../models.dart';
import '../notifications.dart';
import '../storage.dart';
import '../api_client.dart';
import 'ai_generator_screen.dart';
import 'account_screens.dart';
import 'offline_share_screen.dart';
import 'performance_screen.dart';
import 'saved_questions.dart';
import 'gpa_screen.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'courses_screen.dart';
import 'league_screen.dart';
import 'feed_screen.dart';
import 'quests_screen.dart';
import 'learn_bits.dart';
import 'msymbols.dart';
import 'study_setup_screen.dart';
import 'ai_screen.dart';
import 'ai_sparkle.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'exam_screen.dart';
import 'exam_history_screen.dart';
import 'exam_mode_setup_screen.dart';
import 'packs_screen.dart';
import 'onboarding_sheet.dart';
import 'feature_tour_sheet.dart';
import 'daily_subjects_sheet.dart';
import 'offline_offer_sheet.dart';
import 'post_utme_screens.dart';
import 'profile_screen.dart';
import 'renance_logo.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'university_home_screen.dart';
import 'tactile.dart';
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
    // The learn wallet (gems chip, freeze pill) paints from the cache
    // instantly, then refreshes quietly beside the profile.
    context.read<LearnController>()
      ..hydrate()
      ..refresh();
    await student.refresh();
    if (!mounted) return;
    // ONLY the server's own auth decision (401/403) ends the session -
    // and it must be checked BEFORE the cached-profile fallback, because
    // the fallback fills `me` from the local cache (a network failure is
    // TRANSIENT: the student stays signed in and rides the local packs).
    // The old code cleared the session on ANY error, so every offline
    // launch threw the student back to login (founder bug, 2026-09-28:
    // "anytime you close the app and open it back without data the app
    // logs out itself").
    if (student.authError) {
      await session.clear();
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    // Founder directive (2026-09-30): a saved session whose signup email
    // was never confirmed reopens on the verify screen - the study desk
    // stays closed until the mailed link is consumed (the state lives in
    // the database; closing/reopening the app never loses it).
    if (student.emailUnverified) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed('/verify',
          arguments: student.me?.email ?? '');
      return;
    }
    final MeResult? me = student.me;
    if (me == null) {
      // Offline (or a transient server hiccup) with no cache at all:
      // stay on the desk, mark bootstrap done so the shell renders, and
      // try the local-first sync below (it no-ops with no network).
      setState(() => _bootstrapped = true);
      await _startSync(student, sync);
      return;
    }
    if (!student.hasProfile) {
      _showOnboarding();
      return;
    }
    await _startSync(student, sync);
    // The one-time feature tour (founder directive, 2026-09-30): new
    // students meet every surface, Skip always in reach.
    if (!mounted) return;
    await maybeShowFeatureTour(context);
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
    await _maybeNudgeReview(student);
    await _maybeOfferOffline();
  }

  /// Review-due device notification (founder directive 2026-10-04):
  /// once a day, when spaced repetition has topics waiting, a real
  /// Android notification drops. Deduped with a dated prefs key so the
  /// phone never gets a copy every app resume.
  Future<void> _maybeNudgeReview(StudentController student) async {
    final int due = student.dueTopics;
    if (due <= 0) return;
    final SessionStore session = context.read<SessionStore>();
    final String today =
        DateTime.now().toIso8601String().substring(0, 10); // yyyy-mm-dd
    const String key = 'renance.nudge.review.v1';
    if (session.prefs.getString(key) == today) return;
    final bool granted = await RenanceNotifications.ensurePermission();
    if (!granted) return;
    await session.prefs.setString(key, today);
    await RenanceNotifications.show(
      RenanceNotifications.reviewDueId,
      'Renance · time to revise',
      '$due topic${due == 1 ? '' : 's'} due for review - keep the streak alive.',
    );
  }

  /// The offline offer (founder rule): after signing up - and any open
  /// where the shelf is still short - one sheet asks to make Renance
  /// offline (~120 MB of question packs today). A dismissed offer never
  /// nags again; Downloads stays the manual path.
  Future<void> _maybeOfferOffline() async {
    final SessionStore session = context.read<SessionStore>();
    final StudentController student = context.read<StudentController>();
    final SyncController sync = context.read<SyncController>();
    if (!await shouldOfferOffline(session, student, sync)) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflineOfferSheet(onDone: _onOfferDone),
    );
  }

  void _onOfferDone() {
    if (mounted) setState(() {});
  }


  void _showOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // The seeded handle rides along so the username step (founder
      // directive 2026-10-02: ask for the username right after signup)
      // opens pre-filled with whatever the account carries.
      final StudentController student = context.read<StudentController>();
      final bool? completed = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => OnboardingSheet(
          username: student.me?.user.username,
        ),
      );
      if (completed != true || !mounted) return;
      final SyncController sync = context.read<SyncController>();
      await student.refresh();
      await _startSync(student, sync);
    });
  }

  /// Legacy tab-index routing (the old 4-tab shell's callers): 0 home,
  /// 1 library, 2 review, anything else the Profile tab. Library and
  /// Review left the tab bar with the web's 6-tab nav, so they push.
  void _goTab(int t) {
    switch (t) {
      case 0:
        setState(() => _tab = 0);
      case 1:
        // The web's /packs twin (founder directive 2026-10-20: the old
        // black practice-library screen is gone from the codebase).
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PacksScreen(onOpenExam: _openExam),
          ),
        );
      case 2:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
        );
      default:
        setState(() => _tab = 5);
    }
  }

  /// Pull the learner wallet (gems/hearts/streak/freeze) after any learn
  /// action so the header chips stay live.
  void _refreshLearnWallet() {
    context.read<LearnController>().refresh();
  }

  void _openExam(
    BuildContext context,
    ExamMeta exam, {
    int? durationOverrideMinutes,
    bool untimed = false,
    bool shuffleQuestions = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamScreen(
          exam: exam,
          durationOverrideMinutes: durationOverrideMinutes,
          untimed: untimed,
          shuffleQuestions: shuffleQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final bool firstSyncUnderway =
        !_bootstrapped && sync.exams.isEmpty && sync.isSyncing;

    // The web's 6-tab bottom nav (bottom-nav.tsx): Home / Course /
    // Leagues / Feed / Quests / Profile. Practice and Review leave the
    // tab bar (they are launcher tiles + pushed routes, exactly the
    // web's dashboard behaviour).
    final bodies = <Widget>[
      if (student.isPostUtmeFocus)
        PostUtmeHomeTab(
          student: student,
          sync: sync,
          onGoTab: _goTab,
        )
      else if (student.isTertiaryFocus)
        UniversityHomeTab(
          student: student,
          sync: sync,
          onGoTab: _goTab,
        )
      else
        _LauncherTab(
          student: student,
          sync: sync,
          firstSyncUnderway: firstSyncUnderway,
          onOpenExam: _openExam,
          onGoTab: _goTab,
          onOnboarding: _showOnboarding,
        ),
      CoursesScreen(onNeedsResync: () => _refreshLearnWallet()),
      const LeagueScreen(),
      const FeedScreen(),
      const QuestsScreen(),
      ProfileScreen(
        onGoTab: _goTab,
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
            color: context.card,
            child: IndexedStack(index: _tab, children: bodies),
          ),
        ),
        // Brand header, the web dashboard's 56px bar: keycap + wordmark
        // left; gems chip, bell, streak and freeze pills right (founder
        // directive 2026-10-14: no search icon, no avatar).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: HomeHeader(
            streak: student.gamification?.state.currentStreak ?? 0,
            name: student.me?.profile?.fullName ?? '',
            onBrand: () => setState(() => _tab = 0),
            onAvatar: () => showAccountSheet(
              context,
              onGoTab: _goTab,
            ),
            onBackPressed: _tab == 0 ? null : () => setState(() => _tab = 0),
            // The gems chip IS the shop door now: one tap opens the full
            // shop page where diamonds buy streak freezes, hearts, boosts.
            onGems: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
            ),
            onNotifications: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => NotificationsScreen(
                  onGoTab: _goTab,
                ),
              ),
            ),
            alert: student.dueTopics > 0,
            alertCount: student.dueTopics,
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
            backgroundColor: context.pageBg,
            body: shellBody,
            bottomNavigationBar: HomeNav(
              active: _tab,
              reviewBadge: student.dueTopics,
              onTap: (int t) => setState(() => _tab = t),
            ),
            // Floating Renance AI entry (founder directive): home tab
            // only, bottom-right, the house sparkle glyph. Docked above
            // the bottom nav by the scaffold itself.
            floatingActionButton: _tab == 0
                ? AiFloatingButton(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                          builder: (_) => const AiScreen()),
                    ),
                  )
                : null,
          );
        }
        return Scaffold(
          backgroundColor: context.pageBg,
          floatingActionButton: _tab == 0
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16, right: 12),
                  child: AiFloatingButton(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                          builder: (_) => const AiScreen()),
                    ),
                  ),
                )
              : null,
          body: Row(
            children: <Widget>[
              _WideRail(
                active: _tab,
                reviewBadge: student.dueTopics,
                onTap: (int t) => setState(() => _tab = t),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.outlineVariant,
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

  static const _items = <String>['home', 'menu_book', 'trophy', 'newspaper', 'target', 'person'];
  static const _labels = <String>['Home', 'Course', 'Leagues', 'Feed', 'Quests', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      color: context.card,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 16),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.inverseChip,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                'R',
                style: TextStyle(
                  color: context.onInverseChip,
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
                  borderRadius: BorderRadius.circular(16),
                  // The desktop rail's active pill = the web SideNav's
                  // nav-pill: macaw-light face + macaw-dark ink (light
                  // tier) or the 9% macaw wash + inset macaw ring (dark
                  // tier) - never a plain cardLow wash.
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == active
                          ? (context.darkChrome
                              ? const Color(0x171CB0F6)
                              : RenanceColors.macawLight)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: i == active && context.darkChrome
                          ? <BoxShadow>[
                              // the dark tier's inset 1.5px macaw ring
                              BoxShadow(
                                color: const Color(0x731CB0F6),
                                offset: const Offset(0, 0),
                                blurRadius: 0,
                                spreadRadius: -1.5,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: <Widget>[
                        Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            MsIcon(
                              _items[i],
                              size: 24,
                              fill: i == active,
                              color: i == active
                                  ? RenanceColors.macawDark
                                  : context.textSecondary,
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
                          _labels[i],
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: i == active
                                ? RenanceColors.macawDark
                                : context.textSecondary,
                            fontWeight: i == active
                                ? FontWeight.w800
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
    this.onGems,
    this.onNotifications,
    this.alert = false,
    this.alertCount = 0,
  });

  final int streak;
  final String name;
  final VoidCallback? onBrand;
  final VoidCallback? onAvatar;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSearch;
  final VoidCallback? onGems;
  final VoidCallback? onNotifications;

  /// Emerald dot on the bell when something needs attention (review due).
  final bool alert;

  /// The numeric badge the school app paints on its bell ("53").
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    // Web header recipe (dashboard/page.tsx): `border-b-2
    // border-outline-variant bg-surface/90 backdrop-blur-xl`, a compact
    // 56px bar (h-14) with shadow-sm under the rule. The founder's
    // 2026-10-20 pass: the header must NEVER bleed into the scrolling
    // content beneath it - the crisp 2px swan rule + the soft elevation
    // shadow make the separation unmistakable.
    return Container(
      decoration: BoxDecoration(
        color: context.pageBg,
        border: Border(
          bottom: BorderSide(
            color: context.outlineVariant,
            width: 2,
          ),
        ),
        boxShadow: <BoxShadow>[
          // shadow-sm: the soft elevation under the crisp rule
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              _Tappable(onTap: onBrand, child: const _BrandMark()),
              const Spacer(),
              // The gems wallet chip (web LearnStatChips) -> the shop on
              // the profile page.
              GemStatChip(
                onTap: onGems,
              ),
              if (onNotifications != null) ...<Widget>[
                const SizedBox(width: 8),
                _HeaderIcon(
                  icon: 'notifications_none',
                  onTap: onNotifications,
                  alert: alert,
                  // Web: unread > 9 ? '9+' : unread - the badge caps at
                  // 9+ exactly like the dashboard header.
                  badge: alertCount > 0
                      ? (alertCount > 9 ? '9+' : '$alertCount')
                      : null,
                ),
              ],
              const SizedBox(width: 6),
              StreakPill(streak: streak),
              // The freeze pill renders only while freezes are held
              // (web rule) - reads the live learn wallet.
              FreezeHeaderPill(
                count: context.watch<LearnController>().freezeCount,
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

/// Black rounded square with the white R (the student's colour when a
/// seed is live), matches the web header.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The live-seed 3D keycap (the web header's RenanceMark 30).
        const RenanceKeycap(size: 30),
        const SizedBox(width: 8),
        // The wordmark is the brand green lowercase, Nunito-900, 21px -
        // the exact web header treatment (text-primary).
        Text(
          'renance',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: context.primary,
          ),
        ),
      ],
    );
  }
}

/// One round icon button in the header (search, bell) with the optional
/// numeric badge (the school app's bell count) or emerald dot.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.alert = false,
    this.badge,
  });

  final String icon;
  final VoidCallback? onTap;
  final bool alert;

  /// Numeric badge text; overrides the plain dot when present.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: onTap,
          icon: MsIcon(icon, size: 22),
          color: context.ink,
          visualDensity: VisualDensity.compact,
          tooltip: icon == 'search'
              ? 'Search'
              : 'Notifications',
        ),
        if (badge != null)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.cardLowest, width: 1.4),
              ),
              constraints:
                  const BoxConstraints(minWidth: 17, minHeight: 15),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          )
        else if (alert)
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
        color: context.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MsIcon(
            'local_fire_department',
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
        color: context.cardHigh,
        border: Border.all(color: context.outlineLight),
      ),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: context.ink,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ bottom nav

/// The exact web bottom-nav copy (components/bottom-nav.tsx): card bar
/// on a hard 2px swan top rule, six `min-h-48px` rounded-xl items, the
/// active one wrapped icon+label in the macaw-light nav-pill - the web
/// renders FILL 0 glyphs in both states, label 9.5px w800, icon 22px.
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

  static const _items = <String>[
    'home',
    'menu_book',
    'trophy',
    'newspaper',
    'target',
    'person',
  ];
  static const _labels = <String>[
    'Home',
    'Course',
    'Leagues',
    'Feed',
    'Quests',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    // Founder report 2026-10-21: on edge-to-edge phones the Android
    // gesture/3-button strip drew straight over the tab labels, so pass
    // IV reserved a hard 48dp floor (max(48, reported inset)). But on
    // phones whose window does NOT extend behind the system bar the OS
    // ends the app window ABOVE the strip and reports a 0px bottom
    // inset - the floor then paints a dead ~48dp white band under the
    // navbar (founder round-4 screenshot: white gap between the tabs
    // and the system buttons). The OS is trusted exactly now: reserve
    // what the window actually reports (the larger of padding and
    // viewPadding bottoms) and nothing more. Edge-to-edge devices
    // still clear the strip; windowed devices sit flush - no band on
    // any device.
    final double reported = MediaQuery.paddingOf(context).bottom >
            MediaQuery.viewPaddingOf(context).bottom
        ? MediaQuery.paddingOf(context).bottom
        : MediaQuery.viewPaddingOf(context).bottom;
    final double safePad = reported;
    final bool dark = context.darkChrome;
    // The dark tier's nav-pill (globals.css): a 9% macaw wash with the
    // 1.5px inset macaw ring instead of the light macaw-light face.
    final Color pillColor = dark
        ? const Color(0x171CB0F6) // macaw 9%
        : RenanceColors.macawLight;
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        border: Border(
          // the hard 2px swan top rule - the web's border-t-2
          top: BorderSide(
            color: context.outlineVariant,
            width: 2,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: safePad),
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    // The active pill wraps ICON + LABEL together
                    // (rounded-xl, gap 2px) - exactly the web's markup.
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: i == active ? pillColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: i == active && dark
                            ? <BoxShadow>[
                                // inset 1.5px macaw ring
                                BoxShadow(
                                  color: const Color(0x731CB0F6),
                                  offset: const Offset(0, 0),
                                  blurRadius: 0,
                                  spreadRadius: -1.5,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          MsIcon(
                            _items[i],
                            size: 22,
                            color: i == active
                                ? RenanceColors.macawDark
                                : (dark
                                    ? RenanceColors.darkTextSecondary
                                    : RenanceColors.hare),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _labels[i],
                            // maxLines 1 (founder report 2026-10-21): at
                            // large font scales "Leagues" wrapped into
                            // "Leagu / es" and the second line sank into
                            // the system-bar zone. One clean line, the
                            // pill grows with the scale instead.
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 9.5,
                              height: 1.0,
                              color: i == active
                                  ? RenanceColors.macawDark
                                  : (dark
                                      ? RenanceColors.darkTextSecondary
                                      : RenanceColors.hare),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
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
  final void Function(
    BuildContext context,
    ExamMeta exam, {
    int? durationOverrideMinutes,
    bool untimed,
    bool shuffleQuestions,
  }) onOpenExam;
  final ValueChanged<int> onGoTab;
  final VoidCallback onOnboarding;

  /// The Compete desk's Daily Challenge: resolves today's rotating
  /// paper for the student's focus body (GET /daily/{body}) and opens
  /// it in the player - the same sprint the web dashboard deep-links.
  Future<void> _openDaily(BuildContext context) async =>
      openDailyQuiz(context, sync);

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
          MediaQuery.paddingOf(context).top + 56 + 16,
          16,
          // the web's pb-28 (112px): content can never slide under the
          // floating AI sparkle button - no clipped cards, ever.
          112,
        ),
        children: <Widget>[
          // Hero progress card -------------------------------------------
          _HeroCard(
            student: student,
            onContinue: () {
              // Continue the student's most recent sitting when there is
              // one; otherwise route by focus - JAMBites land in the mock
              // composer, university students in the library. Never the
              // old "first manifest pack" shortcut that always opened
              // the accounting bank.
              final List<AttemptRow> recent = student.attempts;
              if (recent.isNotEmpty) {
                final String code = recent.first.code;
                ExamMeta? match;
                for (final ExamMeta e in sync.exams) {
                  if (e.code == code) {
                    match = e;
                    break;
                  }
                }
                if (match != null) {
                  onOpenExam(context, match);
                  return;
                }
              }
              if (student.isTertiaryFocus) {
                onGoTab(1); // library: university packs
              } else if (student.isJambFocus) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExamModeSetupScreen(
                      exams: sync.exams,
                      downloaded: student.downloaded,
                      onBegin: onOpenExam,
                    ),
                  ),
                );
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
          // Launcher grids - the founder's 2026-10-22 pass: every row
          // keeps four live tiles (no blanks), Arena / Review Due / Notes
          // / Tutor are gone, and each header names what sits under it.
          // -------------------------------------------------------------
          const SizedBox(height: 8),
          Text(
            'Practice & Exams',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  msIcon: 'description',
                  label: 'Exams',
                  onTap: () {
                    // Mock Exam Setup is the Exams content for JAMBites
                    // only; every other focus goes straight to the packs.
                    if (student.isJambFocus) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamModeSetupScreen(
                            exams: sync.exams,
                            downloaded: student.downloaded,
                            onBegin: onOpenExam,
                          ),
                        ),
                      );
                    } else {
                      onGoTab(1); // question packs live in the library
                    }
                  },
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'inventory_2',
                  label: 'Question Pack',
                  // The web's href for this tile is /packs - the PACK
                  // SHELF ("Every pack, ready offline"). The mobile twin
                  // is the PacksScreen (the old black library screen is
                  // retired from the codebase, founder 2026-10-20).
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PacksScreen(onOpenExam: onOpenExam),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'local_library',
                  label: 'Study',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudySetupScreen(
                        onOpenExam: onOpenExam,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'history_edu',
                  label: 'Exam History',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ExamHistoryScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Compete & Earn - the quiz and the ladder to rank on, the
          // quests that pay diamonds, and the shop that spends them.
          const SizedBox(height: 16),
          Text(
            'Compete & Earn',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  msIcon: 'event_repeat',
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Daily Quiz',
                  onTap: () => _openDaily(context),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'leaderboard',
                  label: 'Leaderboard',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaderboardScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'checklist',
                  label: 'Quests',
                  onTap: () => onGoTab(4),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'storefront',
                  label: 'Shop',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ShopScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Study & AI - the companion, the generator and the two score
          // lenses (founder 2026-10-21: performance analysis + saved
          // questions live on the grid; Notes is gone 2026-10-22).
          const SizedBox(height: 16),
          Text(
            'Study & AI',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  msIcon: 'smart_toy',
                  label: 'Renance AI',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'auto_awesome',
                  label: 'AI Generator',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiGeneratorScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'insights',
                  label: 'Performance Analysis',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PerformanceScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'bookmark',
                  label: 'Saved Questions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SavedQuestionsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Tools - the utilities that don't fit the rows above; the
          // Tutor is retired (founder 2026-10-22) and Settings now
          // lives one tap from the desk.
          const SizedBox(height: 16),
          Text(
            'Tools',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  msIcon: 'calculate',
                  label: 'GPA Calculator',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GpaScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'search',
                  label: 'Search',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SearchScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'settings',
                  label: 'Settings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'more_horiz',
                  iconColor: context.textSecondary,
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

  /// The web's hero CTA copy: a paused paper offers its seat back,
  /// JAMBites get the mock composer, everyone else starts practice.
  String get _ctaLabel {
    final AttemptRow? latest = student.latestAttempt;
    if (latest != null && latest.status == 'in_progress') {
      return 'Continue Exam';
    }
    if (student.isJambFocus) return 'Start Mock Exam';
    return 'Start Practice';
  }

  @override
  Widget build(BuildContext context) {
    final int? days = student.daysToTarget;
    final int coverage = student.coveragePct;
    // The web's .hero-card recipe (2026-10-13 tactile pass): 20px
    // squircle, 2px mixed outline, hard 4px extruded ledge + the soft
    // depth bloom + glassy inner top lip - the HeroCard twin. The
    // corner blobs (on-hero/12) stay from the founder ornament
    // directive and clip against the card's own rounded frame.
    return HeroCard(
      face: context.heroCard,
      onFace: context.onHeroCard,
      padding: const EdgeInsets.all(14),
      child: Stack(
        // Clip.none: blobs overflow to HeroCard's anti-aliased ClipRRect
        // - a hard Stack clip here sawtooths the arcs (2026-10-20).
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: -76,
            right: -48,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.onHeroCard.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -36,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.onHeroCard.withValues(alpha: 0.12),
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
                          Text(
                            'NEXT TARGET',
                            style: RenanceText.overline.copyWith(color: context.heroMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.targetTitle,
                            style: RenanceText.displayMd.copyWith(color: context.onHeroCard),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text('COUNTDOWN', style: RenanceText.overline.copyWith(color: context.heroMuted)),
                        const SizedBox(height: 4),
                        Text(
                          days == null
                              ? 'Set a year'
                              : days <= 0
                              ? 'This month'
                              : '$days Days',
                          style: RenanceText.bodyMedium.copyWith(
                            color: context.onHeroCard,
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
                        color: context.heroMuted,
                      ),
                    ),
                    Text(
                      '$coverage%',
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.onHeroCard,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // The web's .hero-progress: a 12px recessed rail with
                // the glossed fill - never a flat Material indicator.
                LearnProgressBar(
                  value: coverage / 100,
                  height: 12,
                  trackColor: context.heroTrack,
                ),
                const SizedBox(height: 16),
                TactileButton(
                  onPressed: onContinue,
                  height: 44,
                  radius: BorderRadius.circular(12),
                  fontSize: 14,
                  face: context.heroCta,
                  onFace: context.onHeroCta,
                  edge: mixTowardBlack(context.heroCta, 0.68),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const MsIcon('play_arrow', size: 18, fill: true),
                      const SizedBox(width: 6),
                      Text(_ctaLabel),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- tiles

/// 56px rounded-[18px] launcher tile with the 11px caption underneath.
class LauncherTile extends StatelessWidget {
  const LauncherTile({
    super.key,
    this.icon,
    this.msIcon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.highlight = false,
    this.muted = false,
    this.badge,
    this.badgeColor = RenanceColors.emerald,
  });

  /// Flutter Material icon (legacy focus-variant call sites).
  final IconData? icon;

  /// Material Symbols name (web parity) - takes precedence over [icon].
  final String? msIcon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool highlight; // ink AI tile
  final bool muted; // More tile: tinted bg + hairline border
  final String? badge;
  final Color badgeColor;

  Widget _glyph(BuildContext context) {
    // The web's tile glyph: text-[21px] on phones (md:text-[23px]),
    // inheriting the box's text-on-surface INK - the 2026-10-20 founder
    // screenshot pass: the glyphs read near-black on the website, never
    // the brand green (green is reserved for the inverse Tutor tile).
    if (msIcon != null) {
      return MsIcon(
        msIcon!,
        size: 21,
        wght: 600,
        color: iconColor ?? context.ink,
      );
    }
    if (icon != null) {
      return Icon(
        icon!,
        size: 21,
        // The launcher glyphs are the icon list's "black", and the seed
        // doctrine says the black becomes the student's colour. Stock
        // tiers: black on light, white on dark - unchanged. Seeded: the
        // whole grid takes the picked colour, matching how the website's
        // desk visibly re-tints per appearance.
        color: iconColor ?? context.ink,
      );
    }
    return MsIcon('circle', size: 21, color: iconColor ?? context.ink);
  }

  @override
  Widget build(BuildContext context) {
    // The web's tactile tile (dashboard LauncherTile): a 2px swan
    // outline + a hard 3px extruded ledge - the Duolingo app-icon
    // look. The inverse tile rides the seed primary with its own
    // color-mix 68% ledge; muted and plain derive the ledge from the
    // outline-variant token (the web uses the raw token, no mix).
    final Color outline = context.outlineVariant;
    // The web's exact tile geometry (dashboard LauncherTile):
    // h-12 w-12 (48px) rounded-[16px] on phones - the Duolingo
    // app-icon bubble with the 2px swan outline + hard 3px ledge.
    final BoxDecoration box = highlight
        ? BoxDecoration(
            color: context.inverseChip,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mixTowardBlack(context.inverseChip, 0.68), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: mixTowardBlack(context.inverseChip, 0.68),
                blurRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          )
        : muted
            ? BoxDecoration(
                color: context.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outline, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: outline,
                    blurRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outline, width: 2),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: outline,
                    blurRadius: 0,
                    offset: const Offset(0, 3),
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
                width: 48,
                height: 48,
                // Web parity: the tile is `flex items-center justify-center`
                // - the glyph MUST center in the box, never park top-left.
                alignment: Alignment.center,
                decoration: box,
                // The inverse tile's sheen rides ON TOP of the face but
                // UNDER the glyph (web: absolute inset-0 overlay, glyph
                // relative z-10) - a foreground gradient, not an
                // alignment wrapper that un-centers the glyph.
                foregroundDecoration: highlight
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.2),
                          ],
                        ),
                      )
                    : null,
                child: _glyph(context),
              ),
              if (badge != null)
                Positioned(
                  // Web: -top-1.5 -right-1.5 (-6px), h-[18px] min-w-[18px],
                  // bg-accent-emerald, font-mono text-[10px] font-bold.
                  top: -6,
                  right: -6,
                  child: Container(
                    height: 18,
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Color(0x1A000000), blurRadius: 2),
                      ],
                    ),
                    child: Text(
                      badge!,
                      style: RenanceText.labelMono.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          // Founder 2026-10-21 ("make the app adapt to devices and be
          // responsive on all devices"): the label SCALES DOWN to fit
          // its tile instead of ellipsizing - "Question Pack" and
          // "Review Due" stay whole on narrow phones and at the big
          // system font scales, exactly like the web desk.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // The web's tile label: text-[10.5px] font-bold,
              // text-on-surface-variant / text-primary-ink on the AI tile.
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10.5,
                height: 1.2,
                color: highlight
                    ? Color.lerp(context.primary, Colors.black, 0.28)
                    : context.textSecondary,
                fontWeight: FontWeight.w700,
              ),
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
    // Web parity: an in-progress paper shows the pause treatment and
    // "your seat is saved" copy; graded papers show Score + verdict.
    final bool inProgress = attempt.status == 'in_progress';
    final String verdict = inProgress
        ? 'Paused paper, your seat is saved, continue anytime'
        : switch (pct) {
            null => 'Not marked yet',
            < 50 => 'Score: $pct% · Focus needed',
            < 75 => 'Score: $pct% · Keep pushing',
            _ => 'Score: $pct% · Strong work',
          };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(alignment: Alignment.center,
        
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
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
            Container(alignment: Alignment.center,
              
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: inProgress
                    ? RenanceColors.amber.withValues(alpha: 0.15)
                    : context.errorContainer,
              ),
              child: MsIcon(
                inProgress ? 'pause_circle' : 'science',
                size: 20,
                color: inProgress ? RenanceColors.amber : context.error,
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
                    verdict,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RenanceText.caption.copyWith(color: context.textSecondary),
                  ),
                ],
              ),
            ),
            MsIcon('chevron_right', color: context.outlineDark),
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
          color: context.cardLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            const RenanceMark(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No papers yet. Open a pack and run your first diagnostic.',
                style: RenanceText.bodySecondary.copyWith(color: context.textSecondary),
              ),
            ),
            MsIcon('chevron_right', color: context.outlineDark),
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
    // The pending banner is mobile-native (no web twin) but MUST still
    // respect the tier: the fixed cream wash read as a glaring light box
    // on the dark canvas. Light keeps the amber tint, dark uses the
    // web's dark amber-tint token (#3A2F14).
    final bool dark = context.darkChrome;
    final Color bannerBg =
        dark ? const Color(0xFF3A2F14) : const Color(0xFFFFF7E6);
    final Color bannerInk = dark ? RenanceColors.darkTextPrimary : context.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RenanceColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const MsIcon('schedule', size: 18, color: RenanceColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count finished paper(s) waiting to sync',
              style: RenanceText.caption.copyWith(color: bannerInk),
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
        color: context.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          MsIcon(
            'cloud_off',
            size: 18,
            color: context.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sync.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RenanceText.caption.copyWith(color: context.error),
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
/// Pops the sheet then pushes the route (shared by every More tile).
VoidCallback _push(
  BuildContext sheetContext,
  BuildContext context,
  WidgetBuilder builder,
) {
  return () {
    Navigator.of(sheetContext).pop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  };
}

Future<void> showMoreSheet(
  BuildContext context, {
  void Function(int tab)? onGoTab,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => Container(
      decoration: BoxDecoration(
        color: context.pageBg,
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
                color: context.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('More', style: RenanceText.sectionTitle),
                  const SizedBox(height: 2),
                  Text(
                    'Less-used tools, your daily drivers are on the home grid.',
                    style: RenanceText.bodySecondary.copyWith(color: context.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GridView.count(
                  // The web's More sheet (dashboard/page.tsx MoreSheet):
                  // `grid grid-cols-2 gap-2` - TWO columns. The founder's
                  // 2026-10-20 pass: the old 4-column squeeze guillotined
                  // every row label into 'P...', 'S...', 'D...' ellipses.
                  // Two columns give each row the full web width, and the
                  // labels are the web's own untruncated strings.
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.2,
                  children: <Widget>[
                    // The founder's 2026-10-22 pass: every feature that
                    // lives on the home grid (performance analysis, saved
                    // questions, AI studio, settings, search, exam
                    // history, AI generator, GPA calculator) left the
                    // sheet - no doubles. Study Resources is retired.
                    // What remains is the genuinely occasional stuff.
                    _MoreTile(
                      msIcon: 'wifi_off',
                      label: 'Offline Share',
                      onTap: _push(sheetContext, context,
                          (_) => const OfflineShareScreen()),
                    ),
                    _MoreTile(
                      msIcon: 'help',
                      label: 'Help & FAQ',
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
        color: context.cardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.selectionBlue),
      ),
      child: Row(
        children: <Widget>[
          MsIcon(
            'self_improvement',
            size: 22,
            color: context.ink,
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
                    color: context.textSecondary,
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
    required this.msIcon,
    required this.label,
    required this.onTap,
  });

  final String? msIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The web's More-sheet row (dashboard/page.tsx): rounded-xl card,
    // 1px outline-variant/50 border, p-3, the 22px glyph riding LEFT of
    // a text-sm font-medium label - not the old circle+caption column.
    final Widget tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: <Widget>[
          MsIcon(msIcon ?? 'circle', size: 22, color: context.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              // The web's row label (`text-sm font-medium`) has NO
              // truncate - long names wrap. Two lines, never an ellipse.
              maxLines: 2,
              overflow: TextOverflow.fade,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.25,
                color: context.ink,
              ),
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: tile,
      ),
    );
  }
}

// ---------------------------------------------------------------- daily

/// One entry per subject bank of [body] (slug + question count), read
/// from the synced manifest codes: jamb-english-bank -> english.
/// Public so every focus home (launcher, university desk, post-UTME)
/// resolves the same combination sheet.
List<({String slug, int count})> dailySubjectsFor(
  SyncController sync,
  String body,
) {
  final RegExp hit = RegExp('^${body.toLowerCase()}-([a-z0-9-]+)-bank\$');
  final Map<String, int> seen = <String, int>{};
  for (final ExamMeta e in sync.exams) {
    final RegExpMatch? m = hit.firstMatch(e.code);
    if (m == null) continue;
    final String slug = m.group(1)!;
    if (slug.endsWith('-enrich')) continue; // enrichment forks ride the base bank
    seen[slug] = (seen[slug] ?? 0) + e.questionCount;
  }
  final List<({String slug, int count})> rows = <({String slug, int count})>[
    for (final MapEntry<String, int> e in seen.entries)
      (slug: e.key, count: e.value),
  ];
  rows.sort((a, b) => a.slug.compareTo(b.slug));
  return rows;
}

/// The Compete desk's Daily Challenge (public so every focus home can
/// fire it): resolves today's rotating paper for the student's focus
/// body (GET /daily/{body}) and opens it in the player - the same
/// sprint the web dashboard deep-links.
Future<void> openDailyQuiz(BuildContext context, SyncController sync) async {
  final ApiClient api = context.read<ApiClient>();
  final StudentController student = context.read<StudentController>();
  final String body = switch (student.me?.profile?.exams.firstOrNull) {
    'WAEC' => 'WAEC',
    'NECO' => 'NECO',
    'University Modules' => 'University Modules',
    _ => 'JAMB',
  };
  // Founder rule: the first daily tap asks for the subject combination
  // (bodies with per-subject banks only). The combination is stored on
  // the profile, and every daily sprint afterwards draws ONLY those
  // subjects - the server composes the paper, the same one the web
  // plays.
  final Profile? dailyProfile = student.me?.profile;
  if (kComboBodies.contains(body) &&
      (dailyProfile == null || dailyProfile.subjects.isEmpty)) {
    final List<({String slug, int count})> rows =
        dailySubjectsFor(sync, body);
    if (!context.mounted) return;
    final List<String>? picked = await showDailySubjectsSheet(
      context,
      api: api,
      body: body,
      subjects: rows,
    );
    if (picked == null || picked.isEmpty) return; // dismissed, no sprint
    // The combination now lives on the profile server-side; refresh so
    // the local copy carries it and the gate never re-asks.
    await student.refresh();
  }
  final DailyInfo daily;
  try {
    daily = await api.daily(body);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No daily challenge: ${e.message}')),
    );
    return;
  } on NetworkException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message)),
    );
    return;
  }
  // Prefer the manifest meta (sha + title) when the rotating code is
  // registered; otherwise an empty sha fetches the bundle live.
  ExamMeta meta = ExamMeta(
    code: daily.code,
    title: 'Daily Quiz',
    questionCount: daily.questionCount,
    totalMarks: daily.questionCount,
    bundleSha256: '',
    durationMinutes: 10,
    body: daily.body,
  );
  for (final ExamMeta e in sync.exams) {
    if (e.code == daily.code) {
      meta = e;
      break;
    }
  }
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExamScreen(exam: meta, daily: true),
    ),
  );
}
