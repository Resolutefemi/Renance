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
}

// Duration returns the plan length as a time.Duration.
func (p Plan) Duration() time.Duration {
	return time.Duration(p.DurationDays) * 24 * time.Hour
}

// Student premium tiers (founder pricing): a year of JAMB premium is
// 5,000 Naira and unlocks WAEC, NECO and Post-UTME with it - one key,
// every exam body. Free tier stays on 20-question previews, the arena,
// the daily quiz and the leaderboards.
var premium = []Plan{
	{Code: "week", Label: "1 Week Premium", AmountNaira: 500, AmountKobo: 50000, DurationDays: 7,
		Perks: "Full papers for 7 days: JAMB, WAEC, NECO and Post-UTME, no question cap."},
	{Code: "month", Label: "1 Month Premium", AmountNaira: 1500, AmountKobo: 150000, DurationDays: 30,
		Perks: "Full papers for 30 days: JAMB, WAEC, NECO and Post-UTME, no question cap."},
	{Code: "quarter", Label: "3 Months Premium", AmountNaira: 2500, AmountKobo: 250000, DurationDays: 90,
		Perks: "Full papers for 90 days: JAMB, WAEC, NECO and Post-UTME, no question cap."},
	{Code: "year", Label: "1 Year Premium", AmountNaira: 5000, AmountKobo: 500000, DurationDays: 365,
		Perks: "The full year: JAMB, WAEC, NECO and Post-UTME, no question cap, best value."},
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
