#!/usr/bin/env bash
# Parallel-download the NERDC curriculum PDFs listed in urls.tsv.
# Skips files already fetched (bigger than 50 KB). Usage:
#   bash scripts/download_nerdc_pdfs.sh [PARALLEL] [LIMIT]
set -u
DIR="/home/z/my-project/renance/data/school-schemes/nerdc/_pdf"
URLS="/home/z/my-project/renance/data/school-schemes/nerdc/urls.tsv"
P="${1:-6}"
LIMIT="${2:-0}"
mkdir -p "$DIR"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

fetch_one() {
  local fname="$1" url="$2"
  local out="$DIR/$fname"
  if [ -s "$out" ] && [ "$(stat -c%s "$out")" -gt 50000 ]; then
    return 0
  fi
  curl -sL --max-time 420 -A "$UA" -o "$out" "$url" || return 1
  # a 404 page is tiny HTML; treat as failure
  if [ "$(stat -c%s "$out" 2>/dev/null || echo 0)" -lt 50000 ]; then
    rm -f "$out"
    return 1
  fi
  return 0
}
export -f fetch_one
export DIR UA

if [ "$LIMIT" -gt 0 ]; then
  head -n "$LIMIT" "$URLS" > /tmp/urls_chunk.tsv
  URLS=/tmp/urls_chunk.tsv
fi

xargs -d '\n' -P "$P" -n1 bash -c 'IFS=$'"'"'\t'"'"' read -r f u <<< "$0"; fetch_one "$f" "$u" && echo "OK $f" || echo "FAIL $f"' < "$URLS"
echo "--- downloaded: $(ls "$DIR" | wc -l) of $(wc -l < /home/z/my-project/renance/data/school-schemes/nerdc/urls.tsv) ---"
