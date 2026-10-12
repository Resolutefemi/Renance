# Renance Security - the past-question vault shield

**Founder directive 2026-10-11:** *"Someone is trying to scrape all my
hard work past questions from renance-api.onrender.com. Make sure no
agentic AI can scrape my question. I need ultimate security for my
200,000+ past questions. Protect the website renance.app very well
from any hackers or scraper. I need ultimate security."*

This document is the operating manual for the shield that was built
for that directive: what each layer does, how to deploy it, how to
rotate keys, how to trace a leak, and how to take the protection to
the maximum (Cloudflare) tier.

---

## The seven layers

| # | Layer | Where | What it stops |
|---|-------|-------|---------------|
| 1 | **UA shield** | study API (`internal/httpapi/botshield.go`) | GPTBot, ClaudeBot, CCBot, Bytespider, PerplexityBot, python-requests, curl, Scrapy, headless browsers + every AI crawler UA is refused 403 before any handler runs. No UA at all = refused on question routes. |
| 2 | **robots.txt + noindex** | both properties | `Disallow: /` on the API; robots.txt on renance.app disallows `/bundles/`, `/pdfs/`, `/school-corpus/`, `/api/` and names 25+ AI crawlers individually; every response carries `X-Robots-Tag: noindex, nofollow, noarchive`. |
| 3 | **Static cipher** | renance.app build (`scripts/encrypt_bundles.mjs`) | Every `/bundles/<code>.json` on the CDN is **AES-256-GCM ciphertext keyed per bank code**. A scraper that mirrors the whole website gets 165 MB of useless ciphertext. (This closed the old hole where the site shipped 1,156 plain JSON files with answers.) |
| 4 | **Key gate** | study API `GET /bundles/key?code=` | One key per bank. Signed-in: **unlimited** (the per-account daily quota was removed 2026-10-11 on founder directive - students are never capped). Anonymous: **proof-of-work** (18-bit SHA-256, ~0.3 s of real hashing per bank) + per-IP hourly cap + global anonymous budget. `BUNDLE_ANON_KEY=false` removes the anonymous path entirely. |
| 5 | **Ledger** | study API | Honeypot strikes and lockouts tracked per account; scraping bursts and enumeration are logged (`event=botshield`) - the forensic trail on Render logs. (The daily distinct-bank counter was removed together with the quota.) |
| 6 | **Honeypots + canary** | study API | Ten decoy bank codes (listed in a planted `bundles/index.json` only an enumerator would read). Requesting one serves a **poisoned bundle of canary questions** (marker `RQ7C2ZP4`) and strikes the account; two strikes = 24-hour lockout. Any product that publishes the canary text is provably serving scraped Renance data. |
| 7 | **Watermarks** | study API (`/bundles/{code}`) | Every question stem served to a signed-in user carries an **invisible 16-bit HMAC signature of (account, question)** in zero-width characters. A leaked corpus - even one question - decodes back to the account that pulled it. |

Plus the pre-existing walls: JWT auth on every question route,
bcrypt+rate-limited auth, CORS allowlist, CSP, HSTS at the edge.

---

## Deploy (once)

The master secret is **32 bytes hex** (64 hex chars). It exists in
exactly three places and never in the repo:

1. **Render** (study API): dashboard → Environment →
   `BUNDLE_MASTER_KEY` = the value from
   `download/bundle_master_key.txt` (or generate with
   `openssl rand -hex 32`). Suggested env block is in `render.yaml`.
2. **Vercel** (renance.app build): Project → Settings → Environment
   Variables → `BUNDLE_MASTER_KEY` (same value),
   `BUNDLE_KEY_ID=k1`.
3. **Your password manager** (backup).

Then redeploy both (Render auto-deploys on push; Vercel redeploy from
dashboard). Verify:

```sh
curl -s https://renance.app/bundles/jamb-english-bank.json | head -c 120
# must show {"v":1,"kid":...,"ct":...}  (ciphertext, never plain JSON)

curl -s https://renance-api.onrender.com/robots.txt
# User-agent: * / Disallow: /

curl -A "GPTBot/1.0" https://renance-api.onrender.com/manifest
# {"error":{"code":"bot_shield",...}}  (403)
```

