package arena

import (
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	mrand "math/rand"
	"strings"
	"sync"
	"time"
)

// Config tunes the hub. Everything has a safe default in DefaultConfig.
type Config struct {
	Questions          int           // questions per match
	SecondsPerQuestion int           // answer window per question
	IntroCountdown     time.Duration // matched -> first question
	BotWait            time.Duration // solo queuer waits this long, then the bot plays
	BotSkill           float64       // 0..1, chance the bot's roll lands correct
}

// DefaultConfig matches the shipped defaults (ARENA_* env overrides).
func DefaultConfig() Config {
	return Config{
		Questions:          5,
		SecondsPerQuestion: 15,
		IntroCountdown:     3 * time.Second,
		BotWait:            20 * time.Second,
		BotSkill:           0.6,
	}
}

// PackSource resolves which pack a match plays. The httpapi wiring backs
// it with the content library + answer-key cache; tests use fakes.
type PackSource interface {
	// PickPack returns a random pack for [body] ("" = any body) that has
	// a server-side answer key, plus its student-safe question views.
	PickPack(body string) (code string, qs []QView, key map[string]string, ok bool)
}

// allowedBodies mirrors the server's boot-time body allowlist; the empty
// string means "any body" and gets its own bucket.
var allowedBodies = map[string]struct{}{
	"JAMB": {}, "WAEC": {}, "NECO": {}, "University Modules": {},
}

const anyBucket = "*"

// Hub is the in-process arena: matchmaking queues, presence and the set
// of live matches. One Hub per process; a multi-host deployment is the
// later Redis slice, this one keeps every rule honest and testable.
type Hub struct {
	cfg   Config
	packs PackSource
	sink  MatchSink
	log   *slog.Logger
	clock Clock
	rnd   *mrand.Rand

	mu      sync.Mutex
	queues  map[string][]*Player // bucket -> FIFO of waiting players
	players map[string]*Player   // userID -> live session
	matches map[string]*liveMatch
	wg      sync.WaitGroup // bot timers + match goroutines

	stopCh   chan struct{}
	stopOnce sync.Once
	stopped  bool
	botSeed  uint64
}

func NewHub(cfg Config, packs PackSource, sink MatchSink, log *slog.Logger) *Hub {
	if cfg.Questions <= 0 {
		cfg.Questions = 5
	}
	if cfg.SecondsPerQuestion <= 0 {
		cfg.SecondsPerQuestion = 15
	}
	if cfg.IntroCountdown <= 0 {
		cfg.IntroCountdown = 3 * time.Second
	}
	if cfg.BotWait <= 0 {
		cfg.BotWait = 20 * time.Second
	}
	if cfg.BotSkill < 0 || cfg.BotSkill > 1 {
		cfg.BotSkill = 0.6
	}
	return &Hub{
		cfg: cfg, packs: packs, sink: sink, log: log,
		clock:   RealClock(),
		rnd:     mrand.New(mrand.NewSource(time.Now().UnixNano())),
		queues:  map[string][]*Player{},
		players: map[string]*Player{},
		matches: map[string]*liveMatch{},
		stopCh:  make(chan struct{}),
	}
}

// setClock overrides the clock (tests only).
func (h *Hub) setClock(c Clock) { h.clock = c }

// Attach registers a freshly authenticated session. A user gets exactly
// one live session: replacing an idle/queued session is fine, joining
// while a match is running is refused (the running match owns the user).
func (h *Hub) Attach(p *Player, peer Peer) {
	h.mu.Lock()
	if h.stopped {
		h.mu.Unlock()
		peer.Send(Outbound{Type: OutError, ErrCode: ErrShuttingDown, ErrMsg: "arena is shutting down"})
		peer.Close()
		return
	}
	if old, ok := h.players[p.UserID]; ok && old != p {
		if old.match != nil {
			h.mu.Unlock()
			peer.Send(Outbound{Type: OutError, ErrCode: ErrInMatch, ErrMsg: "you are already in a live match on another connection"})
			peer.Close()
			return
		}
		h.removeFromBucketLocked(old, old.bucket)
		old.inBag = false
		old.Send(Outbound{Type: OutError, ErrCode: ErrReplaced, ErrMsg: "signed in elsewhere"})
		if op := old.currentPeer(); op != nil {
			op.Close()
		}
	}
	p.mu.Lock()
	p.peer = peer
	p.mu.Unlock()
	h.players[p.UserID] = p
	h.mu.Unlock()

	go h.watch(p)
}

