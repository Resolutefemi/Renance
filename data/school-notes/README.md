# data/school-notes - the school note corpus

This folder holds the topic corpora poured into school syllabuses through
the `POST /school/bulk-notes` endpoint. Two kinds of content live here:

## 1. starter/ - Renance original seed notes

Hand-written summaries keyed to the official NERDC scheme of work.
`source: renance-nerdc-seed`. This content is ours: short, factual,
classroom-ready, with evaluation questions. It gives every new school a
working note library from day one.

## 2. classnotes/ and flashlearners/ - harvested notes

Produced by `scripts/scrape_school_notes.py` from free Nigerian K-12 note
sites. Legal doctrine:

- robots.txt is fetched and honored at runtime; disallowed paths are never
  requested
- crawl is single-threaded with a 1.2s delay and a self-identifying
  User-Agent carrying a contact email
- every topic keeps its `source` and `sourceUrl` (per-topic attribution)
- only publicly readable lesson pages are fetched; no login-walled or
  paywalled content
- notes are normalized (plain text, no long hyphens) and meant as study
  aids credited to the source, not as a wholesale replacement for the
  original site
- a source owner who objects can be dropped from the adapter list in one
  line; keep `sourceUrl` intact so provenance is always auditable

## File shape

One file per class + subject + term, matching the bulk-import body:

```json
{
  "class": "JSS 1",
  "subject": "Basic Science",
  "term": 1,
  "session": "",
  "overwrite": false,
  "provenance": { "source": "...", "method": "..." },
  "topics": [
    { "title": "...", "week": 1, "content": "...", "source": "...", "sourceUrl": "..." }
  ]
}
```

`overwrite: false` only fills topics whose content is still empty, so
re-pouring never clobbers a teacher's edits. Set `overwrite: true` for a
full refresh of a topic block you own.

## Pouring

```bash
export RENANCE_SCHOOL_EMAIL=management@yourschool.ng
export RENANCE_SCHOOL_PASSWORD=...
python3 scripts/pour_school_notes.py data/school-notes/starter/jss1-basic-science-term1.json
```

## 3. nerdc-2025/ - lesson notes written from the scheme corpus

One note file for every scheme file in `data/school-schemes/nerdc-2025`,
covering Nursery 1 to SSS 3 across all three terms. Produced by
`scripts/generate_school_notes.mjs`: the script hands each scheme outline
(class, subject, term, weekly topics and content bullets) to the
classroom writer and stores the note in the same relative path as its
scheme, so every note traces straight back to its scheme of work.

Each topic keeps the standard Nigerian lesson note frame: behavioural
objectives, an introduction, the content expanded from the scheme
bullets with Nigerian everyday examples, a class activity, evaluation
questions and a summary. Tone follows the level band: nursery notes are
play way with very short sentences, primary notes stay simple, junior
and senior secondary notes define, explain, work examples and evaluate
with WAEC and NECO awareness in the senior band.

Regenerate or extend with:

```bash
node scripts/generate_school_notes.mjs                  # everything missing
node scripts/generate_school_notes.mjs --level jss-3    # one level
```

The writer is resumable (a checkpoint file tracks finished files) and
enforces the no-long-hyphen rule on every field before writing.

The API enforces the no-long-hyphen rule server-side as well
(`normalizeHyphens` in school_setup.go), so imported content cannot break
the founder content rule.
