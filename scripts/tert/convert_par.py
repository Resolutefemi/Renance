#!/usr/bin/env python3
"""convert_par.py — parallel blobs -> shard-parts converter with exact resume.

Each worker converts blobs_N.jsonl, appending lessons into per-worker part
files shards/<NNNNN>.p<WID>.gz (multi-member gzip). Progress is tracked per
file by a byte-offset marker <blobsfile>.off, flushed every ~20 s, so a kill
never repeats more than 20 s of work. At EOF the blobs file is deleted.
push_r2.py groups all parts of a shard and pushes them in ONE PUT.
"""
import glob
import json
import os
import sys
import time
from multiprocessing import Pool

BUILD = "/home/z/my-project/content/tertiary/build"
SHARD_DIR = os.path.join(BUILD, "shards")
RUN_ID = int(time.time())


def convert_file(args):
    wid, f = args
    t0 = time.time()
    off_path = f + ".off"
    start = 0
    if os.path.exists(off_path):
        try:
            start = int(open(off_path).read().strip() or 0)
        except ValueError:
            start = 0
    handles = {}
    cycle = [0]
    n = 0
    last_flush = time.time()

    def close_all():
        for hh in handles.values():
            hh.close()
        handles.clear()
        cycle[0] += 1

    with open(f) as fh:
        if start:
            fh.seek(start)
        while True:
            line = fh.readline()
            if not line:
                break
            if not line.strip():
                continue
            # verbatim raw extraction: [<shard>,"<uid>",<blob>] -> shard, uid, raw
            s = line.rstrip("\n")
            try:
                i1 = s.index(",\"")
                i2 = s.index("\",", i1 + 1)
                shard = int(s[1:i1])
                uid = s[i1 + 2:i2]
                raw = s[i2 + 2:-1]
            except ValueError:
                shard, uid, blob = json.loads(line)
                raw = json.dumps(blob, ensure_ascii=False, separators=(",", ":"))
            h = handles.get(shard)
            if h is None:
                if len(handles) > 150:
                    close_all()
                import gzip as _gz
                token = "%d_%d_%d" % (wid, RUN_ID, cycle[0])
                h = _gz.open(os.path.join(SHARD_DIR, "%05d.%s.gz" % (shard, token)), "at")
                handles[shard] = h
            h.write("%s\t%s\n" % (uid, raw))
            n += 1
            if time.time() - last_flush > 20:
                close_all()
                with open(off_path, "w") as off:
                    off.write(str(fh.tell()))
                last_flush = time.time()
    close_all()
    os.remove(f)
    if os.path.exists(off_path):
        os.remove(off_path)
    return f, n, time.time() - t0


def main():
    os.makedirs(SHARD_DIR, exist_ok=True)
    files = sorted(glob.glob(BUILD + "/blobs_*.jsonl"))
    files = [f for f in files if not f.endswith(".off")]
    if not files:
        print("convert: nothing to do")
        return
    W = min(len(files), 6)
    args = [(i, f) for i, f in enumerate(files)]
    t0 = time.time()
    if W == 1:
        results = [convert_file(args[0])]
    else:
        with Pool(W) as p:
            results = p.map(convert_file, args)
    total = sum(r[1] for r in results)
    print("convert_par: %d lessons from %d files in %.1f min" % (
        total, len(results), (time.time() - t0) / 60))
    for f, n, secs in results:
        print("  %s: %d lessons (%.1f min)" % (os.path.basename(f), n, secs / 60))


if __name__ == "__main__":
    main()
