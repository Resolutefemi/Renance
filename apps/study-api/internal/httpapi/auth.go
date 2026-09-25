package httpapi

import (
        "context"
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

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
        var req credentials
        if !decodeJSON(w, r, &req) {
                return
        }
        // Either identifier: email (web) or username (legacy mobile).
        var u *store.User
        var err error
        if strings.TrimSpace(req.Email) != "" {
                u, err = s.store.UserByEmail(r.Context(), strings.TrimSpace(req.Email))
        } else {
                u, err = s.store.UserByUsername(r.Context(), strings.TrimSpace(req.Username))
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
        s.finishAuth(w, http.StatusOK, u, profile != nil && profile.Completed)
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
        // Email verification: manual signups only (Google addresses are
        // verified by Google themselves). The link returns the student
        // to where the signup happened (web or app).
        var verifyURL string
        if strings.TrimSpace(req.Email) != "" {
                token, err := newVerifyToken()
                if err == nil {
                        if err := s.store.SetEmailVerification(r.Context(), u.ID, token); err == nil {
                                verifyURL = s.sendVerificationMail(u.ID, strings.TrimSpace(req.Email), token, req.VerifyReturn)
                        }
                } else {
                        s.log.Error("verify token mint failed", "err", err)
                }
        }
        token, err := jwtx.Issue(u.ID, u.Username, s.cfg.JWTSecret)
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
                        "sent":     verifyURL != "",
                },
        })
}

// bindDevice claims the device for the account; empty ids (web) pass.
func (s *Server) bindDevice(ctx context.Context, userID, deviceID string) error {
        if strings.TrimSpace(deviceID) == "" {
                return nil
        }
        if _, err := s.store.EnsureEntitlement(ctx, userID); err != nil {
                return err
        }
        return s.store.ClaimDevice(ctx, userID, strings.TrimSpace(deviceID))
}

func (s *Server) failDevice(w http.ResponseWriter, err error) {
        switch {
        case errors.Is(err, store.ErrDeviceTaken):
                fail(w, http.StatusConflict, "device_taken",
                        "this device already owns an account. Sign in with that account instead.")
        case errors.Is(err, store.ErrDeviceMismatch):
                fail(w, http.StatusForbidden, "device_locked",
                        "this device is locked to another account (one device, one account).")
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
        // second round-trip.
        ent, err := s.store.EnsureEntitlement(r.Context(), uid)
        if err != nil {
                s.log.Error("entitlement load failed", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not load entitlements")
                return
        }
        resp := map[string]any{
                "user":        userPayload{ID: u.ID, Username: u.Username, ProfileCompleted: profile != nil && profile.Completed},
                "entitlement": ent,
                "premium": map[string]any{
                        "active": ent.PremiumActive(time.Now().UTC()),
                },
        }
        if profile != nil {
                resp["profile"] = profile
        } else {
                resp["profile"] = nil
        }
        writeJSON(w, http.StatusOK, resp)
}
