package cbtdata

import (
	"testing"
)

// Boots the REAL committed data dir, the exact call cmd/api makes.
func TestRealDataDirBootsWithCareer(t *testing.T) {
	lib, err := Load("../../../../data")
	if err != nil {
		t.Fatalf("Load(real data): %v", err)
	}
	c := lib.Career()
	if len(c.Scholarships) < 5 {
		t.Fatalf("expected >=5 scholarships, got %d", len(c.Scholarships))
	}
	if len(c.Paths) < 8 {
		t.Fatalf("expected >=8 paths, got %d", len(c.Paths))
	}
	t.Logf("career: %d scholarships, %d paths", len(c.Scholarships), len(c.Paths))
}
