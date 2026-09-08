package daily

import (
        "fmt"
        "strings"
        "testing"

        "renance.dev/study-api/internal/cbtdata"
)

func bundleWith(ids ...string) *cbtdata.Bundle {
        qs := make([]cbtdata.Question, len(ids))
        for i, id := range ids {
                qs[i] = cbtdata.Question{ID: id, Type: "mcq", Marks: 1}
        }
        return &cbtdata.Bundle{Code: "test-pack", Questions: qs, QuestionCount: len(qs)}
}

func TestPickCodeDeterministic(t *testing.T) {
        codes := []string{"jamb-english-bank", "jamb-biology-bank", "jamb-physics-bank", "jamb-mathematics-bank"}
        want := PickCode("2026-09-07", "JAMB", codes)
        for i := 0; i < 100; i++ {
                if got := PickCode("2026-09-07", "JAMB", codes); got != want {
                        t.Fatalf("PickCode drifted on call %d: %q then %q", i, want, got)
                }
        }
        if want == "" {
                t.Fatal("PickCode returned empty for a non-empty pool")
        }
}

func TestPickCodeRotatesAcrossDays(t *testing.T) {
        codes := []string{"jamb-english-bank", "jamb-biology-bank", "jamb-physics-bank", "jamb-mathematics-bank"}
        seen := map[string]int{}
        for d := 1; d <= 120; d++ {
                day := fmt.Sprintf("2026-%02d-%02d", (d-1)/30+1, (d-1)%30+1)
                seen[PickCode(day, "JAMB", codes)]++
        }
        if len(seen) < 3 {
                t.Fatalf("rotation stuck: 120 days produced %v", seen)
        }
}

func TestPickCodeBodyAndOrderIndependent(t *testing.T) {
        codes := []string{"pack-a", "pack-b", "pack-c"}
        jamb := PickCode("2026-09-07", "JAMB", codes)
        waec := PickCode("2026-09-07", "WAEC", codes)
        if jamb == "" || waec == "" {
                t.Fatal("empty pick for non-empty pools")
        }
        // Different bodies must be able to land on different packs somewhere
        // in a window; identical picks every single day would smell like the
        // seed ignoring the body.
        differ := false
        for d := 1; d <= 30; d++ {
                day := fmt.Sprintf("2026-09-%02d", d)
                if PickCode(day, "JAMB", codes) != PickCode(day, "WAEC", codes) {
                        differ = true
                        break
                }
        }
        if !differ {
                t.Fatal("JAMB and WAEC picked identically for 30 straight days")
        }
        // Caller ordering must never leak into the result.
        shuffled := []string{"pack-c", "pack-a", "pack-b"}
        if PickCode("2026-09-07", "JAMB", shuffled) != jamb {
                t.Fatal("PickCode depends on caller's code order")
        }
}

func TestPickCodeEmpty(t *testing.T) {
        if got := PickCode("2026-09-07", "JAMB", nil); got != "" {
                t.Fatalf("expected empty pick for empty pool, got %q", got)
        }
}

func TestQuestionIDsDeterministic(t *testing.T) {
        ids := []string{"q1", "q2", "q3", "q4", "q5", "q6", "q7", "q8", "q9", "q10", "q11", "q12", "q13", "q14", "q15"}
        want := QuestionIDs("2026-09-07", "JAMB", ids)
        if len(want) != Size {
                t.Fatalf("want %d questions, got %d", Size, len(want))
        }
        for i := 0; i < 100; i++ {
                got := QuestionIDs("2026-09-07", "JAMB", ids)
                if strings.Join(got, ",") != strings.Join(want, ",") {
                        t.Fatalf("QuestionIDs drifted on call %d", i)
                }
        }
}

func TestQuestionIDsSubsetPermutation(t *testing.T) {
        ids := make([]string, 40)
        for i := range ids {
                ids[i] = fmt.Sprintf("q%02d", i)
        }
        got := QuestionIDs("2026-09-07", "JAMB", ids)
        if len(got) != Size {
                t.Fatalf("expected %d, got %d", Size, len(got))
        }
        seen := map[string]bool{}
        for _, id := range got {
                if seen[id] {
                        t.Fatalf("duplicate id %q in selection", id)
                }
                seen[id] = true
                if !contains(ids, id) {
                        t.Fatalf("foreign id %q not from the pack", id)
                }
        }
}

func TestQuestionIDsSmallPackServedWhole(t *testing.T) {
        ids := []string{"q1", "q2", "q3"}
        got := QuestionIDs("2026-09-07", "JAMB", ids)
        if len(got) != 3 {
                t.Fatalf("small pack should be served whole, got %d", len(got))
        }
        if !contains(got, "q1") || !contains(got, "q2") || !contains(got, "q3") {
                t.Fatalf("small pack lost questions: %v", got)
        }
}

func TestQuestionIDsVariesByDay(t *testing.T) {
        ids := make([]string, 20)
        for i := range ids {
                ids[i] = fmt.Sprintf("q%02d", i)
        }
        shapes := map[string]bool{}
        for d := 1; d <= 30; d++ {
                shapes[strings.Join(QuestionIDs(fmt.Sprintf("2026-09-%02d", d), "JAMB", ids), ",")] = true
        }
        if len(shapes) < 10 {
                t.Fatalf("challenge barely varies by day: %d distinct shapes over 30 days", len(shapes))
        }
}

func TestQuestionIDsEmpty(t *testing.T) {
        if got := QuestionIDs("2026-09-07", "JAMB", nil); got != nil {
                t.Fatalf("expected nil for empty pack, got %v", got)
        }
}

func TestIDsPreservesPackOrder(t *testing.T) {
        b := bundleWith("z-last", "a-first", "m-mid")
        got := IDs(b)
        if strings.Join(got, ",") != "z-last,a-first,m-mid" {
                t.Fatalf("IDs reordered the pack: %v", got)
        }
}

func contains(hay []string, needle string) bool {
        for _, s := range hay {
                if s == needle {
                        return true
                }
        }
        return false
}
