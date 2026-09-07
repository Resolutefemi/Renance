package arena

import (
	"strings"
	"testing"
	"time"
)

// ------------------------------------------------------------------ helpers

// hostedCode extracts the room code from the host's latest "hosted"
// frame (peers accumulate frames across re-hosts).
func hostedCode(t *testing.T, p *fakePeer) string {
	t.Helper()
	frames := p.ofType(OutHosted)
	if len(frames) == 0 {
		t.Fatal("no hosted frame arrived")
	}
	return frames[len(frames)-1].Code
}

// errCode returns the last error frame's code, "" when none arrived.
func errCode(p *fakePeer) string {
	frames := p.ofType(OutError)
	if len(frames) == 0 {
		return ""
	}
	return frames[len(frames)-1].ErrCode
}

// playThrough drives a running match to "over" the way real clients do:
// wait for each question, both sides pick, collect the reveal. Alice
// always plays the key; Bola always plays a wrong option, so Alice wins.
func playThrough(h *hubTest, n int) {
	for i := 0; i < n; i++ {
		hi := i
		h.clock.advanceUntil(func() bool { return h.peer1.count(OutQuestion) == hi+1 }, 10*time.Second)
		q := h.peer1.ofType(OutQuestion)[hi].Question
		key := h.key[q.ID]
		h.hub.Answer(h.p1, hi, key)
		for letter := range q.Options {
			if letter != key {
				h.hub.Answer(h.p2, hi, letter)
				break
			}
		}
		h.clock.advanceUntil(func() bool {
			return h.peer1.count(OutResult) == hi+1 && h.peer2.count(OutResult) == hi+1
		}, 10*time.Second)
	}
	h.clock.advanceUntil(func() bool {
		return h.peer1.count(OutOver) == 1 && h.peer2.count(OutOver) == 1
	}, 10*time.Second)
}

// ------------------------------------------------------------------ rules

func TestHostIssuesShareableCodeAndWaits(t *testing.T) {
	h := newHubTest(t, Config{
		Questions: 2, SecondsPerQuestion: 10,
		IntroCountdown: time.Second, BotWait: 30 * time.Second, BotSkill: 0.6,
	})
	h.hub.Host(h.p1, "JAMB")

	code := hostedCode(t, h.peer1)
	if len(code) != roomCodeLen {
		t.Fatalf("room code %q is %d chars, want %d", code, len(code), roomCodeLen)
	}
	for _, c := range code {
		if !strings.ContainsRune(roomAlphabet, c) {
			t.Fatalf("room code %q contains ambiguous character %q", code, c)
		}
	}
	if got := h.peer1.ofType(OutHosted)[0].Body; got != "JAMB" {
		t.Fatalf("hosted body = %q, want JAMB", got)
	}

	// Hosting is NOT queueing: no queued frame, and the house bot must
	// never barge into a private lobby when the wait fires.
	if got := h.peer1.count(OutQueued); got != 0 {
		t.Fatalf("host got %d queued frames, want 0", got)
	}
	h.clock.Advance(45 * time.Second)
	time.Sleep(10 * time.Millisecond)
	if got := h.peer1.count(OutMatched); got != 0 {
		t.Fatalf("bot filled a private room (matched frames = %d)", got)
	}
	if h.hub.Status().PrivateRooms != 1 {
		t.Fatalf("privateRooms = %d, want 1", h.hub.Status().PrivateRooms)
	}
}

func TestJoinStartsTheMatchImmediately(t *testing.T) {
	h := newHubTest(t, Config{
		Questions: 2, SecondsPerQuestion: 10,
		IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
	})
	h.hub.Host(h.p1, "JAMB")
	code := hostedCode(t, h.peer1)

	// Codes are case-insensitive: a friend typing it lower-case still lands.
	h.hub.JoinRoom(h.p2, strings.ToLower(code))

	waitFor(t, func() bool { return h.peer1.count(OutMatched) == 1 && h.peer2.count(OutMatched) == 1 })
	ma := h.peer1.ofType(OutMatched)[0]
	mb := h.peer2.ofType(OutMatched)[0]
	if ma.MatchID == "" || ma.MatchID != mb.MatchID {
		t.Fatalf("match ids differ: %q vs %q", ma.MatchID, mb.MatchID)
	}
	if ma.Opponent != "Bola" || mb.Opponent != "Alice" {
		t.Fatalf("opponent names wrong: %q / %q", ma.Opponent, mb.Opponent)
	}

	playThrough(h, 2)
	over := h.peer1.ofType(OutOver)[0]
	if over.Winner != "u1" {
		t.Fatalf("winner = %q, want u1 (both played the key)", over.Winner)
	}
	waitFor(t, func() bool { return len(h.sink.all()) == 1 })
	if h.hub.Status().PrivateRooms != 0 {
		t.Fatalf("room survived its own match, privateRooms = %d", h.hub.Status().PrivateRooms)
	}
}

