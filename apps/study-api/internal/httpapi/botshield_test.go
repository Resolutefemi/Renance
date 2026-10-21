package httpapi

import (
        "crypto/hmac"
        "crypto/sha256"
        "encoding/hex"
        "encoding/json"
        "io"
        "log/slog"
        "net/http"
        "net/http/httptest"
        "os"
        "path/filepath"
        "strings"
        "testing"

        "renance.dev/study-api/internal/cbtdata"
        "renance.dev/study-api/internal/config"
        "renance.dev/study-api/internal/jwtx"
)

// The bundle shield (botshield.go) hardening, per the founder's
// 2026-10-11 "ultimate security" directive. Each test pins one layer:
// UA blocking, robots.txt, key delivery (PoW), unlimited signed-in
// access (the daily quota was removed 2026-10-11), honeypot strikes,
// watermarks, and the cross-system key derivation.

func shieldServer(t *testing.T) (*Server, http.Handler, string, string) {
        t.Helper()
        lib := writeAnswerBank(t)
        master, _ := hex.DecodeString("8a2f1c4e19b76d3f5e8a0c2b4d6f8a1c3e5b7d9f1a3c5e7b9d1f3a5c7e9b1d3f")
        cfg := &config.Config{
                JWTSecret: "shield-test-secret-0123456789", WebOrigin: "*",
                BundleMasterKey: master, BundleKeyID: "t1", BundleAnonKey: true,
                BundleIPPerHour: 60, BundlePowBits: 8,
        }
        log := slog.New(slog.NewTextHandler(io.Discard, nil))
        s := NewServer(cfg, log, nil, lib, nil, nil, nil)
        tok, err := jwtx.Issue("u1", "Student One", cfg.JWTSecret)
        if err != nil {
                t.Fatal(err)
        }
        return s, s.Handler(), tok, "u1"
}

func TestBotShieldBlocksAIUserAgents(t *testing.T) {
        _, h, _, _ := shieldServer(t)
        for _, ua := range []string{
                "GPTBot/1.0", "ClaudeBot/1.0 (+https://anthropic.com)",
                "CCBot/2.0 (https://commoncrawl.org/faq/)",
                "PerplexityBot/1.0", "python-requests/2.31.0",
                "curl/8.5.0", "Scrapy/2.11 (+http://scrapy.org)",
        } {
                rec := httptest.NewRecorder()
                req := httptest.NewRequest(http.MethodGet, "/manifest", nil)
                req.Header.Set("User-Agent", ua)
                req.Header.Set("Authorization", "Bearer x")
                h.ServeHTTP(rec, req)
                if rec.Code != http.StatusForbidden {
                        t.Fatalf("ua %q: want 403, got %d", ua, rec.Code)
                }
        }
        // A real browser UA sails through (to the auth wall, not the shield).
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, "/manifest", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")
        h.ServeHTTP(rec, req)
        if rec.Code == http.StatusForbidden {
                t.Fatal("browser UA must not be blocked by the shield")
        }
}

func TestBotShieldRobotsTxtAndNoindex(t *testing.T) {
        _, h, _, _ := shieldServer(t)
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, "/robots.txt", nil)
        req.Header.Set("User-Agent", "GPTBot") // robots.txt stays reachable to bots
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Disallow: /") {
                t.Fatalf("robots.txt: %d %s", rec.Code, rec.Body.String())
        }
        // Every response carries the anti-indexing header (checked on a
        // blocked-UA response: the shield stamps it before the 403).
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/manifest", nil)
        req.Header.Set("User-Agent", "GPTBot/1.0")
        h.ServeHTTP(rec, req)
        if got := rec.Header().Get("X-Robots-Tag"); !strings.Contains(got, "noindex") {
                t.Fatalf("X-Robots-Tag = %q", got)
        }
}

