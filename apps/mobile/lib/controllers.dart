/// State controllers: silent asset sync (SyncController) and the CBT
/// player (ExamController). Both are plain ChangeNotifiers driven by
/// injectable collaborators, so every rule is unit-testable.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';
import 'storage.dart';

// ------------------------------------------------------------ sync controller

enum SyncPhase { idle, syncing, ready, error }

/// Silent background asset sync, mobile flavour:
/// profile exams decide WHAT to pull ("only what you need"), the manifest
/// sha256 decides WHETHER a local copy is current, and nothing blocks the UI.
class SyncController extends ChangeNotifier {
  SyncController({required ApiClient api, required PackStore store})
      : _api = api,
        _store = store;

  final ApiClient _api;
  final PackStore _store;

  SyncPhase phase = SyncPhase.idle;
  String message = '';
  List<ExamMeta> exams = <ExamMeta>[];
  int done = 0;
  int total = 0;
  int pendingCount = 0;

  bool get isSyncing => phase == SyncPhase.syncing;

  /// Let UI surfaces (e.g. /me failures) route errors through the
  /// controller instead of poking notifyListeners from outside.
  void surfaceFailure(String message) {
    phase = SyncPhase.error;
    this.message = message;
    notifyListeners();
  }

  /// Fetch the manifest and download every pack the student needs but
  /// does not yet hold (or holds under an older sha).
  Future<void> bootstrap({List<String> profileExams = const <String>[]}) async {
    phase = SyncPhase.syncing;
    message = 'Contacting Renance servers…';
    done = 0;
    notifyListeners();
    try {
      final manifest = await _api.manifest();
      exams = manifest.exams;
      final needed = _neededFor(profileExams);
      final have = await _store.downloadedCodes();
      final missing = needed
          .where((e) => !have.contains(e.code))
          .toList(growable: false);
      total = missing.length;
      for (final exam in missing) {
        message = 'Downloading ${exam.title}…';
        notifyListeners();
        final bundle = await _api.bundle(exam.code);
        await _store.savePack(bundle, exam.bundleSha256);
        done += 1;
        notifyListeners();
      }
      await refreshPendingCount();
      phase = SyncPhase.ready;
      message = total == 0
          ? '${exams.length} packs available · ${have.length} on device'
          : 'Synced $done/$total packs';
    } on ApiException catch (e) {
      phase = SyncPhase.error;
      message = e.message;
    } on NetworkException catch (e) {
      phase = SyncPhase.error;
      message = e.message;
    }
    notifyListeners();
  }

  /// Need-based filter (founder rule: the app downloads what the student
  /// is studying for). Falls back to everything when nothing matches —
  /// an empty library helps nobody.
  List<ExamMeta> _neededFor(List<String> profileExams) {
    if (profileExams.isEmpty) return exams;
    final wanted = exams
        .where((e) =>
            profileExams.contains(e.body) || profileExams.contains(e.category))
        .toList(growable: false);
    return wanted.isEmpty ? exams : wanted;
  }