---

## Rotating the key

Set a new `BUNDLE_MASTER_KEY` + a new `BUNDLE_KEY_ID` (k2, k3, …) in
Vercel and Render, redeploy. Every cached key in students' browsers
is keyed with the kid, so clients refetch automatically. Old
ciphertext becomes undecryptable garbage the moment both deploys land.

---

## Tracing a leak (watermark decoder)

When a stolen question bank surfaces, take any question text the
account was served and decode:

```python
# decode_watermark.py - reverse of botshield.go watermarkStem
ZW = {"\u2060": "PRE", "\u2062": "POST", "\u200b": "0", "\u200c": "1"}
import hmac, hashlib, sys
stem = sys.stdin.read()
bits = ""
inside = False
for ch in stem:
    t = ZW.get(ch, "")
    if t == "PRE": inside = True; bits = ""
    elif t == "POST": break
    elif inside and t in "01": bits += t
sig = int(bits, 2).to_bytes(2, "big")
# then brute-force the account id against your user list:
#   hmac.new(WM_KEY, f"renance-wm/v1|{uid}|{qid}".encode(), hashlib.sha256).sum()[:2] == sig
# WM_KEY = HMAC-SHA256(BUNDLE_MASTER_KEY, "renance-watermark/v1")
```

The account that matches is the account that was served the leaked
question. Suspend it, check the Render logs for its fetch pattern
(`event=botshield`), and you have your evidence trail.

---

## Reading the botshield logs (Render → Logs)

```
event=blocked  ua=GPTBot...            # layer 1 refused an AI crawler
event=honeypot code=all-questions-dump user=u_123 strikes=2
event=quota    user=u_123 distinct=41 > 40
event=key      code=jamb-english-bank user=anon   # normal traffic
```

Alerting: pipe Render log drains into any notifier and flag
`honeypot` (always) and `quota` (volume spikes).

---

## Maximum tier: Cloudflare in front of renance.app (recommended)

The static site is now cipher-only, so the CDN layer is safe even
unprotected. For the strongest possible posture, proxy renance.app
through Cloudflare (free plan) and switch on:

1. **DNS proxy** (orange cloud) - hides the origin, absorbs L7 floods.
2. **Bot Fight Mode** (Security → Bots) - blocks headless/automated
   traffic before it reaches Vercel.
3. **WAF custom rules**:
   - `(http.user_agent contains "GPTBot")` → Block
   - `(http.user_agent contains "ClaudeBot")` → Block
   - `(starts_with(http.request.uri.path, "/bundles/") and not
      cf.threat_score lt 10)` → Managed Challenge
4. **Rate limiting rule**: `/bundles/*` > 60 requests/min/IP →
   Block 1 h.
5. **Cache Rule**: `/bundles/*` → Cache Everything (ciphertext caches
   perfectly, it is not secret-dependent).

Vercel stays the origin; only DNS/edge changes. Zero app changes.

---

## Private question API (`renance-api` repo)

The private JAMB/WAEC/NECO API (`Resolutefemi/renance-api`) carries
its own shield (same botshield design):
- `rk_live_` keys, SHA-256 at rest, constant-time compare
- per-key 600 rpm token bucket **plus a daily per-key request quota**
- AI-crawler UA blocklist + robots.txt
- honeypot routes serving canary questions, auto-strike
- answers behind the `allow_answers` privilege only

---

## What "ultimate" means honestly

Content that a browser displays can always be screenshotted by a
determined, logged-in human. What this shield guarantees:

- **No bulk static scraping** (the previous hole - closed with AES-256-GCM).
- **No AI crawler** (all known agents + robots.txt + noindex).
- **No anonymous enumeration** (PoW + IP caps + global budget).
- **No silent bulk theft via accounts** (90 keys/min speed cap,
  honeypot strikes, 24 h lockouts, per-account watermarks that survive
  into any re-published copy).
- **Detection and attribution** for anything that does leak: logs,
  canary questions, per-account watermarks.

That is the strongest practical posture for a public education
platform; a logged-in human transcribing questions one screen at a
time is the residual risk, and the watermark makes even that
traceable.

---

## Static asset shield, round 2 (2026-10-12)

