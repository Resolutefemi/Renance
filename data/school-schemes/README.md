# School schemes corpus

Week-by-week schemes of work harvested for the school platform, one
JSON file per class + subject + term.

- Source: `classbasic.com` (robots.txt allows every crawler; the site
  serves mobile browsers, so the harvester presents a mobile UA that
  still carries the Renance contact string). Every week row keeps its
  source URL.
- Shape: `{class, subject, term, weeks: [{week, topic, content}],
  provenance}` where `content` holds the content bullets printed under
  that week.
- Pour: `scripts/pour_school_schemes.py` posts each file to
  `POST /school/bulk-schemes`. The endpoint drafts the term scheme only
  where it is still empty (or on explicit overwrite) and upserts every
  week's bullets as topic seeds, so re-pouring never clobbers teacher
  edits.
- The founder content rule holds: no long hyphens anywhere; the
  harvesters normalize every text field.
