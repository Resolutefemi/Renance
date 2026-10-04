package httpapi

import (
        "net/http"
        "strings"
)

// Google Identity Services sign-in: web and Android clients obtain a Google
// ID token and POST it here, receiving a first-class Renance JWT in return ,
// one session shape for every client. The Google client SECRET is never
// needed anywhere in Renance; this endpoint verifies public-client tokens
// against Google's JWKS.
type googleAuthRequest struct {
        Credential string `json:"credential"`
        // DeviceID rides the mobile app's Google sign-in so the one-account-
        // per-device lock covers the Google flow too (the web never sends it
        // and the bind is skipped).
        DeviceID string `json:"deviceId,omitempty"`
}

func (s *Server) handleGoogleAuth(w http.ResponseWriter, r *http.Request) {
        if s.google == nil {
                fail(w, http.StatusServiceUnavailable, "google_disabled",
                        "Google sign-in is not configured on this deployment")
                return
        }
        var req googleAuthRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        claims, err := s.google.Verify(r.Context(), req.Credential)
        if err != nil {
                fail(w, http.StatusUnauthorized, "google_invalid",
                        "could not verify the Google sign-in, try again")
                return
        }

        u, err := s.store.UpsertGoogleUser(r.Context(), claims.Subject, claims.Email,
                deriveUsername(claims.Email, claims.Subject))
        if err != nil {
                s.log.Error("google user upsert failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not sign in")
                return
        }

        // Device lock, same rule as the credential flow (one device, one
        // account): a Google login from a second device is refused until
        // management moves the account.
        if err := s.bindDevice(r.Context(), u.ID, req.DeviceID); err != nil {
                s.failDevice(w, err)
                return
        }

        // Google proves the address on its side, so the account lands
        // pre-verified: the row is stamped confirmed (healing legacy rows
        // that predate the stamp) and the session skips the unverified gate.
        if err := s.store.MarkEmailVerified(r.Context(), u.ID); err != nil {
                s.log.Error("google email-verified stamp failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not sign in")
                return
        }

        profile, err := s.store.ProfileByUser(r.Context(), u.ID)
        if err != nil {
                s.log.Error("profile lookup failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not sign in")
                return
        }
        s.finishAuth(w, http.StatusOK, u, profile != nil && profile.Completed)
}

// deriveUsername mints a username-shaped seed from the Google profile:
// the email local-part when usable, otherwise "student" + sub tail.
// Collisions are resolved by UpsertGoogleUser with numbered suffixes.
func deriveUsername(email, sub string) string {
        seed := ""
        if email != "" {
                seed = strings.ToLower(strings.SplitN(email, "@", 2)[0])
        }
        var b strings.Builder
        for _, r := range seed {
                switch {
                case r >= 'a' && r <= 'z', r >= '0' && r <= '9', r == '_':
                        b.WriteRune(r)
                }
        }
        seed = strings.Trim(b.String(), "_")
        if len(seed) > 20 {
                seed = strings.TrimRight(seed[:20], "_")
        }
        if len(seed) < 3 {
                tail := sub
                if len(tail) > 6 {
                        tail = tail[len(tail)-6:]
                }
                seed = "student" + tail
        }
        return seed
}
