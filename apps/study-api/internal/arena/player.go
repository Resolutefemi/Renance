package arena

import (
	"strconv"
	"sync"
)

// Peer is the transport behind one connected player. The hub and the
// match loop speak only to this interface, so every rule runs in tests
// over in-memory fakes with zero sockets (the SpeechEngine rule, server
// edition). Production wires it to a WebSocket in ws.go.
type Peer interface {
	// Send delivers one outbound message, best-effort. It must never
	// block the caller for long and must be safe to call concurrently
	// with Close.
	Send(Outbound)
	// Close tears the transport down (client sees the socket die).
	// Idempotent, safe to call concurrently with Send.
	Close()
	// Done closes when the connection is gone for any reason. The hub
	// listens for this to run presence cleanup.
	Done() <-chan struct{}
}

// Player is one authenticated identity on the arena. Exactly one live
// Player per user at a time: a fresh connection replaces the old one
// (the stale socket gets ErrReplaced and dies).
type Player struct {
	UserID   string
	Username string
	IsBot    bool

	peer Peer

	mu     sync.Mutex
	inBag  bool   // sitting in a matchmaking queue
	bucket string // queue key, ""-normalized; only meaningful while inBag
	match  *liveMatch
}

func (p *Player) Send(o Outbound) {
	if p.IsBot {
		return // the bot has no socket; its voice is the scoreboard
	}
	if peer := p.currentPeer(); peer != nil {
		peer.Send(o)
	}
}

func (p *Player) currentPeer() Peer {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.peer
}

func (p *Player) done() <-chan struct{} {
	if p.IsBot {
		ch := make(chan struct{})
		return ch // never fires
	}
	if peer := p.currentPeer(); peer != nil {
		return peer.Done()
	}
	closed := make(chan struct{})
	close(closed)
	return closed
}

// botID prefixes every synthetic player's userID so persistence can spot
// bot rows without an extra flag lookup.
const botID = "bot:"

// newBot builds the house opponent. BotSkill governs how often it picks
// the right letter; the roll happens per question inside the match.
func newBot(seed uint64) *Player {
	return &Player{
		UserID:   botID + strconv.FormatUint(seed, 10),
		Username: "Renance Bot",
		IsBot:    true,
	}
}
