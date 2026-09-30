/// Study-reader + explanation-sheet behaviour tests (founder directive
/// 2026-09): the explanation opens as a REAL modal bottom sheet whose
/// question list scrolls, the correct option + explanation are never
/// locked, the AI pill needs no graded attempt, and stale sanitized
/// downloads re-fetch the answer-bearing bundle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/models.dart';
import 'package:renance/storage.dart';
import 'package:renance/ui/explanation_sheet.dart';
import 'package:renance/ui/study_reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A bundle that carries the founder-directive answer material.
Bundle answeredBundle(String code) => Bundle(
      code: code,
      title: code,
      version: 2,
      questionCount: 2,
      totalMarks: 2,
      durationMinutes: 10,
      questions: const <BundleQuestion>[
        BundleQuestion(
          id: 'q1',
          type: 'mcq',
          stem: 'one?',
          marks: 1,
          options: <String, String>{'A': 'x', 'B': 'y'},
          answer: 'B',
          explanation: 'Because y follows x.',
        ),
        BundleQuestion(
          id: 'q2',
          type: 'mcq',
          stem: 'two?',
          marks: 1,
          options: <String, String>{'A': 'x', 'B': 'y'},
          answer: 'A',
        ),
      ],
    );

/// The old sanitized shape: same questions, answers stripped.
Bundle sanitizedBundle(String code) => Bundle(
      code: code,
      title: code,
      version: 1,
      questionCount: 2,
      totalMarks: 2,
      durationMinutes: 10,
      questions: const <BundleQuestion>[
        BundleQuestion(
          id: 'q1',
          type: 'mcq',
          stem: 'one?',
          marks: 1,
          options: <String, String>{'A': 'x', 'B': 'y'},
        ),
        BundleQuestion(
          id: 'q2',
          type: 'mcq',
          stem: 'two?',
          marks: 1,
          options: <String, String>{'A': 'x', 'B': 'y'},
        ),
      ],
    );

class _StubApi extends ApiClient {
  _StubApi({this.bundles = const <String>[], this.fail = false})
      : super(baseUrl: 'http://fake');

  /// Sequence of bundles the /bundles/{code} call serves, oldest first.
  final List<String> bundles;
  final bool fail;
  int bundleCalls = 0;

  @override
  Future<Bundle> bundle(String code) async {
    bundleCalls++;
    if (fail) {
      throw NetworkException('offline - check your connection and retry');
    }
    if (bundles.isEmpty) return sanitizedBundle(code);
    return answeredBundle(bundles[bundleCalls - 1]);
  }
}

