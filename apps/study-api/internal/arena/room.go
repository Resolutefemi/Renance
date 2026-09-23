package arena

import (
	"crypto/rand"
	"errors"
	"strings"
	"time"
)

// Private rooms (ROADMAP #14 slice): a student hosts a room, shares the
// short code with a friend over any channel, and the friend's join starts
// the match directly - no public queue, no house bot. The room lives in
// the hub's memory exactly like the matchmaking queues: one process, one
// source of truth; the Redis/multi-host slice moves all of it together.
//
// Lifecycle rules (each one is pinned by a test):
//   - host disconnects / is replaced  -> the room dies with the session
//   - host sends "cancel"             -> the room dies, host goes idle
//   - host sends "queue" or "join"    -> refused (cancel the room first);
//     one live lobby per session, no silent state changes
//   - join with an unknown/expired code -> unknown_room, nothing else moves
//   - the FIRST join consumes the room (delete-then-start under the lock),
//     so a leaked code can never start a second match
//   - a room nobody joins expires after RoomTTL; expiry is swept lazily
//     on join attempts and on Status, so no janitor goroutine exists
//
// No bot fill here on purpose: friends invite each other, and a bot that
// barges into a private lobby would defeat the whole point. The host
// simply waits until someone joins or the room dies.

// roomAlphabet drops I, L, O, 0 and 1 so codes read cleanly aloud in the
// classroom contexts this feature is built for ("text your friend the
// code" should never hinge on 0 vs O over a bad photo of a screen).
const roomAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

const (
	roomCodeLen   = 6
	roomCodeTries = 8 // collision retries before giving up (practically never)
)

// room is one private lobby waiting for its second player.
type room struct {
	code      string
	bucket    string // matchmaking bucket the match will play in (body or "*")
	host      *Player
	expiresAt time.Time
}

// normalizeRoomCode canonicalizes what a client echoes back: trimmed and
// upper-cased, nothing else - the code never contained separators.
func normalizeRoomCode(code string) string {
	return strings.ToUpper(strings.TrimSpace(code))
}

// newRoomCodeLocked mints a fresh code that is not yet taken. Randomness
// comes from crypto/rand for the same reason match IDs do: a guessable
// code would let a stranger crash a private lobby.
func (h *Hub) newRoomCodeLocked() (string, error) {
	for try := 0; try < roomCodeTries; try++ {
		var buf [roomCodeLen]byte
		if _, err := rand.Read(buf[:]); err != nil {
			return "", err
		}
		code := make([]byte, roomCodeLen)
		for i, b := range buf {
			code[i] = roomAlphabet[int(b)%len(roomAlphabet)]
		}
		if _, taken := h.rooms[string(code)]; !taken {
			return string(code), nil
		}
	}
	return "", errors.New("room code space exhausted")
}

// deleteRoomLocked removes the room and clears its host's back-pointer.
// Callers hold h.mu.
func (h *Hub) deleteRoomLocked(r *room) {
	if _, ok := h.rooms[r.code]; !ok {
		return
	}
	delete(h.rooms, r.code)
	if r.host.hosting == r {
		r.host.hosting = nil
	}
}

// sweepRoomsLocked expires every room past its TTL (deleting while
// ranging is safe in Go). Callers hold h.mu.
func (h *Hub) sweepRoomsLocked(now time.Time) {
	for code, r := range h.rooms {
		if now.After(r.expiresAt) {
			h.deleteRoomLocked(r)
			_ = code // range key; deleteRoomLocked already removed the entry
		}
	}
}

// Host opens a private room for [p], optionally scoped to one exam body.
// The host stays attached but out of every queue: the room IS their lobby.
func (h *Hub) Host(p *Player, body string) {
	body = strings.TrimSpace(body)
	if body != "" {
		if _, ok := allowedBodies[body]; !ok {
			p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownBody, ErrMsg: "unknown exam body " + body})
			return
		}
	}
	bucket := body
	if bucket == "" {
		bucket = anyBucket
	}

	h.mu.Lock()
	switch {
	case h.stopped:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrShuttingDown, ErrMsg: "arena is shutting down"})
		return
	case p.match != nil:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrInMatch, ErrMsg: "finish your live match first"})
		return
	case p.inBag:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyQueued, ErrMsg: "leave the matchmaking queue first (cancel)"})
		return
	case p.hosting != nil:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyHost, ErrMsg: "you are already hosting a room"})
		return
	}
	code, err := h.newRoomCodeLocked()
	if err != nil {
		h.mu.Unlock()
		h.log.Error("arena: room code allocation failed", "err", err)
		p.Send(Outbound{Type: OutError, ErrCode: ErrRoomUnavailable, ErrMsg: "could not allocate a room code, try again"})
		return
	}
	r := &room{code: code, bucket: bucket, host: p, expiresAt: h.clock.Now().Add(h.cfg.RoomTTL)}
	h.rooms[code] = r
	p.hosting = r
	h.mu.Unlock()

	p.Send(Outbound{Type: OutHosted, Code: r.code, Body: body})
}

