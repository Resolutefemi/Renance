import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:renance/api_client.dart';
import 'package:renance/models.dart';
import 'package:renance/ui/progress_screen.dart';

Future<GamificationSummary> _summaryFrom(Map<String, dynamic> payload) async {
  final ApiClient api = ApiClient(
    baseUrl: 'http://fake',
    client: MockClient((http.Request request) async {
      if (request.url.path == '/me/gamification') {
        return http.Response(jsonEncode(payload), 200,
            headers: <String, String>{
              'content-type': 'application/json',
            });
      }
      return http.Response('not found', 404);
    }),
  );
  return api.gamification();
}

Future<void> _pumpHub(WidgetTester tester, ApiClient api) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ApiClient>.value(value: api),
      ],
      child: const MaterialApp(home: ProgressScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('gamification model parses server payload', () async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'state': <String, dynamic>{
        'currentStreak': 12,
        'bestStreak': 19,
        'totalXp': 3240,
        'totalCorrect': 210,
        'attempts': 24,
        'level': 7,
        'lastActive': '2026-09-03',
      },
      'awards': <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'first_blood',
          'earnedAt': '2026-09-01T10:00:00Z',
        },
        <String, dynamic>{
          'code': 'streak_3',
          'earnedAt': '2026-09-02T10:00:00Z',
        },
      ],
    };
    final GamificationSummary s = await _summaryFrom(payload);
    expect(s.state.currentStreak, 12);
    expect(s.state.level, 7);
    expect(s.state.levelProgress, closeTo(3240 % 500 / 500, 0.0001));
    expect(s.holds('first_blood'), isTrue);
    expect(s.holds('perfect_paper'), isFalse);
    expect(s.awards.length, 2);

    // The pure parser agrees with the endpoint round-trip.
    final GamificationSummary parsed =
        GamificationSummary.fromJson(payload);
    expect(parsed.state.bestStreak, 19);
  });

  testWidgets('hub renders streak, level and badges from the API',
      (WidgetTester tester) async {
    final ApiClient api = ApiClient(
      baseUrl: 'http://fake',
      client: MockClient((http.Request request) async {
        expect(request.url.path, '/me/gamification');
        return http.Response(
            jsonEncode(<String, dynamic>{
              'state': <String, dynamic>{
                'currentStreak': 12,
                'bestStreak': 19,
                'totalXp': 3240,
                'totalCorrect': 210,
                'attempts': 24,
                'level': 7,
                'lastActive': '2026-09-03',
              },
              'awards': <Map<String, dynamic>>[
                <String, dynamic>{
                  'code': 'first_blood',
                  'earnedAt': '2026-09-01T10:00:00Z',
                },
                <String, dynamic>{
                  'code': 'xp_500',
                  'earnedAt': '2026-09-02T10:00:00Z',
                },
              ],
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'});
      }),
    );

    await _pumpHub(tester, api);

    // Hero + pill + level.
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('12'), findsNWidgets(2)); // hero number + header pill
    expect(find.text('Best Streak: 19'), findsOneWidget);
    expect(find.text('Level 7'), findsOneWidget);
    expect(find.text('3,240 XP'), findsOneWidget);
    expect(find.text('3,500 XP'), findsOneWidget);

    // Badges: 8 tiles total; earned ones show the check chip icon.
    expect(find.text('BADGES'), findsOneWidget);
    expect(find.text('First Blood'), findsWidgets); // tile (+ maybe sheet)
    expect(find.text('Unstoppable'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.lock), findsNWidgets(6));

    // Recent awards ledger lists the newest badge.
    expect(find.text('RECENT AWARDS'), findsOneWidget);
    expect(find.text('Scholar Badge Earned'), findsOneWidget);
  });

  testWidgets('hub shows retry on network failure',
      (WidgetTester tester) async {
    final ApiClient api = ApiClient(
      baseUrl: 'http://fake',
      client: MockClient((http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, String>{
              'code': 'internal',
              'message': 'progress is unavailable right now',
            },
          }),
          500)),
    );
    await _pumpHub(tester, api);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
