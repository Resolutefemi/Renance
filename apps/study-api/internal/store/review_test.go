package store

import (
	"testing"
	"time"
)

func TestQualityFor(t *testing.T) {
	cases := []struct {
		correct, total, want int
	}{
		{0, 0, 0},   // degenerate → blackout
		{10, 10, 5}, // 100% perfect
		{9, 10, 5},  // 90% still perfect recall
		{8, 10, 4},  // 80% good
		{6, 10, 3},  // 60% pass line
		{4, 10, 2},  // 40% fail
		{2, 10, 1},  // 20% faint memory
		{1, 10, 0},  // 10% blackout
		{0, 10, 0},
	}
	for _, c := range cases {
		if got := QualityFor(c.correct, c.total); got != c.want {
			t.Errorf("QualityFor(%d,%d) = %d, want %d", c.correct, c.total, got, c.want)
		}
	}
}

func TestNextSM2NewTopicWalksTheLadder(t *testing.T) {
	fresh := SM2Item{Ease: InitialEase}

	// First pass (q=5): due tomorrow.
	one := NextSM2(fresh, 5)
	if one.IntervalDays != 1 || one.Repetitions != 1 {
		t.Fatalf("first review: %+v, want interval 1 rep 1", one)
	}

	// Second pass (q=5): six days.
	six := NextSM2(one, 5)
	if six.IntervalDays != 6 || six.Repetitions != 2 {
		t.Fatalf("second review: %+v, want interval 6 rep 2", six)
	}

	// Third pass (q=5): prev * new ease = round(6 * 2.6) = 16.
	sixteen := NextSM2(six, 5)
	if sixteen.IntervalDays != 16 || sixteen.Repetitions != 3 {
		t.Fatalf("third review: %+v, want interval 16 rep 3", sixteen)
	}
	if sixteen.Ease <= six.Ease {
		t.Errorf("ease should climb on q=5: %v -> %v", six.Ease, sixteen.Ease)
	}
}

func TestNextSM2LapseResetsAndKeepsCounting(t *testing.T) {
	seasoned := SM2Item{Ease: 2.5, IntervalDays: 24, Repetitions: 4, Lapses: 1}

	// A fail (q=2): back to square one, due tomorrow, lapse counted.
	lapsed := NextSM2(seasoned, 2)
	if lapsed.IntervalDays != 1 || lapsed.Repetitions != 0 || lapsed.Lapses != 2 {
		t.Fatalf("lapse: %+v, want interval 1 rep 0 lapses 2", lapsed)
	}
	if lapsed.Ease >= seasoned.Ease {
		t.Errorf("ease must drop on a lapse: %v -> %v", seasoned.Ease, lapsed.Ease)
	}

	// Relearning pass (q=4): interval restarts the ladder at 1, then 6.
	relearn := NextSM2(lapsed, 4)
	if relearn.Repetitions != 1 || relearn.IntervalDays != 1 {
		t.Fatalf("relearn: %+v, want rep 1 interval 1", relearn)
	}
	if next := NextSM2(relearn, 4); next.IntervalDays != 6 {
		t.Fatalf("relearn 2: %+v, want interval 6", next)
	}
}

func TestNextSM2EaseFloorsAt130(t *testing.T) {
	broken := SM2Item{Ease: 1.3, IntervalDays: 10, Repetitions: 3}
	got := NextSM2(broken, 0) // worst grade on an already-minimum ease
	if got.Ease < MinEase {
		t.Fatalf("ease fell below floor: %v", got.Ease)
	}
	// Even at the floor the interval must keep moving forward.
	if got.IntervalDays <= broken.IntervalDays && got.Repetitions > 0 {
		t.Fatalf("interval stalled at floor: %+v", got)
	}
}

func TestNextSM2IntervalCapsAtAYear(t *testing.T) {
	veteran := SM2Item{Ease: 2.8, IntervalDays: 360, Repetitions: 12}
	got := NextSM2(veteran, 5)
	if got.IntervalDays != MaxInterval {
		t.Fatalf("interval = %d, want cap %d", got.IntervalDays, MaxInterval)
	}
}

func TestNextSM2ClampsAbsurdQualities(t *testing.T) {
	fresh := SM2Item{Ease: InitialEase}
	if got := NextSM2(fresh, 99); got.Repetitions != 1 {
		t.Fatalf("q=99 should behave like a pass: %+v", got)
	}
	if got := NextSM2(fresh, -3); got.Repetitions != 0 || got.Lapses != 1 {
		t.Fatalf("q=-3 should behave like a lapse: %+v", got)
	}
}

func TestReviewItemStatus(t *testing.T) {
	today := time.Date(2026, 9, 4, 15, 0, 0, 0, time.UTC)
	cases := []struct {
		dueOn string
		want  string
	}{
		{"2026-09-01", "overdue"},
		{"2026-09-04", "due"},
		{"2026-09-06", "later"},
	}
	for _, c := range cases {
		it := ReviewItem{DueOn: c.dueOn}
		if got := it.Status(today); got != c.want {
			t.Errorf("Status(%s) = %s, want %s", c.dueOn, got, c.want)
		}
	}
}
