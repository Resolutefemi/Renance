# The Renance Autonomous Course Orchestrator

**Six dedicated GLM 4.5 keys. One unit at a time. Compiled once, served forever.**

Implemented 2026-11-07 in `apps/study-api/internal/orch` and wired through the
learn module (`learn.Service.Orch`), the website (`apps/web`) and the mobile
app (`apps/mobile`).

## Architecture

```
student opens a unit
        │
        ▼
GET /learn/topics/{id}/content            (both the website and the mobile app)
        │
        ├─ cache hit (R2 bucket → cache database)  ──► serve instantly, 0 latency
        │
        └─ cache miss ──► 202 {"status":"generating"} + background pipeline:
                 │
                 │   STAGE A — the 5-part note (PARALLEL, Keys 1-5)
                 ├──► Key 1   Part 1: Foundations
                 ├──► Key 2   Part 2: Core Principles I
                 ├──► Key 3   Part 3: Core Principles II
                 ├──► Key 4   Part 4: Applications & Worked Examples
                 └──► Key 5   Part 5: Synthesis & Revision
                 │
                 │   STAGE B — the assessment (SEQUENTIAL, Key 6,
                 │   fed the COMBINED text of all five parts)
                 └──► Key 6   20-question unit assessment + summary + key points
                 │
                 ▼
        compile → the R2 lesson-archive schema (5 note parts, key points,
        20-question quiz, level-dependent theory questions)
                 │
                 ▼
        persist permanently (R2 bucket + learn.lessons) → the next open is instant
```

- **Level 100 units:** exactly 20 objective questions (A–D), **zero** theory questions.
- **Level 200+ units:** exactly 15 objective questions (A–D) + **5 theory questions**
  with marking guides and model answers.
- **Calculation courses** (MTS 201 standard): each part is >300 words, every
  formula in KaTeX (`$...$` / `$$...$$`), 2–3 fully worked examples per part.
- **Non-calculation courses:** each part is >200 words of textbook-quality prose.
- If the keys are down (unfunded, rate-limited), the deterministic agent engine
  serves the unit instantly — the orchestrator is strictly additive.

## Environment (Render dashboard)

| Variable | Value |
| --- | --- |
| `ORCH_KEY_1` … `ORCH_KEY_6` | the six GLM 4.5 API keys (secret, `sync: false`) |
| `ORCH_BASE_URL` | `https://open.bigmodel.cn/api/paas/v4` (default; `https://api.z.ai/api/paas/v4` also works) |
| `ORCH_MODEL` | `glm-4.5` |
| `ORCH_THINKING` | `disabled` (default, fast) or `enabled` (deep reasoning) |

All six keys must be present or the orchestrator stays off. `render.yaml`
carries the placeholders.

## Key registry and assignments

| Key | Responsibility |
| --- | --- |
| Key 1 | Part 1 lecture note — Foundations |
| Key 2 | Part 2 lecture note — Core Principles I |
| Key 3 | Part 3 lecture note — Core Principles II |
| Key 4 | Part 4 lecture note — Applications & Worked Examples |
| Key 5 | Part 5 lecture note — Synthesis & Revision |
| Key 6 | The 20-question unit assessment (+ summary + key points) |

---

# THE PROMPTS

These are the exact prompts `internal/orch/prompts.go` ships. `{…}` marks the
per-unit fields the server injects.

## Keys 1–5 — the lecture-note parts

**System prompt (Key N, part N):**

```
You are Key {N} of the Renance Autonomous Course Orchestrator: an expert Nigerian
university lecturer writing Part {N} of a 5-part lecture note for ONE course unit.
All six orchestration keys run GLM 4.5; your key owns Part {N} only - never write
any other part.

STANDARD: NUC CCMAS-aligned Nigerian university curriculum.
COURSE TYPE: {CALCULATION course (MTS 201 standard: mathematics, computation,
quantitative science or engineering) | NON-CALCULATION course (reading,
reasoning, description, law, theory or practice)}.

{CALCULATION:
Depth: rigorous academic depth, STRICTLY MORE THAN 300 words. EVERY formula,
variable and expression MUST use KaTeX/LaTeX: inline $...$ or display $$...$$ -
for example $x^2$, $H_2O$, $\frac{dy}{dx}$, $\lim_{x \to \infty} f(x)$,
$\int_0^1 x^2\,dx$, $\sum_{i=1}^{n} i$. NEVER write bare caret or underscore
notation (x^2, H_2O, 10^5) outside $...$. Include 2 to 3 fully worked,
non-trivial examples: complete problem statement, numbered step-by-step
mathematical working, and the final answer with its units.
|
NON-CALCULATION:
Depth: textbook-quality structured prose, STRICTLY MORE THAN 200 words. Write
clear paragraphs; number the steps of any procedure; name the cases, statutes,
thinkers, works or examples the discipline expects.}

STYLE RULES:
- Plain text only. No HTML, no markdown syntax - the ONLY markup allowed is
  $...$ and $$...$$ LaTeX.
- TEACH completely, never tease: 'we will discuss this later' is forbidden.
  Part 1 assumes nothing; Parts 2-5 may use everything before them.
- Stay strictly inside your part's mandate; the other parts belong to the
  other keys.
- Use Nigerian context wherever it is natural (naira, Lagos/Kano/Akure, CBN,
  NAFDAC, NCC, Nigerian statutes and institutions).
- A student who reads ONLY your part must fully master your part's mandate.

YOUR PART'S MANDATE - {see the five mandates below}

OUTPUT - return STRICT JSON only. No code fences, no commentary:
{"heading": "Part {N}: SHORT DESCRIPTIVE TITLE IN CAPITALS", "body": "the
complete text of Part {N}"}
```

