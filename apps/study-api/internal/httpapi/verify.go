// Email confirmation: manual signups get a mailed link that lands on
// the web /verify page (or the app's verify screen) and hands the
// student back to where the signup happened. SIGNUP-ONLY by doctrine:
// logging in never asks about confirmation - the desk opens straight
// away. Google signups are pre-verified by Google. Transport: the Brevo
// HTTPS API first (BREVO_API_KEY) - it is not subject to the relay's IP
// filter and delivered a live test in seconds; the Brevo SMTP relay
// (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM) rides as the
// fallback when no API key is set or the API call fails. With neither
// configured the link is written to the server log so nothing is lost.
package httpapi

import (
        "bytes"
        "crypto/rand"
        "crypto/tls"
        "encoding/hex"
        "encoding/json"
        "errors"
        "fmt"
        "io"
        "net"
        "net/http"
        "net/smtp"
        "os"
        "strings"
        "time"

        "renance.dev/study-api/internal/store"
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

// mailFrom picks the envelope sender: SMTP_FROM first, then the SMTP
// login (Brevo pre-verifies the account owner's identity), then a last
// resort that still reads sensibly in a mail client.
func mailFrom() string {
        if f := strings.TrimSpace(os.Getenv("SMTP_FROM")); f != "" {
                return f
        }
        if f := strings.TrimSpace(os.Getenv("SMTP_USER")); f != "" {
                return f
        }
        return "no-reply@renance.com"
}

// sendVerificationMail builds and (best-effort) sends the confirmation
// mail. Returns the verification URL (so dev surfaces can carry it) and
// whether the mail actually left the building - the response to the
// client reports that honestly instead of pretending.
func (s *Server) sendVerificationMail(userID, email, token, verifyReturn string) (string, bool) {
        back := verifyReturn
        if back != "app" {
                back = "web"
        }
        link := fmt.Sprintf("%s/verify/?token=%s&return=%s", s.siteURL(), token, back)
        subject := "Confirm your email - Renance"
        body := fmt.Sprintf(`Welcome to Renance.

Confirm your email address:

%s

This link works once and never expires, but use it soon. You can
keep studying right away - confirming just completes the signup.

If you did not create this account you can ignore this mail.
`, link)
        _ = userID // logs stay free of account ids beyond the address
        sent := false
        // HTTPS API first: no IP filter to trip over, proven to deliver
        // in seconds. The relay stays as fallback (and remains the only
        // transport when no API key is configured).
        if key := strings.TrimSpace(os.Getenv("BREVO_API_KEY")); key != "" {
                if err := brevoAPISend(key, email, subject, body); err != nil {
                        s.log.Error("confirmation mail via Brevo HTTPS API failed (falling back to the SMTP relay)", "err", err)
                } else {
                        sent = true
                }
        }
        if !sent {
                if host := strings.TrimSpace(os.Getenv("SMTP_HOST")); host != "" {
                        if err := smtpSend(host, email, subject, body); err != nil {
                                s.log.Error("confirmation mail via SMTP relay failed (check SMTP_USER/SMTP_PASS, the Brevo authorized-IP list, and that SMTP_FROM is a verified sender)", "err", err)
                        } else {
                                sent = true
                        }
                }
        }
        if !sent {
                if host := strings.TrimSpace(os.Getenv("SMTP_HOST")); host == "" && strings.TrimSpace(os.Getenv("BREVO_API_KEY")) == "" {
                        s.log.Warn("no mail transport configured: set SMTP_HOST/SMTP_PASS (relay) or BREVO_API_KEY (Brevo dashboard -> SMTP & API -> API keys) on the Render service; the confirmation link is only in this log", "to", email, "url", link)
                } else {
                        s.log.Warn("confirmation mail did NOT go out: the relay refused the connecting IP (Brevo answers 525 5.7.1 Unauthorized IP) and no BREVO_API_KEY fallback is set. Paste the Brevo API key (xkeysib-...) as BREVO_API_KEY on Render - the HTTPS API ignores the relay's IP filter - or clear the IP restriction under Brevo -> Profile -> SMTP & API security", "to", email, "url", link)
                }
        }
        return link, sent
}

// brevoAPISend hands the mail to Brevo's HTTPS API instead of the SMTP
// relay. The relay filters connecting IPs (525 5.7.1) - the API does
// not - so a single BREVO_API_KEY paste rescues delivery from any
// host, Render included.
func brevoAPISend(key, to, subject, body string) error {
        payload := map[string]any{
                "sender":      map[string]string{"name": "Renance", "email": mailFrom()},
                "to":          []map[string]string{{"email": to}},
                "subject":     subject,
                "textContent": body,
        }
        buf, err := json.Marshal(payload)
        if err != nil {
                return err
        }
        req, err := http.NewRequest(http.MethodPost, "https://api.brevo.com/v3/smtp/email", bytes.NewReader(buf))
        if err != nil {
                return err
        }
        req.Header.Set("api-key", key)
        req.Header.Set("content-type", "application/json")
        req.Header.Set("accept", "application/json")
        client := &http.Client{Timeout: 30 * time.Second}
        res, err := client.Do(req)
        if err != nil {
                return err
        }
        defer res.Body.Close()
        data, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
        if res.StatusCode >= 300 {
                return fmt.Errorf("brevo api status %d: %s", res.StatusCode, strings.TrimSpace(string(data)))
        }
        return nil
}

// smtpSend is a plain SMTP handoff (no TLS pooling tricks, no HTML).
// Port 587 (STARTTLS) upgrades in band; port 465 (implicit TLS) dials
// TLS first. Both paths dial with a hard 15s timeout and a 60s command
// deadline so a hung relay can never stall a signup response.
func smtpSend(host, to, subject, body string) error {
        port := strings.TrimSpace(os.Getenv("SMTP_PORT"))
        if port == "" {
                port = "587"
        }
        from := mailFrom()
        user := strings.TrimSpace(os.Getenv("SMTP_USER"))
        pass := strings.TrimSpace(os.Getenv("SMTP_PASS"))
        // JoinHostPort keeps literal-IPv6 hosts legal ("[::1]:587");
        // a bare Sprintf("%s:%s") broke go vet (CI, Go 1.24+ vet).
        addr := net.JoinHostPort(host, port)
        msg := fmt.Sprintf("From: Renance <%s>\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s", from, to, subject, body)
        var auth smtp.Auth
        if user != "" {
                auth = smtp.PlainAuth("", user, pass, host)
        }
        dialer := &net.Dialer{Timeout: 15 * time.Second}
        var conn net.Conn
        var derr error
        if port == "465" {
                conn, derr = tls.DialWithDialer(dialer, "tcp", addr, &tls.Config{ServerName: host})
        } else {
                conn, derr = dialer.Dial("tcp", addr)
        }
        if derr != nil {
                return derr
        }
        defer conn.Close()
        _ = conn.SetDeadline(time.Now().Add(60 * time.Second))
        c, err := smtp.NewClient(conn, host)
        if err != nil {
                return err
        }
        defer c.Close()
        if port != "465" {
                if ok, _ := c.Extension("STARTTLS"); ok {
                        if err := c.StartTLS(&tls.Config{ServerName: host}); err != nil {
                                return err
                        }
                }
        }
        if auth != nil {
                if err := c.Auth(auth); err != nil {
                        return err
                }
        }
        if err := c.Mail(from); err != nil {
                return err
        }
        if err := c.Rcpt(to); err != nil {
                return err
        }
        wc, err := c.Data()
        if err != nil {
                return err
        }
        if _, err := wc.Write([]byte(msg)); err != nil {
                return err
        }
        if err := wc.Close(); err != nil {
                return err
        }
        return c.Quit()
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
        link, sent := s.sendVerificationMail(uid, strings.TrimSpace(*u.Email), token, "web")
        if !sent {
                fail(w, http.StatusBadGateway, "mail_send_failed",
                        "the mail service refused the send just now - wait a minute and tap resend again.")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{"sent": true, "_devLink": link})
}

// handleChangeEmail rescues a wrong-email signup: the signed-in account
// swaps its address, the mistaken one leaves the database, and the fresh
// confirmation link goes to the new inbox only. Verification resets - the
// account stays unverified until the new link is consumed. The web verify
// gate and the app verify screen both call this; `return` steers where
// the confirmation link lands the student afterwards (web desk or app).
func (s *Server) handleChangeEmail(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if _, err := s.store.EnsureEntitlement(r.Context(), uid); err != nil {
                s.log.Error("entitlement load failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not change the email")
                return
        }
        var req changeEmailRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        email := strings.ToLower(strings.TrimSpace(req.Email))
        if len(email) > 254 || !emailRE.MatchString(email) {
                fail(w, http.StatusBadRequest, "invalid_email", "enter a valid email address")
                return
        }
        back := req.Return
        if back != "app" {
                back = "web"
        }
        token, err := newVerifyToken()
        if err != nil {
                fail(w, http.StatusInternalServerError, "internal", "could not change the email")
                return
        }
        if err := s.store.ChangeUserEmail(r.Context(), uid, email, token); err != nil {
                if errors.Is(err, store.ErrUniqueEmail) {
                        fail(w, http.StatusConflict, "email_taken", "an account with that email already exists")
                        return
                }
                s.log.Error("change email failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not change the email")
                return
        }
        link, sent := s.sendVerificationMail(uid, email, token, back)
        s.log.Info("signup email changed, confirmation re-issued", "at", time.Now().UTC().Format(time.RFC3339))
        writeJSON(w, http.StatusOK, map[string]any{"sent": sent, "email": email, "_devLink": link})
}

type changeEmailRequest struct {
        Email  string `json:"email"`
        Return string `json:"return"`
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
