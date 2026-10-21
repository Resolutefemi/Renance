// The AI bridge (founder directive, 2026-09-30): give Renance AI live
// access to the full past-question corpus, all ~207,000 real questions
// across 681 banks (JAMB, WAEC, NECO, Post-UTME, university modules).
//
// Three jobs:
//
//   - bridgeSearch: keyword scan over the in-memory library, exam-core
//     bodies first (JAMB, WAEC, NECO, Post-UTME before university
//     modules), returning real past questions WITH their answers and
//     explanations from the server-only key map. This is what the AI
//     "Researching past questions" phase shows and what generation is
//     grounded on, so generated material reads like the real thing.
//   - bridgeGrounding: a bounded text block of matched past questions
//     for the model's context window.
//   - GET /ai/bridge/search + /ai/bridge/stats: the HTTP surface.
//
// Scans are budget-capped (questions examined and wall clock) so a
// broad one-word query can never pin the CPU on Render's free tier.
package httpapi

import (
	"net/http"
	"sort"
	"strings"
	"time"
)

const (
	bridgeDefaultLimit = 8
	bridgeMaxLimit     = 20
	// bridgeScanBudget: questions examined per search, worst case. Now
	// above the full corpus size (founder directive 2026-10-02: the AI
	// must have access to ALL the past-questions JSON) - the wall-clock
	// budget below stays the real guard against CPU pinning.
	bridgeScanBudget = 260000
	bridgeTimeBudget = 400 * time.Millisecond
	// bridgeGroundBytes caps the grounding block handed to the model.
	// Kept tight (founder deployment reality: GLM-4.5-Flash free tier
	// answers in 15-25s; every extra KB of prompt pushes the call past
	// Render's ~30s proxy wall and the student sees a naked 502).
	bridgeGroundBytes = 3584
	// bridgeGroundQuestions: past questions embedded in one grounding
	// block, spread across the requested topics; the byte cap above
	// still bounds the block.
	bridgeGroundQuestions = 6
	// bridgeGroupCap: max query groups (topics) one grounding considers.
	bridgeGroupCap = 4
	// bridgeLooseCap bounds the loose-candidate buffer during a scan.
	bridgeLooseCap = 64
)

// bridgeBodyOrder puts the exam-prep core before the long tail.
var bridgeBodyOrder = []string{"JAMB", "WAEC", "NECO", "POST-UTME"}

// BridgeQuestion is one real past question with its answer material.
type BridgeQuestion struct {
	Exam        string            `json:"exam"`
	Code        string            `json:"code"`
	Body        string            `json:"body"`
	Year        int               `json:"year,omitempty"`
	ID          string            `json:"id"`
	Stem        string            `json:"stem"`
	Options     map[string]string `json:"options,omitempty"`
	Answer      string            `json:"answer,omitempty"`
	Explanation string            `json:"explanation,omitempty"`
}

type bridgeSearchResponse struct {
	Questions []BridgeQuestion `json:"questions"`
	Total     int              `json:"total"`   // matches found before the limit cut
	Scanned   int              `json:"scanned"` // questions examined
}

type bridgeStatsResponse struct {
	Exams     int `json:"exams"`
	Questions int `json:"questions"`
}

// handleBridgeStats serves GET /ai/bridge/stats - the corpus size the
// UI quotes ("trained on 206,000+ real past questions").
func (s *Server) handleBridgeStats(w http.ResponseWriter, r *http.Request) {
	if s.lib == nil {
		writeJSON(w, http.StatusOK, bridgeStatsResponse{})
		return
	}
	m := s.lib.Manifest()
	total := 0
	for _, ex := range m.Exams {
		total += ex.QuestionCount
	}
	writeJSON(w, http.StatusOK, bridgeStatsResponse{Exams: len(m.Exams), Questions: total})
}

