import type { Lesson } from '@/lib/site-data';

/**
 * Audio summaries (ROADMAP #11), on-device slice: a deterministic spoken
 * script composed from the lesson bundle itself — no provider, no network,
 * works offline. Mirrors apps/mobile/lib/audio_summary.dart 1:1 so both
 * clients narrate the same words for the same lesson.
 */

/** Long-text safety, mirrored from the app: browsers dislike multi-page
 * utterance blobs just as much as Android's TTS engine does. */
export const MAX_SPOKEN_LENGTH = 2400;

/** Strips the markdown the page renders visually (emphasis, code ticks)
 * so the speech engine never reads asterisks aloud. */
function plain(raw: string): string {
  return raw
    .replace(/\*\*/g, '')
    .replace(/`/g, '')
    .replace(/__/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Closes a spoken sentence with a full stop unless it already ends in
 * sentence punctuation. */
function dot(s: string): string {
  const t = s.trim();
  if (!t) return t;
  return /[.!?]$/.test(t) ? t : `${t}.`;
}

/** Caps the script, backing off to the last finished sentence (or the
 * last whitespace when a single sentence is oversized). */
function cap(script: string): string {
  if (script.length <= MAX_SPOKEN_LENGTH) return script;
  const head = script.slice(0, MAX_SPOKEN_LENGTH);
  const sentence = head.lastIndexOf('. ');
  if (sentence > MAX_SPOKEN_LENGTH / 2) return head.slice(0, sentence + 1);
  const space = head.lastIndexOf(' ');
  return space > 0 ? head.slice(0, space) : head;
}

/** Composes the spoken summary of a lesson: the title, a syllabus line,
 * the read time, the editor's summary, a walk through the section
 * headings, up to three key-point callouts, then a closing nudge. */
export function composeSpokenSummary(les: Lesson): string {
  const subject = les.subject ? plain(les.subject) : '';
  const body = les.body ? plain(les.body) : '';

  const sentences: string[] = [];
  if (les.title) sentences.push(dot(plain(les.title)));
  if (subject || body) {
    sentences.push(
      dot([subject, body ? `${body} syllabus` : ''].filter(Boolean).join(', ')),
    );
  }
  if (les.minutes > 0) sentences.push(`About ${les.minutes} minutes.`);
  if (les.summary) sentences.push(dot(plain(les.summary)));

  const headings = les.sections
    .map((s) => (s.heading?.trim() ? dot(plain(s.heading)) : ''))
    .filter(Boolean);
  if (headings.length) sentences.push(`In this lesson: ${headings.join(' ')}`);

  const keyPoints: string[] = [];
  for (const sec of les.sections) {
    for (const b of sec.blocks) {
      if (b.type === 'callout' && (b.text ?? '').trim()) {
        keyPoints.push(dot(plain(b.text ?? '')));
        if (keyPoints.length === 3) break;
      }
    }
    if (keyPoints.length === 3) break;
  }
  if (keyPoints.length) sentences.push(`Key points. ${keyPoints.join(' ')}`);

  sentences.push('That is the summary. Open the lesson to read the full text.');
  return cap(sentences.filter(Boolean).join(' '));
}
