# Renance Web — SEO Playbook

Standing requirement from the founder: the **public** web surface must rank hard.
This checklist governs every PR touching `apps/web`. Foundation is Next.js 15
App Router = server-first rendering, which search engines index cleanly.

## Non-negotiables on every public page
- [ ] Metadata API used (`export const metadata`) — title template
      `%s · Renance`, unique description, canonical URL via `alternates`.
- [ ] `metadataBase` set once in root layout — prevents wrong-host OG links.
- [ ] OpenGraph + Twitter card tags (image comes with Phase 2 brand pass).
- [ ] Semantic HTML first: one `<h1>`, real landmarks (`header/main/footer`),
      descriptive link text. No click-divs.
- [ ] Route renders server-side or SSG — interactive shells stay hydratable,
      content must not depend on client JS.

## Site-level artifacts (present since bootstrap)
| File | Purpose |
|------|---------|
| `app/robots.ts` | allows all crawlers, blocks `/console/*` (private surface), points to sitemap |
| `app/sitemap.ts` | generated from a single ROUTES registry — add public routes there only |

## Structured data
- JSON-LD per entity page as they ship (Phase 2): `Organization`,
  `WebSite` (+ SearchAction), `Course`/`Exam` for CBT listings,
  `BreadcrumbList` on nested pages.

## Performance = ranking (Core Web Vitals)
- Images: always `next/image`, sizes+priority explicit, AVIF/WebP default.
- Fonts: `next/font` self-hosted subsets; zero layout shift.
- Budget: LCP < 2.5s · INP < 200ms · CLS < 0.1 — verify in PageSpeed before merge.

## Hygiene rules
- Public marketing/landing/blog routes: indexable. Admin console `/console/*`:
  `robots: { index: false }` + session-gated anyway.
- No thin pages: anything reachable needs ≥1 screen of real content.
- Canonical discipline: query-param variants point at the clean URL.
- hreflang arrives with any multi-locale push (not yet scheduled).
