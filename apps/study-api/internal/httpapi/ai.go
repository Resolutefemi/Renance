// AI question generation (founder directive, 2026-09): the Gemini
// provider configured for the tutor also powers /ai/generate, the
// backend of the AI Generator page.
//
// POST /ai/generate  {topics: string[], difficulty: string, count: int}
//
//	→ {questions: [{stem, options, answer, explanation, topic, difficulty}]}
//
// The generated questions are PRACTICE MATERIAL, not exam banks: they
// are never scored server-side, never enter the manifest, and carry no
// user state. The student sees them with the correct answer + worked
// explanation inline — that is the feature. Generated sets are anchored
// to Nigerian senior-school / undergraduate syllabi phrasing so they
// read like the rest of Renance.
package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"renance.dev/study-api/internal/tutor"
)

type aiGenerateRequest struct {
	Topics     []string `json:"topics"`
	Difficulty string   `json:"difficulty"`
	Count      int      `json:"count"`
}

type aiGeneratedQuestion struct {
	Stem        string            `json:"stem"`
	Options     map[string]string `json:"options"`
	Answer      string            `json:"answer"`
	Explanation string            `json:"explanation,omitempty"`
	Topic       string            `json:"topic,omitempty"`
	Difficulty  string            `json:"difficulty,omitempty"`
}

type aiGenerateResponse struct {
	Questions []aiGeneratedQuestion `json:"questions"`
	Mode      string                `json:"mode"` // "ai" (hint mode never generates)
}

const (
	aiMaxQuestions = 10
	aiMaxTopics    = 5
)

func (s *Server) handleAIGenerate(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	if !s.limiter.allow("ai:user:" + uid) {
		w.Header().Set("Retry-After", "15")
		fail(w, http.StatusTooManyRequests, "rate_limited", "AI cooling down — retry in a few seconds")
		return
	}
	if s.tutor == nil || s.tutor.Provider == nil {
		fail(w, http.StatusServiceUnavailable, "ai_disabled",
			"AI generation is not configured on this deployment")
		return
	}

	var req aiGenerateRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	var topics []string
	for _, t := range req.Topics {
		t = strings.TrimSpace(t)
		if t != "" {
			topics = append(topics, t)
		}
		if len(topics) == aiMaxTopics {
			break
		}
	}
	if len(topics) == 0 {
		fail(w, http.StatusBadRequest, "invalid_topic", "pick at least one topic")
		return
	}
	for _, t := range topics {
		if len(t) > 80 {
			fail(w, http.StatusBadRequest, "invalid_topic", "topic too long (max 80 chars)")
			return
		}
	}
	difficulty := strings.TrimSpace(req.Difficulty)
	switch difficulty {
	case "Easy", "Medium", "Hard":
	default:
		difficulty = "Medium"
	}
	if req.Count <= 0 {
		req.Count = 5
	}
	if req.Count > aiMaxQuestions {
		req.Count = aiMaxQuestions
	}

	out, err := s.tutor.Provider.Complete(
		aiCtx(r),
		aiSystemPrompt(topics, difficulty, req.Count),
		[]tutor.Message{{Role: "user", Content: fmt.Sprintf(
			"Generate %d %s difficulty practice question(s) on: %s.",
			req.Count, strings.ToLower(difficulty), strings.Join(topics, ", "))}},
		// Room for the JSON: ~350 tokens per question, hard-capped.
		min(4096, 400*req.Count+120),
	)
	if err != nil {
		s.log.Error("ai generate", "err", err)
		fail(w, http.StatusBadGateway, "ai_failed",
			"The AI provider could not generate questions right now — try again shortly")
		return
	}
	questions, err := parseAIBatch(out, topics, difficulty)
	if err != nil {
		s.log.Error("ai generate parse", "err", err, "raw", truncateForLog(out))
		fail(w, http.StatusBadGateway, "ai_failed",
			"The AI reply was not usable — try again, maybe with a tighter topic")
		return
	}
	writeJSON(w, http.StatusOK, aiGenerateResponse{Questions: questions, Mode: "ai"})
}

