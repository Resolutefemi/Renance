/**
 * Client-side composite paper composition — a byte-exact mirror of the
 * study API's internal/cbtdata/paper.go + papercode.go.
 *
 * Why: the study API free plan sleeps (~40s cold start) and requires a
 * session for every bundle, so composed papers (mock / custom / pick)
 * made the whole app slow and locked signed-out students out entirely.
 * A paper is a pure function of its CODE, so the client composes the
 * exact same sitting from the statically shipped banks — instantly, and
 * offline. The API path stays as the fallback.
 *
 * Every detail matters for grading consistency (the server re-composes
 * the same paper when an attempt is submitted): the splitMix64 walk,
 * the Fisher-Yates order, the English comprehension/novel seating and
 * the custom even-share distribution are ported 1:1.
 */

import type { Bundle, BundleQuestion } from './exams';

/* ------------------------------------------------------------------ */
/* Code grammar (papercode.go)                                         */
/* ------------------------------------------------------------------ */

export const MOCK_PAPER_PREFIX = 'jamb-mock-';
const WAEC_CUSTOM_PREFIX = 'waec-custom-';
const NECO_CUSTOM_PREFIX = 'neco-custom-';
const JAMB_CUSTOM_PREFIX = 'jamb-custom-';
export const PICK_PAPER_PREFIX = 'jamb-pick-';

const DEFAULT_MOCK_ENGLISH = 60;
const DEFAULT_MOCK_TIMER = 120;
const DEFAULT_PICK_N = 40;
const DEFAULT_PART_N = 50;
// Go defaultNovelN — the novel seat count (clamped to the pool).
const NOVEL_N = 10;

export interface PaperSpec {
  family: 'mock' | 'custom' | 'pick';
  body: string; // jamb | waec | neco
  subjects: string[]; // mock/custom
  base: string; // pick
  years: number[]; // 0 = random (aligned with subjects; pick: length 1)
  from: number; // pick contiguous 1-based start; 0 = shuffle
  n: number;
  enN: number;
  comp: boolean;
  compN: number;
  novel: boolean;
  timer: number;
}

function splitParams(code: string): [string, string] {
  const i = code.indexOf('~');
  return i >= 0 ? [code.slice(0, i), code.slice(i + 1)] : [code, ''];
}

export function parsePaperCode(code: string): PaperSpec | null {
  const [bodyPart, params] = splitParams(code);
  const spec: PaperSpec = {
    family: 'pick',
    body: 'jamb',
    subjects: [],
    base: '',
    years: [],
    from: 0,
    n: 0,
    enN: 0,
    comp: true,
    compN: 0,
    novel: false,
    timer: 0,
  };
  if (bodyPart.startsWith(MOCK_PAPER_PREFIX) && bodyPart.length > MOCK_PAPER_PREFIX.length) {
    spec.family = 'mock';
    spec.body = 'jamb';
    spec.subjects = bodyPart.slice(MOCK_PAPER_PREFIX.length).split('-');
    applyParams(spec, params);
    return spec;
  }
  if (
    bodyPart.startsWith(WAEC_CUSTOM_PREFIX) && bodyPart.length > WAEC_CUSTOM_PREFIX.length
  ) {
    spec.family = 'custom';
    spec.body = 'waec';
    spec.subjects = bodyPart.slice(WAEC_CUSTOM_PREFIX.length).split('-');
    applyParams(spec, params);
    return spec;
  }
  if (
    bodyPart.startsWith(NECO_CUSTOM_PREFIX) && bodyPart.length > NECO_CUSTOM_PREFIX.length
  ) {
    spec.family = 'custom';
    spec.body = 'neco';
    spec.subjects = bodyPart.slice(NECO_CUSTOM_PREFIX.length).split('-');
    applyParams(spec, params);
    return spec;
  }
  if (
    bodyPart.startsWith(JAMB_CUSTOM_PREFIX) && bodyPart.length > JAMB_CUSTOM_PREFIX.length
  ) {
    spec.family = 'custom';
    spec.body = 'jamb';
    spec.subjects = bodyPart.slice(JAMB_CUSTOM_PREFIX.length).split('-');
    applyParams(spec, params);
    return spec;
  }
  if (bodyPart.startsWith(PICK_PAPER_PREFIX) && bodyPart.length > PICK_PAPER_PREFIX.length) {
    spec.family = 'pick';
    spec.base = bodyPart.slice(PICK_PAPER_PREFIX.length);
    applyParams(spec, params);
    return spec;
  }
  return null;
}

