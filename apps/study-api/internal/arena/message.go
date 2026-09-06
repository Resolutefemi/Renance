// Package arena is the multiplayer head-to-head quiz hub (ROADMAP #14),
// in-process slice: matchmaking queues, live matches and scoring live in
// this process's memory; only the match OUTCOME reaches the database
// (best-effort), so a slow DB can never break a live game.
//
// Doctrine mirrors the grading engine: pure rules are unit-tested with
// injected clocks and fake peers, zero network in the tests. The radio
// transport is WebSocket (gorilla), one hub per process — the Redis /
// multi-host presence layer is a later slice when scale asks for it.
package arena

// Inbound is one client → arena message (JSON on the socket).
type Inbound struct {
        Type   string `json:"type"`             // "queue" | "cancel" | "answer"
        Body   string `json:"body,omitempty"`   // queue: JAMB | WAEC | NECO | University Modules | "" = any
        Index  int    `json:"index,omitempty"`  // answer: 0-based question index
        Letter string `json:"letter,omitempty"` // answer: chosen option letter
}

// Outbound is one arena → client message (JSON on the socket).
type Outbound struct {
        Type string `json:"type"` // queued | cancelled | matched | question | result | over | error

        // matched / over
        MatchID   string         `json:"matchId,omitempty"`
        Winner    string         `json:"winner,omitempty"` // userID; "" = draw/aborted
        Scores    map[string]int `json:"scores,omitempty"`
        Opponent  string         `json:"opponent,omitempty"` // username (bot matches: "Renance Bot")
        Code      string         `json:"code,omitempty"`     // pack both players got
        Body      string         `json:"body,omitempty"`
        Questions int            `json:"questionCount,omitempty"`
        Seconds   int            `json:"secondsPerQuestion,omitempty"`

        // question
        Index    int    `json:"index,omitempty"`
        Deadline int64  `json:"deadline,omitempty"` // unix seconds, answer cutoff
        Question *QView `json:"question,omitempty"`

        // result
        Correct string          `json:"correctLetter,omitempty"`
        Solved  map[string]bool `json:"solved,omitempty"` // userID -> got it right

        // error
        ErrCode string `json:"errorCode,omitempty"`
        ErrMsg  string `json:"message,omitempty"`
}

// QView is the student-safe view of one match question: no answer key,
// ever — the same rule the bundle route enforces.
type QView struct {
        ID      string            `json:"id"`
        Stem    string            `json:"stem"`
        Options map[string]string `json:"options,omitempty"`
        Marks   int               `json:"marks"`
}

// Inbound message type constants.
const (
        InQueue  = "queue"
        InCancel = "cancel"
        InAnswer = "answer"
)

// Outbound message type constants.
const (
        OutQueued    = "queued"
        OutCancelled = "cancelled"
        OutMatched   = "matched"
        OutQuestion  = "question"
        OutResult    = "result"
        OutOver      = "over"
        OutError     = "error"
)

// Error codes carried on OutErrCode.
const (
        ErrAlreadyQueued = "already_queued"
        ErrInMatch       = "in_match"
        ErrNoPack        = "no_pack_available"
        ErrUnknownBody   = "unknown_body"
        ErrLate          = "late_answer"
        ErrReplaced      = "replaced"
        ErrShuttingDown  = "shutting_down"
        ErrBadMessage    = "bad_message"
)
