import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';
import 'package:renance/storage.dart';

Map<String, dynamic> fixtureBundle() => <String, dynamic>{
      'code': 'jamb-english-mock',
      'title': 'JAMB English — Practice Mock',
      'version': 1,
      'questionCount': 2,
      'totalMarks': 2,
      'durationMinutes': 15,
      'category': 'secondary',
      'body': 'JAMB',
      'questions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'jamb-english-mock-0001',
          'type': 'mcq',
          'stem': 'Choose the word most nearly OPPOSITE in meaning to: transparent',
          'marks': 1,
          'options': <String, String>{'A': 'clear', 'B': 'opaque'},
          'topic': 'Antonyms',
          'difficulty': 'easy',
        },
        <String, dynamic>{
          'id': 'jamb-english-mock-0002',
          'type': 'mcq',
          'stem': 'He has been good ______ mathematics since primary school.',
          'marks': 1,
          'options': <String, String>{'A': 'in', 'B': 'at', 'C': 'with', 'D': 'for'},
          'topic': 'Prepositions',
        },
      ],
    };

void main() {
  mainSyllabusBlock();
  group('Bundle parsing', () {
    test('parses full bundle with optional fields', () {
      final Bundle b = Bundle.fromJson(fixtureBundle());
      expect(b.code, 'jamb-english-mock');
      expect(b.questionCount, 2);
      expect(b.durationMinutes, 15);
      expect(b.body, 'JAMB');
      expect(b.category, 'secondary');
      expect(b.questions.length, 2);
      expect(b.questions[0].options['B'], 'opaque');
      expect(b.questions[0].topic, 'Antonyms');
      expect(b.questions[1].difficulty, '');
    });

    test('round-trips through toJson', () {
      final Bundle original = Bundle.fromJson(fixtureBundle());
      final Bundle reparsed = Bundle.fromJson(original.toJson());
      expect(reparsed.code, original.code);
      expect(reparsed.questionCount, original.questionCount);
      expect(reparsed.questions[0].options, original.questions[0].options);
      expect(reparsed.body, original.body);
    });

    test('tolerates missing optional fields', () {
      final Bundle b = Bundle.fromJson(<String, dynamic>{
        'code': 'x',
        'questions': <dynamic>[
          <String, dynamic>{'id': 'q1', 'stem': 's'},
        ],
      });
      expect(b.durationMinutes, isNull);
      expect(b.questions[0].marks, 1);
      expect(b.questions[0].options, isEmpty);
    });
  });

  group('Manifest parsing', () {
    test('parses exams with category/body for need-based filtering', () {
      final Manifest m = Manifest.fromJson(<String, dynamic>{
        'version': 'era2-g1',
        'exams': <dynamic>[
          <String, dynamic>{
            'code': 'jamb-english-mock',
            'title': 'JAMB English — Practice Mock',
            'questionCount': 20,
            'totalMarks': 20,
            'durationMinutes': 15,
            'body': 'JAMB',
            'category': 'secondary',
            'bundleSha256':
                '54fd8f7af4150000000000000000000000000000000000000000000000000000',
            'sizeBytes': 100,
          },
        ],
      });
      expect(m.exams.single.body, 'JAMB');
      expect(m.exams.single.durationMinutes, 15);
      expect(m.version, 'era2-g1');
    });
  });

  group('ExamResult parsing', () {
    test('parses score + topic breakdown', () {
      final ExamResult r = ExamResult.fromJson(<String, dynamic>{
        'score': 12,
        'total': 20,
        'breakdown': <dynamic>[
          <String, dynamic>{'topic': 'Antonyms', 'correct': 2, 'total': 3},
        ],
      });
      expect(r.score, 12);
      expect(r.breakdown.single.correct, 2);
    });
  });

  group('PendingSubmission', () {
    test('round-trips through JSON for the SQLite queue', () {
      final PendingSubmission p = PendingSubmission(
        id: 'a-1',
        code: 'jamb-english-mock',
        attemptId: 'a-1',
        answers: <String, String>{'q1': 'B', 'q2': 'A'},
        durationMs: 95000,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final PendingSubmission back = PendingSubmission.fromJson(p.toJson());
      expect(back.attemptId, 'a-1');
      expect(back.answers, p.answers);
      expect(back.durationMs, 95000);
    });
  });
}

// ---------------------------------------------------- syllabus + adaptive (4, 5)

void mainSyllabusBlock() {
  group('Bundle adaptive walk (ROADMAP #5)', () {
    Bundle pack() => Bundle.fromJson(<String, dynamic>{
          'code': 'p', 'title': 'P', 'version': 1,
          'questionCount': 3, 'totalMarks': 3,
          'questions': <dynamic>[
            <String, dynamic>{'id': 'q1', 'type': 'mcq', 'stem': 'a', 'marks': 1, 'topic': 'Algebra'},
            <String, dynamic>{'id': 'q2', 'type': 'mcq', 'stem': 'b', 'marks': 1, 'topic': 'Geometry'},
            <String, dynamic>{'id': 'q3', 'type': 'mcq', 'stem': 'c', 'marks': 1, 'topic': 'Algebra'},
          ],
        });

    test('withOrder re-sequences without mutating the source pack', () {
      final Bundle source = pack();
      final Bundle walked = source.withOrder(<String>['q2', 'q3', 'q1']);
      expect(walked.questions.map((q) => q.id).toList(), <String>['q2', 'q3', 'q1']);
      // The cached pack keeps its natural order.
      expect(source.questions.map((q) => q.id).toList(), <String>['q1', 'q2', 'q3']);
    });

    test('withOrder appends ids missing from a stale order', () {
      final walked = pack().withOrder(<String>['q2']);
      expect(walked.questions.map((q) => q.id).toList(), <String>['q2', 'q1', 'q3']);
      expect(walked.questionCount, 3);
    });

    test('AttemptStarted parses the adaptive payload', () {
      final started = AttemptStarted.fromJson(<String, dynamic>{
        'attemptId': 'a1', 'code': 'p', 'status': 'in_progress',
        'adaptive': true, 'order': <dynamic>['q2', 'q1'],
      });
      expect(started.adaptive, isTrue);
      expect(started.order, <String>['q2', 'q1']);

      final plain = AttemptStarted.fromJson(<String, dynamic>{
        'attemptId': 'a2', 'code': 'p', 'status': 'in_progress',
      });
      expect(plain.adaptive, isFalse);
      expect(plain.order, isNull);
    });
  });

  group('ExamResult weak topics (ROADMAP #4 deep links)', () {
    test('returns sub-60% topics, worst first', () {
      final result = ExamResult.fromJson(<String, dynamic>{
        'score': 2, 'total': 6,
        'breakdown': <dynamic>[
          <String, dynamic>{'topic': 'Strong', 'correct': 5, 'total': 5},
          <String, dynamic>{'topic': 'Awful', 'correct': 0, 'total': 4},
          <String, dynamic>{'topic': 'Shaky', 'correct': 1, 'total': 2},
        ],
      });
      final weak = result.weakTopics();
      expect(weak.map((r) => r.topic).toList(), <String>['Awful', 'Shaky']);
    });
  });

  group('Syllabus tree parsing (ROADMAP #4)', () {
    test('parses the mastery overlay payload', () {
      final tree = SyllabusTree.fromJson(<String, dynamic>{
        'body': 'JAMB',
        'stats': <String, dynamic>{'topics': 2, 'mastered': 1, 'learning': 1, 'unseen': 0, 'due': 0},
        'weakest': <dynamic>[
          <String, dynamic>{
            'topic': 'Logarithms', 'questions': 1, 'seen': true,
            'lastCorrect': 0, 'lastTotal': 1, 'accuracy': 0.0,
            'status': 'learning', 'weakness': 5.0,
          },
        ],
        'subjects': <dynamic>[
          <String, dynamic>{
            'subject': 'Mathematics',
            'sections': <dynamic>[
              <String, dynamic>{
                'title': 'Algebra', 'mastery': 0.5,
                'topics': <dynamic>[
                  <String, dynamic>{
                    'topic': 'Algebra', 'questions': 4, 'seen': true,
                    'lastCorrect': 2, 'lastTotal': 4, 'accuracy': 0.5,
                    'status': 'learning', 'dueOn': '2026-09-05', 'weakness': 1.9,
                  },
                ],
              },
            ],
          },
        ],
      });
      expect(tree.body, 'JAMB');
      expect(tree.stats.mastered, 1);
      expect(tree.weakest.single.topic, 'Logarithms');
      final topic = tree.subjects.single.sections.single.topics.single;
      expect(topic.dot, 2); // learning -> two lit dots
      expect(topic.status, 'learning');
    });
  });
}
