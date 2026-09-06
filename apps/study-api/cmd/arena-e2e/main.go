// Arena E2E probe (ROADMAP #14): two students queue over real
// WebSockets, get matched, play a full head-to-head match with random
// picks, and both read their match history afterwards. Exit 0 only if
// every phase lands.
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

func main() {
	baseURL := base
	if len(os.Args) > 1 {
		baseURL = strings.TrimRight(os.Args[1], "/")
	}
	stamp := time.Now().UnixMilli()
	fmt.Println("▸ arena e2e: register two students")
	tokA := register(baseURL, fmt.Sprintf("arenaa%d", stamp))
	tokB := register(baseURL, fmt.Sprintf("arenab%d", stamp))

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

	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := 0; i < ma.Questions; i++ {
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
	fmt.Printf("▸ match over — winner %q scores %v\n", oa.Winner, oa.Scores)
	if oa.MatchID != ob.MatchID {
		fatal("over frames disagree on match id")
	}

	fmt.Println("▸ history for both students")
	expectHistory := func(token, who string) {
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
		var out struct {
			Matches []struct {
				MatchID string `json:"matchId"`
				Score   int    `json:"score"`
			} `json:"matches"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&out)
		found := false
		for _, m := range out.Matches {
			if m.MatchID == oa.MatchID {
				found = true
			}
		}
		if !found {
			fatal("%s history missing match %s", who, oa.MatchID)
		}
	}
	expectHistory(tokA, "A")
	expectHistory(tokB, "B")

	fmt.Println("ARENA E2E OK")
}