/** Per-subject slugs: multi-word slugs re-joined from the dash tokens. */
export function segmentSubjects(tokens: string[], dict: ReadonlySet<string>): string[] {
  const memo = new Map<number, string[] | null>();
  const rec = (pos: number): string[] | null => {
    if (pos === tokens.length) return [];
    if (memo.has(pos)) return memo.get(pos) ?? null;
    for (let end = pos + 1; end <= tokens.length; end++) {
      const cand = tokens.slice(pos, end).join('-');
      if (!dict.has(cand)) continue;
      const rest = rec(end);
      if (rest) {
        const out = [cand, ...rest];
        memo.set(pos, out);
        return out;
      }
    }
    memo.set(pos, null);
    return null;
  };
  return rec(0) ?? [];
}

function applyParams(spec: PaperSpec, params: string): void {
  if (!params) return;
  for (const pair of params.split('.')) {
    const eq = pair.indexOf('=');
    if (eq < 0) continue;
    const k = pair.slice(0, eq);
    const v = pair.slice(eq + 1);
    switch (k) {
      case 'y':
        spec.years = v.includes(';')
          ? v.split(';').map((t) => (t === 'r' ? 0 : Number(t) || 0))
          : [Number(v) || 0];
        break;
      case 'n':
        spec.n = Number(v) || 0;
        break;
      case 'from':
        spec.from = Number(v) || 0;
        break;
      case 'enN':
        spec.enN = Number(v) || 0;
        break;
      case 'comp':
        spec.comp = v === '1';
        break;
      case 'compN':
        spec.compN = Number(v) || 0;
        break;
      case 'nov':
        spec.novel = v === '1';
        break;
      case 't':
        spec.timer = Number(v) || 0;
        break;
    }
  }
}

/* ------------------------------------------------------------------ */
/* Deterministic RNG (paper.go splitMix64 + seeded Fisher-Yates)       */
/* ------------------------------------------------------------------ */

async function sha256First8BE(s: string): Promise<bigint> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  const bytes = new Uint8Array(buf.slice(0, 8));
  let v = 0n;
  for (const b of bytes) v = (v << 8n) | BigInt(b);
  return v;
}

// paperRNG seeds from "jamb-mock|" + code for EVERY family (the Go name
// is historical — the server uses it for mock, custom and pick alike).
function paperSeed(code: string): Promise<bigint> {
  return sha256First8BE('jamb-mock|' + code);
}

const MASK64 = 0xffffffffffffffffn;

function splitMix64(x: bigint): bigint {
  x = (x + 0x9e3779b97f4a7c15n) & MASK64;
  let z = x;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK64;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK64;
  return z ^ (z >> 31n);
}

class Rng {
  state: bigint;
  constructor(seed: bigint) {
    this.state = seed;
  }
  next(): bigint {
    this.state = splitMix64(this.state);
    return this.state;
  }
  /**
   * Seeded Fisher-Yates over [0..n) — ported verbatim. NOTE: it always
   * advances the RNG for the FULL array, even when the caller takes
   * zero rows; the server's sequence depends on that.
   */
  shuffledIndex(n: number): number[] {
    const idx = Array.from({ length: n }, (_, i) => i);
    for (let i = n - 1; i > 0; i--) {
      const j = Number(this.next() % BigInt(i + 1));
      [idx[i], idx[j]] = [idx[j], idx[i]];
    }
    return idx;
  }
  takeShuffled<T>(pool: T[], take: number): T[] {
    const k = Math.min(take, pool.length);
    const idx = this.shuffledIndex(pool.length);
    return idx.slice(0, k).map((i) => pool[i]);
  }
}

/* ------------------------------------------------------------------ */
/* Composition (paper.go ComposePaper / ComposePickPaper)              */
/* ------------------------------------------------------------------ */

