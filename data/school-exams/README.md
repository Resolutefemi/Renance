# School exams corpus

Per-term examination objectives harvested for the school question
bank, one JSON file per class + subject + term.

- Source: `classbasic.com` first/second/third-term examination pages
  (robots.txt allows every crawler). SECTION A multiple-choice items
  only; the theory sections are left to teachers.
- Shape: `{class, subject, term, band, questions: [{question, options,
  answerIndex, source, sourceUrl}], provenance}`.
- The source publishes no answer keys, so every question ships
  `answerIndex: -1`. The bulk endpoint stores it and the portal marks
  such rows "Key pending" until a teacher sets the key; nothing
  auto-grades them.
- Pour: `scripts/pour_school_exams.py` posts each file (chunked at the
  endpoint's 500-question cap) to `POST /school/bulk-exam-questions`.
  Rows dedupe on question text server-side, so re-pouring a growing
  corpus never duplicates.
- The founder content rule holds: no long hyphens anywhere.
