// Package learn is Supreme's gamified learn module merged into Renance
// (founder directive 2026-10-14). economy.go ports Supreme's
// lib/supreme/economy.ts + learner.ts one-to-one: the constants, the
// Africa/Lagos time keys, lazy heart regen, streak math with freezes,
// the deterministic league rivals and the quest catalogue. Identity is
// NOT the anonymous cookie anymore - every call carries the real
// study.users id from the JWT.
package learn

import (
        "crypto/rand"
        "fmt"
        "time"
)

// Timezone authority: everything calendar-shaped (streaks, weekly
// leagues, quests, daily goals) is decided in Africa/Lagos, exactly
// like Supreme and the mobile app.
var lagos = func() *time.Location {
        loc, err := time.LoadLocation("Africa/Lagos")
        if err != nil {
                return time.FixedZone("WAT", 3600)
        }
        return loc
}()

// ─── Economy constants (parity with Supreme types.ts) ─────────────────────

const (
        XPPerCorrect            = 10
        PerfectBonusXP          = 5
        PracticeXPPerCorrect    = 2
        ComboTarget             = 3
        ComboBonusXP            = 2
        MaxHearts               = 5
        HeartRegenMinutes       = 45
        HeartRefillPrice        = 350
        FreezePrice             = 200
        BoostPrice              = 100
        BoostMinutes            = 15
        MaxFreezes              = 2
        SuperTrialDays          = 7
        FirstClearGems          = 3
        RepeatClearGems         = 1
        PerfectGemsBonus        = 2
        PromoteCut              = 7  // top 7 of the weekly board promote
        DemoteFrom              = 26 // ranks 26+ demote
        LeaguePromotionGems     = 50
        RowsPerLeague           = 31
        LessonQuizTarget        = 20 // founder: questions attempted after learning, up to 20
        MinPassScore            = 60 // percent needed to bank a topic
        UnlimitedHeartsDefault  = true
)

// Leagues: 10 tiers, Bronze → Diamond (Supreme economy.ts LEAGUES).
var Leagues = []string{
        "Bronze", "Copper", "Silver", "Gold", "Sapphire",
        "Ruby", "Emerald", "Amethyst", "Pearl", "Diamond",
}

// DailyQuest / WeeklyQuest / MonthlyQuest mirror the Supreme quest
// definitions: deterministic per period, gem rewards, live progress.
type QuestDef struct {
        Key      string `json:"key"`
        Title    string `json:"title"`
        Target   int    `json:"target"`
        Gems     int    `json:"gems"`
        Kind     string `json:"kind"` // xp | lessons | correct | perfect | practice | combo
        Icon     string `json:"icon"`
        Period   string `json:"period"` // daily | weekly | monthly
        Progress int    `json:"-"`      // filled at serve time
        Claimed  bool   `json:"-"`
        Complete bool   `json:"-"`
}

var dailyQuestPool = []QuestDef{
        {Key: "daily_xp_30", Title: "Earn 30 XP", Target: 30, Gems: 15, Kind: "xp", Icon: "bolt", Period: "daily"},
        {Key: "daily_xp_50", Title: "Earn 50 XP", Target: 50, Gems: 25, Kind: "xp", Icon: "bolt", Period: "daily"},
        {Key: "daily_lessons_2", Title: "Complete 2 topics", Target: 2, Gems: 15, Kind: "lessons", Icon: "menu_book", Period: "daily"},
        {Key: "daily_correct_10", Title: "Answer 10 questions correctly", Target: 10, Gems: 15, Kind: "correct", Icon: "check_circle", Period: "daily"},
        {Key: "daily_perfect_1", Title: "Score 100% on a topic", Target: 1, Gems: 20, Kind: "perfect", Icon: "star", Period: "daily"},
        {Key: "daily_practice_1", Title: "Practice your mistakes", Target: 1, Gems: 15, Kind: "practice", Icon: "fitness_center", Period: "daily"},
        {Key: "daily_combo_3", Title: "Get a 3 answer combo", Target: 3, Gems: 10, Kind: "combo", Icon: "local_fire_department", Period: "daily"},
}

