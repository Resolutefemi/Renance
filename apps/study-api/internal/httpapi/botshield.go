// Package httpapi - botshield.go
//
// ULTIMATE anti-scraping armor (founder directive 2026-10-11: "someone
// is trying to scrape all my hard work past questions from
// renance-api.onrender.com ... make sure no agentic AI can scrape my
// question, I need ultimate security for my 200,000+ past questions").
//
// The threat model, layered:
//
//   Layer 1  UA shield      - every known AI-crawler / archiver / SEO
//                             spider user-agent is refused before any
//                             handler runs (GPTBot, ClaudeBot, CCBot,
//                             Bytespider, PerplexityBot, ...). Empty or
//                             tool-like UAs cannot touch question
//                             routes at all.
//   Layer 2  robots.txt     - disallow everything; X-Robots-Tag:
//                             noindex, nofollow, noarchive on every
//                             response so indexing pipelines drop the
//                             content even when they ignore robots.txt.
//   Layer 3  static cipher  - the web's /bundles/*.json static shelf
//                             now ships AES-256-GCM ciphertext keyed
//                             per bank code (web_bundles.py). The
//                             master key never leaves the servers;
//                             /bundles/key?code= derives and hands out
//                             one bank's key, so pulling 1,000 keys
//                             means 1,000 metered requests.
//   Layer 4  key gate       - anonymous: proof-of-work challenge
//                             + hard per-IP hourly cap + global
//                             anonymous budget. BUNDLE_ANON_KEY
//                             =false removes the anonymous path
//                             entirely. (The per-account daily bank
//                             quota was REMOVED 2026-10-11 by founder
//                             directive - students prepping many
//                             subjects must never be capped.)
//   Layer 5  ledger         - honeypot strikes and lockouts are
//                             counted per account; scraping bursts
//                             are logged for forensics. (The daily
//                             distinct-bank counter is gone with the
//                             quota.)
//   Layer 6  honeypots      - decoy bank codes nobody legit would
//                             request (hidden in a fake sitemap).
//                             Hitting one serves a POISONED bundle of
//                             canary questions and strikes the
//                             account; two strikes = 24h lockout.
//                             Any third party publishing the canary
//                             text is provably serving scraped
//                             Renance data.
//   Layer 7  watermarking   - every question stem the API serves to a
//                             signed-in user is invisibly watermarked
//                             with an HMAC of (user, question) in
//                             zero-width characters; a leaked corpus
//                             decodes back to the account that pulled
//                             it (see SECURITY.md for the decoder).
//
// All ledgers are in-memory (Render single instance, restarts reset
// them - acceptable: the CDN cipher + quotas are the load-bearing
// walls, the ledger adds detection and account-level throttling).
package httpapi

import (
        "crypto/hmac"
        "crypto/rand"
        "crypto/sha256"
        "encoding/hex"
        "encoding/json"
        "fmt"
        "net/http"
        "os"
        "path/filepath"
        "regexp"
        "runtime"
        "sort"
        "strings"
        "sync"
        "time"

        "renance.dev/study-api/internal/cbtdata"
)

// ---------------------------------------------------------------- Layer 1

// botUARe matches the user agents of every AI crawler, archiver and
// bulk-harvest spider worth blocking. Compiled once. Case-insensitive.
// Maintained from the published crawler lists (openai.com/robots,
// anthropic.com/robots, commoncrawl, and the usual SEO suspects).
var botUARe = regexp.MustCompile(`(?i)` + strings.Join([]string{
        // OpenAI
        `gptbot`, `oai-searchbot`, `chatgpt-user`, `oai-webcrawler`,
        // Anthropic
        `claudebot`, `claude-web`, `anthropic-ai`,
        // Common Crawl + datasets
        `ccbot`, `omgilibot`, `omgili`, `diffbot`, `img2dataset`, `dataset`,
        // Search answer engines
        `perplexitybot`, `perplexity-ai`, `duckassistbot`, `youbot`, `cohere-ai`,
        // ByteDance / Baidu / Yandex bulk agents
        `bytespider`, `petalbot`, `semrushbot`, `ahrefsbot`, `mj12bot`, `dotbot`,
        `serpstatbot`, `dataforseobot`, `sistrix`, `mauibot`,
        // Meta / Amazon / Apple AI appenders
        `facebookexternalhit`, `meta-externalagent`, `amazonbot`, `applebot-extended`,
        // Generic tooling signatures agentic scrapers leave behind
        `python-requests`, `python-urllib`, `aiohttp/`, `httpx`, `curl/`, `wget`,
        `scrapy`, `node-fetch`, `axios/`, `okhttp/`, `go-http-client`, `java/`,
        `libwww-perl`, `mechanize`, `phantomjs`, `headlesschrome`, `puppeteer`,
        `playwright`, `selenium`,
}, "|"))

