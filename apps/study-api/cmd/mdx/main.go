// Command mdx (ROADMAP #8), the lesson content pipeline.
//
//	mdx check   lint every lesson source under -src (no files written)
//	mdx build   parse every source and write data/lessons/{slug}.json
//	            bundles, stamping provenance (contentSha256 over the
//	            source bytes) and pruning orphans whose source vanished
//
// Doctrine mirrors qbuild: a lesson that fails validation never ships,
// and every build is deterministic from the sources alone.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"renance.dev/study-api/internal/cbtdata"
	"renance.dev/study-api/internal/lessonmd"
)

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		usage(stderr)
		return 2
	}
	switch args[0] {
	case "check":
		fs_ := flag.NewFlagSet("check", flag.ContinueOnError)
		fs_.SetOutput(stderr)
		src := fs_.String("src", "data/src/lessons", "directory of lesson markdown sources")
		if err := fs_.Parse(args[1:]); err != nil {
			return 2
		}
		return cmdCheck(*src, stdout, stderr)
	case "build":
		fs_ := flag.NewFlagSet("build", flag.ContinueOnError)
		fs_.SetOutput(stderr)
		src := fs_.String("src", "data/src/lessons", "directory of lesson markdown sources")
		out := fs_.String("out", "data/lessons", "directory to write lesson bundles into")
		if err := fs_.Parse(args[1:]); err != nil {
			return 2
		}
		return cmdBuild(*src, *out, stdout, stderr)
	case "-h", "--help", "help":
		usage(stdout)
		return 0
	default:
		fmt.Fprintf(stderr, "mdx: unknown command %q\n\n", args[0])
		usage(stderr)
		return 2
	}
}

func usage(w io.Writer) {
	fmt.Fprint(w, `mdx — Renance lesson pipeline (ROADMAP #8)

Usage:
  mdx check  [-src data/src/lessons]          lint lesson sources
  mdx build  [-src data/src/lessons] [-out data/lessons]
                                              build + prune bundles
`)
}

// loadSources parses every *.md under src, sorted by filename.
func loadSources(src string) ([]lessonOut, []error) {
	entries, err := os.ReadDir(src)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil, []error{fmt.Errorf("source dir %s does not exist", src)}
		}
		return nil, []error{fmt.Errorf("scan %s: %w", src, err)}
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		names = append(names, e.Name())
	}
	sort.Strings(names)

	var out []lessonOut
	var errs []error
	seen := map[string]string{}
	for _, name := range names {
		path := filepath.Join(src, name)
		raw, err := os.ReadFile(path)
		if err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", name, err))
			continue
		}
		les, err := lessonmd.Parse(raw)
		if err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", name, err))
			continue
		}
		if prev, dup := seen[les.Slug]; dup {
			errs = append(errs, fmt.Errorf("%s: slug %q already built from %s", name, les.Slug, prev))
			continue
		}
		seen[les.Slug] = name
		sum := sha256.Sum256(raw)
		les.ContentSha256 = hex.EncodeToString(sum[:])
		out = append(out, lessonOut{lesson: les, source: name})
	}
	return out, errs
}

type lessonOut struct {
	lesson cbtdata.Lesson
	source string
}

func cmdCheck(src string, stdout, stderr io.Writer) int {
	lessons, errs := loadSources(src)
	for _, e := range errs {
		fmt.Fprintf(stderr, "mdx: %v\n", e)
	}
	if len(errs) > 0 {
		fmt.Fprintf(stderr, "mdx: check FAILED (%d source(s) broken, %d ok)\n", len(errs), len(lessons))
		return 1
	}
	fmt.Fprintf(stdout, "mdx: %d lesson source(s), all valid\n", len(lessons))
	return 0
}

func cmdBuild(src, out string, stdout, stderr io.Writer) int {
	lessons, errs := loadSources(src)
	for _, e := range errs {
		fmt.Fprintf(stderr, "mdx: %v\n", e)
	}
	if len(errs) > 0 {
		fmt.Fprintf(stderr, "mdx: build FAILED (%d error(s))\n", len(errs))
		return 1
	}
	if err := os.MkdirAll(out, 0o755); err != nil {
		fmt.Fprintf(stderr, "mdx: mkdir %s: %v\n", out, err)
		return 1
	}
	built := map[string]struct{}{}
	for _, lo := range lessons {
		raw, err := lessonmd.EncodeJSON(lo.lesson)
		if err != nil {
			fmt.Fprintf(stderr, "mdx: encode %s: %v\n", lo.lesson.Slug, err)
			return 1
		}
		path := filepath.Join(out, lo.lesson.Slug+".json")
		if err := os.WriteFile(path, raw, 0o644); err != nil {
			fmt.Fprintf(stderr, "mdx: write %s: %v\n", path, err)
			return 1
		}
		built[lo.lesson.Slug+".json"] = struct{}{}
		fmt.Fprintf(stdout, "mdx: built %s (%s, %d min read, sha256 %.12s)\n",
			path, lo.lesson.Title, lo.lesson.Minutes, lo.lesson.ContentSha256)
	}
	// prune orphans: bundles whose source is gone would still boot-load,
	// silently resurrecting retired lessons.
	entries, err := os.ReadDir(out)
	if err != nil {
		fmt.Fprintf(stderr, "mdx: rescan %s: %v\n", out, err)
		return 1
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		if _, keep := built[e.Name()]; !keep {
			path := filepath.Join(out, e.Name())
			if err := os.Remove(path); err != nil {
				fmt.Fprintf(stderr, "mdx: prune %s: %v\n", path, err)
				return 1
			}
			fmt.Fprintf(stdout, "mdx: pruned orphan %s\n", path)
		}
	}
	fmt.Fprintf(stdout, "mdx: %d lesson bundle(s) in %s\n", len(lessons), out)
	return 0
}
