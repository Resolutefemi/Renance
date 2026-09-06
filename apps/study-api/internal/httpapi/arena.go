package httpapi

import (
	"context"
	"math/rand"
	"net/http"
	"strings"
	"time"

	"renance.dev/study-api/internal/arena"
	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/grading"
	"renance.dev/study-api/internal/jwtx"
	"renance.dev/study-api/internal/store"
)

// packSource adapts the content library + answer-key cache to the hub's
// PackSource contract: pick a random pack of the requested body that
// has a server-side key, and serve only questions that can be scored.
type packSource struct {
	lib  *cbtdata.Library
	keys grading.KeySource
	rnd  *rand.Rand
}

func newPackSource(lib *cbtdata.Library, keys grading.KeySource) *packSource {
	return &packSource{lib: lib, keys: keys, rnd: rand.New(rand.NewSource(time.Now().UnixNano()))}
}

func (ps *packSource) PickPack(body string) (string, []arena.QView, map[string]string, bool) {
	mf := ps.lib.Manifest()
	candidates := make([]cbtdata.ExamMeta, 0, 8)
	for _, e := range mf.Exams {
		if body != "" && e.Body != body {
			continue
		}
		if e.QuestionCount <= 0 {
			continue
		}
		if _, hasKey := ps.keys.Get(e.Code); !hasKey {
			continue // a live match needs a key, this pack cannot score
		}
		candidates = append(candidates, e)
	}
	if len(candidates) == 0 {
		return "", nil, nil, false
	}
	pick := candidates[ps.rnd.Intn(len(candidates))]
	bundle, ok := ps.lib.Bundle(pick.Code)
	if !ok {
		return "", nil, nil, false
	}
	keymap, hasKey := ps.keys.Get(pick.Code)
	if !hasKey {
		return "", nil, nil, false
	}

	qs := make([]arena.QView, 0, len(bundle.Questions))
	key := make(map[string]string, len(keymap))
	for _, q := range bundle.Questions {
		ke, scored := keymap[q.ID]
		if !scored || ke.Letter == "" {
			continue // unscorable question, never enters a live match
		}
		qs = append(qs, arena.QView{ID: q.ID, Stem: q.Stem, Options: q.Options, Marks: q.Marks})
		key[q.ID] = ke.Letter
	}
	if len(qs) == 0 {
		return "", nil, nil, false
	}
	return pick.Code, qs, key, true
}

// arenaSink bridges the hub's outcome type into the store's record.
func arenaSink(st *store.Store) arena.MatchSink {
	return arena.SinkFunc(func(ctx context.Context, r arena.MatchResult) error {
		rec := store.ArenaMatchRecord{
			MatchID:      r.MatchID,
			Code:         r.Code,
			Body:         r.Body,
			Status:       r.Status,
			WinnerUserID: r.WinnerID,
		}
		for _, p := range r.Participants {
			rec.Participants = append(rec.Participants, store.ArenaParticipant{
				UserID:   p.UserID,
				Username: p.Username,
				Score:    p.Score,
				Correct:  p.Correct,
				Answered: p.Answered,
				IsBot:    p.IsBot,
			})
		}
		return st.SaveArenaMatch(ctx, rec)
	})
}

// ------------------------------------------------------------------ routes

// handleArenaWS upgrades an authenticated session into the arena.
// Browsers cannot set headers on a WebSocket, so the access token rides
// ?token= (the header wins when both are present). Everything after the
// auth check is hijacked streaming handled by the SocketHandler.
func (s *Server) handleArenaWS(w http.ResponseWriter, r *http.Request) {
	if s.arena == nil {
		fail(w, http.StatusServiceUnavailable, "arena_disabled", "arena is not enabled on this deployment")
		return
	}
	token := r.URL.Query().Get("token")
	if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
		token = strings.TrimPrefix(h, "Bearer ")
	}
	claims, err := jwtx.Verify(token, s.cfg.JWTSecret)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "invalid or expired token")
		return
	}
	p := &arena.Player{UserID: claims.UserID, Username: claims.Username}
	s.arenaSock.Serve(p, w, r)
}

// handleArenaStatus exposes the in-process lobby state.
func (s *Server) handleArenaStatus(w http.ResponseWriter, r *http.Request) {
	if s.arena == nil {
		fail(w, http.StatusServiceUnavailable, "arena_disabled", "arena is not enabled on this deployment")
		return
	}
	writeJSON(w, http.StatusOK, s.arena.Status())
}

// handleArenaHistory serves the caller's recent matches.
func (s *Server) handleArenaHistory(w http.ResponseWriter, r *http.Request) {
	uid, err := userIDFrom(r)
	if err != nil {
		fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
		return
	}
	rows, err := s.store.ArenaHistory(r.Context(), uid, 20)
	if err != nil {
		s.log.Error("arena history", "err", err)
		fail(w, http.StatusInternalServerError, "internal", "could not load arena history")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"matches": rows})
}
