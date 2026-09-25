// Billing: the subscription endpoints. The plan catalog is public; the
// Paystack initializer, the webhook and the REN redemption do the
// granting. Everything lands in study.payments + study.entitlements so
// the owner can also grant or extend premium straight from the Neon
// console (premium_role = true, premium_type, premium_expires_at).
package httpapi

import (
        "context"
        "crypto/hmac"
        "crypto/rand"
        "crypto/sha512"
        "encoding/hex"
        "encoding/json"
        "fmt"
        "io"
        "net/http"
        "strings"
        "time"

        "renance.dev/study-api/internal/plans"
)

// ------------------------------------------------------------- catalog

// handleBillingPlans prints the purchasable tiers and the REN exchange
// table. Public: the paywall renders before any account exists.
func (s *Server) handleBillingPlans(w http.ResponseWriter, r *http.Request) {
        writeJSON(w, http.StatusOK, map[string]any{
                "plans":       plans.PremiumList(),
                "redemptions": plans.RedemptionList(),
                "freePreviewQuestions": plans.FreePreviewQuestions,
                "paystackEnabled":      s.cfg.PaystackSecretKey != "",
                "whatsapp":             billingWhatsApp,
        })
}

// billingWhatsApp is the founder's direct line for bulk and school
// subscription negotiation, printed on every paywall surface.
const billingWhatsApp = "07046203544"

// ------------------------------------------------- paystack initialize

type initializeRequest struct {
        Plan string `json:"plan"`
}

// paystackInitResponse is the slice of Paystack's
// POST /transaction/initialize answer the client needs.
type paystackInitResponse struct {
        Status  bool `json:"status"`
        Message string `json:"message"`
        Data    struct {
                AuthorizationURL string `json:"authorization_url"`
                AccessCode       string `json:"access_code"`
                Reference        string `json:"reference"`
        } `json:"data"`
}

