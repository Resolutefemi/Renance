package learn

import (
        "testing"
        "time"
)

// ComputeStreak carries the founder's streak rules (directive
// 2026-10-17): a streak grows only on quiz/lesson activity; ONE quiet
// day keeps it alive (it dies on the SECOND); freezes bridge 2-3 day
// gaps; a 7+ day streak without freeze cover is FORGIVEN free, at most
// three times ever; anything wider resets to 1. The rule is pure, so
// the whole matrix is pinned here without a database.
func TestComputeStreakForgivenessRules(t *testing.T) {
        // 2026-10-17 is a Saturday; LagosToday keys come from dayKey(now)
        // and MissedDaysBetween parses "2006-01-02" in Africa/Lagos, so the
        // probe times are built the same way (noon, Lagos) to stay clear of
        // any midnight edge.
        now := time.Date(2026, 10, 17, 12, 0, 0, 0, lagos)
        day := func(offset int) string {
                return time.Date(2026, 10, 17, 12, 0, 0, 0, lagos).
                        AddDate(0, 0, -offset).Format("2006-01-02")
        }

        cases := []struct {
                name          string
                current       int
                lastActive    string
                freezes       int
                forgivenUsed  int
                wantCount     int
                wantFreezes   int
                wantForgiven  bool
                wantReset     bool
        }{
                {"fresh learner first activity", 0, "", 0, 0, 1, 0, false, false},
                {"active today unchanged", 5, day(0), 0, 0, 5, 0, false, false},
                {"one quiet day keeps streak alive", 5, day(1), 0, 0, 6, 0, false, false},
                {"two quiet days need a freeze", 5, day(2), 0, 0, 1, 0, false, true},
                {"two quiet days bridged by a freeze", 5, day(2), 1, 0, 6, 1, false, false},
                {"three quiet days need two freezes", 5, day(3), 2, 0, 6, 2, false, false},
                {"three quiet days one freeze not enough", 5, day(3), 1, 0, 1, 0, false, true},
                {"7-day streak forgiven on a freezeless 2-day gap", 7, day(2), 0, 0, 8, 0, true, false},
                {"6-day streak is not forgivingable", 6, day(2), 0, 0, 1, 0, false, true},
                {"forgiveness pool exhausted", 30, day(2), 0, 3, 1, 0, false, true},
                {"second forgiveness still available", 30, day(3), 0, 1, 31, 0, true, false},
                {"four quiet days reset even with forgiveness left", 30, day(4), 0, 0, 1, 0, false, true},
                {"four quiet days reset even with freezes", 30, day(4), 2, 0, 1, 0, false, true},
        }

        for _, tc := range cases {
                t.Run(tc.name, func(t *testing.T) {
                        got := ComputeStreak(tc.current, tc.lastActive, tc.freezes, tc.forgivenUsed, now)
                        if got.Count != tc.wantCount {
                                t.Errorf("Count = %d, want %d", got.Count, tc.wantCount)
                        }
                        if got.FreezesUsed != tc.wantFreezes {
                                t.Errorf("FreezesUsed = %d, want %d", got.FreezesUsed, tc.wantFreezes)
                        }
                        if got.Forgiven != tc.wantForgiven {
                                t.Errorf("Forgiven = %v, want %v", got.Forgiven, tc.wantForgiven)
                        }
                        if got.Reset != tc.wantReset {
                                t.Errorf("Reset = %v, want %v", got.Reset, tc.wantReset)
                        }
                })
        }
}

// A 3-day gap must burn TWO freezes - the old bool flag decremented
// only one, silently leaking a free bridge day.
func TestComputeStreakThreeDayGapBurnsTwoFreezes(t *testing.T) {
        now := time.Date(2026, 10, 17, 12, 0, 0, 0, lagos)
        last := time.Date(2026, 10, 14, 12, 0, 0, 0, lagos).Format("2006-01-02")
        got := ComputeStreak(10, last, 2, 0, now)
        if got.Count != 11 || got.FreezesUsed != 2 {
                t.Fatalf("streak 10, 3 quiet days, 2 freezes: got %+v, want Count 11 FreezesUsed 2", got)
        }
}

func TestDisplayStreakDecayOnRead(t *testing.T) {
        // The founder bug 2026-10-17: the stored streak_count only moves on
        // activity, so a learner away from the app kept seeing the old flame
        // forever. DisplayStreak is the read-path rule - same bridges as
        // ComputeStreak, minus the side effects.
        now := time.Date(2026, 10, 17, 12, 0, 0, 0, lagos)
        day := func(offset int) string {
                return time.Date(2026, 10, 17, 12, 0, 0, 0, lagos).
                        AddDate(0, 0, -offset).Format("2006-01-02")
        }

        cases := []struct {
                name          string
                current       int
                lastActive    string
                freezeStock   int
                forgivenCount int
                want          int
        }{
                {"active today keeps the flame", 12, day(0), 0, 0, 12},
                {"one quiet day - window still open", 12, day(1), 0, 0, 12},
                {"second quiet day kills a young streak", 5, day(2), 0, 0, 0},
                {"second quiet day - a 7+ streak shows as forgivable", 12, day(2), 0, 0, 12},
                {"second quiet day with a freeze survives", 12, day(2), 1, 0, 12},
                {"third quiet day with one freeze but a young streak falls", 6, day(3), 1, 0, 0},
                {"third quiet day with two freezes survives", 12, day(3), 2, 0, 12},
                {"a 7+ streak is forgiven inside the window", 9, day(3), 0, 0, 9},
                {"forgiveness is capped at three uses", 9, day(3), 0, 3, 0},
                {"a young streak gets no forgiveness", 6, day(2), 0, 0, 0},
                {"four quiet days is past every bridge", 30, day(4), 0, 0, 0},
                {"zero streak stays zero", 0, day(0), 0, 0, 0},
        }
        for _, tc := range cases {
                if got := DisplayStreak(tc.current, tc.lastActive, tc.freezeStock, tc.forgivenCount, now); got != tc.want {
                        t.Errorf("%s: DisplayStreak(%d, %s, %d, %d) = %d, want %d",
                                tc.name, tc.current, tc.lastActive, tc.freezeStock, tc.forgivenCount, got, tc.want)
                }
        }
}