// botShieldPath returns true for paths that stay reachable to plain
// health probes regardless of UA (uptime monitors, app version gates).
func botShieldPath(p string) bool {
        return p == "/healthz" || p == "/app-version" || p == "/robots.txt"
}

// panicGuard is the outermost handler ring: a panic anywhere inside the
// mux chain is recovered, logged with its stack, and answered with the
// standard error envelope (500 learn_panic) instead of the connection
// being torn down - which the client saw as Cloudflare's bare 502 with
// no body and nothing to log (founder report 2026-10-20, "find my
// courses with ai is not working": live probes reproduced empty replies
// at ~30s while warm calls answered 200). A panic that fires after the
// response started streaming can't be un-sent - the connection still
// dies, but the stack ALWAYS reaches the Render log.
func (s *Server) panicGuard(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                defer func() {
                        rec := recover()
                        if rec == nil {
                                return
                        }
                        buf := make([]byte, 8192)
                        n := runtime.Stack(buf, false)
                        s.shieldLog(r, "panic", fmt.Sprintf("%v\n%s", rec, firstN(string(buf[:n]), 4000)))
                        fail(w, http.StatusInternalServerError, "learn_panic",
                                "something broke on our side - try again in a few seconds")
                }()
                next.ServeHTTP(w, r)
        })
}

// botShield wraps the whole mux: refuses known-bad user agents and
// stamps anti-indexing headers on every response.
func (s *Server) botShield(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                h := w.Header()
                h.Set("X-Robots-Tag", "noindex, nofollow, noarchive, nosnippet")

                ua := r.Header.Get("User-Agent")
                if !botShieldPath(r.URL.Path) {
                        if ua == "" {
                                // No UA at all: browsers always send one, scrapers
                                // often strip it. Question routes only.
                                if strings.HasPrefix(r.URL.Path, "/bundles") || strings.HasPrefix(r.URL.Path, "/manifest") {
                                        s.shieldLog(r, "blocked", "no user-agent")
                                        fail(w, http.StatusForbidden, "bot_shield", "automated access is not permitted")
                                        return
                                }
                        } else if botUARe.MatchString(ua) {
                                s.shieldLog(r, "blocked", "bot user-agent: "+firstN(ua, 90))
                                // 403, not 404: 403 tells honest crawlers to drop the URL
                                // from their queue immediately (they read it as "gone").
                                fail(w, http.StatusForbidden, "bot_shield", "automated access is not permitted")
                                return
                        }
                }
                next.ServeHTTP(w, r)
        })
}

// handleRobotsTxt answers the crawlers' robots.txt with a full
// disallow - the polite layer that keeps question URLs out of any
// index that honors it.
func (s *Server) handleRobotsTxt(w http.ResponseWriter, _ *http.Request) {
        w.Header().Set("Content-Type", "text/plain; charset=utf-8")
        w.Header().Set("Cache-Control", "public, max-age=86400")
        fmt.Fprint(w, "User-agent: *\nDisallow: /\n\n"+
                "# Renance question content is proprietary. Scraping is prohibited.\n")
}

// ---------------------------------------------------------------- Layer 6

// honeypotCodes are decoy bank codes. They appear nowhere in the real
// manifest; the ONLY ways to learn them are scraping artifacts (a fake
// sitemap.json we planted in the web export) or blind enumeration. A
// legitimate client can never ask for one, so asking = scraping, and
// the account earns a strike. Two strikes locks bundle access for 24h.
var honeypotCodes = map[string]struct{}{
        "jamb-english-x9":        {},
        "jamb-maths-superset":    {},
        "waec-physics-2015-all":  {},
        "neco-biology-complete":  {},
        "all-questions-dump":     {},
        "renance-full-bank":      {},
        "jamb-questions-master":  {},
        "waec-answers-key-all":   {},
        "uniosun-mth106-bank":    {},
        "unical-gst112-key":      {},
}

