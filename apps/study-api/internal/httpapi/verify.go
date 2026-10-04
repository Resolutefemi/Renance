// Email confirmation: manual signups get a mailed link that lands on
// the web /verify page (or the app's verify screen) and hands the
// student back to where the signup happened. FOUNDER DIRECTIVE
// (2026-09-30): an email account that never confirmed its signup is
// locked out - login re-sends the mail and answers email_unverified,
// and the session token carries the unv claim so every study endpoint
// stays closed until the link is consumed. Google signups are
// pre-verified by Google. Transport (founder directive 2026-10-03):
// the Brevo HTTPS API first (BREVO_API_KEY - a fresh Brevo account,
// sender Renance <verify@renance.app> already validated on it), then
// the Resend HTTPS API (RESEND_API_KEY - renance.app is a verified
// domain there, so it doubles as the backup), then the SMTP relay
// (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM - pointing
// at Resend's own SMTP so an API-side outage still delivers). With
// none configured the link is written to the server log so nothing
// is lost.
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

        "renance.dev/study-api/internal/jwtx"
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
// login, then a last resort that still reads sensibly in a mail client.
func mailFrom() string {
        if f := strings.TrimSpace(os.Getenv("SMTP_FROM")); f != "" {
                return f
        }
        if f := strings.TrimSpace(os.Getenv("SMTP_USER")); f != "" {
                return f
        }
        return "no-reply@renance.com"
}

// resendFrom picks the Resend sender: RESEND_FROM first (e.g.
// "Renance <verify@renance.app>"), then the domain-verified default.
// The address must belong to a domain verified in the Resend account.
func resendFrom() string {
        if f := strings.TrimSpace(os.Getenv("RESEND_FROM")); f != "" {
                return f
        }
        return "Renance <verify@renance.app>"
}

