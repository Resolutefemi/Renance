// store.go — every SQL statement the learn module runs. pgx simple
// protocol (the pool is already configured for it), chunked inserts,
// structure owned by migration 0028_learn.sql.
package learn

import (
        "context"
        "fmt"
        "strings"

        
)

func insertCurriculum(ctx context.Context, q querier, depts []seedDept, courses []seedCourse, topics []seedTopic) error {
        // Departments
        for start := 0; start < len(depts); start += 500 {
                end := min(start+500, len(depts))
                b := &strings.Builder{}
                args := make([]any, 0, (end-start)*5)
                b.WriteString("INSERT INTO learn.departments (dept_id, itype, faculty, name, focus) VALUES ")
                for i := start; i < end; i++ {
                        if i > start {
                                b.WriteString(",")
                        }
                        b.WriteString(fmt.Sprintf("($%d,$%d,$%d,$%d,$%d)", len(args)+1, len(args)+2, len(args)+3, len(args)+4, len(args)+5))
                        args = append(args, depts[i].id, depts[i].itype, depts[i].faculty, depts[i].name, depts[i].focus)
                }
                b.WriteString(" ON CONFLICT (dept_id) DO NOTHING")
                if _, err := q.Exec(ctx, b.String(), args...); err != nil {
                        return fmt.Errorf("learn: seed departments: %w", err)
                }
        }

        // Courses
        for start := 0; start < len(courses); start += 1000 {
                end := min(start+1000, len(courses))
                b := &strings.Builder{}
                args := make([]any, 0, (end-start)*8)
                b.WriteString("INSERT INTO learn.courses (course_id, dept_id, code, title, level, category, body, subject) VALUES ")
                for i := start; i < end; i++ {
                        if i > start {
                                b.WriteString(",")
                        }
                        b.WriteString(fmt.Sprintf("($%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d)", len(args)+1, len(args)+2, len(args)+3, len(args)+4, len(args)+5, len(args)+6, len(args)+7, len(args)+8))
                        args = append(args, courses[i].id, courses[i].dept, courses[i].code, courses[i].title, courses[i].level, courses[i].category, courses[i].body, courses[i].subject)
                }
                b.WriteString(" ON CONFLICT (course_id) DO NOTHING")
                if _, err := q.Exec(ctx, b.String(), args...); err != nil {
                        return fmt.Errorf("learn: seed courses: %w", err)
                }
        }

        // Topics
        for start := 0; start < len(topics); start += 2000 {
                end := min(start+2000, len(topics))
                b := &strings.Builder{}
                args := make([]any, 0, (end-start)*8)
                b.WriteString("INSERT INTO learn.topics (topic_id, course_id, seq, title, category, unit, keywords, figures) VALUES ")
                for i := start; i < end; i++ {
                        if i > start {
                                b.WriteString(",")
                        }
                        b.WriteString(fmt.Sprintf("($%d,$%d,$%d,$%d,$%d,$%d,$%d,$%d)", len(args)+1, len(args)+2, len(args)+3, len(args)+4, len(args)+5, len(args)+6, len(args)+7, len(args)+8))
                        kw := topics[i].keywords
                        if kw == nil {
                                kw = []string{}
                        }
                        fg := topics[i].figures
                        if fg == nil {
                                fg = []string{}
                        }
                        args = append(args, topics[i].id, topics[i].courseID, topics[i].seq, topics[i].title, topics[i].category, topics[i].unit, kw, fg)
                }
                b.WriteString(" ON CONFLICT (topic_id) DO NOTHING")
                if _, err := q.Exec(ctx, b.String(), args...); err != nil {
                        return fmt.Errorf("learn: seed topics: %w", err)
                }
        }
        return nil
}

func min(a, b int) int {
        if a < b {
                return a
        }
        return b
}
