import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';
import 'package:renance/ui/study_plan_screen.dart';

void main() {
  group('deriveStudyPlanValues', () {
    test('signed out falls back to the exact Stitch mock', () {
      final StudyPlanValues v = deriveStudyPlanValues(signedIn: false);
      expect(v.practiceTitle, 'Biology Practice');
      expect(v.practiceMinutes, 15);
      expect(v.reviewMinutes, 12);
      expect(v.cardsMinutes, 15);
      expect(v.totalMinutes, 42);
      expect(
        v.insight,
        "You usually fade after ~25 min in the evening. We've placed "
        'your heaviest topics (Biology) first to maximize retention.',
      );
    });

    test('unknown slices while signed in keep the mock minutes', () {
      final StudyPlanValues v = deriveStudyPlanValues(signedIn: true);
      expect(v.reviewMinutes, 12);
      expect(v.cardsMinutes, 15);
      expect(v.totalMinutes, 42);
      expect(v.insight, startsWith('No sittings logged today yet'));
    });

    test('review minutes follow the 2 min per due topic rule', () {
      expect(
        deriveStudyPlanValues(signedIn: true, dueTopics: 6).reviewMinutes,
        12,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, dueTopics: 1).reviewMinutes,
        6,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, dueTopics: 30).reviewMinutes,
        40,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, dueTopics: 0).reviewMinutes,
        5,
      );
    });

    test('voice minutes follow the 45s per due card rule', () {
      expect(
        deriveStudyPlanValues(signedIn: true, cardsDue: 20).cardsMinutes,
        15,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, cardsDue: 1).cardsMinutes,
        5,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, cardsDue: 100).cardsMinutes,
        20,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, cardsDue: 0).cardsMinutes,
        5,
      );
    });

    test('weakest subject names the practice block and the insight', () {
      final StudyPlanValues v = deriveStudyPlanValues(
        signedIn: true,
        weakestSubject: 'Chemistry',
      );
      expect(v.practiceTitle, 'Chemistry Practice');
      expect(v.insight, contains('(Chemistry)'));
    });

    test('fatigue levels change the advice, minutes stay honest', () {
      final FatigueState high = FatigueState(
        level: 'high',
        suggestBreak: true,
        minutesToday: 64,
        minutesLast3h: 40,
        sessionsToday: 3,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, fatigue: high).insight,
        "You've studied 64 min today and your pace is dipping. Take five "
        'before the next block to maximize retention.',
      );

      final FatigueState mild = FatigueState(
        level: 'mild',
        suggestBreak: false,
        minutesToday: 52,
        minutesLast3h: 30,
        sessionsToday: 2,
      );
      expect(
        deriveStudyPlanValues(signedIn: true, fatigue: mild).insight,
        "You've studied 52 min today and your pace is easing. The heavier "
        'topics go first while your focus holds.',
      );

      final FatigueState none = FatigueState(
        level: 'none',
        suggestBreak: false,
        minutesToday: 18.4,
        minutesLast3h: 10,
        sessionsToday: 1,
      );
      final StudyPlanValues v =
          deriveStudyPlanValues(signedIn: true, fatigue: none);
      expect(v.insight, startsWith("You've studied 18 min today."));
      expect(v.insight, endsWith('to maximize retention.'));
    });
  });
}