var weeklyQuest = QuestDef{Key: "weekly_xp_250", Title: "Earn 250 XP this week", Target: 250, Gems: 100, Kind: "xp", Icon: "calendar_month", Period: "weekly"}
var monthlyQuest = QuestDef{Key: "monthly_xp_1000", Title: "Earn 1000 XP this month", Target: 1000, Gems: 400, Kind: "xp", Icon: "event", Period: "monthly"}

// DailyQuestsFor picks 3 of the 7 daily templates deterministically per
// Lagos day (same set for every learner, like Duolingo's global dailies).
func DailyQuestsFor(day time.Time) []QuestDef {
        seed := hashStr(dayKey(day))
        pick := map[int]bool{}
        rng := mulberry32(seed)
        for len(pick) < 3 {
                pick[int(rng())%len(dailyQuestPool)] = true
        }
        out := make([]QuestDef, 0, 3)
        for i := range dailyQuestPool {
                if pick[i] {
                        q := dailyQuestPool[i]
                        out = append(out, q)
                }
        }
        return out
}

// ChestReward: deterministic 10-30 gems per unit chest keyed
// courseId#unitIndex (Supreme chestReward).
func ChestReward(chestKey string) int {
        return 10 + 5*int(hashStr(chestKey)%5)
}

// ─── Time keys (Lagos) ────────────────────────────────────────────────────

func dayKey(t time.Time) string { return t.In(lagos).Format("2006-01-02") }

func weekKey(t time.Time) string {
        // ISO week anchored on Lagos Mondays, e.g. 2026-W42.
        year, week := t.In(lagos).ISOWeek()
        return fmt.Sprintf("%04d-W%02d", year, week)
}

func monthKey(t time.Time) string { return t.In(lagos).Format("2006-01") }

// LagosToday is the calendar day the whole streak/quest engine agrees on.
func LagosToday() string { return dayKey(time.Now()) }

// WeekEndsIn: countdown anchor for the league UI.
func WeekEndsIn() time.Time {
        now := time.Now().In(lagos)
        weekday := int(now.Weekday()) // Sun=0..Sat=6
        if weekday == 0 {
                weekday = 7
        }
        nextMonday := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, lagos).
                AddDate(0, 0, 8-weekday)
        return nextMonday
}

// MissedDaysBetween counts calendar days the learner was fully absent.
func MissedDaysBetween(lastActive string, now time.Time) int {
        if lastActive == "" {
                return 0
        }
        last, err := time.ParseInLocation("2006-01-02", lastActive, lagos)
        if err != nil {
                return 0
        }
        today := time.Date(now.In(lagos).Year(), now.In(lagos).Month(), now.In(lagos).Day(), 0, 0, 0, 0, lagos)
        return int(today.Sub(last).Hours() / 24)
}

// ─── Hearts (lazy regen, never a timer) ───────────────────────────────────

type HeartState struct {
        Hearts         int `json:"hearts"`
        NextHeartInMs  *int64 `json:"nextHeartInMs"`
        Unlimited      bool   `json:"unlimited"`
}

// RegenHearts applies the 45-minute regen lazily. superActive (and the
// founder's launch flag: EVERYONE) reads as unlimited.
func RegenHearts(current int, updatedAt time.Time, superActive, unlimited bool) HeartState {
        if superActive || unlimited {
                return HeartState{Hearts: MaxHearts, NextHeartInMs: nil, Unlimited: true}
        }
        if current >= MaxHearts {
                return HeartState{Hearts: MaxHearts}
        }
        elapsed := time.Since(updatedAt)
        gained := int(elapsed / (HeartRegenMinutes * time.Minute))
        hearts := current + gained
        if hearts >= MaxHearts {
                return HeartState{Hearts: MaxHearts}
        }
        ms := int64((HeartRegenMinutes*time.Minute - elapsed%(HeartRegenMinutes*time.Minute)) / time.Millisecond)
        return HeartState{Hearts: hearts, NextHeartInMs: &ms}
}

// ─── Streaks (computeStreak/touchStreak parity) ───────────────────────────