// handleBridgeSearch serves GET /ai/bridge/search?q=&body=&limit=.
func (s *Server) handleBridgeSearch(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	if !s.limiter.allow("ai:user:" + uid) {
		w.Header().Set("Retry-After", "15")
		fail(w, http.StatusTooManyRequests, "rate_limited", "AI cooling down, retry in a few seconds")
		return
	}
	if !requireStandard(w, s.tierRank(r, uid)) {
		return
	}
	if s.lib == nil {
		writeJSON(w, http.StatusOK, bridgeSearchResponse{})
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		fail(w, http.StatusBadRequest, "bad_query", "q is required")
		return
	}
	if len(q) > 200 {
		q = q[:200]
	}
	body := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("body")))
	limit := bridgeDefaultLimit
	if v := r.URL.Query().Get("limit"); v != "" {
		if parsed := parseIntClamp(v, 1, bridgeMaxLimit); parsed > 0 {
			limit = parsed
		}
	}
	questions, total, scanned := s.bridgeSearch(q, body, limit)
	writeJSON(w, http.StatusOK, bridgeSearchResponse{Questions: questions, Total: total, Scanned: scanned})
}

func parseIntClamp(s string, lo, hi int) int {
	n := 0
	for _, c := range strings.TrimSpace(s) {
		if c < '0' || c > '9' {
			return 0
		}
		n = n*10 + int(c-'0')
		if n > hi {
			return hi
		}
	}
	if n < lo {
		return 0
	}
	return n
}

// bridgeScanUnit is one bundle queued for scanning.
type bridgeScanUnit struct {
	code  string
	title string
	body  string
	score int // lower scans first
}

// bridgeScanQueue orders the banks for scanning: exam-prep core first,
// a bank whose title matches any keyword jumps the queue.
func (s *Server) bridgeScanQueue(keywords []string, body string) []bridgeScanUnit {
	manifest := s.lib.Manifest()
	queue := make([]bridgeScanUnit, 0, len(manifest.Exams))
	for _, ex := range manifest.Exams {
		if body != "" && ex.Body != body {
			continue
		}
		score := 10
		for i, b := range bridgeBodyOrder {
			if ex.Body == b {
				score = i
				break
			}
		}
		if ex.Body == "University Modules" {
			score = 20
		}
		lowerTitle := strings.ToLower(ex.Title + " " + ex.Code)
		for _, k := range keywords {
			if strings.Contains(lowerTitle, k) {
				score -= 5 // a bank named for the subject scans first
				break
			}
		}
		queue = append(queue, bridgeScanUnit{code: ex.Code, title: ex.Title, body: ex.Body, score: score})
	}
	sort.SliceStable(queue, func(i, j int) bool { return queue[i].score < queue[j].score })
	return queue
}

// bridgeSearch scans the library for real past questions whose stem (or
// options) mention every keyword of the query. Exam-core bodies scan
// first; a bundle whose title matches a keyword jumps the queue.
func (s *Server) bridgeSearch(query, body string, limit int) ([]BridgeQuestion, int, int) {
	if limit <= 0 {
		limit = bridgeDefaultLimit
	}
	keywords := splitKeywords(query)
	if len(keywords) == 0 {
		return nil, 0, 0
	}
	queue := s.bridgeScanQueue(keywords, body)

	var (
		out      []BridgeQuestion
		total    int
		scanned  int
		deadline = time.Now().Add(bridgeTimeBudget)
	)
	for _, unit := range queue {
		if scanned >= bridgeScanBudget || time.Now().After(deadline) {
			break
		}
		b, ok := s.lib.Bundle(unit.code)
		if !ok {
			continue
		}
		keys, _ := s.lib.KeysFor(unit.code)
		for i := range b.Questions {
			scanned++
			if total >= limit && scanned >= bridgeScanBudget {
				break
			}
			q := &b.Questions[i]
			hay := strings.ToLower(q.Stem)
			if !containsAll(hay, keywords) {
				continue
			}
			total++
			if total > limit {
				if scanned >= bridgeScanBudget || time.Now().After(deadline) {
					break
				}
				continue
			}
			bq := BridgeQuestion{
				Exam:    unit.title,
				Code:    unit.code,
				Body:    unit.body,
				Year:    q.Year,
				ID:      q.ID,
				Stem:    q.Stem,
				Options: q.Options,
			}
			if k, ok := keys[q.ID]; ok {
				bq.Answer = k.Letter
				bq.Explanation = k.Explanation
			}
			out = append(out, bq)
		}
		if total > limit*4 && unit.score > 15 {
			break // enough from the long tail
		}
	}
	return out, total, scanned
}