func TestJoinUnknownOrGarbageCodeIsACleanError(t *testing.T) {
	h := newHubTest(t, Config{BotWait: time.Hour})
	h.hub.JoinRoom(h.p2, "ZZZZZZ")
	if got := errCode(h.peer2); got != ErrUnknownRoom {
		t.Fatalf("error = %q, want %q", got, ErrUnknownRoom)
	}

	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)
	// Lower-case and whitespace around an otherwise-valid code normalize.
	h.hub.JoinRoom(h.p2, "  "+strings.ToLower(code)+"  ")
	waitFor(t, func() bool { return h.peer1.count(OutMatched) == 1 })
}

func TestRoomIsConsumedExactlyOnce(t *testing.T) {
	h := newHubTest(t, Config{
		Questions: 1, SecondsPerQuestion: 10,
		IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
	})
	peer3 := newFakePeer()
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)
	h.hub.JoinRoom(h.p2, code)
	waitFor(t, func() bool { return h.peer1.count(OutMatched) == 1 })

	// A third student holding the same (now spent) code gets a clean miss.
	p3 := &Player{UserID: "u3", Username: "Chidi"}
	h.hub.Attach(p3, peer3)
	h.hub.JoinRoom(p3, code)
	if got := errCode(peer3); got != ErrUnknownRoom {
		t.Fatalf("third join error = %q, want %q", got, ErrUnknownRoom)
	}
}

func TestHostDisconnectDestroysTheRoom(t *testing.T) {
	h := newHubTest(t, Config{BotWait: time.Hour})
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)

	h.peer1.Close() // presence cleanup must take the room with it
	waitFor(t, func() bool { return h.hub.Status().PrivateRooms == 0 })

	h.hub.JoinRoom(h.p2, code)
	if got := errCode(h.peer2); got != ErrUnknownRoom {
		t.Fatalf("error = %q, want %q", got, ErrUnknownRoom)
	}
}

func TestReplacedHostSessionKillsTheRoom(t *testing.T) {
	h := newHubTest(t, Config{BotWait: time.Hour})
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)

	// Same user signs in on a second device: the old session (and its
	// room) is replaced; the code must not keep working.
	p1b := &Player{UserID: "u1", Username: "Alice"}
	peer1b := newFakePeer()
	h.hub.Attach(p1b, peer1b)
	waitFor(t, func() bool { return h.hub.Status().PrivateRooms == 0 })

	h.hub.JoinRoom(h.p2, code)
	if got := errCode(h.peer2); got != ErrUnknownRoom {
		t.Fatalf("error = %q, want %q", got, ErrUnknownRoom)
	}
}

func TestHostCancelClosesTheRoomAndFreesTheSession(t *testing.T) {
	h := newHubTest(t, Config{BotWait: time.Hour})
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)

	h.hub.Cancel(h.p1)
	if got := h.peer1.count(OutCancelled); got != 1 {
		t.Fatalf("cancelled frames = %d, want 1", got)
	}
	if h.hub.Status().PrivateRooms != 0 {
		t.Fatalf("room survived cancel, privateRooms = %d", h.hub.Status().PrivateRooms)
	}

	h.hub.JoinRoom(h.p2, code)
	if got := errCode(h.peer2); got != ErrUnknownRoom {
		t.Fatalf("error = %q, want %q", got, ErrUnknownRoom)
	}

	// The freed host can open a fresh lobby, and it gets a fresh code.
	h.hub.Host(h.p1, "")
	if got := hostedCode(t, h.peer1); got == code {
		t.Fatal("re-host reused the old code")
	}
}

