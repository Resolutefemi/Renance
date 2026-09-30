package httpapi

import (
        "crypto/sha256"
        "encoding/hex"
        "encoding/json"
        "io"
        "log/slog"
        "net/http"
        "net/http/httptest"
        "os"
        "path/filepath"
        "testing"

        "renance.dev/study-api/internal/cbtdata"
        "renance.dev/study-api/internal/config"
        "renance.dev/study-api/internal/jwtx"
)

// The bundle endpoint ships each static bank's per-question answer and
// explanation material (founder directive 2026-09 - the same content
// the web's static bundle shelf publishes, so the study reader grades
// and explains offline on every client), while the library's in-memory
// copy stays answer-free for every internal consumer (ADR-0003 holds
// for composed papers, arena seats and the daily rotation).

func writeAnswerBank(t *testing.T) *cbtdata.Library {
        t.Helper()
        dir := t.TempDir()
        if err := os.MkdirAll(filepath.Join(dir, "questions"), 0o755); err != nil {
                t.Fatal(err)
        }
        bank := map[string]any{
                "code": "test-bank", "title": "Test Bank", "version": 1,
                "questionCount": 2, "totalMarks": 2,
                "questions": []any{
                        map[string]any{
                                "id": "q1", "type": "mcq", "stem": "2+2?", "marks": 1,
                                "options": map[string]string{"A": "3", "B": "4"},
                                "answer": "B", "explanation": "Basic addition: 2 plus 2 is 4.",
                        },
                        map[string]any{
                                "id": "q2", "type": "mcq", "stem": "Capital of Nigeria?", "marks": 1,
                                "options": map[string]string{"A": "Lagos", "B": "Abuja"},
                                "answer": "B",
                        },
                },
        }
        raw, _ := json.Marshal(bank)
        sum := sha256.Sum256(raw)
        manifest := cbtdata.Manifest{Version: "test", Exams: []cbtdata.ExamMeta{{
                Code: "test-bank", Title: "Test Bank", QuestionCount: 2,
                BundleSHA256: hex.EncodeToString(sum[:]),
                SizeBytes:    int64(len(raw)),
        }}}
        mRaw, _ := json.Marshal(manifest)
        if err := os.WriteFile(filepath.Join(dir, "manifest.json"), mRaw, 0o644); err != nil {
                t.Fatal(err)
        }
        if err := os.WriteFile(filepath.Join(dir, "questions", "test-bank.json"), raw, 0o644); err != nil {
                t.Fatal(err)
        }
        lib, err := cbtdata.Load(dir)
        if err != nil {
                t.Fatalf("load: %v", err)
        }
        return lib
}

func TestBundleServesAnswerMaterialForStaticBanks(t *testing.T) {
        lib := writeAnswerBank(t)
        cfg := &config.Config{JWTSecret: "bundle-test-secret-0123456789", WebOrigin: "*"}
        log := slog.New(slog.NewTextHandler(io.Discard, nil))
        s := NewServer(cfg, log, nil, lib, nil, nil, nil)
        tok, err := jwtx.Issue("u1", "Student One", cfg.JWTSecret)
        if err != nil {
                t.Fatal(err)
        }

        handler := s.Handler()
        rec := httptest.NewRecorder()
        req := httptest.NewRequest(http.MethodGet, "/bundles/test-bank", nil)
        req.Header.Set("Authorization", "Bearer "+tok)
        handler.ServeHTTP(rec, req)
        if rec.Code != http.StatusOK {
                t.Fatalf("status = %d body = %s", rec.Code, rec.Body.String())
        }

        var served struct {
                Questions []struct {
                        ID          string `json:"id"`
                        Answer      string `json:"answer"`
                        Explanation string `json:"explanation"`
                } `json:"questions"`
        }
        if err := json.Unmarshal(rec.Body.Bytes(), &served); err != nil {
                t.Fatalf("decode: %v", err)
        }
        if len(served.Questions) != 2 {
                t.Fatalf("want 2 questions, got %d", len(served.Questions))
        }
        if served.Questions[0].Answer != "B" || served.Questions[0].Explanation == "" {
                t.Fatalf("static bank must ship answer + explanation, got %+v", served.Questions[0])
        }
        if served.Questions[1].Answer != "B" {
                t.Fatalf("second question answer missing: %+v", served.Questions[1])
        }

        // The library's cached in-memory copy must stay answer-free so
        // composed papers, arena seats and the daily rotation never leak.
        cached, ok := lib.Bundle("test-bank")
        if !ok {
                t.Fatal("cached bundle missing")
        }
        if cached.Questions[0].Answer != "" || cached.Questions[0].Explanation != "" {
                t.Fatalf("in-memory bundle was mutated: %+v", cached.Questions[0])
        }
}
