import 'package:flutter_test/flutter_test.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/models.dart';
import 'package:renance/storage.dart';

/// Configurable fake: subclass the real client so signatures stay honest.
class FakeLessonsApi extends ApiClient {
  FakeLessonsApi({this.metas = const <LessonMeta>[], this.lessonError})
      : super(baseUrl: 'http://fake');

  List<LessonMeta> metas;
  Exception? lessonError;
  List<String> savedSlugs = <String>[];
  int lessonsCalls = 0;

  @override
  Future<List<LessonMeta>> lessons() async {
    lessonsCalls++;
    return metas;
  }

  @override
  Future<Lesson> lesson(String slug) async {
    final Exception? err = lessonError;
    if (err != null) throw err;
    return Lesson(
      slug: slug,
      title: 'Lesson $slug',
      minutes: 5,
      summary: 'Summary of $slug',
      sections: <LessonSection>[
        LessonSection(heading: 'One', blocks: <LessonBlock>[
          LessonBlock(type: 'p', text: 'Hello **world**.'),
        ]),
      ],
    );
  }
}

class RecordingStore extends MemoryPackStore {
  @override
  Future<void> saveLessonMetas(List<LessonMeta> lessons) async {
    savedSlugs = lessons.map((LessonMeta l) => l.slug).toList();
    await super.saveLessonMetas(lessons);
  }

  List<String> savedSlugs = <String>[];
}

LessonMeta _meta(String slug) => LessonMeta(
      slug: slug,
      title: 'Lesson $slug',
      minutes: 5,
      summary: 'Summary of $slug',
      subject: 'Biology',
    );