func TestHostingSessionsCannotQueueAndQueuedCannotJoin(t *testing.T) {
	h := newHubTest(t, Config{BotWait: time.Hour})
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)

	// Hosting pins the session: public queueing is refused, the room lives.
	h.hub.Queue(h.p1, "JAMB")
	if got := errCode(h.peer1); got != ErrAlreadyHost {
		t.Fatalf("queue-while-hosting error = %q, want %q", got, ErrAlreadyHost)
	}
	if h.hub.Status().PrivateRooms != 1 {
		t.Fatalf("room died on refused queue, privateRooms = %d", h.hub.Status().PrivateRooms)
	}

	// And a queued student cannot hop into a room either.
	h.hub.Queue(h.p2, "JAMB")
	h.hub.JoinRoom(h.p2, code)
	if got := errCode(h.peer2); got != ErrAlreadyQueued {
		t.Fatalf("join-while-queued error = %q, want %q", got, ErrAlreadyQueued)
	}
	if h.hub.Status().PrivateRooms != 1 {
		t.Fatalf("room died on refused join, privateRooms = %d", h.hub.Status().PrivateRooms)
	}
}

func TestJoinWhileInMatchIsRefused(t *testing.T) {
	h := newHubTest(t, Config{
		Questions: 2, SecondsPerQuestion: 10,
		IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
	})
	peer3 := newFakePeer()
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)
	h.hub.JoinRoom(h.p2, code)
	waitFor(t, func() bool { return h.peer2.count(OutMatched) == 1 })

	p3 := &Player{UserID: "u3", Username: "Chidi"}
	h.hub.Attach(p3, peer3)
	// Bola is mid-match: joining another room is refused...
	h.hub.JoinRoom(h.p2, "AAAAAA")
	if got := errCode(h.peer2); got != ErrInMatch {
		t.Fatalf("join-while-in-match error = %q, want %q", got, ErrInMatch)
	}
	// ...and so is hosting one.
	h.hub.Host(h.p2, "")
	if got := errCode(h.peer2); got != ErrInMatch {
		t.Fatalf("host-while-in-match error = %q, want %q", got, ErrInMatch)
	}
	_ = peer3
}

func TestRoomBodyFilterFlowsIntoTheMatch(t *testing.T) {
	h := newHubTest(t, Config{
		Questions: 1, SecondsPerQuestion: 10,
		IntroCountdown: time.Second, BotWait: time.Hour, BotSkill: 0.6,
	})
	h.hub.Host(h.p1, "WAEC")
	code := hostedCode(t, h.peer1)
	h.hub.JoinRoom(h.p2, code)
	waitFor(t, func() bool { return h.peer1.count(OutMatched) == 1 && h.peer2.count(OutMatched) == 1 })
	for _, p := range []*fakePeer{h.peer1, h.peer2} {
		if got := p.ofType(OutMatched)[0].Body; got != "WAEC" {
			t.Fatalf("matched body = %q, want WAEC", got)
		}
	}
}

func TestRoomExpiresAfterTTL(t *testing.T) {
	h := newHubTest(t, Config{
		Questions: 1, SecondsPerQuestion: 10, IntroCountdown: time.Second,
		BotWait: time.Hour, BotSkill: 0.6, RoomTTL: 15 * time.Minute,
	})
	h.hub.Host(h.p1, "")
	code := hostedCode(t, h.peer1)

	h.clock.Advance(16 * time.Minute)
	h.hub.JoinRoom(h.p2, code)
	if got := errCode(h.peer2); got != ErrUnknownRoom {
		t.Fatalf("error = %q, want %q", got, ErrUnknownRoom)
	}
	if h.hub.Status().PrivateRooms != 0 {
		t.Fatalf("expired room still counted, privateRooms = %d", h.hub.Status().PrivateRooms)
	}

	// A join before expiry still works, proving the clock rules the room.
	h.hub.Host(h.p1, "")
	code2 := hostedCode(t, h.peer1)
	h.clock.Advance(14 * time.Minute)
	h.hub.JoinRoom(h.p2, code2)
	waitFor(t, func() bool { return h.peer1.count(OutMatched) == 1 })
}

func TestHostWithUnknownBodyIsRefused(t *testing.T) {
	h := newHubTest(t, Config{BotWait: time.Hour})
	h.hub.Host(h.p1, "JAMB-PLUS")
	if got := errCode(h.peer1); got != ErrUnknownBody {
		t.Fatalf("error = %q, want %q", got, ErrUnknownBody)
	}
	if h.hub.Status().PrivateRooms != 0 {
		t.Fatal("room created despite unknown body")
	}
}
