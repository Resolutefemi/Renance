/// The Learn + Social data layer - the Dart twins of the Go study-api's
/// learn and social contracts (apps/study-api internal/learn/*,
/// internal/social/social.go, internal/httpapi/learn.go +
/// social.go), field-for-field with the web's lib/learn.ts and
/// lib/social.ts so the mobile app renders the exact same payloads the
/// website does.
///
/// Everything here is plain JSON -> model mapping; no controller state
/// lives in this file.
library;

// ------------------------------------------------------------------ learn

/// GET/PATCH /learn/profile - the learner's wallet and desk identity.
class LearnProfile {
  const LearnProfile({
    required this.hearts,
    required this.unlimitedHearts,
    required this.gems,
    required this.xp,
    required this.streak,
    required this.dailyGoal,
    required this.todayXp,
    required this.superActive,
    required this.boostActive,
    required this.freezeCount,
    required this.league,
    required this.courseCount,
    required this.topicsDone,
    required this.perfectCount,
    required this.institutionType,
    required this.department,
    required this.departmentName,
    this.nextHeartInMs,
  });

  final int hearts;
  final bool unlimitedHearts;
  final int? nextHeartInMs;
  final int gems;
  final int xp;
  final int streak;
  final int dailyGoal;
  final int todayXp;
  final bool superActive;
  final bool boostActive;
  final int freezeCount;
  final String league;
  final int courseCount;
  final int topicsDone;
  final int perfectCount;
  final String institutionType;
  final String department;
  final String departmentName;

  /// The web client's offline fallback defaults (learn-stats hook):
  /// hearts 5, unlimited on, everything else zero, league Bronze.
  static const LearnProfile fallback = LearnProfile(
    hearts: 5,
    unlimitedHearts: true,
    gems: 0,
    xp: 0,
    streak: 0,
    dailyGoal: 50,
    todayXp: 0,
    superActive: false,
    boostActive: false,
    freezeCount: 0,
    league: 'Bronze',
    courseCount: 0,
    topicsDone: 0,
    perfectCount: 0,
    institutionType: '',
    department: '',
    departmentName: '',
  );

  factory LearnProfile.fromJson(Map<String, dynamic> j) => LearnProfile(
    hearts: ((j['hearts'] ?? 5) as num).toInt(),
    unlimitedHearts: (j['unlimitedHearts'] ?? true) as bool,
    nextHeartInMs: j['nextHeartInMs'] == null
        ? null
        : ((j['nextHeartInMs'] as num).toInt()),
    gems: ((j['gems'] ?? 0) as num).toInt(),
    xp: ((j['xp'] ?? 0) as num).toInt(),
    streak: ((j['streak'] ?? 0) as num).toInt(),
    dailyGoal: ((j['dailyGoal'] ?? 50) as num).toInt(),
    todayXp: ((j['todayXp'] ?? 0) as num).toInt(),
    superActive: (j['superActive'] ?? false) as bool,
    boostActive: (j['boostActive'] ?? false) as bool,
    freezeCount: ((j['freezeCount'] ?? 0) as num).toInt(),
    league: (j['league'] ?? 'Bronze') as String,
    courseCount: ((j['courseCount'] ?? 0) as num).toInt(),
    topicsDone: ((j['topicsDone'] ?? 0) as num).toInt(),
    perfectCount: ((j['perfectCount'] ?? 0) as num).toInt(),
    institutionType: (j['institutionType'] ?? '') as String,
    department: (j['department'] ?? '') as String,
    departmentName: (j['departmentName'] ?? '') as String,
  );
}