// watch runs presence: when the connection dies the session leaves the
// queue and forfeits any live match.
func (h *Hub) watch(p *Player) {
	select {
	case <-p.done():
	case <-h.stopCh:
		return
	}
	h.Detach(p)
}

// Detach drops a session entirely: out of the registry, out of any
// queue, out of any live match (forfeit). Idempotent.
func (h *Hub) Detach(p *Player) {
	h.mu.Lock()
	cur, ok := h.players[p.UserID]
	if !ok || cur != p {
		h.mu.Unlock()
		return // replaced by a newer session; not ours to clean
	}
	delete(h.players, p.UserID)
	m := p.match
	p.inBag = false
	h.removeFromBucketLocked(p, p.bucket)
	h.mu.Unlock()

	if m != nil {
		select {
		case m.gone <- p:
		default:
		}
	}
}

// Queue puts [p] in the matchmaking bucket for [body] and pairs the
// moment two students wait for the same bucket.
func (h *Hub) Queue(p *Player, body string) {
	body = strings.TrimSpace(body)
	if body != "" {
		if _, ok := allowedBodies[body]; !ok {
			p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownBody, ErrMsg: "unknown exam body " + body})
			return
		}
	}
	h.mu.Lock()
	if h.stopped {
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrShuttingDown, ErrMsg: "arena is shutting down"})
		return
	}
	if p.match != nil {
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrInMatch, ErrMsg: "finish your live match first"})
		return
	}
	if p.inBag {
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyQueued, ErrMsg: "you are already in the queue"})
		return
	}
	bucket := body
	if bucket == "" {
		bucket = anyBucket
	}
	p.inBag = true
	p.bucket = bucket
	h.queues[bucket] = append(h.queues[bucket], p)
	alone := len(h.queues[bucket]) == 1
	h.mu.Unlock()

	p.Send(Outbound{Type: OutQueued, Body: body})
	if alone {
		h.scheduleBotFill(bucket, p)
		return
	}
	h.tryPair(bucket)
}

// Cancel pulls [p] out of the matchmaking queue.
func (h *Hub) Cancel(p *Player) {
	h.mu.Lock()
	if !p.inBag {
		h.mu.Unlock()
		return // not queued; nothing to undo
	}
	h.removeFromBucketLocked(p, p.bucket)
	p.inBag = false
	h.mu.Unlock()
	p.Send(Outbound{Type: OutCancelled})
}

// Answer routes a pick to the player's live match. Non-blocking: a full
// or missing match pipe simply drops the answer (late is late).
func (h *Hub) Answer(p *Player, index int, letter string) {
	h.mu.Lock()
	m := p.match
	h.mu.Unlock()
	if m == nil {
		return
	}
	select {
	case m.answers <- answerMsg{p: p, index: index, letter: letter}:
	default:
	}
}

// scheduleBotFill fires the bot after BotWait if [p] is still waiting
// alone in [bucket].
func (h *Hub) scheduleBotFill(bucket string, p *Player) {
	h.wg.Add(1)
	go func() {
		defer h.wg.Done()
		timer := h.clock.After(h.cfg.BotWait)
		select {
		case <-timer:
		case <-h.stopCh:
			return
		}
		h.fillBot(bucket, p)
	}()
}

func (h *Hub) fillBot(bucket string, p *Player) {
	h.mu.Lock()
	if h.stopped || !p.inBag || p.bucket != bucket {
		h.mu.Unlock()
		return // matched a human in the meantime, or left
	}
	h.removeFromBucketLocked(p, bucket)
	p.inBag = false
	h.mu.Unlock()

	h.botSeed++
	bot := newBot(h.botSeed)
	h.startMatch(p, bot, bucket)
}

// tryPair pops two waiting players from [bucket] and starts a match.
func (h *Hub) tryPair(bucket string) {
	h.mu.Lock()
	q := h.queues[bucket]
	if len(q) < 2 {
		h.mu.Unlock()
		return
	}
	a, b := q[0], q[1]
	h.queues[bucket] = q[2:]
	a.inBag, b.inBag = false, false
	h.mu.Unlock()
	h.startMatch(a, b, bucket)
}