type StreakResult struct {
        Count       int
        ConsumedOne bool // a freeze was spent to save the streak
        Reset       bool
}

// ComputeStreak is pure: active today → unchanged; yesterday → +1; a
// small gap consumes owned freezes (max 2) to bridge; otherwise reset.
func ComputeStreak(current int, lastActiveOn string, freezeStock int, now time.Time) StreakResult {
        today := dayKey(now)
        if lastActiveOn == today {
                return StreakResult{Count: current}
        }
        missed := MissedDaysBetween(lastActiveOn, now)
        switch {
        case missed == 0:
                // lastActive was today already handled above; defensive
                return StreakResult{Count: current}
        case missed == 1:
                return StreakResult{Count: current + 1}
        case missed == 2 && freezeStock >= 1:
                return StreakResult{Count: current + 1, ConsumedOne: true}
        case missed == 3 && freezeStock >= 2:
                return StreakResult{Count: current + 1, ConsumedOne: true}
        default:
                return StreakResult{Count: 1, Reset: true}
        }
}

// ─── Deterministic rivals (FNV-1a + mulberry32, Supreme parity) ──────────

var rivalNames = []string{
        "Adaeze", "Tunde", "Chiamaka", "Ibrahim", "Ngozi", "Emeka", "Fatima",
        "Kelechi", "Aisha", "Oluwaseun", "Blessing", "Yusuf", "Chinedu",
        "Halima", "Femi", "Zainab", "Obinna", "Amaka", "Musa", "Temi",
        "Ifeoma", "Bashir", "Ejiro", "Kemi", "Nonso", "Rukayat", "Uche",
        "Khadija", "Tobi",
}

var avatarColors = []string{
        "#58cc02", "#1cb0f6", "#ffc800", "#ff9600", "#ff4b4b",
        "#ce82ff", "#2b70c9", "#00cd9c",
}

func hashStr(s string) uint32 {
        h := uint32(2166136261)
        for i := 0; i < len(s); i++ {
                h ^= uint32(s[i])
                h *= 16777619
        }
        return h
}

func mulberry32(seed uint32) func() uint32 {
        a := seed
        return func() uint32 {
                a |= 0
                a = a + 0x6D2B79F5
                t := a
                t = (t ^ (t >> 15)) * (t | 1)
                t = (t ^ (t + 0x61D8832B)) ^ (t ^ (t >> 7))
                return t * (t ^ (t >> 14))
        }
}

// Rival is one synthetic row of the weekly league board.
type Rival struct {
        Name   string `json:"name"`
        XP     int    `json:"xp"`
        Color  string `json:"color"`
        IsYou  bool   `json:"isYou"`
}

// RivalsFor builds the 30 synthetic opponents for a league-week. Higher
// leagues farm more XP (base scales with tier, Supreme parity).
func RivalsFor(week string, leagueIndex int, progress float64) []Rival {
        seed := hashStr(week + "|" + Leagues[clamp(leagueIndex, 0, len(Leagues)-1)])
        rng := mulberry32(seed)
        base := 60 + leagueIndex*90
        p := progress
        if p <= 0 {
                p = 0.05
        }
        if p > 1 {
                p = 1
        }
        out := make([]Rival, 0, RowsPerLeague-1)
        for i := 0; i < RowsPerLeague-1; i++ {
                // Pace the board across the week: some rivals ahead, some behind.
                skew := 0.35 + 1.3*(float64(rng())/float64(^uint32(0)))
                xp := int(float64(base) * p * skew)
                if xp < 0 {
                        xp = 0
                }
                out = append(out, Rival{
                        Name:  rivalNames[int(rng())%len(rivalNames)],
                        XP:    xp,
                        Color: avatarColors[int(rng())%len(avatarColors)],
                })
        }
        return out
}

func clamp(v, lo, hi int) int {
        if v < lo {
                return lo
        }
        if v > hi {
                return hi
        }
        return v
}

// RandomToken is a cryptographically random hex string (chest keys,
// idempotency echoes).
func RandomToken(n int) string {
        b := make([]byte, n)
        _, _ = rand.Read(b)
        return fmt.Sprintf("%x", b)
}
