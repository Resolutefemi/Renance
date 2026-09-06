package arena

import (
        "context"
        "io"
        "log/slog"
        "strings"
        "sync"
        "testing"
        "time"
)

// ------------------------------------------------------------------ fakes

// fakeClock only moves when the test advances it.
type fakeClock struct {
        mu     sync.Mutex
        now    time.Time
        timers []*fakeTimer
}

type fakeTimer struct {
        at    time.Time
        ch    chan time.Time
        fired bool
}

func newFakeClock() *fakeClock {
        return &fakeClock{now: time.Date(2026, 9, 6, 12, 0, 0, 0, time.UTC)}
}

func (c *fakeClock) Now() time.Time {
        c.mu.Lock()
        defer c.mu.Unlock()
        return c.now
}

func (c *fakeClock) After(d time.Duration) <-chan time.Time {
        c.mu.Lock()
        defer c.mu.Unlock()
        ch := make(chan time.Time, 1)
        c.timers = append(c.timers, &fakeTimer{at: c.now.Add(d), ch: ch})
        return ch
}

// Advance fires every timer whose deadline has passed, in order.
func (c *fakeClock) Advance(d time.Duration) {
        c.mu.Lock()
        c.now = c.now.Add(d)
        var ready []*fakeTimer
        for _, t := range c.timers {
                if !t.fired && !t.at.After(c.now) {
                        t.fired = true
                        ready = append(ready, t)
                }
        }
        c.mu.Unlock()
        for _, t := range ready {
                t.ch <- c.now
        }
}

// advanceUntil steps the clock forward in small increments until cond()
// holds or the budget is spent. Timers register lazily inside their own
// goroutines, so a one-shot Advance can outrun registration; stepping
// makes the wait robust regardless of scheduling order.
func (c *fakeClock) advanceUntil(cond func() bool, budget time.Duration) {
        step := budget / 100
        if step < 5*time.Millisecond {
                step = 5 * time.Millisecond
        }
        if step > 100*time.Millisecond {
                step = 100 * time.Millisecond
        }
        for elapsed := time.Duration(0); elapsed <= budget; elapsed += step {
                if cond() {
                        return
                }
                c.Advance(step)
                time.Sleep(2 * time.Millisecond)
        }
}

// fakePeer records every outbound frame; Close flips its done channel.
type fakePeer struct {
        mu     sync.Mutex
        out    []Outbound
        closed bool
        done   chan struct{}
}

func newFakePeer() *fakePeer { return &fakePeer{done: make(chan struct{})} }

func (f *fakePeer) Send(o Outbound) {
        f.mu.Lock()
        defer f.mu.Unlock()
        if !f.closed {
                f.out = append(f.out, o)
        }
}

func (f *fakePeer) Close() {
        f.mu.Lock()
        defer f.mu.Unlock()
        if !f.closed {
                f.closed = true
                close(f.done)
        }
}

func (f *fakePeer) Done() <-chan struct{} { return f.done }

func (f *fakePeer) ofType(kind string) []Outbound {
        f.mu.Lock()
        defer f.mu.Unlock()
        out := make([]Outbound, 0, 2)
        for _, o := range f.out {
                if o.Type == kind {
                        out = append(out, o)
                }
        }
        return out
}

func (f *fakePeer) count(kind string) int { return len(f.ofType(kind)) }

// fakePacks serves one fixed pack.
type fakePacks struct {
        code string
        qs   []QView
        key  map[string]string
        fail bool
}

func (f *fakePacks) PickPack(string) (string, []QView, map[string]string, bool) {
        if f.fail {
                return "", nil, nil, false
        }
        return f.code, f.qs, f.key, true
}

// countingSink records every persisted outcome.
type countingSink struct {
        mu      sync.Mutex
        results []MatchResult
}

func (s *countingSink) SaveMatch(_ context.Context, r MatchResult) error {
        s.mu.Lock()
        defer s.mu.Unlock()
        s.results = append(s.results, r)
        return nil
}

func (s *countingSink) all() []MatchResult {
        s.mu.Lock()
        defer s.mu.Unlock()
        return append([]MatchResult{}, s.results...)
}

// waitFor spins until cond() is true, failing the test at the deadline.
func waitFor(t *testing.T, cond func() bool) {
        t.Helper()
        deadline := time.Now().Add(3 * time.Second)
        for time.Now().Before(deadline) {
                if cond() {
                        return
                }
                time.Sleep(5 * time.Millisecond)
        }
        t.Fatal("condition never became true")
}