// canaryMarker is the secret string planted in every poisoned
// question. If it ever surfaces in a third-party product, that product
// provably serves scraped Renance data. Rotate on each deploy batch.
const canaryMarker = "RQ7C2ZP4"

// poisonBundle fabricates a plausible-looking bundle for a honeypot
// code. Every question embeds the canary marker; the marks decode via
// SECURITY.md. Answers are deliberately wrong.
func poisonBundle(code string) *cbtdata.Bundle {
        stems := []string{
                "The primary function of the mitochondrion in cell respiration is to",
                "In an ecosystem, energy flow between trophic levels is best described as",
                "The SI unit of magnetic flux density is correctly given as",
                "When an acid reacts with a carbonate, the products formed include",
                "The process by which green plants synthesize carbohydrates is called",
                "A body moving with uniform velocity has zero",
                "The algebraic sum of oxidation numbers in a neutral compound equals",
                "The fundamental unit of heredity in living organisms is the",
        }
        opts := map[string]string{"A": "ATP", "B": "ADP", "C": "RNA", "D": "DNA", "E": "NADP"}
        qs := make([]cbtdata.Question, 0, len(stems))
        for i, st := range stems {
                qs = append(qs, cbtdata.Question{
                        ID:    fmt.Sprintf("%s-canary-%03d", code, i+1),
                        Type:  "mcq",
                        Stem:  st + " " + canaryMarker,
                        Options: map[string]string{
                                "A": opts["A"], "B": opts["B"], "C": opts["C"], "D": opts["D"],
                        },
                        Marks:  1,
                        Year:   2017 + i%6,
                        Answer: string(rune('A' + i%4)),
                })
        }
        return &cbtdata.Bundle{
                Code:          code,
                Title:         code,
                Version:       1,
                QuestionCount: len(qs),
                TotalMarks:    len(qs),
                Questions:     qs,
        }
}

// ---------------------------------------------------------------- ledger

type userLedger struct {
        mu      sync.Mutex
        entries map[string]*userEntry
}

type userEntry struct {
        strikes     int
        blockedTill time.Time
}

func (l *userLedger) entry(uid string) *userEntry {
        e, ok := l.entries[uid]
        if !ok {
                if l.entries == nil {
                        l.entries = map[string]*userEntry{}
                }
                e = &userEntry{}
                l.entries[uid] = e
        }
        return e
}

// The daily distinct-bank quota (record + BUNDLE_ACCOUNT_DAILY) was
// removed entirely on founder directive 2026-10-11: "remove the daily
// bank limit features completely, remove the limit to question bank -
// it's disturbing". Signed-in students now have unlimited bank access;
// abuse is still held off by the UA wall, anonymous proof-of-work,
// per-IP burst rates, honeypot strikes and per-account watermarks.

func (l *userLedger) strike(uid string) int {
        l.mu.Lock()
        defer l.mu.Unlock()
        e := l.entry(uid)
        e.strikes++
        if e.strikes >= 2 {
                e.blockedTill = time.Now().Add(24 * time.Hour)
        }
        return e.strikes
}

// ------------------------------------------------------- extraction
//
// extractionLedger is the bulk-extraction budget (founder directive
// 2026-11-05): per account it caps bundle/key fetches per hour and
// DISTINCT banks unlocked per UTC day. In-memory like the strike
// ledger (single Render instance; a restart resets budgets, which
// only ever favours the student). Corpus keys are exempt - curriculum
// browsing loads many small files legitimately.
type extractionLedger struct {
        mu      sync.Mutex
        entries map[string]*extractEntry
}

type extractEntry struct {
        hourStart time.Time
        hourCount int
        day       string
        distinct  map[string]struct{}
}