void main() {
  group('SyncController.loadBank - answer-pack migration', () {
    test('a stale sanitized pack re-fetches the answer-bearing bundle',
        () async {
      final _StubApi api = _StubApi(bundles: <String>['pack-a']);
      final MemoryPackStore store = MemoryPackStore();
      await store.savePack(sanitizedBundle('pack-a'), 'sha-a');
      final SyncController sync = SyncController(api: api, store: store);

      final Bundle? loaded = await sync.loadBank('pack-a', 'sha-a');

      expect(api.bundleCalls, 1, reason: 'stale pack must re-fetch');
      expect(loaded, isNotNull);
      expect(loaded!.questions.first.answer, 'B');
      expect(
        (await store.loadPackByCode('pack-a'))!.questions.first.answer,
        'B',
        reason: 'the refreshed bundle must replace the stale download',
      );
    });

    test('offline keeps the stale local pack reading', () async {
      final _StubApi api = _StubApi(fail: true);
      final MemoryPackStore store = MemoryPackStore();
      await store.savePack(sanitizedBundle('pack-a'), 'sha-a');
      final SyncController sync = SyncController(api: api, store: store);

      final Bundle? loaded = await sync.loadBank('pack-a', 'sha-a');

      expect(loaded, isNotNull,
          reason: 'offline: the stale pack beats a dead reader');
      expect(loaded!.questions, isNotEmpty);
    });

    test('an answer-bearing pack never hits the network', () async {
      final _StubApi api = _StubApi(bundles: <String>['pack-a']);
      final MemoryPackStore store = MemoryPackStore();
      await store.savePack(answeredBundle('pack-a'), 'sha-a');
      final SyncController sync = SyncController(api: api, store: store);

      final Bundle? loaded = await sync.loadBank('pack-a', 'sha-a');

      expect(api.bundleCalls, 0, reason: 'fresh pack reads local-first');
      expect(loaded!.questions.first.answer, 'B');
    });
  });

  group('ExplanationSheet - never locked', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      String correct = 'B',
      String explanation = 'Because y follows x.',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExplanationSheet(
              title: 'Question',
              questionNumber: 1,
              stem: 'one?',
              options: const <String, String>{'A': 'x', 'B': 'y'},
              correct: correct,
              explanation: explanation,
              questionId: 'q1',
              saved: false,
              onToggleSave: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('correct option + explanation + AI pill show (web parity)',
        (WidgetTester tester) async {
      await pumpSheet(tester);
      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('Correct Option B'), findsOneWidget);
      expect(find.text('Because y follows x.'), findsOneWidget);
      expect(
          find.textContaining("Get Renance's AI Explanation"), findsOneWidget,
          reason: 'the AI pill must not need a graded attempt');
      expect(
        find.textContaining('Submit the paper to unlock'),
        findsNothing,
        reason: 'the lock message is gone',
      );
    });

    testWidgets('without a correct letter the explanation still shows',
        (WidgetTester tester) async {
      await pumpSheet(tester, correct: '');
      expect(find.text('Because y follows x.'), findsOneWidget);
      expect(find.textContaining('Correct Option'), findsNothing);
      expect(find.textContaining('Submit the paper to unlock'), findsNothing);
    });

    testWidgets('the question list scrolls inside the sheet',
        (WidgetTester tester) async {
      // Eight tall options push the Explanation card below the fold;
      // dragging the sheet body scrolls it into view (the old inline
      // overlay used to resize the panel instead of scrolling).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExplanationSheet(
              title: 'Question',
              questionNumber: 1,
              stem: 'one?',
              options: <String, String>{
                for (int i = 0; i < 8; i++)
                  String.fromCharCode(65 + i):
                      'A reasonably long option body number $i that wraps',
              },
              correct: 'B',
              explanation: 'Because y follows x.',
              questionId: 'q1',
              saved: false,
              onToggleSave: () {},
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explanation'), findsNothing,
          reason: 'the explanation starts below the fold');
      final Finder sheetScrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Explanation'),
        240,
        scrollable: sheetScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('Explanation'), findsOneWidget);
    });
  });

  group('StudyReaderScreen - explanation opens as a modal', () {
    testWidgets('View Explanation opens a modal bottom sheet with a barrier',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SessionStore session =
          SessionStore(await SharedPreferences.getInstance());
      final _StubApi api = _StubApi(bundles: <String>['test-bank']);
      final MemoryPackStore store = MemoryPackStore();
      await store.savePack(answeredBundle('test-bank'), 'sha');
      final SyncController sync = SyncController(api: api, store: store);

      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            Provider<ApiClient>.value(value: api),
            Provider<SessionStore>.value(value: session),
            Provider<PackStore>.value(value: store),
            ChangeNotifierProvider<SyncController>(
              create: (_) => sync,
            ),
          ],
          child: const MaterialApp(
            home: StudyReaderScreen(
              bank: 'test-bank',
              sha: 'sha',
              title: 'Test Bank · Study',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Explanation').first);
      await tester.pumpAndSettle();

      // A real modal route: barrier + the sheet's own header + content.
      expect(find.byType(ModalBarrier), findsWidgets);
      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('Correct Option B'), findsOneWidget);

      // And it dismisses through the barrier - the old inline overlay
      // had neither barrier nor dismissal.
      await tester.tapAt(tester.getTopLeft(find.byType(ModalBarrier).first));
      await tester.pumpAndSettle();
      expect(find.text('Question 1'), findsNothing);
    });
  });
}
