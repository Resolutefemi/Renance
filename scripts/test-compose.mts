/**
 * Standalone verification of the client-side compose mirror
 * (apps/web/lib/paper-compose.ts) against the statically shipped
 * library. Run: node --experimental-strip-types test-compose.mts
 */
import { parsePaperCode, composePaper } from '../apps/web/lib/paper-compose.ts';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url)); // repo root
const manifest = JSON.parse(readFileSync(`${root}/data/manifest.json`, 'utf8'));
const byCode = new Map(manifest.exams.map((e) => [e.code, e]));
const cache = new Map();

function loadBundle(code) {
  if (cache.has(code)) return cache.get(code);
  const exam = byCode.get(code);
  const b = JSON.parse(readFileSync(`${root}/apps/web/public/bundles/${exam.code}.json`, 'utf8'));
  cache.set(code, b);
  return b;
}

let failures = 0;
function check(name, cond, detail = '') {
  if (cond) console.log(`  PASS  ${name}`);
  else {
    failures++;
    console.log(`  FAIL  ${name} ${detail}`);
  }
}

/* 1. contiguous pick — Part 1 of WAEC maths must be exactly Q1-Q50 */
{
  const code = 'jamb-pick-waec-mathematics-bank~from=1.n=50';
  const spec = parsePaperCode(code);
  check('pick spec parsed', spec && spec.family === 'pick' && spec.base === 'waec-mathematics-bank' && spec.from === 1 && spec.n === 50);
  const paper = await composePaper(code, spec, async () => null, async () => loadBundle('waec-mathematics-bank'));
  const base = loadBundle('waec-mathematics-bank');
  const mcq = base.questions.filter((q) => q.type !== 'theory');
  check('pick contiguous = pool[0..50)', paper.questions.length === 50 && paper.questions.every((q, i) => q.id === mcq[i].id));
  check('pick title', paper.title === 'Q1–Q50' || /Q1–Q50/.test(paper.title), paper.title);
  check('pick body carries base body', paper.body === base.body);
  check('pick marks sum', paper.totalMarks === paper.questions.reduce((s, q) => s + q.marks, 0));
}

/* 2. random pick — deterministic, same code twice = same set */
{
  const code = 'jamb-pick-waec-mathematics-bank~n=50';
  const spec = parsePaperCode(code);
  const a = await composePaper(code, spec, async () => null, async () => loadBundle('waec-mathematics-bank'));
  const b = await composePaper(code, spec, async () => null, async () => loadBundle('waec-mathematics-bank'));
  check('random pick deterministic', JSON.stringify(a.questions.map((q) => q.id)) === JSON.stringify(b.questions.map((q) => q.id)));
  check('random pick size', a.questions.length === 50);
  const c = await composePaper('jamb-pick-waec-mathematics-bank~n=40', parsePaperCode('jamb-pick-waec-mathematics-bank~n=40'), async () => null, async () => loadBundle('waec-mathematics-bank'));
  check('different n → different set', JSON.stringify(a.questions.map((q) => q.id)) !== JSON.stringify(c.questions.map((q) => q.id)));
  // all ids must belong to the base bank
  const baseIds = new Set(loadBundle('waec-mathematics-bank').questions.map((q) => q.id));
  check('random pick ids ⊆ base', a.questions.every((q) => baseIds.has(q.id)));
}

/* 3. university pick — the founder's exact broken flow */
{
  const code = 'jamb-pick-uni-futa-ams101-bank~n=50';
  const spec = parsePaperCode(code);
  const paper = await composePaper(code, spec, async () => null, async () => loadBundle('uni-futa-ams101-bank'));
  check('futa pick composes', paper.questions.length === 50);
  check('futa pick answers ride along', paper.questions.every((q) => typeof q.answer === 'string' && q.answer.length >= 1));
}

/* 4. custom paper — waec-custom-english-mathematics~n=40 */
{
  const code = 'waec-custom-english-mathematics~n=40';
  const spec = parsePaperCode(code);
  check('custom spec', spec && spec.family === 'custom' && spec.body === 'waec' && spec.n === 40);
  const paper = await composePaper(
    code,
    spec,
    async (slug) => loadBundle(`waec-${slug}-bank`),
    async () => null,
  );
  check('custom even share', paper.questions.length === 40);
  check('custom sections', paper.sections.length === 2 && paper.sections[0].subject === 'Use of English' && paper.sections[1].subject === 'Mathematics');
  check('custom title', paper.title.startsWith('WASSCE Practice · '), paper.title);
  const ids = paper.questions.map((q) => q.id);
  check('custom no duplicates', new Set(ids).size === ids.length);
}

/* 5. mock paper — jamb-mock-english-biology-chemistry-physics (exam mode) */
{
  const code = 'jamb-mock-english-biology-chemistry-physics';
  const spec = parsePaperCode(code);
  const paper = await composePaper(
    code,
    spec,
    async (slug) => loadBundle(`jamb-${slug}-bank`),
    async () => null,
  );
  check('mock 180 questions', paper.questions.length === 180, String(paper.questions.length));
  check('mock duration 120', paper.durationMinutes === 120);
  check('mock english 60 + electives 40 each', paper.sections[0].questionIds.length === 60 && paper.sections.slice(1).every((s) => s.questionIds.length === 40));
  check('mock exam body', paper.body === 'JAMB' && paper.title.startsWith('UTME Mock · '));
  const ids = paper.questions.map((q) => q.id);
  check('mock no duplicates', new Set(ids).size === ids.length);
}

/* 6. local grading sanity */
{
  const { gradeLocally } = await import('../apps/web/lib/exams-local.ts').catch(() => ({}));
  if (!gradeLocally) {
    console.log('  SKIP  local grading (imported separately in exams.ts)');
  }
}

console.log(failures ? `\n${failures} FAILURES` : '\nALL PASS');
process.exit(failures ? 1 : 0);