func (l *extractionLedger) allow(uid, code string, perHour, distinctPerDay int, now time.Time) bool {
        if uid == "" || perHour <= 0 || distinctPerDay <= 0 {
                return true
        }
        l.mu.Lock()
        defer l.mu.Unlock()
        if l.entries == nil {
                l.entries = map[string]*extractEntry{}
        }
        e, ok := l.entries[uid]
        if !ok {
                e = &extractEntry{distinct: map[string]struct{}{}}
                l.entries[uid] = e
        }
        if now.Sub(e.hourStart) >= time.Hour {
                e.hourStart, e.hourCount = now, 0
        }
        if day := now.UTC().Format("2006-01-02"); e.day != day {
                e.day, e.distinct = day, map[string]struct{}{}
        }
        if e.hourCount >= perHour {
                return false
        }
        if _, seen := e.distinct[code]; !seen && len(e.distinct) >= distinctPerDay {
                return false
        }
        e.hourCount++
        e.distinct[code] = struct{}{}
        return true
}

func (l *userLedger) blocked(uid string) bool {
        l.mu.Lock()
        defer l.mu.Unlock()
        e, ok := l.entries[uid]
        return ok && time.Now().Before(e.blockedTill)
}

// ---------------------------------------------------------------- keys

// bundleKeyFor derives the per-bank AES-256 key from the deployment
// master key: HKDF-ish HMAC-SHA256(master, "renance-bundle/v1|code").
// The web bake (scripts/web_bundles.py) derives the identical key from
// the identical env secret, so cipher and key endpoint always agree.
func bundleKeyFor(master []byte, code string) []byte {
        mac := hmac.New(sha256.New, master)
        mac.Write([]byte("renance-bundle/v1|" + code))
        return mac.Sum(nil)
}

// bundleKeyForStatic derives the AES-256 key for an encrypted STATIC
// asset (past-question PDFs, school-corpus schemes/notes) shipped on
// the renance.app CDN. Byte-identical on all three sides:
// scripts/encrypt_pdfs.mjs, this function, lib/asset-crypto.ts.
// Founder directive 2026-10-12 ("I told someone my past questions on
// the web have no rate limit - is that true? work on it"): the PDF
// shelf is the vault, so it rides the SAME metered key route as the
// question banks.
func bundleKeyForStatic(master []byte, path string) []byte {
        mac := hmac.New(sha256.New, master)
        mac.Write([]byte("renance-static/v1|" + path))
        return mac.Sum(nil)
}

// staticCodePrefix tags a key request for a static CDN asset. The code
// is "static:" + the asset path relative to apps/web/public (e.g.
// "static:pdfs/futa/cos101.pdf").
const staticCodePrefix = "static:"

// isCorpusPath reports whether a static asset belongs to the school
// corpus (NERDC schemes + lesson notes) rather than the past-question
// PDF shelf. The corpus rides a gentler anonymous cap: curriculum
// browsing is a public product surface, the PDFs are the vault.
func isCorpusPath(path string) bool {
        return strings.HasPrefix(path, "school-corpus/")
}

// loadStaticRegistry reads data/static_registry.json (written by
// scripts/encrypt_pdfs.mjs, committed to the repo so the Docker image
// carries it via `COPY data/ /app/data/`). Only paths listed here get
// keys; everything else 404s so enumeration learns nothing. A missing
// or unreadable file leaves both maps nil - static codes then serve
// nothing (fail-closed), banks are unaffected.
func (s *Server) loadStaticRegistry(dataDir string) {
        if dataDir == "" {
                return
        }
        b, err := os.ReadFile(filepath.Join(dataDir, "static_registry.json"))
        if err != nil {
                return
        }
        var reg struct {
                Files     map[string]json.RawMessage `json:"files"`
                Honeypots []string                   `json:"honeypots"`
        }
        if err := json.Unmarshal(b, &reg); err != nil {
                return
        }
        s.staticFiles = make(map[string]struct{}, len(reg.Files))
        for p := range reg.Files {
                s.staticFiles[p] = struct{}{}
        }
        s.staticHoneypots = make(map[string]struct{}, len(reg.Honeypots))
        for _, p := range reg.Honeypots {
                s.staticHoneypots[p] = struct{}{}
        }
}

// ---------------------------------------------------------------- PoW

type powEntry struct {
        issued  time.Time
        diff    int
        used    bool
}

type powLedger struct {
        mu   sync.Mutex
        m    map[string]*powEntry
        last time.Time // last global sweep
}

