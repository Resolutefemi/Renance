package httpapi

import "testing"

func TestNairaToKobo(t *testing.T) {
	cases := []struct {
		in   string
		want int64
		ok   bool
	}{
		{"15000", 1_500_000, true},
		{"15000.5", 1_500_050, true},
		{"2500.50", 250_050, true},
		{"0", 0, true},
		{"0.99", 99, true},
		{"", 0, false},
		{"-5", 0, false},
		{"abc", 0, false},
		{"1.234", 123, true}, // third fraction digit ignored
		{"12,000", 0, false}, // separators are not accepted
	}
	for _, c := range cases {
		got, ok := nairaToKobo(c.in)
		if ok != c.ok || (ok && got != c.want) {
			t.Errorf("nairaToKobo(%q) = %d, %v; want %d, %v", c.in, got, ok, c.want, c.ok)
		}
	}
}

func TestStripDoubleDashes(t *testing.T) {
	cases := map[string]string{
		"clean":          "clean",
		"one - dash":     "one - dash",
		"double -- dash": "double - dash",
		"run ---- dash":  "run - dash",
	}
	for in, want := range cases {
		if got := stripDoubleDashes(in); got != want {
			t.Errorf("stripDoubleDashes(%q) = %q; want %q", in, got, want)
		}
	}
}
