import type { BundleQuestion, BuildReport, CbtBundle, CbtKey, KeyEntry, QuestionType } from './types';

/**
 * The adapter: ingests the 6 REAL bank shapes found across the founder's
 * repos and normalizes to bundle+key. Known variants (evidence-based):
 *
 *  1. bare array of questions                       (jamb biology.json)
 *  2. {course,title,total,questions[]}              (sen101_questions.json)
 *  3. option keys  a..d  |  A..D  (plain strings)   (both repos)
 *  4. options: [{letter,text,correct}]              (COS102_500.json)
 *  5. answer: "c" | answers: ["Science","science"]  (CVE105 = text question)
 *  6. correct_letter: "B" + section/chapter/topic   (COS102, GST112)
 *
 * Plus: UTF-8 BOM stripping (english.json was unparseable for this reason),
 * missing ids, duplicate ids, non-MCQ-with-options inconsistencies.
 */

const LETTERS = 'ABCDEFGH'.split('');

function stripBom(s: string): string {
  return s.charCodeAt(0) === 0xfeff ? s.slice(1) : s;
}

function toCode(filename: string): string {
  return filename
    .replace(/\.json$/i, '')
    .replace(/_questions$/i, '')
    .replace(/_(500|objectives)$/i, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'bank';
}

interface RawOpts {
  style: 'record' | 'array' | 'none';
  options: Record<string, string>;
}

function extractOptions(q: Record<string, unknown>): RawOpts {
  const rec = q.options ?? q.option;
  if (rec && typeof rec === 'object' && !Array.isArray(rec)) {
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(rec as Record<string, unknown>)) {
      if (typeof v === 'string' && v.trim()) out[k.toUpperCase()] = v.trim();
    }
    return { style: Object.keys(out).length >= 2 ? 'record' : 'none', options: out };
  }
  if (Array.isArray(rec)) {
    const out: Record<string, string> = {};
    let sawCorrect = false;
    let stringItems = 0;
    for (const item of rec) {
      if (typeof item === 'string') {
        // variant 7: bare string array — letters assigned by position (AMS101,
        // MTH101, STA111, CHE101, GST111, english.json, ...)
        if (item.trim()) out[LETTERS[stringItems]] = item.trim();
        stringItems++;
        continue;
      }
      if (item && typeof item === 'object') {
        const letter = String((item as Record<string, unknown>).letter ?? '').toUpperCase();
        const text = String((item as Record<string, unknown>).text ?? '').trim();
        if (/^[A-H]$/.test(letter) && text) {
          out[letter] = text;
          if ((item as Record<string, unknown>).correct === true) sawCorrect = true;
        }
      }
    }
    void sawCorrect;
    if (Object.keys(out).length >= 2) return { style: 'array', options: out };
    return { style: 'none', options: {} };
  }
  return { style: 'none', options: {} };
}

function letterFromOptionsByText(text: string, options: Record<string, string>): string | null {
  const norm = text.trim().toLowerCase().replace(/\s+/g, ' ');
  for (const [letter, opt] of Object.entries(options)) {
    if (opt.trim().toLowerCase().replace(/\s+/g, ' ') === norm) return letter;
  }
  return null;
}

function extractAnswer(
  q: Record<string, unknown>,
  options: Record<string, string>,
): { type: QuestionType; letter?: string; accepted?: string[] } | { error: string } {
  const correctInArray =
    Array.isArray(q.options) &&
    (q.options as Array<Record<string, unknown>>).find?.((o) => o && o.correct === true);

  const rawAnswer = q.answer ?? q.correct_letter;
  if (typeof rawAnswer === 'string' && rawAnswer.trim()) {
    const up = rawAnswer.trim().toUpperCase();
    if (/^[A-H]$/.test(up)) {
      if (!options[up]) return { error: `answer ${up} has no matching option` };
      return { type: 'mcq', letter: up };
    }
    // answer given as full text — resolve to a letter
    const letter = letterFromOptionsByText(rawAnswer, options);
    if (letter) return { type: 'mcq', letter };
    return { error: 'answer text matches no option' };
  }
  if (correctInArray) {
    const up = String(correctInArray.letter ?? '').toUpperCase();
    if (/^[A-H]$/.test(up) && options[up]) return { type: 'mcq', letter: up };
    return { error: 'correct:true option has no usable letter' };
  }
  if (Array.isArray(q.answers)) {
    const accepted = (q.answers as unknown[])
      .filter((v): v is string => typeof v === 'string')
      .map((v) => v.trim())
      .filter(Boolean);
    if (accepted.length > 0) return { type: 'text', accepted };
    return { error: 'empty answers array' };
  }
  return { error: 'no answer material found' };
}