func (p *powLedger) issue(diffBits int) (nonce string, diff int) {
        b := make([]byte, 16)
        rand.Read(b)
        nonce = hex.EncodeToString(b)
        p.mu.Lock()
        defer p.mu.Unlock()
        if p.m == nil {
                p.m = map[string]*powEntry{}
        }
        // Difficulty from config (BUNDLE_POW_BITS, default 18 ≈ 262k
        // hashes: ~0.3s of honest browser work, cheap to verify, and a
        // scripted client pays the same price on every single key fetch).
        p.m[nonce] = &powEntry{issued: time.Now(), diff: diffBits}
        if time.Since(p.last) > 10*time.Minute {
                p.sweep()
                p.last = time.Now()
        }
        return nonce, diffBits
}

func (p *powLedger) sweep() {
        cut := time.Now().Add(-10 * time.Minute)
        for k, e := range p.m {
                if e.issued.Before(cut) || e.used {
                        delete(p.m, k)
                }
        }
}

func (p *powLedger) solve(nonce, answer string) bool {
        p.mu.Lock()
        e, ok := p.m[nonce]
        if ok {
                e.used = true
                if e.issued.Before(time.Now().Add(-10*time.Minute)) {
                        ok = false
                }
        }
        p.mu.Unlock()
        if !ok {
                return false
        }
        // verify: sha256(nonce || answer) starts with N/4 zero hex chars
        sum := sha256.Sum256([]byte(nonce + answer))
        hexd := hex.EncodeToString(sum[:])
        zeroes := e.diff / 4
        return len(hexd) >= zeroes && strings.Repeat("0", zeroes) == hexd[:zeroes]
}

// ---------------------------------------------------------------- handler