func TestBundleKeyAnonymousProofOfWork(t *testing.T) {
        _, h, _, _ := shieldServer(t)
        // 1) no solution -> 401 challenge
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, "/bundles/key?code=test-bank", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusUnauthorized {
                t.Fatalf("want challenge 401, got %d %s", rec.Code, rec.Body.String())
        }
        var ch powChallenge
        if err := json.Unmarshal(rec.Body.Bytes(), &ch); err != nil {
                t.Fatalf("decode challenge: %v", err)
        }
        // 2) solve it (difficulty is 8 bits in the test fixture)
        suffix := solveForTest(ch.Challenge.Nonce, ch.Challenge.Difficulty)
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/key?code=test-bank&nonce="+ch.Challenge.Nonce+"&pow="+suffix, nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusOK {
                t.Fatalf("solved pow: want 200, got %d %s", rec.Code, rec.Body.String())
        }
        var kr bundleKeyResponse
        if err := json.Unmarshal(rec.Body.Bytes(), &kr); err != nil {
                t.Fatal(err)
        }
        if kr.KID != "t1" || len(kr.Key) != 64 {
                t.Fatalf("key response: %+v", kr)
        }
        // 3) the key must equal the canonical derivation (the SAME bytes
        // scripts/encrypt_bundles.mjs and lib/bundle-crypto.ts use).
        mac := hmac.New(sha256.New, mustHex(t, "8a2f1c4e19b76d3f5e8a0c2b4d6f8a1c3e5b7d9f1a3c5e7b9d1f3a5c7e9b1d3f"))
        mac.Write([]byte("renance-bundle/v1|test-bank"))
        if want := hex.EncodeToString(mac.Sum(nil)); kr.Key != want {
                t.Fatalf("key mismatch: api=%s want=%s", kr.Key, want)
        }
        // 4) a bogus solution is rejected.
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/key?code=test-bank&nonce=deadbeef&pow=00000001", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusBadRequest {
                t.Fatalf("bogus pow: want 400, got %d", rec.Code)
        }
}

func TestBundleKeyNoDailyLimit(t *testing.T) {
        s, h, tok, uid := shieldServer(t)
        // Founder directive 2026-10-11 ("remove the daily bank limit
        // features completely"): a signed-in student can pull the key
        // route and the bundle route as often as they like - no 429
        // bank_quota, no distinct-bank ceiling, nothing. Practice is
        // never capped.
        for i := 0; i < 5; i++ {
                rec := httptest.NewRecorder()
                req := httptest.NewRequest(http.MethodGet, "/bundles/key?code=test-bank", nil)
                req.Header.Set("User-Agent", "Mozilla/5.0")
                req.Header.Set("Authorization", "Bearer "+tok)
                h.ServeHTTP(rec, req)
                if rec.Code != http.StatusOK {
                        t.Fatalf("signed-in key fetch %d: %d %s", i, rec.Code, rec.Body.String())
                }
                if strings.Contains(rec.Body.String(), "bank_quota") {
                        t.Fatalf("daily bank limit leaked back in: %s", rec.Body.String())
                }
        }
        // Bundle fetches stay unlimited too.
        for i := 0; i < 5; i++ {
                rec := httptest.NewRecorder()
                req := mustReq(t, tok, "/bundles/test-bank")
                h.ServeHTTP(rec, req)
                if rec.Code != http.StatusOK {
                        t.Fatalf("bundle fetch %d: %d %s", i, rec.Code, rec.Body.String())
                }
                if strings.Contains(rec.Body.String(), "bank_quota") {
                        t.Fatalf("daily bank limit leaked back in: %s", rec.Body.String())
                }
        }
        // Unknown banks still 404 (enumeration learns nothing) but
        // NEVER trip a quota wall.
        rec := httptest.NewRecorder()
        req := mustReq(t, tok, "/bundles/other-bank")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusNotFound {
                t.Fatalf("unknown bank: want 404, got %d %s", rec.Code, rec.Body.String())
        }
        // And the account carries no strikes: unlimited != flagged.
        if n := s.ledger.entry(uid).strikes; n != 0 {
                t.Fatalf("strikes = %d, want 0", n)
        }
}

