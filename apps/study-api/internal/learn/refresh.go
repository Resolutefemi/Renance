// refresh.go - the secondary curriculum refresh (founder directive
// 2026-10-17: "10 topics under each unit, and there should be 30 units
// under each course"). The JAMB roadmaps were authored out to 30 units
// x 10 topics = 300 topics per subject. SeedIfEmpty only fills an empty
// database, so populated databases are upgraded here: every SEC-JAMB
// topic row is UPSERTED (existing topic IDs keep their identity, so a
// student's progress and cached lessons survive; new topics append),
// unit titles land in learn.course_sections so the ladder shows real
// captions, and a seed_meta version row makes later boots instant.
package learn

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
)

// secondarySeedVersion bumps whenever the embedded roadmaps change in
// a way the database must absorb.
const secondarySeedVersion = "jamb-30x10-v1"

// RefreshSecondary upgrades populated databases to the current
// secondary roadmaps. Safe to call at every boot: the version marker
// short-circuits after the first run.
func RefreshSecondary(ctx context.Context, q querier, log *slog.Logger) error {
	var version string
	err := q.QueryRow(ctx, `SELECT value FROM learn.seed_meta WHERE key='secondary'`).Scan(&version)
	if err == nil && version == secondarySeedVersion {
		return nil
	}

	subs, err := loadSecondary()
	if err != nil {
		return err
	}
	_, _, topics, unitTitles := collectSecondary(subs)

	// Upsert every secondary topic: identity preserved, ladder updated.
	for start := 0; start < len(topics); start += 1000 {
		end := min(start+1000, len(topics))
		b := &strings.Builder{}
		args := make([]any, 0, (end-start)*8)
		b.WriteString("INSERT INTO learn.units (unit_id, course_id, seq, title, category, section, keywords, figures) VALUES ")
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
		b.WriteString(` ON CONFLICT (unit_id) DO UPDATE SET
			seq      = EXCLUDED.seq,
			title    = EXCLUDED.title,
			category = EXCLUDED.category,
			section  = EXCLUDED.section,
			keywords = EXCLUDED.keywords,
			figures  = EXCLUDED.figures`)
		if _, err := q.Exec(ctx, b.String(), args...); err != nil {
			return fmt.Errorf("learn: refresh secondary topics: %w", err)
		}
	}

	// Unit titles: the ladder reads these captions first.
	const unitStmt = `INSERT INTO learn.course_sections (course_id, section, title) VALUES ($1,$2,$3)
		ON CONFLICT (course_id, section) DO UPDATE SET title = EXCLUDED.title`
	for courseID, titles := range unitTitles {
		for u, title := range titles {
			if strings.TrimSpace(title) == "" {
				continue
			}
			if _, err := q.Exec(ctx, unitStmt, courseID, u+1, strings.TrimSpace(title)); err != nil {
				return fmt.Errorf("learn: refresh unit titles %s#%d: %w", courseID, u+1, err)
			}
		}
	}

	if _, err := q.Exec(ctx, `INSERT INTO learn.seed_meta (key, value, updated_at) VALUES ('secondary', $1, now())
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`, secondarySeedVersion); err != nil {
		return fmt.Errorf("learn: refresh seed_meta: %w", err)
	}

	if log != nil {
		log.Info("learn: secondary curriculum refreshed", "version", secondarySeedVersion,
			"topics", len(topics), "courses_with_unit_titles", len(unitTitles))
	}
	return nil
}
