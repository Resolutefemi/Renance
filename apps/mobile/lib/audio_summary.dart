/// Audio summaries (ROADMAP #11), the on-device TTS slice: a deterministic
/// spoken script composed from the lesson bundle itself. No provider, no
/// network, works offline against the cached copy — the same rule as the
/// voice flashcards engine: voice is an enhancement, never a requirement.
///
/// The composer is pure Dart so it is unit-testable and mirrored 1:1 by
/// apps/web/lib/audio-summary.ts, so both clients narrate the same words
/// for the same lesson.
library;

import 'models.dart';

/// Long-text safety: Android's TTS engine rejects speech requests past
/// ~4000 characters, and nobody wants an unbroken ten-minute blob. The
/// composed script stays well under that limit, truncating on the last
/// finished sentence so the narration never stops mid-thought.
const int kMaxSpokenLength = 2400;

/// Composes the spoken summary of [lesson]: the title, a syllabus line,
/// the read time, the editor's summary, a walk through the section
/// headings, up to three of the lesson's key-point callouts, then a
/// closing nudge back into the full text.
String composeSpokenSummary(Lesson lesson) {
  final List<String> sentences = <String>[
    if (lesson.title.isNotEmpty) _dot(_plain(lesson.title)),
    if (lesson.subject.isNotEmpty || lesson.body.isNotEmpty)
      _dot(
        <String>[
          if (lesson.subject.isNotEmpty) _plain(lesson.subject),
          if (lesson.body.isNotEmpty) '${_plain(lesson.body)} syllabus',
        ].join(', '),
      ),
    if (lesson.minutes > 0) 'About ${lesson.minutes} minutes.',
    if (lesson.summary.isNotEmpty) _dot(_plain(lesson.summary)),
  ];

  final List<String> headings = <String>[
    for (final LessonSection s in lesson.sections)
      if (s.heading.trim().isNotEmpty) _dot(_plain(s.heading)),
  ];
  if (headings.isNotEmpty) {
    sentences.add('In this lesson: ${headings.join(' ')}');
  }

  final List<String> keyPoints = <String>[];
  for (final LessonSection s in lesson.sections) {
    for (final LessonBlock b in s.blocks) {
      if (b.type == 'callout' && b.text.trim().isNotEmpty) {
        keyPoints.add(_dot(_plain(b.text)));
      }
      if (keyPoints.length == 3) break;
    }
    if (keyPoints.length == 3) break;
  }
  if (keyPoints.isNotEmpty) {
    sentences.add('Key points. ${keyPoints.join(' ')}');
  }

  sentences.add('That is the summary. Open the lesson to read the full text.');
  return _cap(sentences.where((String s) => s.isNotEmpty).join(' '));
}

/// Strips the markdown the reader renders visually (emphasis, code ticks)
/// and collapses whitespace, because a speech engine should never read
/// asterisks aloud.
String _plain(String raw) {
  final String t = raw
      .replaceAll('**', '')
      .replaceAll('`', '')
      .replaceAll('__', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t;
}

/// Closes a spoken sentence with a full stop unless it already ends in
/// sentence punctuation.
String _dot(String s) {
  final String t = s.trim();
  if (t.isEmpty) return t;
  final String last = t.substring(t.length - 1);
  return (last == '.' || last == '!' || last == '?') ? t : '$t.';
}

/// Caps the script at [kMaxSpokenLength], backing off to the last finished
/// sentence (or the last whitespace when a single sentence is oversized).
String _cap(String script) {
  if (script.length <= kMaxSpokenLength) return script;
  final String window = script.substring(0, kMaxSpokenLength);
  final int sentence = window.lastIndexOf('. ');
  if (sentence > kMaxSpokenLength ~/ 2) {
    return window.substring(0, sentence + 1);
  }
  final int space = window.lastIndexOf(' ');
  return space > 0 ? window.substring(0, space) : window;
}
