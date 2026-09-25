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
    min: 500, max: 1100,
    perCall: 2,
  },
  'primary-6': {
    learner: 'pupils',
    tone: 'clear upper primary English. Practical Nigerian examples, simple explanations with one or two steps of reasoning.',
    min: 550, max: 1200,
    perCall: 2,
  },
  'jss-3': {
    learner: 'students',
    tone: 'junior secondary classroom English. Define terms, explain step by step, give Nigerian examples, then check understanding.',
    min: 650, max: 1300,
    perCall: 1,
  },
  'sss-3': {
    learner: 'students',
    tone: 'senior secondary classroom English. Exam aware to WAEC and NECO standard. Define, explain with structure, work examples, then evaluate.',
    min: 700, max: 1500,
    perCall: 1,
  },
  'nursery-1': NURSERY_BAND,
  'nursery-2': NURSERY_BAND,
  'nursery-3': NURSERY_BAND,
  'primary-1': {
    learner: 'pupils',
    tone: 'very simple primary one classroom English. Very short sentences, songs, real objects, counting and pointing games. The teacher reads the note aloud.',
    min: 350, max: 800,
    perCall: 2,
  },
  'primary-2': {
    learner: 'pupils',
    tone: 'very simple primary two classroom English. Short sentences, everyday Nigerian examples like the market, kerosene stove, danfo and naira.',
    min: 400, max: 900,
    perCall: 2,
  },
  'primary-4': {
    learner: 'pupils',
    tone: 'clear middle primary English. Practical Nigerian examples, simple explanations with one step of reasoning.',
    min: 500, max: 1100,
    perCall: 2,
  },
  'primary-5': {
    learner: 'pupils',
    tone: 'clear upper primary English. Practical Nigerian examples, simple explanations with one or two steps of reasoning.',
    min: 550, max: 1200,
    perCall: 2,
  },
  'jss-1': {
    learner: 'students',
    tone: 'junior secondary classroom English. Define terms, explain step by step, give Nigerian examples, then check understanding.',
    min: 650, max: 1300,
    perCall: 1,
  },
  'jss-2': {
    learner: 'students',
    tone: 'junior secondary classroom English. Define terms, explain step by step, give Nigerian examples, then check understanding.',
    min: 650, max: 1300,
    perCall: 1,
  },
  'sss-1': {
    learner: 'students',
    tone: 'senior secondary classroom English. Exam aware to WAEC and NECO standard. Define, explain with structure, work examples, then evaluate.',
    min: 700, max: 1500,
    perCall: 1,
  },
  'sss-2': {
    learner: 'students',
    tone: 'senior secondary classroom English. Exam aware to WAEC and NECO standard. Define, explain with structure, work examples, then evaluate.',
    min: 700, max: 1500,
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
- Length: between ${band.min} and ${band.max} characters for the whole block.
- Language level: ${band.tone}
- Never use an em dash, en dash or double hyphen anywhere. Use a single plain hyphen only inside compound words.
- Never mention that the note was generated or mention this instruction.

Answer with STRICT JSON only, no markdown fence, no extra fields, shaped exactly:
{"files":[{"key":"<the key given per file>","topics":[{"week":1,"title":"<topic title from the scheme>","content":"<the note block>"}]}]}
Do not echo the input weeks or any other field. Keep every content string on one JSON line with \\n escapes where a line break is needed.`;
}

function userPayload(files) {
  const body = files.map((f) => ({
    key: f.key,
    class: f.scheme.class,
    subject: f.scheme.subject,
    term: f.scheme.term,
    weeks: f.scheme.weeks.map((w) => ({ week: w.week, topic: w.topic, content: w.content })),
  }));
  return JSON.stringify({ files: body }, null, 1);
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

function validate(note, scheme, level) {
  const band = BAND[level];
  const byWeek = new Map(scheme.weeks.map((w) => [Number(w.week), w]));
  if (!Array.isArray(note.topics) || note.topics.length === 0) throw new Error('no topics');
  const seen = new Set();
  for (const t of note.topics) {
    const wk = Number(t.week);
    if (!byWeek.has(wk)) throw new Error(`unknown week ${wk}`);
    if (seen.has(wk)) throw new Error(`duplicate week ${wk}`);
    seen.add(wk);
    const src = byWeek.get(wk);
    const content = normalize(t.content);
    if (content.length < band.min) throw new Error(`week ${wk} too short (${content.length})`);
    if (content.length > band.max + 400) throw new Error(`week ${wk} too long (${content.length})`);
    for (const label of ['Behavioural objectives:', 'Content:', 'Evaluation questions:']) {
      if (!content.includes(label)) throw new Error(`week ${wk} missing "${label}"`);
    }
    if (DASHES.test(content) || /-{2,}/.test(content)) throw new Error(`week ${wk} long hyphen`);
    if (!t.title || !String(t.title).trim()) throw new Error(`week ${wk} no title`);
    // keep the scheme wording for the title, only normalized
    t.title = normalize(src.topic || t.title);
    t.content = content;
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

async function generateGroup(zai, group, level) {
  // the generation endpoint rate limits; back off and retry a few times
  // before giving the caller a real failure
  let lastErr;
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      return await generateGroupOnce(zai, group, level);
    } catch (e) {
      lastErr = e;
      const hit = /429|rate/i.test(e.message || '');
      if (!hit && attempt >= 1) throw e;
      await sleep(30000 * (attempt + 1) + Math.floor(Math.random() * 10000));
    }
  }
  throw lastErr;
}

async function generateGroupOnce(zai, group, level) {
  const reply = await zai.chat.completions.create({
    messages: [
      { role: 'assistant', content: systemPrompt(BAND[level]) },
      { role: 'user', content: userPayload(group) },
    ],
    thinking: { type: 'disabled' },
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
      return { file: f, ok: false, error: e.message };
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
      let results = [];
      try {
        results = await generateGroup(zai, g.files, g.level);
      } catch (e) {
        results = g.files.map((f) => ({ file: f, ok: false, error: e.message }));
      }
      // single-file retry for anything that failed
      for (let attempt = 0; attempt < 2; attempt++) {
        const failed = results.filter((r) => !r.ok);
        if (!failed.length) break;
        const retry = [];
        for (const f of failed) {
          try {
            retry.push(...(await generateGroup(zai, [f.file], g.level)));
          } catch (e) {
            retry.push({ file: f.file, ok: false, error: e.message });
          }
        }
        results = results.filter((r) => r.ok).concat(retry);
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
      if (my % 5 === 0 || my === groups.length - 1) saveCheckpoint(cp);
    }
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
