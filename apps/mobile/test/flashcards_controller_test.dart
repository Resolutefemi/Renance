import 'package:flutter_test/flutter_test.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/models.dart';
import 'package:renance/storage.dart';
import 'package:renance/tts.dart';

/// Configurable flashcard API fake — subclass the real client so the
/// signatures stay honest (same pattern as controllers_test's FakeApi).
class FakeCardsApi extends ApiClient {
  FakeCardsApi({this.gradesError}) : super(baseUrl: 'http://fake');

  Exception? gradesError;
  int gradeCalls = 0;
  final List<FlashcardGrade> graded = <FlashcardGrade>[];

  FlashcardDeck deckFor(String code) => FlashcardDeck(
        code: code,
        title: 'Deck $code',
        cardCount: 2,
        cards: <FlashcardCard>[
          FlashcardCard(id: '$code-1', front: 'F1', back: 'B1', hint: 'H1'),
          FlashcardCard(id: '$code-2', front: 'F2', back: 'B2'),
        ],
      );

  @override
  Future<List<FlashcardDeckMeta>> flashcardDecks() async =>
      <FlashcardDeckMeta>[
        const FlashcardDeckMeta(
            code: 'bio', title: 'Biology', cardCount: 2, body: 'JAMB'),
      ];

  @override
  Future<FlashcardDeck> flashcardDeck(String code) async => deckFor(code);

  @override
  Future<List<CardProgress>> cardProgress() async => const <CardProgress>[];

  @override
  Future<List<CardProgress>> gradeCards(List<FlashcardGrade> grades) async {
    gradeCalls += grades.length;
    graded.addAll(grades);
    final Exception? err = gradesError;
    if (err != null) throw err;
    return <CardProgress>[
      for (final g in grades)
        CardProgress(
          cardId: g.cardId,
          deckCode: g.deckCode,
          box: g.grade == 'again' ? 1 : 2,
          correct: g.grade == 'again' ? 0 : 1,
          wrong: g.grade == 'again' ? 1 : 0,
          dueOn: '2026-09-04',
          lastGrade: g.grade,
        ),
    ];
  }
}

void main() {
  group('FlashcardsController — voice flashcards (ROADMAP #7)', () {
    test('loadDecks refreshes from the API and caches metas', () async {
      final api = FakeCardsApi();
      final store = MemoryPackStore();
      final c = FlashcardsController(
          api: api, store: store, speech: FakeSpeechEngine());

      await c.loadDecks();

      expect(c.phase, CardsPhase.ready);
      expect(c.decks, hasLength(1));
      expect(c.decks.first.code, 'bio');
      expect(await store.cachedDeckMetas(), hasLength(1));
      c.dispose();
    });

    test('openDeck reads a cached deck offline; flip speaks the back',
        () async {
      final api = FakeCardsApi();
      final store = MemoryPackStore();
      await store.saveDeck(api.deckFor('bio'));
      final speech = FakeSpeechEngine();
      final c = FlashcardsController(api: api, store: store, speech: speech);

      await c.openDeck('bio');
      await Future<void>.delayed(Duration.zero); // let the unawaited speak land

      expect(c.phase, CardsPhase.ready);
      expect(c.current?.id, 'bio-1');
      expect(speech.spoken, contains('F1')); // front auto-read

      c.flip();
      await Future<void>.delayed(Duration.zero);
      expect(c.revealed, isTrue);
      expect(speech.spoken, contains('B1'));
      c.dispose();
    });

    test('grade applies the Leitner rule, advances and syncs', () async {
      final api = FakeCardsApi();
      final store = MemoryPackStore();
      await store.saveDeck(api.deckFor('bio'));
      final c = FlashcardsController(
          api: api, store: store, speech: FakeSpeechEngine());

      await c.openDeck('bio');
      await c.grade('good');

      expect(c.progress['bio-1']?.box, 2);
      expect(c.progress['bio-1']?.lastGrade, 'good');
      expect(c.index, 1); // every grade advances
      expect(api.gradeCalls, 1);
      expect(await store.pendingCardGrades(), isEmpty);
      c.dispose();
    });

    test('offline grade queues and retryPendingGrades flushes FIFO',
        () async {
      final offline = FakeCardsApi()..gradesError = NetworkException('offline');
      final store = MemoryPackStore();
      await store.saveDeck(offline.deckFor('bio'));
      final c = FlashcardsController(
          api: offline, store: store, speech: FakeSpeechEngine());

      await c.openDeck('bio');
      await c.grade('good');
      expect(c.gradesPending, isTrue);
      expect(await store.pendingCardGrades(), hasLength(1));
      expect(c.progress['bio-1']?.box, 2); // local Leitner state stood

      // Back online: the flush pushes the queued grade.
      final online = FakeCardsApi();
      final c2 = FlashcardsController(
          api: online, store: store, speech: FakeSpeechEngine());
      await c2.retryPendingGrades();

      expect(online.graded.map((g) => g.cardId), contains('bio-1'));
      expect(await store.pendingCardGrades(), isEmpty);
      expect(c2.gradesPending, isFalse);
      c.dispose();
      c2.dispose();
    });

    test('toggleVoice stops and resumes reading', () async {
      final api = FakeCardsApi();
      final store = MemoryPackStore();
      await store.saveDeck(api.deckFor('bio'));
      final speech = FakeSpeechEngine();
      final c = FlashcardsController(api: api, store: store, speech: speech);

      await c.openDeck('bio');
      await Future<void>.delayed(Duration.zero);
      c.toggleVoice();
      expect(c.voiceOn, isFalse);
      expect(speech.stopCount, greaterThan(0));

      // Grading while muted never speaks.
      final int stopsBefore = speech.stopCount;
      await c.grade('good');
      expect(speech.spoken.last, 'F1'); // nothing new was spoken
      expect(speech.stopCount, stopsBefore);
      c.dispose();
    });
  });
}
