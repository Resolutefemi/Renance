/// University home, the Stitch university_home_dashboard_light screen,
/// 1:1. Rendered by the shell instead of the JAMB launcher when the
/// student's learning focus is a tertiary institution: the "In Progress"
/// course hero card (COS101, semester progress, resume lecture notes),
/// the Active Courses chips row and the university-flavoured Practice /
/// Grow grids (Quizzes, Review, Cards, Outline / CGPA, Badges, Tutor,
/// Arena). The Mock Exam Setup never appears here: it is a JAMBite
/// product only.
library;

import 'package:flutter/material.dart';

import '../controllers.dart';
import 'arena_lobby_screen.dart';
import 'flashcards_screen.dart';
import 'home_screen.dart' show LauncherTile;
import 'lessons_screen.dart';
import 'syllabus_screen.dart';
import 'theme.dart';
import 'tutor_screen.dart';

class UniversityHomeTab extends StatelessWidget {
  const UniversityHomeTab({
    super.key,
    required this.student,
    required this.sync,
    required this.onGoTab,
  });

  final StudentController student;
  final SyncController sync;
  final ValueChanged<int> onGoTab;

  @override
  Widget build(BuildContext context) {
    final bool syncing = sync.isSyncing;

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
          // Active course hero card --------------------------------------
          _CourseHeroCard(syncing: syncing, onResume: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LessonsScreen()),
            );
          }),
          // Course chips row ----------------------------------------------
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Active Courses', style: RenanceText.sectionTitle.copyWith(fontSize: 16)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SyllabusScreen()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('View all',
                    style: RenanceText.caption.copyWith(
                        fontSize: 13, color: context.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: <Widget>[
                _CourseChip('COS101', false),
                const SizedBox(width: 8),
                _CourseChip('MTH102', false),
                const SizedBox(width: 8),
                _CourseChip('PHY101', true),
                const SizedBox(width: 8),
                _CourseChip('GST101', false),
              ],
            ),
          ),
          // Practice grid ---------------------------------------------------
          const SizedBox(height: 16),
          Text(
            'Practice',
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
                  icon: Icons.quiz,
                  label: 'Quizzes',
                  onTap: () => onGoTab(1), // question packs
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.history_edu,
                  label: 'Review',
                  badge: student.dueTopics > 0 ? '${student.dueTopics}' : null,
                  badgeColor: RenanceColors.emerald,
                  onTap: () => onGoTab(2),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.style,
                  label: 'Cards',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const FlashcardsScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.library_books,
                  label: 'Outline',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SyllabusScreen()),
                  ),
                ),
              ),
            ],
          ),
          // Grow grid -------------------------------------------------------
          const SizedBox(height: 16),
          Text(
            'Grow',
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
                  icon: Icons.timeline,
                  label: 'CGPA',
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
                        builder: (_) => const TutorEntryScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.sports_esports,
                  label: 'Arena',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ArenaLobbyScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- hero

class _CourseHeroCard extends StatelessWidget {
  const _CourseHeroCard({required this.syncing, required this.onResume});

  final bool syncing;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.heroCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14141C2D),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'IN PROGRESS',
                style: RenanceText.labelMono.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                  color: context.heroMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.darkChrome
                      ? RenanceColors.darkSurface
                      : context.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(syncing ? Icons.sync : Icons.check_circle,
                        size: 14, color: context.onHeroCard),
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
          Text('COS101',
              style: RenanceText.displayMd.copyWith(color: context.onHeroCard)),
          const SizedBox(height: 2),
          Text(
            'Introduction to Computing',
            style: RenanceText.bodyMedium.copyWith(color: context.heroMuted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('Semester Progress',
                  style: RenanceText.caption.copyWith(
                      fontSize: 13, color: context.heroMuted)),
              Text('Week 6 of 12',
                  style: RenanceText.labelMono.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.onHeroCard)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.5,
              minHeight: 8,
              backgroundColor: context.heroTrack,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.darkChrome ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResume,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor:
                    context.darkChrome ? Colors.white : null,
                foregroundColor:
                    context.darkChrome ? RenanceColors.ink : null,
              ),
              icon: const Icon(Icons.play_circle, size: 20),
              label: const Text(
                'Resume lecture notes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? context.selectionBlue
            : context.cardLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: selected
            ? RenanceText.bodyMedium.copyWith(fontSize: 14)
            : RenanceText.bodyBase.copyWith(
                fontSize: 14, color: context.textSecondary),
      ),
    );
  }
}
