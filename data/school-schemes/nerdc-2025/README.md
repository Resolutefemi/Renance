# NERDC 2025 Scheme of Work Corpus (Nursery 1 to SSS 3)

The pourable scheme of work corpus for every level the Renance school
portal supports, from pre-primary (Nursery 1) through SSS 3. Every file
carries the shape the `POST /school/bulk-schemes` endpoint consumes:

```json
{"class": "Nursery 1", "subject": "Letter Work", "term": 1,
 "weeks": [{"week": 1, "topic": "...", "content": "..."}]}
```

Pour any file into a registered school with:

```bash
python3 scripts/pour_school_schemes.py data/school-schemes/nerdc-2025/nursery/nursery-1/letter-work-term1.json
```

## Levels and coverage

| Folder | Class | Subjects | Files |
| --- | --- | --- | --- |
| `nursery/nursery-1` | Nursery 1 | 9 | 27 |
| `nursery/nursery-2` | Nursery 2 | 9 | 27 |
| `nursery/nursery-3` | Nursery 3 | 9 | 27 |
| `primary-3` | Primary 3 | 9 | 27 |
| `primary-6` | Primary 6 | 10 | 30 |
| `jss-3` | JSS 3 | 12 | 36 |
| `sss-3` | SSS 3 | 14 | 42 |

Each subject carries three terms of ten weeks (week by week topic plus
content bullets), matching the standard Nigerian three term session.
Nursery counts as pre-primary even though many schools group it under
primary school; the corpus treats it as its own block so early years
teachers pour exactly what they teach.

## Nursery subjects

Letter Work, Number Work, Rhymes, Social Habits, Health Habits, Basic
Science and Discovery, Creative Arts, Moral Instruction, Handwriting.

## Regenerating the corpus

The corpus is generated from the data modules in `scripts/schemes/`:

```bash
python3 scripts/schemes/gen_scheme_nursery.py     # nursery 1 to 3
python3 scripts/schemes/gen_scheme_secondary.py   # pry 3, pry 6, jss 3, sss 3
```

The generator scrubs long hyphens on the way out, per the founder rule.

## Source note

The structure follows the NERDC national curriculum (9-Year Basic
Education plus Senior Secondary) as published on the NERDC new
curriculum portal and in the 2025 scheme of work compilations. The
next pass will splice in the exact week by week text from the uploaded
source PDFs page for page; until then every topic line here is aligned
to the official curriculum scope for the level and subject.
