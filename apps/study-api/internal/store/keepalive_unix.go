// Package store - keepalive_unix.go
//
// The zombie-connection dialer (the courses-are-down hang, 2026-10-17).
//
// The catalog pool idles for long stretches between student traffic.
// Render's egress NAT silently drops idle TCP mappings and Supavisor
// restarts strand sessions WITHOUT an RST reaching us, so the pool's
// "idle" connections become zombies: the socket looks open, the next
// query written into it hangs in TCP retransmit for ~15 minutes.
// That was the outage - /learn/catalog and /learn/faculties answered
// nothing, /readyz reported "content: context deadline exceeded",
// while the database itself answered a fresh connection in ~1s.
//
// Go's default keepalive cadence (idle 15s but interval 75s, count 9)
// takes ~11 minutes to bury a corpse. This dialer tightens the probe
// to idle 15s, interval 5s, count 3 - a dead socket is detected in
// about half a minute, pgxpool discards it, the next request dials a
// fresh connection (which always worked).
//
//go:build unix

package store

import (
	"context"
	"net"
	"syscall"
	"time"
)

// keepaliveDialer returns the DialFunc every store pool rides: a
// 10s connect timeout plus aggressively tuned TCP keepalives.
func keepaliveDialer() func(ctx context.Context, network, addr string) (net.Conn, error) {
	d := &net.Dialer{Timeout: 10 * time.Second, KeepAlive: 15 * time.Second}
	d.Control = func(network, address string, c syscall.RawConn) error {
		switch network {
		case "tcp4", "tcp6":
		default:
			return nil
		}
		var ctlErr error
		c.Control(func(fd uintptr) {
			for _, err := range []error{
				syscall.SetsockoptInt(int(fd), syscall.IPPROTO_TCP, syscall.TCP_KEEPINTVL, 5),
				syscall.SetsockoptInt(int(fd), syscall.IPPROTO_TCP, syscall.TCP_KEEPCNT, 3),
			} {
				if err != nil && ctlErr == nil {
					ctlErr = err
				}
			}
		})
		return ctlErr
	}
	return d.DialContext
}
