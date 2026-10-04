package httpapi

import (
        "crypto/subtle"
        "encoding/json"
        "net/http"
        "strings"
)

// Management rescue for the one-account-per-device lock. A student who
// lost their phone (or bought a new one) cannot sign in on the new
// device - the login refuses with device_locked and points them at
// management's WhatsApp. Management verifies the student, then calls
// POST /internal/device/unbind {user|userId} with the X-Admin-Token
// header (the same ADMIN_TOKEN that guards /internal/review/tick) and
// the next login on the new device seats cleanly.
//
// Founder directive (2026-10-02): this rescue works ONLY for the
// lost/replaced-phone case - someone on a NEW device tried to sign in
// with an account still bound to their OLD device. It is NOT for
// device_taken refusals (a second account trying to claim a device that
// already owns one): that student just signs in with the account the
// device owns, no management involvement.
//
// The unbind itself stays available while the DEVICE_LOCK switch is off:
// bindings recorded by earlier builds can be cleared ahead of the flip.
//
// Example:
//
//      curl -X POST https://renance-api.onrender.com/internal/device/unbind \
//        -H "X-Admin-Token: $ADMIN_TOKEN" \
//        -H "Content-Type: application/json" \
//        -d '{"user":"student@email.com"}'
type unbindRequest struct {
        // User accepts a username OR an email (the DM rarely carries the id).
        User   string `json:"user,omitempty"`
        UserID string `json:"userId,omitempty"`
}

func (s *Server) handleDeviceUnbind(w http.ResponseWriter, r *http.Request) {
        if s.cfg.AdminToken == "" {
                fail(w, http.StatusNotFound, "not_found", "unknown route")
                return
        }
        got := r.Header.Get("X-Admin-Token")
        if subtle.ConstantTimeCompare([]byte(got), []byte(s.cfg.AdminToken)) != 1 {
                fail(w, http.StatusUnauthorized, "unauthorized", "bad admin token")
                return
        }
        var req unbindRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        // Resolve the account: explicit id first, then username-or-email.
        userID := strings.TrimSpace(req.UserID)
        identifier := strings.TrimSpace(req.User)
        if userID == "" && identifier == "" {
                fail(w, http.StatusBadRequest, "bad_request", "pass user (username or email) or userId")
                return
        }
        if userID == "" {
                u, err := s.store.UserByUsername(r.Context(), identifier)
                if err != nil {
                        s.log.Error("unbind user lookup failed", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not look up that account")
                        return
                }
                if u == nil {
                        u, err = s.store.UserByEmail(r.Context(), identifier)
                        if err != nil {
                                s.log.Error("unbind email lookup failed", "err", err)
                                fail(w, http.StatusInternalServerError, "internal", "could not look up that account")
                                return
                        }
                }
                if u == nil {
                        fail(w, http.StatusNotFound, "user_not_found", "no account matches that username or email")
                        return
                }
                userID = u.ID
        }
        cleared, err := s.store.UnbindDevice(r.Context(), userID)
        if err != nil {
                s.log.Error("unbind failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not unbind the device")
                return
        }
        s.log.Info("device unbound", "userId", userID, "cleared", cleared)
        w.Header().Set("Content-Type", "application/json; charset=utf-8")
        w.WriteHeader(http.StatusOK)
        _ = json.NewEncoder(w).Encode(map[string]any{
                "ok":      true,
                "userId":  userID,
                "cleared": cleared,
        })
}