// aiCtx bounds the provider call inside the request scope.
func aiCtx(r *http.Request) context.Context {
	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	context.AfterFunc(ctx, cancel)
	return ctx
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func truncateForLog(s string) string {
	if len(s) > 400 {
		return s[:400]
	}
	return s
}

func aiSystemPrompt(topics []string, difficulty string, count int) string {
	var b strings.Builder
	b.WriteString("You are Renance's exam-question writer for Nigerian students (JAMB, WAEC, NECO and university courses). ")
	b.WriteString("Write exam-standard multiple-choice questions in the style of real Nigerian past questions.\n\n")
	b.WriteString("OUTPUT FORMAT — return ONLY a JSON array, no prose, no code fences:\n")
	b.WriteString(`[{"stem":"…","options":{"A":"…","B":"…","C":"…","D":"…"},"answer":"B","explanation":"one or two sentences why"}, …]` + "\n\n")
	b.WriteString("RULES:\n")
	b.WriteString("- Exactly 4 options lettered A–D; exactly one is correct.\n")
	b.WriteString("- Distractors must be plausible (common misconceptions, near-misses).\n")
	b.WriteString("- Stems are self-contained: no references to figures, passages or prior questions.\n")
	b.WriteString("- Explanation teaches the shortest correct path, under 40 words, plain English.\n")
	b.WriteString(fmt.Sprintf("- Produce exactly %d question(s), %s difficulty, on: %s.\n",
		count, strings.ToLower(difficulty), strings.Join(topics, "; ")))
	return b.String()
}

// parseAIBatch extracts the JSON array from the model reply (models like
// to wrap it in prose or fences), then validates every question.
func parseAIBatch(raw string, topics []string, difficulty string) ([]aiGeneratedQuestion, error) {
	cut := strings.Index(raw, "[")
	end := strings.LastIndex(raw, "]")
	if cut < 0 || end <= cut {
		return nil, fmt.Errorf("no JSON array in reply")
	}
	var parsed []struct {
		Stem        string            `json:"stem"`
		Options     map[string]string `json:"options"`
		Answer      string            `json:"answer"`
		Explanation string            `json:"explanation"`
	}
	if err := json.Unmarshal([]byte(raw[cut:end+1]), &parsed); err != nil {
		return nil, fmt.Errorf("decode array: %w", err)
	}
	if len(parsed) == 0 {
		return nil, fmt.Errorf("empty array")
	}
	if len(parsed) > aiMaxQuestions {
		parsed = parsed[:aiMaxQuestions]
	}
	out := make([]aiGeneratedQuestion, 0, len(parsed))
	for _, p := range parsed {
		stem := strings.TrimSpace(p.Stem)
		if stem == "" || len(p.Options) < 2 {
			continue
		}
		answer := strings.ToUpper(strings.TrimSpace(p.Answer))
		if _, ok := p.Options[answer]; !ok {
			// model returned the answer TEXT instead of the letter
			for l, text := range p.Options {
				if strings.EqualFold(strings.TrimSpace(text), strings.TrimSpace(p.Answer)) {
					answer = l
					break
				}
			}
			if _, ok := p.Options[answer]; !ok {
				continue
			}
		}
		opts := map[string]string{}
		for l, text := range p.Options {
			l = strings.ToUpper(strings.TrimSpace(l))
			text = strings.TrimSpace(text)
			if len(l) == 1 && text != "" {
				opts[l] = text
			}
		}
		if len(opts) < 2 {
			continue
		}
		if _, ok := opts[answer]; !ok {
			continue
		}
		out = append(out, aiGeneratedQuestion{
			Stem:        stem,
			Options:     opts,
			Answer:      answer,
			Explanation: strings.TrimSpace(p.Explanation),
			Topic:       topics[0],
			Difficulty:  difficulty,
		})
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("no valid questions decoded")
	}
	return out, nil
}
