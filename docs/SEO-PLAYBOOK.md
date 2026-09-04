# Renance SEO Playbook — How We Outrank "Renance" (and myschool.ng)

Written 2026-09-04, after shipping the lessons pipeline (#8) and tutor (#9).
This is the founder's battle plan: own the name **Renance** for education,
outrank the Web3 renance.io, and build myschool.ng-grade organic traffic.

## Why we can win

- **Different intent.** The other Renance sells Web3 real estate. Google
  separates results by INTENT: a student searching "JAMB past questions
  app" or "Renance lessons" is not their user. We do not need to beat
  them on their keywords — only on ours.
- **Name + niche.** Trademark Class 41 (education) + Class 42 (software)
  makes us the legal "Renance" for everything study-related. SEO follows
  the same logic: every page we publish reinforces "Renance = learning".
- **Content velocity.** They ship marketing pages; we ship a lesson
  pipeline (`cmd/mdx`) that converts markdown into a crawlable page in
  minutes. Volume + freshness is exactly how myschool.ng won.

## What shipped today (the technical base)

| Asset | Where | Why it matters |
| --- | --- | --- |
| Real landing page at `/` | `apps/web/app/page.tsx` | Was a JS splash-redirect — crawlers saw nothing. Now a static hero + features + coverage + lesson previews. |
| `/lessons` + `/lessons/[slug]` | `apps/web` | Build-time static pages from `data/lessons/*.json`, each with Article JSON-LD, canonical URL, OG tags. This is the programmatic SEO engine. |
| `/subjects` | `apps/web` | Public syllabus coverage index (JAMB/WAEC/NECO/University trees + topic counts) — the "we cover everything" proof page. |
| `/faq` | `apps/web` | 8 real questions + FAQPage JSON-LD → eligible for rich results. |
| Sitemap v2 | `app/sitemap.ts` | Auto-includes every lesson slug from the same commit — content and sitemap can never drift. |
| Structured data | root layout | Organization + SoftwareApplication + WebSite graph (founder as author). |
| Fixed silent bug | `globals.css` | `bg-card` had no token — every card was rendering transparent to crawlers AND users. Now `#FFFFFF`. |

## The 6-month plan (in priority order)

### 1. Programmatic SEO: one page per exam × subject × year

myschool.ng's moat is 10,000+ pages like "JAMB Biology 2019". Our loader
for the founder's 8,679 real questions is `qbuild` — the moment they are
loaded, each paper becomes:
- a practice page (app), and
- a public preview page (web): question count, topics, year, " practise
  this paper" CTA into the app.

**Target:** 8,679 questions ≈ 100+ public paper pages. Long-tail traffic
("jamb biology 2019 question 12 explanation") has almost zero
competition and perfect intent.

### 2. Lessons: 3 → 100, one per syllabus topic

Every syllabus node in `data/syllabus/*.json` is a lesson waiting to be
written. The pipeline is one command:

```bash
go run ./apps/study-api/cmd/mdx build   # markdown → data/lessons/ → site + app
```

Rule: **one lesson per topic, 400–800 words, front-matter filled, built
and committed.** The sitemap and app library pick it up automatically.

### 3. Branded keywords (the name war)

- Every page title carries "Renance" (the `%s · Renance` template does this).
- Target long-tail branded queries first: *Renance learning*, *Renance
  CBT*, *Renance lessons* — win them in weeks, then the bare name splits.
- Publish the founder story (DESIGN-BRIEF name placeholder!) on `/` —
  "built by Resolute Femi" is already in our JSON-LD; it makes the brand
  entity unambiguous to Google's knowledge graph.

### 4. Backlinks (domain authority)

- **GitHub**: repo links to the Pages site (dozens of organic links from
  every fork/stargazer share). Already live.
- **Student communities**: Nairaland, r/NigerianStudents, JAMB/WAEC
  Telegram groups — share a free lesson URL (never the root domain;
  deep-link lessons so the linked page ranks).
- **EdTech directories & blogs**: pitch "offline-first CBT app built by
  a FUTA engineer" — product hunt, alternativeTo, edtech blogs.
- Each published lesson gets a "cite this" anchor — other sites quoting
  lessons is the compounding link type.

### 5. Engagement signals (dwell time)

The app itself is the SEO weapon once users arrive: lessons keep students
reading (minutes), papers keep them solving (tens of minutes), streaks
bring them back daily (returning-visitor signal). Google reads
returning-visitor rate and dwell as quality — a study OS beats a
marketing site on both by design.

### 6. Technical checklist (keep green)

- [x] sitemap.xml auto-covers new content
- [x] robots.txt allows all public pages
- [x] canonical URLs on every page (basePath-aware)
- [x] Article/FAQ/Organization JSON-LD
- [x] mobile-first responsive (the app IS mobile-first)
- [x] static export — sub-second loads on GitHub Pages
- [ ] custom domain (renance.app / renance.ng) → 301 the Pages URL
- [ ] Google Search Console + Bing Webmaster verification after domain
- [ ] OG image per lesson (auto-render from title once design allows)

## Domain strategy

Priority order, matching the founder's budget and the trademark:
1. **renance.app** — exact product type (an app), cheap (~$15–20/yr), zero
   trademark risk in our class.
2. **renance.ng** — local SEO authority for Nigeria (where the students
   are), strong trust signal. `renance.edu.ng` if available through a
   school affiliation — the .edu.ng TLD itself carries weight.
3. **renance.ai** — only if planning AI-forward branding; expensive.
4. **renance.com** — parked by a broker; do NOT pay ransom now. After
   Class 41/42 trademark registration + traffic growth, our position
   improves; revisit post-funding.

## Trademark (do this before spending on ads)

Register **Renance** in **Class 41** (education, training services) and
**Class 42** (SaaS/software) in Nigeria first (~₦15k–30k per class via
the Trademarks Registry), then Madrid Protocol later if going global.
This is the shield that makes our SEO victory legally permanent — the
other Renance cannot force a takedown of the education brand we own.

## Measurement

- After Search Console is live: track queries containing "renance" vs
  generic JAMB/WAEC queries weekly.
- Target in 90 days: bare-name search shows renance.io AND our Pages
  site on page 1; in 180 days: we hold 2+ of the top 5 education-intent
  results ("renance lessons", "renance study", "renance jamb").
- Every lesson page is a rankable asset — the scoreboard is "pages
  indexed" in Search Console. 100 indexed lesson/paper pages beats any
  amount of meta-tag tuning.