  /// Download a single pack on demand (e.g. tapping a not-yet-offline card).
  Future<bool> downloadExam(ExamMeta exam) async {
    try {
      final bundle = await _api.bundle(exam.code);
      await _store.savePack(bundle, exam.bundleSha256);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      message = e.message;
      notifyListeners();
      return false;
    } on NetworkException catch (e) {
      message = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Flush the offline submission queue. Network failures keep entries;
  /// permanent server decisions (e.g. already submitted) clear them.
  Future<void> retryPending() async {
    final pending = await _store.pendingSubmissions();
    for (final item in pending) {
      try {
        await _api.submit(item.attemptId, item.answers, item.durationMs);
        await _store.removeSubmission(item.id);
      } on ApiException {
        await _store.removeSubmission(item.id);
        break;
      } on NetworkException {
        break; // still offline — try again later
      }
    }
    await refreshPendingCount();
  }

  Future<void> refreshPendingCount() async {
    pendingCount = (await _store.pendingSubmissions()).length;
    notifyListeners();
  }
}

// ------------------------------------------------------------ exam controller

enum ExamPhase { loading, intro, playing, grading, queued, graded, error }

/// The CBT player state machine. Offline submissions are queued in the
/// PackStore and SyncController.retryPending() flushes them later.
class ExamController extends ChangeNotifier {
  ExamController({required ApiClient api, required PackStore store})
      : _api = api,
        _store = store;

  final ApiClient _api;
  final PackStore _store;

  ExamPhase phase = ExamPhase.loading;
  ExamMeta? meta;
  Bundle? bundle;
  ExamResult? result;
  String? error;

  int index = 0;
  int secondsRemaining = 0;
  final Map<String, String> answers = <String, String>{};
  final Set<String> flags = <String>{};

  String? _attemptId;
  int? _durationMs;
  DateTime _startedAt = DateTime.now();
  Timer? _timer;
  final Duration _pollDelay = const Duration(milliseconds: 1200);
  final int _pollBudget = 40;

  /// Visible to tests only.
  static const Duration pollWait = Duration(milliseconds: 1200);

  BundleQuestion? get current =>
      bundle == null || index >= bundle!.questions.length
          ? null
          : bundle!.questions[index];

  int get answeredCount => answers.length;

  Future<void> load(ExamMeta examMeta) async {
    meta = examMeta;
    phase = ExamPhase.loading;
    error = null;
    result = null;
    notifyListeners();
    final cached = await _store.loadPack(examMeta.code, examMeta.bundleSha256);
    if (cached != null) {
      bundle = cached;
    } else {
      try {
        final fetched = await _api.bundle(examMeta.code);
        await _store.savePack(fetched, examMeta.bundleSha256);
        bundle = fetched;
      } on ApiException catch (e) {
        error = e.message;
        phase = ExamPhase.error;
        notifyListeners();
        return;
      } on NetworkException catch (e) {
        error = e.message;
        phase = ExamPhase.error;
        notifyListeners();
        return;
      }
    }
    index = 0;
    answers.clear();
    flags.clear();
    phase = ExamPhase.intro;
    notifyListeners();
  }

  Future<void> begin() async {
    if (bundle == null) return;
    try {
      final started =
          await _api.createAttempt(bundle!.code);
      _attemptId = started.attemptId;
    } on ApiException catch (e) {
      error = e.message;
      phase = ExamPhase.error;
      notifyListeners();
      return;
    } on NetworkException {
      // Offline entry is allowed: paper runs fully on-device and the
      // attempt row is created server-side at submission time.
      _attemptId = 'offline-${DateTime.now().millisecondsSinceEpoch}';
      error = null;
    }
    secondsRemaining = (bundle!.durationMinutes ?? 30) * 60;
    _startedAt = DateTime.now();
    phase = ExamPhase.playing;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  /// One second of exam time. Called by the periodic timer; public so
  /// tests can drive the clock deterministically.
  Future<void> tick() async {
    if (phase != ExamPhase.playing) return;
    if (secondsRemaining > 0) {
      secondsRemaining -= 1;
      notifyListeners();
    }
    if (secondsRemaining == 0) {
      await submit();
    }
  }

  void select(String questionId, String letter) {
    answers[questionId] = letter;
    notifyListeners();
  }

  void toggleFlag(String questionId) {
    if (!flags.add(questionId)) {
      flags.remove(questionId);
    }
    notifyListeners();
  }

  void goTo(int i) {
    if (bundle == null) return;
    index = i.clamp(0, bundle!.questions.length - 1);
    notifyListeners();
  }

  void next() => goTo(index + 1);
  void previous() => goTo(index - 1);

  Future<void> submit() async {
    if (phase != ExamPhase.playing || bundle == null || _attemptId == null) {
      return;
    }
    _timer?.cancel();
    final durationMs = DateTime.now().difference(_startedAt).inMilliseconds;
    _durationMs = durationMs;
    phase = ExamPhase.grading;
    notifyListeners();

    // Paper answered but attempt row never reached the server (user went
    // offline before Begin hit the API) → straight to the queue.
    if (_attemptId!.startsWith('offline-')) {
      await _queueOffline(durationMs);
      return;
    }

    try {
      await _api.submit(_attemptId!, Map.of(answers), durationMs);
      await _poll();
    } on NetworkException {
      await _queueOffline(durationMs);
    } on ApiException catch (e) {
      error = e.message;
      phase = ExamPhase.error;
      notifyListeners();
    }
  }

  Future<void> _queueOffline(int durationMs) async {
    await _store.queueSubmission(PendingSubmission(
      id: _attemptId!,
      code: bundle!.code,
      attemptId: _attemptId!,
      answers: Map.of(answers),
      durationMs: durationMs,
      createdAt: DateTime.now(),
    ));
    phase = ExamPhase.queued;
    notifyListeners();
  }

  Future<void> _poll() async {
    for (var i = 0; i < _pollBudget; i++) {
      try {
        final view = await _api.attempt(_attemptId!);
        if (view.status == 'graded' && view.result != null) {
          result = view.result;
          phase = ExamPhase.graded;
          notifyListeners();
          return;
        }
        if (view.status == 'error') {
          error = 'Grading hit an error — please try again.';
          phase = ExamPhase.error;
          notifyListeners();
          return;
        }
        await Future<void>.delayed(_pollDelay);
      } on NetworkException {
        await _queueOffline(
            DateTime.now().difference(_startedAt).inMilliseconds);
        return;
      }
    }
    error = 'Grading is taking unusually long. Check back from the dashboard.';
    phase = ExamPhase.error;
    notifyListeners();
  }

  String? get attemptId => _attemptId;

  /// Wall-clock duration of the sitting (results screen "Time Used").
  int? get durationMsUsed => _durationMs;

  void backToIntro() {
    _timer?.cancel();
    phase = bundle == null ? ExamPhase.loading : ExamPhase.intro;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------- student controller

/// Everything the shell chrome and tab screens read: /me, gamification,
/// paper history, the SM-2 review queue. One refresh() populates the
/// launcher hero card, the streak pill, the review backlog, the due badge
/// and the profile stat strip.
class StudentController extends ChangeNotifier {
  StudentController({required ApiClient api, required PackStore store})
      : _api = api,
        _store = store;

  final ApiClient _api;
  final PackStore _store;

  MeResult? me;
  GamificationSummary? gamification;
  ReviewSummary? review;
  List<AttemptRow> attempts = <AttemptRow>[];
  Set<String> downloaded = <String>{};
  bool loading = false;
  String? error;

  bool get hasProfile => me?.profile?.completed ?? false;

  /// "NEXT TARGET — UTME 2027" hero title from the onboarding pick.
  String get targetTitle {
    final p = me?.profile;
    if (p == null || p.exams.isEmpty) return 'Set your target';
    final String exam = p.exams.first;
    final label = switch (exam) {
      'JAMB' => 'UTME',
      'WAEC' => 'WASSCE',
      'NECO' => 'NECO',
      'University Modules' => 'Semester',
      _ => exam,
    };
    return p.targetYear != null ? '$label ${p.targetYear}' : label;
  }

  /// Exam-target chip copy on the profile screen ("JAMB 2027").
  String get targetChip {
    final p = me?.profile;
    if (p == null || p.exams.isEmpty) return 'No target yet';
    final exam = p.exams.first;
    return p.targetYear != null ? '$exam ${p.targetYear}' : exam;
  }

  /// Days until the target exam. JAMB/UTME sits in late April, so May 1
  /// of the target year is the planning estimate the hero card shows.
  int? get daysToTarget {
    final year = me?.profile?.targetYear;
    if (year == null) return null;
    final examDay = DateTime(year, 5, 1);
    final now = DateTime.now();
    return examDay.difference(now).inDays;
  }

  /// % of the student's packs with at least one graded attempt — the real
  /// number behind the hero card's "Syllabus Completion" bar.
  int get coveragePct {
    final p = me?.profile;
    if (p == null) return 0;
    final gradedCodes = attempts.where((a) => a.isGraded).map((a) => a.code).toSet();
    final relevant = attempts.isEmpty
        ? <String>{
            for (final e in downloaded) e,
          }
        : gradedCodes;
    if (relevant.isEmpty) return 0;
    return (gradedCodes.length * 100 ~/ relevant.length).clamp(0, 100);
  }

  /// Total questions missed across graded papers.
  int get questionsToReview =>
      attempts.fold(0, (sum, a) => sum + a.missed);

  /// Topics the spaced-repetition engine says are due today (or overdue) —
  /// the number behind the Review Due badge and the review hero card.
  int get dueTopics => review?.stats.due ?? 0;

  /// Due + overdue + upcoming rows, in server order (oldest due first).
  List<ReviewItem> get queuePreview => <ReviewItem>[
        ...review?.due ?? const <ReviewItem>[],
        ...review?.upcoming ?? const <ReviewItem>[],
      ];

  /// Questions answered today (daily quest progress, all packs).
  int get todayQuestions {
    final now = DateTime.now();
    return attempts
        .where((a) =>
            a.submittedAt != null &&
            a.submittedAt!.year == now.year &&
            a.submittedAt!.month == now.month &&
            a.submittedAt!.day == now.day)
        .fold(0, (sum, a) => sum + (a.total ?? 0));
  }

  /// Overall accuracy across graded papers (profile stat strip).
  int get accuracyPct {
    int correct = 0, total = 0;
    for (final a in attempts.where((a) => a.isGraded)) {
      correct += a.score!;
      total += a.total!;
    }
    if (total == 0) return 0;
    return correct * 100 ~/ total;
  }

  /// The most recent paper, for the launcher's recent-activity card.
  AttemptRow? get latestAttempt => attempts.isEmpty ? null : attempts.first;

  /// Title of a pack code from the manifest cache (best effort).
  String titleForCode(String code) {
    for (final exam in _manifestTitles.entries) {
      if (exam.key == code) return exam.value;
    }
    return code;
  }

  final Map<String, String> _manifestTitles = <String, String>{};

  void cacheManifestTitles(List<ExamMeta> exams) {
    for (final e in exams) {
      _manifestTitles[e.code] = e.title;
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        _api.me(),
        _api.gamification(),
        _api.attempts(),
        _store.downloadedCodes(),
        _api.reviewQueue(),
      ]);
      me = results[0] as MeResult;
      gamification = results[1] as GamificationSummary;
      attempts = results[2] as List<AttemptRow>;
      downloaded = results[3] as Set<String>;
      review = results[4] as ReviewSummary;
    } on ApiException catch (e) {
      error = e.message;
    } on NetworkException catch (e) {
      error = e.message;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refreshDownloaded() async {
    downloaded = await _store.downloadedCodes();
    notifyListeners();
  }
}
