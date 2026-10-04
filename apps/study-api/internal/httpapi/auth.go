package httpapi

import (
        "context"
        "encoding/json"
        "errors"
        "net/http"
        "regexp"
        "strings"
        "time"

        "golang.org/x/crypto/bcrypt"

        "renance.dev/study-api/internal/jwtx"
        "renance.dev/study-api/internal/store"
)

// Credential flow: the web registers/logs in with EMAIL + password (the
// username is picked later in the account-setup modal); legacy clients
// (mobile) keep posting username + password and keep working unchanged.
var usernameRE = regexp.MustCompile(`^[a-z0-9_]{3,24}$`)

// Practical RFC-ish gate: one @, a dot in the domain, no spaces/controls.
// Deliverability is not our job - a typo'd address still yields a working
// account, it just cannot receive mail yet.
var emailRE = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]{2,}$`)

// dummyHash equalizes the login timing channel: without it, a missing
// username returns immediately while a wrong password burns ~250ms of
// bcrypt - letting an attacker enumerate usernames by clock alone.
var dummyHash = func() []byte {
        h, err := bcrypt.GenerateFromPassword([]byte("renance-timing-equalizer"), 12)
        if err != nil {
                panic("auth: dummy bcrypt hash: " + err.Error())
        }
        return h
}()

type credentials struct {
        Username string `json:"username"`
        Email    string `json:"email"`
        Password string `json:"password"`
        // DeviceID rides the app's register/login calls: one device, one
        // account (anti free-tier abuse). The web never sends it and the
        // checks simply pass.
        DeviceID string `json:"deviceId,omitempty"`
        // Referral is the referrer's RNC code, minting the new account's
        // referrer 3 REN coins on a manual (non-Google) signup.
        Referral string `json:"referral,omitempty"`
        // VerifyReturn is where the confirmation link hands the student
        // back: "web" (default) or "app".
        VerifyReturn string `json:"verifyReturn,omitempty"`
        // Audience (login only): "students" or "schools" - the tab the
        // sign-in happened under. Founder directive (2026-10-02): school
        // workplace accounts and student accounts are separate; the server
        // refuses a student account under For Schools and a school account
        // under For Students. Empty (legacy clients) stays permissive.
        Audience string `json:"audience,omitempty"`
}

type userPayload struct {
        ID               string `json:"id"`
        Username         string `json:"username"`
        ProfileCompleted bool   `json:"profileCompleted"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
        var req credentials
        if !decodeJSON(w, r, &req) {
                return
        }
        if len(req.Password) < 8 || len(req.Password) > 72 {
                fail(w, http.StatusBadRequest, "invalid_password", "password must be 8-72 characters")
                return
        }

        hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
        if err != nil {
                s.log.Error("bcrypt hash failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not register")
                return
        }

        // Email-first flow (web): register with email, username seeded from the
        // local part and renamed during account setup.
        if strings.TrimSpace(req.Email) != "" {
                email := strings.ToLower(strings.TrimSpace(req.Email))
                if len(email) > 254 || !emailRE.MatchString(email) {
                        fail(w, http.StatusBadRequest, "invalid_email", "enter a valid email address")
                        return
                }
                u, err := s.store.CreateUserEmail(r.Context(), email, string(hash))
                if errors.Is(err, store.ErrUniqueEmail) {
                        fail(w, http.StatusConflict, "email_taken", "an account with that email already exists")
                        return
                }
                if err != nil {
                        s.log.Error("create email user failed", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not register")
                        return
                }
                s.finishSignup(w, r, u, false, req)
                return
        }

        // Legacy username flow (mobile): unchanged.
        req.Username = strings.ToLower(strings.TrimSpace(req.Username))
        if !usernameRE.MatchString(req.Username) {
                fail(w, http.StatusBadRequest, "invalid_username",
                        "username must be 3-24 chars: lowercase letters, digits, underscores")
                return
        }

        u, err := s.store.CreateUser(r.Context(), req.Username, string(hash))
        if errors.Is(err, store.ErrUniqueUsername) {
                fail(w, http.StatusConflict, "username_taken", "that username is already taken")
                return
        }
        if err != nil {
                s.log.Error("create user failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not register")
                return
        }
        s.finishSignup(w, r, u, false, req)
}