// splitKeywords cuts a query into lowercase keywords, dropping filler
// words students naturally type ("questions on photosynthesis in jamb").
func splitKeywords(query string) []string {
	stop := map[string]bool{
		"the": true, "a": true, "an": true, "of": true, "on": true, "in": true,
		"for": true, "to": true, "and": true, "or": true, "about": true,
		"questions": true, "question": true, "past": true, "me": true,
		"my": true, "quiz": true, "notes": true, "note": true, "with": true,
		"give": true, "show": true, "find": true, "jamb": true, "waec": true,
		"neco": true, "utme": true, "exam": true, "exams": true, "please": true,
	}
	var out []string
	seen := map[string]bool{}
	for _, w := range strings.Fields(strings.ToLower(query)) {
		w = strings.Trim(w, ".,!?;:'\"()")
		if w == "" || len(w) < 2 || stop[w] || seen[w] {
			continue
		}
		seen[w] = true
		out = append(out, w)
		if len(out) >= 6 {
			break
		}
	}
	return out
}

func containsAll(hay string, keywords []string) bool {
	for _, k := range keywords {
		if !strings.Contains(hay, k) {
			return false
		}
	}
	return true
}

// looseMatch is a fallback candidate: a stem that shares only some of
// the keywords, ranked by how many it shares.
type looseMatch struct {
	q    BridgeQuestion
	hits int
}

// bridgeGroupSearch scans the library ONCE for every query group (one
// group per requested topic; a chat message is a single group). A stem
// is a STRICT match when it contains ALL keywords of any one group; a
// stem that shares only some keywords becomes a loose candidate, used
// when the strict harvest is thin so natural-language chat messages
// still ground on the closest real questions instead of nothing.
//
// This is the fix behind "make sure the AI has access to all the past
// questions JSON" (founder directive 2026-10-02): the old grounding
// joined every topic into one query, so a stem had to contain ALL
// topics' keywords at once and multi-topic quizzes / long chat messages
// grounded on NOTHING.
func (s *Server) bridgeGroupSearch(groups [][]string, body string, limit int) []BridgeQuestion {
	if limit <= 0 {
		limit = bridgeGroundQuestions
	}
	flat := make([]string, 0, 16)
	for _, g := range groups {
		flat = append(flat, g...)
	}
	queue := s.bridgeScanQueue(flat, body)

	strict := make([][]BridgeQuestion, len(groups))
	loose := make([]looseMatch, 0, bridgeLooseCap)
	scanned := 0
	deadline := time.Now().Add(bridgeTimeBudget)
	pushLoose := func(m looseMatch) {
		if len(loose) < bridgeLooseCap {
			loose = append(loose, m)
			return
		}
		worst := 0
		for i := 1; i < len(loose); i++ {
			if loose[i].hits < loose[worst].hits {
				worst = i
			}
		}
		if m.hits > loose[worst].hits {
			loose[worst] = m
		}
	}

outer:
	for _, unit := range queue {
		if scanned >= bridgeScanBudget || time.Now().After(deadline) {
			break
		}
		b, ok := s.lib.Bundle(unit.code)
		if !ok {
			continue
		}
		keys, _ := s.lib.KeysFor(unit.code)
		for i := range b.Questions {
			scanned++
			if scanned >= bridgeScanBudget || time.Now().After(deadline) {
				break outer
			}
			q := &b.Questions[i]
			hay := strings.ToLower(q.Stem)
			g := -1
			for gi, group := range groups {
				if containsAll(hay, group) {
					g = gi
					break
				}
			}
			hits := 0
			if g < 0 {
				for _, k := range flat {
					if strings.Contains(hay, k) {
						hits++
					}
				}
				if hits == 0 {
					continue
				}
			}
			bq := BridgeQuestion{
				Exam:    unit.title,
				Code:    unit.code,
				Body:    unit.body,
				Year:    q.Year,
				ID:      q.ID,
				Stem:    q.Stem,
				Options: q.Options,
			}
			if k, ok := keys[q.ID]; ok {
				bq.Answer = k.Letter
				bq.Explanation = k.Explanation
			}
			if g >= 0 {
				strict[g] = append(strict[g], bq)
			} else {
				pushLoose(looseMatch{q: bq, hits: hits})
			}
		}
	}
	return mergeGroupMatches(strict, loose, limit)
}

