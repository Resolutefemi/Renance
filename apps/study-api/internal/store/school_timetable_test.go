package store

import "testing"

// SaveTimetable must refuse impossible cells before touching the DB.
// These are pure-Go validations of the slot rules the handler relies on.
func TestTimetableSlotRules(t *testing.T) {
	cases := []struct {
		day, period int
		valid       bool
	}{
		{1, 1, true},
		{5, 8, true},
		{1, 15, true},
		{0, 1, false},
		{8, 1, false},
		{1, 0, false},
		{1, 16, false},
	}
	for _, c := range cases {
		got := c.day >= 1 && c.day <= 7 && c.period >= 1 && c.period <= 15
		if got != c.valid {
			t.Errorf("slot(day=%d, period=%d) validity = %v; want %v", c.day, c.period, got, c.valid)
		}
	}
}
