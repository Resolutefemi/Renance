/// Post UTME desk, Renance's fourth focus entity beside JAMB, WAEC,
/// NECO and the School Desk (founder directive).
///
/// [PostUtmeHomeTab] renders instead of the launcher when the student's
/// focus is POST-UTME: the school hero card (the picked school, the
/// Pick School button when nothing is picked), the general practice
/// banks and the school's own prep packs. [PostUtmePickerScreen] lists
/// the schools with banked Post-UTME questions; schools without them
/// wait in the unavailable list. The pick lives under its own key
/// (kPostUtmeSchoolPickKey), separate from the School Desk pick.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import '../storage.dart';
import 'ai_generator_screen.dart';
import 'ai_screen.dart';
import 'about_screen.dart';
import 'exam_history_screen.dart';
import 'exam_screen.dart';
import 'gpa_screen.dart';
import 'home_screen.dart' show LauncherTile, openDailyQuiz;
import 'leaderboard_screen.dart';
import 'msymbols.dart';
import 'packs_screen.dart';
import 'performance_screen.dart';
import 'renance_logo.dart';
import 'saved_questions.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'study_setup_screen.dart';
import 'tactile.dart';
import 'theme.dart';
import 'university_screens.dart';

class PostUtmeHomeTab extends StatelessWidget {
  const PostUtmeHomeTab({
    super.key,
    required this.student,
    required this.sync,
    required this.onGoTab,
  });

  final StudentController student;
  final SyncController sync;
  final ValueChanged<int> onGoTab;

