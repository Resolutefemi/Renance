package httpapi

import (
	"testing"
	"time"
)

func TestDailyDayParam(t *testing.T) {
	// Empty means "today" — the caller substitutes; valid per contract.
	if _, ok := dailyDayParam(""); !ok {
		t.Fatal("empty day must parse (caller substitutes today)")
	}
	for _, bad := range []string{"not-a-day", "2026-9-7", "07-09-2026", "2026-13-01", "2026-09-07T00:00:00Z"} {
		if _, ok := dailyDayParam(bad); ok {
			t.Fatalf("dailyDayParam(%q) should reject", bad)
		}
	}
	got, ok := dailyDayParam("2026-09-07")
	if !ok || got != "2026-09-07" {
		t.Fatalf("dailyDayParam(2026-09-07) = %q, %v", got, ok)
	}
}

func TestDailyDayString(t *testing.T) {
	if s := dailyDayString(nil); s != "" {
		t.Fatalf("nil daily marker must render empty, got %q", s)
	}
	day, _ := time.Parse("2006-01-02", "2026-09-07")
	if s := dailyDayString(&day); s != "2026-09-07" {
		t.Fatalf("daily marker rendered as %q", s)
	}
}

func TestTodayUTCShape(t *testing.T) {
	day := todayUTC()
	if len(day) != 10 || day[4] != '-' || day[7] != '-' {
		t.Fatalf("todayUTC is not YYYY-MM-DD: %q", day)
	}
}
