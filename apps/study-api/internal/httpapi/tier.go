package httpapi

// Tier gates: the founder's subscription ladder enforced server-side.
// The catalog (internal/plans) owns the ranks; a stored premium_type
// that predates the ladder (week, month, quarter, year and every
// console grant) ranks Premium, so grandfathered subscribers keep
// everything. The clients render the upgrade copy from
// /billing/plans - these handlers only refuse and point at the plan.
//
// While plans.StudentBillingEnabled is false (founder directive,
// 2026-09-28: "set subscription to false, everyone gets premium for
// now") every caller ranks Premium with an all-bodies scope: nobody is
// asked for a card anywhere, the AI tutor is open, and the free-tier
// 20-question cap cannot fire. The entitlement rows in the database are
// also stamped premium, so the blue tick and the wallet stay truthful.

import (
        "net/http"
        "time"

        "renance.dev/study-api/internal/plans"
)

// tierRank resolves the caller's ladder rank: 0 free, then the catalog
// ranks (all purchasable plans rank Premium today).
func (s *Server) tierRank(r *http.Request, uid string) int {
        if !plans.StudentBillingEnabled {
                return plans.TierPremium
        }
        ent, err := s.store.EnsureEntitlement(r.Context(), uid)
        if err != nil {
                // Fail open on infrastructure errors: a billing lookup must
                // never lock a paying student out of a paper mid-sitting.
                return plans.TierPremium
        }
        if !ent.PremiumActive(time.Now().UTC()) {
                return 0
        }
        return plans.RankFor(ent.PremiumType)
}

// bodyScope resolves the caller's body scope: "jamb" bounds the JAMB
// annual plan to JAMB papers; "all" opens every body.
func (s *Server) bodyScope(r *http.Request, uid string) string {
        if !plans.StudentBillingEnabled {
                return plans.ScopeAll
        }
        ent, err := s.store.EnsureEntitlement(r.Context(), uid)
        if err != nil {
                return plans.ScopeAll
        }
        if !ent.PremiumActive(time.Now().UTC()) {
                return ""
        }
        return plans.ScopeFor(ent.PremiumType)
}

// requireStandard refuses anything below the Standard tier (the AI
// features). 402 with an upgrade pointer; the message names the plan
// so the snackbar itself sells the upgrade.
func requireStandard(w http.ResponseWriter, rank int) bool {
        if rank >= plans.TierStandard {
                return true
        }
        fail(w, http.StatusPaymentRequired, "tier_required",
                "The AI features open on Premium (from ₦500 a week). JAMB Annual is ₦5,000 for a whole year and carries WAEC, NECO and Post-UTME too - see Plans.")
        return false
}
