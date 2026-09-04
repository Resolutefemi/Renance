import 'package:flutter_test/flutter_test.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/models.dart';
import 'package:renance/storage.dart';

/// Configurable fake: subclass the real client so signatures stay honest.
class FakeApi extends ApiClient {
  FakeApi({
    this.manifestResult = const <ExamMeta>[],
    this.bundleOverride,
    this.attemptResult,
    this.submitError,
  }) : super(baseUrl: 'http://fake');

  List<ExamMeta> manifestResult;
  Bundle? bundleOverride;
  AttemptView? attemptResult;
  Exception? submitError;
  int submitCalls = 0;
  final List<Map<String, String>> submitPayloads = <Map<String, String>>[];

  @override
  Future<Manifest> manifest() async =>
      Manifest(version: 'test', exams: manifestResult);

  @override
  Future<Bundle> bundle(String code) async {
    final Bundle? b = bundleOverride;
    if (b != null && b.code == code) return b;
    return Bundle(
      code: code,
      title: code,
      version: 1,
      questionCount: 2,
      totalMarks: 2,
      durationMinutes: 10,
      questions: const <BundleQuestion>[
        BundleQuestion(
            id: 'q1', type: 'mcq', stem: 'one?', marks: 1,
            options: <String, String>{'A': 'x', 'B': 'y'}),
        BundleQuestion(
            id: 'q2', type: 'mcq', stem: 'two?', marks: 1,
            options: <String, String>{'A': 'x', 'B': 'y'}),
      ],
    );
  }

  bool lastAdaptive = false;

  // Fatigue telemetry (ROADMAP #6) captures.
  int logSessionCalls = 0;
  final List<int> loggedLatencies = <int>[];

  @override
  Future<AttemptStarted> createAttempt(String code, {bool adaptive = false}) async {
    lastAdaptive = adaptive;
    return AttemptStarted(
      attemptId: 'a-1',
      code: 'pack',
      status: 'in_progress',
      adaptive: adaptive,
      order: adaptive ? const <String>['q2', 'q1'] : null,
    );
  }

  @override
  Future<void> submit(
      String attemptId, Map<String, String> answers, int durationMs) async {
    submitCalls += 1;
    submitPayloads.add(Map<String, String>.of(answers));
    final Exception? err = submitError;
    if (err != null) throw err;
  }

  @override
  Future<AttemptView> attempt(String attemptId) async {
    final AttemptView? v = attemptResult;
    if (v != null) return v;
    return const AttemptView(
        attemptId: 'a-1', code: 'pack', status: 'grading');
  }

  @override
  Future<FatigueSignal> logSession({
    required String startedAt,
    String? endedAt,
    String? attemptId,
    String? code,
    int? durationMs,
    List<int> latenciesMs = const <int>[],
  }) async {
    logSessionCalls += 1;
    loggedLatencies.addAll(latenciesMs);
    return FatigueSignal.none;
  }

  @override
  Future<FatigueState> fatigue() async => const FatigueState(
        level: 'none',
        suggestBreak: false,
        minutesToday: 0,
        minutesLast3h: 0,
        sessionsToday: 0,
      );
}

ExamMeta meta(String code, String body) => ExamMeta(
      code: code,
      title: code,
      questionCount: 2,
      totalMarks: 2,
      bundleSha256: 'sha-$code',
      body: body,
      sizeBytes: 10,
    );

Bundle bundleFor(String code) => Bundle(
      code: code,
      title: code,
      version: 1,
      questionCount: 2,
      totalMarks: 2,
      durationMinutes: 10,
      questions: const <BundleQuestion>[
        BundleQuestion(
            id: 'q1', type: 'mcq', stem: 'one?', marks: 1,
            options: <String, String>{'A': 'x', 'B': 'y'}),
        BundleQuestion(
            id: 'q2', type: 'mcq', stem: 'two?', marks: 1,
            options: <String, String>{'A': 'x', 'B': 'y'}),
      ],
    );