// startMatch resolves the pack, announces the pairing and launches the
// match goroutine. Failures (no playable pack) bounce both players with
// a clean error instead of a half-open lobby.
func (h *Hub) startMatch(a, b *Player, bucket string) {
	body := bucket
	if body == anyBucket {
		body = ""
	}
	code, qs, key, ok := h.packs.PickPack(body)
	if !ok || len(qs) == 0 {
		for _, p := range []*Player{a, b} {
			p.Send(Outbound{Type: OutError, ErrCode: ErrNoPack, ErrMsg: "no pack with an answer key is available for this body right now"})
		}
		return
	}
	// Trim to the configured match length, pack order.
	if len(qs) > h.cfg.Questions {
		qs = qs[:h.cfg.Questions]
	}

	cfg := MatchConfig{
		MatchID:            h.newID(),
		Code:               code,
		Body:               body,
		Questions:          qs,
		Key:                key,
		SecondsPerQuestion: h.cfg.SecondsPerQuestion,
		IntroCountdown:     h.cfg.IntroCountdown,
		BotSkill:           h.cfg.BotSkill,
	}

	h.mu.Lock()
	m := newLiveMatch(cfg, a, b, h.clock, mrand.New(mrand.NewSource(h.rnd.Int63())), h.sink, h.log, h.matchDone)
	a.match, b.match = m, m
	h.matches[cfg.MatchID] = m
	h.mu.Unlock()

	a.Send(Outbound{
		Type: OutMatched, MatchID: cfg.MatchID, Opponent: b.Username,
		Code: code, Body: body, Questions: len(qs), Seconds: h.cfg.SecondsPerQuestion,
	})
	b.Send(Outbound{
		Type: OutMatched, MatchID: cfg.MatchID, Opponent: a.Username,
		Code: code, Body: body, Questions: len(qs), Seconds: h.cfg.SecondsPerQuestion,
	})

	h.wg.Add(1)
	go func() {
		defer h.wg.Done()
		m.run()
	}()
}

// matchDone clears the live-match refs once a match goroutine exits.
func (h *Hub) matchDone(matchID string) {
	h.mu.Lock()
	m, ok := h.matches[matchID]
	if ok {
		delete(h.matches, matchID)
	}
	h.mu.Unlock()
	if !ok {
		return
	}
	h.mu.Lock()
	if m.a.match == m {
		m.a.match = nil
	}
	if m.b.match == m {
		m.b.match = nil
	}
	h.mu.Unlock()
}

// Status is the observability surface behind GET /arena/status.
type Status struct {
	Waiting map[string]int `json:"waiting"`
	Live    int            `json:"liveMatches"`
}

func (h *Hub) Status() Status {
	h.mu.Lock()
	defer h.mu.Unlock()
	out := Status{Waiting: map[string]int{}}
	for bucket, q := range h.queues {
		if len(q) > 0 {
			out.Waiting[bucket] = len(q)
		}
	}
	out.Live = len(h.matches)
	return out
}

// Stop tears everything down: bot timers exit, every live match forfeits
// through its own presence path, every socket gets a clean goodbye.
func (h *Hub) Stop() {
	h.stopOnce.Do(func() {
		close(h.stopCh)
	})
	h.mu.Lock()
	h.stopped = true
	players := make([]*Player, 0, len(h.players))
	for _, p := range h.players {
		players = append(players, p)
	}
	h.players = map[string]*Player{}
	h.queues = map[string][]*Player{}
	matches := make([]*liveMatch, 0, len(h.matches))
	for _, m := range h.matches {
		matches = append(matches, m)
	}
	h.matches = map[string]*liveMatch{}
	h.mu.Unlock()

	for _, m := range matches {
		select {
		case m.gone <- m.a:
		default:
		}
	}
	for _, p := range players {
		p.Send(Outbound{Type: OutError, ErrCode: ErrShuttingDown, ErrMsg: "arena is shutting down"})
		if peer := p.currentPeer(); peer != nil {
			peer.Close()
		}
	}
	h.wg.Wait()
}

func (h *Hub) removeFromBucketLocked(p *Player, bucket string) {
	q := h.queues[bucket]
	for i, w := range q {
		if w == p {
			h.queues[bucket] = append(q[:i], q[i+1:]...)
			return
		}
	}
}

func (h *Hub) newID() string {
	var buf [6]byte
	if _, err := rand.Read(buf[:]); err != nil {
		return "m-fallback"
	}
	return "m-" + hex.EncodeToString(buf[:])
}
