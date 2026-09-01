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