// handleBundleKey serves ONE bank's decryption key (Layer 3/4).
//
//      GET /bundles/key?code=<bank>
//
// Anonymous callers: proof-of-work (first request without a solution
// returns the challenge), per-IP hourly cap and a global budget;
// settable off entirely with BUNDLE_ANON_KEY=false. Signed-in callers
// have NO daily quota (removed 2026-10-11, founder directive).
func (s *Server) handleBundleKey(w http.ResponseWriter, r *http.Request) {
        code := strings.TrimSpace(r.URL.Query().Get("code"))
        master := s.cfg.BundleMasterKey

        // Static asset codes ("static:pdfs/futa/cos101.pdf") follow the
        // same walls as bank codes - one shield, two asset families.
        isStatic := strings.HasPrefix(code, staticCodePrefix)
        staticPath := ""
        if isStatic {
                staticPath = strings.TrimPrefix(code, staticCodePrefix)
        }

        // Honeypots strike on the key route too (a scraper enumerates keys,
        // never pages). Bank decoys AND static decoys land here.
        _, bankDecoy := honeypotCodes[code]
        var staticDecoy bool
        if isStatic {
                _, staticDecoy = s.staticHoneypots[staticPath]
        }
        if bankDecoy || staticDecoy {
                uid, _ := userIDFrom(r)
                if uid != "" {
                        n := s.ledger.strike(uid)
                        s.shieldLog(r, "honeypot", fmt.Sprintf("code=%s user=%s strikes=%d", code, uid, n))
                } else {
                        s.shieldLog(r, "honeypot", "code="+code+" (anonymous)")
                }
                // Serve a plausible key so the scraper happily keeps
                // grinding (and, for bank decoys, decrypts the canary
                // content and publishes the proof).
                key := bundleKeyFor(master, code)
                if staticDecoy {
                        key = bundleKeyForStatic(master, staticPath)
                }
                writeJSON(w, http.StatusOK, bundleKeyResponse{KID: s.cfg.BundleKeyID, Code: code, Alg: "A256GCM", Key: hex.EncodeToString(key)})
                return
        }

        if master == nil || len(master) == 0 {
                fail(w, http.StatusServiceUnavailable, "key_unavailable",
                        "static bundle encryption is not configured on this deployment")
                return
        }

        // The code must be a real asset (manifest member for banks,
        // registry member for statics). Unknown codes get no key -
        // enumeration learns nothing.
        if code == "" {
                fail(w, http.StatusBadRequest, "bad_request", "code query parameter is required")
                return
        }
        if isStatic {
                if s.staticFiles == nil {
                        fail(w, http.StatusNotFound, "unknown_asset", "no asset with that code")
                        return
                }
                if _, known := s.staticFiles[staticPath]; !known {
                        fail(w, http.StatusNotFound, "unknown_asset", "no asset with that code")
                        return
                }
        } else if _, known := s.lib.Bundle(code); !known {
                fail(w, http.StatusNotFound, "unknown_bank", "no bank with that code")
                return
        }

        uid, err := userIDFrom(r)
        signedIn := err == nil && uid != ""

        if signedIn {
                // SPEED CAP ONLY (founder directive 2026-10-12: the daily
                // distinct-bank quota stays REMOVED - "a student prepping
                // every subject in one day is the PRODUCT" - but every key
                // fetch is rate limited per account so a scripted
                // enumerator with one free account cannot walk 3,000 codes
                // in a burst. 90/min is 10x any real study session.)
                if !s.bundleKeyUser.allow("u:" + uid) {
                        s.shieldLog(r, "quota", "key user rate user="+uid)
                        fail(w, http.StatusTooManyRequests, "slow_down", "too many requests")
                        return
                }
                // Bulk-extraction budget (banks + PDF vault; corpus exempt).
                if !(isStatic && isCorpusPath(staticPath)) {
                        if !s.extract.allow(uid, code, s.cfg.BundleUserPerHour, s.cfg.BundleUserDistinctPerDay, time.Now()) {
                                s.shieldLog(r, "extraction", "key budget user="+uid+" code="+code)
                                fail(w, http.StatusTooManyRequests, "extraction_limit", "you have opened a lot of question banks in a short time - take a break and continue shortly")
                                return
                        }
                }
                // Honeypot lockout is the only other signed-in wall.
                if s.ledger.blocked(uid) {
                        s.shieldLog(r, "blocked", "user="+uid+" bundle key while locked")
                        fail(w, http.StatusForbidden, "access_suspended", "unusual download activity detected on this account")
                        return
                }
        } else {
                // Anonymous path. PDFs ride the strict vault cap; the
                // school-corpus files ride the gentler curriculum cap.
                if !s.cfg.BundleAnonKey {
                        fail(w, http.StatusUnauthorized, "sign_in_required", "sign in to load question banks")
                        return
                }
                ip := clientIP(r)
                ipCap := s.bundleKeyIP
                if isStatic && isCorpusPath(staticPath) {
                        ipCap = s.staticKeyIPCorpus
                }
                if !ipCap.allow("ip:" + ip) {
                        s.shieldLog(r, "quota", "anon ip rate ip="+ip)
                        fail(w, http.StatusTooManyRequests, "slow_down", "too many requests")
                        return
                }
                if !s.bundleAnonGlobal.allow("global") {
                        s.shieldLog(r, "quota", "anon global budget tripped")
                        fail(w, http.StatusServiceUnavailable, "unavailable", "try again later")
                        return
                }
                // Layer 4 PoW: no solution yet -> hand out the challenge.
                pow := strings.TrimSpace(r.URL.Query().Get("pow"))
                if pow == "" {
                        bits := s.cfg.BundlePowBits
                        if isStatic && isCorpusPath(staticPath) {
                                bits = s.cfg.BundleCorpusPowBits
                        }
                        nonce, diff := s.pows.issue(bits)
                        writeJSON(w, http.StatusUnauthorized, powChallenge{
                                Code: code, Challenge: powChallengeSpec{
                                        Nonce: nonce, Difficulty: diff, Algo: "sha256",
                                        Hint: "find hex suffix s.t. sha256(nonce||suffix) starts with difficulty/4 zero hex chars",
                                },
                        })
                        return
                }
                nonce := strings.TrimSpace(r.URL.Query().Get("nonce"))
                if nonce == "" || !s.pows.solve(nonce, pow) {
                        fail(w, http.StatusBadRequest, "pow_invalid", "proof-of-work rejected")
                        return
                }
        }

        s.shieldLog(r, "key", "code="+code+" user="+nonEmpty(uid, "anon"))
        key := bundleKeyFor(master, code)
        if isStatic {
                key = bundleKeyForStatic(master, staticPath)
        }
        writeJSON(w, http.StatusOK, bundleKeyResponse{
                KID:  s.cfg.BundleKeyID,
                Code: code,
                Alg:  "A256GCM",
                Key:  hex.EncodeToString(key),
        })
}

type bundleKeyResponse struct {
        KID  string `json:"kid"`
        Code string `json:"code"`
        Alg  string `json:"alg"`
        Key  string `json:"key"`
}