void main() {
  mainAdaptiveBlock();
  mainFatigueBlock();
  group('SyncController — need-based downloads', () {
    test('downloads only packs matching profile exams', () async {
      final FakeApi api = FakeApi()
        ..manifestResult = <ExamMeta>[
          meta('jamb-english-mock', 'JAMB'),
          meta('jamb-physics-mock', 'JAMB'),
          meta('cos101-university-mock', 'University Modules'),
        ];
      final MemoryPackStore store = MemoryPackStore();
      final SyncController sync =
          SyncController(api: api, store: store);

      await sync.bootstrap(profileExams: <String>['JAMB']);

      expect(sync.phase, SyncPhase.ready);
      final Set<String> have = await store.downloadedCodes();
      expect(have, <String>{'jamb-english-mock', 'jamb-physics-mock'});
      expect(sync.total, 2);
      sync.dispose();
    });

    test('falls back to ALL packs when nothing matches', () async {
      final FakeApi api = FakeApi()
        ..manifestResult = <ExamMeta>[
          meta('jamb-english-mock', 'JAMB'),
          meta('cos101-university-mock', 'University Modules'),
        ];
      final MemoryPackStore store = MemoryPackStore();
      final SyncController sync = SyncController(api: api, store: store);

      // WAEC/NECO packs don't exist yet in the mock era — an empty library
      // helps nobody, so the controller downloads everything instead.
      await sync.bootstrap(profileExams: <String>['WAEC']);

      expect((await store.downloadedCodes()).length, 2);
      sync.dispose();
    });

    test('skips packs already on device (sha-pinned cache)', () async {
      final FakeApi api = FakeApi()
        ..manifestResult = <ExamMeta>[meta('pack-a', 'JAMB')];
      final MemoryPackStore store = MemoryPackStore();
      await store.savePack(bundleFor('pack-a'), 'sha-pack-a');
      final SyncController sync = SyncController(api: api, store: store);

      await sync.bootstrap(profileExams: <String>['JAMB']);

      expect(sync.total, 0);
      expect(sync.done, 0);
      sync.dispose();
    });

    test('offline manifest surfaces an error phase, not a crash', () async {
      final SyncController sync = SyncController(
        api: _FailingManifestApi(),
        store: MemoryPackStore(),
      );
      await sync.bootstrap();
      expect(sync.phase, SyncPhase.error);
      sync.dispose();
    });
  });

  group('SyncController — offline submission queue', () {
    test('retryPending flushes on success', () async {
      final FakeApi api = FakeApi();
      final MemoryPackStore store = MemoryPackStore();
      await store.queueSubmission(PendingSubmission(
        id: 'a-1',
        code: 'pack',
        attemptId: 'a-1',
        answers: <String, String>{'q1': 'A'},
        durationMs: 1000,
        createdAt: DateTime.now(),
      ));
      final SyncController sync = SyncController(api: api, store: store);

      await sync.retryPending();

      expect(api.submitCalls, 1);
      expect(await store.pendingSubmissions(), isEmpty);
      expect(sync.pendingCount, 0);
      sync.dispose();
    });

    test('network failure keeps the entry queued', () async {
      final FakeApi api = FakeApi()..submitError = NetworkException('offline');
      final MemoryPackStore store = MemoryPackStore();
      await store.queueSubmission(PendingSubmission(
        id: 'a-1',
        code: 'pack',
        attemptId: 'a-1',
        answers: <String, String>{},
        durationMs: 1000,
        createdAt: DateTime.now(),
      ));
      final SyncController sync = SyncController(api: api, store: store);

      await sync.retryPending();

      expect(await store.pendingSubmissions(), hasLength(1));
      sync.dispose();
    });

    test('permanent server rejection clears the entry', () async {
      final FakeApi api = FakeApi()
        ..submitError = ApiException(409, 'already_submitted', 'nope');
      final MemoryPackStore store = MemoryPackStore();
      await store.queueSubmission(PendingSubmission(
        id: 'a-1',
        code: 'pack',
        attemptId: 'a-1',
        answers: <String, String>{},
        durationMs: 1000,
        createdAt: DateTime.now(),
      ));
      final SyncController sync = SyncController(api: api, store: store);

      await sync.retryPending();

      expect(await store.pendingSubmissions(), isEmpty);
      sync.dispose();
    });
  });

  group('ExamController', () {
    test('load uses the local cache and lands on intro', () async {
      final FakeApi api = FakeApi();
      final MemoryPackStore store = MemoryPackStore();
      final ExamController exam = ExamController(api: api, store: store);
      final ExamMeta m = meta('pack-a', 'JAMB');
      await store.savePack(bundleFor('pack-a'), 'sha-pack-a');

      await exam.load(m);

      expect(exam.phase, ExamPhase.intro);
      expect(exam.bundle!.code, 'pack-a');
      exam.dispose();
    });

    test('begin → answer → tick to zero submits and grades', () async {
      final FakeApi api = FakeApi()
        ..attemptResult = const AttemptView(
          attemptId: 'a-1',
          code: 'pack-a',
          status: 'graded',
          result: ExamResult(
            score: 1,
            total: 2,
            breakdown: <TopicRow>[],
          ),
        );
      final ExamController exam =
          ExamController(api: api, store: MemoryPackStore());
      final ExamMeta m = meta('pack-a', 'JAMB');
      await exam.load(m);
      await exam.begin();

      expect(exam.phase, ExamPhase.playing);
      exam.select('q1', 'A');
      exam.select('q2', 'B');
      expect(exam.answeredCount, 2);

      exam.secondsRemaining = 1;
      await exam.tick(); // hits zero → auto submit → poll → graded

      expect(exam.phase, ExamPhase.graded);
      expect(exam.result!.score, 1);
      expect(api.submitCalls, 1);
      exam.dispose();
    });

    test('offline submission is queued, never lost', () async {
      final FakeApi api = FakeApi()..submitError = NetworkException('offline');
      final MemoryPackStore store = MemoryPackStore();
      final ExamController exam = ExamController(api: api, store: store);
      final ExamMeta m = meta('pack-a', 'JAMB');
      await exam.load(m);
      await exam.begin();
      exam.select('q1', 'B');

      await exam.submit();

      expect(exam.phase, ExamPhase.queued);
      final List<PendingSubmission> pending =
          await store.pendingSubmissions();
      expect(pending, hasLength(1));
      expect(pending.single.answers['q1'], 'B');
      exam.dispose();
    });

    test('flags toggle on and off', () async {
      final ExamController exam =
          ExamController(api: FakeApi(), store: MemoryPackStore());
      await exam.load(meta('pack-a', 'JAMB'));

      exam.toggleFlag('q1');
      expect(exam.flags, contains('q1'));
      exam.toggleFlag('q1');
      expect(exam.flags, isNot(contains('q1')));
      exam.dispose();
    });
  });
}

