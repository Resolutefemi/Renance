package main

// The syllabus bridge for lint: qbuild runs from arbitrary working
// directories, so the tree is discovered by walking up from the working
// directory to the nearest <root>/data/syllabus/<slug>.json — the same
// layout instinct as cbtdata.FindDataDir. This keeps `qbuild check`
// behaving identically from apps/study-api, cmd/qbuild (go test CWD), or
// a bare checkout.

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"renance.dev/study-api/internal/cbtdata"
)

// syllabusTopicsFor returns the topic set of body's syllabus tree, or nil
// when no tree is shipped for that body (lint then skips the join rule —
// the boot-time loader still refuses unknown topics once a tree exists).
func syllabusTopicsFor(body string) map[string]struct{} {
	if body == "" {
		return nil
	}
	name := filepath.Join("syllabus", cbtdata.Slug(body)+".json")
	dir, err := os.Getwd()
	if err != nil {
		return nil
	}
	for i := 0; i < 6; i++ {
		raw, err := os.ReadFile(filepath.Join(dir, "data", name))
		if err == nil {
			var sy cbtdata.Syllabus
			if err := json.Unmarshal(raw, &sy); err != nil {
				fmt.Fprintf(os.Stderr, "qbuild: syllabus %s is not valid JSON: %v\n", name, err)
				return nil
			}
			return sy.TopicSet()
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return nil
}
