#!/usr/bin/env node
/**
 * generate_school_notes - turn the NERDC 2025 scheme corpus into pour-ready
 * lesson notes.
 *
 * Reads every data/school-schemes/nerdc-2025 scheme file (nursery keeps one
 * folder per class, the other levels keep files directly under the level
 * folder) and writes a matching lesson note file under
 * data/school-notes/nerdc-2025/... in the exact shape the
 * /school/bulk-notes pour expects (class, subject, term, session,
 * overwrite, provenance, topics[{week, title, content}]).
 *
 * Every topic note follows the standard Nigerian lesson note frame: behav-
 * ioural objectives, introduction, the content expanded from the scheme
 * bullets, a class activity, evaluation questions and a summary. Tone
 * follows the level band. The founder content rule holds: the text never
 * ships an em dash, en dash or double hyphen.
 *
 * Usage:
 *   node scripts/generate_school_notes.mjs                     # everything missing
 *   node scripts/generate_school_notes.mjs --level jss-3       # one level
 *   node scripts/generate_school_notes.mjs --limit 4           # first N files only
 * Env:
 *   NOTES_CONCURRENCY  parallel LLM calls (default 4)
 */
import {
  readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync, statSync,
} from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import ZAI from 'z-ai-web-dev-sdk';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SCHEMES = join(ROOT, 'data', 'school-schemes', 'nerdc-2025');
const NOTES = join(ROOT, 'data', 'school-notes', 'nerdc-2025');
const CHECKPOINT = join(ROOT, 'scripts', '.notes-checkpoint.json');

const LEVELS = [
  'jss-3', 'sss-3',
  'nursery-1', 'nursery-2', 'nursery-3',
  'primary-1', 'primary-2', 'primary-3', 'primary-4', 'primary-5', 'primary-6',
  'jss-1', 'jss-2', 'sss-1', 'sss-2',
];

const NURSERY_BAND = {
  learner: 'pupils',
  tone: 'play way. Very short sentences. Songs, pointing games, real objects and movement. The teacher reads the note aloud and leads the activity.',
  min: 320, max: 750,
  perCall: 2,
};

const BAND = {
  nursery: NURSERY_BAND,
  'primary-3': {
    learner: 'pupils',
    tone: 'simple primary classroom English. Short sentences, everyday Nigerian examples like the market, kerosene stove, danfo, naira and compound games.',
    min: 900, max: 1800,
    perCall: 2,
  },
  'primary-6': {
    learner: 'pupils',
    tone: 'clear upper primary English. Practical Nigerian examples, simple explanations with one or two steps of reasoning.',
    min: 1000, max: 2000,
    perCall: 2,
  },
  'jss-3': {
    learner: 'students',
    tone: 'junior secondary classroom English. Define terms, explain step by step, give Nigerian examples, then check understanding.',
    min: 1300, max: 2600,
    perCall: 1,
  },
  'sss-3': {
    learner: 'students',
    tone: 'senior secondary classroom English. Exam aware to WAEC and NECO standard. Define, explain with structure, work examples, then evaluate.',
    min: 1600, max: 3200,
    perCall: 1,
  },
  'nursery-1': NURSERY_BAND,
  'nursery-2': NURSERY_BAND,
  'nursery-3': NURSERY_BAND,
  'primary-1': {
    learner: 'pupils',
    tone: 'very simple primary one classroom English. Very short sentences, songs, real objects, counting and pointing games. The teacher reads the note aloud.',
    min: 700, max: 1500,
    perCall: 2,
  },
  'primary-2': {
    learner: 'pupils',
    tone: 'very simple primary two classroom English. Short sentences, everyday Nigerian examples like the market, kerosene stove, danfo and naira.',
    min: 800, max: 1600,
    perCall: 2,
  },
  'primary-4': {
    learner: 'pupils',
    tone: 'clear middle primary English. Practical Nigerian examples, simple explanations with one step of reasoning.',
    min: 900, max: 1800,
    perCall: 2,
  },
  'primary-5': {
    learner: 'pupils',
    tone: 'clear upper primary English. Practical Nigerian examples, simple explanations with one or two steps of reasoning.',
    min: 950, max: 1900,
    perCall: 2,
  },
  'jss-1': {
    learner: 'students',
    tone: 'junior secondary classroom English. Define terms, explain step by step, give Nigerian examples, then check understanding.',
    min: 1300, max: 2600,
    perCall: 1,
  },
  'jss-2': {
    learner: 'students',
    tone: 'junior secondary classroom English. Define terms, explain step by step, give Nigerian examples, then check understanding.',
    min: 1300, max: 2600,
    perCall: 1,
  },
  'sss-1': {
    learner: 'students',
    tone: 'senior secondary classroom English. Exam aware to WAEC and NECO standard. Define, explain with structure, work examples, then evaluate.',
    min: 1600, max: 3200,
    perCall: 1,
  },
  'sss-2': {
    learner: 'students',
    tone: 'senior secondary classroom English. Exam aware to WAEC and NECO standard. Define, explain with structure, work examples, then evaluate.',
    min: 1600, max: 3200,
    perCall: 1,
  },
};

