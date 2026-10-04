#!/usr/bin/env bash
# Daily companion: keeps local VS Code and GitHub identical.
#   bash scripts/git-sync.sh          -> fetch + status summary (+ auto-rebase when clean)
#   bash scripts/git-sync.sh --push   -> sync, then push your commits
set -euo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "== renance sync (${BRANCH}) =="

git fetch origin --prune || { echo "(no origin configured yet - see docs/git-workflow.md step 1)"; exit 0; }

BEHIND="$(git rev-list --count "HEAD..origin/${BRANCH}" 2>/dev/null || echo 0)"
AHEAD="$(git rev-list --count "origin/${BRANCH}..HEAD" 2>/dev/null || echo 0)"
DIRTY="$(git status --porcelain | wc -l | tr -d ' ')"

echo "behind origin : ${BEHIND} commit(s)"
echo "ahead  origin : ${AHEAD} commit(s)"
echo "local changes : ${DIRTY} file(s)"

if [ "${BEHIND}" != "0" ] && [ "${DIRTY}" = "0" ]; then
  echo "-- pulling with rebase (history stays linear)"
  git pull --rebase origin "${BRANCH}"
elif [ "${BEHIND}" != "0" ] && [ "${DIRTY}" != "0" ]; then
  echo "!! You have uncommitted changes AND remote moved."
  echo "   Commit first (git add -p && git commit), then re-run this script."
fi

if [ "${1:-}" = "--push" ]; then
  if [ "${AHEAD}" = "0" ] && [ "${BEHIND}" = "0" ]; then
    echo "nothing to push."
  else
    git push origin "${BRANCH}"
    echo "-- pushed."
  fi
else
  if [ "${AHEAD}" != "0" ]; then
    echo "next: bash scripts/git-sync.sh --push"
  fi
fi
