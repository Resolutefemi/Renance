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

// Student premium tiers (founder pricing, Sept 2026): the JAMB annual
// plan carries a full year of UTME prep for ₦5,000; Basic, Standard
// and Premium are the monthly ladder - Basic opens every exam body's
// papers, Standard adds the AI tutor and the AI generator, Premium
// adds the concierge. Free tier stays on 20-question previews, the
// arena, the daily quiz and the leaderboards.
var premium = []Plan{
        {Code: "jamb", Label: "JAMB", AmountNaira: 5000, AmountKobo: 500000, DurationDays: 365,
                Scope: ScopeJamb, Tier: TierJamb,
                Perks: "A full year of JAMB prep for less than two months of Basic.",
                Features: []string{
                        "Every JAMB UTME paper in full - no question cap",
                        "Mocks graded on the official 400 scale",
                        "JAMB syllabus, notes and flashcards",
                        "Arena duels, daily challenge and leaderboards",
                        "12 months straight - the candidate's plan",
                }},
        {Code: "basic", Label: "Basic", AmountNaira: 3000, AmountKobo: 300000, DurationDays: 30,
                Scope: ScopeAll, Tier: TierBasic,
                Perks: "Every exam body in full, month to month.",
                Features: []string{
                        "JAMB, WAEC, NECO and Post-UTME papers in full",
                        "Notes, syllabus and flashcards for every subject",
                        "The official score slip and pacing forensics",
                        "Arena, daily challenge and leaderboards",
                        "Month to month - cancel anytime",
                }},
        {Code: "standard", Label: "Standard", AmountNaira: 6000, AmountKobo: 600000, DurationDays: 30,
                Scope: ScopeAll, Tier: TierStandard,
                Perks: "Basic plus the AI tutor and the AI generator.",
                Features: []string{
                        "Everything in Basic, all exam bodies in full",
                        "The AI tutor on every question you miss",
                        "The AI generator - any topic, any difficulty",
                        "AI chat that explains and drills your weak spots",
                        "A study plan tuned to your weakest topics",
                        "The blue tick next to your name on every board",
                }},
        {Code: "premium", Label: "Premium", AmountNaira: 20000, AmountKobo: 2000000, DurationDays: 30,
                Scope: ScopeAll, Tier: TierPremium,
                Perks: "Everything, plus the founder's concierge.",
                Features: []string{
                        "Everything in Standard",
                        "Priority WhatsApp support straight to the founder",
                        "Early access to every new feature first",
                        "A premium frame on your profile and the boards",
                        "For the families and the daily grinders",
                        "Your subscription keeps Renance free for others",
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
