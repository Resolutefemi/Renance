package jwtx

import (
	"crypto/hmac"
	"crypto/sha256"
	"strings"
	"testing"
	"time"
)

const secret = "unit-test-secret-0123456789"

func TestRoundTrip(t *testing.T) {
	tok, err := Issue("u-123", "adaobi", secret)
	if err != nil {
		t.Fatalf("issue: %v", err)
	}
	got, err := Verify(tok, secret)
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if got.UserID != "u-123" || got.Username != "adaobi" {
		t.Fatalf("claims mismatch: %+v", got)
	}
	if got.Expires-got.IssuedAt != int64(TokenTTL/time.Second) {
		t.Fatalf("TTL not 12h: %d", got.Expires-got.IssuedAt)
	}
}

func TestWrongSecret(t *testing.T) {
	tok, _ := Issue("u-1", "adaobi", secret)
	if _, err := Verify(tok, "another-secret-0123456789"); err != ErrBadSig {
		t.Fatalf("want ErrBadSig, got %v", err)
	}
}

func TestExpired(t *testing.T) {
	head := b64([]byte(`{"alg":"HS256","typ":"JWT"}`))
	tampered := forge(head, `{"sub":"u-1","username":"adaobi","iat":1,"exp":2}`, secret)
	if _, err := Verify(tampered, secret); err != ErrExpired {
		t.Fatalf("want ErrExpired, got %v", err)
	}
}

func TestTamperedPayload(t *testing.T) {
	tok, _ := Issue("u-1", "adaobi", secret)
	parts := strings.Split(tok, ".")
	parts[1] = b64([]byte(`{"sub":"attacker","username":"x","iat":1,"exp":9999999999}`))
	if _, err := Verify(strings.Join(parts, "."), secret); err != ErrBadSig {
		t.Fatalf("want ErrBadSig, got %v", err)
	}
}

func TestMalformed(t *testing.T) {
	for _, bad := range []string{"", "a.b", "a.b.c.d", ".."} {
		if _, err := Verify(bad, secret); err != ErrMalformed {
			t.Fatalf("token %q: want ErrMalformed, got %v", bad, err)
		}
	}
}

// forge builds a properly-signed token with arbitrary claims.
func forge(header, payload, secret string) string {
	signing := header + "." + b64([]byte(payload))
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signing))
	return signing + "." + b64(mac.Sum(nil))
}
