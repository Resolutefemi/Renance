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
    this.subjects = const <String>[],
    this.targetYear,
  });

  final String fullName;
  final String institution;
  final String gradeLevel;
  final List<String> exams;
  final bool completed;

  /// The daily CBT subject combination (founder rule: the first daily
  /// tap asks for it; the sprint then draws only these subjects).
  final List<String> subjects;

  /// Exam year picked at onboarding (drives the hero countdown).
  final int? targetYear;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    fullName: (j['fullName'] ?? '') as String,
    institution: (j['institution'] ?? '') as String,
    gradeLevel: (j['gradeLevel'] ?? '') as String,
    exams: ((j['exams'] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    subjects: ((j['subjects'] as List<dynamic>?) ?? const [])
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
    this.years = const <int>[],
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

  /// Exam years present in the pack (sorted), the practice year chips'
  /// data. Empty when the manifest carries none.
  final List<int> years;

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
    years: ((j['years'] as List<dynamic>?) ?? const <dynamic>[])
        .map((dynamic y) => (y as num).toInt())
        .toList(),
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

/// Today's daily challenge (GET /daily/{body}): the paper code + day.
/// The tile opens the code like any exam; the bundle endpoint serves
/// the rotating bank.
class DailyInfo {
  const DailyInfo({
    required this.body,
    required this.code,
    required this.day,
    this.questionCount = 0,
    this.score,
    this.total,
  });

  final String body;
  final String code;
  final String day;
  final int questionCount;
  final int? score;
  final int? total;

  factory DailyInfo.fromJson(Map<String, dynamic> j) {
    final Map<dynamic, dynamic>? my =
        (j['myResult'] as Map<dynamic, dynamic>?);
    return DailyInfo(
      body: (j['body'] ?? '') as String,
      code: (j['code'] ?? '') as String,
      day: (j['day'] ?? '') as String,
      questionCount: (j['questionCount'] ?? 0) as int,
      score: my == null ? null : (my['score'] ?? 0) as int,
      total: my == null ? null : (my['total'] ?? 0) as int,
    );
  }
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
    this.year = 0,
    this.group = '',
    this.image = '',
    this.passage = '',
  });

  final String id;
  final String type; // mcq | text | theory
  final String stem;
  final Map<String, String> options; // letter -> text
  final int marks;
  final String topic;
  final String difficulty;
  /// Exam year the past question was drawn from (0 when unknown).
  final int year;
  /// Question family ("comprehension" = passage-based English).
  final String group;
  /// Question diagram, origin-less path under /qimages/ on the API.
  final String image;
  /// Shared comprehension text the question belongs to.
  final String passage;

  factory BundleQuestion.fromJson(Map<String, dynamic> j) => BundleQuestion(
    id: (j['id'] ?? '') as String,
    type: (j['type'] ?? 'mcq') as String,
    stem: (j['stem'] ?? '') as String,
    marks: (j['marks'] ?? 1) as int,
    options: ((j['options'] as Map<dynamic, dynamic>?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    topic: (j['topic'] ?? '') as String,
    difficulty: (j['difficulty'] ?? '') as String,
    year: (j['year'] ?? 0) as int,
    group: (j['group'] ?? '') as String,
    image: (j['image'] ?? '') as String,
    passage: (j['passage'] ?? '') as String,
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
        .map((q) => BundleQuestion.fromJson((q as Map).cast<String, dynamic>()))
        .toList(),
  );

  /// A copy of this pack with its questions re-sequenced to the server's
  /// adaptive walk ([order]). Ids missing from the order keep their
  /// relative positions at the end, so a stale order can never strand a
  /// question. The cached pack itself is never mutated.
  Bundle withOrder(List<String> order) {
    final byId = <String, BundleQuestion>{for (final q in questions) q.id: q};
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

  /// A copy of this pack with its questions shuffled by [rng]
  /// (Fisher-Yates). Practice Settings' shuffle toggle uses it; grading
  /// keys by question id, so display order is free. The cached pack
  /// itself is never mutated.
  Bundle reordered(double Function() rng) {
    final List<BundleQuestion> shuffled = List<BundleQuestion>.of(questions);
    for (int i = shuffled.length - 1; i > 0; i--) {
      int j = (rng() * (i + 1)).floor();
      if (j > i) j = i;
      final BundleQuestion tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
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
      questions: shuffled,
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
        .map(
          (q) => <String, dynamic>{
            'id': q.id,
            'type': q.type,
            'stem': q.stem,
            'marks': q.marks,
            if (q.options.isNotEmpty) 'options': q.options,
            if (q.topic.isNotEmpty) 'topic': q.topic,
            if (q.difficulty.isNotEmpty) 'difficulty': q.difficulty,
            if (q.year > 0) 'year': q.year,
            if (q.group.isNotEmpty) 'group': q.group,
            if (q.image.isNotEmpty) 'image': q.image,
            if (q.passage.isNotEmpty) 'passage': q.passage,
          },
        )
        .toList(),
  };
}

class TopicRow {
  const TopicRow({
    required this.topic,
    required this.correct,
    required this.total,
  });
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
  const ExamResult({
    required this.score,
    required this.total,
    required this.breakdown,
  });
  final int score;
  final int total;
  final List<TopicRow> breakdown;

  /// Topics the last paper exposed (accuracy < 60%), the score report's
  /// weak-topic chips that deep-link into the syllabus map (ROADMAP #4).
  List<TopicRow> weakTopics({double threshold = 0.6}) {
    final weak =
        breakdown
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
    order: (j['order'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
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

/// One row of GET /me/attempts, the student's paper history.
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
    startedAt:
        DateTime.tryParse((j['startedAt'] ?? '') as String) ?? DateTime.now(),
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
    this.year = 0,
    this.type = '',
    this.image = '',
    this.answerImage = '',
    this.passage = '',
    this.video = '',
  });

  final String questionId;
  final String stem;
  final String topic;
  final Map<String, String> options;
  final String selected; // '' when skipped
  final String correct;
  final String explanation;
  final bool correctly;
  final int year;
  final String type; // mcq | theory
  /// Question diagram, origin-less /qimages/ path.
  final String image;
  /// Worked-solution diagram unlocked with the key.
  final String answerImage;
  /// Shared comprehension text the question belongs to.
  final String passage;
  /// Optional walkthrough video link.
  final String video;

  bool get isWrong => !correctly;

  factory ReviewQuestion.fromJson(Map<String, dynamic> j) => ReviewQuestion(
    questionId: (j['questionId'] ?? '') as String,
    stem: (j['stem'] ?? '') as String,
    topic: (j['topic'] ?? '') as String,
    options: ((j['options'] as Map<dynamic, dynamic>?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    selected: (j['selected'] ?? '') as String,
    correct: (j['correct'] ?? '') as String,
    explanation: (j['explanation'] ?? '') as String,
    correctly: (j['correctly'] ?? false) as bool,
    year: (j['year'] ?? 0) as int,
    type: (j['type'] ?? '') as String,
    image: (j['image'] ?? '') as String,
    answerImage: (j['answerImage'] ?? '') as String,
    passage: (j['passage'] ?? '') as String,
    video: (j['video'] ?? '') as String,
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
  int get skippedCount => questions.where((q) => q.selected.isEmpty).length;

  factory AttemptReview.fromJson(Map<String, dynamic> j) => AttemptReview(
    attemptId: (j['attemptId'] ?? '') as String,
    code: (j['code'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    score: j['score'] as int?,
    total: j['total'] as int?,
    questions: ((j['questions'] as List<dynamic>?) ?? const [])
        .map(
          (dynamic e) =>
              ReviewQuestion.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );
}

// ---------------------------------------------------------------- gamification

/// One scholar's streak/XP summary, mirrors GET /me/gamification `state`.
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
    earnedAt: DateTime.parse((j['earnedAt'] ?? '') as String).toUtc(),
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
          ((j['state'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>(),
        ),
        awards: ((j['awards'] ?? <dynamic>[]) as List<dynamic>)
            .map(
              (dynamic e) => Award.fromJson((e as Map).cast<String, dynamic>()),
            )
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

  /// Overdue / due / later, the preview status the design renders.
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
  ReviewSummary({
    required this.due,
    required this.upcoming,
    required this.stats,
  });

  final List<ReviewItem> due;
  final List<ReviewItem> upcoming;
  final ReviewStats stats;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
    due: ((j['due'] ?? <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              ReviewItem.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    upcoming: ((j['upcoming'] ?? <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              ReviewItem.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    stats: ReviewStats.fromJson(
      ((j['stats'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>(),
    ),
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
  const SyllabusSection({
    required this.title,
    required this.mastery,
    required this.topics,
  });

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
        .map(
          (s) => SyllabusSection.fromJson((s as Map).cast<String, dynamic>()),
        )
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
      ((j['stats'] ?? const <String, dynamic>{}) as Map)
          .cast<String, dynamic>(),
    ),
    weakest: ((j['weakest'] as List<dynamic>?) ?? const [])
        .map((t) => SyllabusTopic.fromJson((t as Map).cast<String, dynamic>()))
        .toList(),
    subjects: ((j['subjects'] as List<dynamic>?) ?? const [])
        .map(
          (s) => SyllabusSubject.fromJson((s as Map).cast<String, dynamic>()),
        )
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

// -------------------------------------------------------------- fatigue (6)

/// The fatigue signal for one sitting, mirror of the API's pure rule
/// (apps/study-api/internal/fatigue). Ported verbatim so the app, the web
/// page and the server always agree on what "your pace is dipping" means.
class FatigueSignal {
  const FatigueSignal({
    required this.level,
    required this.suggestBreak,
    required this.reasons,
    required this.driftRatio,
    this.medianFirst5Ms = 0,
    this.medianLast5Ms = 0,
  });

  final String level; // none | mild | high
  final bool suggestBreak;
  final List<String> reasons;
  final double driftRatio;
  final int medianFirst5Ms;
  final int medianLast5Ms;

  static const FatigueSignal none = FatigueSignal(
    level: 'none',
    suggestBreak: false,
    reasons: <String>[],
    driftRatio: 0,
  );

  factory FatigueSignal.fromJson(Map<String, dynamic> j) => FatigueSignal(
    level: (j['level'] ?? 'none') as String,
    suggestBreak: (j['suggestBreak'] ?? false) as bool,
    reasons: ((j['reasons'] as List<dynamic>?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(),
    driftRatio: ((j['driftRatio'] ?? 0) as num).toDouble(),
    medianFirst5Ms: (j['medianFirst5Ms'] ?? 0) as int,
    medianLast5Ms: (j['medianLast5Ms'] ?? 0) as int,
  );
}

/// Pure: median of ms samples (empty -> 0). Never mutates the input.
int medianOf(List<int> xs) {
  if (xs.isEmpty) return 0;
  final s = List<int>.of(xs)..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) ~/ 2);
}

const int _fatigueMinAnswers = 8;
const double _fatigueDriftMild = 1.8;
const double _fatigueDriftHigh = 2.6;
const double _fatigueDriftFloorMinutes = 30.0;
const double _fatigueMildMinutes = 50.0;
const double _fatigueHighMinutes = 75.0;
const double _fatigueComboMinutes = 40.0;

/// Pure port of the server's fatigue.Assess (ROADMAP #6): the same
/// thresholds, the same escalation ladder, zero platform dependencies.
FatigueSignal assessFatigue(List<int> latenciesMs, double sessionMinutes) {
  final first = latenciesMs.length > 5
      ? latenciesMs.sublist(0, 5)
      : List<int>.of(latenciesMs);
  final last = latenciesMs.length > 5
      ? latenciesMs.sublist(latenciesMs.length - 5)
      : List<int>.of(latenciesMs);
  final mFirst = medianOf(first);
  final mLast = medianOf(last);
  final ratio = mFirst > 0 ? mLast / mFirst : 0.0;

  var level = 'none';
  final reasons = <String>[];

  final driftMild =
      latenciesMs.length >= _fatigueMinAnswers && ratio >= _fatigueDriftMild;
  final driftHigh =
      latenciesMs.length >= _fatigueMinAnswers &&
      ratio >= _fatigueDriftHigh &&
      sessionMinutes >= _fatigueDriftFloorMinutes;

  if (driftHigh) {
    level = 'high';
    reasons.add('Answers are taking much longer than they did at the start');
  } else if (driftMild && sessionMinutes >= _fatigueComboMinutes) {
    level = 'high';
    reasons.add('Your pace is dipping and this has been a long sitting');
  } else if (driftMild) {
    level = 'mild';
    reasons.add('Your pace is dipping');
  }

  if (sessionMinutes >= _fatigueHighMinutes) {
    level = 'high';
    reasons.add('This has been a long session');
  } else if (sessionMinutes >= _fatigueMildMinutes && level == 'none') {
    level = 'mild';
    reasons.add('This has been a long session');
  }

  return FatigueSignal(
    level: level,
    suggestBreak: level != 'none',
    reasons: reasons,
    driftRatio: ratio,
    medianFirst5Ms: mFirst,
    medianLast5Ms: mLast,
  );
}

/// GET /me/fatigue, the current advisory for home-screen banners.
class FatigueState {
  const FatigueState({
    required this.level,
    required this.suggestBreak,
    required this.minutesToday,
    required this.minutesLast3h,
    required this.sessionsToday,
    this.reason = '',
  });

  final String level; // none | mild | high
  final bool suggestBreak;
  final String reason;
  final double minutesToday;
  final double minutesLast3h;
  final int sessionsToday;

  factory FatigueState.fromJson(Map<String, dynamic> j) => FatigueState(
    level: (j['level'] ?? 'none') as String,
    suggestBreak: (j['suggestBreak'] ?? false) as bool,
    reason: (j['reason'] ?? '') as String,
    minutesToday: ((j['minutesToday'] ?? 0) as num).toDouble(),
    minutesLast3h: ((j['minutesLast3h'] ?? 0) as num).toDouble(),
    sessionsToday: (j['sessionsToday'] ?? 0) as int,
  );
}

// ---------------------------------------------------------- flashcards (7)

/// One flashcard (GET /flashcards/{code} row).
class FlashcardCard {
  const FlashcardCard({
    required this.id,
    required this.front,
    required this.back,
    this.hint = '',
  });

  final String id;
  final String front;
  final String back;
  final String hint;

  factory FlashcardCard.fromJson(Map<String, dynamic> j) => FlashcardCard(
    id: (j['id'] ?? '') as String,
    front: (j['front'] ?? '') as String,
    back: (j['back'] ?? '') as String,
    hint: (j['hint'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'front': front,
    'back': back,
    if (hint.isNotEmpty) 'hint': hint,
  };
}

/// Deck list row (GET /flashcards).
class FlashcardDeckMeta {
  const FlashcardDeckMeta({
    required this.code,
    required this.title,
    required this.cardCount,
    this.subject = '',
    this.body = '',
  });

  final String code;
  final String title;
  final int cardCount;
  final String subject;
  final String body;

  factory FlashcardDeckMeta.fromJson(Map<String, dynamic> j) =>
      FlashcardDeckMeta(
        code: (j['code'] ?? '') as String,
        title: (j['title'] ?? j['code'] ?? '') as String,
        cardCount: (j['cardCount'] ?? 0) as int,
        subject: (j['subject'] ?? '') as String,
        body: (j['body'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'title': title,
    'cardCount': cardCount,
    if (subject.isNotEmpty) 'subject': subject,
    if (body.isNotEmpty) 'body': body,
  };
}

/// Full deck with its cards (GET /flashcards/{code}).
class FlashcardDeck {
  const FlashcardDeck({
    required this.code,
    required this.title,
    required this.cardCount,
    required this.cards,
    this.subject = '',
    this.body = '',
  });

  final String code;
  final String title;
  final int cardCount;
  final String subject;
  final String body;
  final List<FlashcardCard> cards;

  factory FlashcardDeck.fromJson(Map<String, dynamic> j) => FlashcardDeck(
    code: (j['code'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    cardCount: (j['cardCount'] ?? 0) as int,
    subject: (j['subject'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    cards: ((j['cards'] as List<dynamic>?) ?? const <dynamic>[])
        .map(
          (dynamic e) =>
              FlashcardCard.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'title': title,
    'cardCount': cardCount,
    if (subject.isNotEmpty) 'subject': subject,
    if (body.isNotEmpty) 'body': body,
    'cards': cards.map((c) => c.toJson()).toList(),
  };
}

/// Leitner box intervals (days) per box, mirror of store.CardBoxIntervals.
/// Index 0 is unused; box 1 is due immediately.
const List<int> cardBoxIntervals = <int>[0, 0, 1, 2, 4, 7];

/// Pure Leitner rule, mirror of store.NextCardBox.
int nextCardBox(int box, String grade) {
  switch (grade) {
    case 'again':
      return 1;
    case 'good':
      return box >= 5 ? 5 : box + 1;
    default: // 'hard' and unknown grades hold position
      return box < 1 ? 1 : box;
  }
}

/// Pure interval lookup, mirror of store.CardIntervalDays.
int cardIntervalDays(int box) {
  final b = box < 1 ? 1 : (box > 5 ? 5 : box);
  return cardBoxIntervals[b];
}

/// One card's study state (GET/POST /me/cards/progress rows).
class CardProgress {
  const CardProgress({
    required this.cardId,
    required this.deckCode,
    required this.box,
    required this.correct,
    required this.wrong,
    required this.dueOn,
    this.lastGrade = '',
  });

  final String cardId;
  final String deckCode;
  final int box;
  final int correct;
  final int wrong;
  final String dueOn; // YYYY-MM-DD (UTC)
  final String lastGrade; // again | hard | good

  bool get isDue {
    final due = DateTime.tryParse(dueOn);
    if (due == null) return true;
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return !due.isAfter(today);
  }

  factory CardProgress.fromJson(Map<String, dynamic> j) => CardProgress(
    cardId: (j['cardId'] ?? '') as String,
    deckCode: (j['deckCode'] ?? '') as String,
    box: (j['box'] ?? 1) as int,
    correct: (j['correct'] ?? 0) as int,
    wrong: (j['wrong'] ?? 0) as int,
    dueOn: (j['dueOn'] ?? '') as String,
    lastGrade: (j['lastGrade'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cardId': cardId,
    'deckCode': deckCode,
    'box': box,
    'correct': correct,
    'wrong': wrong,
    'dueOn': dueOn,
    'lastGrade': lastGrade,
  };
}

/// One grade to send to POST /me/cards/progress.
class FlashcardGrade {
  const FlashcardGrade({
    required this.cardId,
    required this.deckCode,
    required this.grade,
  });

  final String cardId;
  final String deckCode;
  final String grade; // again | hard | good
}

// ------------------------------------------------------------------ lessons
// ROADMAP #8, mdx-built lesson bundles served from data/lessons and
// cached offline exactly like packs and decks.

/// One paragraph-level block. [type] is p / ul / ol / callout / h3; text
/// carries inline markers (**bold**, *italic*, `code`) rendered by the
/// app's inline renderer, never raw HTML.
class LessonBlock {
  LessonBlock({
    required this.type,
    this.text = '',
    this.items = const <String>[],
  });

  final String type;
  final String text;
  final List<String> items;

  factory LessonBlock.fromJson(Map<String, dynamic> j) => LessonBlock(
    type: (j['type'] ?? 'p') as String,
    text: (j['text'] ?? '') as String,
    items: ((j['items'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    if (text.isNotEmpty) 'text': text,
    if (items.isNotEmpty) 'items': items,
  };
}

class LessonSection {
  LessonSection({required this.heading, required this.blocks});

  final String heading;
  final List<LessonBlock> blocks;

  factory LessonSection.fromJson(Map<String, dynamic> j) => LessonSection(
    heading: (j['heading'] ?? '') as String,
    blocks: ((j['blocks'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              LessonBlock.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'heading': heading,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
}

/// List-view row (no sections attached).
class LessonMeta {
  LessonMeta({
    required this.slug,
    required this.title,
    required this.minutes,
    required this.summary,
    this.subject = '',
    this.body = '',
    this.tags = const <String>[],
  });

  final String slug;
  final String title;
  final String subject;
  final String body;
  final List<String> tags;
  final int minutes;
  final String summary;

  factory LessonMeta.fromJson(Map<String, dynamic> j) => LessonMeta(
    slug: (j['slug'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    subject: (j['subject'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    tags: ((j['tags'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(),
    minutes: (j['minutes'] ?? 0) as int,
    summary: (j['summary'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'slug': slug,
    'title': title,
    'subject': subject,
    'body': body,
    'tags': tags,
    'minutes': minutes,
    'summary': summary,
  };
}

/// Full lesson with sections.
class Lesson {
  Lesson({
    required this.slug,
    required this.title,
    required this.minutes,
    required this.summary,
    required this.sections,
    this.subject = '',
    this.body = '',
    this.tags = const <String>[],
  });

  final String slug;
  final String title;
  final String subject;
  final String body;
  final List<String> tags;
  final int minutes;
  final String summary;
  final List<LessonSection> sections;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    slug: (j['slug'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    subject: (j['subject'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    tags: ((j['tags'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(),
    minutes: (j['minutes'] ?? 0) as int,
    summary: (j['summary'] ?? '') as String,
    sections: ((j['sections'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) =>
              LessonSection.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'slug': slug,
    'title': title,
    'subject': subject,
    'body': body,
    'tags': tags,
    'minutes': minutes,
    'summary': summary,
    'sections': sections.map((s) => s.toJson()).toList(),
  };
}

// -------------------------------------------------------------------- tutor
// ROADMAP #9, Socratic chat anchored to a graded attempt + question.

/// One conversation turn as the client stores it.
class TutorTurn {
  TutorTurn({required this.role, required this.content});

  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
    'content': content,
  };
}

/// The tutor's reply plus the mode that produced it ('ai' | 'hint').
class TutorReply {
  TutorReply({required this.text, required this.mode});

  final String text;
  final String mode;

  factory TutorReply.fromJson(Map<String, dynamic> j) => TutorReply(
    text: (j['reply'] ?? '') as String,
    mode: (j['mode'] ?? 'hint') as String,
  );
}

// --------------------------------------------------------- career (18)

/// One curated funding opportunity (GET /career row). The window line is
/// honest by construction ("Typically opens mid-year", never a countdown
/// the backend cannot know), url points at the provider's official domain.
class CareerScholarship {
  const CareerScholarship({
    required this.id,
    required this.name,
    required this.provider,
    required this.level,
    required this.coverage,
    required this.window,
    required this.tags,
    required this.url,
    required this.eligibility,
  });

  final String id;
  final String name;
  final String provider;
  final String level; // undergraduate | postgraduate | both
  final String coverage;
  final String window;
  final List<String> tags;
  final String url;
  final String eligibility;

  factory CareerScholarship.fromJson(Map<String, dynamic> j) =>
      CareerScholarship(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        provider: (j['provider'] ?? '') as String,
        level: (j['level'] ?? 'undergraduate') as String,
        coverage: (j['coverage'] ?? '') as String,
        window: (j['window'] ?? '') as String,
        tags: ((j['tags'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => e as String)
            .toList(),
        url: (j['url'] ?? '') as String,
        eligibility: (j['eligibility'] ?? '') as String,
      );
}

/// One course destination (GET /career row): the JAMB subject
/// combination, the typical competitive aggregate, example universities
/// and the syllabus topics that decide admission.
class CareerPath {
  const CareerPath({
    required this.id,
    required this.course,
    required this.field,
    required this.blurb,
    required this.cutoff,
    required this.subjects,
    required this.universities,
    required this.topics,
  });

  final String id;
  final String course;
  final String field;
  final String blurb;
  final String cutoff;
  final List<String> subjects;
  final List<String> universities;
  final List<String> topics;

  factory CareerPath.fromJson(Map<String, dynamic> j) => CareerPath(
    id: (j['id'] ?? '') as String,
    course: (j['course'] ?? '') as String,
    field: (j['field'] ?? '') as String,
    blurb: (j['blurb'] ?? '') as String,
    cutoff: (j['cutoff'] ?? '') as String,
    subjects: ((j['subjects'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(),
    universities: ((j['universities'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(),
    topics: ((j['topics'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e as String)
        .toList(),
  );
}

/// The GET /career payload: both curated lists, server order.
class CareerData {
  const CareerData({
    required this.scholarships,
    required this.paths,
  });

  final List<CareerScholarship> scholarships;
  final List<CareerPath> paths;

  factory CareerData.fromJson(Map<String, dynamic> j) => CareerData(
    scholarships: ((j['scholarships'] ?? const <dynamic>[]) as List<dynamic>)
        .map(
          (dynamic e) => CareerScholarship.fromJson(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList(),
    paths: ((j['paths'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => CareerPath.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

// ---------------------------------------------------------------- leaderboard

/// One ranked line of a leaderboard board (GET /leaderboard/xp or
/// /leaderboard/arena). The two boards share a shape; only some fields
/// apply per board, so everything is optional.
class BoardEntry {
  const BoardEntry({
    required this.rank,
    required this.username,
    this.xp = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.attempts = 0,
    this.wins = 0,
    this.matches = 0,
    this.points = 0,
    this.correct = 0,
  });

  final int rank;
  final String username;
  final int xp;
  final int bestStreak;
  final int currentStreak;
  final int attempts;
  final int wins;
  final int matches;
  final int points;
  final int correct;

  factory BoardEntry.fromJson(Map<String, dynamic> j) => BoardEntry(
    rank: (j['rank'] ?? 0) as int,
    username: (j['username'] ?? '') as String,
    xp: (j['xp'] ?? 0) as int,
    bestStreak: (j['bestStreak'] ?? 0) as int,
    currentStreak: (j['currentStreak'] ?? 0) as int,
    attempts: (j['attempts'] ?? 0) as int,
    wins: (j['wins'] ?? 0) as int,
    matches: (j['matches'] ?? 0) as int,
    points: (j['points'] ?? 0) as int,
    correct: (j['correct'] ?? 0) as int,
  );
}

/// One leaderboard response: the ranked rows plus the caller's own row
/// ("me"), which is null when they have not earned a rank yet.
class LeaderboardData {
  const LeaderboardData({
    required this.board,
    required this.period,
    required this.entries,
    this.me,
  });

  final String board; // xp | arena
  final String period; // all | week
  final BoardEntry? me;
  final List<BoardEntry> entries;

  factory LeaderboardData.fromJson(Map<String, dynamic> j) => LeaderboardData(
    board: (j['board'] ?? '') as String,
    period: (j['period'] ?? '') as String,
    me: j['me'] == null
        ? null
        : BoardEntry.fromJson((j['me'] as Map).cast<String, dynamic>()),
    entries: ((j['entries'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => BoardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// One live presence in the arena (GET /arena/players row): a student
/// who is connected and idle right now, with their all-time Ren Points
/// (a win is worth 1 point) so the lobby ranks the active list.
class ArenaPlayer {
  const ArenaPlayer({
    required this.userId,
    required this.username,
    required this.renPoints,
  });

  final String userId;
  final String username;
  final int renPoints;

  factory ArenaPlayer.fromJson(Map<String, dynamic> j) => ArenaPlayer(
    userId: (j['userId'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    renPoints: ((j['renPoints'] ?? 0) as num).toInt(),
  );
}

// ============================================================================
// School platform (For Schools): memberships + the read-only offline pack
// (syllabus, scheme of work, notes). Defensive parsing like every model
// above - the API is a friend, not a contract.
// ============================================================================

/// The school itself (school.schools row).
class SchoolInfo {
  const SchoolInfo({
    required this.id,
    required this.name,
    required this.schoolType,
  });

  final String id;
  final String name;
  final String schoolType; // primary | secondary | both

  factory SchoolInfo.fromJson(Map<String, dynamic> j) => SchoolInfo(
    id: (j['id'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    schoolType: (j['schoolType'] ?? 'secondary') as String,
  );
}

/// The caller's membership of one school (school.members row).
class SchoolMemberInfo {
  const SchoolMemberInfo({
    required this.id,
    required this.schoolId,
    required this.role,
    required this.fullName,
    this.staffCode = '',
    this.status = 'active',
  });

  final String id;
  final String schoolId;
  final String role; // management | teacher
  final String fullName;
  final String staffCode;
  final String status;

  bool get isManagement => role == 'management';

  factory SchoolMemberInfo.fromJson(Map<String, dynamic> j) => SchoolMemberInfo(
    id: (j['id'] ?? '') as String,
    schoolId: (j['schoolId'] ?? '') as String,
    role: (j['role'] ?? 'teacher') as String,
    fullName: (j['fullName'] ?? '') as String,
    staffCode: (j['staffCode'] ?? '') as String,
    status: (j['status'] ?? 'active') as String,
  );
}

/// One school membership joined with its school (GET /school/me row).
class SchoolContextModel {
  const SchoolContextModel({required this.member, required this.school});

  final SchoolMemberInfo member;
  final SchoolInfo school;

  factory SchoolContextModel.fromJson(Map<String, dynamic> j) =>
      SchoolContextModel(
        member: SchoolMemberInfo.fromJson(
          ((j['member'] ?? const <String, dynamic>{}) as Map)
              .cast<String, dynamic>(),
        ),
        school: SchoolInfo.fromJson(
          ((j['school'] ?? const <String, dynamic>{}) as Map)
              .cast<String, dynamic>(),
        ),
      );
}

/// A class of the school (Primary 1 … SSS 3).
class SchoolClassInfo {
  const SchoolClassInfo({
    required this.id,
    required this.name,
    required this.level,
    required this.seq,
  });

  final String id;
  final String name;
  final String level; // primary | junior | senior
  final int seq;

  factory SchoolClassInfo.fromJson(Map<String, dynamic> j) => SchoolClassInfo(
    id: (j['id'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    level: (j['level'] ?? 'junior') as String,
    seq: ((j['seq'] ?? 0) as num).toInt(),
  );
}

/// One week of the scheme of work.
class SchemeWeek {
  const SchemeWeek({
    required this.week,
    required this.topic,
    this.objectives = '',
    this.activities = '',
  });

  final int week;
  final String topic;
  final String objectives;
  final String activities;

  factory SchemeWeek.fromJson(dynamic v) {
    final Map<String, dynamic> j =
        (v as Map).cast<String, dynamic>();
    return SchemeWeek(
      week: ((j['week'] ?? 0) as num).toInt(),
      topic: (j['topic'] ?? '') as String,
      objectives: (j['objectives'] ?? '') as String,
      activities: (j['activities'] ?? '') as String,
    );
  }
}

/// A topic of a term syllabus, carrying the note body.
class SchoolTopicInfo {
  const SchoolTopicInfo({
    required this.id,
    required this.title,
    required this.seq,
    required this.week,
    required this.content,
    this.source = '',
  });

  final String id;
  final String title;
  final int seq;
  final int week;
  final String content;
  final String source;

  factory SchoolTopicInfo.fromJson(Map<String, dynamic> j) =>
      SchoolTopicInfo(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        seq: ((j['seq'] ?? 0) as num).toInt(),
        week: ((j['week'] ?? 0) as num).toInt(),
        content: (j['content'] ?? '') as String,
        source: (j['source'] ?? '') as String,
      );
}

/// One term of a class+subject syllabus.
class SchoolSyllabusTerm {
  const SchoolSyllabusTerm({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.term,
    required this.session,
    required this.schemeOfWork,
    required this.topics,
  });

  final String id;
  final String classId;
  final String subjectId;
  final int term; // 1..3
  final String session;
  final List<SchemeWeek> schemeOfWork;
  final List<SchoolTopicInfo> topics;

  factory SchoolSyllabusTerm.fromJson(Map<String, dynamic> j) =>
      SchoolSyllabusTerm(
        id: (j['id'] ?? '') as String,
        classId: (j['classId'] ?? '') as String,
        subjectId: (j['subjectId'] ?? '') as String,
        term: ((j['term'] ?? 1) as num).toInt(),
        session: (j['session'] ?? '') as String,
        schemeOfWork: ((j['schemeOfWork'] ?? const <dynamic>[]) as List<dynamic>)
            .map(SchemeWeek.fromJson)
            .toList(),
        topics: ((j['topics'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) =>
                SchoolTopicInfo.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// A subject of the school (English Studies, Mathematics, ...).
class SchoolSubjectInfo {
  const SchoolSubjectInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.level,
    required this.seq,
  });

  final String id;
  final String name;
  final String code;
  final String level;
  final int seq;

  factory SchoolSubjectInfo.fromJson(Map<String, dynamic> j) =>
      SchoolSubjectInfo(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        level: (j['level'] ?? 'both') as String,
        seq: ((j['seq'] ?? 0) as num).toInt(),
      );
}

/// One class+subject branch of the offline school pack.
class SchoolPackSyllabus {
  const SchoolPackSyllabus({
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subject,
    required this.terms,
  });

  final String classId;
  final String className;
  final String subjectId;
  final String subject;
  final List<SchoolSyllabusTerm> terms;

  factory SchoolPackSyllabus.fromJson(Map<String, dynamic> j) =>
      SchoolPackSyllabus(
        classId: (j['classId'] ?? '') as String,
        className: (j['className'] ?? '') as String,
        subjectId: (j['subjectId'] ?? '') as String,
        subject: (j['subject'] ?? '') as String,
        terms: ((j['terms'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) =>
                SchoolSyllabusTerm.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// One exam-bank question riding in the offline school pack: the pool
/// mirrors what management poured on the web, tagged per subject and
/// term so staff can read the bank in the classroom.
class SchoolPackExamQuestion {
  const SchoolPackExamQuestion({
    required this.id,
    required this.subjectId,
    required this.subject,
    required this.band,
    required this.term,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    required this.marks,
    required this.source,
  });

  final String id;
  final String subjectId;
  final String subject;
  final String band;
  final int term;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final int marks;
  final String source;

  factory SchoolPackExamQuestion.fromJson(Map<String, dynamic> j) =>
      SchoolPackExamQuestion(
        id: (j['id'] ?? '') as String,
        subjectId: (j['subjectId'] ?? '') as String,
        subject: (j['subjectName'] ?? '') as String,
        band: (j['band'] ?? '') as String,
        term: (j['term'] ?? 1) as int,
        question: (j['question'] ?? '') as String,
        options: ((j['options'] ?? const <dynamic>[]) as List<dynamic>)
            .map((dynamic e) => e.toString())
            .toList(),
        answerIndex: (j['answerIndex'] ?? 0) as int,
        explanation: (j['explanation'] ?? '') as String,
        marks: (j['marks'] ?? 1) as int,
        source: (j['source'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'subjectId': subjectId,
    'subjectName': subject,
    'band': band,
    'term': term,
    'question': question,
    'options': options,
    'answerIndex': answerIndex,
    'explanation': explanation,
    'marks': marks,
    'source': source,
  };
}

/// The whole read-only school pack (GET /school/pack/{id}): classes,
/// subjects and every syllabus with scheme of work + topics + notes.
/// Stored locally like an exam bundle so school staff get the same
/// offline guarantee students get.
class SchoolPack {
  const SchoolPack({
    required this.school,
    required this.version,
    required this.fetchedAt,
    required this.classes,
    required this.subjects,
    required this.syllabus,
    this.examBank = const <SchoolPackExamQuestion>[],
  });

  final SchoolInfo school;
  final String version;
  final String fetchedAt;
  final List<SchoolClassInfo> classes;
  final List<SchoolSubjectInfo> subjects;
  final List<SchoolPackSyllabus> syllabus;
  final List<SchoolPackExamQuestion> examBank;

  /// All topics of the pack (count helper for the storage meter).
  int get topicCount => syllabus.fold<int>(
        0,
        (int n, SchoolPackSyllabus s) => n + s.terms.fold<int>(
              0,
              (int m, SchoolSyllabusTerm t) => m + t.topics.length,
            ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'school': <String, dynamic>{
      'id': school.id,
      'name': school.name,
      'schoolType': school.schoolType,
    },
    'version': version,
    'fetchedAt': fetchedAt,
    'classes': classes
        .map((SchoolClassInfo c) => <String, dynamic>{
              'id': c.id,
              'name': c.name,
              'level': c.level,
              'seq': c.seq,
            })
        .toList(),
    'subjects': subjects
        .map((SchoolSubjectInfo s) => <String, dynamic>{
              'id': s.id,
              'name': s.name,
              'code': s.code,
              'level': s.level,
              'seq': s.seq,
            })
        .toList(),
    'syllabus': syllabus
        .map((SchoolPackSyllabus s) => <String, dynamic>{
              'classId': s.classId,
              'className': s.className,
              'subjectId': s.subjectId,
              'subject': s.subject,
              'terms': s.terms
                  .map((SchoolSyllabusTerm t) => <String, dynamic>{
                        'id': t.id,
                        'classId': t.classId,
                        'subjectId': t.subjectId,
                        'term': t.term,
                        'session': t.session,
                        'schemeOfWork': t.schemeOfWork
                            .map((SchemeWeek w) => <String, dynamic>{
                                  'week': w.week,
                                  'topic': w.topic,
                                  'objectives': w.objectives,
                                  'activities': w.activities,
                                })
                            .toList(),
                        'topics': t.topics
                            .map((SchoolTopicInfo tp) => <String, dynamic>{
                                  'id': tp.id,
                                  'title': tp.title,
                                  'seq': tp.seq,
                                  'week': tp.week,
                                  'content': tp.content,
                                  'source': tp.source,
                                })
                            .toList(),
                      })
                  .toList(),
            })
        .toList(),
    'examBank': examBank
        .map((SchoolPackExamQuestion q) => q.toJson())
        .toList(),
  };

  factory SchoolPack.fromJson(Map<String, dynamic> j) => SchoolPack(
    school: SchoolInfo.fromJson(
      ((j['school'] ?? const <String, dynamic>{}) as Map)
          .cast<String, dynamic>(),
    ),
    version: (j['version'] ?? '') as String,
    fetchedAt: (j['fetchedAt'] ?? '') as String,
    classes: ((j['classes'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolClassInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    subjects: ((j['subjects'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolSubjectInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    syllabus: ((j['syllabus'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) =>
            SchoolPackSyllabus.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    examBank: ((j['examBank'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => SchoolPackExamQuestion.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList(),
  );
}