// mergeGroupMatches interleaves the strict harvest round-robin across
// groups (every topic gets a share before anyone gets seconds), fills
// with the leftovers, and tops up from the loose buffer only when the
// strict harvest is thin (fewer than 3 real matches).
func mergeGroupMatches(strict [][]BridgeQuestion, loose []looseMatch, limit int) []BridgeQuestion {
	if limit <= 0 {
		limit = bridgeGroundQuestions
	}
	strictTotal := 0
	for _, g := range strict {
		strictTotal += len(g)
	}
	if strictTotal == 0 && len(loose) == 0 {
		return nil
	}
	sort.SliceStable(loose, func(i, j int) bool { return loose[i].hits > loose[j].hits })

	out := make([]BridgeQuestion, 0, limit)
	seen := make(map[string]bool, limit)
	add := func(q BridgeQuestion) bool {
		if seen[q.ID] || len(out) >= limit {
			return false
		}
		seen[q.ID] = true
		out = append(out, q)
		return true
	}

	// Round-robin: topic 1's best, topic 2's best, ... then seconds.
rounds:
	for round := 0; ; round++ {
		took := false
		for _, g := range strict {
			if round < len(g) {
				if !add(g[round]) {
					break rounds
				}
				took = true
			}
		}
		if !took || len(out) >= limit {
			break
		}
	}
	// Fill from whatever each group has left.
fill:
	for _, g := range strict {
		for _, q := range g {
			if len(out) >= limit {
				break fill
			}
			add(q)
		}
	}
	// Loose top-up only when strict is thin (natural-language queries).
	if strictTotal < 3 {
		for _, m := range loose {
			if len(out) >= limit {
				break
			}
			add(m.q)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

// bridgeGrounding renders matched past questions as a bounded context
// block for the model. Each entry of queries is one topic (a chat
// message arrives as a single-entry slice); body optionally narrows.
// Returns the block and the number of past questions grounded.
func (s *Server) bridgeGrounding(queries []string, body string) (string, int) {
	if s.lib == nil || len(queries) == 0 {
		return "", 0
	}
	groups := make([][]string, 0, len(queries))
	for _, q := range queries {
		if len(groups) >= bridgeGroupCap {
			break
		}
		if ks := splitKeywords(q); len(ks) > 0 {
			groups = append(groups, ks)
		}
	}
	if len(groups) == 0 {
		return "", 0
	}
	qs := s.bridgeGroupSearch(groups, body, bridgeGroundQuestions)
	if len(qs) == 0 {
		return "", 0
	}
	total := s.bridgeTotalQuestions()
	var b strings.Builder
	b.WriteString("REAL PAST QUESTIONS from Renance's corpus (")
	b.WriteString(itoa(total))
	b.WriteString(" questions, ")
	b.WriteString(itoa(len(s.lib.Manifest().Exams)))
	b.WriteString(" banks). ")
	b.WriteString("Study these to match the exact phrasing, difficulty and style of Nigerian examiners. ")
	b.WriteString("You may teach with them, quote them and build quizzes in their image:\n\n")
	for i, q := range qs {
		b.WriteString("[PAST QUESTION ")
		b.WriteString(itoa(i + 1))
		b.WriteString(" of ")
		b.WriteString(itoa(len(qs)))
		b.WriteString("] (")
		b.WriteString(q.Exam)
		if q.Year > 0 {
			b.WriteString(", ")
			b.WriteString(itoa(q.Year))
		}
		b.WriteString("):\n")
		b.WriteString(q.Stem)
		b.WriteByte('\n')
		if len(q.Options) > 0 {
			letters := sortedLetters(q.Options)
			for _, l := range letters {
				b.WriteString(l + ". " + q.Options[l] + "  ")
			}
			b.WriteByte('\n')
		}
		if q.Answer != "" {
			b.WriteString("Correct: " + q.Answer)
			if q.Explanation != "" {
				b.WriteString(" - " + q.Explanation)
			}
			b.WriteByte('\n')
		}
		if b.Len() > bridgeGroundBytes {
			break
		}
	}
	out := b.String()
	if len(out) > bridgeGroundBytes {
		out = out[:bridgeGroundBytes]
	}
	return out, len(qs)
}

func sortedLetters(m map[string]string) []string {
	letters := make([]string, 0, len(m))
	for l := range m {
		letters = append(letters, l)
	}
	sort.Strings(letters)
	return letters
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [12]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}

// bridgeTotalQuestions is the corpus size for copy and prompts.
func (s *Server) bridgeTotalQuestions() int {
	if s.lib == nil {
		return 0
	}
	total := 0
	for _, ex := range s.lib.Manifest().Exams {
		total += ex.QuestionCount
	}
	return total
}
