// Package plans: the subscription catalog. Single source of truth for
// the paywall UIs (web + app), the Paystack initializer, the REN
// redemption table and the webhook grant. Amounts are Naira; kobo is
// what Paystack actually charges (1 Naira = 100 kobo).
package plans

import (
        "time"
)

// Plan is one purchasable student premium tier.
type Plan struct {
        Code         string `json:"code"`
        Label        string `json:"label"`
        AmountNaira  int    `json:"amountNaira"`
        AmountKobo   int    `json:"amountKobo"`
        DurationDays int    `json:"durationDays"`
        // Perks is the one-line pitch the paywall prints under the price.
        Perks string `json:"perks"`
        // Scope bounds which exam bodies the plan runs in full: "jamb"
        // (the JAMB annual plan) or "all" (every exam body).
        Scope string `json:"scope"`
        // Tier is the ladder rank: 1 jamb < 2 basic < 3 standard < 4
        // premium. The AI tutor and the AI generator open at Standard (3).
        Tier int `json:"tier"`
        // Features is the bullet list the paywalls (web + app) render for
        // the tier - the catalog is the single source of truth, the UIs
        // never hardcode the matrix.
        Features []string `json:"features"`
}

// Scope values for Plan.Scope.
const (
        ScopeJamb = "jamb"
        ScopeAll  = "all"
)

// Tier ladder ranks. Rank 0 = free.
const (
        TierJamb     = 1
        TierBasic    = 2
        TierStandard = 3
        TierPremium  = 4
)

// Duration returns the plan length as a time.Duration.
func (p Plan) Duration() time.Duration {
        return time.Duration(p.DurationDays) * 24 * time.Hour
}

// StudentBillingEnabled gates the whole student paywall. FALSE for now
// (founder directive, 2026-09-28): every student - existing and new -
// rides premium for free, the database says so, and nothing nags for a
// card. Flip to true the day billing goes live and the ladder below
// takes over again. School billing is a separate door and is NOT
// touched by this flag.
const StudentBillingEnabled = false

// Student premium tiers (founder pricing, restated 2026-09-28): the
// JAMB annual plan is the candidate's plan - pay once for JAMB and
// WAEC, NECO and Post-UTME ride along. Week, month and quarter are
// short premium bursts. Free tier keeps the 20-question preview, the
// arena, the daily quiz and the leaderboards.
var premium = []Plan{
        {Code: "jamb", Label: "JAMB Annual", AmountNaira: 5000, AmountKobo: 500000, DurationDays: 365,
                Scope: ScopeAll, Tier: TierPremium,
                Perks: "Pay once for JAMB - WAEC, NECO and Post-UTME ride along for a full year.",
                Features: []string{
                        "Every JAMB UTME paper in full - no question cap",
                        "WAEC, NECO and Post-UTME included at no extra cost",
                        "Mocks graded on the official 400 scale",
                        "JAMB syllabus, notes and flashcards",
                        "Arena duels, daily challenge and leaderboards",
                        "12 months straight - the candidate's plan",
                }},
        {Code: "week", Label: "1 Week Premium", AmountNaira: 500, AmountKobo: 50000, DurationDays: 7,
                Scope: ScopeAll, Tier: TierPremium,
                Perks: "A full week of everything - exam week fuel.",
                Features: []string{
                        "Every exam body in full for 7 days",
                        "JAMB, WAEC, NECO and Post-UTME papers uncapped",
                        "Notes, syllabus and flashcards for every subject",
                        "Arena, daily challenge and leaderboards",
                        "The blue tick next to your name on every board",
                }},
        {Code: "month", Label: "1 Month Premium", AmountNaira: 1500, AmountKobo: 150000, DurationDays: 30,
                Scope: ScopeAll, Tier: TierPremium,
                Perks: "Thirty days of everything, cancel anytime.",
                Features: []string{
                        "Every exam body in full for 30 days",
                        "JAMB, WAEC, NECO and Post-UTME papers uncapped",
                        "Notes, syllabus and flashcards for every subject",
                        "Arena, daily challenge and leaderboards",
                        "The blue tick next to your name on every board",
                }},
        {Code: "quarter", Label: "3 Months Premium", AmountNaira: 2500, AmountKobo: 250000, DurationDays: 90,
                Scope: ScopeAll, Tier: TierPremium,
                Perks: "A term of everything - the best value after the annual plan.",
                Features: []string{
                        "Every exam body in full for 90 days",
                        "JAMB, WAEC, NECO and Post-UTME papers uncapped",
                        "Notes, syllabus and flashcards for every subject",
                        "Arena, daily challenge and leaderboards",
                        "The blue tick next to your name on every board",
                }},
}

// RankFor maps a stored premium_type to its ladder rank. Codes that
// predate the tiered catalog (week, month, quarter, year) and every
// console-granted type were sold as full premium: they rank Premium
// with all-bodies scope, so nobody loses access they paid for.
func RankFor(premiumType string) int {
        if premiumType == "" {
                return 0
        }
        if p, ok := PremiumByCode()[premiumType]; ok {
                return p.Tier
        }
        return TierPremium
}

// ScopeFor maps a stored premium_type to its body scope. Unknown and
// legacy types are all-bodies.
func ScopeFor(premiumType string) string {
        if p, ok := PremiumByCode()[premiumType]; ok {
                return p.Scope
        }
        return ScopeAll
}

// PremiumByCode indexes the purchasable tiers.
func PremiumByCode() map[string]Plan {
        m := make(map[string]Plan, len(premium))
        for _, p := range premium {
                m[p.Code] = p
        }
        return m
}

// PremiumList returns the catalog in display order.
func PremiumList() []Plan { return append([]Plan(nil), premium...) }

// Redemption is one REN coin exchange rate: coins for premium days.
type Redemption struct {
        Code         string `json:"code"`
        Label        string `json:"label"`
        Coins        int    `json:"coins"`
        DurationDays int    `json:"durationDays"`
}

// REN redemption (founder pricing): 1 REN per arena win, 3 per referral.
var redemptions = []Redemption{
        {Code: "ren_3d", Label: "3 Days Premium", Coins: 30, DurationDays: 3},
        {Code: "ren_week", Label: "1 Week Premium", Coins: 100, DurationDays: 7},
        {Code: "ren_month", Label: "1 Month Premium", Coins: 250, DurationDays: 30},
}

// RedemptionByCode indexes the redemption table.
func RedemptionByCode() map[string]Redemption {
        m := make(map[string]Redemption, len(redemptions))
        for _, r := range redemptions {
                m[r.Code] = r
        }
        return m
}

// RedemptionList returns the table in display order.
func RedemptionList() []Redemption { return append([]Redemption(nil), redemptions...) }

// ReferralRewardCoins is what a referrer earns per verified signup.
const ReferralRewardCoins = 3

// ArenaWinCoins is what an arena winner earns per duel.
const ArenaWinCoins = 1

// FreePreviewQuestions is the free-tier cap: a free account runs its
// first regular CBT in full, then every paper answers only this many
// questions before the subscribe prompt.
const FreePreviewQuestions = 20

// SchoolTrialDays is the school free-trial length: every feature except
// PDF downloads, no card required.
const SchoolTrialDays = 30
