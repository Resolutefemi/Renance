/// The university catalog's pure data layer: the school map, the
/// UniCourse model and the manifest parsers. Lives OUT of the UI layer
/// so non-UI code (the exam-title builder in papers.dart) can resolve
/// "uni-<school>-<course>-bank" codes without touching widgets.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// slug -> (short name, full name) for every school whose banks ship.
const Map<String, (String, String)> kUniversitySchools = <String, (String, String)>{
  'aau': ('AAU', 'Ambrose Alli University, Ekpoma'),
  'aaua': ('AAUA', 'Adekunle Ajasin University, Akungba-Akoko'),
  'abu': ('ABU', 'Ahmadu Bello University'),
  'abuad': ('ABUAD', 'Afe Babalola University'),
  'achievers': ('ACHIEVERS', 'Achievers University'),
  'babcock': ('BABCOCK', 'Babcock University'),
  'bowen': ('BOWEN', 'Bowen University'),
  'bouesti': ('BOUESTI', 'Bamidele Olumilua University of Education, Science and Technology, Ikere-Ekiti'),
  'bsu': ('BSU', 'Benue State University'),
  'caleb': ('CALEB', 'Caleb University'),
  'covenant': ('COVENANT', 'Covenant University'),
  'delsu': ('DELSU', 'Delta State University, Abraka'),
  'eksu': ('EKSU', 'Ekiti State University'),
  'elizade': ('ELIZADE', 'Elizade University'),
  'esut': ('ESUT', 'Enugu State University of Science and Technology'),
  'futa': ('FUTA', 'Federal University of Technology, Akure'),
  'futo': ('FUTO', 'Federal University of Technology, Owerri'),
  'greenfield': ('GREENFIELD', 'Greenfield University'),
  'igbinedion': ('IGBINEDION', 'Igbinedion University'),
  'jabu': ('JABU', 'Joseph Ayo Babalola University'),
  'ksu': ('KSU', 'Prince Abubakar Audu University, Anyigba'),
  'lasu': ('LASU', 'Lagos State University'),
  'lautech': ('LAUTECH', 'Ladoke Akintola University of Technology'),
  'leadcity': ('LEADCITY', 'Lead City University'),
  'mountain-top': ('MOUNTAIN', 'Mountain University'),
  'noun': ('NOUN', 'National Open University of Nigeria'),
  'oau': ('OAU', 'Obafemi Awolowo University'),
  // "Other Schools" (founder directive 2026-10-04): the merged
  // general-course desk for students whose school is not on the list.
  // Its banks (uni-others-<course>-bank) gather every school's
  // questions for that course into one generic course (BIO 101).
  'others': ('OTHERS', 'Other Schools - merged general courses'),
  'rsu': ('RSU', 'Rivers State University'),
  'tasued': ('TASUED', 'Tai Solarin University of Education'),
  'ui': ('UI', 'University of Ibadan'),
  'uniben': ('UNIBEN', 'University of Benin'),
  // University of Calabar (founder directive 2026-10-11): the new
  // school desk - GST/CHM/Law/STA/BIO/HIS/CSS course banks.
  'unical': ('UNICAL', 'University of Calabar'),
  'unilag': ('UNILAG', 'University of Lagos'),
  'unilorin': ('UNILORIN', 'University of Ilorin'),
  'uniosun': ('UNIOSUN', 'Osun State University'),
  'uniport': ('UNIPORT', 'University of Port Harcourt'),
  'uniabuja': ('UNIABUJA', 'University of Abuja'),
  'unn': ('UNN', 'University of Nigeria, Nsukka'),
  'veritas': ('VERITAS', 'Veritas University'),
};

/// SharedPreferences key of the School Desk school pick (the same key the
/// website uses, so the two surfaces read one choice). The pick is made
/// ONCE from the desk's Pick School button; afterwards only the profile
/// edit can change it (founder rule).
const String kSchoolPickKey = 'renance.uni.school.v1';

/// SharedPreferences key of the Post UTME desk's school pick.
const String kPostUtmeSchoolPickKey = 'renance.postutme.school.v1';

/// One banked course: the manifest pack plus the parsed display bits.
class UniCourse {
  const UniCourse({required this.exam, required this.school, required this.slug});

  final ExamMeta exam;
  final String school;
  final String slug;

  bool get isPostUtme => slug.startsWith('pq-');

  /// "cos101" -> "COS 101"; "pq-accounting" -> "Accounting".
  String get label {
    if (isPostUtme) {
      final String tail = slug.substring(3);
      return tail
          .split('-')
          .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    // Course codes read with the space (founder naming, 2026-10-04):
    // BIO101 -> BIO 101. Wordy slugs stay uppercased as-is.
    final RegExp coded = RegExp(r'^([a-z]{2,})(\d+[a-z]?)$');
    final RegExpMatch? m = coded.firstMatch(slug);
    if (m != null) {
      return '${m.group(1)!.toUpperCase()} ${m.group(2)!.toUpperCase()}';
    }
    return slug.toUpperCase();
  }
}

/// Parses the manifest's University Modules shelf into per-school course
/// lists ("uni-futa-cos101-bank" -> school "futa", course "cos101").
Map<String, List<UniCourse>> universityCourses(List<ExamMeta> exams) {
  final Map<String, List<UniCourse>> schools = <String, List<UniCourse>>{};
  for (final ExamMeta e in exams) {
    if (!e.code.startsWith('uni-') || !e.code.endsWith('-bank')) continue;
    final String tail = e.code.substring(4, e.code.length - 5);
    final int dash = tail.indexOf('-');
    if (dash <= 0) continue;
    final String school = tail.substring(0, dash);
    final String course = tail.substring(dash + 1);
    if (course.isEmpty) continue;
    (schools[school] ??= <UniCourse>[]).add(
      UniCourse(exam: e, school: school, slug: course),
    );
  }
  for (final List<UniCourse> list in schools.values) {
    list.sort((UniCourse a, UniCourse b) => a.slug.compareTo(b.slug));
  }
  return schools;
}

/// The Post UTME shelf: `uni-<school>-pq-<subject>-bank` packs grouped by
/// school. The Post UTME desk's own entity, separate from the School Desk
/// course banks (founder rule: Post UTME sits beside JAMB/WAEC/NECO).
Map<String, List<UniCourse>> postUtmeCourses(List<ExamMeta> exams) {
  final Map<String, List<UniCourse>> schools = <String, List<UniCourse>>{};
  for (final ExamMeta e in exams) {
    final RegExpMatch? m =
        RegExp(r'^uni-([a-z0-9-]+)-pq-(.+)-bank$').firstMatch(e.code);
    if (m == null) continue;
    (schools[m.group(1)!] ??= <UniCourse>[]).add(
      UniCourse(exam: e, school: m.group(1)!, slug: 'pq-${m.group(2)}'),
    );
  }
  for (final List<UniCourse> list in schools.values) {
    list.sort((UniCourse a, UniCourse b) => a.slug.compareTo(b.slug));
  }
  return schools;
}

/// The stored School Desk pick, when it is still a banked school.
String? storedSchoolPick(Set<String> bankedSlugs, SharedPreferences prefs) {
  final String? slug = prefs.getString(kSchoolPickKey);
  if (slug != null && bankedSlugs.contains(slug)) return slug;
  return null;
}

/// Display name for a school slug - the short acronym when the slug is
/// banked ("futa" -> "FUTA"), a humanized fallback otherwise.
String universitySchoolLabel(String slug) {
  final (String, String)? hit = kUniversitySchools[slug];
  if (hit != null) return hit.$1;
  return slug
      .split('-')
      .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
