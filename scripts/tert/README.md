# Tertiary content pipeline (curated-v3)

Rebuilds all 3,908 tertiary courses (594,016 units) with lesson notes of
250 to 400 words per note (10 notes per unit), straight-to-the-point
teaching content, and the standard 20-item quiz per unit.

## Layout
- `packs/` — 21 discipline packs: unit topics, atoms, examples/apps/traps
  and the verified quiz factories (all arithmetic checked before keying).
- `router.py` — maps every course to its discipline pack.
- `spec.py` — deterministic RNG, subject phrases, option balancing.
- `gen/` — the lesson generation farm:
  - `essay_gen.py` — prompt + parser + post-processor (the model writes a
    10-section teaching essay; JSON mode suppresses length, essay mode does not)
  - `farm.py` — resumable farm: validate + feedback retries + rescue pass
  - `validate_lesson.py` — founder rules: 10 notes, 250-400 words each,
    ASCII only, no "--", no tag-like "<", no exam-coaching language
  - `json_repair.py` — lenient JSON parsing (unescaped quotes, bad escapes)
  - `zai_client.py` — direct chat API client with 429 penalty ride-out
  - `make_tasks.py` — enumerates all 3,192 pack unit/foundation topics
- `build_all.py` — builds ladder rows + lesson blobs from generated lessons
  (skips packs that are not fully generated yet).
- `push_r2.py` — full shard push (GET-merge-PUT, one Class A PUT per shard,
  resume ledger `pack_done.txt`).
- `push_r2_wave.py` — incremental push for fully generated packs (own ledger
  `wave_done.txt`, merges new lessons into existing shard objects).

## Founder rules enforced by the validators
1. Exactly 10 notes per unit, each note body 250 to 400 words.
2. On-topic teaching only, no study-philosophy filler.
3. No exam/marks/revision coaching language.
4. No "--" anywhere; ASCII only; no tag-like angle brackets (the Flutter
   renderer parses them as HTML and swallows them).
5. Quiz: 20 items, balanced A-D answers, one-line explanations.

## Class A budget ledger
- Round 1 (60-105 word notes, superseded): ~26,345 PUTs spent.
- Wave pushes: ~600 PUTs per completed pack.
- Final full push: ~60,000 PUTs.
- Total ceiling: 150,000 Class A operations (founder line).
