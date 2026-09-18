/// Canonical composed-paper code conformance — the same vectors the Go
/// papercode_test and the web canonical test carry. The server refuses
/// non-canonical codes byte-for-byte, so these builders must reproduce
/// the exact strings the server would encode.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';
import 'package:renance/papers.dart';

void main() {
  group('buildMockCode', () {
    test('English first, electives sorted and deduped', () {
      expect(
        buildMockCode(<String>['biology', 'mathematics']),
        'jamb-mock-english-biology-mathematics',
      );
      expect(
        buildMockCode(<String>['mathematics', 'biology', 'mathematics']),
        'jamb-mock-english-biology-mathematics',
      );
    });

    test('one shared year collapses to a single param', () {
      expect(
        buildMockCode(
          <String>['mathematics', 'biology'],
          years: const <int?>[2022, 2022, 2022],
        ),
        'jamb-mock-english-biology-mathematics~y=2022',
      );
    });

    test('mixed years encode per-subject with r tokens, aligned to the '
        'full subject list (English first)', () {
      expect(
        buildMockCode(
          <String>['mathematics', 'biology'],
          years: const <int?>[2023, 2022, null],
        ),
        'jamb-mock-english-biology-mathematics~y=2023;2022;r',
      );
    });

    test('all-random years omit the param entirely', () {
      expect(
        buildMockCode(
          <String>['mathematics'],
          years: const <int?>[null, null],
        ),
        'jamb-mock-english-mathematics',
      );
    });

    test('server defaults are omitted, non-defaults emitted in order', () {
      // 120 timer and the default English/comprehension sizing are the
      // server's defaults — none of them may appear.
      expect(
        buildMockCode(<String>['physics'], timer: 120),
        'jamb-mock-english-physics',
      );
      // novel opts in; comprehension off is stated explicitly; a 60
      // minute timer is non-default.
      expect(
        buildMockCode(
          <String>['physics'],
          comprehension: false,
          novel: true,
          timer: 60,
        ),
        'jamb-mock-english-physics~comp=0.nov=1.t=60',
      );
      expect(
        buildMockCode(<String>['physics'], comprehensionCount: 20),
        'jamb-mock-english-physics~compN=20',
      );
    });
  });

  group('buildCustomCode', () {
    test('subjects fully sorted, count before timer', () {
      expect(
        buildCustomCode(
          <String>['physics', 'biology'],
          count: 40,
          timer: 30,
        ),
        'jamb-custom-biology-physics~n=40.t=30',
      );
    });

    test('year precedes count (canonical y,n,t order)', () {
      expect(
        buildCustomCode(
          <String>['physics'],
          count: 40,
          year: 2023,
          timer: 30,
        ),
        'jamb-custom-physics~y=2023.n=40.t=30',
      );
    });

    test('body prefixes pin the composing shelves', () {
      expect(
        buildCustomCode(<String>['biology'], body: 'waec', count: 40),
        'waec-custom-biology~n=40',
      );
      expect(
        buildCustomCode(<String>['biology'], body: 'neco', count: 25),
        'neco-custom-biology~n=25',
      );
    });
  });

  group('buildPickCode', () {
    test('year-pin and subset in canonical y,from,n,t order', () {
      expect(
        buildPickCode('jamb-accounting-bank', count: 40, year: 2022),
        'jamb-pick-jamb-accounting-bank~y=2022.n=40',
      );
    });

    test('contiguous Part slice (from before n)', () {
      expect(
        buildPickCode('uni-futa-cos101-bank', count: 50, from: 51),
        'jamb-pick-uni-futa-cos101-bank~from=51.n=50',
      );
    });

    test('count alone', () {
      expect(
        buildPickCode('uni-aaua-gst111-bank', count: 25),
        'jamb-pick-uni-aaua-gst111-bank~n=25',
      );
    });

    test('pickBaseOf strips the family prefix and params', () {
      expect(
        pickBaseOf('jamb-pick-jamb-english-bank~n=40.t=15'),
        'jamb-english-bank',
      );
      expect(pickBaseOf('jamb-pick-jamb-english-bank'), 'jamb-english-bank');
    });
  });

  group('isComposedPaperCode', () {
    test('recognises every family and refuses static packs', () {
      expect(isComposedPaperCode('jamb-mock-english-biology'), isTrue);
      expect(isComposedPaperCode('jamb-custom-biology~n=40'), isTrue);
      expect(isComposedPaperCode('waec-custom-biology'), isTrue);
      expect(isComposedPaperCode('neco-custom-english~n=40.t=15'), isTrue);
      expect(isComposedPaperCode('jamb-pick-jamb-english-bank~n=40'), isTrue);
      expect(isComposedPaperCode('jamb-english-bank'), isFalse);
      expect(isComposedPaperCode('uni-futa-cos101-bank'), isFalse);
      expect(isComposedPaperCode('jamb-mock-'), isFalse);
    });
  });

  group('display metas', () {
    final ExamMeta base = ExamMeta(
      code: 'uni-futa-cos101-bank',
      title: 'FUTA COS101 | Computer Programming',
      questionCount: 190,
      totalMarks: 190,
      bundleSha256: 'abc123',
      body: 'University Modules',
      durationMinutes: 45,
    );

    test('mock meta carries the bare quiz name and the official 2-hour window',
        () {
      final ExamMeta meta = mockExamMeta(
        'jamb-mock-english-biology-physics',
        <String>['biology', 'physics'],
      );
      expect(meta.code, 'jamb-mock-english-biology-physics');
      // Quiz name only — the player's subject strip carries the subjects.
      expect(meta.title, 'UTME Mock');
      expect(meta.body, 'JAMB');
      expect(meta.durationMinutes, 120);
      // 60 English + 40 per elective.
      expect(meta.questionCount, 140);
      expect(meta.bundleSha256, '');
    });

    test('custom meta labels WAEC as WASSCE practice', () {
      final ExamMeta meta = customExamMeta(
        'waec-custom-biology~n=40',
        'waec',
        <String>['biology'],
        count: 40,
      );
      expect(meta.title, 'WASSCE Practice');
      expect(meta.body, 'WAEC');
      expect(meta.questionCount, 40);
      expect(meta.durationMinutes, isNull);
    });

    test('pick meta inherits the base pack identity', () {
      final ExamMeta meta = pickExamMeta(
        'jamb-pick-uni-futa-cos101-bank~from=51.n=50',
        base,
        count: 50,
      );
      expect(meta.title, '${base.title} · Practice 50');
      expect(meta.body, 'University Modules');
      expect(meta.durationMinutes, 45);
      expect(meta.bundleSha256, '');
    });
  });

  group('subject names', () {
    test('display names for every banked slug', () {
      expect(subjectName('english'), 'Use of English');
      expect(subjectName('mathematics'), 'Mathematics');
      expect(subjectName('agricultural-science'), 'Agricultural Science');
      expect(subjectName('accounting'), 'Principles of Accounts');
      expect(subjectName('crs'), 'Christian Religious Studies');
    });
  });
}
