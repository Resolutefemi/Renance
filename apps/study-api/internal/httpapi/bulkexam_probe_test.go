package httpapi

// Local probe for the bulk exam pour: replays a real corpus chunk
// through the same decode + skip logic (minus the DB write) and prints
// where rows would die. Run with:
//   go test ./internal/httpapi/ -run TestProbeBulkExam -v

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestProbeBulkExam(t *testing.T) {
	path := os.Getenv("PROBE_CORPUS")
	if path == "" {
		t.Skip("set PROBE_CORPUS to a corpus json")
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var corpus struct {
		Band      string `json:"band"`
		Term      int    `json:"term"`
		Questions []struct {
			Question    string   `json:"question"`
			Options     []string `json:"options"`
			AnswerIndex int      `json:"answerIndex"`
			Explanation string   `json:"explanation"`
			Marks       int      `json:"marks"`
			Source      string   `json:"source"`
			SourceURL   string   `json:"sourceUrl"`
		} `json:"questions"`
	}
	if err := json.Unmarshal(raw, &corpus); err != nil {
		t.Fatalf("corpus decode: %v", err)
	}
	// Re-marshal exactly like the pour does, then decode with
	// DisallowUnknownFields like decodeJSON does.
	body, _ := json.Marshal(map[string]any{
		"subjectId": "00000000-0000-0000-0000-000000000000",
		"band":      corpus.Band,
		"term":      corpus.Term,
		"session":   "",
		"source":    "classbasic.com",
		"questions": corpus.Questions,
	})
	var req struct {
		SubjectID string `json:"subjectId"`
		Band      string `json:"band"`
		Term      int    `json:"term"`
		Session   string `json:"session"`
		Source    string `json:"source"`
		Questions []struct {
			Question    string   `json:"question"`
			Options     []string `json:"options"`
			AnswerIndex int      `json:"answerIndex"`
			Explanation string   `json:"explanation"`
			Marks       int      `json:"marks"`
			Source      string   `json:"source"`
			SourceURL   string   `json:"sourceUrl"`
		} `json:"questions"`
	}
	dec := json.NewDecoder(strings.NewReader(string(body)))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		t.Fatalf("decode with disallow: %v", err)
	}
	skipped := map[string]int{}
	would := 0
	for i := range req.Questions {
		q := &req.Questions[i]
		q.Question = stripDoubleDashes(strings.TrimSpace(q.Question))
		q.Explanation = stripDoubleDashes(strings.TrimSpace(q.Explanation))
		if q.Question == "" {
			skipped["empty question"]++
			continue
		}
		cleaned := make([]string, 0, len(q.Options))
		for _, o := range q.Options {
			o = stripDoubleDashes(strings.TrimSpace(o))
			if o == "" || len(o) > 400 {
				continue
			}
			cleaned = append(cleaned, o)
		}
		if len(cleaned) < 2 || len(cleaned) > 6 {
			skipped["options"]++
			continue
		}
		would++
	}
	t.Logf("received=%d would_write=%d skipped=%v", len(req.Questions), would, skipped)
}
