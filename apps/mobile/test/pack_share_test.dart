import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:renance/models.dart';
import 'package:renance/pack_share.dart';

Bundle _bundle() => const Bundle(
  code: 'jamb-biology-mock',
  title: 'JAMB Biology — Practice Mock',
  version: 1,
  questionCount: 2,
  totalMarks: 2,
  category: 'secondary',
  body: 'JAMB',
  questions: <BundleQuestion>[
    BundleQuestion(
      id: 'q1',
      type: 'mcq',
      stem: 'Which organelle releases energy?',
      marks: 1,
      options: <String, String>{'A': 'Mitochondrion', 'B': 'Nucleus'},
      topic: 'Cell Biology',
    ),
    BundleQuestion(
      id: 'q2',
      type: 'mcq',
      stem: 'Photosynthesis happens mainly in the…',
      marks: 1,
      options: <String, String>{'A': 'Root', 'B': 'Leaf', 'C': 'Stem'},
      topic: 'Photosynthesis',
    ),
  ],
);

void main() {
  group('encodeSharedPack / decodeSharedPack', () {
    test('roundtrip preserves the pack', () {
      final Bundle original = _bundle();
      final Bundle decoded = decodeSharedPack(encodeSharedPack(original));
      expect(decoded.code, original.code);
      expect(decoded.title, original.title);
      expect(decoded.questionCount, original.questionCount);
      expect(decoded.totalMarks, original.totalMarks);
      expect(decoded.body, original.body);
      expect(decoded.questions.length, 2);
      expect(decoded.questions[0].id, 'q1');
      expect(decoded.questions[0].options['A'], 'Mitochondrion');
      expect(decoded.questions[1].topic, 'Photosynthesis');
    });

    test('packSha is stable, 64 hex chars, matches the digest of the encoding', () {
      final Bundle b = _bundle();
      final String sha = packSha(b);
      expect(sha.length, 64);
      expect(sha, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(packSha(_bundle()), sha, reason: 'same pack, same digest');
      final String reencoded = jsonEncode(
        decodeSharedPack(encodeSharedPack(b)).toJson(),
      );
      expect(packSha(decodeSharedPack(reencoded)), sha,
          reason: 'a shared file re-imported keeps its digest');
    });

    test('rejects non-JSON and non-objects with user-safe copy', () {
      expect(
        () => decodeSharedPack('not json at all'),
        throwsA(
          isA<PackShareException>().having(
            (PackShareException e) => e.message,
            'message',
            'That file is not valid JSON.',
          ),
        ),
      );
      expect(
        () => decodeSharedPack(jsonEncode(<String>['a', 'b'])),
        throwsA(
          isA<PackShareException>().having(
            (PackShareException e) => e.message,
            'message',
            'That file is not a Renance pack.',
          ),
        ),
      );
    });

    test('rejects a pack whose declared counts disagree with its body', () {
      final Map<String, dynamic> j = _bundle().toJson();
      j['questionCount'] = 5;
      expect(
        () => decodeSharedPack(jsonEncode(j)),
        throwsA(
          isA<PackShareException>().having(
            (PackShareException e) => e.message,
            'message',
            'The pack declares 5 questions but carries 2.',
          ),
        ),
      );

      final Map<String, dynamic> m = _bundle().toJson();
      m['totalMarks'] = 9;
      expect(
        () => decodeSharedPack(jsonEncode(m)),
        throwsA(isA<PackShareException>()),
      );
    });

    test('rejects duplicate ids, empty stems and thin MCQs', () {
      final Map<String, dynamic> dup = _bundle().toJson();
      (dup['questions']! as List<dynamic>)[1] =
          ((dup['questions']! as List<dynamic>)[1]
                  as Map<String, dynamic>)
              .cast<String, dynamic>()
            ..['id'] = 'q1';
      expect(() => decodeSharedPack(jsonEncode(dup)),
          throwsA(isA<PackShareException>()));

      final Map<String, dynamic> stem = _bundle().toJson();
      ((stem['questions']! as List<dynamic>).first
              as Map<String, dynamic>)['stem'] = '   ';
      expect(() => decodeSharedPack(jsonEncode(stem)),
          throwsA(isA<PackShareException>()));

      final Map<String, dynamic> thin = _bundle().toJson();
      ((thin['questions']! as List<dynamic>).first
              as Map<String, dynamic>)['options'] = <String, String>{};
      expect(() => decodeSharedPack(jsonEncode(thin)),
          throwsA(isA<PackShareException>()));
    });

    test('sharedPackFileName is predictable and picker-friendly', () {
      expect(sharedPackFileName(_bundle()), 'jamb-biology-mock.renance-pack.json');
    });
  });
}