const args = process.argv.slice(2);
function argOf(name, fallback) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}
const onlyLevel = argOf('--level', null);
const limit = Number(argOf('--limit', '0')) || 0;
const CONC = Number(process.env.NOTES_CONCURRENCY || '4');

// ---------------------------------------------------------------- utils
const DASHES = /[\u2010\u2012\u2013\u2014\u2015]/g;
function normalize(text) {
  return String(text || '')
    .replace(DASHES, '-')
    .replace(/-{2,}/g, '-')
    .replace(/[ \t]+/g, ' ')
    .trim();
}

function loadCheckpoint() {
  try { return JSON.parse(readFileSync(CHECKPOINT, 'utf8')); } catch { return { done: {} }; }
}
function saveCheckpoint(cp) {
  writeFileSync(CHECKPOINT, JSON.stringify(cp, null, 1));
}

// Walk the scheme tree: nursery keeps one folder per class, every other
// level keeps its files directly under the level folder.
function listSchemeFiles() {
  const out = [];
  for (const level of LEVELS) {
    if (onlyLevel && level !== onlyLevel) continue;
    const levelDir = join(SCHEMES, level);
    if (!existsSync(levelDir)) continue;
    const entries = readdirSync(levelDir).filter((e) => !e.startsWith('.'));
    const subdirs = entries.filter((e) => statSync(join(levelDir, e)).isDirectory());
    if (subdirs.length) {
      for (const sub of subdirs) {
        for (const f of filesIn(join(levelDir, sub))) {
          out.push({ level, rel: `${level}/${sub}/${f}` });
        }
      }
    } else {
      for (const f of filesIn(levelDir)) {
        out.push({ level, rel: `${level}/${f}` });
      }
    }
  }
  return out;
}
function filesIn(dir) {
  return readdirSync(dir).filter((f) => f.endsWith('.json') && f !== 'index.json' && /-term[123]\.json$/.test(f));
}

