// Package googleid verifies Google-issued ID tokens (RS256 JWS) against
// Google's published JWKS. Dependency-free by doctrine, like jwtx:
// crypto/rsa + sha256 + base64 are stdlib, the claim set is tiny and stable.
//
// Flow: the web/Android client runs Google Identity Services, gets an ID
// token, and posts it to POST /auth/google. We verify the token here so the
// Google client SECRET never needs to exist anywhere in Renance.
package googleid

import (
        "context"
        "crypto"
        "crypto/rsa"
        "crypto/sha256"
        "crypto/x509"
        "encoding/base64"
        "encoding/json"
        "errors"
        "fmt"
        "io"
        "math/big"
        "net/http"
        "strings"
        "sync"
        "time"
)

const (
        googleJWKS = "https://www.googleapis.com/oauth2/v3/certs"
        cacheTTL   = 12 * time.Hour
)

var (
        ErrMalformed    = errors.New("googleid: malformed token")
        ErrBadAlg       = errors.New("googleid: only RS256 accepted")
        ErrBadSig       = errors.New("googleid: bad signature")
        ErrExpired      = errors.New("googleid: token expired")
        ErrBadAudience  = errors.New("googleid: wrong audience")
        ErrBadIssuer    = errors.New("googleid: wrong issuer")
        ErrUnknownKey   = errors.New("googleid: unknown signing key")
        ErrJWKSUnusable = errors.New("googleid: JWKS unusable")
)

// Claims carries the subset of Google ID-token claims Renance uses.
type Claims struct {
        Issuer  string `json:"iss"`
        Subject string `json:"sub"`
        Email   string `json:"email"`
        Name    string `json:"name"`
        Expires int64  `json:"exp"`

        audience []string
}

func (c *Claims) Audiences() []string { return c.audience }

type jwk struct {
        Kid string `json:"kid"`
        N   string `json:"n"`
        E   string `json:"e"`
}

type jwksDoc struct {
        Keys []jwk `json:"keys"`
}

// Verifier caches Google's signing keys and checks tokens for one audience.
type Verifier struct {
        clientID string
        jwks     string
        client   *http.Client

        mu        sync.Mutex
        keys      map[string]*rsa.PublicKey
        fetchedAt time.Time
}

// New builds a Verifier against Google's production JWKS.
func New(clientID string) *Verifier {
        return NewWithJWKS(clientID, googleJWKS, http.DefaultClient)
}

// NewWithJWKS exists for tests (httptest JWKS) and future region pinning.
func NewWithJWKS(clientID, jwksURL string, client *http.Client) *Verifier {
        if client == nil {
                client = http.DefaultClient
        }
        return &Verifier{clientID: clientID, jwks: jwksURL, client: client}
}

// Verify signature-checks token against a cached (kid → key) table —
// refreshing once on an unknown kid so Google key rotations never lock
// sign-ins — then validates expiry, audience and issuer.
func (v *Verifier) Verify(ctx context.Context, token string) (*Claims, error) {
        parts := strings.Split(token, ".")
        if len(parts) != 3 || parts[0] == "" || parts[1] == "" || parts[2] == "" {
                return nil, ErrMalformed
        }
        var header struct {
                Alg string `json:"alg"`
                Kid string `json:"kid"`
        }
        headerRaw, err := base64.RawURLEncoding.DecodeString(parts[0])
        if err != nil || json.Unmarshal(headerRaw, &header) != nil {
                return nil, ErrMalformed
        }
        if !strings.EqualFold(header.Alg, "RS256") || header.Kid == "" {
                return nil, ErrBadAlg
        }

        key, err := v.key(ctx, header.Kid)
        if err != nil {
                return nil, err
        }

        sig, err := b64(parts[2])
        if err != nil {
                return nil, ErrMalformed
        }
        digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
        if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], sig); err != nil {
                return nil, ErrBadSig
        }

        payloadRaw, err := b64(parts[1])
        if err != nil {
                return nil, ErrMalformed
        }
        var wire struct {
                Claims
                Audience any `json:"aud"`
        }
        if err := json.Unmarshal(payloadRaw, &wire); err != nil {
                return nil, ErrMalformed
        }
        c := wire.Claims
        switch aud := wire.Audience.(type) {
        case string:
                c.audience = []string{aud}
        case []any:
                for _, a := range aud {
                        if s, ok := a.(string); ok {
                                c.audience = append(c.audience, s)
                        }
                }
        }
        if c.Expires <= time.Now().Unix() {
                return nil, ErrExpired
        }
        if c.Subject == "" {
                return nil, ErrMalformed
        }
        found := false
        for _, a := range c.audience {
                if a == v.clientID {
                        found = true
                        break
                }
        }
        if !found {
                return nil, ErrBadAudience
        }
        if c.Issuer != "accounts.google.com" && c.Issuer != "https://accounts.google.com" {
                return nil, ErrBadIssuer
        }
        return &c, nil
}