class _FailingManifestApi extends ApiClient {
  _FailingManifestApi() : super(baseUrl: 'http://fake');

  @override
  Future<Manifest> manifest() async => throw NetworkException('no route');
}

// -------------------------------------------------- adaptive begin (ROADMAP #5)

void mainAdaptiveBlock() {
  group('ExamController adaptive begin', () {
    test('applies the server walk to the in-memory bundle only', () async {
      final api = FakeApi();
      final MemoryPackStore store = MemoryPackStore();
      final c = ExamController(api: api, store: store);
      await c.load(meta('pack', 'JAMB'));
      expect(c.bundle!.questions.map((q) => q.id).toList(), <String>['q1', 'q2']);

      c.adaptive = true;
      await c.begin();

      expect(api.lastAdaptive, isTrue);
      expect(c.appliedAdaptive, isTrue);
      expect(c.bundle!.questions.map((q) => q.id).toList(), <String>['q2', 'q1']);
      expect(c.phase, ExamPhase.playing);
    });

    test('non-adaptive begin keeps the natural order', () async {
      final api = FakeApi();
      final MemoryPackStore store = MemoryPackStore();
      final c = ExamController(api: api, store: store);
      await c.load(meta('pack', 'JAMB'));

      await c.begin();

      expect(api.lastAdaptive, isFalse);
      expect(c.appliedAdaptive, isFalse);
      expect(c.bundle!.questions.map((q) => q.id).toList(), <String>['q1', 'q2']);
    });
  });
}

// -------------------------------------------------- fatigue telemetry (6)

