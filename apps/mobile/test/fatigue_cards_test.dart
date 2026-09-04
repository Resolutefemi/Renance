import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';

/// Pure ports must stay in lockstep with the server's Go rules — these
/// are the same vectors the Go tests run (fatigue + Leitner).
void main() {
  group('assessFatigue — the pure port of fatigue.Assess', () {
    test('steady pace, short sitting: no signal', () {
      final s = assessFatigue(List<int>.filled(40, 12000), 25);
      expect(s.level, 'none');
      expect(s.suggestBreak, isFalse);
      expect(s.reasons, isEmpty);
    });

    test('drift alone (under 30 min) is mild', () {
      final lat = <int>[...List<int>.filled(5, 8000), ...List<int>.filled(5, 20000)];
      final s = assessFatigue(lat, 20);
      expect(s.level, 'mild');
      expect(s.suggestBreak, isTrue);
      expect(s.medianFirst5Ms, 8000);
      expect(s.medianLast5Ms, 20000);
    });

    test('heavy drift on a long sitting is high', () {
      final lat = <int>[...List<int>.filled(5, 5000), ...List<int>.filled(5, 25000)];
      expect(assessFatigue(lat, 42).level, 'high');
      // same drift, short dash: still mild
      expect(assessFatigue(lat, 10).level, 'mild');
    });

    test('length thresholds match the server', () {
      expect(assessFatigue(List<int>.filled(12, 9000), 49.9).level, 'none');
      expect(assessFatigue(List<int>.filled(12, 9000), 55).level, 'mild');
      expect(assessFatigue(List<int>.filled(12, 9000), 80).level, 'high');
    });

    test('median never mutates its input', () {
      final xs = <int>[9, 1, 5];
      medianOf(xs);
      expect(xs, <int>[9, 1, 5]);
    });
  });

  group('Leitner pure rules — the port of store.NextCardBox', () {
    test('again resets, hard holds, good climbs and caps', () {
      expect(nextCardBox(4, 'again'), 1);
      expect(nextCardBox(3, 'hard'), 3);
      expect(nextCardBox(3, 'good'), 4);
      expect(nextCardBox(5, 'good'), 5);
      expect(nextCardBox(1, 'hard'), 1);
    });

    test('intervals per box (0,1,2,4,7) with clamping', () {
      expect(cardIntervalDays(1), 0);
      expect(cardIntervalDays(2), 1);
      expect(cardIntervalDays(3), 2);
      expect(cardIntervalDays(4), 4);
      expect(cardIntervalDays(5), 7);
      expect(cardIntervalDays(0), 0);
      expect(cardIntervalDays(9), 7);
    });

    test('the walk a student experiences', () {
      var box = 1;
      for (final want in <int>[2, 3, 4, 5]) {
        box = nextCardBox(box, 'good');
        expect(box, want);
      }
      expect(cardIntervalDays(box), 7);
      box = nextCardBox(box, 'again');
      expect(box, 1);
    });

    test('CardProgress.isDue handles past and future dates', () {
      final now = DateTime.now().toUtc();
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 2));
      String day(DateTime d) => d.toIso8601String().substring(0, 10);
      final past = CardProgress(
          cardId: 'c1', deckCode: 'd', box: 2, correct: 1, wrong: 0,
          dueOn: day(yesterday));
      final future = CardProgress(
          cardId: 'c2', deckCode: 'd', box: 2, correct: 1, wrong: 0,
          dueOn: day(tomorrow));
      expect(past.isDue, isTrue);
      expect(future.isDue, isFalse);
    });
  });
}
