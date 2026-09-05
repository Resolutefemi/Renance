// Career bridge (ROADMAP #18), curated scholarships and course paths
// served like lessons: data/career/{scholarships,paths}.json, loaded and
// validated at boot.
//
// The catalogue is curated by hand, so the boot only checks mechanics:
// unique ids, required fields, https URLs, and the join this feature
// exists for, every path's Topics must be real syllabus topics from ANY
// shipped tree, so "Where can Biology take you?" always links back to
// things the student actually studies. The directory is optional (an
// install with no career data boots fine and serves empty lists) but a
// file that IS present must be fully valid.
package cbtdata

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Scholarship is one curated funding opportunity. Window phrasing is
// deliberately honest ("Typically opens mid-year", never a fabricated
// countdown); URL points at the provider's official domain.
type Scholarship struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Provider    string   `json:"provider"`
	Level       string   `json:"level"` // undergraduate | postgraduate | both
	Coverage    string   `json:"coverage"`
	Window      string   `json:"window"`
	Tags        []string `json:"tags"`
	URL         string   `json:"url"`
	Eligibility string   `json:"eligibility"`
}

// CareerPath is one course destination: the JAMB subject combination,
// the typical competitive aggregate, example universities and the
// syllabus topics that decide admission (the topic-graph reuse).
type CareerPath struct {
	ID           string   `json:"id"`
	Course       string   `json:"course"`
	Field        string   `json:"field"`
	Blurb        string   `json:"blurb"`
	Cutoff       string   `json:"cutoff"`
	Subjects     []string `json:"subjects"`
	Universities []string `json:"universities"`
	Topics       []string `json:"topics"`
}

// careerScholarshipsFile mirrors data/career/scholarships.json.
type careerScholarshipsFile struct {
	Scholarships []Scholarship `json:"scholarships"`
}

// careerPathsFile mirrors data/career/paths.json.
type careerPathsFile struct {
	Paths []CareerPath `json:"paths"`
}

// Career is the GET /career payload: both curated lists.
type Career struct {
	Scholarships []Scholarship `json:"scholarships"`
	Paths        []CareerPath  `json:"paths"`
}

var scholarshipLevels = map[string]struct{}{
	"undergraduate": {},
	"postgraduate":  {},
	"both":          {},
}

// loadCareer reads dataDir/career/*.json. Optional directory, mandatory
// validity, the same rule as lessons and flashcards.
func (l *Library) loadCareer(dataDir string) error {
	dir := filepath.Join(dataDir, "career")

	schPath := filepath.Join(dir, "scholarships.json")
	if raw, err := os.ReadFile(schPath); err == nil {
		if err := scanForAnswerMaterial("career/scholarships.json", raw); err != nil {
			return err
		}
		var f careerScholarshipsFile
		if err := json.Unmarshal(raw, &f); err != nil {
			return fmt.Errorf("cbtdata: parse career/scholarships.json: %w", err)
		}
		seen := map[string]struct{}{}
		for i, s := range f.Scholarships {
			if err := validScholarship(i, s, seen); err != nil {
				return err
			}
			l.scholarships = append(l.scholarships, s)
		}
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("cbtdata: read career/scholarships.json: %w", err)
	}

	pathsPath := filepath.Join(dir, "paths.json")
	if raw, err := os.ReadFile(pathsPath); err == nil {
		if err := scanForAnswerMaterial("career/paths.json", raw); err != nil {
			return err
		}
		var f careerPathsFile
		if err := json.Unmarshal(raw, &f); err != nil {
			return fmt.Errorf("cbtdata: parse career/paths.json: %w", err)
		}
		seen := map[string]struct{}{}
		for i, p := range f.Paths {
			if err := validPath(i, p, seen); err != nil {
				return err
			}
			l.paths = append(l.paths, p)
		}
		if err := l.validateCareerTopics(); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("cbtdata: read career/paths.json: %w", err)
	}
	return nil
}

func validScholarship(i int, s Scholarship, seen map[string]struct{}) error {
	where := fmt.Sprintf("career/scholarships.json entry %d", i+1)
	if s.ID == "" {
		return fmt.Errorf("cbtdata: %s has no id", where)
	}
	if _, dup := seen[s.ID]; dup {
		return fmt.Errorf("cbtdata: %s repeats id %q", where, s.ID)
	}
	seen[s.ID] = struct{}{}
	if strings.TrimSpace(s.Name) == "" || strings.TrimSpace(s.Provider) == "" ||
		strings.TrimSpace(s.Eligibility) == "" || strings.TrimSpace(s.Coverage) == "" {
		return fmt.Errorf("cbtdata: %s (%s) needs name, provider, coverage and eligibility", where, s.ID)
	}
	if _, ok := scholarshipLevels[s.Level]; !ok {
		return fmt.Errorf("cbtdata: %s (%s) level must be undergraduate, postgraduate or both (got %q)",
			where, s.ID, s.Level)
	}
	if strings.TrimSpace(s.Window) == "" {
		return fmt.Errorf("cbtdata: %s (%s) needs an honest window line", where, s.ID)
	}
	if !strings.HasPrefix(s.URL, "https://") {
		return fmt.Errorf("cbtdata: %s (%s) url must be https (got %q)", where, s.ID, s.URL)
	}
	if len(s.Tags) == 0 {
		return fmt.Errorf("cbtdata: %s (%s) needs at least one tag", where, s.ID)
	}
	return nil
}

func validPath(i int, p CareerPath, seen map[string]struct{}) error {
	where := fmt.Sprintf("career/paths.json entry %d", i+1)
	if p.ID == "" {
		return fmt.Errorf("cbtdata: %s has no id", where)
	}
	if _, dup := seen[p.ID]; dup {
		return fmt.Errorf("cbtdata: %s repeats id %q", where, p.ID)
	}
	seen[p.ID] = struct{}{}
	if strings.TrimSpace(p.Course) == "" || strings.TrimSpace(p.Field) == "" ||
		strings.TrimSpace(p.Blurb) == "" || strings.TrimSpace(p.Cutoff) == "" {
		return fmt.Errorf("cbtdata: %s (%s) needs course, field, blurb and cutoff", where, p.ID)
	}
	if len(p.Subjects) < 3 {
		return fmt.Errorf("cbtdata: %s (%s) needs at least three exam subjects", where, p.ID)
	}
	if len(p.Universities) == 0 {
		return fmt.Errorf("cbtdata: %s (%s) needs at least one example university", where, p.ID)
	}
	if len(p.Topics) < 3 {
		return fmt.Errorf("cbtdata: %s (%s) needs at least three syllabus topics", where, p.ID)
	}
	return nil
}

// validateCareerTopics enforces the join: every path topic must be a real
// topic in at least one shipped syllabus tree. This is the whole point of
// the bridge: a course row always links back to things the student studies.
func (l *Library) validateCareerTopics() error {
	known := map[string]struct{}{}
	for _, sy := range l.syllabi {
		for _, sub := range sy.Subjects {
			for _, sec := range sub.Sections {
				for _, t := range sec.Topics {
					known[t] = struct{}{}
				}
			}
		}
	}
	for _, p := range l.paths {
		for _, t := range p.Topics {
			if _, ok := known[t]; !ok {
				return fmt.Errorf("cbtdata: career path %s links unknown topic %q (not in any syllabus tree)", p.ID, t)
			}
		}
	}
	return nil
}

// Career serves the curated lists (order preserved from the files).
func (l *Library) Career() Career {
	return Career{Scholarships: l.scholarships, Paths: l.paths}
}
