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
import 'exam_screen.dart';
import 'flashcards_screen.dart';
import 'home_screen.dart' show LauncherTile;
import 'renance_logo.dart';
import 'study_setup_screen.dart';
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
  String? get _schoolSlug {
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
    final String? slug = _schoolSlug;
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
          MediaQuery.paddingOf(context).top + 64 + 16,
          16,
          24,
        ),
        children: <Widget>[
          // Desk hero card ------------------------------------------------
          Container(
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
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PostUtmePickerScreen(exams: sync.exams),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: context.darkChrome ? Colors.white : null,
                      foregroundColor:
                          context.darkChrome ? RenanceColors.ink : null,
                    ),
                    icon: const Icon(Icons.school, size: 20),
                    label: Text(
                      slug != null ? 'Open past questions' : 'Pick School',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
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
                  icon: Icons.history_edu,
                  label: 'Study',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const StudySetupScreen()),
                  ),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.inventory_2,
                  label: 'Packs',
                  onTap: () => onGoTab(1),
                ),
              ),
              Expanded(
                child: LauncherTile(
                  icon: Icons.history,
                  label: 'Review',
                  badge:
                      student.dueTopics > 0 ? '${student.dueTopics}' : null,
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
            style:
                RenanceText.caption.copyWith(color: context.textSecondary)),
        trailing: Text(trailing,
            style:
                RenanceText.labelMono.copyWith(fontSize: 11, color: picked ? context.ink : context.textSecondary)),
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
          child: Icon(Icons.history_edu, size: 22, color: context.ink),
        ),
        title: Text(label, style: RenanceText.bodyMedium),
        subtitle: Text(
          '${exam.questionCount} questions'
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