void main() {
  group('LessonsController', () {
    test('load fetches metas and caches them for offline reuse', () async {
      final api = FakeLessonsApi(metas: <LessonMeta>[_meta('a'), _meta('b')]);
      final store = RecordingStore();
      final controller = LessonsController(api: api, store: store);

      await controller.load();

      expect(controller.phase, LessonsPhase.ready);
      expect(controller.lessons.length, 2);
      expect(controller.error, '');
      expect(store.savedSlugs, <String>['a', 'b']);
      expect(api.lessonsCalls, 1);
    });

    test('load skips refetch when the library is already in memory', () async {
      final api = FakeLessonsApi(metas: <LessonMeta>[_meta('a')]);
      final controller = LessonsController(api: api, store: MemoryPackStore());

      await controller.load();
      await controller.load();

      expect(api.lessonsCalls, 1);
    });

    test('offline load falls back to cached metas with an offline note',
        () async {
      final store = MemoryPackStore();
      await store.saveLessonMetas(<LessonMeta>[_meta('cached-1')]);
      // simulate a network failure by throwing from lessons()
      final offlineApi = _OfflineLessonsApi();
      final controller = LessonsController(api: offlineApi, store: store);

      await controller.load();

      expect(controller.phase, LessonsPhase.ready);
      expect(controller.lessons.single.slug, 'cached-1');
      expect(controller.error, contains('Offline'));
    });

    test('loadLesson prefers the network and refreshes the cache', () async {
      final api = FakeLessonsApi();
      final store = MemoryPackStore();
      final controller = LessonsController(api: api, store: store);

      final Lesson? les = await controller.loadLesson('cell-structure');

      expect(les, isNotNull);
      expect(les!.sections.single.blocks.single.text, 'Hello **world**.');
      expect((await store.loadLesson('cell-structure')), isNotNull);
    });

    test('loadLesson falls back to cache when offline', () async {
      final store = MemoryPackStore();
      await store.saveLesson(_fullLesson('cached'));
      final controller =
          LessonsController(api: _OfflineLessonsApi(), store: store);

      final Lesson? les = await controller.loadLesson('cached');

      expect(les, isNotNull);
      expect(les!.slug, 'cached');
    });
  });

  group('TutorController', () {
    test('send appends user turn then assistant reply and records mode',
        () async {
      final controller = TutorController(
        api: _FakeTutorApi(replyText: 'Read the qualifiers first.', mode: 'ai'),
        attemptId: 'att-1',
        questionId: 'q-1',
      );

      await controller.send('Why is my answer wrong?');

      expect(controller.phase, TutorPhase.ready);
      expect(controller.turns.length, 2);
      expect(controller.turns.first.role, 'user');
      expect(controller.turns.last.role, 'assistant');
      expect(controller.turns.last.content, 'Read the qualifiers first.');
      expect(controller.mode, 'ai');
      expect(controller.aiEnabled, isTrue);
    });

    test('rate limit surfaces as a cooldown error, conversation intact',
        () async {
      final controller = TutorController(
        api: _FakeTutorApi(
            error: ApiException(429, 'rate_limited', 'slow down')),
        attemptId: 'att-1',
        questionId: 'q-1',
      );

      await controller.send('help');

      expect(controller.phase, TutorPhase.error);
      expect(controller.error, contains('cooling down'));
      // the student's ask is kept visible
      expect(controller.turns.single.role, 'user');
    });

    test('offline shows a network error', () async {
      final controller = TutorController(
        api: _FakeTutorApi(error: NetworkException('offline')),
        attemptId: 'att-1',
        questionId: 'q-1',
      );

      await controller.send('help');

      expect(controller.phase, TutorPhase.error);
      expect(controller.error, contains('connection'));
    });

    test('blank input and double-send are ignored', () async {
      final api = _FakeTutorApi(replyText: 'ok', mode: 'hint');
      final controller = TutorController(
        api: api,
        attemptId: 'att-1',
        questionId: 'q-1',
      );

      await controller.send('   ');
      expect(controller.turns, isEmpty);

      // simulate a stuck in-flight request: while thinking, sends drop
      api.delay = const Duration(milliseconds: 50);
      final Future<void> first = controller.send('first');
      final Future<void> second = controller.send('second');
      await Future.wait(<Future<void>>[first, second]);
      expect(controller.turns.where((t) => t.role == 'user').length, 1);
    });
  });

  group('Lesson model', () {
    test('json round-trip preserves sections, blocks and items', () {
      final Lesson les = _fullLesson('round-trip');
      final Lesson back =
          Lesson.fromJson((les.toJson() as Map).cast<String, dynamic>());

      expect(back.slug, 'round-trip');
      expect(back.sections.length, 2);
      expect(back.sections.last.blocks.single.type, 'ol');
      expect(back.sections.last.blocks.single.items, <String>['one', 'two']);
      expect(back.sections.first.blocks.first.text, 'Hello **world**.');
    });
  });
}

class _OfflineLessonsApi extends FakeLessonsApi {
  @override
  Future<List<LessonMeta>> lessons() async => throw NetworkException('offline');

  @override
  Future<Lesson> lesson(String slug) async => throw NetworkException('offline');
}

class _FakeTutorApi extends ApiClient {
  _FakeTutorApi({this.replyText = 'ok', this.mode = 'hint', this.error})
      : super(baseUrl: 'http://fake');

  final String replyText;
  final String mode;
  final Exception? error;
  Duration delay = Duration.zero;

  @override
  Future<TutorReply> tutorChat({
    required String attemptId,
    required String questionId,
    required List<TutorTurn> messages,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final Exception? err = error;
    if (err != null) throw err;
    return TutorReply(text: replyText, mode: mode);
  }
}

Lesson _fullLesson(String slug) => Lesson(
      slug: slug,
      title: 'Title $slug',
      subject: 'Physics',
      body: 'JAMB',
      tags: const <String>['mechanics'],
      minutes: 7,
      summary: 'Summary $slug',
      sections: <LessonSection>[
        LessonSection(heading: 'Intro', blocks: <LessonBlock>[
          LessonBlock(type: 'p', text: 'Hello **world**.'),
        ]),
        LessonSection(heading: 'Steps', blocks: <LessonBlock>[
          LessonBlock(type: 'ol', items: <String>['one', 'two']),
        ]),
      ],
    );
