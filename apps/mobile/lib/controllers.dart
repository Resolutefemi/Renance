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
