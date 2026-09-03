import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:renance/api_client.dart';
import 'package:renance/controllers.dart';
import 'package:renance/storage.dart';

void main() {
  // Canned JSON plumbing — the StudentController just aggregates.
  ApiClient apiWith(Map<String, dynamic Function()> routes) {
    return ApiClient(
      baseUrl: 'http://fake',
      client: MockClient((http.Request request) async {
        final match = routes.entries
            .firstWhere((e) => request.url.path.endsWith(e.key));
        return http.Response(
          jsonEncode(match.value()),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
  }

  test('StudentController derives target, backlog and accuracy from history',
      () async {
    final api = apiWith(<String, dynamic Function()>{
      '/me': () => <String, dynamic>{
            'user': <String, dynamic>{
              'id': 'u1',
              'username': 'ada',
              'profileCompleted': true,
            },
            'profile': <String, dynamic>{
              'fullName': 'Ada Obi',
              'institution': 'UI',
              'gradeLevel': 'SS3',
              'exams': <String>['JAMB'],
              'targetYear': 2027,
              'completed': true,
            },
          },
      '/me/gamification': () => <String, dynamic>{
            'state': <String, dynamic>{
              'currentStreak': 4,
              'bestStreak': 9,
              'totalXp': 640,
              'totalCorrect': 34,
              'attempts': 2,
              'level': 2,
            },
            'awards': <dynamic>[],
          },
      '/me/attempts': () => <String, dynamic>{
            'attempts': <dynamic>[
              <String, dynamic>{
                'attemptId': 'a2',
                'code': 'jamb-biology-mock',
                'status': 'graded',
                'startedAt': '2026-09-03T10:00:00Z',
                'submittedAt': '2026-09-03T10:40:00Z',
                'score': 30,
                'total': 50,
              },
              <String, dynamic>{
                'attemptId': 'a1',
                'code': 'jamb-mathematics-mock',
                'status': 'graded',
                'startedAt': '2026-09-02T10:00:00Z',
                'submittedAt': '2026-09-02T10:30:00Z',
                'score': 20,
                'total': 50,
              },
            ],
          },
    });

    final student = StudentController(api: api, store: MemoryPackStore());
    await student.refresh();

    // target title: JAMB -> UTME + stored year
    expect(student.targetTitle, 'UTME 2027');
    expect(student.targetChip, 'JAMB 2027');
    // countdown: May 1 2027 minus today is positive
    expect(student.daysToTarget, isNotNull);
    expect(student.daysToTarget, greaterThan(0));
    // backlog: (50-30) + (50-20) = 50 missed questions
    expect(student.questionsToReview, 50);
    // accuracy: (30+20)/(50+50) = 50%
    expect(student.accuracyPct, 50);
    // coverage: 2 distinct graded codes / 2 papers = 100%
    expect(student.coveragePct, 100);
    // streak pill
    expect(student.gamification?.state.currentStreak, 4);
  });

  test('StudentController empty history yields zero state, never a crash',
      () async {
    final api = apiWith(<String, dynamic Function()>{
      '/me': () => <String, dynamic>{
            'user': <String, dynamic>{
              'id': 'u1',
              'username': 'ada',
              'profileCompleted': true,
            },
            'profile': <String, dynamic>{
              'fullName': 'Ada Obi',
              'institution': 'UI',
              'gradeLevel': 'SS3',
              'exams': <String>[],
              'completed': true,
            },
          },
      '/me/gamification': () => <String, dynamic>{
            'state': <String, dynamic>{
              'currentStreak': 0,
              'bestStreak': 0,
              'totalXp': 0,
              'totalCorrect': 0,
              'attempts': 0,
              'level': 1,
            },
            'awards': <dynamic>[],
          },
      '/me/attempts': () => <String, dynamic>{'attempts': <dynamic>[]},
    });

    final student = StudentController(api: api, store: MemoryPackStore());
    await student.refresh();

    expect(student.targetTitle, 'Set your target');
    expect(student.questionsToReview, 0);
    expect(student.accuracyPct, 0);
    expect(student.coveragePct, 0);
    expect(student.daysToTarget, isNull);
  });
}

