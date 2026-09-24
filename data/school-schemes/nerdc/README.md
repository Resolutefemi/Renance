# NERDC Curriculum Library (official Nigerian curriculum, scraped)

Every subject and class curriculum the Federal Government's NERDC publishes
on its new-curriculum portal, captured in one place.

Source of truth: <https://nerdc.gov.ng/content_manager/new_curriculum_home.html>
which hands off to the NERDC LMIS portal at
<https://lmis.nerdcportals.com.ng/>. Copyright stays with NERDC; this
library exists so schools on Renance get the national curriculum
pre-installed instead of retyping it.

## What is in here

| File | Contents |
| --- | --- |
| `pry_1.json` | Primary 1, 13 subject curriculums |
| `pry_2.json` | Primary 2, 12 subject curriculums |
| `pry_4.json` | Primary 4, 16 subject curriculums |
| `pry_5.json` | Primary 5, 9 subject curriculums |
| `jss_1.json` | JSS 1, 16 subject curriculums |
| `jss_2.json` | JSS 2, 10 subject curriculums |
| `sss_1.json` | SSS 1, 28 subject curriculums across Core, Science, Humanities, Business and Trades |
| `sss_2.json` | SSS 2, 20 subject curriculums across the same fields |
| `index.json` | One combined catalogue of all 124 documents (metadata only) |
| `plan.tsv` | The exact download ledger: file, level, label, subject, source URL |

Each document in a level file carries:

- `subject` - the NERDC subject (or senior-secondary field) name
- `sourceUrl` - the official PDF link on lmis.nerdcportals.com.ng
- `pages` - page count of the official PDF
- `outline` - best-effort THEME/TOPIC outline parsed from the PDF
- `text` - the full extracted text of the curriculum document

## Why Nursery is not here

The user brief asked for Nursery 1 to SSS 3. The NERDC LMIS portal does not
publish a nursery track: the new curriculum framework starts at Primary 1,
and early-childhood education stays under the state-level ECE guidelines.
The scrape therefore covers Primary 1 through SSS 2, which is the complete
set the official portal exposes (pry_3, pry_6, jss_3 and sss_3 are not on
the portal yet either; re-run the scraper as NERDC uploads them).

## Refreshing the data

```
python3 scripts/scrape_nerdc_curriculum.py plan > data/school-schemes/nerdc/plan.tsv
bash scripts/download_nerdc_pdfs.sh 8
python3 scripts/scrape_nerdc_curriculum.py extract
```

The raw PDFs (about 248 MB) are not tracked in git; they ship as a release
asset on this repository and re-download with the commands above.
