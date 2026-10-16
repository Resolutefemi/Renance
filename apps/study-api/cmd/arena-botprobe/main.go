// arena-botprobe: one student queues against the house bot over a real
// WebSocket and plays the duel to the end. Diagnostic for the persist
// path (the e2e only covers human vs human).
package main

import (
        "bytes"
        "encoding/json"
        "fmt"
        "net/http"
        "net/url"
        "os"
        "time"

        "github.com/gorilla/websocket"
)

func fatal(f string, a ...any) { fmt.Printf("BOTPROBE FAIL: "+f+"\n", a...); os.Exit(1) }

type resp struct {
        Token string `json:"token"`
        Error *struct {
                Message string `json:"message"`
        } `json:"error"`
}

func main() {
        base := "http://127.0.0.1:3990"
        body, _ := json.Marshal(map[string]string{"username": "arenaqa1729", "password": "arena-qa-live-1"})
        req, _ := http.NewRequest("POST", base+"/auth/login", bytes.NewReader(body))
        req.Header.Set("Content-Type", "application/json")
        req.Header.Set("User-Agent", "RenanceBotProbe/1.0")
        r, err := http.DefaultClient.Do(req)
        if err != nil {
                fatal("login: %v", err)
        }
        defer r.Body.Close()
        var out resp
        _ = json.NewDecoder(r.Body).Decode(&out)
        if out.Token == "" {
                fatal("no token: %s", out.Error.Message)
        }
        u := "ws://127.0.0.1:3990/arena/ws?token=" + url.QueryEscape(out.Token)
        hdr := http.Header{"User-Agent": []string{"RenanceBotProbe/1.0"}}
        ws, _, err := websocket.DefaultDialer.Dial(u, hdr)
        if err != nil {
                fatal("dial: %v", err)
        }
        defer ws.Close()
        ws.WriteJSON(map[string]any{"type": "queue", "body": "JAMB"})
        fmt.Println("queued, waiting for the bot...")
        ws.SetReadDeadline(time.Now().Add(120 * time.Second))
        questions := 0
        for {
                var f map[string]any
                if err := ws.ReadJSON(&f); err != nil {
                        fatal("read: %v", err)
                }
                switch f["type"] {
                case "matched":
                        fmt.Printf("matched vs %s (%v questions)\n", f["opponent"], f["questionCount"])
                case "question":
                        questions++
                        idx := f["index"].(float64)
                        ws.WriteJSON(map[string]any{"type": "answer", "index": int(idx), "letter": "A"})
                case "over":
                        fmt.Printf("OVER after %d questions. winner=%v scores=%v\n", questions, f["winner"], f["scores"])
                        return
                case "error":
                        fatal("server error: %v / %v", f["errorCode"], f["message"])
                }
        }
}