**Founder directive**: "I told someone my past questions on the web
have no rate limit and can be scraped - is that true? If not work on
it... I just need ultimate security, no vulnerability or openings."

**Audit finding**: the question-bank JSON was already ciphertext, but
the `/pdfs/**` shelf (2,026 past-question PDFs, 322 MB) and
`/school-corpus/**` (1,127 NERDC scheme/note files) shipped PLAIN on
the CDN. Static hosting has no rate limit: `wget -r` took the whole
library in minutes. The claim was true for those two shelves.

**The fix** (same architecture as the bundle shield, one more asset
family):

- `scripts/encrypt_pdfs.mjs` rewrites every PDF + corpus file in place
  at build time as a binary envelope
  `RNP1 | kidLen u8 | kid | nonce 12B | AES-256-GCM ct+tag`, keyed per
  path: `HMAC-SHA256(master, "renance-static/v1|" + path)`. Fail-closed
  without `BUNDLE_MASTER_KEY`.
- Keys ride the SAME metered route:
  `GET /bundles/key?code=static:pdfs/futa/cos101.pdf`.
  - anonymous PDF key: 18-bit PoW + 12/IP/hour
  - anonymous corpus key (public curriculum surface): 14-bit PoW +
    120/IP/hour
  - signed-in: **speed cap only** - 90 key fetches/min per account
    (default, `BUNDLE_KEY_USER_PER_MIN`). The daily total cap stays
    REMOVED per the 2026-10-11 founder directive; speed != quota.
- `data/static_registry.json` (committed; the Docker image carries it
  via `COPY data/`) lists every protected path + 9 honeypot decoys.
  The Go API 404s unknown `static:` codes and strikes accounts that
  ask for decoys (2 strikes = 24 h lockout, same ledger as banks).
  The Vercel build FAILS (exit 3) if the walked file set drifts from
  the committed registry, so no asset can ever ship whose key the API
  would refuse. Regenerate after adding PDFs:
  `node scripts/encrypt_pdfs.mjs --refresh` + commit the registry.
- Web client: `lib/asset-crypto.ts` (WebCrypto decrypt, legacy plain
  fallback), `components/pdf-link.tsx` (shielded PDF button), corpus
  loads decrypt transparently. All three PDF surfaces converted
  (course desk, course practice, notes shelf).
- `vercel.json`: `X-Robots-Tag: noindex` on `/bundles/` and `/pdfs/`
  (matching `/school-corpus/`); PDF cache window tightened.

## Mobile anti-decompile hardening (2026-10-12)

**Founder directive**: "make sure nobody can decompile my mobile app
... mobile apps are easy to scrape than website."

Posture (verified this audit):

- **No question data ships in the binary.** The APK/AAB contains zero
  question assets (verified: `assets/` = brand images, fonts, NERDC
  schemes). Every question is served at runtime through the
  authenticated, watermarked, rate-limited API - decompiling the app
  yields no past questions at all.
- **Dart symbol obfuscation ON** (was missing): every CI release build
  (universal APK, per-ABI APKs, AAB) now passes
  `--obfuscate --split-debug-info=build/symbols/...`. A decompiler now
  sees mangled names with no class/method map; symbol maps stay in CI
  only for crash de-obfuscation.
- **R8 + resource shrinking ON** (already): `isMinifyEnabled` +
  `isShrinkResources` with `proguard-android-optimize.txt`.
- **Backup extraction closed**: `allowBackup=false` +
  `fullBackupContent` + `dataExtractionRules` refuse adb backup,
  cloud backup and device-to-device transfer of the app's data
  directory (session vault, cached data).
- **Cleartext off in release**: `usesCleartextTraffic=false` in the
  main manifest (production API is HTTPS-only); the debug-only
  manifest keeps localhost dev working.
- **Tokens in hardware-backed storage**: `flutter_secure_storage`
  (Android EncryptedSharedPreferences / iOS Keychain) - unchanged.

Residual honesty: no app is 100% un-decompilable; the point is that
decompiling now yields nothing (no content, no symbols, no secrets)
while every runtime request is authenticated, watermarked and
rate-limited server-side, where the scraper cannot reach.
