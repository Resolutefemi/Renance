package arena

import (
        "context"
        "log/slog"
        "math/rand"
        "time"
)

// Clock abstracts time so the match loop is deterministic under test:
// a fake clock fires deadlines only when the test advances it.
type Clock interface {
        Now() time.Time
        After(d time.Duration) <-chan time.Time
}

type realClock struct{}

func (realClock) Now() time.Time                  { return time.Now() }
func (realClock) After(d time.Duration) <-chan time.Time { return time.After(d) }

// RealClock is the production clock.
func RealClock() Clock { return realClock{} }

// MatchConfig is everything one match needs, resolved before the first
// question so the loop itself is pure scheduling.
type MatchConfig struct {
        MatchID            string
        Code               string // pack code both players play
        Body               string
        Questions          []QView
        Key                map[string]string // questionID -> correct letter (server-only)
        SecondsPerQuestion int
        IntroCountdown     time.Duration
        BotSkill           float64 // 0..1, chance the bot's roll lands correct
}

// ParticipantResult is one player's final line for persistence.
type ParticipantResult struct {
        UserID   string
        Username string
        Score    int
        Correct  int
        Answered int
        IsBot    bool
}

// MatchResult is the durable outcome of one match. Live state never
// crosses this boundary mid-game.
type MatchResult struct {
        MatchID      string
        Code         string
        Body         string
        Status       string // "finished" | "aborted"
        WinnerID     string // "" = draw or aborted
        Participants []ParticipantResult
}

// MatchSink persists outcomes, best-effort by contract: an error here is
// logged and forgotten, never propagated into a live match.
type MatchSink interface {
        SaveMatch(ctx context.Context, r MatchResult) error
}

// SinkFunc adapts a plain function to MatchSink (wiring glue in main).
type SinkFunc func(ctx context.Context, r MatchResult) error

func (f SinkFunc) SaveMatch(ctx context.Context, r MatchResult) error { return f(ctx, r) }

type answerMsg struct {
        p      *Player
        index  int
        letter string
}

// liveMatch is the goroutine-owned state machine of one running match.
// All mutation happens on its own goroutine; the outside world talks to
// it exclusively through the answers and gone channels.
type liveMatch struct {
        cfg     MatchConfig
        a, b    *Player
        answers chan answerMsg
        gone    chan *Player
        clock   Clock
        rnd     *rand.Rand
        sink    MatchSink
        log     *slog.Logger
        onDone  func(matchID string)

        botPlan []string // pre-rolled bot letter per question ("" = none)
        scores  map[string]int
        correct map[string]int
        answered map[string]int
        picks   map[string]string // userID -> letter picked this question
}

const (
        // botMaxSeed keeps bot IDs bounded for the seeded rand.
        botMaxSeed = 1 << 30
)

func newLiveMatch(cfg MatchConfig, a, b *Player, clock Clock, rnd *rand.Rand, sink MatchSink, log *slog.Logger, onDone func(string)) *liveMatch {
        m := &liveMatch{
                cfg: cfg, a: a, b: b,
                answers: make(chan answerMsg, 8),
                gone:    make(chan *Player, 2),
                clock:   clock, rnd: rnd, sink: sink, log: log, onDone: onDone,
                scores:   map[string]int{a.UserID: 0, b.UserID: 0},
                correct:  map[string]int{a.UserID: 0, b.UserID: 0},
                answered: map[string]int{a.UserID: 0, b.UserID: 0},
                picks:    map[string]string{},
        }
        if b.IsBot {
                m.botPlan = m.rollBotPlan()
        }
        return m
}

// rollBotPlan decides, per question, which letter the bot will "pick" by
// the deadline: the correct one with probability BotSkill, else a wrong
// one (falls back to the only option when the question has a single
// choice, in which case it is always correct — nobody's perfect).
func (m *liveMatch) rollBotPlan() []string {
        plan := make([]string, len(m.cfg.Questions))
        for i, q := range m.cfg.Questions {
                key := m.cfg.Key[q.ID]
                if m.rnd.Float64() < m.cfg.BotSkill {
                        plan[i] = key
                        continue
                }
                wrong := wrongLetter(q.Options, key, m.rnd)
                plan[i] = wrong
        }
        return plan
}

func wrongLetter(options map[string]string, key string, rnd *rand.Rand) string {
        letters := make([]string, 0, len(options))
        for l := range options {
                if l != key {
                        letters = append(letters, l)
                }
        }
        if len(letters) == 0 {
                return key // single-option question: wrong is impossible
        }
        return letters[rnd.Intn(len(letters))]
}

// run drives the whole match to completion. Exactly one goroutine per
// match, started by the hub after both sides saw "matched".
func (m *liveMatch) run() {
        defer m.done()

        // Intro countdown: both clients flip to the match screen.
        select {
        case <-m.clock.After(m.cfg.IntroCountdown):
        case p := <-m.gone:
                m.forfeit(p)
                return
        }

        for i := range m.cfg.Questions {
                if !m.playQuestion(i) {
                        return // forfeit already finalised the match
                }
        }
        m.finalise("finished")
}