// testPack builds a 3-question pack with an A/B/C/D key.
func testPack() (string, []QView, map[string]string) {
        qs := []QView{
                {ID: "q1", Stem: "2 + 2 = ?", Options: map[string]string{"A": "3", "B": "4", "C": "5"}, Marks: 2},
                {ID: "q2", Stem: "Capital of Nigeria?", Options: map[string]string{"A": "Abuja", "B": "Lagos", "C": "Kano"}, Marks: 3},
                {ID: "q3", Stem: "H2O is?", Options: map[string]string{"A": "Water", "B": "Salt"}, Marks: 1},
        }
        key := map[string]string{"q1": "B", "q2": "A", "q3": "A"}
        return "jamb-mock", qs, key
}

// hubTest bundles a hub with its fakes and two pre-attached players.
type hubTest struct {
        hub   *Hub
        clock *fakeClock
        sink  *countingSink
        p1    *Player
        p2    *Player
        peer1 *fakePeer
        peer2 *fakePeer
        key   map[string]string
}

func newHubTest(t *testing.T, cfg Config) *hubTest {
        t.Helper()
        code, qs, key := testPack()
        h := &hubTest{
                clock: newFakeClock(),
                sink:  &countingSink{},
                key:   key,
        }
        h.hub = NewHub(cfg, &fakePacks{code: code, qs: qs, key: key}, h.sink, testLogger())
        h.hub.setClock(h.clock)
        h.p1 = &Player{UserID: "u1", Username: "Alice"}
        h.p2 = &Player{UserID: "u2", Username: "Bola"}
        h.peer1, h.peer2 = newFakePeer(), newFakePeer()
        h.hub.Attach(h.p1, h.peer1)
        h.hub.Attach(h.p2, h.peer2)
        return h
}

// pair queues both players and waits for the matched handshake.
func (h *hubTest) pair(t *testing.T) Outbound {
        t.Helper()
        h.hub.Queue(h.p1, "JAMB")
        h.hub.Queue(h.p2, "JAMB")
        waitFor(t, func() bool { return h.peer1.count(OutMatched) == 1 && h.peer2.count(OutMatched) == 1 })
        return h.peer1.ofType(OutMatched)[0]
}

func testLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

// ------------------------------------------------------------------ match rules

func TestMatchFullFlowAndScoring(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 2, SecondsPerQuestion: 10,
                IntroCountdown: 2 * time.Second, BotWait: time.Hour, BotSkill: 0.6,
        })
        matched := h.pair(t)
        if matched.Code != "jamb-mock" {
                t.Fatalf("matched with pack %q, want jamb-mock", matched.Code)
        }
        if matched.Questions != 2 {
                t.Fatalf("question count = %d, want 2", matched.Questions)
        }

        // Intro countdown fires, question 0 lands.
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 1 }, 5*time.Second)
        q := h.peer1.ofType(OutQuestion)[0]
        if q.Question.ID != "q1" || q.Index != 0 {
                t.Fatalf("first question = %+v, want q1 at index 0", q.Question)
        }

        // Alice is right, Bola is wrong: reveal is immediate.
        h.hub.Answer(h.p1, 0, "B")
        h.hub.Answer(h.p2, 0, "C")
        waitFor(t, func() bool { return h.peer1.count(OutResult) == 1 })
        res := h.peer1.ofType(OutResult)[0]
        if res.Correct != "B" {
                t.Fatalf("correct letter = %q, want B", res.Correct)
        }
        if !res.Solved["u1"] || res.Solved["u2"] {
                t.Fatalf("solved map wrong: %+v", res.Solved)
        }
        if res.Scores["u1"] != 2 || res.Scores["u2"] != 0 {
                t.Fatalf("scores after q1 = %v, want u1=2 u2=0", res.Scores)
        }

        // Question 2: nobody answers, the deadline scores a blank round.
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 2 }, 15*time.Second)
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutResult) == 2 && h.peer1.count(OutOver) == 1 }, 15*time.Second)

        over := h.peer1.ofType(OutOver)[0]
        if over.Winner != "u1" {
                t.Fatalf("winner = %q, want u1", over.Winner)
        }
        if over.Scores["u1"] != 2 {
                t.Fatalf("final score u1 = %d, want 2", over.Scores["u1"])
        }
        waitFor(t, func() bool { return len(h.sink.all()) == 1 })
        rec := h.sink.all()[0]
        if rec.Status != "finished" || rec.WinnerID != "u1" || len(rec.Participants) != 2 {
                t.Fatalf("persisted record wrong: %+v", rec)
        }
}

