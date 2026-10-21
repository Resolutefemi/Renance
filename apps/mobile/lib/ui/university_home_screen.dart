/// University home, the Stitch university_home_dashboard_light screen,
/// 1:1, renamed the School Desk (founder rename). Rendered by the shell
/// instead of the JAMB launcher when the student's learning focus is a
/// tertiary institution: the school hero card (name, course count, the
/// Pick School button when nothing is picked yet), the Active Courses
/// chips row and the Practice / Grow grids. The school pick is stored
/// once (the founder rule): after that only the profile edit changes it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../storage.dart';
import 'exam_history_screen.dart';
import 'gpa_screen.dart';
import 'home_screen.dart' show LauncherTile, openDailyQuiz, showMoreSheet;
import 'leaderboard_screen.dart';
import 'msymbols.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'study_setup_screen.dart';
import 'tactile.dart';
import 'theme.dart';
import 'university_screens.dart';

class UniversityHomeTab extends StatelessWidget {
  /// "1668" -> "1,668" (the web's toLocaleString('en-US')).
  static String _formatThousands(int n) {
    final String raw = n.toString();
    final StringBuffer out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
      out.write(raw[i]);
    }
    return out.toString();
  }

  const UniversityHomeTab({
    super.key,
    required this.student,
    required this.sync,
    required this.onGoTab,
  });

  final StudentController student;
  final SyncController sync;
  final ValueChanged<int> onGoTab;

  /// The student's school: the stored pick first, then the profile
  /// institution match against the banked schools. Null = nothing picked
  /// yet, the desk shows its Pick School button.
  String? _schoolSlug(BuildContext context) {
    final Set<String> banked =
        universityCourses(sync.exams).keys.toSet();
    final String? stored = context
        .read<SessionStore>()
        .prefs
        .getString(kSchoolPickKey);
    if (stored != null && banked.contains(stored)) return stored;
    final String institution =
        student.me?.profile?.institution.trim().toLowerCase() ?? '';
    if (institution.isEmpty) return null;
    for (final MapEntry<String, (String, String)> e
        in kUniversitySchools.entries) {
      if (!banked.contains(e.key)) continue;
      final (String short, String full) = e.value;
      if (institution == e.key ||
          institution == short.toLowerCase() ||
          institution.contains(full.toLowerCase()) ||
          full.toLowerCase().contains(institution)) {
        return e.key;
      }
    }
    return null;
  }

  void _openDesk(BuildContext context) {
    // Founder directive (2026-10-16, the School Desk overhaul - web
    // parity): the tertiary student's primary CTA opens MY SEMESTER,
    // the gamified courses desk (courses tab), exactly like the web's
    // "Open your semester desk" -> /courses. The old school desk and
    // the picker stay reachable from the Active Courses strip.
    final String? slug = _schoolSlug(context);
    if (slug != null) {
      onGoTab(1); // the Courses tab - the My Semester dashboard
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UniversityPickerScreen(exams: sync.exams),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool syncing = sync.isSyncing;
    final Map<String, List<UniCourse>> schools = universityCourses(sync.exams);
    final String? slug = _schoolSlug(context);
    final List<UniCourse> schoolCourses =
        slug != null ? (schools[slug] ?? const <UniCourse>[]) : const <UniCourse>[];
    final (String short, String full) = slug != null
        ? (kUniversitySchools[slug]!.$1, kUniversitySchools[slug]!.$2)
        : ('School Desk', '${schools.length} banked schools');
    // The web's hero subtitle: "X courses · Y questions" - the LIVE
    // bank counts for the picked school.
    final int questionCount = schoolCourses.fold<int>(
        0, (int n, UniCourse c) => n + c.exam.questionCount);

    return RefreshIndicator(
      onRefresh: student.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top +74,
          16,
          // the web's pb-28: clear of the AI sparkle button
          112,
        ),
        children: <Widget>[
          // School hero card ----------------------------------------------
          _SchoolHeroCard(
            syncing: syncing,
            heroShort: short,
            heroName: slug != null ? full : 'Pick your school',
            subtitle: slug != null && schoolCourses.isNotEmpty
                ? '${schoolCourses.length} courses'
                  ' · ${_formatThousands(questionCount)} questions'
                : 'Course content lands as it is harvested',
            onOpen: () => _openDesk(context),
          ),
          // Course chips row (web: the whole section hides when the
          // picked school has no courses - header, link and chips all go).
          if (schoolCourses.isNotEmpty) ...<Widget>[
            // gap-4 + mt-1 - the web's exact 20px under the hero card.
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // web: text-sm font-semibold text-on-surface (14px w600)
                Text('Active Courses',
                    style: RenanceText.sectionTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                // web: Link "View all" p-2 text-[13px]
                // text-on-surface-variant -> /university/<slug> - the
                // school's own course-bank desk. Every student gets it.
                TextButton(
                  onPressed: () =>
                      _openSchoolBanks(context, slug, schoolCourses),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('View all',
                      style: RenanceText.caption.copyWith(
                          fontSize: 13, color: context.textSecondary)),
                ),
              ],
            ),
            // web: pt-1.5 - the 6px gap between header and chips.
            const SizedBox(height: 6),
            // Founder report 2026-10-21 ("it should be like the way it
            // was before"): back to the ORIGINAL one-row strip - the
            // wrapped chip cloud stacked 4 tall rows and pushed Study
            // below the fold. The strip scrolls sideways, exactly as
            // the web's overflow-x row (courses.slice(0, 10), gap-1.5).
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  // web: courses.slice(0, 10), gap-1.5 (6px).
                  for (final UniCourse c in schoolCourses.take(10))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _CourseChip(c.label, false),
                    ),
                ],
              ),
            ),
          ],
          // Study grid - the web's university desk icons
          // gap-4 + mt-2 - the web's 24px under the chips strip.
          const SizedBox(height: 24),
          Text(
            'Study',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  msIcon: 'assignment',
                  label: 'Courses',
                  // The web's university Courses tile passes NO badge -
                  // the count chip is the JAMB desk's Review-Due
                  // treatment only. The green "4" bubble is gone.
                  onTap: () => onGoTab(1),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'fact_check',
                  label: 'Quizzes',
                  // the school's own course banks (web /university/<slug>)
                  onTap: () => _openSchoolBanks(context, slug, schoolCourses),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'local_library',
                  label: 'Study',
                  // founder directive (2026-10-04): the university desk's
                  // Study tile opens the SCHOOL past-questions setup,
                  // never the JAMB default.
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const StudySetupScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  msIcon: 'rate_review',
                  label: 'Review',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ReviewScreen()),
                  ),
                ),
              ),
            ],
          ),
          // Compete & Earn - the founder's 2026-10-22 pass: Arena is
          // retired, the row now carries the daily quiz, the ladder,
          // the gem quests and the shop that spends the diamonds.
          const SizedBox(height: 32),
          Text(
            'Compete & Earn',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
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
          // Tools - CGPA, exam history, search, settings and the More
          // sheet; Notes and Tutor retired (founder 2026-10-22).
          const SizedBox(height: 32),
          Text(
            'Tools',
            style: RenanceText.sectionTitle.copyWith(
              color: context.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: LauncherTile(
                  msIcon: 'calculate',
                  label: 'CGPA',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const GpaScreen()),
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
                  msIcon: 'more_horiz',
                  iconColor: context.textSecondary,
                  muted: true,
                  label: 'More',
                  onTap: () => showMoreSheet(context, onGoTab: onGoTab),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The web's Quizzes tile: the picked school's own course-bank desk
  /// (/university/SLUG). Nothing picked yet falls back to the picker.
  void _openSchoolBanks(
      BuildContext context, String? slug, List<UniCourse> courses) {
    if (slug == null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UniversityPickerScreen(exams: sync.exams),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            UniversityDeskScreen(schoolSlug: slug, courses: courses),
      ),
    );
  }
}

// ----------------------------------------------------------------- hero

/// The school hero card - the founder's 2026-10-20 screenshot recipe
/// (the web dashboard's UniversityHome hero, apps/web/app/dashboard/
/// page.tsx): the .hero-card 3D ledge, the "School Desk" mono eyebrow,
/// the SOLID school badge (charcoal pill, white ink - the screenshot's
/// badge reads as a filled chip, not the old /15 translucent one), the
/// big institution title, the live "X courses · Y questions" line and
/// the tall full-width "Open your semester desk" CTA. The corner blobs
/// run at the screenshot's visible strength - big, clearly present.
class _SchoolHeroCard extends StatelessWidget {
  const _SchoolHeroCard({
    required this.syncing,
    required this.heroShort,
    required this.heroName,
    required this.subtitle,
    required this.onOpen,
  });

  final bool syncing;
  final String heroShort;
  final String heroName;
  final String subtitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final Color onHero = context.onHeroCard;
    return HeroCard(
      face: context.heroCard,
      onFace: onHero,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Stack(
        // Clip.none: the corner blobs MUST overflow this Stack's bounds
        // and be clipped once by HeroCard's anti-aliased ClipRRect - a
        // hard Stack clip here sawtooths every arc that crosses it.
        clipBehavior: Clip.none,
        children: <Widget>[
          // corner blobs - the target screenshot's ornaments, measured
          // off it: a big quarter circle behind the badge corner (arc
          // dips to ~48% card height, ~85px of it visible leftward)
          // and a large blob whose mass shows BELOW the CTA's bottom
          // left, with a small notch peeking above the button's left
          // end. Offsets live in the padded content space (padL 18,
          // padT 16) and pin to their corners on any card width.
          Positioned(
            top: -95,
            right: -103,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onHero.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: -83,
            left: -87,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onHero.withValues(alpha: 0.14),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // the web's eyebrow: font-mono 10px w800 uppercase
                  // tracking-[0.2em] hero-muted
                  Text(
                    'SCHOOL DESK',
                    style: RenanceText.labelMono.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: context.heroMuted,
                    ),
                  ),
                  // the screenshot's badge: SOLID ink pill - white icon
                  // + short code on charcoal (light tier), inverted on
                  // the dark tiers the same way the hero face inverts
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: onHero,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        MsIcon('school',
                            size: 15, color: context.heroCard, fill: true),
                        const SizedBox(width: 5),
                        Text(
                          syncing ? 'SYNCING' : heroShort,
                          style: RenanceText.labelMono.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.heroCard,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // title: text-xl font-bold tracking-tight, screenshot scale
              Text(
                heroName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1.15,
                  color: Color(0xFF3C3C46),
                ).copyWith(color: onHero),
              ),
              const SizedBox(height: 4),
              // subtitle: the live counts line, screenshot scale
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.heroMuted,
                ),
              ),
              const SizedBox(height: 16),
              // CTA: the screenshot's big full-width desk button - 52px
              // tall, 16px extrabold label, 21px school icon, 13px
              // radius, the 4px darker-green tactile edge underneath.
              TactileButton(
                height: 52,
                radius: BorderRadius.circular(13),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                // The founder's 2026-10-20 colour fix: the desk CTA wears
                // the SAME token as the logo keycap and the sparkle FAB -
                // the vivid Renance green (#10da11) in stock tiers, the
                // seed colour when the student picked one - never a
                // derived/darker variant.
                face: context.primary,
                onFace: context.onPrimary,
                edge: mixTowardBlack(context.primary, 0.68),
                onPressed: onOpen,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const MsIcon('school', size: 21, fill: true),
                    const SizedBox(width: 9),
                    // The web CTA label is static - "Open your semester
                    // desk" even when no school is picked yet (the
                    // picker opens behind it).
                    const Text('Open your semester desk'),
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

// ----------------------------------------------------------------- chips

class _CourseChip extends StatelessWidget {
  const _CourseChip(this.label, this.selected);

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // The web's chip: rounded-full border-2 border-outline-variant/70
    // bg-surface-container-low px-3.5 text-[12px] font-semibold
    // on-surface-variant, 1px press sink.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? context.selectionBlue
            : context.cardLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.outlineVariant.withValues(alpha: 0.70),
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? context.ink : context.textSecondary,
        ),
      ),
    );
  }
}
