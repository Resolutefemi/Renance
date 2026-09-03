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
      '/me/review': () => <String, dynamic>{
            'due': <dynamic>[
              <String, dynamic>{
                'topic': 'Organic Chemistry',
                'ease': 1.9,
                'intervalDays': 3,
                'repetitions': 0,
                'lapses': 2,
                'dueOn': '2026-09-01',
                'lastCorrect': 1,
                'lastTotal': 4,
              },
            ],
            'upcoming': <dynamic>[
              <String, dynamic>{
                'topic': 'Optics',
                'ease': 2.6,
                'intervalDays': 6,
                'repetitions': 2,
                'lapses': 0,
                'dueOn': '2026-09-09',
                'lastCorrect': 5,
                'lastTotal': 5,
              },
            ],
            'stats': <String, dynamic>{
              'tracked': 2,
              'due': 1,
              'mature': 0,
              'learning': 2,
            },
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
    // spaced repetition: 1 topic due today, queue preview = due + upcoming
    expect(student.dueTopics, 1);
    expect(student.review?.stats.tracked, 2);
    expect(student.queuePreview.length, 2);
    expect(student.queuePreview.first.topic, 'Organic Chemistry');
    expect(student.queuePreview.first.status(DateTime(2026, 9, 4)), 'overdue');
    expect(student.queuePreview.last.status(DateTime(2026, 9, 4)), 'later');
    expect(student.queuePreview.last.laterLabel, 'in 6d');
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
      '/me/review': () => <String, dynamic>{
            'due': <dynamic>[],
            'upcoming': <dynamic>[],
            'stats': <String, dynamic>{
              'tracked': 0,
              'due': 0,
              'mature': 0,
              'learning': 0,
            },
          },
    });

    final student = StudentController(api: api, store: MemoryPackStore());
    await student.refresh();

    expect(student.targetTitle, 'Set your target');
    expect(student.questionsToReview, 0);
    expect(student.accuracyPct, 0);
    expect(student.coveragePct, 0);
    expect(student.daysToTarget, isNull);
    // zero-state review queue: empty, never a crash
    expect(student.dueTopics, 0);
    expect(student.queuePreview, isEmpty);
  });
}

