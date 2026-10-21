// Package jwtx is a dependency-free HS256 JWT implementation.
//
// ERA-1 doctrine carried over: 12h tokens, HS256 only. Hand-rolled because
// the claims set is tiny and stable; crypto/hmac + sha256 are stdlib, which
// keeps the Go service dependency-light.
package jwtx

import (
        "crypto/hmac"
        "crypto/sha256"
        "encoding/base64"
        "encoding/json"
        "errors"
        "fmt"
        "strings"
        "time"
)

const TokenTTL = 12 * time.Hour

var (
        ErrMalformed = errors.New("jwtx: malformed token")
        ErrBadSig    = errors.New("jwtx: bad signature")
        ErrExpired   = errors.New("jwtx: token expired")
)

type Claims struct {
        UserID   string `json:"sub"`
        Username string `json:"username"`
        IssuedAt int64  `json:"iat"`
        Expires  int64  `json:"exp"`
        // Unverified marks a session minted while the signup email was still
        // unconfirmed (email accounts only). The claim rides the token so the
        // API can close the study surface without a database round-trip per
        // request: absent - legacy tokens, username accounts, Google signins
        // and confirmed students - always means fully seated.
        Unverified bool `json:"unv,omitempty"`
}

func b64(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

func sign(payload []byte, secret []byte) string {
        mac := hmac.New(sha256.New, secret)
        mac.Write(payload)
        return b64(mac.Sum(nil))
}

// Issue mints a 12h HS256 token for a fully seated student.
func Issue(userID, username, secret string) (string, error) {
        return issue(userID, username, secret, false)
}

// IssueUnverified mints the same 12h token carrying the unv claim: the
// signup email is not confirmed yet, so the study surface stays closed
// (the confirmation endpoints aside) until the mailed link is consumed
// and a fresh, verified token is issued.
func IssueUnverified(userID, username, secret string) (string, error) {
        return issue(userID, username, secret, true)
}

func issue(userID, username, secret string, unverified bool) (string, error) {
        now := time.Now()
        c := Claims{
                UserID:     userID,
                Username:   username,
                IssuedAt:   now.Unix(),
                Expires:    now.Add(TokenTTL).Unix(),
                Unverified: unverified,
        }
        header := b64([]byte(`{"alg":"HS256","typ":"JWT"}`))
        payload, err := json.Marshal(c)
        if err != nil {
                return "", fmt.Errorf("jwtx: marshal claims: %w", err)
        }
        signing := header + "." + b64(payload)
        return signing + "." + sign([]byte(signing), []byte(secret)), nil
}

// Verify parses, signature-checks and expiry-checks a token.
func Verify(token, secret string) (*Claims, error) {
        parts := strings.Split(token, ".")
        if len(parts) != 3 || parts[0] == "" || parts[1] == "" {
                return nil, ErrMalformed
        }
        signing := parts[0] + "." + parts[1]
        if !hmac.Equal([]byte(sign([]byte(signing), []byte(secret))), []byte(parts[2])) {
                return nil, ErrBadSig
        }
        raw, err := base64.RawURLEncoding.DecodeString(parts[1])
        if err != nil {
                return nil, ErrMalformed
        }
        var c Claims
        if err := json.Unmarshal(raw, &c); err != nil {
                return nil, ErrMalformed
        }
        if c.Expires <= time.Now().Unix() {
                return nil, ErrExpired
        }
        if c.UserID == "" {
                return nil, ErrMalformed
        }
        return &c, nil
}
