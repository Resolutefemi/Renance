package arena

import (
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait  = 10 * time.Second
	pongWait   = 90 * time.Second
	pingPeriod = 30 * time.Second // must be < pongWait
	sendBuffer = 16
)

// SocketHandler serves one authenticated arena session over WebSocket.
// The HTTP layer performs JWT auth BEFORE calling Serve — browsers
// cannot set headers on a WebSocket, so the access token rides the
// ?token= query parameter and must never arrive here unverified.
type SocketHandler struct {
	Hub *Hub
	Log *slog.Logger
}

// Serve upgrades, attaches the player to the hub and pumps the socket
// until the client goes away. CheckOrigin is wide open ON PURPOSE: the
// handshake carries no cookies, only the caller-verified token, so a
// cross-site socket has nothing to ride and dies at auth.
func (sh *SocketHandler) Serve(p *Player, w http.ResponseWriter, r *http.Request) {
	up := websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(*http.Request) bool { return true },
	}
	conn, err := up.Upgrade(w, r, nil)
	if err != nil {
		sh.Log.Warn("arena: upgrade failed", "err", err)
		return
	}

	peer := newWSPeer(conn, sh.Log)
	sh.Hub.Attach(p, peer)
	defer sh.Hub.Detach(p)

	conn.SetReadLimit(4096)
	_ = conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	for {
		var in Inbound
		if err := conn.ReadJSON(&in); err != nil {
			return // read error or clean close; Detach runs presence cleanup
		}
		switch in.Type {
		case InQueue:
			sh.Hub.Queue(p, in.Body)
		case InCancel:
			sh.Hub.Cancel(p)
		case InAnswer:
			sh.Hub.Answer(p, in.Index, strings.ToUpper(strings.TrimSpace(in.Letter)))
		default:
			peer.Send(Outbound{Type: OutError, ErrCode: ErrBadMessage, ErrMsg: "unknown message type " + in.Type})
		}
	}
}

// WSPeer is the production Peer backed by a gorilla WebSocket: an
// outbound ring drained by a write pump, pings to keep NATs honest.
type WSPeer struct {
	conn *websocket.Conn
	send chan Outbound
	done chan struct{}
	once sync.Once
	log  *slog.Logger
}

func newWSPeer(conn *websocket.Conn, log *slog.Logger) *WSPeer {
	p := &WSPeer{
		conn: conn,
		send: make(chan Outbound, sendBuffer),
		done: make(chan struct{}),
		log:  log,
	}
	go p.writePump()
	return p
}

func (p *WSPeer) Send(o Outbound) {
	select {
	case p.send <- o:
	case <-p.done:
	default:
		// Backpressure: better to drop one frame than stall the hub.
		p.log.Warn("arena: outbound full, dropping frame", "type", o.Type)
	}
}

func (p *WSPeer) Close() {
	p.once.Do(func() {
		close(p.done)
	})
	_ = p.conn.Close()
}

func (p *WSPeer) Done() <-chan struct{} { return p.done }

func (p *WSPeer) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		_ = p.conn.Close()
	}()
	for {
		select {
		case o, ok := <-p.send:
			if !ok {
				return
			}
			_ = p.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := p.conn.WriteJSON(o); err != nil {
				return
			}
		case <-ticker.C:
			_ = p.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := p.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		case <-p.done:
			return
		}
	}
}