// sendVerificationMail builds and (best-effort) sends the confirmation
// mail. Returns the verification URL (so dev surfaces can carry it) and
// whether the mail actually left the building - the response to the
// client reports that honestly instead of pretending. The mail ships
// as HTML with a real anchor (plus a plain-text fallback): mail clients
// that do not auto-linkify bare URLs (Outlook, Samsung Mail, some
// Gmail layouts) still get a big tappable Confirm button, and the
// query ampersand is encoded exactly once - no &amp; surprises.
func (s *Server) sendVerificationMail(userID, email, token, verifyReturn string) (string, bool) {
        back := verifyReturn
        if back != "app" {
                back = "web"
        }
        link := fmt.Sprintf("%s/verify/?token=%s&return=%s", s.siteURL(), token, back)
        subject := "Confirm your email - Renance"
        textBody := fmt.Sprintf(`Welcome to Renance.

Confirm your email address:

%s

This link works once and never expires, but use it soon. You must
confirm before you can sign in and study.

Nothing in your inbox? Check the spam folder - marking this mail
'Not spam' keeps Renance in your main inbox.

If you did not create this account you can ignore this mail.
`, link)
        htmlBody := fmt.Sprintf(`<!doctype html>
<html><body style="margin:0;padding:24px;background:#f4f2ef;font-family:Arial,Helvetica,sans-serif;color:#17181c;">
  <table role="presentation" width="100%%" cellpadding="0" cellspacing="0"><tr><td align="center">
    <table role="presentation" width="100%%" style="max-width:420px;background:#ffffff;border-radius:14px;padding:28px 24px;" cellpadding="0" cellspacing="0">
      <tr><td align="center" style="font-size:20px;font-weight:700;letter-spacing:2px;padding-bottom:6px;">RENANCE</td></tr>
      <tr><td align="center" style="font-size:15px;color:#5c5f66;padding-bottom:18px;">Your guide to academic success</td></tr>
      <tr><td style="font-size:15px;line-height:1.6;padding-bottom:8px;"><b>Welcome to Renance.</b></td></tr>
      <tr><td style="font-size:14px;line-height:1.6;color:#33363d;padding-bottom:22px;">
        Confirm your email address to unlock your account. The link works once and never expires.
      </td></tr>
      <tr><td align="center" style="padding-bottom:22px;">
        <a href="%s" style="display:inline-block;background:#17181c;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:14px 34px;border-radius:999px;">Confirm your email</a>
      </td></tr>
      <tr><td style="font-size:12px;line-height:1.7;color:#8b8e96;word-break:break-all;">
        Button not working? Copy this link into your browser:<br>
        <a href="%s" style="color:#17181c;">%s</a>
      </td></tr>
      <tr><td style="font-size:12px;line-height:1.7;color:#8b8e96;padding-top:14px;">
        Nothing in your inbox? Check the spam folder - marking this mail 'Not spam' keeps Renance in your main inbox.
      </td></tr>
      <tr><td style="font-size:12px;line-height:1.7;color:#8b8e96;padding-top:16px;">
        If you did not create this account you can ignore this mail.
      </td></tr>
    </table>
  </td></tr></table>
</body></html>`, link, link, link)
        _ = userID // logs stay free of account ids beyond the address
        sent := false
        // Brevo HTTPS API first (founder directive 2026-10-03): a
        // fresh Brevo account, sender Renance <verify@renance.app>
        // already validated on it. One provider call per mail, no
        // retries, no polling - deliberately gentle API usage so the
        // fresh account stays in good standing.
        if key := strings.TrimSpace(os.Getenv("BREVO_API_KEY")); key != "" {
                if err := brevoAPISend(key, email, subject, textBody, htmlBody); err != nil {
                        s.log.Error("confirmation mail via Brevo HTTPS API failed (falling back to Resend)", "err", err)
                } else {
                        sent = true
                }
        }
        if !sent {
                if key := strings.TrimSpace(os.Getenv("RESEND_API_KEY")); key != "" {
                        if err := resendAPISend(key, email, subject, textBody, htmlBody); err != nil {
                                s.log.Error("confirmation mail via Resend API failed (falling back to the SMTP relay)", "err", err)
                        } else {
                                sent = true
                        }
                }
        }
        if !sent {
                if host := strings.TrimSpace(os.Getenv("SMTP_HOST")); host != "" {
                        if err := smtpSend(host, email, subject, textBody); err != nil {
                                s.log.Error("confirmation mail via SMTP relay failed (check SMTP_USER/SMTP_PASS - the Brevo relay code + SMTP key - and that SMTP_FROM is a validated sender)", "err", err)
                        } else {
                                sent = true
                        }
                }
        }
        if !sent {
                if strings.TrimSpace(os.Getenv("RESEND_API_KEY")) == "" && strings.TrimSpace(os.Getenv("BREVO_API_KEY")) == "" && strings.TrimSpace(os.Getenv("SMTP_HOST")) == "" {
                        s.log.Warn("no mail transport configured: set BREVO_API_KEY (primary) or RESEND_API_KEY / SMTP_HOST/SMTP_PASS (backup + relay) on the Render service; the confirmation link is only in this log", "to", email, "url", link)
                } else {
                        s.log.Warn("confirmation mail did NOT go out: every configured transport refused the send (check the Brevo sender, the Resend domain status and the relay credentials)", "to", email, "url", link)
                }
        }
        return link, sent
}

// sendVerificationMailAsync ships the confirmation mail OFF the request
// path (founder bugfix 2026-10-05, "Renance server timed out then email
// already existed"): the transports used to run INSIDE the signup/login
// response - Brevo up to 30s, Resend 30s more, the SMTP relay a minute
// - while the app's HTTP client gave up long before, showed "servers
// timed out", and the retry then hit "email already exists" because the
// account had been created all along. The mail now goes out in the
// background with its own deadline; the response returns the moment the
// database row is stamped. Request contexts die with the handler, so
// the goroutine runs on its own.
func (s *Server) sendVerificationMailAsync(userID, email, token, verifyReturn string) {
        go func() {
                _, sent := s.sendVerificationMail(userID, email, token, verifyReturn)
                if !sent {
                        s.log.Warn("confirmation mail did not leave the building (async send)", "to", email)
                }
        }()
}