export interface NormalizeResult {
  bundle: CbtBundle;
  key: CbtKey;
  report: BuildReport;
}

export function normalizeBank(rawText: string, filename: string): NormalizeResult {
  const fixes: string[] = [];
  const dropped: Array<{ index: number; reason: string }> = [];

  const clean = stripBom(rawText);
  if (clean !== rawText) fixes.push('stripped UTF-8 BOM');

  let parsedRaw: unknown;
  try {
    parsedRaw = JSON.parse(clean);
  } catch (e) {
    throw new Error(`${filename}: not valid JSON (${(e as Error).message})`);
  }
  const isWrapper =
    typeof parsedRaw === 'object' && parsedRaw !== null && Array.isArray((parsedRaw as { questions?: unknown }).questions);
  const rawQuestions: unknown[] = Array.isArray(parsedRaw)
    ? parsedRaw
    : isWrapper
      ? ((parsedRaw as { questions: unknown[] }).questions)
      : [];
  if (rawQuestions.length === 0) throw new Error(`${filename}: no questions array found`);

  const wrapper = isWrapper ? (parsedRaw as Record<string, unknown>) : {};
  const code = toCode(filename);
  const title =
    (typeof wrapper.title === 'string' && wrapper.title) ||
    (typeof wrapper.course === 'string' && wrapper.course) ||
    code;

  const questions: BundleQuestion[] = [];
  const answers: Record<string, KeyEntry> = {};
  const seenIds = new Set<string>();
  const seenStems = new Set<string>();
  let mcq = 0;
  let text = 0;

  rawQuestions.forEach((item, i) => {
    if (!item || typeof item !== 'object') {
      dropped.push({ index: i, reason: 'not an object' });
      return;
    }
    const q = item as Record<string, unknown>;
    const stem = String(q.question ?? '').trim();
    if (!stem) {
      dropped.push({ index: i, reason: 'empty stem' });
      return;
    }
    const dedupeKey = stem.toLowerCase();
    if (seenStems.has(dedupeKey)) {
      dropped.push({ index: i, reason: 'duplicate stem' });
      return;
    }

    const { style, options } = extractOptions(q);
    const ans = extractAnswer(q, options);
    if ('error' in ans) {
      dropped.push({ index: i, reason: ans.error });
      return;
    }

    let id = q.id !== undefined ? String(q.id) : '';
    if (!id || seenIds.has(id)) {
      if (id) fixes.push(`reassigned duplicate id "${id}" (question #${i + 1})`);
      id = `q${String(i + 1).padStart(3, '0')}`;
      while (seenIds.has(id)) id = `x${id}`;
    }

    const type: QuestionType = ans.type;
    const entry: BundleQuestion = { id, type, stem, marks: 1 };
    if (type === 'mcq') {
      entry.options = options;
      answers[id] = { type: 'mcq', letter: ans.letter!, ...(typeof q.explanation === 'string' && q.explanation.trim() ? { explanation: q.explanation.trim() } : {}) };
      mcq++;
    } else {
      answers[id] = { type: 'text', accepted: ans.accepted!, ...(typeof q.explanation === 'string' && q.explanation.trim() ? { explanation: q.explanation.trim() } : {}) };
      text++;
    }

    seenIds.add(id);
    seenStems.add(dedupeKey);
    questions.push(entry);
    if (style === 'array') fixes.push(`options array normalized (question #${i + 1})`);
  });

  const bundle: CbtBundle = {
    code,
    title,
    version: 1,
    questionCount: questions.length,
    totalMarks: questions.reduce((s, q) => s + q.marks, 0),
    durationMinutes: null,
    questions,
  };
  const key: CbtKey = { code, version: 1, answers };
  const report: BuildReport = {
    file: filename,
    code,
    parsed: rawQuestions.length,
    kept: questions.length,
    mcq,
    text,
    fixes: [...new Set(fixes)],
    dropped,
  };
  return { bundle, key, report };
}
