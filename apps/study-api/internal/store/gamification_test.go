package store

import (
	"testing"
	"time"
)

func TestNextStreak(t *testing.T) {
	today := time.Date(2026, 9, 3, 10, 0, 0, 0, time.UTC)
	yesterday := today.AddDate(0, 0, -1)
	twoDaysAgo := today.AddDate(0, 0, -2)
	// Same calendar day but different clock time must count as "today".
	earlierToday := today.Add(-3 * time.Hour)

	cases := []struct {
		name       string
		current    int
		lastActive time.Time
		want       int
	}{
		{"first ever", 0, time.Time{}, 1},
		{"same day keeps streak", 7, earlierToday, 7},
		{"yesterday increments", 7, yesterday, 8},
		{"gap resets to 1", 7, twoDaysAgo, 1},
		{"long gap resets to 1", 120, today.AddDate(0, 0, -45), 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := NextStreak(tc.current, tc.lastActive, today)
			if got != tc.want {
				t.Fatalf("NextStreak(%d, last=%v) = %d, want %d",
					tc.current, tc.lastActive.Format("2006-01-02"), got, tc.want)
			}
		})
	}
}

func TestLevelFor(t *testing.T) {
	cases := []struct {
		xp   int
		want int
	}{
		{-50, 1}, // negative XP clamps, never below level 1
		{0, 1},
		{499, 1},
		{500, 2},
		{999, 2},
		{1000, 3},
	}
	for _, tc := range cases {
		if got := LevelFor(tc.xp); got != tc.want {
			t.Errorf("LevelFor(%d) = %d, want %d", tc.xp, got, tc.want)
		}
	}
}

func TestBadgesFor(t *testing.T) {
	base := StreakState{Attempts: 0, CurrentStreak: 0}

	got := BadgesFor(base, 0, 0)
	if len(got) != 0 {
		t.Fatalf("zero state earned %v, want none", got)
	}

	// A perfect first paper: 40/40 → first_blood + perfect_paper.
	afterFirst := StreakState{Attempts: 1, CurrentStreak: 1, TotalXP: 400, TotalCorrect: 40}
	got = BadgesFor(afterFirst, 40, 40)
	want := map[string]bool{"first_blood": true, "perfect_paper": true}
	if len(got) != len(want) {
		t.Fatalf("first paper earned %v, want %v", got, want)
	}
	for _, c := range got {
		if !want[c] {
			t.Errorf("unexpected badge %q", c)
		}
	}

	// Century + XP ladder + streak ladder.
	veteran := StreakState{
		Attempts: 12, CurrentStreak: 7, BestStreak: 9,
		TotalXP: 2100, TotalCorrect: 130,
	}
	got = BadgesFor(veteran, 8, 40)
	want = map[string]bool{
		"first_blood": true, "century": true,
		"xp_500": true, "xp_2000": true,
		"streak_3": true, "streak_7": true,
	}
	if len(got) != len(want) {
		t.Fatalf("veteran earned %v, want %v", got, want)
	}
	for _, c := range got {
		if !want[c] {
			t.Errorf("unexpected badge %q", c)
		}
	}

	// Exactly-at-threshold counts (>= semantics).
	edge := StreakState{Attempts: 1, CurrentStreak: 3, TotalXP: 500, TotalCorrect: 50}
	got = BadgesFor(edge, 5, 40)
	for _, c := range []string{"first_blood", "xp_500", "streak_3"} {
		found := false
		for _, g := range got {
			if g == c {
				found = true
			}
		}
		if !found {
			t.Errorf("threshold badge %q missing from %v", c, got)
		}
	}
}

func TestXPPerCorrectEconomy(t *testing.T) {
	// The level curve and badge thresholds assume 10 XP/correct:
	// a perfect 40-question paper = 400 XP (badge xp_500 still out of reach).
	if XPPerCorrect != 10 {
		t.Fatalf("XP economy changed to %d — revisit badge thresholds + tests", XPPerCorrect)
	}
}