func TestMatchDuplicateAndStaleAnswersIgnored(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 1, SecondsPerQuestion: 10,
                IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
        })
        h.pair(t)
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 1 }, 5*time.Second)

        // Duplicate pick from Alice: only the first counts. Stale index and a
        // letter that is not an option: dropped outright.
        h.hub.Answer(h.p1, 0, "B")
        h.hub.Answer(h.p1, 0, "C")
        h.hub.Answer(h.p1, 9, "B")
        h.hub.Answer(h.p2, 0, "Z")
        h.hub.Answer(h.p2, 0, "C")
        waitFor(t, func() bool { return h.peer1.count(OutResult) == 1 })
        res := h.peer1.ofType(OutResult)[0]
        if !res.Solved["u1"] || res.Solved["u2"] {
                t.Fatalf("solved = %+v, want u1 true u2 false (Z invalid, C counted)", res.Solved)
        }
}

func TestMatchForfeitWhenConnectionDies(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 3, SecondsPerQuestion: 10,
                IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
        })
        h.pair(t)
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 1 }, 5*time.Second)

        // Alice's socket dies mid-match: Bola wins without playing on.
        h.peer1.Close()
        waitFor(t, func() bool { return h.peer2.count(OutOver) == 1 })
        over := h.peer2.ofType(OutOver)[0]
        if over.Winner != "u2" {
                t.Fatalf("winner = %q, want u2", over.Winner)
        }
        waitFor(t, func() bool { return len(h.sink.all()) == 1 })
        if h.sink.all()[0].Status != "aborted" {
                t.Fatalf("status = %s, want aborted", h.sink.all()[0].Status)
        }
}

// ------------------------------------------------------------------ bot

func TestBotFillsAfterWaitAndDrawsWhenPerfect(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 2, SecondsPerQuestion: 10,
                IntroCountdown: time.Second, BotWait: 30 * time.Second, BotSkill: 1,
        })
        h.hub.Queue(h.p1, "JAMB")
        if got := h.peer1.count(OutQueued); got != 1 {
                t.Fatalf("queued frames = %d, want 1", got)
        }
        // No human second: the bot joins when the wait fires.
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutMatched) == 1 }, 35*time.Second)
        matched := h.peer1.ofType(OutMatched)[0]
        if matched.Opponent != "Renance Bot" {
                t.Fatalf("opponent = %q, want Renance Bot", matched.Opponent)
        }

        // A perfect bot mirrors every correct answer: guaranteed draw.
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 1 }, 5*time.Second)
        h.hub.Answer(h.p1, 0, "B")
        waitFor(t, func() bool { return h.peer1.count(OutResult) == 1 })
        if got := h.peer1.ofType(OutResult)[0]; !got.Solved["u1"] {
                t.Fatalf("human missed an answered question: %+v", got)
        }
        // q2: nobody answers; the perfect bot still "picks" at evaluation —
        // that is the deal with the house opponent: it always shows up.
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 2 }, 15*time.Second)
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutOver) == 1 }, 15*time.Second)
        over := h.peer1.ofType(OutOver)[0]
        if !strings.HasPrefix(over.Winner, "bot:") {
                t.Fatalf("winner = %q, want the perfect bot", over.Winner)
        }
        rec := h.sink.all()[0]
        var botRow, humanRow *ParticipantResult
        for i := range rec.Participants {
                if rec.Participants[i].IsBot {
                        botRow = &rec.Participants[i]
                } else {
                        humanRow = &rec.Participants[i]
                }
        }
        if botRow == nil || humanRow == nil {
                t.Fatalf("missing bot/human participant rows: %+v", rec.Participants)
        }
        if botRow.Score != 5 || humanRow.Score != 2 {
                t.Fatalf("scores bot=%d human=%d, want bot 5 (q1+q2) human 2 (q1)", botRow.Score, humanRow.Score)
        }
        if botRow.UserID[:4] != "bot:" {
                t.Fatalf("bot userID %q lacks prefix", botRow.UserID)
        }
}

func TestBotLosesWhenSkillIsZero(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 1, SecondsPerQuestion: 5,
                IntroCountdown: time.Second, BotWait: 5 * time.Second, BotSkill: 0,
        })
        h.hub.Queue(h.p1, "JAMB")
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutMatched) == 1 }, 10*time.Second)
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == 1 }, 5*time.Second)
        // Deadline passes; the human never answers, the bot never scores.
        h.clock.advanceUntil(func() bool { return h.peer1.count(OutResult) == 1 && h.peer1.count(OutOver) == 1 }, 10*time.Second)
        over := h.peer1.ofType(OutOver)[0]
        if over.Scores["u1"] != 0 {
                t.Fatalf("human score = %d, want 0", over.Scores["u1"])
        }
        if over.Winner != "" {
                t.Fatalf("winner = %q, want draw at 0-0", over.Winner)
        }
}

// ------------------------------------------------------------------ hub rules