// isGoogleAccount reports whether the user row carries a linked Google
// identity (their address was proven on Google's side, so the email
// never needs a Renance confirmation round-trip).
func isGoogleAccount(u *store.User) bool {
        return u != nil && u.GoogleSub != nil && strings.TrimSpace(*u.GoogleSub) != ""
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
        var req credentials
        if !decodeJSON(w, r, &req) {
                return
        }
        // Either identifier: email (web) or username (legacy mobile).
        // Founder bugfix (2026-10-02, "password login broken for
        // months"): the app's login field takes "Username or email" but
        // legacy clients posted the address in the `username` key, so an
        // email login was looked up as a username and refused with
        // "invalid credentials" even with the right password. Two
        // rescues ship here so EVERY client version logs in: the email
        // branch lowercases the address (signup lowercases it too), and
        // a username-shaped miss that contains "@" retries the email
        // lookup before answering.
        identifier := strings.TrimSpace(req.Username)
        var u *store.User
        var err error
        if strings.TrimSpace(req.Email) != "" {
                u, err = s.store.UserByEmail(r.Context(), strings.ToLower(strings.TrimSpace(req.Email)))
        } else {
                u, err = s.store.UserByUsername(r.Context(), strings.ToLower(identifier))
                if err == nil && u == nil && strings.Contains(identifier, "@") {
                        // The identifier is email-shaped: retry as an
                        // email before rejecting the login.
                        u, err = s.store.UserByEmail(r.Context(), strings.ToLower(identifier))
                }
        }
        if err != nil {
                s.log.Error("login lookup failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not log in")
                return
        }
        // Generic error whether the user is missing or the password is
        // wrong - and a real bcrypt compare runs in BOTH branches so the
        // response time cannot reveal which accounts exist.
        if u == nil {
                _ = bcrypt.CompareHashAndPassword(dummyHash, []byte(req.Password))
                fail(w, http.StatusUnauthorized, "invalid_credentials", "invalid email or password")
                return
        }
        if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
                fail(w, http.StatusUnauthorized, "invalid_credentials", "invalid email or password")
                return
        }

        // Audience gate (founder directive 2026-10-02): a student account
        // cannot open the school workplace with student details, and a
        // school account (management/teacher) does not ride the student
        // desk - the details never mix. Runs before the device bind so a
        // refused sign-in never claims the device.
        if !s.allowLoginAudience(r, u, req.Audience) {
                kind, _ := s.store.AccountKindOf(r.Context(), u.ID)
                if kind == store.AccountKindSchool {
                        fail(w, http.StatusForbidden, "school_account",
                                "this is a school account (management or teacher). Sign in under For Schools to open your school workspace.")
                } else {
                        fail(w, http.StatusForbidden, "not_school_account",
                                "this is a student account. Student details cannot open the school workplace - sign in under For Students.")
                }
                return
        }

        // Device lock (one device, one account): a login from a device
        // bound to a DIFFERENT account is refused; an unbound device
        // binds to this account on first app login.
        if err := s.bindDevice(r.Context(), u.ID, req.DeviceID); err != nil {
                s.failDevice(w, err)
                return
        }

        profile, err := s.store.ProfileByUser(r.Context(), u.ID)
        if err != nil {
                s.log.Error("profile lookup failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not log in")
                return
        }
        // Email-confirmation gate (founder directive 2026-09-30): an email
        // account that never confirmed its signup cannot enter. The login
        // re-sends the confirmation mail and hands back a restricted session
        // that drives the confirm screen (resend + wrong-email rescue) and
        // nothing else - closing the app or reloading the tab never loses the
        // unverified state, it lives in the database. Username (legacy mobile),
        // Google and school-staff accounts carry no unconfirmed state and
        // sail through.
        if u.Email != nil && strings.TrimSpace(*u.Email) != "" && !isGoogleAccount(u) {
                ent, err := s.store.EnsureEntitlement(r.Context(), u.ID)
                if err != nil {
                        s.log.Error("entitlement load failed at login", "err", err)
                        fail(w, http.StatusInternalServerError, "internal", "could not log in")
                        return
                }
                if !ent.EmailVerified {
                        // Staff exemption: school workspace accounts
                        // (management/teachers) never ride the student
                        // confirmation loop - their membership is the trust.
                        // Heal the row so later logins skip this lookup.
                        if ctxs, serr := s.store.SchoolsForUser(r.Context(), u.ID); serr == nil && len(ctxs) > 0 {
                                if verr := s.store.MarkEmailVerified(r.Context(), u.ID); verr != nil {
                                        s.log.Error("staff verified-stamp failed", "err", verr)
                                }
                        } else {
                                s.blockUnverifiedLogin(w, r, u, ent, strings.TrimSpace(*u.Email))
                                return
                        }
                }
        }
        s.finishAuth(w, http.StatusOK, u, profile != nil && profile.Completed)
}

