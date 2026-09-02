package main

// Command implementations: check / build / manifest.

import (
	"fmt"
	"os"
	"path/filepath"

	"renance.dev/study-api/internal/cbtdata"
)

// printIssues renders a lint report; returns true if any error-level issue.
func printIssues(src string, iss []Issue) bool {
	failed := false
	for _, i := range iss {
		marker := "warn"
		if i.Level == "error" {
			marker = "ERROR"
			failed = true
		}
		fmt.Printf("  %s %s: %s\n", marker, i.Where, i.Msg)
	}
	return failed
}

func cmdCheck(o buildOpts) int {
	if len(o.Inputs) == 0 {
		fmt.Fprintln(os.Stderr, "qbuild check: nothing to check (use -i file.yaml)")
		return 2
	}
	meta := packMeta{
		Code: o.Code, Title: o.Title, Category: o.Category, Body: o.Body,
		Duration: o.Duration,
	}
	failed := false
	for _, src := range o.Inputs {
		fmt.Printf("%s:\n", src)
		spec, issues, err := parseSource(src, meta)
		if err != nil {
			fmt.Printf("  ERROR parse: %v\n", err)
			failed = true
			continue
		}
		if printIssues(src, issues) {
			failed = true
		}
		// Full lint (including warnings from the rule set).
		if printIssues(src, lintSpec(spec)) {
			failed = true
		}
	}
	if failed {
		fmt.Println("check: FAILED")
		return 1
	}
	fmt.Println("check: all sources OK")
	return 0
}

type buildOpts struct {
	Inputs                      []string
	Outdir, Keysub, Version     string
	Code, Title, Category, Body string
	Duration                    int
}

func cmdBuild(o buildOpts) int {
	if len(o.Inputs) == 0 {
		fmt.Fprintln(os.Stderr, "qbuild build: no source (use -i file.yaml)")
		return 2
	}
	if len(o.Inputs) > 1 {
		fmt.Fprintln(os.Stderr, "qbuild build: one -i per build (run repeatedly for more packs)")
		return 2
	}
	meta := packMeta{
		Code: o.Code, Title: o.Title, Category: o.Category, Body: o.Body,
		Duration: o.Duration,
	}
	spec, issues, err := parseSource(o.Inputs[0], meta)
	if err != nil {
		fmt.Fprintf(os.Stderr, "qbuild build: parse %s: %v\n", o.Inputs[0], err)
		return 1
	}
	lintIssues := append(issues, lintSpec(spec)...)
	fmt.Printf("%s: %d questions\n", spec.Source, len(spec.Questions))
	if printIssues(spec.Source, lintIssues) {
		fmt.Println("build: FAILED (fix errors above, or run `qbuild check` for details)")
		return 1
	}

	pack, key, err := buildArtifacts(spec)
	if err != nil {
		fmt.Fprintf(os.Stderr, "qbuild build: %v\n", err)
		return 1
	}

	for _, d := range []string{
		filepath.Join(o.Outdir, "questions"),
		filepath.Join(o.Outdir, "answer-keys", o.Keysub),
		filepath.Join(o.Outdir, "src", o.Keysub),
	} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			fmt.Fprintf(os.Stderr, "qbuild build: mkdir %s: %v\n", d, err)
			return 1
		}
	}
	packPath := filepath.Join(o.Outdir, "questions", spec.Code+".json")
	keyPath := filepath.Join(o.Outdir, "answer-keys", o.Keysub, spec.Code+".json")
	if err := os.WriteFile(packPath, pack, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "qbuild build: write pack: %v\n", err)
		return 1
	}
	if err := os.WriteFile(keyPath, key, 0o644); err != nil {
		fmt.Fprintf(os.Stderr, "qbuild build: write key: %v\n", err)
		return 1
	}
	// Provenance: keep the raw source next to its generation.
	srcCopy := filepath.Join(o.Outdir, "src", o.Keysub, filepath.Base(spec.Source))
	raw, _ := os.ReadFile(spec.Source)
	if len(raw) > 0 {
		_ = os.WriteFile(srcCopy, raw, 0o644)
	}

	n, err := writeManifest(o.Outdir, o.Version)
	if err != nil {
		fmt.Fprintf(os.Stderr, "qbuild build: manifest: %v\n", err)
		return 1
	}

	// Boot verification with the REAL loader: sha256 + answer-leak + counts.
	if _, err := cbtdata.Load(o.Outdir); err != nil {
		fmt.Fprintf(os.Stderr, "qbuild build: boot-verify FAILED: %v\n", err)
		return 1
	}

	fmt.Printf("pack  → %s\n", packPath)
	fmt.Printf("key   → %s (server-only)\n", keyPath)
	fmt.Printf("manifest: %d packs fingerprinted → %s\n", n, filepath.Join(o.Outdir, "manifest.json"))
	fmt.Printf("boot-verify: OK (%s builds a loadable library)\n", spec.Code)
	return 0
}

func cmdManifest(outdir, version string) int {
	n, err := writeManifest(outdir, version)
	if err != nil {
		fmt.Fprintf(os.Stderr, "qbuild manifest: %v\n", err)
		return 1
	}
	fmt.Printf("manifest: %d packs fingerprinted → %s\n", n, filepath.Join(outdir, "manifest.json"))
	return 0
}
