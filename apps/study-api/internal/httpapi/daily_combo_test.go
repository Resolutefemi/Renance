package httpapi

import "testing"

// The daily subject-combination sprint composes a <body>-custom paper
// from the student's stored combination. These are the pure rules the
// handler and the attempt pipeline both lean on — if they drift, the
// GET /daily code and the POST /attempts code stop matching and every
// combo sprint 409s, so they are pinned here.
func TestDailyCustomCode(t *testing.T) {
	cases := []struct {
		name string
		body string
		in   []string
		want string
		ok   bool
	}{
		{
			name: "jamb combination is sorted and canonical",
			body: "JAMB",
			in:   []string{"Mathematics", "english", "Biology", "chemistry"},
			want: "jamb-custom-biology-chemistry-english-mathematics~n=10.t=15",
			ok:   true,
		},
		{
			name: "waec combination rides the waec shelf",
			body: "WAEC",
			in:   []string{"english", "commerce"},
			want: "waec-custom-commerce-english~n=10.t=15",
			ok:   true,
		},
		{
			name: "neco combination rides the neco shelf",
			body: "NECO",
			in:   []string{"government"},
			want: "neco-custom-government~n=10.t=15",
			ok:   true,
		},
		{name: "university modules has no custom family", body: "University Modules", in: []string{"ams101"}, want: "", ok: false},
		{name: "post-utme has no custom family", body: "POST-UTME", in: []string{"english"}, want: "", ok: false},
		{name: "empty combination falls back", body: "JAMB", in: nil, want: "", ok: false},
		{
			name: "junk slugs are dropped, not fatal",
			body: "JAMB",
			in:   []string{"eng lish!", "", "chemistry"},
			want: "jamb-custom-chemistry~n=10.t=15",
			ok:   true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, ok := dailyCustomCode(tc.body, tc.in)
			if ok != tc.ok {
				t.Fatalf("ok = %v, want %v", ok, tc.ok)
			}
			if got != tc.want {
				t.Fatalf("code = %q, want %q", got, tc.want)
			}
		})
	}
}

func TestDailySubjectsSanitisation(t *testing.T) {
	got := dailySubjects([]string{
		"  English ", "ENGLISH", "math4", "further-mathematics",
		"bad subject!", "", withLEN(45), "civic-education",
	})
	// Duplicates collapse, junk drops, 9-cap applies in stable order.
	want := 4 // english, math4, further-mathematics, civic-education
	if len(got) != want {
		t.Fatalf("subjects = %v (len %d), want %d canonical slugs", got, len(got), want)
	}
	for i := 1; i < len(got); i++ {
		if got[i-1] >= got[i] {
			t.Fatalf("subjects not sorted+deduped: %v", got)
		}
	}
}

func withLEN(n int) string {
	b := make([]byte, n)
	for i := range b {
		b[i] = 'a'
	}
	return string(b)
}
