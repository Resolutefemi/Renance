#!/bin/bash
# runner_v3.sh — supervised end-to-end rebuild at the 150-250 word band:
#   preflight probe -> farm passes -> sweep -> build+convert per pack ->
#   R2 push (GET-merge-PUT) -> sample verify. Fully logged, resumable.
set -u
export PYTHONUNBUFFERED=1
GEN=/home/z/my-project/scripts/tert/gen
TERT=/home/z/my-project/scripts/tert
BUILDDIR=/home/z/my-project/content/tertiary/build
LOG=/home/z/my-project/content/tertiary/gen/runner_v3.log
cd "$GEN"
exec >> "$LOG" 2>&1
echo "=== runner start $(date -u +%FT%TZ) ==="

# ---- Stage 0: preflight probe (wait out throttle; max ~3h, then continue) ----
for i in $(seq 1 72); do
  if python3 - <<'PYEOF'
import sys
sys.path.insert(0, "/home/z/my-project/scripts/tert/gen")
from zai_client import chat
try:
    chat("Reply OK.", "Say OK.", model="glm-4-flash", max_tokens=8, retries=1, timeout=40)
    sys.exit(0)
except Exception:
    sys.exit(1)
PYEOF
  then echo "preflight: API OK after $i probe(s)"; break; fi
  echo "preflight: throttled (probe $i)"; sleep 150
done

# ---- Stage 1: farm passes (up to 4; exits early when nothing pending) ----
for p in 1 2 3 4; do
  echo "--- farm pass $p $(date -u +%T) ---"
  python3 farm.py --workers 3 --max-fail 40
  echo "farm pass $p rc=$?"
  PENDING=$(python3 farm.py --status | head -1 | sed 's/.*remaining=//')
  echo "pending after pass $p: $PENDING"
  [ "$PENDING" = "0" ] && break
  sleep 120
done
python3 farm.py --status

# ---- Stage 2: sweep validate at the new band ----
echo "--- sweep $(date -u +%T) ---"
python3 "$TERT/sweep_validate.py"
echo "sweep rc=$? (rc=1 means some packs incomplete; complete packs still build)"

# ---- Stage 3: fresh shard space (old 60-105-word content is replaced) ----
rm -f "$BUILDDIR/pack_done.txt"
rm -rf "$BUILDDIR/shards"

# ---- Stage 4: per-pack build + shard conversion ----
PACKS="accounting_finance agriculture arts bio_sciences business chem_phys computing_general computing_python data_analytics economics education eng_chemical eng_civil eng_electrical eng_mechanical english_lang environment law medicine networking social_sciences"
for pk in $PACKS; do
  echo "--- build+convert $pk $(date -u +%T) ---"
  python3 "$TERT/build_all.py" --only "$pk" --workers 6
  python3 "$TERT/push_r2.py" --phase1-only
  df -h / | tail -1
done

# ---- Stage 5: R2 push (GET-merge-PUT, cap 140k) ----
echo "--- R2 push $(date -u +%T) ---"
python3 "$TERT/push_r2.py"

# ---- Stage 6: verify samples ----
echo "--- verify $(date -u +%T) ---"
python3 "$TERT/verify_samples.py"
echo "=== runner end $(date -u +%FT%TZ) ==="