// blockUnverifiedLogin answers a credentials-correct login from an
// unconfirmed email account: a fresh confirmation mail goes out
// (cooldown-willing), a restricted session token rides the response so
// the client can drive the confirm screen, and the study surface stays
// closed until the mailed link is consumed.
func (s *Server) blockUnverifiedLogin(w http.ResponseWriter, r *http.Request, u *store.User, ent *store.Entitlement, email string) {
        email = strings.ToLower(strings.TrimSpace(email))
        sent := true
        // Cooldown: a mail just went out (signup, an earlier blocked login or
        // a manual resend) - do not spam the inbox. The window is 15 minutes
        // (founder directive 2026-10-04: every sign-in retry used to mail a
        // fresh copy after just one minute, so the inbox filled with
        // identical confirmation mails). The confirm screen's own Resend
        // button stays on its explicit one-minute cooldown, so a student
        // who genuinely lost the mail still gets it quickly.
        if ent.VerifySentAt == nil || time.Since(*ent.VerifySentAt) >= 15*time.Minute {
                token, err := newVerifyToken()
                if err != nil {
                        s.log.Error("verify token mint failed", "err", err)
                } else if err := s.store.SetEmailVerification(r.Context(), u.ID, token); err != nil {
                        s.log.Error("verify token stamp failed", "err", err)
                } else {
                        _, sent = s.sendVerificationMail(u.ID, email, token, "web")
                }
        }
        token, err := jwtx.IssueUnverified(u.ID, u.Username, s.cfg.JWTSecret)
        if err != nil {
                s.log.Error("token issue failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not log in")
                return
        }
        w.Header().Set("Content-Type", "application/json; charset=utf-8")
        w.WriteHeader(http.StatusForbidden)
        _ = json.NewEncoder(w).Encode(map[string]any{
                "error": map[string]any{
                        "code":    "email_unverified",
                        "message": "confirm your email - we sent a confirmation link to " + email,
                },
                "token":             token,
                "user":              userPayload{ID: u.ID, Username: u.Username},
                "emailVerification": map[string]any{"required": true, "sent": sent, "email": email},
        })
}

func (s *Server) finishAuth(w http.ResponseWriter, status int, u *store.User, profileCompleted bool) {
        token, err := jwtx.Issue(u.ID, u.Username, s.cfg.JWTSecret)
        if err != nil {
                s.log.Error("token issue failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not log in")
                return
        }
        writeJSON(w, status, map[string]any{
                "token": token,
                "user":  userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profileCompleted},
        })
}

// finishSignup wraps finishAuth with everything a fresh manual account
// needs: the device claim (one device, one account), the referral
// credit, the email verification stamp and the verification mail.
func (s *Server) finishSignup(w http.ResponseWriter, r *http.Request, u *store.User, profileCompleted bool, req credentials) {
        if err := s.bindDevice(r.Context(), u.ID, req.DeviceID); err != nil {
                s.failDevice(w, err)
                return
        }
        // Referral: the referrer earns 3 REN for this signup.
        if referrer, _ := s.store.UserByReferralCode(r.Context(), strings.TrimSpace(req.Referral)); referrer != nil && referrer.ID != u.ID {
                if err := s.store.CreditReferral(r.Context(), referrer.ID); err != nil {
                        s.log.Error("referral credit failed", "err", err)
                }
                _ = s.store.SetReferredBy(r.Context(), u.ID, referrer.ID)
        }
        // Mint this account's own referral code (the profile page and
        // the referral share sheet read it).
        if code, cerr := newReferralCode(); cerr == nil {
                if _, cerr := s.store.EnsureReferralCode(r.Context(), u.ID, code); cerr != nil {
                        s.log.Error("referral code mint failed", "err", cerr)
                }
        }
        // Email confirmation: manual signups only (Google addresses are
        // verified by Google themselves). The link returns the student
        // to where the signup happened (web or app).
        var verifyURL string
        sentMail := false
        if strings.TrimSpace(req.Email) != "" {
                token, err := newVerifyToken()
                if err == nil {
                        if err := s.store.SetEmailVerification(r.Context(), u.ID, token); err == nil {
                                verifyURL, sentMail = s.sendVerificationMail(u.ID, strings.TrimSpace(req.Email), token, req.VerifyReturn)
                        }
                } else {
                        s.log.Error("verify token mint failed", "err", err)
                }
        }
        // Founder directive (2026-09-30): the signup itself no longer seats an
        // unconfirmed email account - the token carries the unv claim so every
        // study endpoint stays closed until the mailed link is consumed. The
        // client keeps the session purely to drive the confirm screen (resend,
        // wrong-email rescue, state polling).
        var token string
        var err error
        if strings.TrimSpace(req.Email) != "" {
                token, err = jwtx.IssueUnverified(u.ID, u.Username, s.cfg.JWTSecret)
        } else {
                token, err = jwtx.Issue(u.ID, u.Username, s.cfg.JWTSecret)
        }
        if err != nil {
                s.log.Error("token issue failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not register")
                return
        }
        writeJSON(w, http.StatusCreated, map[string]any{
                "token": token,
                "user":  userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profileCompleted},
                "emailVerification": map[string]any{
                        "required": verifyURL != "" || strings.TrimSpace(req.Email) != "",
                        "sent":     sentMail,
                },
        })
}

