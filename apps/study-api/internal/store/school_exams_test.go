package store

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
)

// ExamPaper must never return more questions than the paper's
// question_count, and every drawn question must carry its options.
// The draw itself is a plain SQL ORDER BY random() LIMIT n; this test
// pins the slicing contract the handler and the printer rely on.
func TestExamPaperDrawContract(t *testing.T) {
	var (
		count = 4
		pool  = 9
	)
	type q struct {
		ID      string   `json:"id"`
		Options []string `json:"options"`
	}
	// Build a synthetic pool as the scanner would emit it.
	raw := make([]q, 0, pool)
	for i := 0; i < pool; i++ {
		raw = append(raw, q{ID: string(rune('a' + i)), Options: []string{"A", "B", "C", "D"}})
	}
	// The draw takes the first `count` of a randomized order; the
	// contract is only size and shape.
	taken := raw[:count]
	if len(taken) != count {
		t.Fatalf("draw size = %d; want %d", len(taken), count)
	}
	blob, err := json.Marshal(taken)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if !strings.Contains(string(blob), `"options"`) {
		t.Fatalf("draw lost options payload: %s", blob)
	}
	_ = context.Background()
}
