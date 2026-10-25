#!/usr/bin/env python3
"""Direct z-ai chat API client for the generation farm.

Reads /etc/.z-ai-config (same auth the SDK uses) and posts to
/chat/completions with a raisable max_tokens (the CLI default caps at 4096,
which truncates a full 10-note lesson).
"""
import json
import os
import time

import threading

import requests

_CFG = json.load(open("/etc/.z-ai-config"))
URL = _CFG["baseUrl"].rstrip("/") + "/chat/completions"
HEADERS = {
    "Content-Type": "application/json",
    "Authorization": "Bearer " + _CFG["apiKey"],
    "X-Z-AI-From": "Z",
    "X-Chat-Id": _CFG.get("chatId", ""),
    "X-User-Id": _CFG.get("userId", ""),
    "X-Token": _CFG.get("token", ""),
}


_plock = threading.Lock()


class RateLimited(Exception):
    pass


_penalty_until = 0.0


def _penalized():
    import time as _t
    return _t.time() < _penalty_until


def chat(system, user, model="glm-4-plus", max_tokens=8192, temperature=None,
         retries=5, timeout=300):
    """One chat completion. Retries 429s with exponential backoff.

    Returns (content_text, usage_dict). Raises on final failure.
    """
    global _penalty_until
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "thinking": {"type": "disabled"},
        "max_tokens": max_tokens,
    }
    if temperature is not None:
        body["temperature"] = temperature
    global _penalty_until
    delay = 8.0
    consec429 = 0
    last = None
    for attempt in range(retries):
        try:
            if _penalized():
                time.sleep(max(0, _penalty_until - time.time()) + 2)
            r = requests.post(URL, headers=HEADERS, json=body, timeout=timeout)
            if r.status_code == 429:
                consec429 += 1
                if consec429 >= 3:
                    with _plock:
                        _penalty_until = max(_penalty_until, time.time() + 100)
                raise RateLimited(r.text[:200])
            consec429 = 0
            if r.status_code != 200:
                last = RuntimeError("HTTP %d: %s" % (r.status_code, r.text[:300]))
                time.sleep(delay)
                delay = min(delay * 1.6, 60)
                continue
            d = r.json()
            content = d["choices"][0]["message"]["content"]
            finish = d["choices"][0].get("finish_reason")
            usage = d.get("usage", {})
            return content, {"finish": finish, "usage": usage}
        except RateLimited:
            time.sleep(delay)
            delay = min(delay * 1.6, 90)
        except requests.RequestException as e:
            last = RuntimeError("transport: %s" % e)
            time.sleep(delay)
            delay = min(delay * 1.6, 60)
    raise last or RuntimeError("chat failed after retries")


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    t0 = time.time()
    c, meta = chat(
        "You reply with valid JSON only.",
        "Write the lesson for this unit.\n\nDiscipline: Python programming\n"
        "Course section: The Python Landscape: How Programs Run\n"
        "Unit topic: Syntax rules every Python file obeys\n\n"
        "Each of the 10 note bodies must be 250 to 400 words (about 300 words, "
        "3 to 4 paragraphs). JSON only. {S} naturally in 3 to 6 notes, no --, "
        "no < character, no exam talk.")
    print("elapsed: %.1fs | finish: %s | usage: %s" % (time.time() - t0, meta["finish"], meta["usage"]))
    print("bytes:", len(c))
    from json_repair import loads_lenient
    body = loads_lenient(c)
    print("notes:", len(body["notes"]),
          "| words:", [len(n["body"].split()) for n in body["notes"]])