const SUBJECT_TITLES: Record<string, string> = {
  english: 'Use of English',
  mathematics: 'Mathematics',
  'further-mathematics': 'Further Mathematics',
  physics: 'Physics',
  chemistry: 'Chemistry',
  biology: 'Biology',
  economics: 'Economics',
  government: 'Government',
  geography: 'Geography',
  literature: 'Literature in English',
  crs: 'Christian Religious Studies',
  irs: 'Islamic Religious Studies',
  'agricultural-science': 'Agricultural Science',
  'animal-husbandry': 'Animal Husbandry',
  commerce: 'Commerce',
  accounting: 'Principles of Accounts',
  'book-keeping': 'Book Keeping',
  'computer-studies': 'Computer Studies',
  'data-processing': 'Data Processing',
  'civic-education': 'Civic Education',
  insurance: 'Insurance',
  history: 'History',
  french: 'French',
  arabic: 'Arabic',
  hausa: 'Hausa',
  igbo: 'Igbo',
  yoruba: 'Yoruba',
  music: 'Music',
  'fine-arts': 'Fine Arts',
  'home-economics': 'Home Economics',
  'food-and-nutrition': 'Food and Nutrition',
  'home-management': 'Home Management',
  'catering-craft-practice': 'Catering Craft Practice',
  'physical-education': 'Physical Education',
  'health-education': 'Health Education',
  'office-practice': 'Office Practice',
  'technical-drawing': 'Technical Drawing',
  marketing: 'Marketing',
};

function subjectTitle(slug: string): string {
  return (
    SUBJECT_TITLES[slug] ??
    slug
      .split('-')
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(' ')
  );
}

function mcqOnly(qs: BundleQuestion[]): BundleQuestion[] {
  return qs.filter((q) => q.type !== 'theory');
}

function yearPool(qs: BundleQuestion[], year: number): BundleQuestion[] {
  return year ? qs.filter((q) => q.year === year) : qs;
}

function mockCap(slug: string): number {
  return slug === 'english' ? DEFAULT_MOCK_ENGLISH : 40;
}

/** English comprehension/novel seating — ported 1:1 from englishSplit. */
function englishSplit(
  pool: BundleQuestion[],
  rng: Rng,
  total: number,
  comp: boolean,
  compN: number,
  novel: boolean,
): BundleQuestion[] {
  const compQ: BundleQuestion[] = [];
  const novelQ: BundleQuestion[] = [];
  const restQ: BundleQuestion[] = [];
  for (const q of pool) {
    if (q.group === 'comprehension') compQ.push(q);
    else if (q.group === 'novel') novelQ.push(q);
    else restQ.push(q);
  }
  if (comp && compN > compQ.length) compN = compQ.length;
  if (!comp) compN = 0;
  let novelN = NOVEL_N;
  if (novelN > novelQ.length) novelN = novelQ.length;
  if (!novel) novelN = 0;
  if (total > compQ.length + novelQ.length + restQ.length) {
    total = compQ.length + novelQ.length + restQ.length;
  }
  if (total <= 0) throw new Error('english section has no questions');
  if (!comp && !novel && restQ.length === 0) {
    throw new Error('comprehension excluded but the bank has no other English questions');
  }
  novelN = Math.min(novelN, total);
  compN = Math.min(compN, total - novelN);
  const out: BundleQuestion[] = [];
  const used = new Set<string>();
  const seat = (src: BundleQuestion[], n: number) => {
    for (const q of rng.takeShuffled(src, n)) {
      out.push(q);
      used.add(q.id);
    }
  };
  seat(novelQ, novelN);
  seat(compQ, compN);
  const need = total - out.length;
  if (need > 0) seat(restQ, need);
  if (out.length < total) {
    const extra = rng.takeShuffled([...novelQ, ...compQ], novelQ.length + compQ.length);
    for (const q of extra) {
      if (out.length >= total) break;
      if (used.has(q.id)) continue;
      out.push(q);
      used.add(q.id);
    }
  }
  return out;
}

