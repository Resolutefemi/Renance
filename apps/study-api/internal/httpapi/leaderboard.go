package httpapi

import (
        "context"
        "net/http"
        "strings"

        "renance.dev/study-api/internal/store"
)

// faceMap resolves one avatar key + photo key per username with ONE
// query (founder 2026-10-22: every leaderboard row opens the scholar's
// profile, so the rows wear their real faces). Never fails the board.
func (s *Server) faceMap(ctx context.Context, usernames []string) map[string][2]string {
        out := map[string][2]string{}
        if len(usernames) == 0 {
                return out
        }
        rows, err := s.store.Pool.Query(ctx, `
                SELECT u.username, COALESCE(p.avatar,''), COALESCE(p.avatar_photo,'')
                FROM study.users u
                LEFT JOIN study.profiles p ON p.user_id = u.id
                WHERE u.username = ANY($1)`, usernames)
        if err != nil {
                return out
        }
        defer rows.Close()
        for rows.Next() {
                var u, a, ph string
                if rows.Scan(&u, &a, &ph) == nil {
                        out[u] = [2]string{a, ph}
                }
        }
        return out
}

// Leaderboards (ROADMAP #14 slice): public standings over data the
// product already records - arena outcomes and study XP. Both routes are
// auth-gated like the rest of the student surface; the caller's own row
// rides along as "me" even when it sits outside the top 25, so a student
// always learns exactly where they stand.

// boardPeriod validates the ?period= query for the arena board. Empty
// means the default (week); anything unknown is a 400, never a silent
// fallback, so client bugs surface instead of showing the wrong board.
func boardPeriod(raw string) (string, bool) {
        switch raw {
        case "", "week":
                return "week", true
        case "all":
                return "all", true
        default:
                return "", false
        }
}

// handleArenaLeaderboard serves GET /leaderboard/arena?period=week|all&body=.
// body scopes the board to one focus (JAMB, WAEC, NECO, POST-UTME,
// "University Modules") - each focus ranks on its own ladder; empty
// means the combined board.
func (s *Server) handleArenaLeaderboard(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        period, ok := boardPeriod(r.URL.Query().Get("period"))
        if !ok {
                fail(w, http.StatusBadRequest, "bad_period", "period must be week or all")
                return
        }
        body := strings.TrimSpace(r.URL.Query().Get("body"))
        entries, err := s.store.ArenaLeaderboard(r.Context(), period, body, 25)
        if err != nil {
                s.log.Error("arena leaderboard", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load arena leaderboard")
                return
        }
        // The caller may never have queued for the arena yet - that keeps
        // "me" null instead of inventing a rank they have not earned.
        var me *store.ArenaBoardEntry
        if row, found, err := s.store.ArenaRank(r.Context(), uid, period, body); err != nil {
                s.log.Error("arena rank", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load arena leaderboard")
                return
        } else if found {
                me = &row
        }
        for i := range entries {
                entries[i].Rank = i + 1
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "board":   "arena",
                "period":  period,
                "body":    body,
                "me":      me,
                "entries": entries,
        })
}

// focusBody validates the ?body= query for the focus boards. The value
// is the attempt-code prefix the board ranks on: official UTME mocks
// ("jamb-mock-"), or the whole WAEC / NECO bank family.
func focusBody(raw string) (string, bool) {
        switch raw {
        case "jamb":
                return "jamb-mock-", true
        case "waec":
                return "waec-", true
        case "neco":
                return "neco-", true
        default:
                return "", false
        }
}

// handleFocusLeaderboard serves GET /leaderboard/focus?body=jamb|waec|neco.
// JAMB ranks on the official UTME aggregate out of 400 the grading engine
// seals per attempt; WAEC and NECO rank on the best paper percentage.
func (s *Server) handleFocusLeaderboard(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        focus := strings.TrimSpace(r.URL.Query().Get("focus"))
        prefix, ok := focusBody(focus)
        if !ok {
                fail(w, http.StatusBadRequest, "bad_focus", "focus must be jamb, waec or neco")
                return
        }
        entries, err := s.store.FocusLeaderboard(r.Context(), prefix, 25)
        if err != nil {
                s.log.Error("focus leaderboard", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
                return
        }
        var me *store.FocusBoardEntry
        if row, found, err := s.store.FocusRank(r.Context(), uid, prefix); err != nil {
                s.log.Error("focus rank", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
                return
        } else if found {
                me = &row
        }
        for i := range entries {
                entries[i].Rank = i + 1
        }
        names := make([]string, len(entries))
        for i := range entries {
                names[i] = entries[i].Username
        }
        faces := s.faceMap(r.Context(), names)
        for i := range entries {
                if f, ok := faces[entries[i].Username]; ok {
                        entries[i].Avatar, entries[i].Photo = f[0], f[1]
                }
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "board":   "focus",
                "focus":   focus,
                "me":      me,
                "entries": entries,
        })
}

// handleStreakLeaderboard serves GET /leaderboard/streak - the students
// still showing up day after day, ranked by the streak they are holding.
func (s *Server) handleStreakLeaderboard(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        entries, err := s.store.StreakLeaderboard(r.Context(), 25)
        if err != nil {
                s.log.Error("streak leaderboard", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
                return
        }
        var me *store.StreakBoardEntry
        if row, found, err := s.store.StreakRank(r.Context(), uid); err != nil {
                s.log.Error("streak rank", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
                return
        } else if found {
                me = &row
        }
        for i := range entries {
                entries[i].Rank = i + 1
        }
        names := make([]string, len(entries))
        for i := range entries {
                names[i] = entries[i].Username
        }
        faces := s.faceMap(r.Context(), names)
        for i := range entries {
                if f, ok := faces[entries[i].Username]; ok {
                        entries[i].Avatar, entries[i].Photo = f[0], f[1]
                }
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "board":   "streak",
                "period":  "all",
                "me":      me,
                "entries": entries,
        })
}

// GET /leaderboard/gems - the diamond board (founder directive
// 2026-10-17): learners ranked by their gem balance. Same contract as
// the other boards: top 25 + the caller's own row as "me".
func (s *Server) handleGemsLeaderboard(w http.ResponseWriter, r *http.Request) {
        uid := r.Context().Value(ctxUserID).(string)
        entries, err := s.store.GemsLeaderboard(r.Context(), 25)
        if err != nil {
                s.log.Error("gems leaderboard", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
                return
        }
        var me *store.GemsBoardEntry
        if row, found, err := s.store.GemsRank(r.Context(), uid); err != nil {
                s.log.Error("gems rank", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load leaderboard")
                return
        } else if found {
                me = &row
        }
        for i := range entries {
                entries[i].Rank = i + 1
        }
        names := make([]string, len(entries))
        for i := range entries {
                names[i] = entries[i].Username
        }
        faces := s.faceMap(r.Context(), names)
        for i := range entries {
                if f, ok := faces[entries[i].Username]; ok {
                        entries[i].Avatar, entries[i].Photo = f[0], f[1]
                }
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "board":   "gems",
                "period":  "all",
                "me":      me,
                "entries": entries,
        })
}