  /// The stored Post UTME school pick, when it still has banked packs.
  String? _schoolSlug(BuildContext context) {
    final Map<String, List<UniCourse>> pq = postUtmeCourses(sync.exams);
    final String? stored =
        context.read<SessionStore>().prefs.getString(kPostUtmeSchoolPickKey);
    if (stored != null && pq.containsKey(stored)) return stored;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool syncing = sync.isSyncing;
    final Map<String, List<UniCourse>> pq = postUtmeCourses(sync.exams);
    final List<ExamMeta> general = <ExamMeta>[
      for (final ExamMeta e in sync.exams)
        if (e.body == 'POST-UTME') e,
    ];
    final String? slug = _schoolSlug(context);
    final List<UniCourse> own = slug != null
        ? (pq[slug] ?? const <UniCourse>[])
        : const <UniCourse>[];
    final (String short, String full) = slug != null
        ? (kUniversitySchools[slug]?.$1 ?? slug.toUpperCase(),
            kUniversitySchools[slug]?.$2 ?? slug)
        : ('Post UTME', 'Pick your school');

    return RefreshIndicator(
      onRefresh: student.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top +74,
          16,
          24,
        ),
        children: <Widget>[
          // Desk hero card ------------------------------------------------
          // The web's .hero-card recipe (same as every focus desk):
          // 20px squircle, 2px mixed outline, 4px extruded ledge, soft
          // depth bloom, glassy top lip - plus the founder's corner
          // blobs (on-hero/12, 2026-10-11 directive).
          HeroCard(
            face: context.heroCard,
            onFace: context.onHeroCard,
            padding: const EdgeInsets.all(14),
            child: Stack(
              // Clip.none: blobs clip once at HeroCard's anti-aliased
              // ClipRRect - a hard Stack clip sawtooths the arcs.
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('POST UTME DESK',
                        style: RenanceText.labelMono.copyWith(
                          fontSize: 11,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                          color: context.heroMuted,
                        )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.heroTrack,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          MsIcon(
                              syncing ? 'sync' : 'check_circle',
                              size: 14,
                              fill: !syncing,
                              color: context.onHeroCard),
                          const SizedBox(width: 4),
                          Text(
                            syncing ? 'Syncing' : 'Synced',
                            style: RenanceText.labelMono.copyWith(
                                fontSize: 11, color: context.onHeroCard),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(full, style: RenanceText.displayMd.copyWith(color: context.onHeroCard)),
                const SizedBox(height: 2),
                Text(
                  own.isNotEmpty
                      ? '$short · ${own.length} school prep packs · ${general.length} general banks'
                      : '${pq.length} schools banked · ${general.length} general practice banks',
                  style: RenanceText.bodyMedium.copyWith(color: context.heroMuted),
                ),
                const SizedBox(height: 16),
                // The Pick School button, the same seat the School Desk
                // keeps it in. No Change School button: the pick sticks.
                TactileButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PostUtmePickerScreen(exams: sync.exams),
                      ),
                    );
                  },
                  height: 44,
                  radius: BorderRadius.circular(10),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  face: context.heroCta,
                  onFace: context.onHeroCta,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const MsIcon('school', size: 18, fill: true),
                      const SizedBox(width: 8),
                      Text(
                        slug != null ? 'Open past questions' : 'Pick School',
                      ),
                    ],
                  ),
                ),
              ],
            ),
                ],
              ),
          ),
          const SizedBox(height: 16),
          // Practice grid - the web's exact four (dashboard/page.tsx
          // PostUtmeHome): Past Questions / Study / Review Due /
          // Question Pack. The old three-tile row dropped the desk's
          // own Past Questions tile and pointed Packs at the course hub.
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
                  label: 'Past Questions',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PostUtmePickerScreen(exams: sync.exams),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'local_library',
                  label: 'Study',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const StudySetupScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'history_edu',
                  label: 'Exam History',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ExamHistoryScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'inventory_2',
                  label: 'Question Pack',
                  // The web's href is /packs - the pack shelf (the mobile
                  // twin is PacksScreen; the old black library screen is
                  // retired, founder 2026-10-20).
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PacksScreen(
                        onOpenExam: (BuildContext context, ExamMeta exam,
                                {int? durationOverrideMinutes,
                                bool untimed = false,
                                bool shuffleQuestions = false}) =>
                            _openExam(context, exam),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Compete & Earn - the founder's 2026-10-22 pass: Arena is
          // retired; the daily quiz, the ladder, the gem quests and the
          // diamond shop fill the row, no blanks.
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
                  onTap: () => openDailyQuiz(context, sync),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'leaderboard',
                  label: 'Leaderboard',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const LeaderboardScreen()),
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
                        builder: (_) => const ShopScreen()),
                  ),
                ),
              ),
            ],
          ),
          // Study & AI - the same companion row the main desk carries.
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
                        builder: (_) => const AiScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'auto_awesome',
                  label: 'AI Generator',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AiGeneratorScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'insights',
                  label: 'Performance Analysis',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PerformanceScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'bookmark',
                  label: 'Saved Questions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SavedQuestionsScreen()),
                  ),
                ),
              ),
            ],
          ),
          // School prep packs -----------------------------------------------
          if (own.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              '$short prep packs',
              style: RenanceText.sectionTitle.copyWith(
                color: context.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            for (final UniCourse c in own.take(6))
              _PostUtmePackTile(
                exam: c.exam,
                label: c.label,
                downloaded: student.downloaded.contains(c.exam.code),
                onOpen: () => showPracticeSheet(context, c),
                onDownload: () => sync.downloadExam(c.exam),
              ),
          ],
          // General banks ----------------------------------------------------
          const SizedBox(height: 16),
          Text(
            'General practice banks',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final ExamMeta e in general)
            _PostUtmePackTile(
              exam: e,
              label: e.title,
              downloaded: student.downloaded.contains(e.code),
              onOpen: () => _openExam(context, e),
              onDownload: () => sync.downloadExam(e),
            ),
          // Tools - search, settings and the About page; Notes and the
          // Tutor are retired (founder 2026-10-22).
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
                        builder: (_) => const GpaScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'search',
                  label: 'Search',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SearchScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'settings',
                  label: 'Settings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'info',
                  label: 'About Renance',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openExam(BuildContext context, ExamMeta exam) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamScreen(exam: exam),
      ),
    );
  }
}

// ----------------------------------------------------------------- picker

/// Post UTME school picker: the schools with banked Post-UTME past
/// questions open the desk; the rest wait in the unavailable list.
class PostUtmePickerScreen extends StatelessWidget {
  const PostUtmePickerScreen({super.key, required this.exams});

