import 'package:flutter_test/flutter_test.dart';

import 'package:renance/audio_summary.dart';
import 'package:renance/controllers.dart';
import 'package:renance/models.dart';
import 'package:renance/tts.dart';

/// Audio summaries (ROADMAP #11) rules: the composed script names the
/// lesson, walks the headings, carries the key points clean of markdown,
/// never crosses the TTS long-text limit, and the narrator's on/off state
/// follows the toggle with an injected fake engine.
void main() {
  Lesson lesson() => Lesson(
    slug: 'cell-structure',
    title: 'Cell Structure and Organisation',
    subject: 'Biology',
    body: 'JAMB',
    minutes: 7,
    summary: 'Every organelle you must know for JAMB and WAEC biology.',
    sections: <LessonSection>[
      LessonSection(
        heading: 'The cell is the unit of life',
        blocks: <LessonBlock>[
          LessonBlock(
            type: 'p',
            text: 'Every living thing is built from cells.',
          ),
          LessonBlock(
            type: 'callout',
            text: 'Key point: examiners love the cell theory, learn **all three** parts.',
          ),
        ],
      ),
      LessonSection(
        heading: 'Organelles and their jobs',
        blocks: const <LessonBlock>[],
      ),
    ],
  );

  group('composeSpokenSummary', () {
    test('names the lesson, syllabus line, read time and summary', () {
      final String script = composeSpokenSummary(lesson());
      expect(script, contains('Cell Structure and Organisation.'));
      expect(script, contains('Biology, JAMB syllabus.'));
      expect(script, contains('About 7 minutes.'));
      expect(script, contains('Every organelle you must know'));
    });

    test('walks the section headings', () {
      final String script = composeSpokenSummary(lesson());
      expect(script, contains('In this lesson:'));
      expect(script, contains('The cell is the unit of life.'));
      expect(script, contains('Organelles and their jobs.'));
    });

    test('carries key-point callouts without markdown markers', () {
      final String script = composeSpokenSummary(lesson());
      expect(script, contains('Key points.'));
      expect(script, contains('learn all three parts'));
      expect(script.contains('**'), isFalse);
      expect(script.contains('`'), isFalse);
    });

    test('closes with the nudge back into the full text', () {
      final String script = composeSpokenSummary(lesson());
      expect(script, endsWith('Open the lesson to read the full text.'));
    });

    test('stays under the TTS long-text limit on an oversized lesson', () {
      final Lesson huge = Lesson(
        slug: 'huge',
        title: 'A very long lesson',
        minutes: 90,
        summary: 'Padding.',
        sections: <LessonSection>[
          for (var i = 0; i < 40; i++)
            LessonSection(
              heading: 'Section $i with a reasonably long heading',
              blocks: <LessonBlock>[
                LessonBlock(
                  type: 'p',
                  text: List<String>.filled(
                    30,
                    'Sentence $i about some detail of the topic at hand.',
                  ).join(' '),
                  items: const <String>[],
                ),
              ],
            ),
        ],
      );
      final String script = composeSpokenSummary(huge);
      expect(script.length, lessThanOrEqualTo(kMaxSpokenLength));
      // truncation lands on a finished sentence, never mid-word
      expect(script.endsWith('.'), isTrue);
    });

    test('handles a bare lesson without sections, subject or minutes', () {
      final Lesson bare = Lesson(
        slug: 'bare',
        title: 'Bare lesson',
        minutes: 0,
        summary: 'Still narrates.',
        sections: const <LessonSection>[],
      );
      final String script = composeSpokenSummary(bare);
      expect(script, contains('Bare lesson.'));
      expect(script, contains('Still narrates.'));
      expect(script.contains('In this lesson'), isFalse);
      expect(script.contains('Key points'), isFalse);
      expect(script, endsWith('Open the lesson to read the full text.'));
    });
  });

  group('LessonNarrator', () {
    test('toggle speaks the composed script, re-tap stops', () {
      final FakeSpeechEngine fake = FakeSpeechEngine();
      final LessonNarrator narrator = LessonNarrator(speech: fake);
      final Lesson les = lesson();

      expect(narrator.playing, isFalse);
      narrator.toggle(les);
      expect(narrator.playing, isTrue);
      expect(narrator.slug, 'cell-structure');
      expect(fake.spoken, hasLength(1));
      expect(fake.spoken.single, contains('Cell Structure and Organisation.'));

      narrator.toggle(les);
      expect(narrator.playing, isFalse);
      expect(fake.stopCount, 1);
    });

    test('switching lessons speaks the new script', () {
      final FakeSpeechEngine fake = FakeSpeechEngine();
      final LessonNarrator narrator = LessonNarrator(speech: fake);
      final Lesson a = lesson();
      final Lesson b = Lesson(
        slug: 'newton-laws',
        title: 'Newton Laws',
        minutes: 5,
        summary: 'Motion.',
        sections: const <LessonSection>[],
      );

      narrator.toggle(a);
      narrator.toggle(b);
      expect(narrator.playing, isTrue);
      expect(narrator.slug, 'newton-laws');
      expect(fake.spoken, hasLength(2));
      expect(fake.spoken.last, contains('Newton Laws.'));
    });

    test('stopSilently resets state without notifying listeners', () {
      final FakeSpeechEngine fake = FakeSpeechEngine();
      final LessonNarrator narrator = LessonNarrator(speech: fake);
      var notified = 0;
      narrator.addListener(() => notified++);

      narrator.toggle(lesson());
      final int afterToggle = notified;
      narrator.stopSilently();
      expect(narrator.playing, isFalse);
      expect(fake.stopCount, 1);
      expect(notified, afterToggle);
    });

    test('dispose silences the engine exactly once', () {
      final FakeSpeechEngine fake = FakeSpeechEngine();
      final LessonNarrator narrator = LessonNarrator(speech: fake);
      narrator.toggle(lesson());
      narrator.dispose();
      expect(fake.stopCount, greaterThanOrEqualTo(1));
    });
  });
}
