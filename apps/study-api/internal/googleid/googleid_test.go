package googleid

import (
        "context"
        "crypto"
        "crypto/rand"
        "crypto/rsa"
        "crypto/sha256"
        "encoding/base64"
        "encoding/json"
        "math/big"
        "net/http"
        "net/http/httptest"
        "testing"
        "time"
)

// keymaterial is one test signing key + its JWKS JSON representation.
type keymaterial struct {
        priv   *rsa.PrivateKey
        kid    string
        jwkJSON string
}

func newKeyMaterial(t *testing.T, kid string) keymaterial {
        t.Helper()
        priv, err := rsa.GenerateKey(rand.Reader, 2048)
        if err != nil {
                t.Fatalf("gen key: %v", err)
        }
        b64 := func(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }
        doc := jwksDoc{Keys: []jwk{{
                Kid: kid,
                N:   b64(priv.N.Bytes()),
                E:   b64(big.NewInt(int64(priv.E)).Bytes()),
        }}}
        raw, err := json.Marshal(doc)
        if err != nil {
                t.Fatalf("marshal jwks: %v", err)
        }
        return keymaterial{priv: priv, kid: kid, jwkJSON: string(raw)}
}

func (k keymaterial) sign(t *testing.T, claims map[string]any) string {
        t.Helper()
        b64 := func(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }
        header, err := json.Marshal(map[string]string{"alg": "RS256", "typ": "JWT", "kid": k.kid})
        if err != nil {
                t.Fatalf("marshal header: %v", err)
        }
        payload, err := json.Marshal(claims)
        if err != nil {
                t.Fatalf("marshal payload: %v", err)
        }
        signing := b64(header) + "." + b64(payload)
        digest := sha256.Sum256([]byte(signing))
        sig, err := rsa.SignPKCS1v15(rand.Reader, k.priv, crypto.SHA256, digest[:])
        if err != nil {
                t.Fatalf("sign: %v", err)
        }
        return signing + "." + b64(sig)
}

func jwksServer(t *testing.T, docs ...string) *httptest.Server {
        t.Helper()
        calls := 0
        srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
                // Serve each document in order; the last one repeats forever.
                i := calls
                if i >= len(docs) {
                        i = len(docs) - 1
                }
                calls++
                w.Header().Set("Content-Type", "application/json")
                _, _ = w.Write([]byte(docs[i]))
            }))
        t.Cleanup(srv.Close)
        return srv
}

func idClaims(now time.Time, aud any) map[string]any {
        return map[string]any{
                "iss": "https://accounts.google.com",
                "sub": "1234567890",
                "aud": aud,
                "exp": now.Add(time.Hour).Unix(),
        }
}

func TestVerifyHappyPath(t *testing.T) {
        k := newKeyMaterial(t, "kid-1")
        srv := jwksServer(t, k.jwkJSON)
        v := NewWithJWKS([]string{"renance-client"}, srv.URL, srv.Client())

        claims, err := v.Verify(context.Background(), k.sign(t, idClaims(time.Now(), "renance-client")))
        if err != nil {
                t.Fatalf("verify: %v", err)
        }
        if claims.Subject != "1234567890" {
                t.Fatalf("sub = %q", claims.Subject)
        }
}

func TestVerifyWrongAudience(t *testing.T) {
        k := newKeyMaterial(t, "kid-1")
        srv := jwksServer(t, k.jwkJSON)
        v := NewWithJWKS([]string{"renance-client"}, srv.URL, srv.Client())

        _, err := v.Verify(context.Background(), k.sign(t, idClaims(time.Now(), "someone-else")))
        if err != ErrBadAudience {
                t.Fatalf("want ErrBadAudience, got %v", err)
        }
}