  final List<ExamMeta> exams;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<UniCourse>> pq = postUtmeCourses(exams);
    final List<String> available = pq.keys.toList()..sort();
    final Set<String> bankedSet = pq.keys.toSet();
    final List<String> unavailable = kUniversitySchools.keys
        .where((String s) => !bankedSet.contains(s))
        .toList()
      ..sort();
    final String? picked =
        context.read<SessionStore>().prefs.getString(kPostUtmeSchoolPickKey);

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
                  child: Text('Post UTME Desk',
                      style: RenanceText.displayLg),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${available.length} schools bank Post-UTME past questions. '
                    'Pick the school you are writing for.',
                    style: RenanceText.bodyBase
                        .copyWith(color: context.textSecondary),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: available.length + unavailable.length,
                    itemBuilder: (BuildContext context, int i) {
                      if (i < available.length) {
                        final String slug = available[i];
                        final (String short, String full) =
                            kUniversitySchools[slug] ?? (slug.toUpperCase(), slug);
                        final List<UniCourse> packs = pq[slug]!;
                        return _PostUtmePickerCard(
                          short: short,
                          full: full,
                          trailing: '${packs.length} packs',
                          picked: slug == picked,
                          onTap: () async {
                            await context
                                .read<SessionStore>()
                                .prefs
                                .setString(kPostUtmeSchoolPickKey, slug);
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PostUtmePacksScreen(
                                  schoolSlug: slug,
                                  packs: packs,
                                ),
                              ),
                            );
                          },
                        );
                      }
                      final String slug = unavailable[i - available.length];
                      final (String short, String full) =
                          kUniversitySchools[slug] ?? (slug.toUpperCase(), slug);
                      return _PostUtmePickerCard(
                        short: short,
                        full: full,
                        trailing: 'Not banked yet',
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

class _PostUtmePickerCard extends StatelessWidget {
  const _PostUtmePickerCard({
    required this.short,
    required this.full,
    required this.trailing,
    required this.onTap,
    this.locked = false,
    this.picked = false,
  });

  final String short;
  final String full;
  final String trailing;
  final VoidCallback? onTap;
  final bool locked;
  final bool picked;

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
              style:
                  RenanceText.caption.copyWith(color: context.textSecondary)),
          trailing: Text(trailing,
              style:
                  RenanceText.labelMono.copyWith(fontSize: 11, color: picked ? context.ink : context.textSecondary)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ packs

/// One school's Post-UTME prep packs: the desk behind the picker tap.
class PostUtmePacksScreen extends StatelessWidget {
  const PostUtmePacksScreen({
    super.key,
    required this.schoolSlug,
    required this.packs,
  });

  final String schoolSlug;
  final List<UniCourse> packs;

  @override
  Widget build(BuildContext context) {
    final StudentController student = context.watch<StudentController>();
    final SyncController sync = context.watch<SyncController>();
    final (String short, String full) =
        kUniversitySchools[schoolSlug] ?? (schoolSlug.toUpperCase(), schoolSlug);

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
                  child: Text('$short Post-UTME',
                      style: RenanceText.displayLg),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '$full · ${packs.length} prep packs of real past questions.',
                    style: RenanceText.bodyBase
                        .copyWith(color: context.textSecondary),
                  ),
                ),
                Expanded(
                  child: packs.isEmpty
                      ? const Center(
                          child: LogoActivityIndicator(
                              label: 'Loading packs…', size: 34))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: <Widget>[
                            for (final UniCourse c in packs)
                              _PostUtmePackTile(
                                exam: c.exam,
                                label: c.label,
                                downloaded:
                                    student.downloaded.contains(c.exam.code),
                                onOpen: () => showPracticeSheet(context, c),
                                onDownload: () => sync.downloadExam(c.exam),
                              ),
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

// ------------------------------------------------------------------- tile

class _PostUtmePackTile extends StatelessWidget {
  const _PostUtmePackTile({
    required this.exam,
    required this.label,
    required this.downloaded,
    required this.onOpen,
    required this.onDownload,
  });

  final ExamMeta exam;
  final String label;
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
            child: MsIcon('history_edu', size: 22, color: context.ink),
          ),
          title: Text(label, style: RenanceText.bodyMedium),
          subtitle: Text(
            '${exam.questionCount} questions'
            '${downloaded ? ' · on device' : ''}',
            style: RenanceText.caption.copyWith(color: context.textSecondary),
          ),
          trailing: downloaded
              ? const MsIcon('check_circle',
                  size: 20, fill: true, color: RenanceColors.emerald)
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
