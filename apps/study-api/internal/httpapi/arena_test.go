package httpapi

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"renance.dev/study-api/internal/arena"
	"renance.dev/study-api/internal/config"
	"renance.dev/study-api/internal/jwtx"
)

// The arena socket path end-to-end over real WebSockets: JWT gate, hub
// matchmaking and a full two-player match, all in-process with a fake
// pack source (no database, no content directory needed here).

type arenaTestPacks struct{}

func (arenaTestPacks) PickPack(string) (string, []arena.QView, map[string]string, bool) {
	qs := []arena.QView{
		{ID: "q1", Stem: "2 + 2 = ?", Options: map[string]string{"A": "3", "B": "4", "C": "5"}, Marks: 2},
		{ID: "q2", Stem: "H2O is?", Options: map[string]string{"A": "Water", "B": "Salt"}, Marks: 3},
	}
	return "jamb-mock", qs, map[string]string{"q1": "B", "q2": "A"}, true
}

type arenaTestSink struct{}

func (arenaTestSink) SaveMatch(_ context.Context, _ arena.MatchResult) error { return nil }

func arenaTestServer(t *testing.T) (*Server, string, string) {
	t.Helper()
	cfg := &config.Config{
		JWTSecret: "arena-test-secret-0123456789",
		WebOrigin: "*",
	}
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewServer(cfg, log, nil, nil, nil, nil, nil)
	hub := arena.NewHub(arena.Config{
		Questions:          2,
		SecondsPerQuestion: 3,
		IntroCountdown:     50 * time.Millisecond,
		BotWait:            time.Hour,
		BotSkill:           0.6,
	}, arenaTestPacks{}, arenaTestSink{}, log)
	s.arena = hub
	s.arenaSock = &arena.SocketHandler{Hub: hub, Log: log}

	token := func(uid, name string) string {
		tok, err := jwtx.Issue(uid, name, cfg.JWTSecret)
		if err != nil {
			t.Fatal(err)
		}
		return tok
	}
	return s, token("u1", "Alice"), token("u2", "Bola")
}

func dialArena(t *testing.T, url string) *websocket.Conn {
	t.Helper()
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial %s: %v", url, err)
	}
	_ = conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	return conn
}

func readArena(t *testing.T, conn *websocket.Conn, kind string) arena.Outbound {
	t.Helper()
	for {
		var out arena.Outbound
		if err := conn.ReadJSON(&out); err != nil {
			t.Fatalf("read %s: %v", kind, err)
		}
		if out.Type == kind {
			return out
		}
	}
}

func TestArenaWSTwoPlayerMatch(t *testing.T) {
	s, tok1, tok2 := arenaTestServer(t)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()
	wsBase := "ws" + strings.TrimPrefix(srv.URL, "http")

	c1 := dialArena(t, wsBase+"/arena/ws?token="+tok1)
	defer c1.Close()
	c2 := dialArena(t, wsBase+"/arena/ws?token="+tok2)
	defer c2.Close()

	for _, c := range []*websocket.Conn{c1, c2} {
		if err := c.WriteJSON(arena.Inbound{Type: arena.InQueue, Body: "JAMB"}); err != nil {
			t.Fatal(err)
		}
	}

	m1 := readArena(t, c1, arena.OutMatched)
	m2 := readArena(t, c2, arena.OutMatched)
	if m1.MatchID == "" || m1.MatchID != m2.MatchID {
		t.Fatalf("matched ids differ: %q vs %q", m1.MatchID, m2.MatchID)
	}
	if m1.Code != "jamb-mock" || m1.Opponent != "Bola" {
		t.Fatalf("matched frame wrong: %+v", m1)
	}

	// q1: Alice right, Bola wrong.
	readArena(t, c1, arena.OutQuestion)
	readArena(t, c2, arena.OutQuestion)
	_ = c1.WriteJSON(arena.Inbound{Type: arena.InAnswer, Index: 0, Letter: "b"}) // lower-case on purpose
	_ = c2.WriteJSON(arena.Inbound{Type: arena.InAnswer, Index: 0, Letter: "C"})
	r1 := readArena(t, c1, arena.OutResult)
	if r1.Correct != "B" || !r1.Solved["u1"] || r1.Solved["u2"] {
		t.Fatalf("result 1 wrong: %+v", r1)
	}

	// q2: both right.
	readArena(t, c1, arena.OutQuestion)
	_ = c1.WriteJSON(arena.Inbound{Type: arena.InAnswer, Index: 1, Letter: "A"})
	_ = c2.WriteJSON(arena.Inbound{Type: arena.InAnswer, Index: 1, Letter: "A"})
	readArena(t, c1, arena.OutResult)

	over := readArena(t, c1, arena.OutOver)
	if over.Winner != "u1" {
		t.Fatalf("winner = %q, want u1 (5 vs 3)", over.Winner)
	}
	if over.Scores["u1"] != 5 || over.Scores["u2"] != 3 {
		t.Fatalf("final scores %v, want u1=5 u2=3", over.Scores)
	}
	readArena(t, c2, arena.OutOver)
}

func TestArenaWSRequiresToken(t *testing.T) {
	s, _, _ := arenaTestServer(t)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/arena/ws"
	if _, _, err := websocket.DefaultDialer.Dial(wsURL, nil); err == nil {
		t.Fatal("unauthenticated socket must be refused")
	}
}

func TestArenaStatusRoute(t *testing.T) {
	s, tok1, _ := arenaTestServer(t)
	srv := httptest.NewServer(s.Handler())
	defer srv.Close()

	req, _ := http.NewRequest("GET", srv.URL+"/arena/status", nil)
	req.Header.Set("Authorization", "Bearer "+tok1)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		t.Fatalf("status = %d, want 200", resp.StatusCode)
	}
}
