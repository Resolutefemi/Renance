/// State controllers: silent asset sync (SyncController) and the CBT
/// player (ExamController). Both are plain ChangeNotifiers driven by
/// injectable collaborators, so every rule is unit-testable.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'audio_summary.dart';
import 'device_id.dart';
import 'models.dart';
import 'papers.dart' show isComposedPaperCode;
import 'school_offline.dart';
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
  Set<String> get shelfBodies => exams
      .map((ExamMeta e) => e.body)
      .where((String b) => b.isNotEmpty)
      .toSet();

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
  ///
  /// Every failure shape ends HERE, inside the controller: storage
  /// hiccups, decode errors, anything unexpected becomes phase=error
  /// with a message, never an escaped exception (an escaped one killed
  /// the download button dead with zero feedback - founder bug
  /// "download is not working at all", 2026-09-28).
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
      final missing =
          needed.where((e) => !have.contains(e.code)).toList(growable: false);
      total = missing.length;
      int failed = 0;
      // Three parallel downloads: Nigerian mobile latency is per-request,
      // so three pipes cut the wall-clock to about a third without
      // starving the radio (sequential downloads read as a frozen screen).
      int cursor = 0;
      Future<void> worker() async {
        while (true) {
          final int i = cursor;
          if (i >= missing.length) return;
          cursor += 1;
          final ExamMeta exam = missing[i];
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
            } catch (_) {
              // A storage or decode hiccup must not kill the whole
              // sync - count this pack failed and keep pulling the
              // rest of the desk.
              break;
            }
          }
          if (saved) {
            done += 1;
          } else {
            failed += 1;
          }
          notifyListeners();
        }
      }

      await Future.wait(<Future<void>>[worker(), worker(), worker()]);
      try {
        await refreshPendingCount();
        // Downloads just reconnected the desk - push any exam sittings
        // the student completed offline while we are here.
        await retryPending();
      } catch (_) {
        // A queue flush hiccup must never read as a failed download.
      }
      if (failed > 0 && done == 0) {
        phase = SyncPhase.error;
        message = '$failed packs could not download, check your connection and '
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
    } on SocketException {
      // Friendly copy only: raw socket errors carry the API host
      // ("Failed host lookup: 'renance-api.onrender.com'") which must
      // stay out of student-facing offline messages.
      phase = SyncPhase.error;
      message = 'No connection to Renance servers. Check your internet and '
          'retry - the rest of the app works offline.';
    } catch (e) {
      // Anything unexpected (storage full, decode quirk) still lands
      // here as a visible error instead of an unhandled crash the
      // student reads as "the button does nothing". The raw error is
      // deliberately NOT interpolated: it can embed the API host.
      phase = SyncPhase.error;
      message = 'Download hit a problem on this device. Free some space '
          'and retry - the rest of the app works offline.';
    }
    notifyListeners();
  }

  /// Need-based filter (founder rule: the app downloads what the student
  /// is studying for). Falls back to every STUDENT pack when nothing
  /// matches, an empty library helps nobody.
  ///
  /// University Modules is the one exception: 500+ course banks would
  /// blast a fresh install with hundreds of megabytes, so nothing
  /// auto-downloads - the school desk fetches each course on demand
  /// (founder directive: per-school folders stay server-side until a
  /// student actually opens them).
  ///
  /// "All student question packs" (founder directive, 2026-09-28) =
  /// every secondary-school pack: JAMB + WAEC + NECO + Post-UTME +
  /// GCSE + NEET - the whole 133-pack library, university banks still
  /// opt-in per tile.
  List<ExamMeta> _neededFor(List<String> profileExams) {
    final List<ExamMeta> studentPacks = exams
        .where((e) => e.body != 'University Modules')
        .toList(growable: false);
    if (profileExams.isEmpty) return studentPacks;
    final wanted = exams
        .where(
          (e) =>
              profileExams.contains(e.body) ||
              profileExams.contains(e.category),
        )
        .toList(growable: false);
    if (wanted.isEmpty) return studentPacks;
    // University-only profiles sync nothing up front; every university
    // pack downloads from its desk tile instead.
    if (profileExams.length == 1 &&
        profileExams.first == 'University Modules') {
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

  /// The study reader's data source: the bank pack, LOCAL FIRST (the
  /// reader must open offline for every downloaded bank), network as
  /// the fill-in path that also seeds the cache for next time. Returns
  /// null only when the bank is neither on the device nor reachable -
  /// the reader then shows its retry card.
  Future<Bundle?> loadBank(String code, String sha) async {
    final Bundle? local = await _store.loadPackByCode(code);
    if (local != null && _packCarriesAnswers(local)) return local;
    // A pre-2026-09 sanitized download (answers stripped server-side):
    // re-fetch so the reader un-locks - the bundle endpoint now ships
    // the per-question answer material, same as the web statics. When
    // the fetch fails (offline / old API) the stale pack keeps reading -
    /// better locked than nothing.
    try {
      final Bundle bundle = await _api.bundle(code);
      await _store.savePack(bundle, sha);
      notifyListeners();
      return bundle;
    } on ApiException {
      return local;
    } on NetworkException {
      return local;
    } catch (_) {
      return local;
    }
  }

  /// True when a pack already carries its per-question answer material
  /// (founder directive 2026-09: answers + explanations ship to
  /// students). A pack whose MCQs all lack answers is a sanitized
  /// pre-directive download; theory-only packs legitimately carry no
  /// option letters, so they never count as stale.
  static bool _packCarriesAnswers(Bundle b) {
    final Iterable<BundleQuestion> mcqs =
        b.questions.where((BundleQuestion q) => q.options.isNotEmpty);
    return mcqs.isEmpty || mcqs.any((BundleQuestion q) => q.answer.isNotEmpty);
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
  })  : _api = api,
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

  /// Free-tier cap from the attempt creation response (null = full
  /// paper), plus the one-shot subscribe prompt state the player reads.
  int? serverCap;
  bool capPromptShown = false;
  bool capPromptVisible = false;

  /// Closes the subscribe prompt (dismiss, not paid).
  void dismissCapPrompt() {
    capPromptVisible = false;
    notifyListeners();
  }

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
    Bundle? cached =
        await _store.loadPack(examMeta.code, examMeta.bundleSha256);
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
      // Free-tier cap: the server says this paper answers at most N
      // questions before the subscribe prompt (premium and the one free
      // testing CBT carry no cap).
      serverCap = started.cap;
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
    // Free-tier gate: when a capped paper lands on its 20th answer, ask
    // for the subscription. Progress stays saved either way.
    if (serverCap != null &&
        !capPromptShown &&
        phase == ExamPhase.playing &&
        answers.length == serverCap) {
      capPromptShown = true;
      capPromptVisible = true;
    }
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
    } on ApiException catch (e) {
      // Free-tier cap: the server saved the answers and kept the attempt
      // open. Return to the paper with the subscribe prompt up; after
      // paying, the student continues exactly where they stopped.
      if (e.statusCode == 402 || e.code == 'free_cap') {
        capPromptShown = true;
        capPromptVisible = true;
        phase = ExamPhase.playing;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
        notifyListeners();
        return;
      }
      error = e.message;
      phase = ExamPhase.error;
      notifyListeners();
    } on NetworkException {
      await _queueOffline(durationMs);
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

  /// When this sitting began - the report's Start Time line.
  DateTime get startedAt => _startedAt;

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
  StudentController({
    required ApiClient api,
    required PackStore store,
    SharedPreferences? prefs,
  })  : _api = api,
        _store = store,
        _prefs = prefs;

  final ApiClient _api;

  /// Optional persistence for the offline /me cache (null in tests that
  /// construct the controller bare).
  final SharedPreferences? _prefs;

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

  /// TRUE only when the failure was the SERVER's own auth decision
  /// (401/403) - the one shape that may log the student out. A network
  /// hiccup is TRANSIENT: the shell keeps the session and rides the local
  /// cache (founder rule: closing the app offline must never log out,
  /// 2026-09-28).
  bool authError = false;

  /// TRUE when the session belongs to a signup whose email was never
  /// confirmed (founder directive 2026-09-30): /me answers (it is
  /// allowlisted) but the study endpoints refuse with 403
  /// email_unverified. The shell routes to the verify screen instead of
  /// logging the student out.
  bool emailUnverified = false;

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
    final gradedCodes =
        attempts.where((a) => a.isGraded).map((a) => a.code).toSet();
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
    authError = false;
    emailUnverified = false;
    notifyListeners();
    // /me first, on its own: it is the one endpoint a restricted
    // (unverified-signup) session may still call, so the confirmation
    // state is learned HERE - before the study endpoints answer 403 -
    // and the shell can route to the verify screen with the signup
    // address in hand.
    try {
      me = await _api.me();
      cacheMe(me!);
    } on ApiException catch (e) {
      if (e.code == 'email_unverified') {
        emailUnverified = true;
        _fallbackToCachedMe();
        loading = false;
        notifyListeners();
        return;
      }
      error = e.message;
      // The server ANSWERED. Only a 401/403 is a genuine "this session is
      // no longer valid" - every other status is a server-side decision
      // about the request, not the session.
      if (e.statusCode == 401 || e.statusCode == 403) authError = true;
      _fallbackToCachedMe();
      loading = false;
      notifyListeners();
      return;
    } on NetworkException catch (e) {
      error = e.message;
      authError = false;
      _fallbackToCachedMe();
      loading = false;
      notifyListeners();
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        _api.gamification(),
        _api.attempts(),
        _store.downloadedCodes(),
        _api.reviewQueue(),
        _api.fatigue(),
      ]);
      gamification = results[0] as GamificationSummary;
      attempts = results[1] as List<AttemptRow>;
      downloaded = results[2] as Set<String>;
      review = results[3] as ReviewSummary;
      fatigue = results[4] as FatigueState;
    } on ApiException catch (e) {
      // The batch failed but /me already landed: the desk renders from
      // the fresh profile, the transient pieces keep their last state.
      error = e.message;
      if (e.statusCode == 401 || e.statusCode == 403) authError = true;
    } on NetworkException catch (e) {
      error = e.message;
      authError = false;
    }
    loading = false;
    notifyListeners();
  }

  // ------------------------------------------------- offline profile cache

  /// The last good /me payload, persisted so a no-data launch still shows
  /// the student's name, target exam and profile state (founder rule:
  /// "once a student signup or login on the app it should always remain
  /// logged in" - and usable - until they log out themselves).
  void cacheMe(MeResult result) {
    try {
      _prefs?.setString(kMeCacheKey, jsonEncode(result.toJson()));
    } catch (_) {
      // A full disk must never break a good refresh.
    }
  }

  void _fallbackToCachedMe() {
    if (me != null) return;
    final raw = _prefs?.getString(kMeCacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      me = MeResult.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      // Gamification/attempts/review stay from the last session in memory
      // (they are transient lists); the profile is what offline needs.
    } on FormatException {
      // Corrupt cache - ignore, screens show their offline states.
    }
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
        error =
            'No connection and no saved lessons yet. Reconnect once to download the library.';
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
      final List<CorpusSchemeTermModel> terms =
          await _api.corpusSchemes(classId, subject);
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
      final List<CorpusNotesTermModel> terms =
          await _api.corpusNotes(classId, subject);
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
  final Map<String, AttendanceEntryModel> marks =
      <String, AttendanceEntryModel>{};

  /// Per-student attendance rates over the loaded window.
  List<AttendanceSummaryRowModel> attendanceRows =
      <AttendanceSummaryRowModel>[];

  bool rosterLoading = false;
  String? rosterError;

  /// The active membership context (first membership), if any.
  SchoolContextModel? get activeContext => contexts.firstOrNull;

  /// True when the register was last served from the device cache.
  bool offlineMode = false;

  /// Registers saved offline and still waiting to sync.
  int pendingAttendance = 0;

  /// True when the last [saveAttendanceDay] queued offline instead of
  /// reaching the server (the snackbar reads this).
  bool lastSaveQueued = false;

  /// Refreshes the offline queue counter (workspace shell badge).
  Future<void> refreshPendingAttendance() async {
    pendingAttendance =
        SchoolAttendanceQueue.pending(_session.prefs).length;
    notifyListeners();
  }

  /// Loads the class list (once per school) and the roster for [classId].
  /// Offline (founder directive 2026-10-04): the roster falls back to the
  /// device cache so the register still opens - the server stays the
  /// source of truth, the cache is only a read snapshot.
  Future<void> loadRoster(String schoolId, {String classId = ''}) async {
    rosterLoading = true;
    rosterError = null;
    notifyListeners();
    try {
      if (classes.isEmpty) {
        classes = await _api.schoolClasses(schoolId);
        await SchoolRosterCache.cacheClasses(
            _session.prefs, schoolId, classes);
      }
      roster = await _api.schoolStudents(schoolId, classId: classId);
      if (classId.isNotEmpty) {
        await SchoolRosterCache.cacheStudents(
            _session.prefs, schoolId, classId, roster);
      }
      offlineMode = false;
    } on ApiException catch (e) {
      rosterError = e.message;
    } on NetworkException catch (_) {
      if (classes.isEmpty) {
        classes = SchoolRosterCache.cachedClasses(_session.prefs, schoolId);
      }
      if (classId.isNotEmpty) {
        roster = SchoolRosterCache.cachedStudents(
            _session.prefs, schoolId, classId);
      }
      offlineMode = true;
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
      final int i =
          roster.indexWhere((SchoolStudentModel s) => s.id == saved.id);
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

  /// Pulls one day's register and seeds [marks] with it. Offline, the
  /// cached server copy is seeded first and any queued local sheet for
  /// the same day is layered on top (the device's own marks win until
  /// they sync).
  Future<void> loadAttendanceDay(
      String schoolId, String classId, String day) async {
    rosterLoading = true;
    rosterError = null;
    notifyListeners();
    try {
      final List<AttendanceEntryModel> entries =
          await _api.attendanceDay(schoolId, classId, day);
      marks.clear();
      for (final AttendanceEntryModel e in entries) {
        marks[e.studentId] = e;
      }
      await SchoolRosterCache.cacheAttendanceDay(
          _session.prefs, schoolId, classId, day, entries);
      if (roster.isEmpty || roster.first.classId != classId) {
        roster = await _api.schoolStudents(schoolId, classId: classId);
        await SchoolRosterCache.cacheStudents(
            _session.prefs, schoolId, classId, roster);
      }
      offlineMode = false;
    } on ApiException catch (e) {
      rosterError = e.message;
    } on NetworkException catch (_) {
      marks.clear();
      for (final AttendanceEntryModel e in SchoolRosterCache
          .cachedAttendanceDay(_session.prefs, schoolId, classId, day)) {
        marks[e.studentId] = e;
      }
      final OfflineAttendanceSession? queued =
          SchoolAttendanceQueue.sessionFor(
              _session.prefs, schoolId, classId, day);
      if (queued != null) {
        for (final AttendanceEntryModel e in queued.entries) {
          marks[e.studentId] = e;
        }
      }
      if (roster.isEmpty || roster.first.classId != classId) {
        roster = SchoolRosterCache.cachedStudents(
            _session.prefs, schoolId, classId);
      }
      if (classes.isEmpty) {
        classes = SchoolRosterCache.cachedClasses(_session.prefs, schoolId);
      }
      offlineMode = true;
    } finally {
      rosterLoading = false;
      notifyListeners();
    }
  }

  /// Marks one student locally; [saveAttendanceDay] pushes the sheet.
  void mark(String studentId, String status, {String note = ''}) {
    marks[studentId] =
        AttendanceEntryModel(studentId: studentId, status: status, note: note);
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
  /// Offline (founder directive 2026-10-04): the sheet is queued on the
  /// device with the device id and reported as saved - the auto-sync
  /// replays it through the same endpoint once a connection returns.
  Future<int?> saveAttendanceDay(
      String schoolId, String classId, String day) async {
    lastError = null;
    final List<AttendanceEntryModel> entries =
        marks.values.toList(growable: false);
    if (entries.isEmpty) return 0;
    lastSaveQueued = false;
    try {
      final int saved =
          await _api.saveAttendance(schoolId, classId, day, entries);
      await refreshPendingAttendance();
      return saved;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (_) {
      final int pending = await SchoolAttendanceQueue.enqueue(
        _session.prefs,
        OfflineAttendanceSession(
          id: OfflineAttendanceSession.buildId(schoolId, classId, day),
          schoolId: schoolId,
          classId: classId,
          day: day,
          entries: entries,
          deviceId: await DeviceId.get(),
          markedAt: DateTime.now(),
        ),
      );
      lastSaveQueued = true;
      pendingAttendance = pending;
      return entries.length;
    }
    notifyListeners();
    return null;
  }

  /// Replays every queued register sheet to the server. Returns how many
  /// synced. Merge policy: the server is the source of truth for the
  /// roster; attendance rows are append-only upserts keyed by the day,
  /// so replaying is idempotent. A PERMANENT server refusal (e.g. the
  /// teacher's assignment was revoked) drops the sheet - retrying a 4xx
  /// forever would jam the queue.
  Future<int> flushOfflineAttendance() async {
    final List<OfflineAttendanceSession> queued =
        SchoolAttendanceQueue.pending(_session.prefs);
    int synced = 0;
    for (final OfflineAttendanceSession s in queued) {
      try {
        await _api.saveAttendance(s.schoolId, s.classId, s.day, s.entries);
        await SchoolAttendanceQueue.markSynced(_session.prefs, s.id);
        synced++;
      } on NetworkException catch (_) {
        // Still offline - keep the sheet queued for the next trigger.
        break;
      } on ApiException catch (e) {
        lastError = 'Offline register for ${s.day} was refused: ${e.message}';
        await SchoolAttendanceQueue.remove(_session.prefs, s.id);
      }
    }
    await refreshPendingAttendance();
    return synced;
  }

  /// Loads the per-student rates for a window (inclusive dates).
  Future<void> loadAttendanceSummary(
    String schoolId,
    String classId,
    String from,
    String to,
  ) async {
    try {
      attendanceRows =
          await _api.attendanceSummary(schoolId, classId, from, to);
    } on ApiException catch (e) {
      rosterError = e.message;
    } on NetworkException catch (e) {
      rosterError = e.message;
    }
    notifyListeners();
  }

  // ---- staff, results, id cards + plan (MOB-SCHOOL) -------------------

  /// The school's subjects (cached for the session once loaded).
  List<SchoolSubjectInfo> subjects = <SchoolSubjectInfo>[];

  Future<List<SchoolSubjectInfo>> loadSubjects(String schoolId) async {
    if (subjects.isNotEmpty) return subjects;
    lastError = null;
    try {
      subjects = await _api.schoolSubjects(schoolId);
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return subjects;
  }

  // ---- live syllabus (the online syllabus tab) -------------------------

  /// The class+subject pairs taught in the school (cached per school
  /// for the session) - the syllabus pickers' shared list.
  final Map<String, List<SchoolClassSubjectPair>> _pairCache =
      <String, List<SchoolClassSubjectPair>>{};

  Future<List<SchoolClassSubjectPair>> loadClassSubjects(String schoolId) async {
    final List<SchoolClassSubjectPair>? cached = _pairCache[schoolId];
    if (cached != null) return cached;
    lastError = null;
    try {
      final List<SchoolClassSubjectPair> pairs =
          await _api.schoolClassSubjects(schoolId);
      _pairCache[schoolId] = pairs;
      notifyListeners();
      return pairs;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    return const <SchoolClassSubjectPair>[];
  }

  /// One class + subject's syllabus terms, read straight from online
  /// (GET /school/syllabus) - the same fetch the web portal makes.
  /// Cached per class+subject for the session so tab switches never
  /// re-fetch.
  final Map<String, List<SchoolSyllabusTerm>> _syllabusCache =
      <String, List<SchoolSyllabusTerm>>{};

  Future<List<SchoolSyllabusTerm>> loadSchoolSyllabus(
    String schoolId,
    String classId,
    String subjectId,
  ) async {
    final String key = '$schoolId/$classId/$subjectId';
    final List<SchoolSyllabusTerm>? cached = _syllabusCache[key];
    if (cached != null) return cached;
    lastError = null;
    try {
      final List<SchoolSyllabusTerm> terms =
          await _api.schoolSyllabus(schoolId, classId, subjectId);
      _syllabusCache[key] = terms;
      notifyListeners();
      return terms;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    return const <SchoolSyllabusTerm>[];
  }

  /// Every staff member (management only) - the Teachers screen list.
  List<SchoolMemberSummaryModel> members = <SchoolMemberSummaryModel>[];
  bool membersLoading = false;

  Future<void> loadMembers(String schoolId) async {
    membersLoading = true;
    lastError = null;
    notifyListeners();
    try {
      members = await _api.schoolMembers(schoolId);
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    } finally {
      membersLoading = false;
      notifyListeners();
    }
  }

  /// Management creates a teacher account; returns the new member or
  /// null with [lastError] set.
  Future<SchoolMemberSummaryModel?> createTeacher(
    String schoolId, {
    required String fullName,
    required String email,
    required String password,
    String staffCode = '',
  }) async {
    lastError = null;
    try {
      final SchoolMemberSummaryModel member = await _api.schoolCreateTeacher(
        schoolId,
        fullName: fullName,
        email: email,
        password: password,
        staffCode: staffCode,
      );
      members.add(member);
      notifyListeners();
      return member;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return null;
  }

  /// The caller's own class+subject assignments (teachers; management
  /// passes any memberId to read someone else's).
  List<SchoolAssignmentModel> assignments = <SchoolAssignmentModel>[];

  Future<List<SchoolAssignmentModel>> loadAssignments(
      String schoolId, String memberId) async {
    lastError = null;
    try {
      assignments = await _api.schoolAssignments(schoolId, memberId);
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return assignments;
  }

  /// Grants (or revokes) one teacher's class+subject assignment.
  Future<bool> setAssignment(
    String schoolId, {
    required String memberId,
    required String classId,
    required String subjectId,
    required bool remove,
  }) async {
    lastError = null;
    try {
      await _api.schoolSetAssignment(
        schoolId,
        memberId: memberId,
        classId: classId,
        subjectId: subjectId,
        remove: remove,
      );
      assignments.removeWhere((SchoolAssignmentModel a) =>
          a.memberId == memberId &&
          a.classId == classId &&
          a.subjectId == subjectId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return false;
  }

  /// The class ids the caller may work with. null = NO restriction
  /// (management sees every class); a non-null set = the teacher's
  /// assigned classes only (possibly empty = nothing assigned yet).
  Set<String>? allowedClassIds() {
    final SchoolContextModel? ctx = activeContext;
    if (ctx == null || ctx.member.isManagement) return null;
    return <String>{
      for (final SchoolAssignmentModel a in assignments) a.classId,
    };
  }

  /// The class broadsheet for one class + term + session.
  List<SchoolResultModel> results = <SchoolResultModel>[];
  bool resultsLoading = false;

  Future<void> loadResults(
    String schoolId, {
    required String classId,
    required int term,
    String session = '',
  }) async {
    resultsLoading = true;
    lastError = null;
    notifyListeners();
    try {
      results = await _api.schoolResults(
        schoolId,
        classId: classId,
        term: term,
        session: session,
      );
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    } finally {
      resultsLoading = false;
      notifyListeners();
    }
  }

  /// One student's full result sheet (null on failure).
  Future<SchoolResultModel?> resultSheet(
    String schoolId, {
    required String studentId,
    required int term,
    String session = '',
  }) async {
    lastError = null;
    try {
      return await _api.schoolResultSheet(
        schoolId,
        studentId: studentId,
        term: term,
        session: session,
      );
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    return null;
  }

  /// Saves one student's subject scores (teacher-assigned or management).
  Future<SchoolResultItemModel?> saveResultItem(
    String schoolId, {
    required String studentId,
    required String classId,
    required String subjectId,
    required int term,
    required String session,
    required num ca1,
    required num ca2,
    required num exam,
  }) async {
    lastError = null;
    try {
      final SchoolResultItemModel item = await _api.schoolSaveResultItem(
        schoolId,
        studentId: studentId,
        classId: classId,
        subjectId: subjectId,
        term: term,
        session: session,
        ca1: ca1,
        ca2: ca2,
        exam: exam,
      );
      final int i = results.indexWhere(
          (SchoolResultModel r) => r.studentId == studentId);
      if (i >= 0) {
        final SchoolResultModel row = results[i];
        final List<SchoolResultItemModel> items =
            row.items
                .where((SchoolResultItemModel it) =>
                    it.subjectId != item.subjectId)
                .toList()
              ..add(item);
        results[i] = SchoolResultModel(
          id: row.id,
          studentId: row.studentId,
          studentName: row.studentName,
          admissionNo: row.admissionNo,
          classId: row.classId,
          className: row.className,
          term: row.term,
          session: row.session,
          status: row.status,
          pin: row.pin,
          marksObtainable: row.marksObtainable,
          teacherReport: row.teacherReport,
          principalReport: row.principalReport,
          schoolName: row.schoolName,
          items: items,
        );
      }
      notifyListeners();
      return item;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return null;
  }

  /// The issued ID card ledger (management). Teachers read the roster
  /// preview instead - the server keeps the ledger management-only.
  List<SchoolIdCardModel> idCards = <SchoolIdCardModel>[];
  bool idCardsLoading = false;

  Future<void> loadIdCards(
    String schoolId, {
    String classId = '',
    String session = '',
  }) async {
    idCardsLoading = true;
    lastError = null;
    notifyListeners();
    try {
      idCards = await _api.schoolIdCards(
        schoolId,
        classId: classId,
        session: session,
      );
    } on ApiException catch (e) {
      lastError = e.message;
      idCards = <SchoolIdCardModel>[];
    } on NetworkException catch (e) {
      lastError = e.message;
      idCards = <SchoolIdCardModel>[];
    } finally {
      idCardsLoading = false;
      notifyListeners();
    }
  }

  /// Batch-issues ID cards for a class (management). Returns the count
  /// issued, or null on failure.
  Future<int?> issueIdCards(
    String schoolId, {
    String classId = '',
    required String session,
  }) async {
    lastError = null;
    try {
      final int issued = await _api.schoolIssueIdCards(
        schoolId,
        classId: classId,
        session: session,
      );
      await loadIdCards(schoolId, classId: classId, session: session);
      return issued;
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
    }
    notifyListeners();
    return null;
  }

  /// The subscription summary (management only surface).
  SchoolPlanModel? plan;

  Future<void> loadPlan(String schoolId) async {
    lastError = null;
    try {
      plan = await _api.schoolPlan(schoolId);
    } on ApiException catch (e) {
      lastError = e.message;
    } on NetworkException catch (e) {
      lastError = e.message;
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
      final Map<String, dynamic> j = jsonDecode(raw) as Map<String, dynamic>;
      return j.map<String, String>(
        (String k, dynamic v) => MapEntry(k, (v ?? '').toString()),
      );
    } on FormatException {
      return null;
    }
  }
}