// allowLoginAudience enforces the student/school split at sign-in.
// Empty audience (legacy clients) and unknown values stay permissive so
// existing flows keep working; the web and the app both send the tab the
// user signed in under.
func (s *Server) allowLoginAudience(r *http.Request, u *store.User, audience string) bool {
        switch strings.ToLower(strings.TrimSpace(audience)) {
        case "schools":
                kind, err := s.store.AccountKindOf(r.Context(), u.ID)
                if err != nil {
                        s.log.Error("account kind lookup failed", "err", err)
                        return false
                }
                return kind == store.AccountKindSchool
        case "students":
                kind, err := s.store.AccountKindOf(r.Context(), u.ID)
                if err != nil {
                        s.log.Error("account kind lookup failed", "err", err)
                        return false
                }
                return kind != store.AccountKindSchool
        default:
                return true
        }
}

// bindDevice claims the device for the account; empty ids (web) pass.
// The one-device-one-account lock itself is switch-gated (founder
// directive 2026-10-02): while DEVICE_LOCK is false the feature stays
// LOCKED - no binding is recorded and no login is refused, so the app
// behaves exactly as if the lock did not exist. The moment the founder
// sets DEVICE_LOCK=true, every sign-up/sign-in that carries a deviceId
// binds and enforces: an account signed up on a device can only be used
// on that device, and anyone - even the owner - signing in from another
// phone is refused with device_locked + the WhatsApp management rescue.
func (s *Server) bindDevice(ctx context.Context, userID, deviceID string) error {
        if strings.TrimSpace(deviceID) == "" {
                return nil
        }
        if !s.cfg.DeviceLock {
                return nil // feature locked OFF: nothing recorded, nothing refused
        }
        if _, err := s.store.EnsureEntitlement(ctx, userID); err != nil {
                return err
        }
        return s.store.ClaimDevice(ctx, userID, strings.TrimSpace(deviceID))
}

// ManagementWhatsApp is the rescue line printed with every device_locked
// refusal: a student who lost or replaced their phone DMs management,
// management verifies them and clears the binding via
// POST /internal/device/unbind, and the next login on the new phone
// seats cleanly (founder directive 2026-10-02). The DM rescue exists
// ONLY for this case - a login from a new device for an account still
// bound to the old lost one. A device_taken refusal (a second account
// trying to claim a device that already owns one) never points at the
// DM: that student simply signs in with the account this device owns.
const ManagementWhatsApp = "+234 916 763 6685"

func (s *Server) failDevice(w http.ResponseWriter, err error) {
        switch {
        case errors.Is(err, store.ErrDeviceTaken):
                fail(w, http.StatusConflict, "device_taken",
                        "this device already owns an account. Sign in with that account instead.")
        case errors.Is(err, store.ErrDeviceMismatch):
                fail(w, http.StatusForbidden, "device_locked",
                        "one account, one device - this account is locked to your other device. "+
                                "Lost or changed your phone? DM Renance management on WhatsApp at "+
                                ManagementWhatsApp+" and we will move your account.")
        default:
                s.log.Error("device bind failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not bind device")
        }
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
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
        profile, err := s.store.ProfileByUser(r.Context(), uid)
        if err != nil {
                s.log.Error("profile lookup failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load profile")
                return
        }
        // Entitlements: premium role/type/expiry, the REN wallet, the
        // device lock state and email verification ride every /me so the
        // paywall, the blue tick and the verification banner never need a
        // second round-trip. The referral code is minted lazily here so
        // older accounts still get one to share.
        ent, err := s.store.EnsureEntitlement(r.Context(), uid)
        if err != nil {
                s.log.Error("entitlement load failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load entitlements")
                return
        }
        if ent.ReferralCode == "" {
                if code, cerr := newReferralCode(); cerr == nil {
                        if _, uerr := s.store.EnsureReferralCode(r.Context(), uid, code); uerr == nil {
                                ent.ReferralCode = code
                        }
                }
        }
        resp := map[string]any{
                "user":        userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profile != nil && profile.Completed},
                "entitlement": ent,
                "premium": map[string]any{
                        "active": ent.PremiumActive(time.Now().UTC()),
                },
        }
        // The signup address rides /me so the confirm screen (web and app)
        // can show exactly which inbox the confirmation link went to.
        if u.Email != nil {
                if e := strings.TrimSpace(*u.Email); e != "" {
                        resp["email"] = e
                }
        }
        if isGoogleAccount(u) {
                resp["googleAccount"] = true
        }
        if profile != nil {
                resp["profile"] = profile
        } else {
                resp["profile"] = nil
        }
        writeJSON(w, http.StatusOK, resp)
}
