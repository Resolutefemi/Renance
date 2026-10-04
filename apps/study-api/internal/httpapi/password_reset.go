package httpapi

import (
        "fmt"
        "net/http"
        "os"
        "strings"
        "sync"
        "time"

        "golang.org/x/crypto/bcrypt"

        "renance.dev/study-api/internal/store"
)

// resendAPIKey / mailAPIKey / mailRelayHost read the same transports
// the confirmation mail uses (Brevo HTTPS API first - a fresh account
// since 2026-10-03 - then the Resend HTTPS API, then the Resend SMTP
// relay as the last hop; founder directive 2026-10-03).
func resendAPIKey() string  { return os.Getenv("RESEND_API_KEY") }
func mailAPIKey() string    { return os.Getenv("BREVO_API_KEY") }
func mailRelayHost() string { return os.Getenv("SMTP_HOST") }

// Forgot password (founder directive, 2026-10-02): works on the web and
// for app accounts. The request takes an email OR a username; the reset
// link mails to the address on the account and lands on the web
// /reset-password page, which runs in any browser - including the
// in-app browser of a phone. Responses are uniform (always sent:true)
// so the endpoint cannot be used to enumerate accounts.
//
// Quota armor, trimmed (founder directive 2026-10-05, "remove the 100
// email/day budget, remove the 3 emails per one user"): the 2026-10-04
// armor stacked THREE walls and the per-account ones locked real students
// out once a bot had burned their address. What remains is exactly the
// request-driven armor - the mail count only follows what users actually
// request:
//   1. route-level authLimit (per-IP + global token buckets, server.go)
//   2. per-account 10-minute duplicate guard: a double-tap, a second tab
//      or a retried submit no longer stacks identical mails - the earlier
//      link is still live (30 minutes) and works exactly the same. No
//      per-account daily ceiling: a user can request as many times as
//      the cooldown allows, every day.
//   3. global RESET_MAIL_DAILY_CAP per UTC day across all accounts,
//      set to 300 - the Brevo free plan itself - so a flood still cannot
//      push the provider past its own plan (confirmation mails share it).
// Every suppression keeps the uniform sent:true response.

// dailyMailBudget is the global per-day cap on reset mails. Zero cap
// disables it. The counter is in-memory on purpose: it is a quota
// safety valve, not an audit log - a Render restart resets the day's
// count, which only ever lets a handful more mails through.
type dailyMailBudget struct {
        mu  sync.Mutex
        cap int
        day string // UTC "2006-01-02" the count belongs to
        n   int
        now func() time.Time
}

func newDailyMailBudget(cap int) *dailyMailBudget {
        return &dailyMailBudget{cap: cap, now: time.Now}
}

// take spends one mail from today's budget, reporting whether it
// cleared. A disabled or untouched budget always clears.
func (b *dailyMailBudget) take() bool {
        if b == nil || b.cap <= 0 {
                return true
        }
        b.mu.Lock()
        defer b.mu.Unlock()
        today := b.now().UTC().Format("2006-01-02")
        if b.day != today {
                b.day = today
                b.n = 0
        }
        if b.n >= b.cap {
                return false
        }
        b.n++
        return true
}

// (Stringer keeps the suppression log readable.)
func (b *dailyMailBudget) String() string {
        if b == nil {
                return "budget(disabled)"
        }
        return fmt.Sprintf("budget(%d/%d)", b.n, b.cap)
}

type forgotPasswordRequest struct {
        // Identifier accepts an email or a username (app users remember the
        // handle; the lookup falls back username -> email).
        Identifier string `json:"identifier,omitempty"`
        Email      string `json:"email,omitempty"`
        Username   string `json:"username,omitempty"`
        // Return steers the reset link's tail: "web" (default) or "app".
        Return string `json:"return,omitempty"`
}

