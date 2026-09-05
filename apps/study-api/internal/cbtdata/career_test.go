package cbtdata

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const careerSyllabus = `{
  "body": "JAMB",
  "subjects": [
    {"subject": "Biology", "sections": [
      {"title": "Cell Biology", "topics": ["Cell Biology", "Genetics", "Ecology"]},
      {"title": "Physiology", "topics": ["Respiration", "Transport"]}
    ]}
  ]
}`

const validScholarships = `{
  "scholarships": [
    {
      "id": "nnpc-chevron-university",
      "name": "NNPC/Chevron JV National University Scholarship",
      "provider": "NNPC/Chevron Joint Venture",
      "level": "undergraduate",
      "coverage": "Full tuition + annual allowance",
      "window": "Typically opens mid-year",
      "tags": ["STEM"],
      "url": "https://www.nnpcgroup.com",
      "eligibility": "200-level STEM undergraduates."
    }
  ]
}`

const validPaths = `{
  "paths": [
    {
      "id": "medicine-surgery",
      "course": "Medicine & Surgery",
      "field": "Health",
      "blurb": "The strictest cut-off in Nigeria.",
      "cutoff": "280+",
      "subjects": ["English", "Biology", "Chemistry", "Physics"],
      "universities": ["UNILAG", "UI"],
      "topics": ["Cell Biology", "Genetics", "Respiration"]
    }
  ]
}`

func writeCareerDataDir(t *testing.T, scholarshipsJSON, pathsJSON, syllabusJSON string) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "manifest.json"),
		[]byte(`{"generatedAt":"t","version":"t","exams":[]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if syllabusJSON != "" {
		if err := os.MkdirAll(filepath.Join(dir, "syllabus"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "syllabus", "jamb.json"),
			[]byte(syllabusJSON), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if scholarshipsJSON != "" {
		if err := os.MkdirAll(filepath.Join(dir, "career"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "career", "scholarships.json"),
			[]byte(scholarshipsJSON), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if pathsJSON != "" {
		if err := os.MkdirAll(filepath.Join(dir, "career"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "career", "paths.json"),
			[]byte(pathsJSON), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func TestLoadCareerHappyPath(t *testing.T) {
	lib, err := Load(writeCareerDataDir(t, validScholarships, validPaths, careerSyllabus))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	career := lib.Career()
	if len(career.Scholarships) != 1 || career.Scholarships[0].ID != "nnpc-chevron-university" {
		t.Fatalf("scholarships = %+v", career.Scholarships)
	}
	if len(career.Paths) != 1 || career.Paths[0].Course != "Medicine & Surgery" {
		t.Fatalf("paths = %+v", career.Paths)
	}
	if career.Paths[0].Cutoff != "280+" || len(career.Paths[0].Topics) != 3 {
		t.Fatalf("path = %+v", career.Paths[0])
	}
}

func TestLoadCareerOptionalBoots(t *testing.T) {
	lib, err := Load(writeCareerDataDir(t, "", "", careerSyllabus))
	if err != nil {
		t.Fatalf("Load without career dir: %v", err)
	}
	career := lib.Career()
	if len(career.Scholarships) != 0 || len(career.Paths) != 0 {
		t.Fatalf("expected empty career, got %+v", career)
	}
}

func TestLoadCareerRefusesUnknownTopic(t *testing.T) {
	bad := strings.Replace(validPaths, "Cell Biology", "Quantum Teleportation", 1)
	_, err := Load(writeCareerDataDir(t, validScholarships, bad, careerSyllabus))
	if err == nil || !strings.Contains(err.Error(), "unknown topic") {
		t.Fatalf("want unknown topic error, got %v", err)
	}
}

const scholarshipDupIDs = `{
  "scholarships": [
    {
      "id": "same-id",
      "name": "First Entry",
      "provider": "Provider One",
      "level": "undergraduate",
      "coverage": "Full tuition",
      "window": "Typically opens mid-year",
      "tags": ["STEM"],
      "url": "https://www.nnpcgroup.com",
      "eligibility": "First entry."
    },
    {
      "id": "same-id",
      "name": "Second Entry",
      "provider": "Provider Two",
      "level": "undergraduate",
      "coverage": "Full tuition",
      "window": "Typically opens mid-year",
      "tags": ["STEM"],
      "url": "https://www.nnpcgroup.com/2",
      "eligibility": "Second entry reusing the first id."
    }
  ]
}`

func TestLoadCareerRefusesBadEntries(t *testing.T) {
	cases := map[string]string{
		"repeated id": scholarshipDupIDs,
		"http url": strings.Replace(validScholarships,
			`https://www.nnpcgroup.com`, `http://www.nnpcgroup.com`, 1),
		"bad level": strings.Replace(validScholarships,
			`"level": "undergraduate"`, `"level": "sometimes"`, 1),
	}
	for name, json := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := Load(writeCareerDataDir(t, json, "", careerSyllabus))
			if err == nil {
				t.Fatalf("expected Load to refuse %s", name)
			}
		})
	}
}
