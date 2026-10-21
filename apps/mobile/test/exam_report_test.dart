/// The Examination Performance report (the founder's reference
/// screenshots) renders for both paper shapes: the composite JAMB mock
/// (subject ledger + /400 aggregate) and the single-subject paper
/// (percentage hero + topic breakdown). The black action row, the
/// timing cards and the history helpers are covered too.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';
import 'package:renance/ui/exam_report_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const ExamResult _jambResult = ExamResult(
  score: 69,
  total: 180,
  breakdown: <TopicRow>[
    TopicRow(topic: 'Comprehension', correct: 11, total: 20),
  ],
  subjects: <UtmeSubjectRow>[
    UtmeSubjectRow(
        subject: 'english', attempted: 60, total: 60, correct: 30,
        score: 50, timeMs: 2400000),
    UtmeSubjectRow(
        subject: 'physics', attempted: 40, total: 40, correct: 14,
        score: 35, timeMs: 1800000),
    UtmeSubjectRow(
        subject: 'biology', attempted: 40, total: 40, correct: 15,
        score: 56, timeMs: 1500000),
    UtmeSubjectRow(
        subject: 'chemistry', attempted: 40, total: 40, correct: 10,
        score: 30, timeMs: 1200000),
  ],
);

const ExamResult _paperResult = ExamResult(
  score: 22,
  total: 50,
  breakdown: <TopicRow>[
    TopicRow(topic: 'Heredity', correct: 8, total: 10),
    TopicRow(topic: 'Ecology', correct: 6, total: 12),
  ],
);

void main() {
  testWidgets('JAMB mock report: aggregate, passed line, breakdown',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(const ExamReportView(
      result: _jambResult,
      title: 'UTME Mock',
      code: 'jamb-mock-english-physics-biology',
      body: 'JAMB',
      startedAt: null,
      durationMs: 6240000, // 1h 44m
      attemptId: 'att-1',
      xpEarned: 690,
      streak: 3,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Examination Performance'), findsOneWidget);
    expect(find.text('Your JAMB score'), findsOneWidget);
    expect(find.text('171'), findsOneWidget); // 50 + 35 + 56 + 30 aggregate
    expect(find.text('You passed 69 of 180 questions'), findsOneWidget);
    expect(find.text('38'), findsOneWidget); // 38%
    expect(find.text('You spent'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // 1 Hour
    expect(find.text('44'), findsOneWidget); // 44 Min
    expect(find.text('Score breakdown'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('60 of 60 Attempted'), findsOneWidget);
    expect(find.text('View Corrections'), findsOneWidget);
    expect(find.text('Send to Online Ranking'), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);
  });

  testWidgets('other exam report: percentage hero + topic rows',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap(const ExamReportView(
      result: _paperResult,
      title: 'Biology Bank',
      code: 'jamb-biology-bank',
      body: 'JAMB',
      durationMs: 3540000, // 59m
      attemptId: 'att-2',
    )));
    await tester.pumpAndSettle();

    expect(find.text('You passed 22 of 50 questions'), findsOneWidget);
    expect(find.text('44'), findsOneWidget); // 44%
    expect(find.text('0'), findsOneWidget); // 0 Hour
    expect(find.text('59'), findsOneWidget); // 59 Min
    expect(find.text('Heredity'), findsOneWidget);
    expect(find.text('8 of 10 Attempted'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget); // trailing pct
    // No JAMB ledger on a plain paper.
    expect(find.text('Your JAMB score'), findsNothing);
    expect(find.text('English'), findsNothing);
  });

  test('subject + type helpers', () {
    expect(
        subjectsFromCode('jamb-mock-english-physics-biology~n=100'),
        const <String>['English', 'Physics', 'Biology']);
    expect(subjectsFromCode('jamb-biology-bank'), const <String>[]);
    expect(examTypeOf('jamb-mock-english'), 'JAMB');
    expect(examTypeOf('waec-custom-math'), 'WAEC');
    expect(examTypeOf('daily-jamb'), 'Challenge');
    expect(examTypeOf('university-ams101'), 'CBT');
    expect(humanizeSubject('english'), 'English');
  });
}
