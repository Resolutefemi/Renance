// Offline pack sharing (ROADMAP #16, the file slice).
//
// A downloaded pack is a sealed questions-only bundle, so it can travel
// between phones as a FILE over any offline pipe students already use
// (Bluetooth, Xender, ShareIT, Nearby). The OS share sheet is the
// transport; this module is the contract:
//
//   encodeSharedPack  pack -> shareable JSON text
//   decodeSharedPack  text -> pack, strictly validated or throws
//   packSha           the integrity key the receiving store keeps
//
// Pure Dart: no platform channels, fully unit-testable. The strictness
// mirrors the API's boot loader: a file that decodes but fails its own
// invariants (counts, marks, empty stems) is refused, never half-trusted.
// Answer keys cannot travel this way, the app never holds them.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';

/// A shared pack file failed validation. [message] is user-safe copy.
class PackShareException implements Exception {
  PackShareException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The canonical shareable text for a pack. The receiving phone stores
/// [packSha] of exactly this encoding alongside the pack.
String encodeSharedPack(Bundle bundle) => jsonEncode(bundle.toJson());

/// Parses and fully validates a shared pack file.
///
/// Rejects: non-JSON, non-objects, missing/empty identity fields, count
/// mismatches, mark mismatches, empty stems, MCQs with fewer than two
/// options, and duplicate question ids. Every rejection carries copy the
/// screen can show directly.
Bundle decodeSharedPack(String raw) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw PackShareException('That file is not valid JSON.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw PackShareException('That file is not a Renance pack.');
  }

  final Bundle bundle = Bundle.fromJson(decoded);

  if (bundle.code.trim().isEmpty) {
    throw PackShareException('The pack file has no exam code.');
  }
  if (bundle.title.trim().isEmpty) {
    throw PackShareException('The pack file has no title.');
  }
  if (bundle.questions.isEmpty) {
    throw PackShareException('The pack file ships no questions.');
  }
  if (bundle.questionCount != bundle.questions.length) {
    throw PackShareException(
      'The pack declares ${bundle.questionCount} questions but carries '
      '${bundle.questions.length}.',
    );
  }
  final int marks = bundle.questions.fold(0, (int s, BundleQuestion q) => s + q.marks);
  if (bundle.totalMarks != marks) {
    throw PackShareException(
      'The pack declares ${bundle.totalMarks} marks but its questions sum to $marks.',
    );
  }
  final Set<String> ids = <String>{};
  for (final BundleQuestion q in bundle.questions) {
    if (q.id.trim().isEmpty) {
      throw PackShareException('A question in the pack has no id.');
    }
    if (!ids.add(q.id)) {
      throw PackShareException('The pack repeats question id ${q.id}.');
    }
    if (q.stem.trim().isEmpty) {
      throw PackShareException('Question ${q.id} has no text.');
    }
    if (q.type == 'mcq' && q.options.length < 2) {
      throw PackShareException('Question ${q.id} has too few options.');
    }
  }
  return bundle;
}

/// The integrity key for a shared pack, the lowercase hex sha256 of the
/// canonical encoding (the same digest format the manifest uses).
String packSha(Bundle bundle) =>
    sha256.convert(utf8.encode(encodeSharedPack(bundle))).toString();

/// The file name the share sheet suggests. Ends in .json so every file
/// manager (and the picker on the receiving phone) recognises it.
String sharedPackFileName(Bundle bundle) =>
    '${bundle.code}.renance-pack.json';
