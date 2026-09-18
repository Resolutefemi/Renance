/// Canonical composed-paper codes — the Dart mirror of the server's
/// papercode.go grammar (apps/study-api/internal/cbtdata/papercode.go)
/// and the web's exams.ts builders. Every composed paper is a pure
/// function of its CODE, so the code the app builds IS the paper the
/// server composes, grades and reviews.
///
/// Families:
///   `jamb-mock-english-<sorted electives>[~params]`   official UTME mock
///   `<body>-custom-<sorted subjects>[~params]`        custom practice,
///                                                     body jamb|waec|neco
///   `jamb-pick-<base>[~params]`                       practice subset
///                                                     carved from a pack
///
/// params are dot-joined key=value pairs in canonical order
/// y,from,n,enN,comp,compN,nov,t — the server REFUSES non-canonical
/// codes, so every surface builds them through the builders below.
library;

import 'models.dart';

/// The subjects a UTME candidate can pick beyond the mandatory Use of
/// English — mirrors the web's UTME_ELECTIVES, one entry per JAMB bank.
const List<(String, String)> kUtmeElectives = <(String, String)>[
  ('mathematics', 'Mathematics'),
  ('physics', 'Physics'),
  ('chemistry', 'Chemistry'),
  ('biology', 'Biology'),
  ('economics', 'Economics'),
  ('government', 'Government'),
  ('geography', 'Geography'),
  ('literature', 'Literature in English'),
  ('crs', 'Christian Religious Studies'),
  ('irs', 'Islamic Religious Studies'),
  ('agricultural-science', 'Agricultural Science'),
  ('commerce', 'Commerce'),
  ('accounting', 'Principles of Accounts'),
  ('computer-studies', 'Computer Studies'),
  ('civic-education', 'Civic Education'),
  ('history', 'History'),
  ('french', 'French'),
  ('arabic', 'Arabic'),
  ('hausa', 'Hausa'),
  ('igbo', 'Igbo'),
  ('yoruba', 'Yoruba'),
  ('music', 'Music'),
  ('fine-arts', 'Fine Arts'),
  ('home-economics', 'Home Economics'),
  ('physical-education', 'Physical Education'),
];

