// Daily challenge (ROADMAP #20): one deterministic 10-question sprint
// per exam body per UTC day. The selection is a pure function of (day,
// body, library) - internal/daily - so every student worldwide plays
// the same questions in the same order, which is what makes the
// per-day board a fair race. The sprint itself flows through the
// ordinary /attempts pipeline (adaptive, grading, review all apply);
// only the marker on the attempt and the ledger seat are new.
package httpapi

import (
	"net/http"
	"sort"
	"strings"
	"time"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/daily"
	"renance.dev/study-api/internal/store"
)

// todayUTC is the challenge clock: one UTC day, same for everyone.
func todayUTC() string { return time.Now().UTC().Format("2006-01-02") }

// dailyDayString renders an attempt's daily marker as the "YYYY-MM-DD"
// string the ledger keys on; nil (ordinary paper) stays empty.
func dailyDayString(d *time.Time) string {
	if d == nil {
		return ""
	}
	return d.UTC().Format("2006-01-02")
}

// parseDay validates the ?day= query on the leaderboard. Empty means
// "today" (the caller substitutes); anything unparseable is a 400,
// never a silent fallback - same contract as boardPeriod.
func dailyDayParam(raw string) (string, bool) {
	if raw == "" {
		return "", true
	}
	t, err := time.Parse("2006-01-02", raw)
	if err != nil {
		return "", false
	}
	return t.Format("2006-01-02"), true
}

// dailyPool canonical-matches the path's body against the loaded packs.
// Matching is case-insensitive so /daily/jamb works; the canonical
// spelling (e.g. "JAMB", "University Modules") is what gets stored and
// echoed back, keeping the ledger's body column uniform.
func (s *Server) dailyPool(rawBody string) []*cbtdata.Bundle {
	return s.lib.BundlesByBody(rawBody)
}

// dailySubjects sanitises the stored combination: lowercase slug shapes
// only, deduped, at most 9 (a WAEC wrist's worth). Order is canonical
// (sorted) - custom paper codes demand it, and a stable order keeps the
// composed code (and therefore the whole attempt pipeline) reproducible.
func dailySubjects(raw []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(raw))
	for _, s := range raw {
		s = strings.ToLower(strings.TrimSpace(s))
		if s == "" || len(s) > 40 {
			continue
		}
		valid := true
		for _, r := range s {
			if (r < 'a' || r > 'z') && (r < '0' || r > '9') && r != '-' {
				valid = false
				break
			}
		}
		if !valid {
			continue
		}
		if _, dup := seen[s]; dup {
			continue
		}
		seen[s] = struct{}{}
		out = append(out, s)
	}
	sort.Strings(out)
	if len(out) > 9 {
		out = out[:9]
	}
	return out
}

// dailyCustomCode derives the composed-paper code for a subject
// combination: <body>-custom-<sorted slugs>~n=10.t=15 - a 10-question
// sprint on a 15-minute clock, composed from that body's own banks by
// the ordinary custom-paper machinery. ok is false when the body has no
// custom family (University Modules, POST-UTME) or the combination is
// empty after sanitisation; callers fall back to the classic sprint.
func dailyCustomCode(canonicalBody string, subjects []string) (string, bool) {
	var prefix string
	switch canonicalBody {
	case "JAMB":
		prefix = "jamb-custom-"
	case "WAEC":
		prefix = "waec-custom-"
	case "NECO":
		prefix = "neco-custom-"
	default:
		return "", false
	}
	slugs := dailySubjects(subjects)
	if len(slugs) == 0 {
		return "", false
	}
	return prefix + strings.Join(slugs, "-") + "~n=10.t=15", true
}

// callerDailySubjects resolves the calling student's stored combination
// (empty when the profile has none - the daily then stays classic).
func (s *Server) callerDailySubjects(r *http.Request, uid string) []string {
	profile, err := s.store.ProfileByUser(r.Context(), uid)
	if err != nil || profile == nil {
		return nil
	}
	return dailySubjects(profile.Subjects)
}

// dailyPack returns the day's challenge pack for an already-matched
// body pool (PickCode always lands on a pool member).
func dailyPack(day string, pool []*cbtdata.Bundle) *cbtdata.Bundle {
	codes := make([]string, len(pool))
	for i, b := range pool {
		codes[i] = b.Code
	}
	code := daily.PickCode(day, pool[0].Body, codes)
	for _, b := range pool {
		if b.Code == code {
			return b
		}
	}
	return pool[0] // unreachable; keeps the compiler honest
}