// handleBillingInitialize starts a Paystack charge for one plan. Without
// PAYSTACK_SECRET_KEY the endpoint answers 503 paystack_unavailable and
// the paywall falls back to the WhatsApp line; the plan catalog still
// renders, nothing is half-charged.
func (s *Server) handleBillingInitialize(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        if s.cfg.PaystackSecretKey == "" {
                fail(w, http.StatusServiceUnavailable, "paystack_unavailable",
                        "card payments are being connected. Use the WhatsApp line or REN coins for now.")
                return
        }
        var req initializeRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        plan, ok := plans.PremiumByCode()[req.Plan]
        if !ok {
                fail(w, http.StatusBadRequest, "unknown_plan", "no plan named "+req.Plan)
                return
        }
        reference := newReference(uid)
        if _, err := s.store.CreatePayment(r.Context(), uid, "paystack", plan.Code,
                plan.AmountKobo, reference, "{}"); err != nil {
                s.log.Error("billing: create payment", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not start payment")
                return
        }
        authURL, err := s.paystackInitialize(r.Context(), plan, reference, uid)
        if err != nil {
                s.log.Error("billing: paystack initialize", "err", err)
                fail(w, http.StatusBadGateway, "paystack_error",
                        "could not reach Paystack, try again shortly")
                return
        }
        writeJSON(w, http.StatusCreated, map[string]any{
                "reference":         reference,
                "plan":              plan.Code,
                "amountKobo":        plan.AmountKobo,
                "authorizationUrl":  authURL,
        })
}

// paystackInitialize calls Paystack's transaction initialize endpoint.
func (s *Server) paystackInitialize(ctx context.Context, p plans.Plan, reference, userID string) (string, error) {
        body, _ := json.Marshal(map[string]any{
                "email":     "renance+" + userID + "@users.noreply.reance.app",
                "amount":    p.AmountKobo,
                "reference": reference,
                "currency":  "NGN",
                "metadata":  map[string]string{"plan": p.Code, "user_id": userID},
        })
        req, err := http.NewRequestWithContext(ctx, http.MethodPost,
                "https://api.paystack.co/transaction/initialize", strings.NewReader(string(body)))
        if err != nil {
                return "", err
        }
        req.Header.Set("Authorization", "Bearer "+s.cfg.PaystackSecretKey)
        req.Header.Set("Content-Type", "application/json")
        resp, err := http.DefaultClient.Do(req)
        if err != nil {
                return "", err
        }
        defer resp.Body.Close()
        raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
        if err != nil {
                return "", err
        }
        var init paystackInitResponse
        if err := json.Unmarshal(raw, &init); err != nil {
                return "", fmt.Errorf("paystack: bad payload: %w", err)
        }
        if !init.Status || init.Data.AuthorizationURL == "" {
                return "", fmt.Errorf("paystack: initialize refused: %s", init.Message)
        }
        return init.Data.AuthorizationURL, nil
}

// --------------------------------------------------------------- webhook

// handlePaystackWebhook receives charge events. Paystack signs the raw
// body with HMAC-SHA512 of the secret key in x-paystack-signature; the
// body is read exactly once and verified before anything parses.
func (s *Server) handlePaystackWebhook(w http.ResponseWriter, r *http.Request) {
        if s.cfg.PaystackSecretKey == "" {
                fail(w, http.StatusServiceUnavailable, "paystack_unavailable", "webhook is not configured")
                return
        }
        raw, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
        if err != nil {
                fail(w, http.StatusBadRequest, "bad_request", "unreadable body")
                return
        }
        mac := hmac.New(sha512.New, []byte(s.cfg.PaystackSecretKey))
        mac.Write(raw)
        want := hex.EncodeToString(mac.Sum(nil))
        if got := r.Header.Get("x-paystack-signature"); !hmac.Equal([]byte(got), []byte(want)) {
                fail(w, http.StatusUnauthorized, "bad_signature", "signature mismatch")
                return
        }
        var event struct {
                Event string `json:"event"`
                Data  struct {
                        Reference string `json:"reference"`
                        Status    string `json:"status"`
                } `json:"data"`
        }
        if err := json.Unmarshal(raw, &event); err != nil {
                fail(w, http.StatusBadRequest, "bad_request", "unparsable event")
                return
        }
        if event.Event != "charge.success" {
                writeJSON(w, http.StatusOK, map[string]any{"received": true})
                return
        }
        userID, planCode, changed, err := s.store.SetPaymentStatus(r.Context(), event.Data.Reference, "success")
        if err != nil {
                s.log.Error("billing: webhook settle", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not settle payment")
                return
        }
        if !changed {
                // Replay or already-granted charge: acknowledge, never re-grant.
                writeJSON(w, http.StatusOK, map[string]any{"received": true})
                return
        }
        plan, ok := plans.PremiumByCode()[planCode]
        if !ok {
                s.log.Error("billing: webhook grant", "plan", planCode, "err", "unknown plan")
                writeJSON(w, http.StatusOK, map[string]any{"received": true})
                return
        }
        if err := s.store.SetPremium(r.Context(), userID, plan.Code, plan.Duration()); err != nil {
                s.log.Error("billing: webhook grant", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not grant premium")
                return
        }
        s.log.Info("billing: premium granted", "user", userID, "plan", plan.Code)
        writeJSON(w, http.StatusOK, map[string]any{"received": true})
}

// -------------------------------------------------------------- redeem

type redeemRequest struct {
        Code string `json:"code"`
}

// handleBillingRedeem exchanges REN coins for premium days. The debit is
// atomic (short balances refuse), the grant stacks onto any remaining
// subscription exactly like a purchase.
func (s *Server) handleBillingRedeem(w http.ResponseWriter, r *http.Request) {
        uid, err := userIDFrom(r)
        if err != nil {
                fail(w, http.StatusUnauthorized, "unauthorized", "missing identity")
                return
        }
        var req redeemRequest
        if !decodeJSON(w, r, &req) {
                return
        }
        red, ok := plans.RedemptionByCode()[req.Code]
        if !ok {
                fail(w, http.StatusBadRequest, "unknown_redemption", "no redemption named "+req.Code)
                return
        }
        spent, err := s.store.SpendCoins(r.Context(), uid, red.Coins)
        if err != nil {
                s.log.Error("billing: redeem spend", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not redeem")
                return
        }
        if !spent {
                fail(w, http.StatusPaymentRequired, "insufficient_coins",
                        fmt.Sprintf("this reward costs %d REN coins, your balance is short. Win in the arena (+1 per duel) or refer a friend (+3).", red.Coins))
                return
        }
        if err := s.store.SetPremium(r.Context(), uid, "ren_"+red.Code,
                time.Duration(red.DurationDays)*24*time.Hour); err != nil {
                // Refund on grant failure so coins are never lost to a bug.
                _ = s.store.AddCoins(r.Context(), uid, red.Coins)
                s.log.Error("billing: redeem grant", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not apply premium")
                return
        }
        ent, err := s.store.EnsureEntitlement(r.Context(), uid)
        if err != nil {
                s.log.Error("billing: redeem reload", "err", err)
                fail(w, http.StatusInternalServerError, "internal", "could not reload entitlement")
                return
        }
        writeJSON(w, http.StatusOK, map[string]any{"entitlement": ent})
}

// newReference mints a payment reference: pay_ + 16 random hex chars,
// collision-safe enough for a nation-scale study app.
func newReference(userID string) string {
        buf := make([]byte, 8)
        if _, err := rand.Read(buf); err != nil {
                // A timing-stable fallback reference; uniqueness rides the
                // payments table's UNIQUE constraint.
                return fmt.Sprintf("pay_%s_%d", shortID(userID), time.Now().UnixNano())
        }
        return "pay_" + hex.EncodeToString(buf)
}

func shortID(id string) string {
        if len(id) > 8 {
                id = id[:8]
        }
        return strings.ReplaceAll(id, "-", "")
}
