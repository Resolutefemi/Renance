# Git Workflow — keeping VS Code and GitHub identical

The goal: your laptop (VS Code) and GitHub are ALWAYS the same project, no
matter who writes code — you, or an AI agent you later give a token to.

## Golden rules

1. **Start of every session: pull. End of every session: push.**
2. Never work long without committing — small, frequent commits beat big ones.
3. Never force-push `main`.
4. One writer at a time per file/folder: if the AI agent session is touching
   `apps/api/core`, you don't edit those files at the same time locally.

## Step 1 — one-time setup (after running renance-init.sh)

```bash
cd renance

# option A: GitHub CLI (easiest)
gh auth login
gh repo create renance --private --source=. --push

# option B: manual
# create empty repo github.com/<you>/renance, then:
git remote add origin https://github.com/<you>/renance.git
git add .
git commit -m "chore: phase 0 scaffold"
git push -u origin main
```

## Step 2 — daily loop (both sides, always)

```bash
bash scripts/git-sync.sh          # before starting: fetch + auto-rebase if clean
# ...work, commit small...
git commit -am "feat(cbt): exam timer service"    # conventional commits
bash scripts/git-sync.sh --push   # end of session: push
```

`scripts/git-sync.sh` refuses dangerous situations and tells you what to do,
so keep using it instead of raw pull/push.

## Step 3 — when you hand me (or any agent) a token later

Create a **fine-grained PAT**: GitHub → Settings → Developer settings →
Fine-grained tokens → scope it to ONLY the `renance` repo with
Contents: read/write, expiry ≤ 30 days.

The agent side then runs:

```bash
git clone https://<TOKEN>@github.com/<you>/renance.git
cd renance && git checkout -b agent/<task>
# ...work...
git commit -am "feat(api): ..."
git push -u origin agent/<task>
# open PR -> YOU review & merge on github.com
```

Why a branch + PR instead of direct pushes to main:
- you review everything before it lands;
- your protected `main` can never be broken by a bad agent session;
- conflicts surface in the PR instead of silently overwriting your work.

## Step 4 — conflict recovery (when both sides edited the same file)

```bash
git status                        # see conflicted files
# fix each file, then:
git add <file>
git rebase --continue
bash scripts/git-sync.sh --push
```

If ever truly stuck: `git reflog` shows every state your repo was in —
nothing committed is ever lost.

## Branch naming

| prefix | use |
|--------|-----|
| `feat/<scope>` | new functionality |
| `fix/<scope>` | bug fixes |
| `chore/<scope>` | tooling/config |
| `agent/<task>` | AI-agent sessions |

## Personal-access-token hygiene

- minimum expiry, single-repo scope, contents-only permission;
- never paste the token into chat/code/issues — put it in the credential
  field of the git URL or `GH_TOKEN` env var on the machine that needs it;
- revoke the moment a working sprint ends; issue a fresh one next time.