func TestHoneypotStrikesAndPoison(t *testing.T) {
        s, h, tok, uid := shieldServer(t)
        // Strike 1: poison bundle served, plausible shape.
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, "/bundles/renance-full-bank", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        req.Header.Set("Authorization", "Bearer "+tok)
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusOK {
                t.Fatalf("honeypot serve: %d", rec.Code)
        }
        if !strings.Contains(rec.Body.String(), canaryMarker) {
                t.Fatal("poison bundle must carry the canary marker")
        }
        if n := s.ledger.entry(uid).strikes; n != 1 {
                t.Fatalf("strikes = %d, want 1", n)
        }
        // Strike 2: locked out for 24h.
        h.ServeHTTP(httptest.NewRecorder(), mustReq(t, tok, "/bundles/all-questions-dump"))
        if !s.ledger.blocked(uid) {
                t.Fatal("two honeypot strikes must lock bundle access")
        }
        // The lockout also covers the real bank + the key route.
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/test-bank", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        req.Header.Set("Authorization", "Bearer "+tok)
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusForbidden {
                t.Fatalf("locked account: want 403, got %d", rec.Code)
        }
}

func TestWatermarkDecodesToAccount(t *testing.T) {
        s, _, _, uid := shieldServer(t)
        b := &cbtdata.Bundle{
                Code: "test-bank", Questions: []cbtdata.Question{
                        {ID: "q1", Type: "mcq", Stem: "The primary function of the xylem in vascular plants is to", Marks: 1},
                },
        }
        wm := s.watermarkBundle(b, uid)
        marked := wm.Questions[0].Stem
        if marked == b.Questions[0].Stem {
                t.Fatal("stem was not watermarked")
        }
        // Visible text unchanged: strip zero-width chars and compare.
        stripped := stripZeroWidth(marked)
        if stripped != b.Questions[0].Stem {
                t.Fatalf("visible text changed:\n%q\n%q", stripped, b.Questions[0].Stem)
        }
        // Decode the 16-bit signature and re-derive it from (uid, qid).
        bits := decodeWatermarkBits(marked)
        secret := s.watermarkSecret()
        mac := hmac.New(sha256.New, secret)
        mac.Write([]byte("renance-wm/v1|" + uid + "|q1"))
        sig := mac.Sum(nil)
        want := int(sig[0])<<8 | int(sig[1])
        if bits != want {
                t.Fatalf("watermark bits = %04b want %04b", bits, want)
        }
        // Deterministic: same account + question -> identical bits.
        if s.watermarkBundle(b, uid).Questions[0].Stem != marked {
                t.Fatal("watermark must be deterministic")
        }
        // Different account -> different bits.
        other := s.watermarkBundle(b, "u2").Questions[0].Stem
        if other == marked {
                t.Fatal("watermark must vary by account")
        }
}

func stripZeroWidth(s string) string {
        r := strings.NewReplacer(zwSP, "", zwNJ, "", zwPre, "", zwPost, "")
        return r.Replace(s)
}

func decodeWatermarkBits(stem string) int {
        start := strings.Index(stem, zwPre)
        end := strings.Index(stem, zwPost)
        if start < 0 || end < start {
                return -1
        }
        payload := stem[start+len(zwPre) : end]
        bits := 0
        for _, r := range payload {
                bits <<= 1
                switch string(r) {
                case zwNJ:
                        bits |= 1
                case zwSP:
                default:
                        return -1
                }
        }
        return bits
}

func solveForTest(nonce string, diff int) string {
        for i := 0; ; i++ {
                suffix := []byte{byte(i >> 24), byte(i >> 16), byte(i >> 8), byte(i)}
                sum := sha256.Sum256([]byte(nonce + hex.EncodeToString(suffix)))
                if leadingZeroBits(sum[:]) >= diff {
                        return hex.EncodeToString(suffix)
                }
        }
}

func leadingZeroBits(b []byte) int {
        n := 0
        for _, x := range b {
                for i := 7; i >= 0; i-- {
                        if x&(1<<uint(i)) != 0 {
                                return n
                        }
                        n++
                }
        }
        return n
}

