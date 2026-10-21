import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';

/// Pure ports must stay in lockstep with the server's Go rules, these
/// are the same vectors the Go tests run (fatigue).
void main() {
  group('assessFatigue, the pure port of fatigue.Assess', () {
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

}