void mainFatigueBlock() {
  group('ExamController — fatigue telemetry (ROADMAP #6)', () {
    test('selects record latencies, the nudge fires on drift, break pauses the clock',
        () async {
      DateTime t = DateTime(2026, 9, 4, 10);
      final api = FakeApi();
      final store = MemoryPackStore();
      final b = tenQuestionBundle('pack');
      await store.savePack(b, 'sha-pack');
      final ExamController exam = ExamController(
        api: api,
        store: store,
        clock: () => t,
      );

      await exam.load(tenQuestionMeta('pack'));
      expect(exam.phase, ExamPhase.intro);
      await exam.begin();
      expect(exam.phase, ExamPhase.playing);

      // Five quick answers (8s each), then three slow ones (20s each):
      // after the 8th answer the drift is 20/8 = 2.5x -> mild nudge.
      for (var i = 1; i <= 5; i++) {
        t = t.add(const Duration(seconds: 8));
        exam.select('q$i', 'A');
      }
      expect(exam.nudgeVisible, isFalse); // only 5 samples — not enough
      for (var i = 6; i <= 8; i++) {
        t = t.add(const Duration(seconds: 20));
        exam.select('q$i', 'A');
      }
      expect(exam.latenciesMs, hasLength(8));
      expect(exam.signal.level, 'mild');
      expect(exam.nudgeVisible, isTrue);
      final int secondsBeforeBreak = exam.secondsRemaining;

      // Take 5 pauses the exam clock on its own countdown.
      exam.takeBreak();
      expect(exam.breakSecondsLeft, 300);
      expect(exam.nudgeVisible, isFalse);
      await exam.tick();
      expect(exam.breakSecondsLeft, 299);
      expect(exam.secondsRemaining, secondsBeforeBreak);
      exam.breakSecondsLeft = 1;
      await exam.tick();
      expect(exam.breakSecondsLeft, 0);
      await exam.tick(); // back to exam time
      expect(exam.secondsRemaining, secondsBeforeBreak - 1);

      // Keep going dismisses for the rest of the sitting.
      expect(exam.nudgeDismissed, isTrue); // takeBreak already dismissed
      exam.keepGoing();
      expect(exam.nudgeVisible, isFalse);
      exam.dispose();
    });

    test('submit posts the telemetry once (fire-and-forget)', () async {
      DateTime t = DateTime(2026, 9, 4, 10);
      final api = FakeApi()
        ..attemptResult = const AttemptView(
            attemptId: 'a-1',
            code: 'pack',
            status: 'graded',
            result: ExamResult(score: 2, total: 2, breakdown: <TopicRow>[]));
      final store = MemoryPackStore();
      await store.savePack(bundleFor('pack'), 'sha-pack');
      final ExamController exam = ExamController(
        api: api,
        store: store,
        clock: () => t,
      );

      await exam.load(meta('pack', 'JAMB'));
      await exam.begin();
      t = t.add(const Duration(seconds: 9));
      exam.select('q1', 'A');
      exam.next(); // advancing resets the per-question shown-at clock
      t = t.add(const Duration(seconds: 11));
      exam.select('q2', 'B');
      t = t.add(const Duration(seconds: 30));
      await exam.submit();
      // Let the unawaited telemetry POST land.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(exam.phase, ExamPhase.graded);
      expect(api.logSessionCalls, 1);
      expect(api.loggedLatencies, <int>[9000, 11000]);
      exam.dispose();
    });
  });
}

/// Bundle with [n] questions so telemetry tests can record real drift.
Bundle tenQuestionBundle(String code) {
  final questions = <BundleQuestion>[
    for (var i = 1; i <= 10; i++)
      BundleQuestion(
        id: 'q$i',
        type: 'mcq',
        stem: 'q$i?',
        marks: 1,
        options: const <String, String>{'A': 'x', 'B': 'y'},
      ),
  ];
  return Bundle(
    code: code,
    title: code,
    version: 1,
    questionCount: 10,
    totalMarks: 10,
    durationMinutes: 60,
    questions: questions,
  );
}

ExamMeta tenQuestionMeta(String code) => ExamMeta(
      code: code,
      title: code,
      questionCount: 10,
      totalMarks: 10,
      bundleSha256: 'sha-$code',
      body: 'JAMB',
      sizeBytes: 10,
    );