func mustReq(t *testing.T, tok, path string) *http.Request {
        t.Helper()
        req := httptest.NewRequest(http.MethodGet, path, nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        req.Header.Set("Authorization", "Bearer "+tok)
        return req
}

func mustHex(t *testing.T, s string) []byte {
        t.Helper()
        b, err := hex.DecodeString(s)
        if err != nil {
                t.Fatal(err)
        }
        return b
}

// ------------------------------------------------------------------
// STATIC ASSET SHIELD (founder directive 2026-10-12: "I told someone
// my past questions on the web have no rate limit and can be scraped -
// is that true? work on it"). The /pdfs shelf + school-corpus are now
// RNP1 ciphertext; their keys ride the same route. These tests pin the
// static path: registry validation, the renance-static/v1 derivation,
// tiered anonymous PoW, the signed-in SPEED cap (daily stays REMOVED),
// and static honeypot strikes.

func staticShieldServer(t *testing.T, keyPerMin int) (*Server, http.Handler, string, string) {
        t.Helper()
        lib := writeAnswerBank(t)
        master, _ := hex.DecodeString("8a2f1c4e19b76d3f5e8a0c2b4d6f8a1c3e5b7d9f1a3c5e7b9d1f3a5c7e9b1d3f")
        dir := t.TempDir()
        reg := `{"v":1,"files":{
                "pdfs/futa/cos101.pdf":{"sha256":"00","bytes":1},
                "pdfs/noun/acc102.pdf":{"sha256":"00","bytes":1},
                "school-corpus/schemes/jss-1/basic-science-term1.json":{"sha256":"00","bytes":1}
        },"honeypots":["pdfs/noun/all-past-questions-complete.pdf"]}`
        if err := os.WriteFile(filepath.Join(dir, "static_registry.json"), []byte(reg), 0o644); err != nil {
                t.Fatal(err)
        }
        cfg := &config.Config{
                JWTSecret: "shield-test-secret-0123456789", WebOrigin: "*",
                BundleMasterKey: master, BundleKeyID: "t1", BundleAnonKey: true,
                BundleIPPerHour: 60, BundlePowBits: 8, BundleCorpusPowBits: 6,
                BundleKeyUserPerMin: keyPerMin, BundleCorpusIPPerHour: 60,
                DataDir: dir,
        }
        log := slog.New(slog.NewTextHandler(io.Discard, nil))
        s := NewServer(cfg, log, nil, lib, nil, nil, nil)
        tok, err := jwtx.Issue("u1", "Student One", cfg.JWTSecret)
        if err != nil {
                t.Fatal(err)
        }
        return s, s.Handler(), tok, "u1"
}

func TestStaticKeyRoute(t *testing.T) {
        _, h, tok, _ := staticShieldServer(t, 90)
        // Unknown static path: 404, enumeration learns nothing.
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, "/bundles/key?code=static:pdfs/futa/nope.pdf", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusNotFound {
                t.Fatalf("unknown static: want 404, got %d %s", rec.Code, rec.Body.String())
        }
        // Unregistered prefix without a registry entry also 404s.
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/key?code=static:", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusNotFound {
                t.Fatalf("empty static path: want 404, got %d", rec.Code)
        }
        // Signed-in: the key is the canonical renance-static/v1 derivation
        // (byte-identical to scripts/encrypt_pdfs.mjs + lib/asset-crypto.ts).
        rec = httptest.NewRecorder()
        req = mustReq(t, tok, "/bundles/key?code=static:pdfs/futa/cos101.pdf")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusOK {
                t.Fatalf("signed-in static key: %d %s", rec.Code, rec.Body.String())
        }
        var kr bundleKeyResponse
        if err := json.Unmarshal(rec.Body.Bytes(), &kr); err != nil {
                t.Fatal(err)
        }
        mac := hmac.New(sha256.New, mustHex(t, "8a2f1c4e19b76d3f5e8a0c2b4d6f8a1c3e5b7d9f1a3c5e7b9d1f3a5c7e9b1d3f"))
        mac.Write([]byte("renance-static/v1|pdfs/futa/cos101.pdf"))
        if want := hex.EncodeToString(mac.Sum(nil)); kr.Key != want {
                t.Fatalf("static key mismatch: api=%s want=%s", kr.Key, want)
        }
        // Anonymous PDF path: PoW challenge at the VAULT difficulty.
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/key?code=static:pdfs/futa/cos101.pdf", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusUnauthorized {
                t.Fatalf("anon static: want 401 challenge, got %d", rec.Code)
        }
        var ch powChallenge
        if err := json.Unmarshal(rec.Body.Bytes(), &ch); err != nil {
                t.Fatal(err)
        }
        if ch.Challenge.Difficulty != 8 {
                t.Fatalf("pdf pow difficulty: want 8, got %d", ch.Challenge.Difficulty)
        }
        suffix := solveForTest(ch.Challenge.Nonce, ch.Challenge.Difficulty)
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/key?code=static:pdfs/futa/cos101.pdf&nonce="+ch.Challenge.Nonce+"&pow="+suffix, nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusOK {
                t.Fatalf("solved static pow: want 200, got %d %s", rec.Code, rec.Body.String())
        }
        // Anonymous CORPUS path: the gentler difficulty (14-bit-class
        // tier, 6 in this fixture).
        rec = httptest.NewRecorder()
        req = httptest.NewRequest(http.MethodGet, "/bundles/key?code=static:school-corpus/schemes/jss-1/basic-science-term1.json", nil)
        req.Header.Set("User-Agent", "Mozilla/5.0")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusUnauthorized {
                t.Fatalf("anon corpus: want 401, got %d", rec.Code)
        }
        if err := json.Unmarshal(rec.Body.Bytes(), &ch); err != nil {
                t.Fatal(err)
        }
        if ch.Challenge.Difficulty != 6 {
                t.Fatalf("corpus pow difficulty: want 6, got %d", ch.Challenge.Difficulty)
        }
}

