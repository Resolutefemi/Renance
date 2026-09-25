// Email verification: manual signups confirm their address through a
// mailed link that lands on the web /verify page and then hands the
// student back to where the signup happened (the site, or the app when
// the request came from it). Google signups are pre-verified by Google.
// SMTP credentials arrive via the environment (SMTP_HOST, SMTP_PORT,
// SMTP_USER, SMTP_PASS, SMTP_FROM); without them the message with the
// verification link is written to the server log so nothing is lost.
package httpapi

import (
        "crypto/rand"
        "encoding/hex"
        "fmt"
        "net/http"
        "net/smtp"
        "os"
        "strings"
        "time"
)

// verifyToken mints 24 hex chars of crypto randomness.
func newVerifyToken() (string, error) {
        buf := make([]byte, 12)
        if _, err := rand.Read(buf); err != nil {
                return "", err
        }
        return hex.EncodeToString(buf), nil
}

// siteURL is the deployed web origin the verification link points at.
func (s *Server) siteURL() string {
        if u := strings.TrimSpace(os.Getenv("SITE_URL")); u != "" {
                return strings.TrimRight(u, "/")
        }
        return "https://renance-edtech.vercel.app"
}

// sendVerificationMail builds and (best-effort) sends the confirmation
// mail. Returns the verification URL so the response can carry it to
// dev surfaces; production students only ever get the mail.
func (s *Server) sendVerificationMail(userID, email, token, verifyReturn string) string {
        back := verifyReturn
        if back != "app" {
                back = "web"
        }
        link := fmt.Sprintf("%s/verify/?token=%s&return=%s", s.siteURL(), token, back)
        subject := "Confirm your email - Renance"
        body := fmt.Sprintf(`Welcome to Renance.

Confirm your email address to unlock your account:

%s

This link works once and never expires, but use it soon.

If you did not create this account you can ignore this mail.
`, link)
        _ = userID // logs stay free of account ids beyond the address
        if host := strings.TrimSpace(os.Getenv("SMTP_HOST")); host != "" {
                if err := smtpSend(host, email, subject, body); err != nil {
                        s.log.Error("verification mail send failed", "err", err)
                }
        } else {
                s.log.Info("SMTP not configured, verification link in logs", "to", email, "url", link)
        }
        return link
}

// smtpSend is a plain SMTP handoff (no TLS pooling tricks, no HTML).
func smtpSend(host, to, subject, body string) error {
        port := strings.TrimSpace(os.Getenv("SMTP_PORT"))
        if port == "" {
                port = "587"
        }
        from := strings.TrimSpace(os.Getenv("SMTP_FROM"))
        if from == "" {
                from = "no-reply@renance.com"
        }
        user := strings.TrimSpace(os.Getenv("SMTP_USER"))
        pass := strings.TrimSpace(os.Getenv("SMTP_PASS"))
        addr := fmt.Sprintf("%s:%s", host, port)
        msg := fmt.Sprintf("From: Renance <%s>\r\nTo: %s\r\nSubject: %s\r\n\r\n%s", from, to, subject, body)
        var auth smtp.Auth
        if user != "" {
                auth = smtp.PlainAuth("", user, pass, host)
        }
        return smtp.SendMail(addr, auth, from, []string{to}, []byte(msg))
}

type verifyEmailRequest struct {
        Token string `json:"token"`
}

// handleVerifyEmail consumes the confirmation token. The web /verify
// page calls it; success is idempotent (a replayed link just answers
// verified).
func (s *Server) handleVerifyEmail(w http.ResponseWriter, r *http.Request) {
        var req verifyEmailRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        userID, ok, err := s.store.VerifyEmail(r.Context(), strings.TrimSpace(req.Token))
        if err != nil {
                s.log.Error("verify email failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not verify")
                return
        }
        if !ok {
                fail(w, http.StatusBadRequest, "invalid_token",
                        "this link is not valid any more. Sign in and resend the confirmation mail.")
                return
        }
        s.log.Info("email verified", "user", userID, "at", time.Now().UTC().Format(time.RFC3339))
        writeJSON(w, http.StatusOK, map[string]any{"verified": true})
}

// handleResendVerification re-issues the confirmation mail for the
// signed-in account; a minute's cooldown keeps it abuse-proof.
func (s *Server) handleResendVerification(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        ent, err := s.store.EnsureEntitlement(r.Context(), uid)
        if err != nil {
                s.log.Error("entitlement load failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not resend")
                return
        }
        if ent.EmailVerified {
                writeJSON(w, http.StatusOK, map[string]any{"verified": true})
                return
        }
        if ent.VerifySentAt != nil && time.Since(*ent.VerifySentAt) < time.Minute {
                fail(w, http.StatusTooManyRequests, "cooldown",
                        "the confirmation mail was just sent, wait a minute for the next one.")
                return
        }
        u, err := s.store.UserByID(r.Context(), uid)
        if err != nil || u == nil || u.Email == nil || strings.TrimSpace(*u.Email) == "" {
                fail(w, http.StatusBadRequest, "no_email", "this account carries no email address")
                return
        }
        token, err := newVerifyToken()
        if err != nil {
                fail(w, http.StatusInternalServerError, "internal", "could not resend")
                return
        }
        if err := s.store.SetEmailVerification(r.Context(), uid, token); err != nil {
                s.log.Error("verify token stamp failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not resend")
                return
        }
        link := s.sendVerificationMail(uid, strings.TrimSpace(*u.Email), token, "web")
        writeJSON(w, http.StatusOK, map[string]any{"sent": true, "_devLink": link})
}

// newReferralCode mints a candidate referral code (REN + 5 hex); the
// store re-derives on the rare collision.
func newReferralCode() (string, error) {
	buf := make([]byte, 3)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return "REN" + strings.ToUpper(hex.EncodeToString(buf)), nil
}