func (s *Server) handleForgotPassword(w http.ResponseWriter, r *http.Request) {
        var req forgotPasswordRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        identifier := strings.ToLower(strings.TrimSpace(req.Identifier))
        if identifier == "" {
                identifier = strings.ToLower(strings.TrimSpace(req.Email))
        }
        if identifier == "" {
                identifier = strings.ToLower(strings.TrimSpace(req.Username))
        }
        if identifier == "" {
                fail(w, http.StatusBadRequest, "invalid_body", "pass your email or username")
                return
        }

        // Resolve email first, then username. Not found -> the same 200 as
        // everyone else; no account enumeration.
        u, err := s.store.UserByEmail(r.Context(), identifier)
        if err != nil {
                s.log.Error("forgot-password lookup failed", "err", err)
                writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                return
        }
        if u == nil {
                u, err = s.store.UserByUsername(r.Context(), identifier)
                if err != nil {
                        s.log.Error("forgot-password lookup failed", "err", err)
                        writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                        return
                }
        }
        if u == nil || u.Email == nil || strings.TrimSpace(*u.Email) == "" {
                // Legacy username-only accounts carry no inbox: nothing to mail,
                // but the response stays uniform.
                writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                return
        }
        email := strings.ToLower(strings.TrimSpace(*u.Email))

        // Duplicate-mail guard (founder directive 2026-10-04): every
        // request used to mint and mail a fresh link, so a double-tap, a
        // second tab or a retried submit stacked identical mails in the
        // inbox. Inside the ten-minute window the response stays the
        // uniform sent:true but nothing new is mailed - the earlier link
        // is still live (30 minutes) and works exactly the same.
        if at, lerr := s.store.LatestPasswordResetAt(r.Context(), u.ID); lerr == nil &&
                !at.IsZero() && time.Since(at) < 10*time.Minute {
                s.log.Info("password reset mail suppressed (cooldown)", "to", email)
                writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                return
        }

        // Global daily budget (wall 3, founder directive 2026-10-05):
        // sized to the Brevo plan itself (300/day) - even a distributed
        // flood across many inboxes cannot push the provider past its
        // own plan. No per-account daily ceiling: the request-driven
        // 10-minute guard above is the only per-account wall.
        if !s.resetBudget.take() {
                s.log.Warn("password reset mail suppressed (global daily budget)",
                        "to", email, "budget", s.resetBudget.String())
                writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                return
        }

        // Mint and store the single-use token (30 minutes).
        token, err := newVerifyToken()
        if err != nil {
                s.log.Error("reset token mint failed", "err", err)
                writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                return
        }
        if err := s.store.CreatePasswordReset(r.Context(), u.ID,
                store.HashResetToken(token), time.Now().UTC().Add(30*time.Minute)); err != nil {
                s.log.Error("reset token store failed", "err", err)
                writeJSON(w, http.StatusOK, map[string]any{"sent": true})
                return
        }
        link, sent := s.sendPasswordResetMail(email, token, req.Return)
        s.log.Info("password reset requested", "to", email, "sent", sent, "link", link)
        writeJSON(w, http.StatusOK, map[string]any{"sent": true})
}

type resetPasswordRequest struct {
        Token    string `json:"token"`
        Password string `json:"password"`
}

func (s *Server) handleResetPassword(w http.ResponseWriter, r *http.Request) {
        var req resetPasswordRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        if len(req.Password) < 8 || len(req.Password) > 72 {
                fail(w, http.StatusBadRequest, "invalid_password", "password must be 8-72 characters")
                return
        }
        userID, err := s.store.ConsumePasswordReset(r.Context(),
                store.HashResetToken(strings.TrimSpace(req.Token)))
        if err != nil {
                fail(w, http.StatusBadRequest, "invalid_token",
                        "this reset link is not valid any more - request a fresh one.")
                return
        }
        hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
        if err != nil {
                s.log.Error("bcrypt hash failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not reset the password")
                return
        }
        if err := s.store.UpdatePasswordHash(r.Context(), userID, string(hash)); err != nil {
                s.log.Error("password update failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not reset the password")
                return
        }
        s.log.Info("password reset completed", "user", userID)
        writeJSON(w, http.StatusOK, map[string]any{"reset": true})
}

