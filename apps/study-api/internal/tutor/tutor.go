// Package tutor (ROADMAP #9) — the Socratic AI tutor anchored to graded
// attempts.
//
// Two modes, one interface:
//
//   - AI mode: an OpenAI-compatible chat-completions endpoint (OpenAI,
//     OpenRouter, Groq, Gemini's OpenAI surface, vLLM...) configured via
//     AI_API_KEY / AI_BASE_URL / AI_MODEL. Prompt embeds the question,
//     the student's pick and the key, with Socratic coaching rules.
//   - Hint mode: a deterministic, zero-dependency fallback that cycles
//     exam-technique nudges (read-like-an-examiner, eliminate, qualifier
//     check, definition match) WITHOUT revealing the correct letter.
//     This is what runs until the founder drops an API key in.
//
// The tutor never sees PII beyond what the attempt already carries; the
// client supplies only the conversation turns.
package tutor

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sort"
	"strings"
	"time"
)

const (
	ModeAI   = "ai"
	ModeHint = "hint"
)

// Message is one conversation turn supplied by the client.
type Message struct {
	Role    string `json:"role"` // "user" | "assistant"
	Content string `json:"content"`
}

// AttemptContext is everything the tutor knows about the question being
// discussed. Picked and Correct are post-grade material — the review
// screen already shows them, so there is no leak here.
type AttemptContext struct {
	ExamTitle   string
	Code        string
	QuestionID  string
	Stem        string
	Topic       string
	Options     map[string]string
	Picked      string
	Correct     string
	Explanation string
}

// Reply is the tutor's answer and the mode that produced it.
type Reply struct {
	Text string `json:"text"`
	Mode string `json:"mode"`
}

// Provider is any backend that completes a chat.
type Provider interface {
	Complete(ctx context.Context, system string, msgs []Message, maxTokens int) (string, error)
}

// Tutor is the mode-aware front of the feature. A nil Provider keeps the
// product fully functional in hint mode — no key, no crash, no dead UI.
type Tutor struct {
	Provider  Provider
	MaxTokens int
	Log       *slog.Logger
}

// Reply answers the conversation. AI failures degrade to hint mode so a
// provider outage can never break the study loop mid-session.
func (t *Tutor) Reply(ctx context.Context, ac AttemptContext, msgs []Message) Reply {
	turn := userTurn(msgs)
	if t.Provider != nil {
		out, err := t.Provider.Complete(ctx, SystemPrompt(ac), msgs, t.MaxTokens)
		if err == nil && strings.TrimSpace(out) != "" {
			return Reply{Text: strings.TrimSpace(out), Mode: ModeAI}
		}
		if t.Log != nil {
			t.Log.Error("tutor provider failed — degrading to hint mode", "err", err)
		}
	}
	return Reply{Text: Hint(ac, turn), Mode: ModeHint}
}

func userTurn(msgs []Message) int {
	n := 0
	for _, m := range msgs {
		if m.Role == "user" {
			n++
		}
	}
	if n > 0 {
		n-- // zero-based coaching step
	}
	return n
}

// SystemPrompt embeds the question, the pick, the key and the coaching
// doctrine into one system string.
func SystemPrompt(ac AttemptContext) string {
	var b strings.Builder
	b.WriteString("You are Renance's Socratic exam tutor for Nigerian students (JAMB, WAEC, NECO and university courses). ")
	b.WriteString("A student is reviewing a question they got wrong and asking why. Coach, don't lecture.\n\n")
	b.WriteString("RULES:\n")
	b.WriteString("- Ask guiding questions before telling. On the student's THIRD ask or later, walk through the full reasoning to the answer.\n")
	b.WriteString("- Never just state the correct letter as your first sentence.\n")
	b.WriteString("- Keep every reply under 120 words, warm and plain-English. No markdown headings.\n")
	b.WriteString("- Reference the topic and their pick when it helps. End with one concrete next action.\n\n")
	fmt.Fprintf(&b, "EXAM: %s (%s)\n", ac.ExamTitle, ac.Code)
	if ac.Topic != "" {
		fmt.Fprintf(&b, "TOPIC: %s\n", ac.Topic)
	}
	fmt.Fprintf(&b, "QUESTION: %s\n", ac.Stem)
	letters := make([]string, 0, len(ac.Options))
	for l := range ac.Options {
		letters = append(letters, l)
	}
	sort.Strings(letters)
	for _, l := range letters {
		fmt.Fprintf(&b, "OPTION %s: %s\n", l, ac.Options[l])
	}
	fmt.Fprintf(&b, "STUDENT PICKED: %s\nCORRECT: %s\n", ac.Picked, ac.Correct)
	if ac.Explanation != "" {
		fmt.Fprintf(&b, "OFFICIAL EXPLANATION: %s\n", ac.Explanation)
	}
	return b.String()
}