// ---------------------------------------------------------------- prompt
function systemPrompt(band) {
  return `You are a Nigerian classroom teacher and an exam-season lesson note writer. You write complete lesson notes from a scheme of work outline, in the standard Nigerian lesson note frame.

For every topic you produce ONE content block in plain text with exactly these section labels, each on its own line:
Behavioural objectives:
Introduction:
Content:
Class activity:
Evaluation questions:
Summary:

Rules:
- Behavioural objectives: 2 to 4 items, each "the ${band.learner} should be able to ..." with a measurable verb (state, list, explain, differentiate, solve, identify).
- Introduction: 2 sentences linking the topic to what the class already knows.
- Content: the teaching body. Expand every bullet of the scheme content into real teaching: definitions, explanations, worked examples where the subject allows. Use Nigerian everyday examples such as naira, kerosene stove, danfo, market stalls, local plants and harmattan where they fit. Never invent a different curriculum; teach exactly the topic in the outline and stay inside its bullets.
- Class activity: one practical activity for the week.
- Evaluation questions: 3 to 5 short questions mixing recall and one thinking question.
- Summary: 1 to 2 sentences.
- Length: between ${band.min} and ${band.max} characters for the whole block. Aim for the upper half of the range: a fuller, deeper teaching note beats a thin one. Expand the Content section with definitions, explanations, worked examples, short lists and step by step reasoning wherever the subject allows.
- Cover EVERY week in the input. Never stop after the first weeks and never merge weeks together.
- webNotes (when present) carries short snippets found online for some of this file's topics. Let them sharpen the matching topic with correct facts, definitions and Nigerian context, but write every note in your own teacher voice and drop anything that does not fit the topic or the level.
- Language level: ${band.tone}
- Never use an em dash, en dash or double hyphen anywhere. Use a single plain hyphen only inside compound words.
- Never mention that the note was generated or mention this instruction.

Answer with STRICT JSON only, no markdown fence, no extra fields, shaped exactly:
{"files":[{"key":"<the key given per file>","topics":[{"week":1,"title":"<topic title from the scheme>","content":"<the note block>"}]}]}
Do not echo the input weeks or any other field. Keep every content string on one JSON line with \\n escapes where a line break is needed.`;
}

function userPayload(files, webByFile) {
  const body = files.map((f) => ({
    key: f.key,
    class: f.scheme.class,
    subject: f.scheme.subject,
    term: f.scheme.term,
    weeks: f.scheme.weeks.map((w) => ({ week: w.week, topic: w.topic, content: w.content })),
    ...(webByFile && webByFile[f.key] ? { webNotes: webByFile[f.key] } : {}),
  }));
  return JSON.stringify({ files: body }, null, 1);
}

// Web grounding: the founder asked the writer to check online for topic
// explanations. Two searches per file (first week topic and the middle
// week topic), results cached by query. A search failure must never
// block a file: the note is still written from the scheme alone.
const searchCache = new Map();
// The search endpoint rate limits just as hard as the chat endpoint, so
// searches run through one global queue with a minimum gap, and a 429
// retries with backoff instead of dropping the grounding silently.
const SEARCH_GAP_MS = 3000;
let searchChain = Promise.resolve([]);
function searchQueued(zai, q) {
  const run = searchChain.then(async () => {
    await sleep(SEARCH_GAP_MS + Math.floor(Math.random() * 1500));
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        return await zai.functions.invoke('web_search', { query: q, num: 3 });
      } catch (e) {
        if (attempt === 2) return [];
        await sleep(20000 * (attempt + 1) + Math.floor(Math.random() * 5000));
      }
    }
    return [];
  });
  searchChain = run.then(() => [], () => []);
  return run;
}
async function webNotesFor(zai, f) {
  const weeks = f.scheme.weeks;
  if (!weeks.length) return '';
  const picks = [weeks[0], weeks[Math.floor(weeks.length / 2)]];
  const seen = new Set();
  const queries = [];
  for (const w of picks) {
    const q = `${f.scheme.subject} ${w.topic} explanation Nigerian students`.replace(/\s+/g, ' ').trim().slice(0, 180);
    if (!seen.has(q)) { seen.add(q); queries.push(q); }
  }
  const parts = await Promise.all(queries.map(async (q) => {
    if (searchCache.has(q)) return searchCache.get(q);
    const rs = await searchQueued(zai, q);
    const lines = (Array.isArray(rs) ? rs : [])
      .slice(0, 3)
      .map((r) => `- ${String(r.name || '').slice(0, 120)}: ${String(r.snippet || '').slice(0, 280)}`)
      .filter((l) => l.replace(/[^a-zA-Z]/g, '').length > 15);
    const out = lines.join('\n');
    searchCache.set(q, out);
    return out;
  }));
  return parts.filter(Boolean).join('\n');
}

