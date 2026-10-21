// The NERDC national scheme of work ships INSIDE the app
// (assets/nerdc_schemes.json, founder directive 2026-10-05): the
// syllabus tab must be able to show every class's scheme without any
// network. These tests pin the asset to the real corpus shape.
import 'package:flutter_test/flutter_test.dart';

import 'package:renance/nerdc_schemes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled scheme asset loads and covers Nursery 1 to SSS 3', () async {
    final NerdcSchemes schemes = await NerdcSchemes.load();
    expect(schemes.classes, hasLength(15));
    expect(schemes.classes.first.name, 'Nursery 1');
    expect(schemes.classes.last.name, 'SSS 3');
  });

  test('every class carries subjects with term schemes + weeks', () async {
    final NerdcSchemes schemes = await NerdcSchemes.load();
    for (final NerdcClass cls in schemes.classes) {
      expect(cls.subjects, isNotEmpty, reason: '${cls.name} has no subjects');
      for (final NerdcSubject subject in cls.subjects) {
        expect(subject.terms, isNotEmpty,
            reason: '${cls.name}/${subject.name} has no term schemes');
        for (final NerdcTermScheme term in subject.terms) {
          expect(term.weeks, isNotEmpty,
              reason: '${cls.name}/${subject.name} term ${term.term} empty');
          for (final NerdcWeek week in term.weeks) {
            expect(week.topic, isNotEmpty,
                reason: '${cls.name}/${subject.name} week ${week.week}');
          }
        }
      }
    }
  });

  test('slug matching lands a school class+subject on the corpus', () async {
    final NerdcSchemes schemes = await NerdcSchemes.load();
    final NerdcClass? jss1 = schemes.classForSchoolName('JSS 1');
    expect(jss1?.name, 'JSS 1');
    final NerdcSubject? maths =
        jss1 == null ? null : schemes.subjectForSchoolName(jss1, 'Mathematics');
    expect(maths, isNotNull);
    expect(maths!.term(1)!.weeks.first.week, 1);

    // Prefix tolerance: a streamed class name ("Primary 4A") still lands.
    expect(schemes.classForSchoolName('Primary 4A')?.name, 'Primary 4');
    // Unknown names answer null without throwing.
    expect(schemes.classForSchoolName('Golden Hall'), isNull);
  });
}
