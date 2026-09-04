/// State controllers: silent asset sync (SyncController) and the CBT
/// player (ExamController). Both are plain ChangeNotifiers driven by
/// injectable collaborators, so every rule is unit-testable.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';
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
  /// is studying for). Falls back to everything when nothing matches ,
  /// an empty library helps nobody.
  List<ExamMeta> _neededFor(List<String> profileExams) {
    if (profileExams.isEmpty) return exams;
    final wanted = exams
        .where(
          (e) =>
              profileExams.contains(e.body) ||
              profileExams.contains(e.category),
        )
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
  }) async {
    meta = examMeta;
    this.durationOverrideMinutes = durationOverrideMinutes;
    this.untimed = untimed;
    elapsedSeconds = 0;
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
    visited.clear();
    latenciesMs.clear();
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
