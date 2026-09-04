package store

import "testing"

func TestNextCardBox(t *testing.T) {
	cases := []struct {
		name  string
		box   int
		grade string
		want  int
	}{
		{"again resets to 1", 4, "again", 1},
		{"hard holds box", 3, "hard", 3},
		{"good climbs", 3, "good", 4},
		{"good caps at 5", 5, "good", 5},
		{"hard never drops", 1, "hard", 1},
		{"again from box 1 stays 1", 1, "again", 1},
		{"new card good → 2", 1, "good", 2},
		{"unknown grade holds", 2, "meh", 2},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := NextCardBox(tc.box, tc.grade); got != tc.want {
				t.Fatalf("NextCardBox(%d,%q) = %d, want %d", tc.box, tc.grade, got, tc.want)
			}
		})
	}
}

func TestCardIntervalDays(t *testing.T) {
	cases := map[int]int{1: 0, 2: 1, 3: 2, 4: 4, 5: 7}
	for box, want := range cases {
		if got := CardIntervalDays(box); got != want {
			t.Fatalf("CardIntervalDays(%d) = %d, want %d", box, got, want)
		}
	}
	// clamped edges
	if got := CardIntervalDays(0); got != 0 {
		t.Fatalf("box 0 clamps to 1 → 0d, got %d", got)
	}
	if got := CardIntervalDays(9); got != 7 {
		t.Fatalf("box 9 clamps to 5 → 7d, got %d", got)
	}
}

// The Leitner walk a student actually experiences: pass a card four
// times and it matures to a 7-day gap; one "again" sends it back to day 0.
func TestCardWalk(t *testing.T) {
	box := 1
	want := []int{2, 3, 4, 5}
	for i, exp := range want {
		box = NextCardBox(box, "good")
		if box != exp {
			t.Fatalf("step %d: box = %d, want %d", i, box, exp)
		}
	}
	if CardIntervalDays(box) != 7 {
		t.Fatalf("mature box should sit 7 days out")
	}
	box = NextCardBox(box, "again")
	if box != 1 || CardIntervalDays(box) != 0 {
		t.Fatalf("lapse should return the card to box 1 / due now, got box %d", box)
	}
}
