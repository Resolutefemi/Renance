#!/usr/bin/env python3
"""list_r2.py - save the landed shard set; verify fnv1a32 shard function
round-trips a known unit (CRS-01835-EU0210 was fetched from shard 12345)."""
import boto3, sys
from botocore.config import Config

ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KEY = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
OUT = "/home/z/my-project/content/tertiary/recover/landed_shards.txt"

s3 = boto3.client(
    "s3",
    endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
    aws_access_key_id=KEY,
    aws_secret_access_key=SEC,
    config=Config(connect_timeout=15, read_timeout=30, retries={"max_attempts": 2}),
    region_name="auto",
)

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

# round-trip check against the shard fetched earlier
assert fnv1a32("CRS-01835-EU0210") % 60000 == 12345, fnv1a32("CRS-01835-EU0210") % 60000
print("fnv1a32 round-trip OK: CRS-01835-EU0210 -> shard 12345")

nums = set()
paginator = s3.get_paginator("list_objects_v2")
n = 0
for page in paginator.paginate(Bucket="renance", Prefix="packs/p-", MaxKeys=1000):
    for o in page.get("Contents", []):
        k = o["Key"]  # packs/p-NNNNN.json
        nums.add(int(k[len("packs/p-"):].split(".")[0]))
        n += 1
with open(OUT, "w") as f:
    f.write("\n".join(str(x) for x in sorted(nums)))
print(f"landed shards: {n} objects, {len(nums)} distinct -> {OUT}")
print("min", min(nums), "max", max(nums))