/// Subject display name for a bank slug ("english" -> "Use of English").
String subjectName(String slug) {
  if (slug == 'english') return 'Use of English';
  for (final (String s, String name) in kUtmeElectives) {
    if (s == slug) return name;
  }
  return slug
      .split('-')
      .map((String w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Comma title fragment for a subject list ("English, Biology, Physics").
String subjectsLabel(Iterable<String> slugs) => slugs.map(subjectName).join(', ');

// ------------------------------------------------------------------ years

/// Encodes per-subject years the way the server's paramsString does:
/// null entries are random ("r"), all-random omits the param entirely and
/// one shared year collapses to a single value.
String? _yearsParam(List<int?>? years) {
  if (years == null || years.isEmpty) return null;
  if (years.every((int? y) => y == null)) return null;
  final bool allSame = years.first != null && years.every((int? y) => y == years.first);
  if (allSame) return '${years.first}';
  return years.map((int? y) => y == null ? 'r' : '$y').join(';');
}

String _joinParams(List<String> parts) => parts.isEmpty ? '' : '~${parts.join('.')}';

// ------------------------------------------------------------------ mock

/// Canonical official-UTME mock code: Use of English first (mandatory),
/// electives deduped and sorted, at least one elective required.
///
/// [years] aligns with the full subject list — English at index 0, the
/// sorted electives after (null = random), exactly the web's convention.
/// [englishSize], [comprehensionCount] and [timer] only emit when they
/// differ from the server defaults (60 / 10 / 120) — a redundant param
/// breaks the byte-for-byte canonical check.
String buildMockCode(
  List<String> electives, {
  List<int?>? years,
  int? englishSize,
  bool? comprehension,
  int? comprehensionCount,
  bool novel = false,
  int? timer,
}) {
  final List<String> rest = electives.toSet().toList()..sort();
  assert(rest.isNotEmpty, 'a mock needs at least one elective beside English');
  final List<String> parts = <String>[];
  final String? y = _yearsParam(years);
  if (y != null) parts.add('y=$y');
  if (englishSize != null && englishSize != 60) parts.add('enN=$englishSize');
  if (comprehension == false) {
    parts.add('comp=0');
  } else if (comprehensionCount != null && comprehensionCount != 10) {
    parts.add('compN=$comprehensionCount');
  }
  if (novel) parts.add('nov=1');
  if (timer != null && timer > 0 && timer != 120) parts.add('t=$timer');
  return 'jamb-mock-english-${rest.join('-')}${_joinParams(parts)}';
}

// ------------------------------------------------------------------ custom

/// Canonical custom-practice code: subjects deduped and fully sorted
/// (>= 1), question total spread across them. The [body] pins whose banks
/// the server composes from; WAEC/NECO papers carry y/n/t only — the
/// English comprehension/novel controls are JAMB-section features the
/// server refuses elsewhere.
String buildCustomCode(
  List<String> subjects, {
  String body = 'jamb',
  int? count,
  int? year,
  int? timer,
}) {
  final List<String> sorted = subjects.toSet().toList()..sort();
  assert(sorted.isNotEmpty, 'a custom paper needs at least one subject');
  final List<String> parts = <String>[];
  if (year != null && year > 0) parts.add('y=$year');
  if (count != null && count > 0) parts.add('n=${count > 500 ? 500 : count}');
  if (timer != null && timer > 0) parts.add('t=$timer');
  final String prefix = switch (body) {
    'waec' => 'waec-custom-',
    'neco' => 'neco-custom-',
    _ => 'jamb-custom-',
  };
  return '$prefix${sorted.join('-')}${_joinParams(parts)}';
}

// ------------------------------------------------------------------ pick

/// Canonical practice-subset code: carves [count] questions out of one
/// static manifest pack (optionally pinned to one [year], optionally a
/// contiguous [from] slice — the university Part pages serve Q1-50,
/// Q51-100, … in original order).
String buildPickCode(
  String base, {
  int? count,
  int? year,
  int? from,
  int? timer,
}) {
  final List<String> parts = <String>[];
  if (year != null && year > 0) parts.add('y=$year');
  if (from != null && from > 0) parts.add('from=${from > 100000 ? 100000 : from}');
  if (count != null && count > 0) parts.add('n=${count > 500 ? 500 : count}');
  if (timer != null && timer > 0) parts.add('t=$timer');
  return 'jamb-pick-$base${_joinParams(parts)}';
}

/// The static pack a pick code carves from ("jamb-pick-x~n=40" -> "x").
String pickBaseOf(String code) {
  String c = code.startsWith('jamb-pick-') ? code.substring('jamb-pick-'.length) : code;
  final int tilde = c.indexOf('~');
  if (tilde >= 0) c = c.substring(0, tilde);
  return c;
}

/// Reports whether [code] names a custom-practice paper (any body).
bool isCustomPaperCode(String code) {
  for (final String p in const <String>[
    'jamb-custom-',
    'waec-custom-',
    'neco-custom-',
  ]) {
    if (code.startsWith(p) && code.length > p.length) return true;
  }
  return false;
}

/// Reports whether [code] names any server-composed paper (never in the
/// manifest; resolves by code alone through /bundles/<code>).
bool isComposedPaperCode(String code) =>
    (code.startsWith('jamb-mock-') && code.length > 'jamb-mock-'.length) ||
    isCustomPaperCode(code) ||
    (code.startsWith('jamb-pick-') && code.length > 'jamb-pick-'.length);

// ------------------------------------------------------------------ meta

/// Builds the display [ExamMeta] a composed run opens with. The real
/// counts arrive with the composed bundle from the server; these carry
/// the canonical estimates (60 English + 40 per elective for the mock,
/// the chosen total for custom/pick) so intro cards show honest numbers.
ExamMeta composedExamMeta({
  required String code,
  required String title,
  required String body,
  required int questionCount,
  int? durationMinutes,
}) {
  return ExamMeta(
    code: code,
    title: title,
    questionCount: questionCount,
    totalMarks: questionCount,
    durationMinutes: durationMinutes,
    category: 'secondary',
    body: body,
    bundleSha256: '', // composed papers cache by code alone
    sizeBytes: 0, // fetched over the air on first run
  );
}

/// Display meta for a standard UTME mock (60 English + 40 per elective).
ExamMeta mockExamMeta(String code, List<String> electives, {int? timerMinutes}) {
  return composedExamMeta(
    code: code,
    // Quiz name only — the in-player subject strip carries the subjects.
    title: 'UTME Mock',
    body: 'JAMB',
    questionCount: 60 + 40 * electives.length,
    durationMinutes: timerMinutes ?? 120,
  );
}

/// Display meta for a custom practice paper (any body).
ExamMeta customExamMeta(String code, String body, List<String> subjects,
    {required int count, int? timerMinutes}) {
  final String label = switch (body) {
    'waec' => 'WASSCE Practice',
    'neco' => 'NECO Practice',
    _ => 'Custom Practice',
  };
  return composedExamMeta(
    code: code,
    // Quiz name only — the in-player subject strip carries the subjects.
    title: label,
    body: switch (body) {
      'waec' => 'WAEC',
      'neco' => 'NECO',
      _ => 'JAMB',
    },
    questionCount: count,
    durationMinutes: timerMinutes,
  );
}

/// Display meta for a practice subset carved from a manifest pack.
ExamMeta pickExamMeta(String code, ExamMeta base, {required int count}) {
  return composedExamMeta(
    code: code,
    title: '${base.title} · Practice $count',
    body: base.body,
    questionCount: count,
    durationMinutes: base.durationMinutes,
  );
}
