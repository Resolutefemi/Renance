# NEET — sources & harvest notes

| Source | Type | Status |
|---|---|---|
| byjus.com/neet/neet-question-paper/ | year-wise PDFs (papers, official NTA keys, solutions) | 2021 HARVESTED (198 q -> NEET/{physics,chemistry,botany,zoology}.json); other years cataloged |

byjus retired its NEET MCQ section (redirects to GATE); previous-year PDFs are the free content.
Pipeline: column-aware pdfplumber extraction + token-pair NTA key parser (scripts/research/neet2021_parse.py).
Answers are INLINE (official NTA key letters); sanitized at API boot.