// playQuestion broadcasts question [i], collects answers until both
// humans picked or the deadline fires, then pushes the reveal. Returns
// false when a forfeit ended the match mid-question.
func (m *liveMatch) playQuestion(i int) bool {
        q := m.cfg.Questions[i]
        key := m.cfg.Key[q.ID]
        deadline := m.clock.Now().Add(time.Duration(m.cfg.SecondsPerQuestion) * time.Second)
        timeout := m.clock.After(time.Duration(m.cfg.SecondsPerQuestion) * time.Second)

        m.picks = map[string]string{}
        for _, p := range []*Player{m.a, m.b} {
                if !p.IsBot {
                        p.Send(Outbound{
                                Type: OutQuestion, Index: i, Deadline: deadline.Unix(),
                                Question: &QView{ID: q.ID, Stem: q.Stem, Options: q.Options, Marks: q.Marks},
                        })
                }
        }

        humans := m.humans()
        for {
                if m.allPicked(humans) {
                        break
                }
                select {
                case ans := <-m.answers:
                        if ans.index != i || m.picks[ans.p.UserID] != "" {
                                continue // stale or duplicate, ignore silently
                        }
                        if _, ok := q.Options[ans.letter]; !ok {
                                continue // not a real option, ignore
                        }
                        m.picks[ans.p.UserID] = ans.letter
                        m.answered[ans.p.UserID]++
                case <-timeout:
                        // Deadline: everyone who did not pick simply missed it.
                        goto evaluate
                case p := <-m.gone:
                        m.forfeit(p)
                        return false
                }
        }

evaluate:
        solved := map[string]bool{}
        for _, p := range []*Player{m.a, m.b} {
                pick := m.picks[p.UserID]
                if p.IsBot && pick == "" {
                        // The bot always "picks by the deadline": apply its roll.
                        pick = m.botPlan[i]
                        m.picks[p.UserID] = pick
                        m.answered[p.UserID]++
                }
                right := pick != "" && pick == key
                if right {
                        m.scores[p.UserID] += q.Marks
                        m.correct[p.UserID]++
                }
                solved[p.UserID] = right
        }
        snapshot := map[string]int{}
        for id, s := range m.scores {
                snapshot[id] = s
        }
        for _, p := range []*Player{m.a, m.b} {
                p.Send(Outbound{Type: OutResult, Index: i, Correct: key, Scores: snapshot, Solved: solved})
        }
        return true
}

func (m *liveMatch) humans() []*Player {
        out := make([]*Player, 0, 2)
        for _, p := range []*Player{m.a, m.b} {
                if !p.IsBot {
                        out = append(out, p)
                }
        }
        return out
}

func (m *liveMatch) allPicked(humans []*Player) bool {
        for _, p := range humans {
                if m.picks[p.UserID] == "" {
                        return false
                }
        }
        return true
}

// forfeit ends the match because [gone] lost its connection: the survivor
// wins if one remains, nobody wins if both are gone.
func (m *liveMatch) forfeit(gone *Player) {
        other := m.a
        if gone == m.a {
                other = m.b
        }
        select {
        case <-other.done():
                // Both sides are unreachable: nobody wins this one.
                m.finaliseAborted()
                return
        default:
        }
        other.Send(Outbound{
                Type: OutOver, MatchID: m.cfg.MatchID, Winner: other.UserID,
                Scores: m.snapshotScores(),
        })
        m.persist("aborted", other.UserID)
}

// finaliseAborted closes out a match nobody can play any more (both
// connections gone): no reveal, no winner, straight to persistence.
func (m *liveMatch) finaliseAborted() {
        m.persist("aborted", "")
}

// finalise scores the completed match and pushes "over" to humans.
func (m *liveMatch) finalise(status string) {
        winner := ""
        switch {
        case m.scores[m.a.UserID] > m.scores[m.b.UserID]:
                winner = m.a.UserID
        case m.scores[m.b.UserID] > m.scores[m.a.UserID]:
                winner = m.b.UserID
        }
        for _, p := range m.humans() {
                p.Send(Outbound{
                        Type: OutOver, MatchID: m.cfg.MatchID, Winner: winner,
                        Scores: m.snapshotScores(),
                })
        }
        m.persist(status, winner)
}

func (m *liveMatch) snapshotScores() map[string]int {
        out := map[string]int{}
        for id, s := range m.scores {
                out[id] = s
        }
        return out
}

// persist hands the outcome to the sink with a hard timeout; a failure
// is logged and dropped, the players already have their result.
func (m *liveMatch) persist(status, winner string) {
        if m.sink == nil {
                return
        }
        r := MatchResult{
                MatchID: m.cfg.MatchID, Code: m.cfg.Code, Body: m.cfg.Body,
                Status: status, WinnerID: winner,
        }
        for _, p := range []*Player{m.a, m.b} {
                r.Participants = append(r.Participants, ParticipantResult{
                        UserID:   p.UserID,
                        Username: p.Username,
                        Score:    m.scores[p.UserID],
                        Correct:  m.correct[p.UserID],
                        Answered: m.answered[p.UserID],
                        IsBot:    p.IsBot,
                })
        }
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        if err := m.sink.SaveMatch(ctx, r); err != nil {
                m.log.Error("arena: persist match", "match", m.cfg.MatchID, "err", err)
        }
}

func (m *liveMatch) done() {
        if m.onDone != nil {
                m.onDone(m.cfg.MatchID)
        }
}