type powChallenge struct {
        Code      string           `json:"code"`
        Challenge powChallengeSpec `json:"challenge"`
}

type powChallengeSpec struct {
        Nonce     string `json:"nonce"`
        Difficulty int   `json:"difficulty"`
        Algo      string `json:"algo"`
        Hint      string `json:"hint,omitempty"`
}

// shieldBundle wraps handleBundle with the account/IP/honeypot walls
// (Layers 4-6) and the per-user watermark (Layer 7).
func (s *Server) shieldBundle(next http.HandlerFunc) http.HandlerFunc {
        return func(w http.ResponseWriter, r *http.Request) {
                code := r.PathValue("code")

                // Layer 4 (IP): burst rate on the bundle route for everyone.
                if !s.bundleBurstIP.allow("bun:" + clientIP(r)) {
                        s.shieldLog(r, "quota", "bundle ip rate ip="+clientIP(r))
                        fail(w, http.StatusTooManyRequests, "slow_down", "too many requests")
                        return
                }

                if _, decoy := honeypotCodes[code]; decoy {
                        uid, _ := userIDFrom(r)
                        if uid != "" {
                                n := s.ledger.strike(uid)
                                s.shieldLog(r, "honeypot", fmt.Sprintf("bundle code=%s user=%s strikes=%d", code, uid, n))
                        } else {
                                s.shieldLog(r, "honeypot", "bundle code="+code+" (anonymous)")
                        }
                        // Poisoned bundle: canary-marked, plausible, worthless.
                        writeJSON(w, http.StatusOK, poisonBundle(code))
                        return
                }

                uid, err := userIDFrom(r)
                if err == nil && uid != "" {
                        if s.ledger.blocked(uid) {
                                fail(w, http.StatusForbidden, "access_suspended", "unusual download activity detected on this account")
                                return
                        }
                        if !s.extract.allow(uid, code, s.cfg.BundleUserPerHour, s.cfg.BundleUserDistinctPerDay, time.Now()) {
                                s.shieldLog(r, "extraction", "bundle budget user="+uid+" code="+code)
                                fail(w, http.StatusTooManyRequests, "extraction_limit", "you have opened a lot of question banks in a short time - take a break and continue shortly")
                                return
                        }
                        // No daily quota here either (founder directive
                        // 2026-10-11). The per-IP burst wall above stays.
                        // Layer 7: the served copy is watermarked inside handleBundle
                        // (s.watermarkBundle) via userIDFrom - see exams.go.
                }
                next(w, r)
        }
}

// ---------------------------------------------------------------- wm impl

// watermarkBundle returns a serveable copy of the bundle with every
// long-enough stem invisibly signed for the account (Layer 7). Called
// from handleBundle once the payload is assembled; deterministic per
// (account, question) so even ONE leaked question identifies the
// account it was served to. Decoding recipe lives in SECURITY.md.
func (s *Server) watermarkBundle(b *cbtdata.Bundle, uid string) *cbtdata.Bundle {
        secret := s.watermarkSecret()
        if b == nil || uid == "" || secret == nil {
                return b
        }
        out := *b
        qs := make([]cbtdata.Question, len(b.Questions))
        copy(qs, b.Questions)
        for i := range qs {
                qs[i].Options, qs[i].Answer = fingerprintOptions(qs[i], uid, secret)
                if len(qs[i].Stem) >= 24 {
                        qs[i].Stem = watermarkStem(qs[i].Stem, uid, qs[i].ID, secret)
                }
        }
        out.Questions = qs
        return &out
}

// watermarkSecret derives the watermark HMAC key from the bundle
// master key (JWT secret as fallback) - never the same bytes as the
// transport cipher key.
func (s *Server) watermarkSecret() []byte {
        if len(s.cfg.BundleMasterKey) > 0 {
                mac := hmac.New(sha256.New, s.cfg.BundleMasterKey)
                mac.Write([]byte("renance-watermark/v1"))
                return mac.Sum(nil)
        }
        return []byte(s.cfg.JWTSecret)
}

