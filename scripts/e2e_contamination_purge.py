#!/usr/bin/env python3
"""Purge the CI-E2E rows from production Neon + InsForge #1.

The 2026-10-16 CI leak (five runs, 10:58Z-14:17Z) registered e2e
scholars and created E2E schools/exams/receipts in the live user
databases. Order matters: school.schools first (every school table
cascades from it), then study.purge_user per e2e account (the app's
own one-call delete, 0027_user_purge.sql). Prints every row it removes
and re-scans to zero at the end.
"""
import json

import pg8000.native

TARGETS = {
    "neon": dict(
        user="neondb_owner", password="npg_siaeB4m7IMUZ",
        host="ep-snowy-base-axf83q3b-pooler.c-4.us-east-2.aws.neon.tech",
        database="neondb", port=5432,
    ),
    "insforge1": dict(
        user="postgres", password="8261cb984054ff872330f6b73200eb99",
        host="dbeqj4dx.us-east.database.insforge.app",
        database="insforge", port=5432,
    ),
}

E2E_USER_SQL = "username ~ '^e2e[0-9]{1,10}$'"


def purge(con, label):
    print(f"\n===== {label} =====")
    users = con.run(f"SELECT id, username FROM study.users WHERE {E2E_USER_SQL}")
    ids = [r[0] for r in users]
    print(f"e2e users: {len(ids)}: {[u[1] for u in users]}")
    if not ids:
        print("nothing to do")
        return

    # 1) schools owned by e2e accounts (everything school-domain cascades)
    ph = ", ".join(":p%d" % i for i in range(len(ids)))
    kw = {f"p{i}": v for i, v in enumerate(ids)}
    schools = con.run(
        f"SELECT id, name FROM school.schools WHERE owner_user_id IN ({ph}) "
        "OR lower(name) LIKE '%e2e%'", **kw)
    for sid, name in schools:
        print(f"  school: {name} ({sid})")
        con.run("DELETE FROM school.schools WHERE id = :sid", sid=sid)
    print(f"schools deleted: {len(schools)} (children cascaded)")

    # 2) the accounts themselves via the app's own purge
    for uid, uname in users:
        con.run("SELECT study.purge_user(:uid)", uid=uid)
        print(f"  purged user {uname}")

    # 3) verify zero
    left_users = con.run(f"SELECT count(*) FROM study.users WHERE {E2E_USER_SQL}")[0][0]
    left_schools = con.run(
        f"SELECT count(*) FROM school.schools WHERE owner_user_id IN ({ph}) "
        "OR lower(name) LIKE '%e2e%'", **kw)[0][0]
    left_pay = con.run(
        "SELECT count(*) FROM school.fee_payments WHERE reference LIKE 'E2E-%'")[0][0]
    left_q = con.run(
        "SELECT count(*) FROM school.exam_questions WHERE question LIKE 'E2E question%' "
        "OR question LIKE 'Dash test%'")[0][0]
    print(f"verify -> users {left_users}, schools {left_schools}, "
          f"receipts {left_pay}, e2e questions {left_q}")
    return dict(users=len(ids), schools=len(schools),
                left=dict(users=left_users, schools=left_schools,
                          receipts=left_pay, questions=left_q))


def main():
    report = {}
    for label, cfg in TARGETS.items():
        con = pg8000.native.Connection(
            user=cfg["user"], password=cfg["password"], host=cfg["host"],
            database=cfg["database"], port=cfg["port"], ssl_context=True, timeout=60)
        try:
            report[label] = purge(con, label)
        finally:
            con.close()
    json.dump(report, open("/tmp/e2e_purge.json", "w"), indent=1, default=str)
    print("\nreport -> /tmp/e2e_purge.json")


if __name__ == "__main__":
    main()