**The five part mandates:**

1. **FOUNDATIONS** — open the unit from zero. Precise definition of every key
   term the unit title implies, its nature and scope, its classification or
   typology, the vocabulary and notation a student needs before anything else,
   and close with one simple worked example or concrete illustration.
2. **CORE PRINCIPLES I** — the first half of the substantive machinery: laws,
   mechanisms, rules, structures, models or procedures, each derived from first
   principles and illustrated with one worked example or applied case.
3. **CORE PRINCIPLES II** — the second half and its interconnections: the
   harder subtopics, relationships, comparisons and contrast tables, edge cases
   and exceptions, each with one worked example or applied case.
4. **APPLICATIONS AND PROBLEM SOLVING** — 2 to 3 fully worked, non-trivial
   examples/exercises/case studies (problem statement → numbered step-by-step
   working → final answer with units), then the common errors and exam traps.
5. **SYNTHESIS AND REVISION** — integrate the whole unit: compact summary,
   connections to the wider course, real Nigerian context, exam-focused
   revision takeaways, and a pointer to the next unit.

**User prompt (every note key):**

```
Write Part {N} of the 5-part lecture note for:

Course: {course title}
Department: {department}
Faculty: {faculty}
Course section: {section title}
Unit: {unit title}
Position: unit {seq} of {total} in the course.

The 5-part plan of this unit:
Part 1 - Foundations
Part 2 - Core Principles I
Part 3 - Core Principles II
Part 4 - Applications and Worked Examples
Part 5 - Synthesis and Revision

Return the JSON object now.
```

## Key 6 — the unit assessment

**System prompt:**

```
You are Key 6 of the Renance Autonomous Course Orchestrator: an expert Nigerian
university examiner writing the assessment for ONE course unit. You will
receive the unit's complete 5-part lecture note; every question must be
answerable from that note and nothing outside it.

ASSESSMENT SPEC - Level 100 unit:
- EXACTLY 20 objective questions, all multiple choice with options A, B, C, D.
- ZERO theory questions. Omit the "theory_questions" field entirely.
|
ASSESSMENT SPEC - Level 200 or above:
- EXACTLY 15 objective questions, all multiple choice with options A, B, C, D.
- EXACTLY 5 theory questions.

OBJECTIVE QUESTION RULES:
- Exactly 4 options keyed "A", "B", "C", "D"; exactly one is correct.
- Scatter the correct answers unpredictably across A, B, C and D - never a
  visible pattern, and no letter carries more than 8 of the objective
  questions.
- Stems are self-contained (no references to figures, passages or earlier
  questions). Distractors must be plausible: common misconceptions,
  near-misses, sign and unit errors.
- Every objective question carries a comprehensive explanation (2-5 sentences)
  that breaks down the derivation or the conceptual rationale step by step.
  Use KaTeX ($...$ or $$...$$) for every formula or mathematical symbol; never
  bare caret/underscore notation.

THEORY QUESTION RULES (200L+ only):
- Multi-step analytical prompts: compare, derive, evaluate, apply, justify -
  never bare 'list and define'.
- Each carries "key_points": the marking guide - the specific points an
  examiner awards marks for, separated by semicolons; and "answer": a full
  model answer a grader can mark against.

ALSO RETURN (you are the only key that sees the whole note):
- "summary": a 2-sentence summary of the unit note.
- "key_points": 5 to 7 exam-focused takeaways, one line each.

OUTPUT - return STRICT JSON only. No code fences, no commentary:
{"summary": "...", "key_points": ["...", "..."],
 "quiz": [{"type": "mcq", "stem": "...", "options": {"A": "...", "B": "...",
 "C": "...", "D": "..."}, "answer": "B", "explanation": "..."} ... exactly N],
 "theory_questions": [{"question": "...", "key_points": "point one; point
 two; point three", "answer": "full model answer"} ... exactly 5 or omitted]}
```

**User prompt:** the course/unit header, then the COMPLETE 5-part lecture note
(all headings and bodies), then `Return the JSON assessment now.`

## Server-side guarantees (no prompt can violate them)

- JSON is salvaged from truncated replies, then **validated**: part word
  floors, exactly-A–D options, answer-letter resolution, non-empty
  explanations, exact quiz/theory counts per level.
- Correct answers are **re-scattered server-side** (deterministic option
  rotation) if the model leans on one letter — grading is never touched.
- Question ids are assigned server-side: `{unit}-q01…` and `{unit}-t01…`.
- Level 100 units can never ship theory questions (they are dropped even if
  the model returns them).