export async function composePaper(
  code: string,
  spec: PaperSpec,
  resolveBank: (slug: string) => Promise<Bundle | null>,
  resolveBase: () => Promise<Bundle | null>,
): Promise<Bundle> {
  const rng = new Rng(await paperSeed(code));

  if (spec.family === 'pick') {
    const base = await resolveBase();
    if (!base) throw new Error('base pack not loaded');
    const year = spec.years.length === 1 ? spec.years[0] : 0;
    const pool = yearPool(mcqOnly(base.questions), year);
    if (pool.length === 0) {
      throw new Error(year ? `${base.code} has no objective questions for ${year}` : `${base.code} has no objective questions`);
    }
    let n = spec.n;
    if (n <= 0) n = spec.from > 0 ? DEFAULT_PART_N : DEFAULT_PICK_N;
    let picked: BundleQuestion[];
    if (spec.from > 0) {
      const start = spec.from - 1;
      if (start >= pool.length) {
        throw new Error(`${base.code} has ${pool.length} questions, from=${spec.from} is past the end`);
      }
      picked = pool.slice(start, Math.min(start + n, pool.length));
    } else {
      picked = rng.takeShuffled(pool, n);
    }
    const paper: Bundle = {
      code,
      title: base.title,
      version: 1,
      category: base.category,
      body: base.body,
      questions: [...picked],
      questionCount: 0,
      totalMarks: 0,
    };
    if (year) {
      paper.title = `${base.title.replace(/ Bank$/, '')} · ${year} Practice`;
    } else if (spec.from > 0) {
      paper.title = `${base.title} · Q${spec.from}–Q${spec.from + picked.length - 1}`;
    } else {
      paper.title = `${base.title} · Practice Set`;
    }
    if (base.durationMinutes != null && spec.timer === 0) {
      paper.durationMinutes = base.durationMinutes;
    }
    if (spec.timer > 0) {
      paper.durationMinutes = spec.timer;
    }
    paper.totalMarks = paper.questions.reduce((s, q) => s + (q.marks || 0), 0);
    paper.questionCount = paper.questions.length;
    return paper;
  }

  // mock / custom
  const body = spec.body;
  const subjects = spec.subjects;
  const share = new Map<string, number>();
  if (spec.family === 'custom') {
    let n = spec.n;
    if (n <= 0) n = 40;
    const baseShare = Math.floor(n / subjects.length);
    const rem = n % subjects.length;
    subjects.forEach((s, i) => {
      share.set(s, baseShare + (i < rem ? 1 : 0));
    });
  }

  const paper: Bundle = {
    code,
    title: '',
    version: 1,
    category: 'secondary',
    body: body.toUpperCase(),
    sections: [],
    questions: [],
    questionCount: 0,
    totalMarks: 0,
  };
  const titles: string[] = [];
  for (let i = 0; i < subjects.length; i++) {
    const slug = subjects[i];
    const bank = await resolveBank(slug);
    if (!bank || bank.code !== `${body}-${slug}-bank`) {
      throw new Error(`paper ${code} needs bank ${body}-${slug}-bank`);
    }
    titles.push(subjectTitle(slug));
    const year = spec.years.length > i ? spec.years[i] : 0;
    const pool = yearPool(mcqOnly(bank.questions), year);

    let take: number;
    if (spec.family === 'mock') {
      take = mockCap(slug);
      if (slug === 'english' && spec.enN > 0) take = spec.enN;
    } else {
      take = share.get(slug) ?? 0;
    }

    const useEnglishSplit = slug === 'english' && body === 'jamb';
    let section: BundleQuestion[];
    if (useEnglishSplit) {
      // NB: the server passes spec.CompN through UNCHANGED — an absent
      // compN param is 0 (no comprehension seated), NOT the documented
      // default of 10 (paper_test.go asserts CompN == 0 canonically).
      section = englishSplit(pool, rng, take, spec.comp, spec.compN, spec.novel);
    } else {
      section = rng.takeShuffled(pool, Math.min(take, pool.length));
    }
    paper.sections!.push({
      subject: subjectTitle(slug),
      questionIds: section.map((q) => q.id),
    });
    paper.questions.push(...section);
  }
  paper.totalMarks = paper.questions.reduce((s, q) => s + (q.marks || 0), 0);
  if (spec.family === 'mock') {
    paper.durationMinutes = spec.timer || DEFAULT_MOCK_TIMER;
  } else if (spec.timer > 0) {
    paper.durationMinutes = spec.timer;
  }
  paper.questionCount = paper.questions.length;
  let label = 'UTME Mock';
  if (spec.family === 'custom') {
    label = body === 'waec' ? 'WASSCE Practice' : body === 'neco' ? 'NECO Practice' : 'Custom Practice';
  }
  paper.title = `${label} · ${titles.join(' + ')}`;
  if (paper.questionCount === 0) throw new Error(`paper ${code} composed to zero questions`);
  return paper;
}
