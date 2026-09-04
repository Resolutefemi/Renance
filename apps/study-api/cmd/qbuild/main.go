// Command qbuild is Renance's exam-pack builder (ROADMAP #1).
//
//	qbuild check   -i src.yaml [-i src2.csv ...]
//	qbuild build   -i src.yaml [-outdir data] [-keysub mock]
//	qbuild manifest [-outdir data] [-version era2-g1]
//
// Sources: YAML (self-describing) or CSV (pack metadata via flags).
// Output matches the cbt-build pipeline byte-for-byte conventions:
//
//	data/questions/<code>.json            student-visible pack
//	data/answer-keys/<keysub>/<code>.json server-only key (gitignored except mock/)
//	data/src/<keysub>/<file>              provenance copy of the source
//	data/manifest.json                    sha256 fingerprint of every pack
//
// build always ends with cbtdata.Load(outdir), the REAL boot loader, so a
// pack that would refuse to boot can never reach a commit.
package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	if len(args) < 1 {
		usage()
		return 2
	}
	fs := flag.NewFlagSet(args[0], flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	var (
		inputs   multiFlag
		outdir   = fs.String("outdir", "data", "content root (contains questions/, answer-keys/)")
		keysub   = fs.String("keysub", "mock", "answer-keys subdir for the generated key")
		version  = fs.String("version", "", "manifest version label (default: preserve existing, else era2-g1)")
		code     = fs.String("code", "", "pack code (required for CSV input)")
		title    = fs.String("title", "", "pack title (required for CSV input)")
		category = fs.String("category", "", "category, e.g. secondary|university (CSV input)")
		body     = fs.String("body", "", "exam body, e.g. JAMB|WAEC|NECO|University Modules (CSV input)")
		duration = fs.Int("duration", 0, "duration in minutes (CSV input; 0 = omit)")
	)
	fs.Var(&inputs, "i", "source file (.yaml/.yml/.csv), repeatable")
	switch args[0] {
	case "check":
		fs.Parse(args[1:])
		return cmdCheck(buildOpts{
			Inputs: inputs,
			Code:   *code, Title: *title, Category: *category, Body: *body,
			Duration: *duration,
		})
	case "build":
		fs.Parse(args[1:])
		return cmdBuild(buildOpts{
			Inputs: inputs, Outdir: *outdir, Keysub: *keysub, Version: *version,
			Code: *code, Title: *title, Category: *category, Body: *body,
			Duration: *duration,
		})
	case "manifest":
		fs.Parse(args[1:])
		return cmdManifest(*outdir, *version)
	case "-h", "-help", "help":
		usage()
		return 0
	default:
		fmt.Fprintf(os.Stderr, "qbuild: unknown command %q\n", args[0])
		usage()
		return 2
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `qbuild — Renance exam pack builder

Usage:
  qbuild check    -i src.yaml [-i src2.csv ...]           lint sources only
  qbuild build    -i src.yaml [-outdir data] [-keysub mock]
                                                       validate + write pack/key/src + remanifest + boot-verify
  qbuild manifest [-outdir data] [-version era2-g1]     recompute manifest only

CSV input needs pack metadata flags: -code, -title (+ -category -body -duration).
YAML carries its own metadata; flags override when given.

YAML schema:
  code: jamb-chemistry-mock
  title: JAMB Chemistry - Practice Mock
  category: secondary      # optional
  body: JAMB               # optional
  durationMinutes: 60      # optional
  questions:
    - stem: ...
      a: ...               # options a-d (or options: {A: ..., B: ...})
      b: ...
      c: ...
      d: ...
      answer: B            # key-only, never written into the pack
      explanation: ...     # key-only
      topic: ...           # optional
      difficulty: easy     # optional: easy|medium|hard
      marks: 1             # optional, default 1

Exit codes: 0 ok · 1 validation failure · 2 usage/IO error
`)
}

// multiFlag collects repeated -i values.
type multiFlag []string

func (m *multiFlag) String() string { return fmt.Sprint(*m) }
func (m *multiFlag) Set(v string) error {
	*m = append(*m, v)
	return nil
}