// brevoAPISend hands the mail to Brevo's HTTPS API - the PRIMARY
// transport again since 2026-10-03 (founder directive: a fresh Brevo
// account; sender Renance <verify@renance.app> is validated on it).
// The relay filters connecting IPs (525 5.7.1) - the API does not -
// so a single BREVO_API_KEY paste rescues delivery from any host,
// Render included. Sends both an HTML body (the tappable Confirm
// button) and the plain-text fallback.
func brevoAPISend(key, to, subject, textBody, htmlBody string) error {
        payload := map[string]any{
                "sender":      map[string]string{"name": "Renance", "email": mailFrom()},
                "to":          []map[string]string{{"email": to}},
                "subject":     subject,
                "textContent": textBody,
                "htmlContent": htmlBody,
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
        // 12s hard cap (was 30): the send now rides the async path, and a
        // hung provider must never eat a whole transport window - the
        // fallback chain gets its turn quickly.
        client := &http.Client{Timeout: 12 * time.Second}
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

// resendAPISend hands the mail to Resend's HTTPS API: the BACKUP
// transport since 2026-10-03 (Brevo is primary again) - renance.app
// is a verified domain there and the sender Renance
// <verify@renance.app> survives any Brevo-side suspension. Ships the
// HTML body (the tappable Confirm button) plus the plain-text
// fallback.
func resendAPISend(key, to, subject, textBody, htmlBody string) error {
        payload := map[string]any{
                "from":    resendFrom(),
                "to":      []string{to},
                "subject": subject,
                "html":    htmlBody,
                "text":    textBody,
        }
        buf, err := json.Marshal(payload)
        if err != nil {
                return err
        }
        req, err := http.NewRequest(http.MethodPost, "https://api.resend.com/emails", bytes.NewReader(buf))
        if err != nil {
                return err
        }
        req.Header.Set("Authorization", "Bearer "+key)
        req.Header.Set("content-type", "application/json")
        req.Header.Set("accept", "application/json")
        // Same 12s hard cap as the Brevo transport (see above).
        client := &http.Client{Timeout: 12 * time.Second}
        res, err := client.Do(req)
        if err != nil {
                return err
        }
        defer res.Body.Close()
        data, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
        if res.StatusCode >= 300 {
                return fmt.Errorf("resend api status %d: %s", res.StatusCode, strings.TrimSpace(string(data)))
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
        // Founder bugfix 2026-10-05: the send rides the async path - the
        // transports (up to a minute of Brevo/Resend/SMTP retries) must
        // never hold this response open long enough for a phone client to
        // give up. "sent: true" from here means the mail is queued with
        // the transports; a total refusal lands in the service log.
        s.sendVerificationMailAsync(uid, strings.TrimSpace(*u.Email), token, "web")
        writeJSON(w, http.StatusOK, map[string]any{"sent": true})
}

// handleRefreshSession swaps a restricted (unverified) session for a
// fully seated one: the client consumes the mailed link, /me reports
// emailVerified flipped true, and this re-mints the 12h token without
// the unv claim so the study surface opens. A still-unconfirmed account
// keeps the 403 - the confirm screen stays up.
func (s *Server) handleRefreshSession(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        u, err := s.store.UserByID(r.Context(), uid)
        if err != nil || u == nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "unknown user")
                return
        }
        verified := u.Email == nil || strings.TrimSpace(*u.Email) == "" || isGoogleAccount(u)
        if !verified {
                ent, err := s.store.EnsureEntitlement(r.Context(), uid)
                if err != nil {
                        s.log.Error("entitlement load failed", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not refresh the session")
                        return
                }
                verified = ent.EmailVerified
        }
        if !verified {
                fail(w, http.StatusForbidden, "email_unverified",
                        "confirm your email to continue - sign in again to resend the confirmation mail.")
                return
        }
        profile, err := s.store.ProfileByUser(r.Context(), uid)
        if err != nil {
                s.log.Error("profile lookup failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not refresh the session")
                return
        }
        token, err := jwtx.Issue(u.ID, u.Username, s.cfg.JWTSecret)
        if err != nil {
                s.log.Error("token issue failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not refresh the session")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{
                "token": token,
                "user":  userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profile != nil && profile.Completed},
        })
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
        s.sendVerificationMailAsync(uid, email, token, back)
        s.log.Info("signup email changed, confirmation re-issued", "at", time.Now().UTC().Format(time.RFC3339))
        writeJSON(w, http.StatusOK, map[string]any{"sent": true, "email": email})
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
