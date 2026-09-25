/// State controllers: silent asset sync (SyncController) and the CBT
/// player (ExamController). Both are plain ChangeNotifiers driven by
/// injectable collaborators, so every rule is unit-testable.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'audio_summary.dart';
import 'models.dart';
import 'papers.dart' show isComposedPaperCode;
import 'storage.dart';
import 'tts.dart';

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

  /// The exam bodies present in the synced manifest (JAMB | WAEC | NECO
  /// | University Modules), insertion-stable - the library shelf chips'
  /// data.
  Set<String> get shelfBodies =>
      exams.map((ExamMeta e) => e.body).where((String b) => b.isNotEmpty).toSet();

  /// Let UI surfaces (e.g. /me failures) route errors through the
  /// controller instead of poking notifyListeners from outside.
  void surfaceFailure(String message) {
    phase = SyncPhase.error;
    this.message = message;
    notifyListeners();
  }

  /// Fetch the manifest and download every pack the student needs but
  /// does not yet hold (or holds under an older sha). Each pack gets a
  /// retry with a short backoff; one flaky pack never abandons the rest
  /// of the sync - the failure list only surfaces when packs actually
  /// failed, and a later bootstrap silently fills the holes.
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
      int failed = 0;
      for (final exam in missing) {
        message = 'Downloading ${exam.title}… ($done/$total)';
        notifyListeners();
        bool saved = false;
        // Two passes per pack: an instant retry catches the common
        // mobile-network stall that kills the first attempt.
        for (var attempt = 0; attempt < 2 && !saved; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(const Duration(seconds: 2));
            message = 'Retrying ${exam.title}…';
            notifyListeners();
          }
          try {
            final bundle = await _api.bundle(exam.code);
            await _store.savePack(bundle, exam.bundleSha256);
            saved = true;
          } on ApiException {
            // Permanent server decisions (404/409) will not heal -
            // retrying only burns the student's data.
            break;
          } on NetworkException {
            // Transient: fall through to the retry pass.
          }
        }
        if (saved) {
          done += 1;
        } else {
          failed += 1;
        }
        notifyListeners();
      }
      await refreshPendingCount();
      if (failed > 0 && done == 0) {
        phase = SyncPhase.error;
        message =
            '$failed packs could not download, check your connection and '
            'retry - the rest of the app works offline.';
      } else {
        phase = SyncPhase.ready;
        message = total == 0
            ? '${exams.length} packs available · ${have.length} on device'
            : failed > 0
                ? 'Synced $done/$total packs, $failed to retry later'
                : 'Synced $done/$total packs';
      }
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
  /// is studying for). Falls back to everything when nothing matches,
  /// an empty library helps nobody.
  ///
  /// University Modules is the one exception: 500+ course banks would
  /// blast a fresh install with hundreds of megabytes, so nothing
  /// auto-downloads - the school desk fetches each course on demand
  /// (founder directive: per-school folders stay server-side until a
  /// student actually opens them).
  List<ExamMeta> _neededFor(List<String> profileExams) {
    if (profileExams.isEmpty) return exams;
    final wanted = exams
        .where(
          (e) =>
              profileExams.contains(e.body) ||
              profileExams.contains(e.category),
        )
        .toList(growable: false);
    if (wanted.isEmpty) return exams;
    // University-only profiles sync nothing up front; every university
    // pack downloads from its desk tile instead.
    if (profileExams.length == 1 && profileExams.first == 'University Modules') {
      return <ExamMeta>[];
    }
    return wanted.where((e) => e.body != 'University Modules').toList();
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
        break; // still offline, try again later
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
  ExamController({
    required ApiClient api,
    required PackStore store,
    DateTime Function()? clock,
  }) : _api = api,
       _store = store,
       _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final PackStore _store;

  /// Injectable wall clock (tests drive it deterministically).
  final DateTime Function() _clock;

  /// Fatigue telemetry (ROADMAP #6): per-answer latencies in answer
  /// order, the running signal, the nudge overlay state and the 5-minute
  /// break the nudge offers. No PII beyond timing leaves the device.
  final List<int> latenciesMs = <int>[];
  DateTime _shownAt = DateTime.now();
  FatigueSignal signal = FatigueSignal.none;
  bool nudgeVisible = false;
  bool nudgeDismissed = false;
  int breakSecondsLeft = 0;

  ExamPhase phase = ExamPhase.loading;
  ExamMeta? meta;
  Bundle? bundle;
  ExamResult? result;
  String? error;

  /// When true, BEGIN asks the server for a weak-topic-first paper
  /// (ROADMAP #5). Offline starts keep the pack's natural order.
  bool adaptive = false;

  /// Set after a successful adaptive begin, the intro/results UI reads it.
  bool appliedAdaptive = false;

  int index = 0;
  int secondsRemaining = 0;

  /// Practice Settings overrides (Stitch practice_mode_setup): a chosen
  /// timer replaces the pack's own duration; untimed runs the paper
  /// with a count-up clock instead of a countdown.
  int? durationOverrideMinutes;
  bool untimed = false;

  /// Count-up clock seconds for untimed practice runs.
  int elapsedSeconds = 0;

  final Map<String, String> answers = <String, String>{};
  final Set<String> flags = <String>{};

  /// Questions the student has actually seen (drives the navigator's
  /// Skipped vs Unseen split).
  final Set<String> visited = <String>{};

  /// Per-question dwell time in milliseconds, banked on every question
  /// transition (and at submit/break) so the pacing engine can score
  /// clock discipline. Keyed by question id.
  final Map<String, int> questionMs = <String, int>{};

  String get _currentQuestionId =>
      bundle != null && bundle!.questions.isNotEmpty
          ? bundle!.questions[index].id
          : '';

  /// Banks the live stretch of the current question into questionMs.
  void _bankDwell() {
    final String qid = _currentQuestionId;
    if (qid.isEmpty || phase != ExamPhase.playing) return;
    final int ms = _clock().difference(_shownAt).inMilliseconds;
    if (ms <= 0) return;
    questionMs[qid] = (questionMs[qid] ?? 0) + ms;
  }

  /// Milliseconds spent on the question currently on screen: everything
  /// banked so far plus the live stretch since the last transition.
  int dwellMsOnCurrent() {
    final String qid = _currentQuestionId;
    final int banked = questionMs[qid] ?? 0;
    if (qid.isEmpty || phase != ExamPhase.playing) return banked;
    final int live = _clock().difference(_shownAt).inMilliseconds;
    return banked + (live > 0 ? live : 0);
  }

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

  Future<void> load(
    ExamMeta examMeta, {
    int? durationOverrideMinutes,
    bool untimed = false,
    bool shuffleQuestions = false,
  }) async {
    meta = examMeta;
    this.durationOverrideMinutes = durationOverrideMinutes;
    this.untimed = untimed;
    elapsedSeconds = 0;
    phase = ExamPhase.loading;
    error = null;
    result = null;
    notifyListeners();
    final bool composed = isComposedPaperCode(examMeta.code);
    Bundle? cached = await _store.loadPack(examMeta.code, examMeta.bundleSha256);
    // Composed papers (mock/custom/pick) cache by CODE alone - their
    // bundleSha256 is empty, so the code-keyed lookup is the offline
    // resume path for every paper the student has already started.
    cached ??= composed ? await _store.loadPackByCode(examMeta.code) : null;
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
      } on NetworkException {
        error = composed
            ? 'Composed papers need one online load - reconnect and tap '
                'again, the paper then stays on the device.'
            : 'No connection. Download the pack once and it plays fully '
                'offline.';
        phase = ExamPhase.error;
        notifyListeners();
        return;
      }
    }
    if (shuffleQuestions && bundle!.questions.length > 1) {
      bundle = bundle!.reordered(Random().nextDouble);
    }
    index = 0;
    answers.clear();
    flags.clear();
    visited.clear();
    latenciesMs.clear();
    questionMs.clear();
    signal = FatigueSignal.none;
    nudgeVisible = false;
    nudgeDismissed = false;
    breakSecondsLeft = 0;
    _shownAt = _clock();
    phase = ExamPhase.intro;
    notifyListeners();
  }

  Future<void> begin() async {
    if (bundle == null) return;
    appliedAdaptive = false;
    visited.clear();
    visited.add(bundle!.questions.first.id);
    try {
      final started = await _api.createAttempt(
        bundle!.code,
        adaptive: adaptive,
      );
      _attemptId = started.attemptId;
      // The server walked the pack weak-topic-first (ROADMAP #5):
      // re-sequence the in-memory copy so the player, the navigator and
      // the paper history all follow exactly that order. The cached pack
      // on disk is untouched.
      if (adaptive && started.order != null && started.order!.isNotEmpty) {
        bundle = bundle!.withOrder(started.order!);
        appliedAdaptive = true;
      }
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
    if (untimed) {
      secondsRemaining = 0;
    } else if ((durationOverrideMinutes ?? 0) > 0) {
      secondsRemaining = durationOverrideMinutes! * 60;
    } else {
      secondsRemaining = (bundle!.durationMinutes ?? 30) * 60;
    }
    _startedAt = _clock();
    _shownAt = _clock();
    phase = ExamPhase.playing;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  /// One second of exam time. Called by the periodic timer; public so
  /// tests can drive the clock deterministically.
  Future<void> tick() async {
    if (phase != ExamPhase.playing) return;
    // "Take 5": the break runs on its own countdown and the exam clock
    // is paused for it, that is the whole point of the break.
    if (breakSecondsLeft > 0) {
      breakSecondsLeft -= 1;
      notifyListeners();
      return;
    }
    if (untimed) {
      elapsedSeconds += 1;
      notifyListeners();
      return;
    }
    if (secondsRemaining > 0) {
      secondsRemaining -= 1;
      notifyListeners();
    }
    if (secondsRemaining == 0) {
      await submit();
    }
  }

  void select(String questionId, String letter) {
    if (!answers.containsKey(questionId)) {
      latenciesMs.add(_clock().difference(_shownAt).inMilliseconds);
      _assessFatigue();
    }
    answers[questionId] = letter;
    notifyListeners();
  }

  /// Wall-clock minutes since the sitting began.
  double get elapsedMinutes =>
      _clock().difference(_startedAt).inMilliseconds / 60000.0;

  void _assessFatigue() {
    signal = assessFatigue(List<int>.of(latenciesMs), elapsedMinutes);
    if (signal.suggestBreak && !nudgeDismissed) {
      nudgeVisible = true;
    }
  }

  /// The nudge's "Take 5": pause the exam clock for five minutes.
  void takeBreak() {
    _bankDwell(); // stop the dwell clock before the break eats time
    breakSecondsLeft = 300;
    nudgeVisible = false;
    nudgeDismissed = true;
    _shownAt = _clock(); // the break is not answer time
    notifyListeners();
  }

  /// The nudge's "Keep going": quiet for the rest of the sitting.
  void keepGoing() {
    nudgeVisible = false;
    nudgeDismissed = true;
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
    _bankDwell();
    index = i.clamp(0, bundle!.questions.length - 1);
    visited.add(bundle!.questions[index].id);
    _shownAt = _clock();
    notifyListeners();
  }

  void next() => goTo(index + 1);
  void previous() => goTo(index - 1);

  Future<void> submit() async {
    if (phase != ExamPhase.playing || bundle == null || _attemptId == null) {
      return;
    }
    _bankDwell();
    _timer?.cancel();
    final durationMs = _clock().difference(_startedAt).inMilliseconds;
    _durationMs = durationMs;
    phase = ExamPhase.grading;
    signal = assessFatigue(List<int>.of(latenciesMs), durationMs / 60000.0);
    _reportSession(durationMs);
    notifyListeners();

    // Paper answered but attempt row never reached the server (user went
    // offline before Begin hit the API) → straight to the queue.
    if (_attemptId!.startsWith('offline-')) {
      await _queueOffline(durationMs);
      return;
    }

    try {
      await _api.submit(
        _attemptId!,
        Map.of(answers),
        durationMs,
        questionMs: Map.of(questionMs),
      );
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
    await _store.queueSubmission(
      PendingSubmission(
        id: _attemptId!,
        code: bundle!.code,
        attemptId: _attemptId!,
        answers: Map.of(answers),
        durationMs: durationMs,
        createdAt: DateTime.now(),
      ),
    );
    phase = ExamPhase.queued;
    notifyListeners();
  }

  /// Best-effort telemetry POST (ROADMAP #6). Never awaited by the exam
  /// flow and never surfaces errors: offline sittings simply skip it.
  void _reportSession(int durationMs) {
    final id = _attemptId ?? '';
    if (id.startsWith('offline-')) return; // server unreachable this sitting
    final latencies = List<int>.of(latenciesMs);
    final started = _startedAt.toUtc().toIso8601String();
    final code = bundle?.code ?? '';
    unawaited(() async {
      try {
        await _api.logSession(
          startedAt: started,
          attemptId: id,
          code: code,
          durationMs: durationMs,
          latenciesMs: latencies,
        );
      } on ApiException catch (_) {
        // Permanent server decision, telemetry is dropped, not queued.
      } on NetworkException catch (_) {
        // Transient, telemetry is dropped, not queued (never load-bearing).
      }
    }());
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
          error = 'Grading hit an error, please try again.';
          phase = ExamPhase.error;
          notifyListeners();
          return;
        }
        await Future<void>.delayed(_pollDelay);
      } on NetworkException {
        await _queueOffline(
          DateTime.now().difference(_startedAt).inMilliseconds,
        );
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

  /// Public read for screens that need one-off API calls outside the
  /// controller's cached state (e.g. the syllabus map).
  ApiClient? get api => _api;

  /// Public read for screens that need the pack store directly (the
  /// offline-share export path loads a cached bundle by code).
  PackStore get store => _store;
  final PackStore _store;

  MeResult? me;
  GamificationSummary? gamification;
  ReviewSummary? review;
  FatigueState? fatigue;
  List<AttemptRow> attempts = <AttemptRow>[];
  Set<String> downloaded = <String>{};
  bool loading = false;
  String? error;

  bool get hasProfile => me?.profile?.completed ?? false;

  /// "NEXT TARGET, UTME 2027" hero title from the onboarding pick.
  /// Mock Exam Setup is a JAMBite product: this gates it everywhere.
  bool get isJambFocus =>
      (me?.profile?.exams.firstOrNull?.toUpperCase() ?? '').contains('JAMB');

  /// Tertiary students get the university home (Stitch
  /// university_home_dashboard_light) instead of the JAMB launcher.
  bool get isTertiaryFocus =>
      (me?.profile?.exams.firstOrNull ?? '').contains('University');

  /// Post UTME candidates get their own desk, the fourth focus entity
  /// beside JAMB / WAEC / NECO / School Desk (founder directive).
  bool get isPostUtmeFocus =>
      (me?.profile?.exams.firstOrNull ?? '').toUpperCase().contains('POST');

  String get targetTitle {
    final p = me?.profile;
    if (p == null || p.exams.isEmpty) return 'Set your target';
    final String exam = p.exams.first;
    final label = switch (exam) {
      'JAMB' => 'UTME',
      'WAEC' => 'WASSCE',
      'NECO' => 'NECO',
      'POST-UTME' => 'Post UTME',
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

  /// % of the student's packs with at least one graded attempt, the real
  /// number behind the hero card's "Syllabus Completion" bar.
  int get coveragePct {
    final p = me?.profile;
    if (p == null) return 0;
    final gradedCodes = attempts
        .where((a) => a.isGraded)
        .map((a) => a.code)
        .toSet();
    final relevant = attempts.isEmpty
        ? <String>{for (final e in downloaded) e}
        : gradedCodes;
    if (relevant.isEmpty) return 0;
    return (gradedCodes.length * 100 ~/ relevant.length).clamp(0, 100);
  }

  /// Total questions missed across graded papers.
  int get questionsToReview => attempts.fold(0, (sum, a) => sum + a.missed);

  /// Topics the spaced-repetition engine says are due today (or overdue) ,
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
        .where(
          (a) =>
              a.submittedAt != null &&
              a.submittedAt!.year == now.year &&
              a.submittedAt!.month == now.month &&
              a.submittedAt!.day == now.day,
        )
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
        _api.fatigue(),
      ]);
      me = results[0] as MeResult;
      gamification = results[1] as GamificationSummary;
      attempts = results[2] as List<AttemptRow>;
      downloaded = results[3] as Set<String>;
      review = results[4] as ReviewSummary;
      fatigue = results[5] as FatigueState;
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

// ------------------------------------------------------ lesson narrator

/// Audio summaries (ROADMAP #11): narrates a lesson's spoken summary with
/// the on-device speech engine, the same engine family as the voice
/// flashcards. Simple on/off state - the toggle re-taps as stop, and the
/// reader screen silences playback when it leaves. The engine is injected
/// so tests run with a fake and zero platform channels.
class LessonNarrator extends ChangeNotifier {
  LessonNarrator({SpeechEngine? speech})
    : speech = speech ?? FlutterTtsEngine();

  final SpeechEngine speech;

  String _slug = '';

  /// Whether a summary is (nominally) being narrated right now. On-device
  /// engines expose no completion callback through [SpeechEngine], so a
  /// finished script keeps this true until the student re-taps - the same
  /// honesty trade the flashcard pill makes.
  bool get playing => _slug.isNotEmpty;

  /// Slug of the lesson currently being narrated.
  String get slug => _slug;

  void toggle(Lesson lesson) {
    if (playing && _slug == lesson.slug) {
      stop();
      return;
    }
    _slug = lesson.slug;
    notifyListeners();
    unawaited(speech.speak(composeSpokenSummary(lesson)));
  }

  void stop() {
    if (!playing) return;
    _slug = '';
    unawaited(speech.stop());
    notifyListeners();
  }

  /// Stops playback without notifying, for screen-dispose teardown where
  /// the listening widgets are already being torn down.
  void stopSilently() {
    if (!playing) return;
    _slug = '';
    unawaited(speech.stop());
  }

  @override
  void dispose() {
    speech.stop();
    speech.dispose();
    super.dispose();
  }
}

// ------------------------------------------------------ flashcards controller

enum CardsPhase { loading, ready, error }

/// Voice flashcards (ROADMAP #7): deck list, offline-cached decks, the
/// Leitner box state and the on-device speech engine. Decks come from the
/// API like exam packs, cache into the same local store, and progress
/// syncs with an offline queue, the exact pattern of exam submissions.
class FlashcardsController extends ChangeNotifier {
  FlashcardsController({
    required ApiClient api,
    required PackStore store,
    SpeechEngine? speech,
    DateTime Function()? clock,
  }) : _api = api,
       _store = store,
       speech = speech ?? FlutterTtsEngine(),
       _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final PackStore _store;

  /// The voice behind "reads card fronts/backs aloud", injected so tests
  /// run with a fake and no platform channels.
  final SpeechEngine speech;
  final DateTime Function() _clock;

  CardsPhase phase = CardsPhase.loading;
  List<FlashcardDeckMeta> decks = <FlashcardDeckMeta>[];
  FlashcardDeck? deck;
  Map<String, CardProgress> progress = <String, CardProgress>{};

  int index = 0;
  bool revealed = false;
  bool voiceOn = true;
  bool gradesPending = false;
  String? error;

  FlashcardCard? get current =>
      deck == null || index >= deck!.cards.length ? null : deck!.cards[index];

  /// Cards sitting in box 3+ (seen and mostly recalled).
  int get knownCount => progress.values.where((p) => p.box >= 3).length;

  /// True after the last card was graded, the completed state.
  bool get isDeckDone => deck != null && index >= deck!.cards.length;

  Future<void> loadDecks() async {
    phase = CardsPhase.loading;
    error = null;
    notifyListeners();
    // Offline-first: paint the cache immediately, then refresh quietly.
    try {
      decks = await _store.cachedDeckMetas();
      if (decks.isNotEmpty) {
        phase = CardsPhase.ready;
        notifyListeners();
      }
    } catch (_) {
      // Corrupt cache rows, the refresh below replaces them anyway.
    }
    unawaited(retryPendingGrades());
    try {
      decks = await _api.flashcardDecks();
      await _store.saveDeckMetas(decks);
      phase = CardsPhase.ready;
    } on ApiException catch (e) {
      if (decks.isEmpty) {
        phase = CardsPhase.error;
        error = e.message;
      } else {
        phase = CardsPhase.ready;
      }
    } on NetworkException catch (e) {
      if (decks.isEmpty) {
        phase = CardsPhase.error;
        error = e.message;
      } else {
        phase = CardsPhase.ready;
      }
    }
    notifyListeners();
  }

  Future<void> openDeck(String code) async {
    phase = CardsPhase.loading;
    error = null;
    notifyListeners();
    final cached = await _store.loadDeck(code);
    if (cached != null && cached.cards.isNotEmpty) {
      deck = cached;
    } else {
      try {
        deck = await _api.flashcardDeck(code);
        await _store.saveDeck(deck!);
      } on ApiException catch (e) {
        error = e.message;
        phase = CardsPhase.error;
        notifyListeners();
        return;
      } on NetworkException catch (e) {
        error = e.message;
        phase = CardsPhase.error;
        notifyListeners();
        return;
      }
    }
    final rows = await _store.loadCardProgress();
    progress = <String, CardProgress>{for (final r in rows) r.cardId: r};
    index = 0;
    revealed = false;
    phase = CardsPhase.ready;
    notifyListeners();
    unawaited(_refreshProgress());
    unawaited(_speakCurrent());
  }

  Future<void> _refreshProgress() async {
    try {
      final rows = await _api.cardProgress();
      // MERGE, never replace: local-only rows (offline grades still in the
      // queue) must survive the refresh, server rows win on conflict.
      progress = <String, CardProgress>{
        ...progress,
        for (final r in rows) r.cardId: r,
      };
      await _store.saveCardProgress(rows);
      notifyListeners();
    } on ApiException catch (_) {
      // Server said no, local state keeps working.
    } on NetworkException catch (_) {
      // Offline, local state keeps working.
    }
  }

  /// Flip the card; the back is spoken on reveal.
  void flip() {
    revealed = !revealed;
    notifyListeners();
    if (revealed && voiceOn) {
      unawaited(speech.speak(current?.back ?? ''));
    }
  }

  void next() {
    if (deck == null) return;
    if (index < deck!.cards.length) index++;
    revealed = false;
    notifyListeners();
    unawaited(_speakCurrent());
  }

  void previous() {
    if (deck == null || index == 0) return;
    index--;
    revealed = false;
    notifyListeners();
    unawaited(_speakCurrent());
  }

  /// Grades the current card (again | hard | good), applies the pure
  /// Leitner rule optimistically, advances, then syncs (or queues offline).
  Future<void> grade(String g) async {
    final card = current;
    if (card == null || deck == null) return;
    final deckCode = deck!.code;
    final prev = progress[card.id];
    final baseBox = prev?.box ?? 1;
    final newBox = nextCardBox(baseBox, g);
    final now = _clock().toUtc();
    final due = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: cardIntervalDays(newBox)));
    final updated = CardProgress(
      cardId: card.id,
      deckCode: deckCode,
      box: newBox,
      correct: (prev?.correct ?? 0) + (g == 'again' ? 0 : 1),
      wrong: (prev?.wrong ?? 0) + (g == 'again' ? 1 : 0),
      dueOn: due.toIso8601String().substring(0, 10),
      lastGrade: g,
    );
    progress[card.id] = updated;
    await _store.saveCardProgress(<CardProgress>[updated]);
    notifyListeners();
    // Every grade advances, the design's Again/Hard/Good all move on.
    next();

    final grade = FlashcardGrade(cardId: card.id, deckCode: deckCode, grade: g);
    try {
      final rows = await _api.gradeCards(<FlashcardGrade>[grade]);
      for (final r in rows) {
        progress[r.cardId] = r;
      }
      await _store.saveCardProgress(rows);
      gradesPending = (await _store.pendingCardGrades()).isNotEmpty;
      notifyListeners();
    } on ApiException catch (_) {
      // Permanent server decision, the local Leitner state stands.
    } on NetworkException catch (_) {
      await _store.queueCardGrade(
        PendingCardGrade(
          id: 'g-${card.id}-${now.millisecondsSinceEpoch}',
          cardId: card.id,
          deckCode: deckCode,
          grade: g,
          createdAt: _clock(),
        ),
      );
      gradesPending = true;
      notifyListeners();
    }
  }

  /// Flush queued card grades, FIFO. Network failures keep entries;
  /// permanent server decisions clear them.
  Future<void> retryPendingGrades() async {
    final pending = await _store.pendingCardGrades();
    for (final item in pending) {
      try {
        final rows = await _api.gradeCards(<FlashcardGrade>[
          FlashcardGrade(
            cardId: item.cardId,
            deckCode: item.deckCode,
            grade: item.grade,
          ),
        ]);
        await _store.removeCardGrade(item.id);
        for (final r in rows) {
          progress[r.cardId] = r;
        }
        await _store.saveCardProgress(rows);
      } on ApiException catch (_) {
        await _store.removeCardGrade(item.id);
        break;
      } on NetworkException catch (_) {
        break; // still offline, try again later
      }
    }
    gradesPending = (await _store.pendingCardGrades()).isNotEmpty;
    notifyListeners();
  }

  Future<void> _speakCurrent() async {
    if (!voiceOn || deck == null) return;
    await speech.speak(
      revealed ? (current?.back ?? '') : (current?.front ?? ''),
    );
  }

  /// Voice on/off, turning it on re-reads the current side.
  void toggleVoice() {
    voiceOn = !voiceOn;
    if (!voiceOn) {
      unawaited(speech.stop());
    } else {
      unawaited(_speakCurrent());
    }
    notifyListeners();
  }

  void closeDeck() {
    unawaited(speech.stop());
    deck = null;
    index = 0;
    revealed = false;
    notifyListeners();
  }

  /// Back to card one (the deck-complete screen's "Run it again").
  void restartDeck() {
    index = 0;
    revealed = false;
    notifyListeners();
    unawaited(_speakCurrent());
  }

  @override
  void dispose() {
    speech.stop();
    speech.dispose();
    super.dispose();
  }
}

// --------------------------------------------------------- lessons controller

enum LessonsPhase { idle, loading, ready, error }

/// Lesson library state (ROADMAP #8): fetches the list from the API,
/// caches metas for offline reuse, and loads single bundles with a
/// cache fallback so saved lessons stay readable with zero connectivity.
class LessonsController extends ChangeNotifier {
  LessonsController({required ApiClient api, required PackStore store})
    : _api = api,
      _store = store;

  final ApiClient _api;
  final PackStore _store;

  LessonsPhase phase = LessonsPhase.idle;
  List<LessonMeta> lessons = <LessonMeta>[];
  String error = '';

  Future<void> load({bool force = false}) async {
    if (phase == LessonsPhase.loading) return;
    if (!force && lessons.isNotEmpty) return;
    phase = LessonsPhase.loading;
    notifyListeners();
    try {
      lessons = await _api.lessons();
      phase = LessonsPhase.ready;
      error = '';
      // best-effort cache: metas keep the list browsable offline
      try {
        await _store.saveLessonMetas(lessons);
      } on Exception {
        // cache failure must never break the online path
      }
    } on NetworkException {
      // offline: fall back to the cached library
      lessons = await _store.cachedLessonMetas();
      if (lessons.isEmpty) {
        phase = LessonsPhase.error;
        error = 'No connection and no saved lessons yet. Reconnect once to download the library.';
      } else {
        phase = LessonsPhase.ready;
        error = 'Offline, showing your saved lessons.';
      }
    } on ApiException catch (e) {
      phase = LessonsPhase.error;
      error = e.message;
    }
    notifyListeners();
  }

  /// One full lesson: online fetch first, cache fallback, and every
  /// successful fetch refreshes the cache.
  Future<Lesson?> loadLesson(String slug) async {
    try {
      final Lesson les = await _api.lesson(slug);
      try {
        await _store.saveLesson(les);
      } on Exception {
        // ignore cache write failures
      }
      return les;
    } on NetworkException {
      return _store.loadLesson(slug);
    } on ApiException {
      return _store.loadLesson(slug);
    }
  }
}

// ---------------------------------------------------------- tutor controller

enum TutorPhase { idle, thinking, ready, error }

/// One Socratic conversation (ROADMAP #9): anchored to a graded attempt
/// + question, it holds the visible turns and the mode badge from the
/// last reply ('ai' | 'hint'). Provider outages and rate limits surface
/// as an error row, the conversation itself is never lost.
class TutorController extends ChangeNotifier {
  TutorController({
    required ApiClient api,
    required this.attemptId,
    required this.questionId,
  }) : _api = api;

  final ApiClient _api;
  final String attemptId;
  final String questionId;

  final List<TutorTurn> turns = <TutorTurn>[];
  TutorPhase phase = TutorPhase.idle;
  String mode = 'hint';
  String error = '';

  bool get aiEnabled => mode == 'ai';

  Future<void> send(String content) async {
    final String text = content.trim();
    if (text.isEmpty || phase == TutorPhase.thinking) return;
    turns.add(TutorTurn(role: 'user', content: text));
    phase = TutorPhase.thinking;
    error = '';
    notifyListeners();
    try {
      final TutorReply reply = await _api.tutorChat(
        attemptId: attemptId,
        questionId: questionId,
        messages: List<TutorTurn>.of(turns),
      );
      turns.add(TutorTurn(role: 'assistant', content: reply.text));
      mode = reply.mode;
      phase = TutorPhase.ready;
    } on ApiException catch (e) {
      phase = TutorPhase.error;
      error = e.statusCode == 429
          ? 'The tutor is cooling down, retry in a few seconds.'
          : e.message;
    } on NetworkException {
      phase = TutorPhase.error;
      error = 'No connection, the tutor needs the server to coach.';
    }
    notifyListeners();
  }
}

/// School workspace controller (For Schools): loads the caller's school
/// memberships, downloads/removes offline school packs (syllabus, scheme
/// of work, notes) and remembers which school session is active so the
/// splash can land staff straight in their workspace.
class SchoolController extends ChangeNotifier {
  SchoolController({
    required ApiClient api,
    required PackStore store,
    required SessionStore session,
  })  : _api = api,
        _store = store,
        _session = session;

  final ApiClient _api;
  final PackStore _store;
  final SessionStore _session;

  /// The caller's active memberships (management + teacher).
  List<SchoolContextModel> contexts = <SchoolContextModel>[];

  /// Downloaded offline packs by school id.
  final Map<String, SchoolPack> packs = <String, SchoolPack>{};

  bool loadingContexts = false;
  final Set<String> _downloading = <String>{};
  String? lastError;

  bool get isDownloading => _downloading.isNotEmpty;
  bool isDownloadingSchool(String schoolId) => _downloading.contains(schoolId);

  /// Loads the memberships (empty list = plain student account).
  Future<void> loadContexts() async {
    // No session, no school world - keeps stale contexts from leaking
    // across sign-outs and gives the injected session a real job.
    if ((_session.token ?? '').isEmpty) {
      contexts = <SchoolContextModel>[];
      notifyListeners();
      return;
    }
    loadingContexts = true;
    lastError = null;
    notifyListeners();
    try {
      contexts = await _api.schoolMe();
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    } finally {
      loadingContexts = false;
      notifyListeners();
    }
  }

  /// Refreshes the downloaded pack shelf from local storage.
  Future<void> refreshPacks() async {
    try {
      final List<SchoolPack> stored = await _store.loadSchoolPacks();
      packs
        ..clear()
        ..addEntries(stored.map((SchoolPack p) => MapEntry(p.school.id, p)));
      notifyListeners();
    } catch (_) {
      // A missing table (fresh install pre-migration) is fine.
    }
  }

  // ------------------------------------------------------------- corpus

  /// The national curriculum corpus cache. Fetched directly from the
  /// codebase files the API ships with; nothing here touches Neon.
  List<CorpusClassModel>? corpusClasses;
  final Map<String, List<CorpusSchemeTermModel>> _corpusSchemes =
      <String, List<CorpusSchemeTermModel>>{};
  final Map<String, List<CorpusNotesTermModel>> _corpusNotes =
      <String, List<CorpusNotesTermModel>>{};

  /// Loads (and caches) the corpus class list. Returns an empty list
  /// on failure with the error surfaced in lastError.
  Future<List<CorpusClassModel>> loadCorpusClasses() async {
    if (corpusClasses != null) return corpusClasses!;
    lastError = null;
    try {
      corpusClasses = await _api.corpusClasses();
    } on ApiException catch (e) {
      lastError = e.message;
      corpusClasses = const <CorpusClassModel>[];
    } on NetworkException catch (e) {
      lastError = e.message;
      corpusClasses = const <CorpusClassModel>[];
    }
    notifyListeners();
    return corpusClasses!;
  }

  /// Loads (and caches) every term scheme for one corpus subject.
  Future<List<CorpusSchemeTermModel>> loadCorpusSchemes(
    String classId,
    String subject,
  ) async {
    final String key = '$classId/$subject';
    final List<CorpusSchemeTermModel>? cached = _corpusSchemes[key];
    if (cached != null) return cached;
    try {
      final List<CorpusSchemeTermModel> terms = await _api.corpusSchemes(classId, subject);
      _corpusSchemes[key] = terms;
      return terms;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    return const <CorpusSchemeTermModel>[];
  }

  /// Loads (and caches) every term note set for one corpus subject.
  Future<List<CorpusNotesTermModel>> loadCorpusNotes(
    String classId,
    String subject,
  ) async {
    final String key = '$classId/$subject';
    final List<CorpusNotesTermModel>? cached = _corpusNotes[key];
    if (cached != null) return cached;
    try {
      final List<CorpusNotesTermModel> terms = await _api.corpusNotes(classId, subject);
      _corpusNotes[key] = terms;
      return terms;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    return const <CorpusNotesTermModel>[];
  }

  /// Downloads (or refreshes) one school's offline pack. Returns true on
  /// success. Network-safe: failures surface in lastError, never throw.
  Future<bool> download(String schoolId) async {
    if (_downloading.contains(schoolId)) return false;
    _downloading.add(schoolId);
    lastError = null;
    notifyListeners();
    try {
      final SchoolPack pack = await _api.schoolPack(schoolId);
      await _store.saveSchoolPack(pack);
      packs[schoolId] = pack;
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    } finally {
      _downloading.remove(schoolId);
      notifyListeners();
    }
    return false;
  }

  Future<void> remove(String schoolId) async {
    await _store.removeSchoolPack(schoolId);
    packs.remove(schoolId);
    notifyListeners();
  }

  // ---- live roster + attendance (management + teachers) --------------

  /// The school's classes for the roster pickers.
  List<SchoolClassInfo> classes = <SchoolClassInfo>[];

  /// The enrolled students of the currently loaded class (or school).
  List<SchoolStudentModel> roster = <SchoolStudentModel>[];

  /// Today's marks keyed by student id for the register screen.
  final Map<String, AttendanceEntryModel> marks = <String, AttendanceEntryModel>{};

  /// Per-student attendance rates over the loaded window.
  List<AttendanceSummaryRowModel> attendanceRows = <AttendanceSummaryRowModel>[];

  bool rosterLoading = false;
  String? rosterError;

  /// Loads the class list (once per school) and the roster for [classId].
  Future<void> loadRoster(String schoolId, {String classId = ''}) async {
    rosterLoading = true;
    rosterError = null;
    notifyListeners();
    try {
      if (classes.isEmpty) {
        classes = await _api.schoolClasses(schoolId);
      }
      roster = await _api.schoolStudents(schoolId, classId: classId);
    } on ApiException catch (e) {
      rosterError = e.message;
    } on NetworkException catch (e) {
      rosterError = e.message;
    } finally {
      rosterLoading = false;
      notifyListeners();
    }
  }

  /// Creates or edits a student's details. Returns null on failure with
  /// [lastError] set; otherwise the saved student.
  Future<SchoolStudentModel?> saveStudent(
    String schoolId, {
    required SchoolStudentModel student,
    required bool isNew,
    required String session,
  }) async {
    lastError = null;
    try {
      final SchoolStudentModel saved = isNew
          ? await _api.schoolCreateStudent(
              schoolId,
              classId: student.classId,
              fullName: student.fullName,
              admissionNo: student.admissionNo,
              sex: student.sex,
              session: session,
              dob: student.dob,
              guardianName: student.guardianName,
              guardianPhone: student.guardianPhone,
              address: student.address,
            )
          : await _api.schoolUpdateStudent(schoolId, student);
      final int i = roster.indexWhere((SchoolStudentModel s) => s.id == saved.id);
      if (i >= 0) {
        roster[i] = saved;
      } else {
        roster.add(saved);
      }
      notifyListeners();
      return saved;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return null;
  }

  /// Pulls one day's register and seeds [marks] with it.
  Future<void> loadAttendanceDay(String schoolId, String classId, String day) async {
    rosterLoading = true;
    rosterError = null;
    notifyListeners();
    try {
      marks.clear();
      for (final AttendanceEntryModel e in await _api.attendanceDay(schoolId, classId, day)) {
        marks[e.studentId] = e;
      }
      if (roster.isEmpty || roster.first.classId != classId) {
        roster = await _api.schoolStudents(schoolId, classId: classId);
      }
    } on ApiException catch (e) {
      rosterError = e.message;
    } on NetworkException catch (e) {
      rosterError = e.message;
    } finally {
      rosterLoading = false;
      notifyListeners();
    }
  }

  /// Marks one student locally; [saveAttendanceDay] pushes the sheet.
  void mark(String studentId, String status, {String note = ''}) {
    marks[studentId] = AttendanceEntryModel(studentId: studentId, status: status, note: note);
    notifyListeners();
  }

  /// Fills every empty cell with a mark (the morning 'all present' sweep);
  /// existing marks stay untouched.
  void markAllPresent(List<SchoolStudentModel> students) {
    for (final SchoolStudentModel s in students) {
      marks.putIfAbsent(
        s.id,
        () => AttendanceEntryModel(studentId: s.id, status: 'present'),
      );
    }
    notifyListeners();
  }

  /// Pushes the whole day's marks. Returns the saved count or null.
  Future<int?> saveAttendanceDay(String schoolId, String classId, String day) async {
    lastError = null;
    final List<AttendanceEntryModel> entries =
        marks.values.toList(growable: false);
    if (entries.isEmpty) return 0;
    try {
      final int saved = await _api.saveAttendance(schoolId, classId, day, entries);
      return saved;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return null;
  }

  /// Loads the per-student rates for a window (inclusive dates).
  Future<void> loadAttendanceSummary(
    String schoolId,
    String classId,
    String from,
    String to,
  ) async {
    try {
      attendanceRows = await _api.attendanceSummary(schoolId, classId, from, to);
    } on ApiException catch (e) {
      rosterError = e.message;
    } on NetworkException catch (e) {
      rosterError = e.message;
    }
    notifyListeners();
  }

  // ---- active school session (splash routing) -------------------------

  static const String _sessionPrefKey = 'renance.school.session.v1';

  /// Marks the session as a school workspace session.
  static Future<void> rememberSchoolSession(
    SharedPreferences prefs,
    SchoolContextModel ctx,
  ) async {
    await prefs.setString(
      _sessionPrefKey,
      jsonEncode(<String, String>{
        'schoolId': ctx.school.id,
        'schoolName': ctx.school.name,
        'role': ctx.member.role,
        'memberId': ctx.member.id,
        'fullName': ctx.member.fullName,
      }),
    );
  }

  /// Clears the school workspace marker (student login / sign-out).
  static Future<void> forgetSchoolSession(SharedPreferences prefs) async {
    await prefs.remove(_sessionPrefKey);
  }

  /// The remembered school session, if this device last used one.
  static Map<String, String>? rememberedSession(SharedPreferences prefs) {
    final String? raw = prefs.getString(_sessionPrefKey);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> j =
          jsonDecode(raw) as Map<String, dynamic>;
      return j.map<String, String>(
        (String k, dynamic v) => MapEntry(k, (v ?? '').toString()),
      );
    } on FormatException {
      return null;
    }
  }
}
