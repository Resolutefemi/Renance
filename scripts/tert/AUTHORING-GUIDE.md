# Renance Tertiary Pack Authoring Guide (binding)

You are authoring a discipline pack module for Renance's tertiary course content engine.
Read this fully. The exemplar is `/home/z/my-project/scripts/tert/packs/computing_python.py`
(read its first 150 lines for tone and format before writing).

## What the pack becomes
Each of ~3,900 Nigerian university/polytechnic/college courses gets 152 units. Section 1
(12 units) keeps real syllabus topics. Sections 2-15 (14 sections x 10 units) come from
YOUR pack: for every course routed to your discipline, its 14 sections take your titles,
its 140 unit topics take your unit strings, and every unit's lesson (10 note paragraphs
+ 20 quiz items) is assembled from your atoms, examples, apps, traps and quiz factories.

## File you create
`/home/z/my-project/scripts/tert/packs/<pack_name>.py`

Module contract (exact names):
```python
SECTIONS = [S2, S3, ..., S15]      # exactly 14 dicts, in teaching order
FOUNDATIONS = [f1, ..., f12]       # exactly 12 strings
```

Each section dict:
```python
S2 = {
    "title": "Section title shown to every course in this discipline",
    "units": [10 unit topic strings],
    "atoms": [10-12 note paragraphs],
    "examples": [2-3 worked-example paragraphs],
    "apps": [2-3 application paragraphs],
    "traps": [2-3 common-errors paragraphs],
    "quiz": [>= 22 quiz tuples],
}
```

## The {S} slot
`{S}` is replaced at build time by the course's subject phrase, e.g. "Python programming",
"cost accounting", "human nutrition and dietetics". Use it inside atoms/examples/apps/traps
and quiz stems so the same section serves every course of the discipline. Write sentences
that read naturally with ANY reasonable subject phrase: "In {S}, ...", "... central to {S}".
Never put `{S}` inside quotes or at a position needing capitalisation.

## Atom-to-unit alignment (CRITICAL)
`atoms[i]` is the PRIMARY paragraph for `units[i]`: it must teach exactly that unit's topic.
Write atoms in unit order. Atoms 10-12 (if present) are spare paragraphs rotated into
later notes. So each section needs 10 on-topic atoms, one per unit, plus 0-2 spares.

## Quality bar (this is what separates us from the junk the founder deleted)
- Every paragraph TEACHES the discipline: real definitions, real mechanisms, real named
  examples, real numbers. A lecturer of that subject would nod.
- Nigerian classroom context where natural (Naira and kobo, Lagos/Kano/Enugu, NUC CCMAS,
  JAMB/WAEC, Ghana-Nigeria trade, NNPC, CBN) - never slang, never forced.
- ZERO filler about "studying" in the abstract: no "definitions come first in every serious
  study", no "this section fixes the vocabulary", no philosophy-of-learning sentences.
  Every sentence must carry subject facts.
- No cross-discipline contamination: medical packs never talk code; computing packs never
  talk specimens.
- Words per atom: 60-95. One paragraph, one idea, plain text, no newlines, no markdown,
  no emoji, no unicode math symbols (write x, 7.5 percent, ^ or spelled-out powers).
- Quiz stems: standard exam register. Explanations: 1-2 sentences citing the rule.
  Distractors = the most likely student slip, never silly. For numeric items, VERIFY the
  arithmetic with real Python before writing the tuple.
- Unit titles: concrete facets, <= 12 words, no "Overview of", no "Meaning, scope and
  importance of", no "and its place in", no "Revision focus on". Vary openings.
- Section titles: specific to the discipline ("Pharmacology of the Autonomic Nervous
  System"), never generic ("Key Concepts and Vocabulary").

## Quiz tuple format (exactly 5 elements)
```python
("mcq", "stem text", "correct option", ["slip1", "slip2", "slip3"], "explanation"),
("tf",  "statement to judge.", "True", ["False"], "explanation"),
("fill", "Fill: the keyword is ____.", "answer", ["answer"], "explanation"),
```
- mcq: exactly 3 slips, all strings, all distinct from correct and each other.
- tf: statement form, correct is "True" or "False", slips is [the opposite].
- fill: the blank written as ____ (four underscores); slips repeat the answer.
- Mix per section: about 15-17 mcq, 3-4 tf, 2-3 fill. Stems must not contain newlines.
- At least a third of items must be application/case/computation, not pure recall.

## FOUNDATIONS
12 real foundation-level topics of the discipline (first-semester territory), used to
replace junk titles in section 1 of routed courses. Same style rules as unit titles.

## Self-check before you finish (MANDATORY)
Run:
```
cd /home/z/my-project/scripts && python3 tert/pack_check.py <pack_name>
```
Fix every reported problem until it prints PACK OK. Then append one line to
/home/z/my-project/worklog.md starting with "---" describing the pack (do not overwrite
the file; append only).