// handleDaily serves GET /daily/{body}: today's challenge with the
// questions in play order, ready for POST /attempts {code, daily:true}.
func (s *Server) handleDaily(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	pool := s.dailyPool(r.PathValue("body"))
	if len(pool) == 0 {
		fail(w, http.StatusNotFound, "unknown_body",
			"no packs for this exam body; available: "+strings.Join(s.lib.Bodies(), ", "))
		return
	}
	body := pool[0].Body
	day := todayUTC()

	// Subject combination (founder rule): when the student picked one,
	// the daily sprint composes ONLY their subjects - a deterministic
	// <body>-custom paper seeded by the same compose machinery the
	// custom practice flow uses, so grading/resume/review all see an
	// ordinary bundle. No combination (or a body without per-subject
	// banks) keeps the classic single-pack sprint.
	bundle := dailyPack(day, pool)
	var combo []string
	if profile, perr := s.store.ProfileByUser(r.Context(), uid); perr == nil && profile != nil {
		combo = dailySubjects(profile.Subjects)
	}
	subjectsUsed := []string(nil)
	if code, ok := dailyCustomCode(body, combo); ok {
		if b, good := s.ensurePaperRequest(r, code); good {
			bundle = b
			subjectsUsed = combo
		}
	}

	ids := daily.QuestionIDs(day, body, daily.IDs(bundle))
	questions := make([]cbtdata.Question, 0, len(ids))
	marks := 0
	for _, id := range ids {
		q, ok := bundle.Question(id)
		if !ok {
			// Cannot happen: the selection draws from this bundle.
			continue
		}
		questions = append(questions, q)
		marks += q.Marks
	}

	// The student's seated result (null until their first graded daily
	// submission lands) rides along so the client can show "done today"
	// without a second call.
	var me *store.DailyResult
	if me, err = s.store.DailyResultFor(r.Context(), day, body, uid); err != nil {
		s.log.Error("daily result", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load today's challenge")
		return
	}

	resp := map[string]any{
		"day":  day,
		"body": body,
		"code": bundle.Code,
		// The quiz name, not the plumbing: whether today's sprint
		// rides a composed custom paper or a rotating static pack,
		// every client head reads "Daily Quiz".
		"title":           "Daily Quiz",
		"questionCount":   len(questions),
		"totalMarks":      marks,
		"durationMinutes": bundle.DurationMinutes,
		"questions":       questions,
		"myResult":        me,
	}
	if subjectsUsed != nil {
		resp["subjects"] = subjectsUsed
	}
	writeJSON(w, http.StatusOK, resp)
}

// handleDailyLeaderboard serves GET /daily/{body}/leaderboard?day=:
// the top 25 of one UTC day's challenge plus the caller's absolute
// rank, exactly like the arena/XP boards.
func (s *Server) handleDailyLeaderboard(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	pool := s.dailyPool(r.PathValue("body"))
	if len(pool) == 0 {
		fail(w, http.StatusNotFound, "unknown_body",
			"no packs for this exam body; available: "+strings.Join(s.lib.Bodies(), ", "))
		return
	}
	body := pool[0].Body
	day, ok := dailyDayParam(r.URL.Query().Get("day"))
	if !ok {
		fail(w, http.StatusBadRequest, "bad_day", "day must be YYYY-MM-DD")
		return
	}
	if day == "" {
		day = todayUTC()
	}
	bundle := dailyPack(day, pool)

	entries, err := s.store.DailyLeaderboard(r.Context(), day, body, 25)
	if err != nil {
		s.log.Error("daily leaderboard", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load daily leaderboard")
		return
	}
	var me *store.DailyBoardEntry
	if row, found, err := s.store.DailyRank(r.Context(), day, body, uid); err != nil {
		s.log.Error("daily rank", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load daily leaderboard")
		return
	} else if found {
		me = &row
	}
	for i := range entries {
		entries[i].Rank = i + 1
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"board":   "daily",
		"body":    body,
		"day":     day,
		"code":    bundle.Code,
		"me":      me,
		"entries": entries,
	})
}
