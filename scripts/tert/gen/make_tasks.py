#!/usr/bin/env python3
"""Build the farm task list: every pack unit-topic + foundations topic.

Ordering: computing_python first (founder reference course), then packs by
the number of courses routed to them (student impact), within a pack:
foundations first, then sections 2..15 in order.
"""
import json
import re
import sys

sys.path.insert(0, "/home/z/my-project/scripts")
sys.path.insert(0, "/home/z/my-project/scripts/tert")

from tert.router import route  # noqa: E402
from tert.build_all import load_pack  # noqa: E402
from tert.spec import subject_phrase  # noqa: E402

DISCIPLINE = {
    "computing_python": "introductory Python programming for university students",
    "computing_general": "general computing, information technology and office applications for university students",
    "networking": "computer networks, cybersecurity and operating systems for university students",
    "medicine": "human medicine, nursing, anatomy, physiology and public health for university students",
    "education": "education science, teaching theory and classroom practice for university students",
    "arts": "humanities: literature, history, philosophy, languages and performing arts for university students",
    "bio_sciences": "biological sciences: biology, microbiology, botany, zoology and genetics for university students",
    "business": "business administration, management, marketing and entrepreneurship for university students",
    "english_lang": "English language, grammar, linguistics and communication skills for university students",
    "agriculture": "agriculture: crop science, soil, animal production and agricultural extension for university students",
    "eng_electrical": "electrical and electronic engineering, power systems and telecommunications for university students",
    "eng_mechanical": "mechanical, production and materials engineering for university students",
    "chem_phys": "chemistry, physics, geology and physical sciences for university students",
    "eng_civil": "civil engineering, structures, construction and surveying for university students",
    "data_analytics": "statistics, data science and mathematics for university students",
    "social_sciences": "social sciences: political science, sociology, psychology and mass communication for university students",
    "eng_chemical": "chemical, petroleum and polymer engineering for university students",
    "law": "law, jurisprudence and legal studies for university students",
    "economics": "economics and development economics for university students",
    "accounting_finance": "accounting, finance, banking and taxation for university students",
    "environment": "geography, environmental management, urban planning and estate management for university students",
}

corpus = json.load(open("/home/z/my-project/content/tertiary/corpus.json"))

# pack -> {count, sample subjects}
pack_info = {}
for c in corpus:
    pk = route(c)
    d = pack_info.setdefault(pk, {"n": 0, "subs": []})
    d["n"] += 1
    if len(d["subs"]) < 40:
        d["subs"].append(subject_phrase(c["title"], c["dept_name"]))

order = sorted(pack_info.items(), key=lambda kv: -kv[1]["n"])
# founder reference course first
order.sort(key=lambda kv: 0 if kv[0] == "computing_python" else 1)

tasks = []
for pk, info in order:
    try:
        pack = load_pack(pk)
    except Exception as e:
        print("SKIP", pk, e)
        continue
    subs = info["subs"]
    # 3 spread sample subject phrases for the prompt
    picks = [subs[0], subs[len(subs) // 2], subs[-1]] if len(subs) >= 3 else subs
    disc = DISCIPLINE.get(pk, pk.replace("_", " "))
    for fi, ft in enumerate(pack["foundations"], 1):
        tasks.append({
            "id": "%s/F%02d" % (pk, fi), "pack": pk, "kind": "foundation",
            "sec_idx": 1, "unit_idx": fi, "unit": ft,
            "section": "Foundation topics of the course",
            "discipline": disc, "samples": picks,
        })
    for si, sec in enumerate(pack["sections"], start=2):
        for ui, ut in enumerate(sec["units"], start=1):
            tasks.append({
                "id": "%s/S%02dU%02d" % (pk, si, ui), "pack": pk, "kind": "unit",
                "sec_idx": si, "unit_idx": ui, "unit": ut,
                "section": sec["title"],
                "discipline": disc, "samples": picks,
            })

out = "/home/z/my-project/content/tertiary/gen/tasks.json"
with open(out, "w") as f:
    json.dump(tasks, f, ensure_ascii=False)
print("tasks:", len(tasks))
print("packs:", len(order))
for pk, info in order[:25]:
    print("  %-20s courses=%4d tasks=%d" % (pk, info["n"],
          sum(1 for t in tasks if t["pack"] == pk)))
