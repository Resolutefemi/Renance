#!/usr/bin/env python3
"""Scan production Neon + InsForge #1 for rows the CI E2E leaked.

Five CI runs (2026-10-16 10:58Z-14:17Z) booted the study-api with the
baked production DSNs and ran scripts/api-e2e.sh against them: e2e
scholars, E2E schools, exam papers, fee receipts and their child rows
landed in the live user databases. This tool COUNTS them first - it
never deletes (purge is a separate, reviewed step).
"""
import json

import pg8000.native

TARGETS = {
    "neon": dict(
        user="neondb_owner",
        password="npg_siaeB4m7IMUZ",
        host="ep-snowy-base-axf83q3b-pooler.c-4.us-east-2.aws.neon.tech",
        database="neondb",
        port=5432,
    ),
    "insforge1": dict(
        user="postgres",
        password="8261cb984054ff872330f6b73200eb99",
        host="dbeqj4dx.us-east.database.insforge.app",
        database="insforge",
        port=5432,
    ),
}

# username pattern of scripts/api-e2e.sh: e2e$RANDOM$RANDOM
E2E_USER_SQL = "username ~ '^e2e[0-9]{1,10}$'"


def scan(con, label):
    print(f"\n===== {label} =====")
    out = {}
    rows = con.run(
        "SELECT id, username, created_at FROM study.users "
        f"WHERE {E2E_USER_SQL} ORDER BY created_at"
    )
    out["users"] = [dict(id=str(r[0]), username=r[1], created_at=str(r[2])) for r in rows]
    print(f"e2e users: {len(out['users'])}")
    for u in out["users"]:
        print("   ", u["username"], u["created_at"])

    ids = [u["id"] for u in out["users"]]
    placeholders = ", ".join(f"'{i}'" for i in ids) or "''"

    def count(sql, key):
        try:
            r = con.run(sql)
            out[key] = r[0][0]
            print(f"{key}: {r[0][0]}")
        except Exception as e:  # table may not exist on one side
            out[key] = f"ERR {str(e)[:80]}"
            print(f"{key}: ERR {str(e)[:80]}")

    count(
        "SELECT count(*) FROM school.schools "
        f"WHERE owner_user_id IN ({placeholders}) OR lower(name) LIKE '%e2e%'",
        "schools_owned_by_e2e_or_named_e2e",
    )
    count(
        "SELECT count(*) FROM school.fee_payments WHERE reference LIKE 'E2E-%' "
        "OR amount_kobo = 250050",
        "fee_payments_e2e",
    )
    count(
        "SELECT count(*) FROM school.exams WHERE title LIKE 'E2E paper%' OR title LIKE 'E2E%'",
        "exams_e2e",
    )
    count(
        "SELECT count(*) FROM school.exam_questions WHERE question LIKE 'E2E question%' "
        "OR question LIKE 'Dash test%'",
        "exam_questions_e2e",
    )
    count(
        "SELECT count(*) FROM study.attempts WHERE user_id IN (" + placeholders + ")",
        "attempts_by_e2e",
    ) if False else count(
        "SELECT count(*) FROM study.exam_attempts WHERE user_id IN (" + placeholders + ")",
        "exam_attempts_by_e2e",
    )
    return out


def main():
    report = {}
    for label, cfg in TARGETS.items():
        try:
            con = pg8000.native.Connection(
                user=cfg["user"], password=cfg["password"],
                host=cfg["host"], database=cfg["database"], port=cfg["port"],
                ssl_context=True, timeout=45,
            )
            report[label] = scan(con, label)
            con.close()
        except Exception as e:
            print(f"{label}: CONNECT FAILED: {str(e)[:200]}")
            report[label] = {"connect_error": str(e)[:200]}
    json.dump(report, open("/tmp/e2e_scan.json", "w"), indent=1)
    print("\nreport -> /tmp/e2e_scan.json")


if __name__ == "__main__":
    main()