// zeroWidth bits (Space=0, Joiner=1) + sentinels. Decoding: strip all
// zero-width characters, map ZWSP->0 / ZWNJ->1 between the sentinels,
// 16 bits -> hex -> HMAC bytes prefix. See SECURITY.md.
const (
        zwSP = "\u200b" // zero-width space  -> bit 0
        zwNJ = "\u200c" // zero-width non-joiner -> bit 1
        zwPre = "\u2060" // word joiner: watermark start sentinel
        zwPost = "\u2062" // invisible times: watermark end sentinel
)

// watermarkStem embeds a 16-bit account signature into a stem copy.
// Deterministic: the same (uid, qid) always yields the same bits, so
// any single leaked question still identifies the account.
func watermarkStem(stem, uid, qid string, secret []byte) string {
        if stem == "" || len(stem) < 24 {
                return stem
        }
        mac := hmac.New(sha256.New, secret)
        mac.Write([]byte("renance-wm/v1|"))
        mac.Write([]byte(uid))
        mac.Write([]byte{'|'})
        mac.Write([]byte(qid))
        sig := mac.Sum(nil)
        bits := int(sig[0])<<8 | int(sig[1]) // 16 bits
        var sb strings.Builder
        sb.WriteString(zwPre)
        for i := 15; i >= 0; i-- {
                if bits&(1<<uint(i)) != 0 {
                        sb.WriteString(zwNJ)
                } else {
                        sb.WriteString(zwSP)
                }
        }
        sb.WriteString(zwPost)
        // Insert after the first space boundary past char 12 so the mark
        // rides mid-sentence, invisible and out of truncation danger.
        idx := strings.IndexFunc(stem[12:min(60, len(stem))], func(r rune) bool { return r == ' ' })
        if idx < 0 {
                return stem[:12] + sb.String() + stem[12:]
        }
        cut := 12 + idx + 1
        return stem[:cut] + sb.String() + stem[cut:]
}

// fingerprintOptions deterministically permutes one question's
// options for one account and remaps the answer letter to the same
// answer text. Unlike the zero-width stem mark, the permutation
// survives plain-text copying, screenshots re-typed by an AI agent,
// and dataset re-publication: the pattern of orderings across many
// questions identifies the serving account (testable against any
// candidate account with the server secret, never guessable without
// it). Questions whose answer letter is not an option key keep their
// original order - a shuffle must never corrupt grading.
func fingerprintOptions(q cbtdata.Question, uid string, secret []byte) (map[string]string, string) {
        if len(q.Options) < 2 || uid == "" || len(secret) == 0 {
                return q.Options, q.Answer
        }
        keys := make([]string, 0, len(q.Options))
        for k := range q.Options {
                keys = append(keys, k)
        }
        sort.Strings(keys)
        answerIdx := -1
        for i, k := range keys {
                if k == q.Answer {
                        answerIdx = i
                }
        }
        if answerIdx < 0 {
                out := make(map[string]string, len(q.Options))
                for k, v := range q.Options {
                        out[k] = v
                }
                return out, q.Answer
        }
        mac := hmac.New(sha256.New, secret)
        mac.Write([]byte("renance-opt/v1|" + uid + "|" + q.ID))
        seed := mac.Sum(nil)
        perm := make([]int, len(keys))
        for i := range perm {
                perm[i] = i
        }
        for i := len(perm) - 1; i > 0; i-- {
                j := int(seed[i%len(seed)]) % (i + 1)
                perm[i], perm[j] = perm[j], perm[i]
        }
        out := make(map[string]string, len(keys))
        answer := q.Answer
        for pos, src := range perm {
                out[keys[pos]] = q.Options[keys[src]]
                if src == answerIdx {
                        answer = keys[pos]
                }
        }
        return out, answer
}

// ---------------------------------------------------------------- util

func nonEmpty(s, def string) string {
        if s == "" {
                return def
        }
        return s
}

func firstN(s string, n int) string {
        if len(s) > n {
                return s[:n]
        }
        return s
}

// shieldLog emits a structured log line for the abuse ledger. On
// Render these lines are the forensic trail; wire alerts to them.
func (s *Server) shieldLog(r *http.Request, event, detail string) {
        if s.log == nil {
                return
        }
        s.log.Warn("botshield",
                "event", event,
                "ip", clientIP(r),
                "ua", firstN(r.Header.Get("User-Agent"), 120),
                "path", r.URL.Path,
                "detail", detail)
}