func TestHubRejectsUnknownBody(t *testing.T) {
        h := newHubTest(t, DefaultConfig())
        h.hub.Queue(h.p1, "IGCSE")
        waitFor(t, func() bool { return h.peer1.count(OutError) == 1 })
        if got := h.peer1.ofType(OutError)[0].ErrCode; got != ErrUnknownBody {
                t.Fatalf("error = %q, want %q", got, ErrUnknownBody)
        }
}

func TestHubReportsMissingPack(t *testing.T) {
        code, qs, key := testPack()
        h := &hubTest{
                clock: newFakeClock(),
                sink:  &countingSink{},
        }
        h.hub = NewHub(DefaultConfig(), &fakePacks{code: code, qs: qs, key: key, fail: true}, h.sink, testLogger())
        h.hub.setClock(h.clock)
        h.p1 = &Player{UserID: "u1", Username: "Alice"}
        h.p2 = &Player{UserID: "u2", Username: "Bola"}
        h.peer1, h.peer2 = newFakePeer(), newFakePeer()
        h.hub.Attach(h.p1, h.peer1)
        h.hub.Attach(h.p2, h.peer2)

        h.hub.Queue(h.p1, "JAMB")
        h.hub.Queue(h.p2, "JAMB")
        waitFor(t, func() bool {
                return h.peer1.count(OutError) == 1 && h.peer2.count(OutError) == 1
        })
        if got := h.peer1.ofType(OutError)[0].ErrCode; got != ErrNoPack {
                t.Fatalf("error = %q, want %q", got, ErrNoPack)
        }
        if h.hub.Status().Live != 0 {
                t.Fatalf("live matches = %d, want 0", h.hub.Status().Live)
        }
}

func TestHubQueueGuardsAndCancel(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 1, SecondsPerQuestion: 5,
                IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
        })
        h.hub.Queue(h.p1, "JAMB")
        h.hub.Queue(h.p1, "JAMB") // already queued
        waitFor(t, func() bool { return h.peer1.count(OutError) == 1 })
        if got := h.peer1.ofType(OutError)[0].ErrCode; got != ErrAlreadyQueued {
                t.Fatalf("error = %q, want %q", got, ErrAlreadyQueued)
        }

        h.hub.Cancel(h.p1)
        waitFor(t, func() bool { return h.peer1.count(OutCancelled) == 1 })
        if st := h.hub.Status(); len(st.Waiting) != 0 {
                t.Fatalf("waiting buckets = %v, want empty", st.Waiting)
        }

        // Cancel without a queue entry is a silent no-op.
        h.hub.Cancel(h.p1)
        if h.peer1.count(OutCancelled) != 1 {
                t.Fatalf("second cancel emitted a frame")
        }
}

func TestHubReplacesIdleSessionButRefusesMatchedOne(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 1, SecondsPerQuestion: 5,
                IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
        })
        // Queued session: a fresh Attach replaces it and closes the old peer.
        h.hub.Queue(h.p1, "JAMB")
        p1b := &Player{UserID: "u1", Username: "Alice"}
        peer1b := newFakePeer()
        h.hub.Attach(p1b, peer1b)
        waitFor(t, func() bool { return h.peer1.closedByFlag() })
        if got := h.peer1.ofType(OutError)[0].ErrCode; got != ErrReplaced {
                t.Fatalf("old session error = %q, want %q", got, ErrReplaced)
        }

        // In a live match: a second connection is refused outright.
        h.hub.Queue(p1b, "JAMB")
        h.hub.Queue(h.p2, "JAMB")
        waitFor(t, func() bool { return peer1b.count(OutMatched) == 1 })
        p1c := &Player{UserID: "u1", Username: "Alice"}
        peer1c := newFakePeer()
        h.hub.Attach(p1c, peer1c)
        waitFor(t, func() bool { return peer1c.count(OutError) == 1 && peer1c.doneClosed() })
        if got := peer1c.ofType(OutError)[0].ErrCode; got != ErrInMatch {
                t.Fatalf("error = %q, want %q", got, ErrInMatch)
        }
}

func TestHubStopShutsEverythingDown(t *testing.T) {
        h := newHubTest(t, Config{
                Questions: 2, SecondsPerQuestion: 5,
                IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
        })
        h.pair(t)
        h.hub.Stop()
        // Every queued/live session peer got closed.
        if !h.peer1.closedByFlag() || !h.peer2.closedByFlag() {
                t.Fatalf("peers must be closed after Stop")
        }
}

// ------------------------------------------------------------------ helpers on fakePeer

func (f *fakePeer) closedByFlag() bool {
        f.mu.Lock()
        defer f.mu.Unlock()
        return f.closed
}

func (f *fakePeer) doneClosed() bool {
        select {
        case <-f.done:
                return true
        default:
                return false
        }
}
