# BECE — Basic Education Certificate Examination (data area)

BECE sits at the end of junior secondary (JSS3): a student who passes it
moves to SS1. It is NOT one national paper — every state runs its own BECE
through its Ministry of Education / examinations board, while NECO runs the
National BECE for Federal Unity Colleges. That is why this folder is a
top-level entity beside `JAMB/`, `WAEC/`, `NECO/`, `POST_UTME/`: it has no
single owner and no single question body.

## What is here

| file | what it is |
|------|------------|
| `state_catalog.json` | All 36 states + FCT: administering body (confirmed vs expected), CBT status, public past-question sources found by the research sweep. Confirmed boards so far: Lagos (LASEB), Kaduna (KSSQAA — the only state running a Hybrid CBT BECE, 2026 Phase II pilot), Benue (BEQAEB). Every unconfirmed value is flagged `confirmed: false`. |
| `national/bece-english-flashlearners.json` | 17 national BECE (Junior WAEC) English sample questions harvested from flashlearners.com. Only 1 carries a confirmed key — harvest-grade source material, NOT yet a gradeable bank. |

## Why there is no per-state question bank yet

State BECE papers are rarely published free; tutors sell compiled PDFs
(samphina/Selar funnel is paid). The resumable per-state sweep lives at
`scripts/research/legacyGabriel/bece_state_sweep.py` (waits for the search
quota, then 2 queries × 37 states, auto-downloads free PDFs it finds). When
it completes, re-run `build_bece_catalog.py` and ship gradeable banks into
`data/questions/BECE/` following the same shape as the JAMB banks
(`code`/`questions[]`/embedded `answer` + manifest re-seal).

## Kaduna signal (worth tracking)

Kaduna is the CBT mover: KSSQAA's Hybrid CBT pilot Phase II (2026) with an
optional mock CBT means a Kaduna-specific CBT practice surface is the most
defensible per-state product first.