// key returns the cached public key for kid. On a miss it pulls a fresh
// JWKS — and pulls ONCE MORE if the kid is still unknown, so a mid-rotation
// race (new token, JWKS endpoint still serving the old key set) can never
// 401 a legitimate sign-in.
func (v *Verifier) key(ctx context.Context, kid string) (*rsa.PublicKey, error) {
        v.mu.Lock()
        keys, stale := v.keys, time.Since(v.fetchedAt) > cacheTTL
        v.mu.Unlock()

        if k, ok := keys[kid]; ok && !stale {
                return k, nil
        }
        fresh, err := v.fetch(ctx)
        if err != nil {
                // Fall back to a key we already trust rather than hard-failing
                // when Google's JWKS endpoint blips.
                if k, ok := keys[kid]; ok {
                        return k, nil
                }
                return nil, err
        }
        if k, ok := v.swap(fresh)[kid]; ok {
                return k, nil
        }
        // Still unknown right after a refresh — one retry, then give up.
        fresh, err = v.fetch(ctx)
        if err != nil {
                return nil, err
        }
        if k, ok := v.swap(fresh)[kid]; ok {
                return k, nil
        }
        return nil, ErrUnknownKey
}

func (v *Verifier) swap(keys map[string]*rsa.PublicKey) map[string]*rsa.PublicKey {
        v.mu.Lock()
        v.keys, v.fetchedAt = keys, time.Now()
        v.mu.Unlock()
        return keys
}

func (v *Verifier) fetch(ctx context.Context) (map[string]*rsa.PublicKey, error) {
        req, err := http.NewRequestWithContext(ctx, http.MethodGet, v.jwks, nil)
        if err != nil {
                return nil, fmt.Errorf("%w: %v", ErrJWKSUnusable, err)
        }
        res, err := v.client.Do(req)
        if err != nil {
                return nil, fmt.Errorf("%w: %v", ErrJWKSUnusable, err)
        }
        defer res.Body.Close()
        if res.StatusCode != http.StatusOK {
                return nil, fmt.Errorf("%w: status %d", ErrJWKSUnusable, res.StatusCode)
        }
        raw, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
        if err != nil {
                return nil, fmt.Errorf("%w: %v", ErrJWKSUnusable, err)
        }
        var doc jwksDoc
        if err := json.Unmarshal(raw, &doc); err != nil {
                return nil, fmt.Errorf("%w: %v", ErrJWKSUnusable, err)
        }
        out := make(map[string]*rsa.PublicKey, len(doc.Keys))
        for _, k := range doc.Keys {
                n, err := b64(k.N)
                if err != nil {
                        continue
                }
                e, err := b64(k.E)
                if err != nil {
                        continue
                }
                pub := &rsa.PublicKey{
                        N: new(big.Int).SetBytes(n),
                        E: int(new(big.Int).SetBytes(e).Int64()),
                }
                if _, err := x509.MarshalPKIXPublicKey(pub); err != nil {
                        continue // sanity: refuse degenerate keys
                }
                out[k.Kid] = pub
        }
        if len(out) == 0 {
                return nil, ErrJWKSUnusable
        }
        return out, nil
}

// b64 decodes unpadded OR padded base64url (Google emits both flavours).
func b64(s string) ([]byte, error) {
        if raw, err := base64.RawURLEncoding.DecodeString(s); err == nil {
                return raw, nil
        }
        return base64.URLEncoding.DecodeString(s)
}