// JoinRoom pairs [p] with the host of room [code] and starts the match
// immediately. Exactly one join ever consumes a room: the pop happens
// under the same lock that validates it, so a stale or double-joined
// code degrades to a clean unknown_room.
func (h *Hub) JoinRoom(p *Player, code string) {
	code = normalizeRoomCode(code)

	h.mu.Lock()
	switch {
	case h.stopped:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrShuttingDown, ErrMsg: "arena is shutting down"})
		return
	case p.match != nil:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrInMatch, ErrMsg: "finish your live match first"})
		return
	case p.inBag:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyQueued, ErrMsg: "leave the matchmaking queue first (cancel)"})
		return
	case p.hosting != nil:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyHost, ErrMsg: "cancel your own room before joining another"})
		return
	}
	r, ok := h.rooms[code]
	if !ok {
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownRoom, ErrMsg: "no waiting room with that code"})
		return
	}
	if h.clock.Now().After(r.expiresAt) {
		h.deleteRoomLocked(r)
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownRoom, ErrMsg: "that room has expired"})
		return
	}
	host := r.host
	if h.players[host.UserID] != host {
		// The host's session was replaced by a new connection; the room is
		// bound to the session that created it, so it is dead already.
		h.deleteRoomLocked(r)
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownRoom, ErrMsg: "no waiting room with that code"})
		return
	}
	bucket := r.bucket
	h.deleteRoomLocked(r)
	h.mu.Unlock()

	h.startMatch(host, p, bucket)
}

// Challenge invites a specific online student to a duel: the challenger
// auto-hosts a room scoped to [body] and the target receives a live
// invite frame carrying the code. Accepting is the ordinary join path
// (the room's code IS the handshake), so declining is just ignoring it
// and the RoomTTL janitor logic cleans up behind everyone.
//
// Deliverable contract:
//   - challenger gets "challenge_sent" (with the code to share as a
//     fallback over any channel) or a typed error
//   - target gets "challenge" {opponent, code, body} while online
//
// A target who is mid-match cannot be invited; a target who is queued
// or hosting CAN be - their client decides whether to surface the
// invite, and joining auto-cancels their own lobby through the
// ordinary JoinRoom guards.
func (h *Hub) Challenge(p *Player, targetUserID, body string) {
	body = strings.TrimSpace(body)
	if body != "" {
		if _, ok := allowedBodies[body]; !ok {
			p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownBody, ErrMsg: "unknown exam body " + body})
			return
		}
	}
	bucket := body
	if bucket == "" {
		bucket = anyBucket
	}

	h.mu.Lock()
	switch {
	case h.stopped:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrShuttingDown, ErrMsg: "arena is shutting down"})
		return
	case p.match != nil:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrInMatch, ErrMsg: "finish your live match first"})
		return
	case p.inBag:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyQueued, ErrMsg: "leave the matchmaking queue first (cancel)"})
		return
	case p.hosting != nil:
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrAlreadyHost, ErrMsg: "cancel your room before challenging again"})
		return
	}
	target, ok := h.players[targetUserID]
	if !ok || target == p || target.IsBot {
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrUnknownPlayer, ErrMsg: "that student is not in the arena right now"})
		return
	}
	if target.match != nil {
		h.mu.Unlock()
		p.Send(Outbound{Type: OutError, ErrCode: ErrInMatch, ErrMsg: target.Username + " is already in a live match"})
		return
	}
	targetUsername := target.Username
	code, err := h.newRoomCodeLocked()
	if err != nil {
		h.mu.Unlock()
		h.log.Error("arena: room code allocation failed", "err", err)
		p.Send(Outbound{Type: OutError, ErrCode: ErrRoomUnavailable, ErrMsg: "could not allocate a room code, try again"})
		return
	}
	r := &room{code: code, bucket: bucket, host: p, expiresAt: h.clock.Now().Add(h.cfg.RoomTTL)}
	h.rooms[code] = r
	p.hosting = r
	h.mu.Unlock()

	p.Send(Outbound{Type: OutChallengeSent, Code: code, Body: body, Opponent: targetUsername})
	target.Send(Outbound{Type: OutChallenge, Code: code, Body: body, Opponent: p.Username})
}

// OnlinePlayer is one live human presence in the arena (the
// "active players" list behind GET /arena/players).
type OnlinePlayer struct {
	UserID   string `json:"userId"`
	Username string `json:"username"`
}

// OnlinePlayers lists every attached human who is idle enough to duel:
// connected, not mid-match, not already waiting in a queue or lobby.
// The HTTP layer enriches the rows with each student's Ren Points.
func (h *Hub) OnlinePlayers() []OnlinePlayer {
	h.mu.Lock()
	defer h.mu.Unlock()
	out := make([]OnlinePlayer, 0, len(h.players))
	for _, p := range h.players {
		if p.IsBot || p.match != nil || p.inBag || p.hosting != nil {
			continue
		}
		out = append(out, OnlinePlayer{UserID: p.UserID, Username: p.Username})
	}
	sortOnline(out)
	return out
}

// sortOnline orders the presence list by username so the lobby list is
// stable between polls.
func sortOnline(s []OnlinePlayer) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j].Username < s[j-1].Username; j-- {
			s[j], s[j-1] = s[j-1], s[j]
		}
	}
}
