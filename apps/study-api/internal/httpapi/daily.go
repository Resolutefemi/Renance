// Daily challenge (ROADMAP #20): one deterministic 10-question sprint
// per exam body per UTC day. The selection is a pure function of (day,
// body, library) — internal/daily — so every student worldwide plays
// the same questions in the same order, which is what makes the
// per-day board a fair race. The sprint itself flows through the
// ordinary /attempts pipeline (adaptive, grading, review all apply);
// only the marker on the attempt and the ledger seat are new.
package httpapi

import (
	"net/http"
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
// never a silent fallback — same contract as boardPeriod.
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
	bundle := dailyPack(day, pool)

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

	writeJSON(w, http.StatusOK, map[string]any{
		"day":             day,
		"body":            body,
		"code":            bundle.Code,
		"title":           bundle.Title,
		"questionCount":   len(questions),
		"totalMarks":      marks,
		"durationMinutes": bundle.DurationMinutes,
		"questions":       questions,
		"myResult":        me,
	})
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
