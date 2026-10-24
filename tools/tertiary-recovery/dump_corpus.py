#!/usr/bin/env python3
"""dump_corpus.py - dump the tertiary ladder from Supabase into a local sqlite
corpus for offline recovery work. Tables:
  courses(course_id, title, dept_id, category)
  sections(course_id, sec, title)
  units(unit_id, course_id, sec, seq, pos, title)
  meta(k, v)
Also computes pos (position within section: sec 1 => 1..12, sec>=2 => 1..10).
"""
import psycopg2, sqlite3, os

DSN = "postgresql://postgres.zfxrmcwdnmmxjawmsiyp:Stephen2474life%23@aws-1-eu-west-3.pooler.supabase.com:5432/postgres?sslmode=require"
OUT = "/home/z/my-project/content/tertiary/recover/corpus.sqlite"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
if os.path.exists(OUT):
    os.remove(OUT)

con = psycopg2.connect(DSN, connect_timeout=30)
cur = con.cursor()
cur.execute("select course_id, title, dept_id, category from learn.courses where body='tertiary'")
courses = cur.fetchall()
cur.execute("select course_id, section, title from learn.course_sections order by course_id, section")
sections = cur.fetchall()
cur.execute("select u.unit_id, u.course_id, u.section, u.seq, u.title from learn.units u join learn.courses c on c.course_id=u.course_id where c.body='tertiary'")
units = cur.fetchall()
con.close()
print(f"fetched: {len(courses)} courses, {len(sections)} sections, {len(units)} units")

ldb = sqlite3.connect(OUT)
ldb.executescript("""
create table courses(course_id text primary key, title text, dept_id text, category text);
create table sections(course_id text, sec int, title text);
create table units(unit_id text primary key, course_id text, sec int, seq int, pos int, title text);
create index idx_units_course on units(course_id);
create index idx_sect_course on sections(course_id);
create table meta(k text, v text);
""")

ldb.executemany("insert into courses values (?,?,?,?)", courses)
ldb.executemany("insert into sections values (?,?,?)", sections)

rows = []
for unit_id, course_id, sec, seq, title in units:
    if sec == 1:
        pos = seq  # 1..12
    else:
        pos = seq - 10 * sec + 8  # sec 2 starts at seq 13, each section = block of 10
    rows.append((unit_id, course_id, sec, seq, pos, title))
ldb.executemany("insert into units values (?,?,?,?,?,?)", rows)
ldb.execute("insert into meta values ('n_courses', ?)", (str(len(courses)),))
ldb.execute("insert into meta values ('n_units', ?)", (str(len(units)),))
ldb.commit()

for r in ldb.execute("select sec, min(pos), max(pos), count(*) from units group by sec order by sec"):
    print("  sec", r)
bad = ldb.execute("select count(*) from units u where (u.sec>1 and (u.pos<1 or u.pos>10)) or (u.sec=1 and (u.pos<1 or u.pos>12))").fetchone()[0]
print("pos range violations:", bad)
ldb.close()
print("sqlite corpus at", OUT, f"({os.path.getsize(OUT)/1e6:.1f} MB)")