/// One row of the course catalog (GET /learn/catalog items, and the
/// secondary bodies' selection lists).
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.title,
    required this.topicCount,
    required this.inList,
    this.faculty = '',
    this.institutionType = '',
    this.body = '',
    this.learnerCount = 0,
  });

  final String id;
  final String title;
  final String faculty;
  final String institutionType;
  final String body;
  final int topicCount;
  final bool inList;
  final int learnerCount;

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
    id: (j['id'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    faculty: (j['faculty'] ?? '') as String,
    institutionType: (j['institutionType'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    topicCount: ((j['topicCount'] ?? 0) as num).toInt(),
    inList: (j['inList'] ?? false) as bool,
    learnerCount: ((j['learnerCount'] ?? 0) as num).toInt(),
  );
}

/// GET /learn/my-courses row - one desk course with its progress.
class MyCourse {
  const MyCourse({
    required this.id,
    required this.title,
    required this.topicCount,
    required this.completedTopics,
    required this.bestScoreSum,
    required this.active,
    this.body = '',
  });

  final String id;
  final String title;
  final String body;
  final int topicCount;
  final int completedTopics;
  final int bestScoreSum;
  final bool active;

  factory MyCourse.fromJson(Map<String, dynamic> j) => MyCourse(
    id: (j['id'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    topicCount: ((j['topicCount'] ?? 0) as num).toInt(),
    completedTopics: ((j['completedTopics'] ?? 0) as num).toInt(),
    bestScoreSum: ((j['bestScoreSum'] ?? 0) as num).toInt(),
    active: (j['active'] ?? false) as bool,
  );
}

/// One topic bubble on the course PATH ladder.
class TopicNode {
  const TopicNode({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.unit,
    required this.status,
    required this.bestScore,
    this.category = '',
  });

  final String id;
  final String title;
  final String category;
  final int orderIndex;
  final int unit;
  final String status; // completed | current | locked
  final int bestScore;

  bool get isCompleted => status == 'completed';
  bool get isCurrent => status == 'current';

  factory TopicNode.fromJson(Map<String, dynamic> j) => TopicNode(
    id: (j['id'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    category: (j['category'] ?? '') as String,
    orderIndex: ((j['orderIndex'] ?? 0) as num).toInt(),
    unit: ((j['unit'] ?? 1) as num).toInt(),
    status: (j['status'] ?? 'locked') as String,
    bestScore: ((j['bestScore'] ?? 0) as num).toInt(),
  );
}

/// One unit banner of the ladder: topic range, its chest, its review.
class UnitNode {
  const UnitNode({
    required this.index,
    required this.name,
    required this.from,
    required this.to,
    required this.hasChest,
    required this.chestOpened,
    required this.reviewReady,
  });

  final int index;
  final String name;
  final int from;
  final int to;
  final bool hasChest;
  final bool chestOpened;
  final bool reviewReady;

  factory UnitNode.fromJson(Map<String, dynamic> j) => UnitNode(
    index: ((j['index'] ?? 1) as num).toInt(),
    name: (j['name'] ?? '') as String,
    from: ((j['from'] ?? 0) as num).toInt(),
    to: ((j['to'] ?? 0) as num).toInt(),
    hasChest: (j['hasChest'] ?? false) as bool,
    chestOpened: (j['chestOpened'] ?? false) as bool,
    reviewReady: (j['reviewReady'] ?? false) as bool,
  );
}

/// GET /learn/courses/{id} - the full PATH document.
class CoursePathModel {
  const CoursePathModel({
    required this.id,
    required this.title,
    required this.topics,
    required this.units,
    required this.completedPercent,
    required this.generating,
    this.body = '',
    this.institutionType = '',
    this.faculty = '',
    this.department = '',
  });

  final String id;
  final String title;
  final String body;
  final String institutionType;
  final String faculty;
  final String department;
  final List<TopicNode> topics;
  final List<UnitNode> units;
  final int completedPercent;
  final bool generating;

  factory CoursePathModel.fromJson(Map<String, dynamic> j) => CoursePathModel(
    id: (j['id'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    institutionType: (j['institutionType'] ?? '') as String,
    faculty: (j['faculty'] ?? '') as String,
    department: (j['department'] ?? '') as String,
    topics: ((j['topics'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => TopicNode.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    units: ((j['units'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => UnitNode.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    completedPercent: ((j['completedPercent'] ?? 0) as num).toInt(),
    generating: (j['generating'] ?? false) as bool,
  );
}

/// One course row of the tertiary desk (course-desk shelves).
class DeskCourse {
  const DeskCourse({
    required this.id,
    required this.code,
    required this.title,
    required this.topicCount,
    required this.inList,
    this.department = '',
  });

  final String id;
  final String code;
  final String title;
  final String department;
  final int topicCount;
  final bool inList;

  factory DeskCourse.fromJson(Map<String, dynamic> j) => DeskCourse(
    id: (j['id'] ?? '') as String,
    code: (j['code'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    department: (j['department'] ?? '') as String,
    topicCount: ((j['topicCount'] ?? 0) as num).toInt(),
    inList: (j['inList'] ?? false) as bool,
  );
}

/// GET /learn/course-desk - the tertiary semester shelves.
class DeskShelves {
  const DeskShelves({
    required this.institutionType,
    required this.department,
    required this.departmentName,
    required this.general,
    required this.departmental,
  });

  final String institutionType;
  final String department;
  final String departmentName;
  final List<DeskCourse> general;
  final List<DeskCourse> departmental;

  factory DeskShelves.fromJson(Map<String, dynamic> j) => DeskShelves(
    institutionType: (j['institutionType'] ?? '') as String,
    department: (j['department'] ?? '') as String,
    departmentName: (j['departmentName'] ?? '') as String,
    general: ((j['general'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => DeskCourse.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    departmental: ((j['departmental'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => DeskCourse.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// GET /learn/departments row - one department of an institution kind.
class DeskDepartment {
  const DeskDepartment({
    required this.id,
    required this.name,
    required this.courseCount,
    this.faculty = '',
    this.focus = '',
  });

  final String id;
  final String faculty;
  final String name;
  final String focus;
  final int courseCount;

  factory DeskDepartment.fromJson(Map<String, dynamic> j) => DeskDepartment(
    id: (j['id'] ?? '') as String,
    faculty: (j['faculty'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    focus: (j['focus'] ?? '') as String,
    courseCount: ((j['courseCount'] ?? 0) as num).toInt(),
  );
}

/// POST /learn/ai-match line - one pasted course title and its matches.
class AIMatchLine {
  const AIMatchLine({required this.input, required this.matches, this.picked});

  final String input;
  final List<DeskCourse> matches;
  final String? picked;

  factory AIMatchLine.fromJson(Map<String, dynamic> j) => AIMatchLine(
    input: (j['input'] ?? '') as String,
    matches: ((j['matches'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => DeskCourse.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    picked: j['picked'] as String?,
  );
}

// --------------------------------------------------------------- lessons

/// One section of the lesson's study phase.
class LessonNote {
  const LessonNote({required this.heading, required this.body, this.image, this.imageAlt});

  final String heading;
  final String body;
  final String? image;
  final String? imageAlt;

  factory LessonNote.fromJson(Map<String, dynamic> j) => LessonNote(
    heading: (j['heading'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    image: j['image'] as String?,
    imageAlt: j['imageAlt'] as String?,
  );
}

/// One quiz item (AI-generated or a real past question from the bank).
class LessonQuizQ {
  const LessonQuizQ({
    required this.id,
    required this.type,
    required this.stem,
    required this.answer,
    this.options = const <String, String>{},
    this.explanation = '',
    this.year = 0,
    this.fromBank = false,
  });

  final String id;
  final String type; // mcq | true_false | fill_blank | word_bank
  final String stem;
  final Map<String, String> options;
  final String answer;
  final String explanation;
  final int year;
  final bool fromBank;

  bool get isTypeIn => type == 'fill_blank' || type == 'word_bank';

  factory LessonQuizQ.fromJson(Map<String, dynamic> j) => LessonQuizQ(
    id: (j['id'] ?? '') as String,
    type: (j['type'] ?? 'mcq') as String,
    stem: (j['stem'] ?? '') as String,
    options: ((j['options'] ?? const <String, String>{}) as Map<dynamic, dynamic>)
        .map((dynamic k, dynamic v) => MapEntry(k.toString(), v.toString())),
    answer: (j['answer'] ?? '') as String,
    explanation: (j['explanation'] ?? '') as String,
    year: ((j['year'] ?? 0) as num).toInt(),
    fromBank: (j['fromBank'] ?? false) as bool,
  );
}

/// One curated drawing (server-side SVG, currentColor strokes).
class LearnDrawing {
  const LearnDrawing({required this.id, required this.title, required this.svg});

  final String id;
  final String title;
  final String svg;

  factory LearnDrawing.fromJson(Map<String, dynamic> j) => LearnDrawing(
    id: (j['id'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    svg: (j['svg'] ?? '') as String,
  );
}

/// GET /learn/topics/{id}/content - the full lesson document.
class LessonDoc {
  const LessonDoc({
    required this.topicId,
    required this.courseId,
    required this.course,
    required this.title,
    required this.summary,
    required this.notes,
    required this.keyPoints,
    required this.quiz,
    required this.drawings,
    required this.source,
    required this.cached,
  });

  final String topicId;
  final String courseId;
  final String course;
  final String title;
  final String summary;
  final List<LessonNote> notes;
  final List<String> keyPoints;
  final List<LessonQuizQ> quiz;
  final List<LearnDrawing> drawings;
  final String source;
  final bool cached;

  factory LessonDoc.fromJson(Map<String, dynamic> j) => LessonDoc(
    topicId: (j['topicId'] ?? '') as String,
    courseId: (j['courseId'] ?? '') as String,
    course: (j['course'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    summary: (j['summary'] ?? '') as String,
    notes: ((j['notes'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => LessonNote.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    keyPoints: ((j['keyPoints'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e.toString())
        .toList(),
    quiz: ((j['quiz'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => LessonQuizQ.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    drawings: ((j['drawings'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => LearnDrawing.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    source: (j['source'] ?? '') as String,
    cached: (j['cached'] ?? false) as bool,
  );
}

/// One randomized topic-chest reward.
class ChestDrop {
  const ChestDrop({
    required this.kind,
    required this.amount,
    required this.icon,
    required this.label,
  });

  final String kind; // gems | freeze | boost
  final int amount;
  final String icon;
  final String label;

  factory ChestDrop.fromJson(Map<String, dynamic> j) => ChestDrop(
    kind: (j['kind'] ?? 'gems') as String,
    amount: ((j['amount'] ?? 0) as num).toInt(),
    icon: (j['icon'] ?? 'diamond') as String,
    label: (j['label'] ?? '') as String,
  );
}

/// The achievement the platform just posted to the feed.
class MilestoneInfo {
  const MilestoneInfo({required this.code, required this.label});

  final String code;
  final String label;

  factory MilestoneInfo.fromJson(Map<String, dynamic> j) => MilestoneInfo(
    code: (j['code'] ?? '') as String,
    label: (j['label'] ?? '') as String,
  );
}

/// POST /learn/progress result - every reward the run paid.
class CompleteResult {
  const CompleteResult({
    required this.xpEarned,
    required this.gemsEarned,
    required this.perfect,
    required this.firstClear,
    required this.comboBonus,
    required this.boosted,
    required this.streak,
    required this.streakUp,
    required this.unlimitedHearts,
    required this.hearts,
    required this.gems,
    required this.xp,
    required this.completedPercent,
    this.streakForgiven = false,
    this.streakForgivesLeft = 0,
    this.chest,
    this.milestone,
  });

  final int xpEarned;
  final int gemsEarned;
  final bool perfect;
  final bool firstClear;
  final int comboBonus;
  final bool boosted;
  final int streak;
  final bool streakUp;
  final bool streakForgiven;
  final int streakForgivesLeft;
  final int hearts;
  final bool unlimitedHearts;
  final int gems;
  final int xp;
  final int completedPercent;
  final ChestDrop? chest;
  final MilestoneInfo? milestone;

  factory CompleteResult.fromJson(Map<String, dynamic> j) => CompleteResult(
    xpEarned: ((j['xpEarned'] ?? 0) as num).toInt(),
    gemsEarned: ((j['gemsEarned'] ?? 0) as num).toInt(),
    perfect: (j['perfect'] ?? false) as bool,
    firstClear: (j['firstClear'] ?? false) as bool,
    comboBonus: ((j['comboBonus'] ?? 0) as num).toInt(),
    boosted: (j['boosted'] ?? false) as bool,
    streak: ((j['streak'] ?? 0) as num).toInt(),
    streakUp: (j['streakUp'] ?? false) as bool,
    streakForgiven: (j['streakForgiven'] ?? false) as bool,
    streakForgivesLeft: ((j['streakForgivesLeft'] ?? 0) as num).toInt(),
    hearts: ((j['hearts'] ?? 5) as num).toInt(),
    unlimitedHearts: (j['unlimitedHearts'] ?? true) as bool,
    gems: ((j['gems'] ?? 0) as num).toInt(),
    xp: ((j['xp'] ?? 0) as num).toInt(),
    completedPercent: ((j['completedPercent'] ?? 0) as num).toInt(),
    chest: j['chest'] == null
        ? null
        : ChestDrop.fromJson((j['chest'] as Map).cast<String, dynamic>()),
    milestone: j['milestone'] == null
        ? null
        : MilestoneInfo.fromJson((j['milestone'] as Map).cast<String, dynamic>()),
  );
}

/// GET|POST /learn/practice, GET /learn/review, GET /learn/revision -
/// every practice surface serves the same question set envelope.
class PracticeSet {
  const PracticeSet({required this.questions});

  final List<LessonQuizQ> questions;

  factory PracticeSet.fromJson(Map<String, dynamic> j) => PracticeSet(
    questions: ((j['questions'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => LessonQuizQ.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

// ---------------------------------------------------------------- quests

/// One quest with its live state (GET /learn/quests row).
class QuestOut {
  const QuestOut({
    required this.key,
    required this.title,
    required this.target,
    required this.gems,
    required this.kind,
    required this.icon,
    required this.period,
    required this.periodKey,
    required this.progress,
    required this.claimed,
    required this.complete,
  });

  final String key;
  final String title;
  final int target;
  final int gems;
  final String kind;
  final String icon;
  final String period; // daily | weekly | monthly
  final String periodKey;
  final int progress;
  final bool claimed;
  final bool complete;

  factory QuestOut.fromJson(Map<String, dynamic> j) => QuestOut(
    key: (j['key'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    target: ((j['target'] ?? 0) as num).toInt(),
    gems: ((j['gems'] ?? 0) as num).toInt(),
    kind: (j['kind'] ?? 'xp') as String,
    icon: (j['icon'] ?? 'bolt') as String,
    period: (j['period'] ?? 'daily') as String,
    periodKey: (j['periodKey'] ?? '') as String,
    progress: ((j['progress'] ?? 0) as num).toInt(),
    claimed: (j['claimed'] ?? false) as bool,
    complete: (j['complete'] ?? false) as bool,
  );
}

class QuestsResponse {
  const QuestsResponse({required this.daily, required this.weekly, required this.monthly});

  final List<QuestOut> daily;
  final QuestOut weekly;
  final QuestOut monthly;

  factory QuestsResponse.fromJson(Map<String, dynamic> j) => QuestsResponse(
    daily: ((j['daily'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => QuestOut.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    weekly: QuestOut.fromJson(
      ((j['weekly'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>(),
    ),
    monthly: QuestOut.fromJson(
      ((j['monthly'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>(),
    ),
  );
}

// ------------------------------------------------------------------ shop

/// One gem-shop item.
class ShopItem {
  const ShopItem({
    required this.key,
    required this.title,
    required this.desc,
    required this.gems,
    required this.icon,
    required this.owned,
    required this.max,
    required this.soldOut,
  });

  final String key; // freeze | heart_refill | boost
  final String title;
  final String desc;
  final int gems;
  final String icon;
  final int owned;
  final int max;
  final bool soldOut;

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
    key: (j['key'] ?? '') as String,
    title: (j['title'] ?? '') as String,
    desc: (j['desc'] ?? '') as String,
    gems: ((j['gems'] ?? 0) as num).toInt(),
    icon: (j['icon'] ?? 'diamond') as String,
    owned: ((j['owned'] ?? 0) as num).toInt(),
    max: ((j['max'] ?? 0) as num).toInt(),
    soldOut: (j['soldOut'] ?? false) as bool,
  );
}

/// GET /learn/shop - the wallet plus the item list.
class ShopResponse {
  const ShopResponse({
    required this.gems,
    required this.hearts,
    required this.items,
    required this.superTrial,
  });

  final int gems;
  final int hearts;
  final List<ShopItem> items;
  final ShopItem superTrial;

  factory ShopResponse.fromJson(Map<String, dynamic> j) => ShopResponse(
    gems: ((j['gems'] ?? 0) as num).toInt(),
    hearts: ((j['hearts'] ?? 5) as num).toInt(),
    items: ((j['items'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => ShopItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    superTrial: ShopItem.fromJson(
      ((j['superTrial'] ?? <String, dynamic>{}) as Map).cast<String, dynamic>(),
    ),
  );
}

/// POST /learn/chests result - the unit chest's gem payout.
class ChestOpenResult {
  const ChestOpenResult({required this.chestKey, required this.gems, required this.gemsTotal});

  final String chestKey;
  final int gems;
  final int gemsTotal;

  factory ChestOpenResult.fromJson(Map<String, dynamic> j) => ChestOpenResult(
    chestKey: (j['chestKey'] ?? '') as String,
    gems: ((j['gems'] ?? 0) as num).toInt(),
    gemsTotal: ((j['gemsTotal'] ?? 0) as num).toInt(),
  );
}

// ---------------------------------------------------------------- league

/// One row of the weekly XP league board.
class LeagueEntry {
  const LeagueEntry({
    required this.name,
    required this.xp,
    required this.isYou,
    required this.isReal,
    this.username = '',
    this.color = '',
  });

  final String name;
  final int xp;
  final String color;
  final bool isYou;
  final String username;
  final bool isReal;

  factory LeagueEntry.fromJson(Map<String, dynamic> j) => LeagueEntry(
    name: (j['name'] ?? '') as String,
    xp: ((j['xp'] ?? 0) as num).toInt(),
    color: (j['color'] ?? '') as String,
    isYou: (j['isYou'] ?? false) as bool,
    username: (j['username'] ?? '') as String,
    isReal: (j['isReal'] ?? true) as bool,
  );
}

/// GET /learn/leaderboard - one tier's board with the reset clock.
class LeagueBoard {
  const LeagueBoard({
    required this.league,
    required this.leagueIndex,
    required this.leagues,
    required this.viewing,
    required this.entries,
    required this.endsInMs,
    required this.promotedCut,
    required this.demotedFrom,
    required this.yourRank,
    this.promotedLastWeek = false,
    this.demotedLastWeek = false,
  });

  final String league;
  final int leagueIndex;
  final List<String> leagues;
  final bool viewing;
  final List<LeagueEntry> entries;
  final int endsInMs;
  final int promotedCut;
  final int demotedFrom;
  final bool promotedLastWeek;
  final bool demotedLastWeek;
  final int yourRank;

  factory LeagueBoard.fromJson(Map<String, dynamic> j) => LeagueBoard(
    league: (j['league'] ?? 'Bronze') as String,
    leagueIndex: ((j['leagueIndex'] ?? 0) as num).toInt(),
    leagues: ((j['leagues'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => e.toString())
        .toList(),
    viewing: (j['viewing'] ?? false) as bool,
    entries: ((j['entries'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => LeagueEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    endsInMs: ((j['endsInMs'] ?? 0) as num).toInt(),
    promotedCut: ((j['promotedCut'] ?? 7) as num).toInt(),
    demotedFrom: ((j['demotedFrom'] ?? 26) as num).toInt(),
    promotedLastWeek: (j['promotedLastWeek'] ?? false) as bool,
    demotedLastWeek: (j['demotedLastWeek'] ?? false) as bool,
    yourRank: ((j['yourRank'] ?? 0) as num).toInt(),
  );
}

// ---------------------------------------------------------------- social

/// The author block of a feed post / comment / follow row.
class SocialAuthor {
  const SocialAuthor({
    required this.id,
    required this.username,
    required this.name,
    required this.premium,
    this.avatar,
    this.photo,
  });

  final String id;
  final String username;
  final String name;
  final bool premium;
  final String? avatar;

  /// The uploaded R2 photo key (founder 2026-10-22 identity pass): set
  /// whenever the scholar uploaded a profile picture - it wins over
  /// [avatar] exactly like the web's one-wins rule.
  final String? photo;

  factory SocialAuthor.fromJson(Map<String, dynamic> j) => SocialAuthor(
    id: (j['id'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    premium: (j['premium'] ?? false) as bool,
    avatar: j['avatar'] as String?,
    photo: j['photo'] as String?,
  );
}

/// The milestone metadata a platform post carries.
class SocialMeta {
  const SocialMeta({this.streak, this.league, this.score, this.exam, this.course, this.matchId});

  final int? streak;
  final String? league;
  final int? score;
  final String? exam;
  final String? course;
  final String? matchId;

  factory SocialMeta.fromJson(Map<String, dynamic> j) => SocialMeta(
    streak: j['streak'] == null ? null : ((j['streak'] as num).toInt()),
    league: j['league'] as String?,
    score: j['score'] == null ? null : ((j['score'] as num).toInt()),
    exam: j['exam'] as String?,
    course: j['course'] as String?,
    matchId: j['matchId'] as String?,
  );
}

/// One feed post (platform milestone or user post).
class SocialPost {
  const SocialPost({
    required this.id,
    required this.kind,
    required this.body,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    required this.mine,
    required this.createdAtMs,
    required this.author,
    this.meta,
  });

  final int id;
  final SocialAuthor? author;
  final String kind; // user | milestone
  final String body;
  final SocialMeta? meta;
  final int likes;
  final int comments;
  final bool likedByMe;
  final bool mine;
  final int createdAtMs;

  bool get isMilestone => kind == 'milestone';

  factory SocialPost.fromJson(Map<String, dynamic> j) => SocialPost(
    id: ((j['id'] ?? 0) as num).toInt(),
    author: j['author'] == null
        ? null
        : SocialAuthor.fromJson((j['author'] as Map).cast<String, dynamic>()),
    kind: (j['kind'] ?? 'user') as String,
    body: (j['body'] ?? '') as String,
    meta: j['meta'] == null
        ? null
        : SocialMeta.fromJson((j['meta'] as Map).cast<String, dynamic>()),
    likes: ((j['likes'] ?? 0) as num).toInt(),
    comments: ((j['comments'] ?? 0) as num).toInt(),
    likedByMe: (j['likedByMe'] ?? false) as bool,
    mine: (j['mine'] ?? false) as bool,
    createdAtMs: ((j['createdAtMs'] ?? 0) as num).toInt(),
  );
}

/// One comment row.
class SocialComment {
  const SocialComment({
    required this.id,
    required this.body,
    required this.mine,
    required this.createdAtMs,
    required this.author,
  });

  final int id;
  final SocialAuthor? author;
  final String body;
  final bool mine;
  final int createdAtMs;

  factory SocialComment.fromJson(Map<String, dynamic> j) => SocialComment(
    id: ((j['id'] ?? 0) as num).toInt(),
    author: j['author'] == null
        ? null
        : SocialAuthor.fromJson((j['author'] as Map).cast<String, dynamic>()),
    body: (j['body'] ?? '') as String,
    mine: (j['mine'] ?? false) as bool,
    createdAtMs: ((j['createdAtMs'] ?? 0) as num).toInt(),
  );
}

/// One course progress bar on a public profile ("Taking").
class CoursePulse {
  const CoursePulse({
    required this.title,
    required this.body,
    required this.topics,
    required this.done,
    required this.percent,
  });

  final String title;
  final String body;
  final int topics;
  final int done;
  final int percent;

  factory CoursePulse.fromJson(Map<String, dynamic> j) => CoursePulse(
    title: (j['title'] ?? '') as String,
    body: (j['body'] ?? '') as String,
    topics: ((j['topics'] ?? 0) as num).toInt(),
    done: ((j['done'] ?? 0) as num).toInt(),
    percent: ((j['percent'] ?? 0) as num).toInt(),
  );
}

/// GET /social/users/{username} - the public profile.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.premium,
    required this.level,
    required this.xp,
    required this.streak,
    required this.league,
    required this.topicsDone,
    required this.perfectCount,
    required this.followers,
    required this.following,
    required this.isFollowing,
    required this.isSelf,
    required this.joinedMs,
    required this.courses,
    this.avatar,
    this.photo,
    this.institution,
    this.followsYou = false,
  });

  final String id;
  final String username;
  final String name;
  final bool premium;
  final String? avatar;
  final int level;
  final int xp;
  final int streak;
  final String league;
  final int topicsDone;
  final int perfectCount;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool followsYou;
  final bool isSelf;
  final int joinedMs;
  final List<CoursePulse> courses;

  /// The uploaded R2 photo key (founder 2026-10-22): wins over [avatar].
  final String? photo;

  /// The scholar's school / institution (founder 2026-10-22: the
  /// profile wears the school like every other identity field).
  final String? institution;

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    id: (j['id'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    premium: (j['premium'] ?? false) as bool,
    avatar: j['avatar'] as String?,
    level: ((j['level'] ?? 1) as num).toInt(),
    xp: ((j['xp'] ?? 0) as num).toInt(),
    streak: ((j['streak'] ?? 0) as num).toInt(),
    league: (j['league'] ?? 'Bronze') as String,
    topicsDone: ((j['topicsDone'] ?? 0) as num).toInt(),
    perfectCount: ((j['perfectCount'] ?? 0) as num).toInt(),
    followers: ((j['followers'] ?? 0) as num).toInt(),
    following: ((j['following'] ?? 0) as num).toInt(),
    isFollowing: (j['isFollowing'] ?? false) as bool,
    followsYou: (j['followsYou'] ?? false) as bool,
    isSelf: (j['isSelf'] ?? false) as bool,
    joinedMs: ((j['joinedMs'] ?? 0) as num).toInt(),
    photo: j['photo'] as String?,
    institution: j['institution'] as String?,
    courses: ((j['courses'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => CoursePulse.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// One follower / following row.
class FollowRow {
  const FollowRow({
    required this.id,
    required this.username,
    required this.name,
    required this.premium,
    required this.followsYou,
    required this.following,
    this.avatar,
    this.photo,
  });

  final String id;
  final String username;
  final String name;
  final bool premium;
  final String? avatar;

  /// The uploaded R2 photo key (founder 2026-10-22 identity pass).
  final String? photo;
  final bool followsYou;
  final bool following;

  factory FollowRow.fromJson(Map<String, dynamic> j) => FollowRow(
    id: (j['id'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    premium: (j['premium'] ?? false) as bool,
    avatar: j['avatar'] as String?,
    photo: j['photo'] as String?,
    followsYou: (j['followsYou'] ?? false) as bool,
    following: (j['following'] ?? false) as bool,
  );
}

/// GET /social/connections.
class SocialConnections {
  const SocialConnections({required this.followers, required this.following});

  final List<FollowRow> followers;
  final List<FollowRow> following;

  factory SocialConnections.fromJson(Map<String, dynamic> j) => SocialConnections(
    followers: ((j['followers'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => FollowRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    following: ((j['following'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => FollowRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}

// ------------------------------------------------------------- gems board

/// GET /leaderboard/gems row.
class GemsBoardEntry {
  const GemsBoardEntry({
    required this.rank,
    required this.username,
    required this.gems,
    required this.xp,
    required this.streak,
    this.userId = '',
    this.premium = false,
  });

  final int rank;
  final String userId;
  final String username;
  final int gems;
  final int xp;
  final int streak;
  final bool premium;

  factory GemsBoardEntry.fromJson(Map<String, dynamic> j) => GemsBoardEntry(
    rank: ((j['rank'] ?? 0) as num).toInt(),
    userId: (j['userId'] ?? '') as String,
    username: (j['username'] ?? '') as String,
    gems: ((j['gems'] ?? 0) as num).toInt(),
    xp: ((j['xp'] ?? 0) as num).toInt(),
    streak: ((j['streak'] ?? 0) as num).toInt(),
    premium: (j['premium'] ?? false) as bool,
  );
}

/// GET /leaderboard/gems envelope.
class GemsLeaderboardData {
  const GemsLeaderboardData({required this.entries, this.me});

  final List<GemsBoardEntry> entries;
  final GemsBoardEntry? me;

  factory GemsLeaderboardData.fromJson(Map<String, dynamic> j) => GemsLeaderboardData(
    entries: ((j['entries'] ?? const <dynamic>[]) as List<dynamic>)
        .map((dynamic e) => GemsBoardEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    me: j['me'] == null
        ? null
        : GemsBoardEntry.fromJson((j['me'] as Map).cast<String, dynamic>()),
  );
}