// sendPasswordResetMail builds and best-effort sends the reset mail.
// Same transports as the confirmation mail: Resend HTTPS API first,
// the SMTP relay as fallback. Returns the reset URL and whether the
// mail left the building.
func (s *Server) sendPasswordResetMail(email, token, resetReturn string) (string, bool) {
        back := resetReturn
        if back != "app" {
                back = "web"
        }
        link := s.siteURL() + "/reset-password/?token=" + token + "&return=" + back
        subject := "Reset your password - Renance"
        textBody := `Password reset requested.

Set a new password for your Renance account:

` + link + `

This link works once and expires in 30 minutes.

Nothing in your inbox? Check the spam folder - marking this mail
'Not spam' keeps Renance in your main inbox.

If you did not request a reset you can ignore this mail - your
current password keeps working.`
        htmlBody := `<!doctype html>
<html><body style="margin:0;padding:24px;background:#f4f2ef;font-family:Arial,Helvetica,sans-serif;color:#17181c;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
    <table role="presentation" width="100%" style="max-width:420px;background:#ffffff;border-radius:14px;padding:28px 24px;" cellpadding="0" cellspacing="0">
      <tr><td align="center" style="font-size:20px;font-weight:700;letter-spacing:2px;padding-bottom:6px;">RENANCE</td></tr>
      <tr><td align="center" style="font-size:15px;color:#5c5f66;padding-bottom:18px;">Your guide to academic success</td></tr>
      <tr><td style="font-size:15px;line-height:1.6;padding-bottom:8px;"><b>Password reset requested.</b></td></tr>
      <tr><td style="font-size:14px;line-height:1.6;color:#33363d;padding-bottom:22px;">
        Set a new password for your Renance account. The link works once and expires in 30 minutes.
      </td></tr>
      <tr><td align="center" style="padding-bottom:22px;">
        <a href="` + link + `" style="display:inline-block;background:#17181c;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:14px 34px;border-radius:999px;">Reset password</a>
      </td></tr>
      <tr><td style="font-size:12px;line-height:1.7;color:#8b8e96;word-break:break-all;">
        Button not working? Copy this link into your browser:<br>
        <a href="` + link + `" style="color:#17181c;">` + link + `</a>
      </td></tr>
      <tr><td style="font-size:12px;line-height:1.7;color:#8b8e96;padding-top:14px;">
        Nothing in your inbox? Check the spam folder - marking this mail 'Not spam' keeps Renance in your main inbox.
      </td></tr>
      <tr><td style="font-size:12px;line-height:1.7;color:#8b8e96;padding-top:16px;">
        If you did not request a reset you can ignore this mail - your current password keeps working.
      </td></tr>
    </table>
  </td></tr></table>
</body></html>`
        sent := false
        // Brevo first, Resend second, the relay (Resend SMTP) last - the
        // same order the confirmation mail rides (founder directive
        // 2026-10-03). One provider call per mail, no retries, no
        // polling - gentle on the fresh Brevo account.
        if key := strings.TrimSpace(mailAPIKey()); key != "" {
                if err := brevoAPISend(key, email, subject, textBody, htmlBody); err != nil {
                        s.log.Error("reset mail via Brevo HTTPS API failed (falling back to Resend)", "err", err)
                } else {
                        sent = true
                }
        }
        if !sent {
                if key := strings.TrimSpace(resendAPIKey()); key != "" {
                        if err := resendAPISend(key, email, subject, textBody, htmlBody); err != nil {
                                s.log.Error("reset mail via Resend API failed (falling back to the SMTP relay)", "err", err)
                        } else {
                                sent = true
                        }
                }
        }
        if !sent {
                if host := strings.TrimSpace(mailRelayHost()); host != "" {
                        if err := smtpSend(host, email, subject, textBody); err != nil {
                                s.log.Error("reset mail via SMTP relay failed", "err", err)
                        } else {
                                sent = true
                        }
                }
        }
        if !sent && strings.TrimSpace(resendAPIKey()) == "" && strings.TrimSpace(mailAPIKey()) == "" && strings.TrimSpace(mailRelayHost()) == "" {
                s.log.Warn("no mail transport configured: the reset link is only in this log", "to", email, "url", link)
        }
        return link, sent
}
