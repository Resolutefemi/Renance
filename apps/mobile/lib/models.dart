/// Data models mirroring the Go study-api contract (apps/study-api).
/// All parsing is defensive: the API may omit optional fields.
library;

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.profileCompleted,
  });

  final String id;
  final String username;
  final bool profileCompleted;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] ?? '') as String,
        username: (j['username'] ?? '') as String,
        profileCompleted: (j['profileCompleted'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'username': username,
        'profileCompleted': profileCompleted,
      };
}

class Profile {
  const Profile({
    required this.fullName,
    required this.institution,
    required this.gradeLevel,
    required this.exams,
    required this.completed,
    this.targetYear,
  });

  final String fullName;
  final String institution;
  final String gradeLevel;
  final List<String> exams;
  final bool completed;

  /// Exam year picked at onboarding (drives the hero countdown).
  final int? targetYear;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        fullName: (j['fullName'] ?? '') as String,
        institution: (j['institution'] ?? '') as String,
        gradeLevel: (j['gradeLevel'] ?? '') as String,
        exams: ((j['exams'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        targetYear: j['targetYear'] as int?,
        completed: (j['completed'] ?? false) as bool,
      );
}

class MeResult {
  const MeResult({required this.user, this.profile});
  final AppUser user;
  final Profile? profile;

  factory MeResult.fromJson(Map<String, dynamic> j) => MeResult(
        user: AppUser.fromJson((j['user'] as Map).cast<String, dynamic>()),
        profile: j['profile'] == null
            ? null
            : Profile.fromJson((j['profile'] as Map).cast<String, dynamic>()),
      );
}

class AuthTokens {
  const AuthTokens({required this.token, required this.user});
  final String token;
  final AppUser user;
}

class ExamMeta {
  const ExamMeta({
    required this.code,
    required this.title,
    required this.questionCount,
    required this.totalMarks,
    required this.bundleSha256,
    this.durationMinutes,
    this.category = '',
    this.body = '',
    this.sizeBytes = 0,
  });

  final String code;
  final String title;
  final int questionCount;
  final int totalMarks;
  final int? durationMinutes;
  final String category; // secondary | university | ...
  final String body; // JAMB | WAEC | NECO | University Modules
  final String bundleSha256;
  final int sizeBytes;

  factory ExamMeta.fromJson(Map<String, dynamic> j) => ExamMeta(
        code: (j['code'] ?? '') as String,
        title: (j['title'] ?? j['code'] ?? '') as String,
        questionCount: (j['questionCount'] ?? 0) as int,
        totalMarks: (j['totalMarks'] ?? 0) as int,
        durationMinutes: j['durationMinutes'] as int?,
        category: (j['category'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        bundleSha256: (j['bundleSha256'] ?? '') as String,
        sizeBytes: (j['sizeBytes'] ?? 0) as int,
      );
}

class Manifest {
  const Manifest({required this.version, required this.exams});
  final String version;
  final List<ExamMeta> exams;

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        version: (j['version'] ?? '') as String,
        exams: ((j['exams'] as List<dynamic>?) ?? const [])
            .map((e) => ExamMeta.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class BundleQuestion {
  const BundleQuestion({
    required this.id,
    required this.type,
    required this.stem,
    required this.marks,
    this.options = const {},
    this.topic = '',
    this.difficulty = '',
  });

  final String id;
  final String type; // mcq | text
  final String stem;
  final Map<String, String> options; // letter -> text
  final int marks;
  final String topic;
  final String difficulty;

  factory BundleQuestion.fromJson(Map<String, dynamic> j) => BundleQuestion(
        id: (j['id'] ?? '') as String,
        type: (j['type'] ?? 'mcq') as String,
        stem: (j['stem'] ?? '') as String,
        marks: (j['marks'] ?? 1) as int,
        options: ((j['options'] as Map<dynamic, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        topic: (j['topic'] ?? '') as String,
        difficulty: (j['difficulty'] ?? '') as String,
      );
}

class Bundle {
  const Bundle({
    required this.code,
    required this.title,
    required this.version,
    required this.questionCount,
    required this.totalMarks,
    required this.questions,
    this.durationMinutes,
    this.category = '',
    this.body = '',
  });

  final String code;
  final String title;
  final int version;
  final int questionCount;
  final int totalMarks;
  final int? durationMinutes;
  final String category;
  final String body;
  final List<BundleQuestion> questions;

  factory Bundle.fromJson(Map<String, dynamic> j) => Bundle(
        code: (j['code'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        version: (j['version'] ?? 1) as int,
        questionCount: (j['questionCount'] ?? 0) as int,
        totalMarks: (j['totalMarks'] ?? 0) as int,
        durationMinutes: j['durationMinutes'] as int?,
        category: (j['category'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        questions: ((j['questions'] as List<dynamic>?) ?? const [])
            .map((q) =>
                BundleQuestion.fromJson((q as Map).cast<String, dynamic>()))
            .toList(),
      );

  /// A copy of this pack with its questions re-sequenced to the server's
  /// adaptive walk ([order]). Ids missing from the order keep their
  /// relative positions at the end, so a stale order can never strand a
  /// question. The cached pack itself is never mutated.
  Bundle withOrder(List<String> order) {
    final byId = <String, BundleQuestion>{
      for (final q in questions) q.id: q,
    };
    final ordered = <BundleQuestion>[];
    final used = <String>{};
    for (final id in order) {
      final q = byId[id];
      if (q != null && used.add(id)) ordered.add(q);
    }
    for (final q in questions) {
      if (!used.contains(q.id)) ordered.add(q);
    }
    return Bundle(
      code: code,
      title: title,
      version: version,
      questionCount: questionCount,
      totalMarks: totalMarks,
      durationMinutes: durationMinutes,
      category: category,
      body: body,
      questions: ordered,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'title': title,
        'version': version,
        'questionCount': questionCount,
        'totalMarks': totalMarks,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (category.isNotEmpty) 'category': category,
        if (body.isNotEmpty) 'body': body,
        'questions': questions
            .map((q) => <String, dynamic>{
                  'id': q.id,
                  'type': q.type,
                  'stem': q.stem,
                  'marks': q.marks,
                  if (q.options.isNotEmpty) 'options': q.options,
                  if (q.topic.isNotEmpty) 'topic': q.topic,
                  if (q.difficulty.isNotEmpty) 'difficulty': q.difficulty,
                })
            .toList(),
      };
}

class TopicRow {
  const TopicRow({required this.topic, required this.correct, required this.total});
  final String topic;
  final int correct;
  final int total;

  factory TopicRow.fromJson(Map<String, dynamic> j) => TopicRow(
        topic: (j['topic'] ?? '') as String,
        correct: (j['correct'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
      );
}

class ExamResult {
  const ExamResult({required this.score, required this.total, required this.breakdown});
  final int score;
  final int total;
  final List<TopicRow> breakdown;

  /// Topics the last paper exposed (accuracy < 60%) — the score report's
  /// weak-topic chips that deep-link into the syllabus map (ROADMAP #4).
  List<TopicRow> weakTopics({double threshold = 0.6}) {
    final weak = breakdown
        .where((r) => r.total > 0 && r.correct / r.total < threshold)
        .toList()
      ..sort((a, b) {
        final fa = a.total == 0 ? 1.0 : a.correct / a.total;
        final fb = b.total == 0 ? 1.0 : b.correct / b.total;
        return fa.compareTo(fb);
      });
    return weak;
  }

  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
        score: (j['score'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
        breakdown: ((j['breakdown'] as List<dynamic>?) ?? const [])
            .map((r) => TopicRow.fromJson((r as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class AttemptStarted {
  const AttemptStarted({
    required this.attemptId,
    required this.code,
    required this.status,
    this.durationMinutes,
    this.questionCount,
    this.adaptive = false,
    this.order,
  });

  final String attemptId;
  final String code;
  final String status;
  final int? durationMinutes;
  final int? questionCount;

  /// True when the server ranked this paper weak-topic-first (ROADMAP #5).
  final bool adaptive;

  /// The question-id walk to answer in; null keeps the pack's natural
  /// order (pre-adaptive attempts and non-adaptive papers).
  final List<String>? order;

  factory AttemptStarted.fromJson(Map<String, dynamic> j) => AttemptStarted(
        attemptId: (j['attemptId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        status: (j['status'] ?? 'in_progress') as String,
        durationMinutes: j['durationMinutes'] as int?,
        questionCount: j['questionCount'] as int?,
        adaptive: (j['adaptive'] ?? false) as bool,
        order: (j['order'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
      );
}

class AttemptView {
  const AttemptView({
    required this.attemptId,
    required this.code,
    required this.status,
    this.result,
  });

  final String attemptId;
  final String code;
  final String status; // in_progress | grading | graded | error
  final ExamResult? result;

  factory AttemptView.fromJson(Map<String, dynamic> j) => AttemptView(
        attemptId: (j['attemptId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        result: j['result'] == null
            ? null
            : ExamResult.fromJson((j['result'] as Map).cast<String, dynamic>()),
      );
}

// ---------------------------------------------------------- paper history

/// One row of GET /me/attempts — the student's paper history.
class AttemptRow {
  AttemptRow({
    required this.attemptId,
    required this.code,
    required this.status,
    required this.startedAt,
    this.submittedAt,
    this.durationMs,
    this.score,
    this.total,
  });

  final String attemptId;
  final String code;
  final String status; // in_progress | grading | graded | error
  final DateTime startedAt;
  final DateTime? submittedAt;
  final int? durationMs;
  final int? score;
  final int? total;

  int? get pct {
    if (score == null || total == null || total! == 0) return null;
    return score! * 100 ~/ total!;
  }

  bool get isGraded => status == 'graded' && score != null && total != null;

  /// Questions the student got wrong on this paper (review backlog).
  int get missed => isGraded ? total! - score! : 0;

  factory AttemptRow.fromJson(Map<String, dynamic> j) => AttemptRow(
        attemptId: (j['attemptId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        startedAt: DateTime.tryParse((j['startedAt'] ?? '') as String) ??
            DateTime.now(),
        submittedAt: j['submittedAt'] == null
            ? null
            : DateTime.tryParse(j['submittedAt'] as String),
        durationMs: j['durationMs'] as int?,
        score: j['score'] as int?,
        total: j['total'] as int?,
      );
}

/// One reviewed question of a graded paper (GET /attempts/{id}/review).
class ReviewQuestion {
  ReviewQuestion({
    required this.questionId,
    required this.stem,
    required this.topic,
    required this.options,
    required this.selected,
    required this.correct,
    required this.explanation,
    required this.correctly,
  });

  final String questionId;
  final String stem;
  final String topic;
  final Map<String, String> options;
  final String selected; // '' when skipped
  final String correct;
  final String explanation;
  final bool correctly;

  bool get isWrong => !correctly;

  factory ReviewQuestion.fromJson(Map<String, dynamic> j) => ReviewQuestion(
        questionId: (j['questionId'] ?? '') as String,
        stem: (j['stem'] ?? '') as String,
        topic: (j['topic'] ?? '') as String,
        options: ((j['options'] as Map<dynamic, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        selected: (j['selected'] ?? '') as String,
        correct: (j['correct'] ?? '') as String,
        explanation: (j['explanation'] ?? '') as String,
        correctly: (j['correctly'] ?? false) as bool,
      );
}

/// Full review payload for one graded paper.
class AttemptReview {
  AttemptReview({
    required this.attemptId,
    required this.code,
    required this.title,
    required this.questions,
    this.score,
    this.total,
  });

  final String attemptId;
  final String code;
  final String title;
  final List<ReviewQuestion> questions;
  final int? score;
  final int? total;

  int get wrongCount => questions.where((q) => q.isWrong).length;
  int get skippedCount =>
      questions.where((q) => q.selected.isEmpty).length;

  factory AttemptReview.fromJson(Map<String, dynamic> j) => AttemptReview(
        attemptId: (j['attemptId'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        score: j['score'] as int?,
        total: j['total'] as int?,
        questions: ((j['questions'] as List<dynamic>?) ?? const [])
            .map((dynamic e) =>
                ReviewQuestion.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

// ---------------------------------------------------------------- gamification

/// One scholar's streak/XP summary — mirrors GET /me/gamification `state`.
class StreakState {
  StreakState({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalXp,
    required this.totalCorrect,
    required this.attempts,
    required this.level,
    this.lastActive,
  });

  final int currentStreak;
  final int bestStreak;
  final int totalXp;
  final int totalCorrect;
  final int attempts;
  final int level;

  /// YYYY-MM-DD (UTC) of the last graded attempt, if any.
  final String? lastActive;

  factory StreakState.fromJson(Map<String, dynamic> j) => StreakState(
        currentStreak: (j['currentStreak'] ?? 0) as int,
        bestStreak: (j['bestStreak'] ?? 0) as int,
        totalXp: (j['totalXp'] ?? 0) as int,
        totalCorrect: (j['totalCorrect'] ?? 0) as int,
        attempts: (j['attempts'] ?? 0) as int,
        level: (j['level'] ?? 1) as int,
        lastActive: j['lastActive'] as String?,
      );

  /// XP earned inside the CURRENT level (500 XP per level, server rule).
  int get xpIntoLevel => totalXp % 500;

  /// XP still needed to reach the next level.
  int get xpToNextLevel => 500 - xpIntoLevel;

  /// 0.0..1.0 progress through the current level.
  double get levelProgress => xpIntoLevel / 500;
}

/// One earned badge in the ledger.
class Award {
  Award({required this.code, required this.earnedAt});

  final String code;
  final DateTime earnedAt;

  factory Award.fromJson(Map<String, dynamic> j) => Award(
        code: (j['code'] ?? '') as String,
        earnedAt:
            DateTime.parse((j['earnedAt'] ?? '') as String).toUtc(),
      );
}

/// Full gamification payload: `state` + `awards[]`.
class GamificationSummary {
  GamificationSummary({required this.state, required this.awards});

  final StreakState state;
  final List<Award> awards;

  bool holds(String code) => awards.any((Award a) => a.code == code);

  factory GamificationSummary.fromJson(Map<String, dynamic> j) =>
      GamificationSummary(
        state: StreakState.fromJson(
            ((j['state'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>()),
        awards: ((j['awards'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic e) =>
                Award.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

// ------------------------------------------------------------ spaced repetition

/// One queued topic of the SM-2 review queue (GET /me/review rows).
class ReviewItem {
  ReviewItem({
    required this.topic,
    required this.ease,
    required this.intervalDays,
    required this.repetitions,
    required this.lapses,
    required this.dueOn,
    required this.lastCorrect,
    required this.lastTotal,
  });

  final String topic;
  final double ease;
  final int intervalDays;
  final int repetitions;
  final int lapses;

  /// YYYY-MM-DD (UTC) the topic comes due.
  final String dueOn;
  final int lastCorrect;
  final int lastTotal;

  /// Overdue / due / later — the preview status the design renders.
  String status(DateTime now) {
    final due = DateTime.tryParse(dueOn);
    if (due == null) return 'due';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final days = today.difference(day).inDays;
    if (days > 0) return 'overdue';
    if (days == 0) return 'due';
    return 'later';
  }

  /// "in 3d" / "in 2w" for upcoming rows (design's "In 2 hours" slot).
  String get laterLabel {
    if (intervalDays >= 14) return 'in ${intervalDays ~/ 7}w';
    return 'in ${intervalDays}d';
  }

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
        topic: (j['topic'] ?? '') as String,
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: (j['intervalDays'] ?? 0) as int,
        repetitions: (j['repetitions'] ?? 0) as int,
        lapses: (j['lapses'] ?? 0) as int,
        dueOn: (j['dueOn'] ?? '') as String,
        lastCorrect: (j['lastCorrect'] ?? 0) as int,
        lastTotal: (j['lastTotal'] ?? 0) as int,
      );
}

/// Review queue stats block (GET /me/review `stats`).
class ReviewStats {
  const ReviewStats({
    required this.tracked,
    required this.due,
    required this.mature,
    required this.learning,
  });

  final int tracked;
  final int due;
  final int mature;
  final int learning;

  factory ReviewStats.fromJson(Map<String, dynamic> j) => ReviewStats(
        tracked: (j['tracked'] ?? 0) as int,
        due: (j['due'] ?? 0) as int,
        mature: (j['mature'] ?? 0) as int,
        learning: (j['learning'] ?? 0) as int,
      );
}

/// Full spaced-repetition payload: due + upcoming + stats.
class ReviewSummary {
  ReviewSummary({required this.due, required this.upcoming, required this.stats});

  final List<ReviewItem> due;
  final List<ReviewItem> upcoming;
  final ReviewStats stats;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        due: ((j['due'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic e) =>
                ReviewItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        upcoming: ((j['upcoming'] ?? <dynamic>[]) as List<dynamic>)
            .map((dynamic e) =>
                ReviewItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        stats:
            ReviewStats.fromJson(((j['stats'] ?? <String, dynamic>{}) as Map)
                .cast<String, dynamic>()),
      );
}

// ------------------------------------------------------------- syllabus (4)

/// One topic node of the syllabus map, overlaid with the student's own
/// SM-2 mastery state served by GET /syllabus/{body}.
class SyllabusTopic {
  const SyllabusTopic({
    required this.topic,
    required this.questions,
    required this.seen,
    required this.lastCorrect,
    required this.lastTotal,
    required this.accuracy,
    required this.status,
    required this.dueOn,
    required this.weakness,
  });

  final String topic;
  final int questions;
  final bool seen;
  final int lastCorrect;
  final int lastTotal;
  final double accuracy; // last paper's accuracy, 0 when unseen
  final String status; // unseen | learning | mastered
  final String dueOn; // YYYY-MM-DD, '' when unseen
  final double weakness; // the adaptive-ordering score

  /// The three mastery dots of the design: mastered / learning / unseen.
  int get dot => status == 'mastered' ? 3 : (status == 'learning' ? 2 : 1);

  factory SyllabusTopic.fromJson(Map<String, dynamic> j) => SyllabusTopic(
        topic: (j['topic'] ?? '') as String,
        questions: (j['questions'] ?? 0) as int,
        seen: (j['seen'] ?? false) as bool,
        lastCorrect: (j['lastCorrect'] ?? 0) as int,
        lastTotal: (j['lastTotal'] ?? 0) as int,
        accuracy: ((j['accuracy'] ?? 0) as num).toDouble(),
        status: (j['status'] ?? 'unseen') as String,
        dueOn: (j['dueOn'] ?? '') as String,
        weakness: ((j['weakness'] ?? 0) as num).toDouble(),
      );
}

class SyllabusSection {
  const SyllabusSection({required this.title, required this.mastery, required this.topics});

  final String title;
  final double mastery; // 0..1, drives the section percentage
  final List<SyllabusTopic> topics;

  factory SyllabusSection.fromJson(Map<String, dynamic> j) => SyllabusSection(
        title: (j['title'] ?? '') as String,
        mastery: ((j['mastery'] ?? 0) as num).toDouble(),
        topics: ((j['topics'] as List<dynamic>?) ?? const [])
            .map((t) => SyllabusTopic.fromJson((t as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class SyllabusSubject {
  const SyllabusSubject({required this.subject, required this.sections});

  final String subject;
  final List<SyllabusSection> sections;

  factory SyllabusSubject.fromJson(Map<String, dynamic> j) => SyllabusSubject(
        subject: (j['subject'] ?? '') as String,
        sections: ((j['sections'] as List<dynamic>?) ?? const [])
            .map((s) => SyllabusSection.fromJson((s as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class SyllabusTree {
  const SyllabusTree({
    required this.body,
    required this.stats,
    required this.weakest,
    required this.subjects,
  });

  final String body;
  final SyllabusStats stats;
  final List<SyllabusTopic> weakest; // focus-next chips, worst first
  final List<SyllabusSubject> subjects;

  factory SyllabusTree.fromJson(Map<String, dynamic> j) => SyllabusTree(
        body: (j['body'] ?? '') as String,
        stats: SyllabusStats.fromJson(
            ((j['stats'] ?? const <String, dynamic>{}) as Map).cast<String, dynamic>()),
        weakest: ((j['weakest'] as List<dynamic>?) ?? const [])
            .map((t) => SyllabusTopic.fromJson((t as Map).cast<String, dynamic>()))
            .toList(),
        subjects: ((j['subjects'] as List<dynamic>?) ?? const [])
            .map((s) => SyllabusSubject.fromJson((s as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class SyllabusStats {
  const SyllabusStats({
    this.topics = 0,
    this.mastered = 0,
    this.learning = 0,
    this.unseen = 0,
    this.due = 0,
  });

  final int topics;
  final int mastered;
  final int learning;
  final int unseen;
  final int due;

  factory SyllabusStats.fromJson(Map<String, dynamic> j) => SyllabusStats(
        topics: (j['topics'] ?? 0) as int,
        mastered: (j['mastered'] ?? 0) as int,
        learning: (j['learning'] ?? 0) as int,
        unseen: (j['unseen'] ?? 0) as int,
        due: (j['due'] ?? 0) as int,
      );
}