func TestStaticKeyUserSpeedLimit(t *testing.T) {
        // Founder directives, both honored at once:
        //   2026-10-11 "remove the daily bank limit completely" -> there
        //     is NO daily total anywhere in this path.
        //   2026-10-12 "no rate limit... work on it" -> there IS a
        //     per-account speed cap: 3/min here, 90/min in production.
        _, h, tok, _ := staticShieldServer(t, 3)
        for i := 0; i < 3; i++ {
                rec := httptest.NewRecorder()
                req := mustReq(t, tok, "/bundles/key?code=static:pdfs/futa/cos101.pdf")
                h.ServeHTTP(rec, req)
                if rec.Code != http.StatusOK {
                        t.Fatalf("signed-in fetch %d: want 200, got %d %s", i, rec.Code, rec.Body.String())
                }
        }
        // 4th inside the window: 429 slow_down - the speed wall.
        rec := httptest.NewRecorder()
        req := mustReq(t, tok, "/bundles/key?code=static:pdfs/futa/cos101.pdf")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusTooManyRequests {
                t.Fatalf("speed cap: want 429, got %d %s", rec.Code, rec.Body.String())
        }
        if !strings.Contains(rec.Body.String(), "slow_down") {
                t.Fatalf("speed cap body: %s", rec.Body.String())
        }
        // The same cap covers BANK keys too (one wall, all codes)...
        rec = httptest.NewRecorder()
        req = mustReq(t, tok, "/bundles/key?code=test-bank")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusTooManyRequests {
                t.Fatalf("bank key after static burst: want 429, got %d", rec.Code)
        }
        // ...and it is a SPEED cap, not a daily quota: no quota error
        // code ever appears.
        if strings.Contains(rec.Body.String(), "quota") {
            t.Fatalf("daily quota leaked back in: %s", rec.Body.String())
        }
}

func TestStaticHoneypotStrike(t *testing.T) {
        s, h, tok, uid := staticShieldServer(t, 90)
        // Two honeypot hits = 24h lockout for the account (the decoy
        // names come from data/static_registry.json, planted by
        // scripts/encrypt_pdfs.mjs).
        for i := 0; i < 2; i++ {
                rec := httptest.NewRecorder()
                req := mustReq(t, tok, "/bundles/key?code=static:pdfs/noun/all-past-questions-complete.pdf")
                h.ServeHTTP(rec, req)
                if rec.Code != http.StatusOK {
                        t.Fatalf("honeypot %d: the decoy must answer 200 (keep the scraper grinding), got %d", i, rec.Code)
                }
        }
        if n := s.ledger.entry(uid).strikes; n < 2 {
                t.Fatalf("strikes = %d, want 2", n)
        }
        // Locked out on the next key fetch, any code.
        rec := httptest.NewRecorder()
        req := mustReq(t, tok, "/bundles/key?code=static:pdfs/futa/cos101.pdf")
        h.ServeHTTP(rec, req)
        if rec.Code != http.StatusForbidden {
                t.Fatalf("locked account: want 403, got %d %s", rec.Code, rec.Body.String())
        }
}