// Hint is the deterministic coaching ladder. turn is zero-based over the
// user's asks in this conversation; it cycles after the last rung. Hints
// deliberately never name the correct letter — they teach the technique
// that finds it.
func Hint(ac AttemptContext, turn int) string {
	topic := ac.Topic
	if topic == "" {
		topic = "this part of " + subjectOf(ac)
	}
	picked := "your answer"
	if ac.Picked != "" {
		picked = "option " + strings.ToUpper(ac.Picked)
	}
	rungs := []string{
		"Let's read like an examiner. Before the options, say in one sentence what this question about " +
			topic + " is actually asking. Now: which option matches THAT sentence exactly?",
		"Eliminate the wild ones first. Cross out any option that adds a condition the stem never mentions, " +
			"or drops one it clearly does. Which two survive? Compare only those two.",
		"Recheck the qualifiers — always, only, most, least, best. Examiners hide the trap in one word. " +
			picked + " — does it survive those words, or does one of them break it?",
		"Match every option against the definition of " + topic + ". The right one states it exactly; " +
			"the distractors overstate, understate or swap a term. Reset, reread fresh, and commit.",
	}
	if turn < 0 {
		turn = 0
	}
	return rungs[turn%len(rungs)]
}

func subjectOf(ac AttemptContext) string {
	if ac.ExamTitle != "" {
		return ac.ExamTitle
	}
	return "the syllabus"
}

// OpenAICompat speaks the OpenAI chat-completions dialect against any
// compatible base URL.
type OpenAICompat struct {
	BaseURL string // e.g. https://api.openai.com/v1 (no trailing slash)
	APIKey  string
	Model   string
	HTTP    *http.Client // nil => 30s timeout default
}

type chatRequest struct {
	Model     string        `json:"model"`
	Messages  []chatMessage `json:"messages"`
	MaxTokens int           `json:"max_tokens,omitempty"`
	Temp      float64       `json:"temperature"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

func (p *OpenAICompat) Complete(ctx context.Context, system string, msgs []Message, maxTokens int) (string, error) {
	if maxTokens <= 0 {
		maxTokens = 320
	}
	reqMsgs := make([]chatMessage, 0, len(msgs)+1)
	reqMsgs = append(reqMsgs, chatMessage{Role: "system", Content: system})
	for _, m := range msgs {
		reqMsgs = append(reqMsgs, chatMessage{Role: m.Role, Content: m.Content})
	}
	payload, err := json.Marshal(chatRequest{
		Model:     p.Model,
		Messages:  reqMsgs,
		MaxTokens: maxTokens,
		Temp:      0.4,
	})
	if err != nil {
		return "", fmt.Errorf("tutor: encode request: %w", err)
	}
	hc := p.HTTP
	if hc == nil {
		hc = &http.Client{Timeout: 30 * time.Second}
	}
	url := strings.TrimRight(p.BaseURL, "/") + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return "", fmt.Errorf("tutor: request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+p.APIKey)
	res, err := hc.Do(req)
	if err != nil {
		return "", fmt.Errorf("tutor: provider call: %w", err)
	}
	defer res.Body.Close()
	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("tutor: read provider response: %w", err)
	}
	if res.StatusCode != http.StatusOK {
		return "", fmt.Errorf("tutor: provider status %d: %.200s", res.StatusCode, string(body))
	}
	var parsed chatResponse
	if err := json.Unmarshal(body, &parsed); err != nil {
		return "", fmt.Errorf("tutor: parse provider response: %w", err)
	}
	if parsed.Error != nil && parsed.Error.Message != "" {
		return "", fmt.Errorf("tutor: provider error: %s", parsed.Error.Message)
	}
	if len(parsed.Choices) == 0 {
		return "", fmt.Errorf("tutor: provider returned no choices")
	}
	return parsed.Choices[0].Message.Content, nil
}
