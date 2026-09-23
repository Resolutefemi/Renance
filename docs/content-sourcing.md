# Content Sourcing Doctrine

Renance ships study content in two channels: the candidate world (past
questions, lessons, flashcards) and the school world (syllabuses,
scheme of work, topics with notes, exam question banks). Every byte of
that content has a documented origin, and the rules below are not
optional. They are how the platform stays legal, credible and clean.

## 1. The house bank is original

The exam question bank seeds original, NERDC-aligned questions written
for Renance. They live in `apps/study-api/internal/school/exambank*.go`
and pour into each school with the "Pour starter bank" action on the
Exam Bank desk. Nothing in that bank is scraped, and every poured row
is tagged `renance-original` in the `source` column. Schools grow the
pool from the portal with their own questions, tagged
`school-original` by the API.

## 2. Harvested notes are credited, robots-aware and traceable

The weekly harvest (`scripts/scrape_school_notes.py`, wired to
`.github/workflows/note-harvest.yml`) only touches sites whose
robots.txt allows it, at one polite request per 1.2 seconds, with a
contactable user agent. Every topic keeps `source` and `sourceUrl`, so
a note printed in a classroom shows where it came from. The corpus
lands under `data/school-notes/<source>/` shaped exactly like the
`/school/bulk-notes` body, and `scripts/pour_school_notes.py` pours it
into a school.

### Active rotation

| Source | Status |
| --- | --- |
| flashlearners.com | active |
| edudelight.com | active (the classnotes alternative) |
| classnotes.ng | postponed, explicit `--source classnotes` only |

classnotes.ng was the original source. It is postponed by the founder's
call until its robots and permissions posture is re-checked; the
adapter stays in the codebase so the rotation can pick it up again
without new engineering.

## 3. The long-hyphen rule is enforced at every gate

No shipped content or note ever contains a long dash or a `--` run.
The guard is four layers deep:

1. `tools/cbt-build/sweep_hyphens.py` and `scripts/no_long_hyphen.py`
   clean the built corpus and CI checks the result.
2. The scraper normalizes Unicode dashes to a plain hyphen on ingest.
3. The bulk-notes import normalizes server-side.
4. The exam bank endpoints collapse `--` runs at write time
   (`internal/httpapi/textrule.go`).

## 4. When in doubt

A source that cannot answer "does robots.txt permit this, and can we
credit the page?" is not a source. Postpone it, keep the adapter if it
already exists, and grow the house bank instead.
