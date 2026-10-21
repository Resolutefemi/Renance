package learn

import (
        "strings"
        "testing"
)

// The GST shelf must parse with real titles, real codes and one topic
// per course (the 2026-10-14 regression seeded empty titles under
// bogus departments).
func TestCollectTertiaryGST(t *testing.T) {
        deptList, courseList, topics, err := collectTertiary()
        if err != nil {
                t.Fatalf("collectTertiary: %v", err)
        }
        depts := map[string]seedDept{}
        for _, d := range deptList {
                depts[d.id] = d
        }
        courses := map[string]seedCourse{}
        for _, c := range courseList {
                courses[c.id] = c
        }
        if d, ok := depts["GST-ALL"]; !ok || d.itype != "General Studies" {
                t.Fatalf("GST-ALL department missing or wrong: %+v", d)
        }
        nGST, bad := 0, 0
        var gst101 seedCourse
        for _, c := range courses {
                if strings.HasPrefix(c.id, "GST ") {
                        nGST++
                        if c.title == "" || c.dept != "GST-ALL" {
                                bad++
                        }
                        if c.id == "GST 101" {
                                gst101 = c
                        }
                }
        }
        if nGST < 60 {
                t.Fatalf("expected the GST suite (~80 rows), got %d", nGST)
        }
        if bad > 0 {
                t.Fatalf("%d GST rows have empty titles or the wrong department", bad)
        }
        if gst101.id == "" || gst101.code != "GST 101" || gst101.title == "" {
                t.Fatalf("GST 101 malformed: %+v", gst101)
        }
        nTopics := 0
        for _, tp := range topics {
                if tp.courseID == "GST 101" {
                        nTopics++
                        if tp.title == "" {
                                t.Fatalf("GST 101 topic has no title")
                        }
                }
        }
        if nTopics < 1 {
                t.Fatalf("GST 101 should carry its real topics from the master sheet, got %d", nTopics)
        }
        // No bogus safety-net departments from the GST sheet may exist.
        for id, d := range depts {
                if strings.HasPrefix(d.itype, "Core for all programmes") {
                        t.Fatalf("bogus department %q (%s) leaked into the seed", id, d.itype)
                }
        }
        // The master rows are deduplicated by title (founder directive
        // 2026-10-21: one course per title, in its origin department).
        // Every CRS id stays unique and no two courses share a folded
        // title; the cleaned sheet carries ~3.9k canonical courses.
        nCRS := 0
        seenTitle := map[string]string{}
        for _, c := range courseList {
                if strings.HasPrefix(c.id, "CRS-") {
                        nCRS++
                        key := normSeedTitle(c.title)
                        if prev, ok := seenTitle[key]; ok {
                                t.Fatalf("duplicate title %q: %s and %s", c.title, prev, c.id)
                        }
                        seenTitle[key] = c.id
                }
        }
        if nCRS < 3000 {
                t.Fatalf("master rows lost: only %d CRS courses", nCRS)
        }
        if len(seenTitle) != nCRS {
                t.Fatalf("title fold collapsed %d CRS courses into %d titles", nCRS, len(seenTitle))
        }
}
