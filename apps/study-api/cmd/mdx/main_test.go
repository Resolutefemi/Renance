package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const goodLesson = `---
slug: osmosis-basics
title: Osmosis Basics
subject: Biology
minutes: 4
summary: Water potential across membranes, in four minutes.
---

## Definition

Osmosis is the movement of water across a
semi-permeable membrane.

> Key point: only water moves; the solute stays.
`

func writeSrc(t *testing.T, files map[string]string) (src, out string) {
	t.Helper()
	base := t.TempDir()
	src = filepath.Join(base, "src")
	out = filepath.Join(base, "out")
	if err := os.MkdirAll(src, 0o755); err != nil {
		t.Fatal(err)
	}
	for name, content := range files {
		if err := os.WriteFile(filepath.Join(src, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return src, out
}

func TestBuildWritesValidBundles(t *testing.T) {
	src, out := writeSrc(t, map[string]string{"osmosis-basics.md": goodLesson})
	code := run([]string{"build", "-src", src, "-out", out}, os.Stdout, os.Stderr)
	if code != 0 {
		t.Fatalf("build exited %d", code)
	}
	raw, err := os.ReadFile(filepath.Join(out, "osmosis-basics.json"))
	if err != nil {
		t.Fatalf("bundle missing: %v", err)
	}
	if !strings.Contains(string(raw), `"contentSha256"`) || !strings.Contains(string(raw), "semi-permeable membrane.") {
		t.Fatalf("bundle content off: %s", raw)
	}
}

func TestCheckFailsOnBrokenSource(t *testing.T) {
	bad := strings.Replace(goodLesson, "minutes: 4", "minutes: 400", 1)
	src, _ := writeSrc(t, map[string]string{"bad.md": bad})
	code := run([]string{"check", "-src", src}, os.Stdout, os.Stderr)
	if code != 1 {
		t.Fatalf("check should exit 1 on minutes=400, got %d", code)
	}
}

func TestBuildPrunesOrphans(t *testing.T) {
	src, out := writeSrc(t, map[string]string{"osmosis-basics.md": goodLesson})
	if code := run([]string{"build", "-src", src, "-out", out}, os.Stdout, os.Stderr); code != 0 {
		t.Fatal("first build failed")
	}
	stale := filepath.Join(out, "retired-lesson.json")
	if err := os.WriteFile(stale, []byte(`{"slug":"retired-lesson"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if code := run([]string{"build", "-src", src, "-out", out}, os.Stdout, os.Stderr); code != 0 {
		t.Fatal("second build failed")
	}
	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Fatal("orphan bundle should have been pruned")
	}
}

func TestDuplicateSlugsRefused(t *testing.T) {
	second := strings.Replace(goodLesson, "title: Osmosis Basics", "title: Osmosis Basics II", 1)
	src, _ := writeSrc(t, map[string]string{
		"a-osmosis-basics.md": goodLesson,
		"b-osmosis-basics.md": second,
	})
	code := run([]string{"check", "-src", src}, os.Stdout, os.Stderr)
	if code != 1 {
		t.Fatalf("duplicate slug should fail check, got %d", code)
	}
}

func TestUnknownCommand(t *testing.T) {
	if code := run([]string{"nonsense"}, os.Stdout, os.Stderr); code != 2 {
		t.Fatalf("unknown command should exit 2, got %d", code)
	}
}
