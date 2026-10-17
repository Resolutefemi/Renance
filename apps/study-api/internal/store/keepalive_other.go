// Package store - keepalive_other.go
//
// Non-Unix fallback for the zombie-connection dialer: the platform's
// default keepalive cadence applies (see keepalive_unix.go for why
// the tuning exists). Production (Render) and CI are Linux, so this
// file exists only to keep the package buildable everywhere.
//
//go:build !unix

package store

import (
	"context"
	"net"
	"time"
)

// keepaliveDialer returns the DialFunc every store pool rides.
func keepaliveDialer() func(ctx context.Context, network, addr string) (net.Conn, error) {
	d := &net.Dialer{Timeout: 10 * time.Second, KeepAlive: 15 * time.Second}
	return d.DialContext
}