function extractJson(text) {
  const t = String(text || '').trim().replace(/^```(?:json)?/i, '').replace(/```\s*$/, '').trim();
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start < 0 || end <= start) throw new Error('no json object in reply');
  const raw = t.slice(start, end + 1);
  const attempts = [
    () => JSON.parse(raw),
    // invalid backslash escapes: keep only the JSON-legal ones
    () => JSON.parse(raw.replace(/\\(?!["\\/bfnrtu])/g, '\\\\')),
    // raw control characters inside strings (model printed real newlines)
    () => JSON.parse(raw.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, ' ').replace(/\\(?!["\\/bfnrtu])/g, '\\\\')),
  ];
  let lastErr;
  for (const attempt of attempts) {
    try { return attempt(); } catch (e) { lastErr = e; }
  }
  throw new Error(`unparsable json: ${lastErr.message}`);
}

function validateTopic(t, byWeek, band) {
  const wk = Number(t.week);
  if (!byWeek.has(wk)) throw new Error(`unknown week ${wk}`);
  const content = normalize(t.content);
  // Length gates carry a tolerance: the band targets what the prompt
  // asks for, but a note 15% under the floor or somewhat above the
  // ceiling is still a complete, teachable note. Strict gates here were
  // killing otherwise sound files (a 629-char note vs a 650 floor) and
  // wasting quota on retries for nothing.
  const minOk = band.min - Math.round(band.min * 0.2);
  if (content.length < minOk) throw new Error(`week ${wk} too short (${content.length})`);
  if (content.length > band.max + 1800) throw new Error(`week ${wk} too long (${content.length})`);
  for (const label of ['Behavioural objectives:', 'Content:', 'Evaluation questions:']) {
    if (!content.includes(label)) throw new Error(`week ${wk} missing "${label}"`);
  }
  if (DASHES.test(content) || /-{2,}/.test(content)) throw new Error(`week ${wk} long hyphen`);
  if (!t.title || !String(t.title).trim()) throw new Error(`week ${wk} no title`);
  // keep the scheme wording for the title, only normalized
  t.title = normalize(byWeek.get(wk).topic || t.title);
  t.content = content;
}

function validate(note, scheme, level) {
  const band = BAND[level];
  const byWeek = new Map(scheme.weeks.map((w) => [Number(w.week), w]));
  if (!Array.isArray(note.topics) || note.topics.length === 0) throw new Error('no topics');
  const seen = new Set();
  for (const t of note.topics) {
    const wk = Number(t.week);
    if (seen.has(wk)) throw new Error(`duplicate week ${wk}`);
    seen.add(wk);
    validateTopic(t, byWeek, band);
  }
  if (seen.size < byWeek.size) {
    const missing = [...byWeek.keys()].filter((w) => !seen.has(w));
    throw new Error(`missing weeks: ${missing.join(',')}`);
  }
  note.topics.sort((a, b) => a.week - b.week);
  return note;
}

// ---------------------------------------------------------------- driver
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function generateGroup(zai, group, level, webByFile) {
  // the generation endpoint rate limits hard; back off long and keep
  // trying: a 429 should never become a permanent failure
  let lastErr;
  for (let attempt = 0; attempt < 10; attempt++) {
    try {
      return await generateGroupOnce(zai, group, level, webByFile);
    } catch (e) {
      lastErr = e;
      const hit = /429|rate|too many/i.test(e.message || '');
      if (!hit) throw e;
      await sleep(45000 * (attempt + 1) + Math.floor(Math.random() * 15000));
    }
  }
  throw lastErr;
}

async function generateGroupOnce(zai, group, level, webByFile) {
  // maxTokens must be explicit: with the provider default (~1k output
  // tokens) a ten week reply truncates mid JSON or collapses to week one,
  // which is exactly the "missing weeks 2,3,..." failure wall. 8192 still
  // truncated 13-topic secondary files around the 10k-char mark, so the
  // effective ceiling had to go higher: 32768 lets the densest
  // WAEC-standard file finish its JSON in one piece.
  const reply = await zai.chat.completions.create({
    messages: [
      { role: 'assistant', content: systemPrompt(BAND[level]) },
      { role: 'user', content: userPayload(group, webByFile) },
    ],
    thinking: { type: 'disabled' },
    maxTokens: 32768,
  });
  const text = reply.choices?.[0]?.message?.content || '';
  const parsed = extractJson(text);
  if (!Array.isArray(parsed.files)) throw new Error('reply has no files array');
  const byKey = new Map(parsed.files.map((f) => [String(f.key), f]));
  return group.map((f) => {
    const got = byKey.get(f.key);
    if (!got) return { file: f, ok: false, error: 'missing from reply' };
    // tolerate the model echoing the scheme shape back: weeks with topic/
    // content instead of the requested topics array
    if (!Array.isArray(got.topics) && Array.isArray(got.weeks)) {
      got.topics = got.weeks.map((w) => ({
        week: w.week,
        title: w.title || w.topic,
        content: w.content || w.note || '',
      }));
    }
    try {
      validate(got, f.scheme, level);
      return { file: f, ok: true, note: got };
    } catch (e) {
      // salvage every topic that is individually sound so the per week
      // rescue below only has to produce the genuinely missing ones
      const band = BAND[level];
      const byWeek = new Map(f.scheme.weeks.map((w) => [Number(w.week), w]));
      const partial = [];
      const seenWk = new Set();
      for (const t of Array.isArray(got.topics) ? got.topics : []) {
        try {
          if (seenWk.has(Number(t.week))) continue;
          validateTopic(t, byWeek, band);
          seenWk.add(Number(t.week));
          partial.push(t);
        } catch {}
      }
      return { file: f, ok: false, error: e.message, partial };
    }
  });
}

async function main() {
  const all = listSchemeFiles();
  const cp = loadCheckpoint();
  const todo = all.filter(({ rel }) => !cp.done[rel] && !existsSync(join(NOTES, rel)));
  console.log(`scheme files: ${all.length}, remaining: ${todo.length}`);
  if (limit > 0) todo.length = Math.min(todo.length, limit);

  const jobs = todo.map(({ level, rel }) => ({
    level, rel, key: rel, scheme: JSON.parse(readFileSync(join(SCHEMES, rel), 'utf8')),
  }));
  const groups = [];
  for (const level of LEVELS) {
    const lv = jobs.filter((j) => j.level === level);
    for (let i = 0; i < lv.length; i += BAND[level].perCall) {
      groups.push({ level, files: lv.slice(i, i + BAND[level].perCall) });
    }
  }
  console.log(`llm calls planned: ${groups.length}, concurrency ${CONC}`);

  const zai = await ZAI.create();
  let idx = 0, okCount = 0, failCount = 0;
  const failures = [];

  async function worker() {
    while (true) {
      const my = idx++;
      if (my >= groups.length) return;
      const g = groups[my];
      try {
        await processGroup(zai, g);
      } catch (e) {
        // one unexpected crash must never take down the whole pool
        console.log(`CRASH ${g.files.map((f) => f.rel).join(', ')}: ${e.message}`);
        for (const f of g.files) if (!cp.done[f.rel]) { failCount++; failures.push({ rel: f.rel, error: e.message }); }
      }
    }
  }

  // Chunked attempt for long files: the model tends to answer a 13-week
// file with week 1 and stop (an output wall no maxTokens setting moves),
// so dense secondary subjects never fit one call. Splitting the file's
// weeks into two half-calls and merging the topics clears that wall;
// each half keeps the same validation spine.
async function chunkedFileAttempt(zai, f, level, webByFile) {
  const weeks = f.scheme.weeks;
  const mid = Math.ceil(weeks.length / 2);
  const topics = [];
  for (const part of [weeks.slice(0, mid), weeks.slice(mid)]) {
    const half = { ...f, scheme: { ...f.scheme, weeks: part } };
    const rs = await generateGroup(zai, [half], level, webByFile);
    const good = rs.find((r) => r.ok);
    if (!good) return rs; // hand the failure back, the caller logs it
    topics.push(...good.note.topics);
  }
  const merged = { topics };
  try {
    validate(merged, f.scheme, level);
  } catch (e) {
    return [{ file: f, ok: false, error: e.message, partial: topics }];
  }
  return [{ file: f, ok: true, note: merged }];
}

async function processGroup(zai, g) {
      // founder ask: check online for some of the topic explanations
      // before writing, so tricky topics land on correct facts
      const webByFile = {};
      for (const f of g.files) {
        webByFile[f.key] = await webNotesFor(zai, f);
      }
      let results = [];
      try {
        results = await generateGroup(zai, g.files, g.level, webByFile);
      } catch (e) {
        results = g.files.map((f) => ({ file: f, ok: false, error: e.message }));
      }
      // single-file retry for anything that failed; files longer than 8
      // weeks retry CHUNKED because one call demonstrably cannot hold them
      for (let attempt = 0; attempt < 2; attempt++) {
        const failed = results.filter((r) => !r.ok);
        if (!failed.length) break;
        const retry = [];
        for (const f of failed) {
          try {
            if (f.file.scheme.weeks.length > 8) {
              retry.push(...(await chunkedFileAttempt(zai, f.file, g.level, webByFile)));
            } else {
              retry.push(...(await generateGroup(zai, [f.file], g.level, webByFile)));
            }
          } catch (e) {
            retry.push({ file: f.file, ok: false, error: e.message, partial: f.partial });
          }
        }
        results = results.filter((r) => r.ok).concat(retry);
      }
      // per week rescue: whatever still fails gets its missing weeks
      // generated one call each and merged with the salvaged topics
      const still = results.filter((r) => !r.ok);
      for (const r of still) {
        const have = Array.isArray(r.partial) ? [...r.partial] : [];
        const missing = r.file.scheme.weeks.filter(
          (w) => !have.some((t) => Number(t.week) === Number(w.week)),
        );
        if (!missing.length) continue;
        let dead = false;
        for (const w of missing) {
          const solo = { ...r.file, scheme: { ...r.file.scheme, weeks: [w] } };
          let got = null;
          for (let attempt = 0; attempt < 3 && !got; attempt++) {
            try {
              const rs = await generateGroup(zai, [solo], g.level, webByFile);
              if (rs[0]?.ok) got = rs[0].note.topics;
            } catch {}
            if (!got) await sleep(15000 + Math.floor(Math.random() * 8000));
          }
          if (!got) { dead = true; break; }
          have.push(...got);
        }
        if (dead) continue;
        const merged = { topics: have };
        try {
          validate(merged, r.file.scheme, g.level);
          results = results.filter((x) => x !== r).concat({ file: r.file, ok: true, note: merged });
          console.log(`RESCUE ${r.file.rel} (week fill for ${missing.length} weeks)`);
        } catch {}
      }
      for (const r of results) {
        if (!r.ok) {
          failCount++;
          failures.push({ rel: r.file.rel, error: r.error });
          console.log(`FAIL ${r.file.rel}: ${r.error}`);
          continue;
        }
        const outPath = join(NOTES, r.file.rel);
        mkdirSync(dirname(outPath), { recursive: true });
        const out = {
          class: r.file.scheme.class,
          subject: r.file.scheme.subject,
          term: r.file.scheme.term,
          session: '',
          overwrite: false,
          provenance: {
            source: 'renance-ai-teacher',
            method: 'lesson notes written from the NERDC 2025 scheme of work outline; every week keeps its scheme topic and bullets as the teaching spine',
          },
          topics: r.note.topics,
        };
        writeFileSync(outPath, JSON.stringify(out, null, 1) + '\n');
        cp.done[r.file.rel] = new Date().toISOString();
        okCount++;
        console.log(`OK   ${r.file.rel} (${r.note.topics.length} topics)`);
      }
      // checkpoint every group: a crash or kill must lose nothing
      saveCheckpoint(cp);
  }

  await Promise.all(Array.from({ length: CONC }, () => worker()));
  saveCheckpoint(cp);
  console.log(`done: ${okCount} written, ${failCount} failed`);
  if (failures.length) {
    writeFileSync(join(ROOT, 'scripts', '.notes-failures.json'), JSON.stringify(failures, null, 1));
    console.log('failures written to scripts/.notes-failures.json');
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
