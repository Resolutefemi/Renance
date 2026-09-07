// Arena E2E probe (ROADMAP #14): two students queue over real
// WebSockets, get matched, play a full head-to-head match with random
// picks, and both read their match history afterwards. A second phase
// exercises private rooms: A hosts, a stray code is rejected, B joins
// by code, they play a full match and both read it in their history.
// Exit 0 only if every phase lands.
//
// Usage: go run ./cmd/arena-e2e [BASE_URL]  (default http://127.0.0.1:3990)
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

const (
	base     = "http://127.0.0.1:3990"
	deadline = 60 * time.Second
)

type apiResp struct {
	Token string `json:"token"`
	Error *struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

func fatal(format string, args ...any) {
	fmt.Printf("ARENA E2E FAIL: "+format+"\n", args...)
	os.Exit(1)
}

func register(baseURL, username string) string {
	body, _ := json.Marshal(map[string]string{"username": username, "password": "arena-e2e-password-1"})
	resp, err := http.Post(baseURL+"/auth/register", "application/json", bytes.NewReader(body))
	if err != nil {
		fatal("register %s: %v", username, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 201 && resp.StatusCode != 409 {
		fatal("register %s -> %d", username, resp.StatusCode)
	}
	var out apiResp
	_ = json.NewDecoder(resp.Body).Decode(&out)
	if out.Token != "" {
		return out.Token
	}
	// 409: user exists from a previous run — log in instead.
	resp2, err := http.Post(baseURL+"/auth/login", "application/json", bytes.NewReader(body))
	if err != nil {
		fatal("login %s: %v", username, err)
	}
	defer resp2.Body.Close()
	var out2 apiResp
	_ = json.NewDecoder(resp2.Body).Decode(&out2)
	if out2.Token == "" {
		fatal("no token for %s", username)
	}
	return out2.Token
}

type frame struct {
	Type      string         `json:"type"`
	MatchID   string         `json:"matchId,omitempty"`
	Winner    string         `json:"winner,omitempty"`
	Scores    map[string]int `json:"scores,omitempty"`
	Opponent  string         `json:"opponent,omitempty"`
	Code      string         `json:"code,omitempty"`
	Questions int            `json:"questionCount,omitempty"`
	Index     int            `json:"index,omitempty"`
	Question  *struct {
		ID      string            `json:"id"`
		Stem    string            `json:"stem"`
		Options map[string]string `json:"options,omitempty"`
		Marks   int               `json:"marks"`
	} `json:"question,omitempty"`
	Correct string          `json:"correctLetter,omitempty"`
	Solved  map[string]bool `json:"solved,omitempty"`
	ErrCode string          `json:"errorCode,omitempty"`
}

func readUntil(conn *websocket.Conn, kinds ...string) frame {
	deadline := time.Now().Add(deadline)
	for {
		_ = conn.SetReadDeadline(deadline)
		var f frame
		if err := conn.ReadJSON(&f); err != nil {
			fatal("read (want %v): %v", kinds, err)
		}
		if f.Type == "error" {
			fatal("server error frame: code=%s", f.ErrCode)
		}
		for _, k := range kinds {
			if f.Type == k {
				return f
			}
		}
	}
}

// readAny reads one frame of any kind, including error frames.
func readAny(conn *websocket.Conn) frame {
	_ = conn.SetReadDeadline(time.Now().Add(deadline))
	var f frame
	if err := conn.ReadJSON(&f); err != nil {
		fatal("read: %v", err)
	}
	return f
}

// playMatch drives a running match (both sockets already saw
// "matched") question by question with random picks, then returns the
// caller's "over" frame after checking both sides agree.
func playMatch(a, b *websocket.Conn, questions int) frame {
	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := 0; i < questions; i++ {
		qa := readUntil(a, "question")
		readUntil(b, "question")
		if qa.Index != i || qa.Question == nil {
			fatal("question frame wrong: %+v", qa)
		}
		letters := make([]string, 0, len(qa.Question.Options))
		for l := range qa.Question.Options {
			letters = append(letters, l)
		}
		pick := letters[rnd.Intn(len(letters))]
		_ = a.WriteJSON(map[string]any{"type": "answer", "index": i, "letter": pick})
		_ = b.WriteJSON(map[string]any{"type": "answer", "index": i, "letter": pick})
		readUntil(a, "result")
		readUntil(b, "result")
	}
	oa := readUntil(a, "over")
	ob := readUntil(b, "over")
	if oa.Scores == nil || len(oa.Scores) != 2 {
		fatal("over frame scores wrong: %+v", oa)
	}
	if oa.MatchID != ob.MatchID {
		fatal("over frames disagree on match id")
	}
	return oa
}

// These lobby helpers retry once-per-300ms on in_match: the hub clears
// the previous match's state right after the "over" frame is written,
// so a fast client can race the teardown by a few microseconds.

// hostRoom hosts a private JAMB room and returns its code.
func hostRoom(c *websocket.Conn) string {
	for attempt := 0; ; attempt++ {
		if err := c.WriteJSON(map[string]string{"type": "host", "body": "JAMB"}); err != nil {
			fatal("host: %v", err)
		}
		f := readAny(c)
		switch f.Type {
		case "hosted":
			if len(f.Code) != 6 {
				fatal("room code %q is not 6 characters", f.Code)
			}
			return f.Code
		case "error":
			if f.ErrCode == "in_match" && attempt < 20 {
				time.Sleep(300 * time.Millisecond)
				continue
			}
			fatal("host refused: %s", f.ErrCode)
		default:
			fatal("unexpected frame while hosting: %s", f.Type)
		}
	}
}

// joinRoom joins a private room by code and returns the joiner's
// "matched" frame (it consumes it, so main must not read it again).
func joinRoom(c *websocket.Conn, code string) frame {
	for attempt := 0; ; attempt++ {
		if err := c.WriteJSON(map[string]string{"type": "join", "code": code}); err != nil {
			fatal("join: %v", err)
		}
		f := readAny(c)
		switch f.Type {
		case "matched":
			return f
		case "error":
			if f.ErrCode == "in_match" && attempt < 20 {
				time.Sleep(300 * time.Millisecond)
				continue
			}
			fatal("join refused: %s", f.ErrCode)
		default:
			fatal("unexpected frame while joining: %s", f.Type)
		}
	}
}

// joinExpectErr joins and requires an error frame with [wantErr]
// (in_match during teardown is retried, anything else fails).
func joinExpectErr(c *websocket.Conn, code, wantErr string) {
	for attempt := 0; ; attempt++ {
		_ = c.WriteJSON(map[string]string{"type": "join", "code": code})
		f := readAny(c)
		if f.Type == "error" {
			if f.ErrCode == wantErr {
				return
			}
			if f.ErrCode == "in_match" && attempt < 20 {
				time.Sleep(300 * time.Millisecond)
				continue
			}
			fatal("join error = %s, want %s", f.ErrCode, wantErr)
		}
		fatal("join expected an error frame, got %s", f.Type)
	}
}

func main() {
	baseURL := base
	if len(os.Args) > 1 {
		baseURL = strings.TrimRight(os.Args[1], "/")
	}
	stamp := time.Now().UnixMilli()
	fmt.Println("▸ arena e2e: register two students")
	// e2e-prefixed usernames: one `e2eclean -prefix e2e` pass purges both
	// the api-e2e.sh student and these two, even against the REAL database.
	tokA := register(baseURL, fmt.Sprintf("e2eara%d", stamp))
	tokB := register(baseURL, fmt.Sprintf("e2earb%d", stamp))

	wsBase := "ws" + strings.TrimPrefix(baseURL, "http") + "/arena/ws"
	dial := func(token string) *websocket.Conn {
		u := wsBase + "?token=" + url.QueryEscape(token)
		conn, _, err := websocket.DefaultDialer.Dial(u, nil)
		if err != nil {
			fatal("dial: %v", err)
		}
		return conn
	}
	fmt.Println("▸ connect both sockets")
	a, b := dial(tokA), dial(tokB)
	defer a.Close()
	defer b.Close()

	fmt.Println("▸ queue both for JAMB")
	for _, c := range []*websocket.Conn{a, b} {
		if err := c.WriteJSON(map[string]string{"type": "queue", "body": "JAMB"}); err != nil {
			fatal("queue: %v", err)
		}
	}
	ma := readUntil(a, "matched")
	mb := readUntil(b, "matched")
	if ma.MatchID == "" || ma.MatchID != mb.MatchID {
		fatal("match ids differ: %q vs %q", ma.MatchID, mb.MatchID)
	}
	if ma.Code == "" || ma.Questions == 0 {
		fatal("matched frame incomplete: %+v", ma)
	}
	fmt.Printf("▸ matched on %s (%d questions)\n", ma.Code, ma.Questions)

	oa := playMatch(a, b, ma.Questions)
	fmt.Printf("▸ match over — winner %q scores %v\n", oa.Winner, oa.Scores)

	fmt.Println("▸ history for both students")
	expectHistory := func(token, who, matchID string) {
		req, _ := http.NewRequest("GET", baseURL+"/arena/history", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			fatal("history %s: %v", who, err)
		}
		defer resp.Body.Close()
		if resp.StatusCode != 200 {
			fatal("history %s -> %d", who, resp.StatusCode)
		}
		found := false
		// The write landed before "over" was sent, but give the pooler a
		// beat of slack anyway: a few short retries, then fail loudly.
		for attempt := 0; attempt < 8 && !found; attempt++ {
			if attempt > 0 {
				time.Sleep(300 * time.Millisecond)
				req, _ = http.NewRequest("GET", baseURL+"/arena/history", nil)
				req.Header.Set("Authorization", "Bearer "+token)
				resp, err = http.DefaultClient.Do(req)
				if err != nil {
					fatal("history %s: %v", who, err)
				}
			}
			var out struct {
				Matches []struct {
					MatchID string `json:"matchId"`
					Score   int    `json:"score"`
				} `json:"matches"`
			}
			_ = json.NewDecoder(resp.Body).Decode(&out)
			resp.Body.Close()
			for _, m := range out.Matches {
				if m.MatchID == matchID {
					found = true
				}
			}
		}
		if !found {
			fatal("%s history missing match %s", who, matchID)
		}
	}
	expectHistory(tokA, "A", oa.MatchID)
	expectHistory(tokB, "B", oa.MatchID)

	fmt.Println("▸ private room: A hosts, stray code rejected, B joins by code")
	code := hostRoom(a)
	joinExpectErr(b, "ZZZZZZ", "unknown_room")
	fmt.Printf("▸ room %s open — stray joins rejected\n", code)
	ma2 := readUntil(a, "matched")
	mb2 := joinRoom(b, code)
	if ma2.MatchID == "" || ma2.MatchID != mb2.MatchID {
		fatal("private match ids differ: %q vs %q", ma2.MatchID, mb2.MatchID)
	}
	oa2 := playMatch(a, b, ma2.Questions)
	fmt.Printf("▸ private match over — winner %q scores %v\n", oa2.Winner, oa2.Scores)
	expectHistory(tokA, "A(private)", ma2.MatchID)
	expectHistory(tokB, "B(private)", ma2.MatchID)

	fmt.Println("ARENA E2E OK")
}