// Real deployments register TWO clients (web + Android); a token minted
// for either must be accepted, everything else rejected.
func TestVerifyMultiAudience(t *testing.T) {
        k := newKeyMaterial(t, "kid-1")
        srv := jwksServer(t, k.jwkJSON)
        v := NewWithJWKS([]string{"renance-web", " renance-android "}, srv.URL, srv.Client())

        for _, aud := range []string{"renance-web", "renance-android"} {
                if _, err := v.Verify(context.Background(), k.sign(t, idClaims(time.Now(), aud))); err != nil {
                        t.Fatalf("verify aud %q: %v", aud, err)
                }
        }
        if _, err := v.Verify(context.Background(), k.sign(t, idClaims(time.Now(), "renance-web,renance-android"))); err != ErrBadAudience {
                t.Fatalf("comma-joined aud must not pass, got %v", err)
        }
        if _, err := v.Verify(context.Background(), k.sign(t, idClaims(time.Now(), "someone-else"))); err != ErrBadAudience {
                t.Fatalf("want ErrBadAudience, got %v", err)
        }
}

func TestVerifyExpired(t *testing.T) {
        k := newKeyMaterial(t, "kid-1")
        srv := jwksServer(t, k.jwkJSON)
        v := NewWithJWKS([]string{"renance-client"}, srv.URL, srv.Client())

        stale := idClaims(time.Now(), "renance-client")
        stale["exp"] = time.Now().Add(-time.Minute).Unix()
        _, err := v.Verify(context.Background(), k.sign(t, stale))
        if err != ErrExpired {
                t.Fatalf("want ErrExpired, got %v", err)
        }
}

func TestVerifyBadSignature(t *testing.T) {
        attacker := newKeyMaterial(t, "kid-1")
        honest := newKeyMaterial(t, "kid-1")
        // Attacker forges a token for the SAME kid but their own key; the
        // JWKS serves the honest key, so the signature must be rejected.
        srv := jwksServer(t, honest.jwkJSON)
        v := NewWithJWKS([]string{"renance-client"}, srv.URL, srv.Client())

        _, err := v.Verify(context.Background(), attacker.sign(t, idClaims(time.Now(), "renance-client")))
        if err != ErrBadSig {
                t.Fatalf("want ErrBadSig, got %v", err)
        }
}

func TestVerifyKeyRotationTriggersRefresh(t *testing.T) {
        old := newKeyMaterial(t, "kid-old")
        next := newKeyMaterial(t, "kid-new")
        // First fetch: only the old key. Later fetches: both keys.
        both, err := json.Marshal(jwksDoc{Keys: []jwk{
                jwkFrom(old.priv, old.kid),
                jwkFrom(next.priv, next.kid),
        }})
        if err != nil {
                t.Fatalf("marshal: %v", err)
        }
        srv := jwksServer(t, old.jwkJSON, string(both))
        v := NewWithJWKS([]string{"renance-client"}, srv.URL, srv.Client())

        // Unknown kid → cache refresh → found in refreshed JWKS.
        if _, err := v.Verify(context.Background(), next.sign(t, idClaims(time.Now(), "renance-client"))); err != nil {
                t.Fatalf("verify after rotation: %v", err)
        }
}

func jwkFrom(priv *rsa.PrivateKey, kid string) jwk {
        b64 := func(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }
        return jwk{
                Kid: kid,
                N:   b64(priv.N.Bytes()),
                E:   b64(big.NewInt(int64(priv.E)).Bytes()),
        }
}

func TestVerifyIssuerLocked(t *testing.T) {
        k := newKeyMaterial(t, "kid-1")
        srv := jwksServer(t, k.jwkJSON)
        v := NewWithJWKS([]string{"renance-client"}, srv.URL, srv.Client())

        forged := idClaims(time.Now(), "renance-client")
        forged["iss"] = "https://evil.example/issuer"
        _, err := v.Verify(context.Background(), k.sign(t, forged))
        if err != ErrBadIssuer {
                t.Fatalf("want ErrBadIssuer, got %v", err)
        }
}
