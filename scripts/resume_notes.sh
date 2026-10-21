#!/bin/sh
# resume_notes.sh - the one command to finish the school lesson notes.
#
# The NERDC 2025 scheme corpus (data/school-schemes/nerdc-2025) carries
# 846 scheme-of-work files. Every one of them needs a matching lesson
# note file under data/school-notes/nerdc-2025, written by an LLM in the
# standard Nigerian lesson note frame (see generate_school_notes.mjs).
#
# The generation endpoint rate limits hard, so the script is built for
# stop-and-start: it skips files that already exist, checkpoints what
# finished (scripts/.notes-checkpoint.json), retries 429s with an
# escalating backoff, and validates each reply against the scheme's
# weeks (a reply that drops weeks fails instead of shipping holes).
#
# Run it repeatedly until it prints nothing left to do. Only data/
# changes need committing - the web build bakes the corpus via
# bake_school_corpus.py and the API reads the same files at boot.
#
# Usage:
#   scripts/resume_notes.sh                 # all levels, concurrency 2
#   NOTES_CONCURRENCY=3 scripts/resume_notes.sh
#   scripts/resume_notes.sh --level sss-1   # one level
set -e

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

CONC="${NOTES_CONCURRENCY:-2}"
export NOTES_CONCURRENCY="$CONC"

echo "resuming school notes (concurrency $CONC, args: $*)"
exec node scripts/generate_school_notes.mjs "$@"
