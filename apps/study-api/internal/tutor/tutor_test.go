package tutor

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func sampleAC() AttemptContext {
	return AttemptContext{
		ExamTitle:   "JAMB Biology — Practice Mock",
		Code:        "jamb-biology-mock",
		QuestionID:  "bio-001",
		Stem:        "Which organelle releases energy from glucose?",
		Topic:       "The Cell",
		Options:     map[string]string{"A": "Ribosome", "B": "Mitochondrion", "C": "Nucleus", "D": "Vacuole"},
		Picked:      "A",
		Correct:     "B",
		Explanation: "The mitochondrion is the site of aerobic respiration.",
	}
}

type fakeProvider struct {
	out     string
	err     error
	gotSys  string
	gotMsgs []Message
	gotMax  int
}

func (f *fakeProvider) Complete(ctx context.Context, system string, msgs []Message, maxTokens int) (string, error) {
	f.gotSys, f.gotMsgs, f.gotMax = system, msgs, maxTokens
	if f.err != nil {
		return "", f.err
	}
	return f.out, nil
}

func TestHintLadderNeverRevealsTheLetter(t *testing.T) {
	ac := sampleAC()
	for turn := 0; turn < 12; turn++ {
		h := Hint(ac, turn)
		if h == "" {
			t.Fatalf("turn %d produced an empty hint", turn)
		}
		if strings.Contains(strings.ToUpper(h), "OPTION B") && turn < 100 {
			// hint mode must teach technique, not the answer
			t.Fatalf("turn %d hint leaked the correct letter: %s", turn, h)
		}
		if !strings.Contains(h, " ") {
			t.Fatalf("turn %d hint is not a sentence", turn)
		}
	}
	// ladder cycles rather than repeating rung 0 forever
	if Hint(ac, 0) == Hint(ac, 1) {
		t.Fatal("hint ladder does not advance between turns")
	}
	if Hint(ac, 0) != Hint(ac, 4) {
		t.Fatal("hint ladder should cycle after the last rung")
	}
}

func TestHintWithoutTopicFallsBackToExamTitle(t *testing.T) {
	ac := sampleAC()
	ac.Topic = ""
	h := Hint(ac, 0)
	if !strings.Contains(h, "JAMB Biology") {
		t.Fatalf("fallback hint should reference the exam, got: %s", h)
	}
}

func TestReplyUsesAIWhenProviderHealthy(t *testing.T) {
	fp := &fakeProvider{out: "Let's think it through: what does the mitochondrion do?"}
	tut := &Tutor{Provider: fp, MaxTokens: 200}
	reply := tut.Reply(context.Background(), sampleAC(), []Message{{Role: "user", Content: "why is this wrong?"}})
	if reply.Mode != ModeAI {
		t.Fatalf("mode = %s, want ai", reply.Mode)
	}
	if reply.Text != fp.out {
		t.Fatalf("reply text mismatch")
	}
	if fp.gotMax != 200 {
		t.Fatalf("max tokens not forwarded")
	}
	sys := fp.gotSys
	for _, want := range []string{"JAMB Biology", "STUDENT PICKED: A", "CORRECT: B", "OFFICIAL EXPLANATION"} {
		if !strings.Contains(sys, want) {
			t.Fatalf("system prompt missing %q", want)
		}
	}
}

func TestReplyDegradesToHintOnProviderError(t *testing.T) {
	fp := &fakeProvider{err: errors.New("boom")}
	tut := &Tutor{Provider: fp}
	reply := tut.Reply(context.Background(), sampleAC(), []Message{{Role: "user", Content: "why?"}})
	if reply.Mode != ModeHint {
		t.Fatalf("mode = %s, want hint after provider failure", reply.Mode)
	}
	if reply.Text == "" {
		t.Fatal("degraded reply must still coach")
	}
}

func TestReplyDegradesWhenProviderReturnsBlank(t *testing.T) {
	fp := &fakeProvider{out: "   "}
	tut := &Tutor{Provider: fp}
	reply := tut.Reply(context.Background(), sampleAC(), []Message{{Role: "user", Content: "why?"}})
	if reply.Mode != ModeHint {
		t.Fatalf("mode = %s, want hint on blank provider output", reply.Mode)
	}
}

func TestUserTurnCounts(t *testing.T) {
	cases := []struct {
		msgs []Message
		want int
	}{
		{[]Message{{Role: "user", Content: "a"}}, 0},
		{[]Message{{Role: "user", Content: "a"}, {Role: "assistant", Content: "b"}, {Role: "user", Content: "c"}}, 1},
		{[]Message{{Role: "assistant", Content: "b"}, {Role: "user", Content: "c"}}, 0},
	}
	for i, c := range cases {
		if got := userTurn(c.msgs); got != c.want {
			t.Fatalf("case %d: userTurn = %d, want %d", i, got, c.want)
		}
	}
}

func TestOpenAICompatAgainstFakeServer(t *testing.T) {
	var gotPath, gotAuth string
	var gotBody chatRequest
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotAuth = r.Header.Get("Authorization")
		_ = json.NewDecoder(r.Body).Decode(&gotBody)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"choices":[{"message":{"content":"Coach says: eliminate first."}}]}`))
	}))
	defer srv.Close()

	p := &OpenAICompat{BaseURL: srv.URL, APIKey: "sk-test", Model: "test-model"}
	out, err := p.Complete(context.Background(), "system-prompt",
		[]Message{{Role: "user", Content: "hi"}}, 150)
	if err != nil {
		t.Fatalf("Complete: %v", err)
	}
	if out != "Coach says: eliminate first." {
		t.Fatalf("out = %q", out)
	}
	if gotPath != "/chat/completions" {
		t.Fatalf("path = %s", gotPath)
	}
	if gotAuth != "Bearer sk-test" {
		t.Fatalf("auth = %s", gotAuth)
	}
	if gotBody.Model != "test-model" || gotBody.MaxTokens != 150 || gotBody.Temp != 0.4 {
		t.Fatalf("payload mismatch: %+v", gotBody)
	}
	if len(gotBody.Messages) != 2 || gotBody.Messages[0].Role != "system" {
		t.Fatalf("messages = %+v", gotBody.Messages)
	}
}

func TestOpenAICompatSurfacesProviderErrors(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`{"error":{"message":"quota exceeded"}}`))
	}))
	defer srv.Close()
	p := &OpenAICompat{BaseURL: srv.URL, APIKey: "k", Model: "m"}
	if _, err := p.Complete(context.Background(), "s", nil, 0); err == nil {
		t.Fatal("expected an error on 429")
	} else if !strings.Contains(err.Error(), "quota") {
		t.Fatalf("error should carry provider message, got %v", err)
	}
}

func TestSystemPromptOptionsAreSorted(t *testing.T) {
	sys := SystemPrompt(sampleAC())
	iA := strings.Index(sys, "OPTION A")
	iB := strings.Index(sys, "OPTION B")
	iC := strings.Index(sys, "OPTION C")
	iD := strings.Index(sys, "OPTION D")
	if !(iA < iB && iB < iC && iC < iD) {
		t.Fatalf("options not emitted in stable order: %d %d %d %d", iA, iB, iC, iD)
	}
}
