// synthgen - the agent's bulk pre generation runner (founder directive
// 2026-10-16: "you have to generate all the 10,000+ tertiary courses
// content, the notes and the quiz ... all the notes and quizzes should
// be cached to Supabase as you generate them").
//
// Phase structure: grows every tertiary course to the full 15 unit x
// 10 topic ladder (learn.course_units + learn.topics), deterministic
// per course via the synth engine - identical to what the API would
// expand on demand, so the two can never disagree.
//
// Phase lessons: synthesizes the deep lesson (10 long reading sections
// + 20 questions, 10 easy + 10 hard) for every topic that has no
// cached lesson yet and upserts it into learn.lessons with source
// 'agent-v1'. Breadth first by unit so the topics students open FIRST
// (unit 1 everywhere) are cached first.
//
// Storage aware: the runner stops gracefully when the database size
// crosses cap-mb (Supabase free tier is 500 MB; the API synthesizes
// on open regardless, so an uncached topic is a speed detail, never a
// missing lesson).
//
// Idempotent and resumable: every insert is ON CONFLICT aware, so the
// runner can be killed and rerun at any time, and the GitHub Actions
// workflow can continue after this session ends.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"renance.dev/study-api/internal/learn/synth"
)

func main() {
	var (
		phase    = flag.String("phase", "all", "all | structure | lessons | retitles")
		workers  = flag.Int("workers", 8, "parallel workers")
		limit    = flag.Int("limit", 0, "max lessons to write this run (0 = until storage cap)")
		capMB    = flag.Int("cap-mb", 470, "stop when pg_database_size exceeds this many MB")
		course   = flag.String("courses", "", "only courses whose course_id starts with this prefix (debug)")
		capUnits = flag.Int("units", 15, "units per course in the structure phase")
	)
	flag.Parse()

	// TWO POOLS since the split-horizon databases (founder directive
	// 2026-10-16: "Supabase should only hold the courses, topics and
	// units"): the catalog pool (CONTENT_DATABASE_URL, Supabase - the
	// courses/topics/units reads AND the structure-phase writes) and the
	// cache pool (DATABASE_URL, InsForge - the learn.lessons writes and
	// the storage cap). CONTENT_DATABASE_URL unset degrades to one pool
	// against DATABASE_URL, exactly the pre-split single-pool behaviour.
	cacheDSN := os.Getenv("DATABASE_URL")
	if cacheDSN == "" {
		cacheDSN = os.Getenv("CACHE_DATABASE_URL")
	}
	if cacheDSN == "" {
		cacheDSN = os.Getenv("INSFORGE_DATABASE_URL")
	}
	if cacheDSN == "" {
		log.Fatal("synthgen: set DATABASE_URL (the lesson cache DSN, InsForge)")
	}
	contentDSN := os.Getenv("CONTENT_DATABASE_URL")
	if contentDSN == "" {
		contentDSN = os.Getenv("SUPABASE_DATABASE_URL")
	}
	if contentDSN == "" {
		contentDSN = cacheDSN // single-pool degradation
	}

	newPool := func(dsn string) *pgxpool.Pool {
		cfg, err := pgxpool.ParseConfig(dsn)
		if err != nil {
			log.Fatalf("synthgen: parse dsn: %v", err)
		}
		cfg.MaxConns = int32(*workers + 4)
		cfg.MinConns = 2
		cfg.MaxConnLifetime = 30 * time.Minute
		// Supabase pooler certificates do not carry the host SAN on every
		// region build, so pin the ServerName to the DSN host itself
		if cfg.ConnConfig.TLSConfig != nil {
			cfg.ConnConfig.TLSConfig.ServerName = cfg.ConnConfig.Host
		}
		pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
		if err != nil {
			log.Fatalf("synthgen: pool: %v", err)
		}
		return pool
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	pool := newPool(cacheDSN)
	defer pool.Close()
	var cpool *pgxpool.Pool
	if contentDSN == cacheDSN {
		cpool = pool
	} else {
		cpool = newPool(contentDSN)
		defer cpool.Close()
	}

	var dbMB int
	if err := pool.QueryRow(ctx, `SELECT pg_database_size(current_database())/1048576`).Scan(&dbMB); err != nil {
		log.Fatalf("synthgen: size check: %v", err)
	}
	log.Printf("synthgen: connected; lesson cache is at %d MB (cap %d MB)", dbMB, *capMB)
	if cpool != pool {
		var cMB int
		if err := cpool.QueryRow(ctx, `SELECT pg_database_size(current_database())/1048576`).Scan(&cMB); err == nil {
			log.Printf("synthgen: catalog database is at %d MB", cMB)
		}
	}

	g := &runner{pool: pool, cpool: cpool, capMB: *capMB, limit: *limit, course: *course, units: *capUnits}
	if *phase != "retitles" && dbMB >= g.capMB {
		log.Printf("synthgen: storage cap already reached; nothing to do")
		return
	}

	start := time.Now()
	if *phase == "retitles" {
		g.runRetitles(ctx, *workers)
	}
	if *phase == "all" || *phase == "structure" {
		g.runStructure(ctx, *workers)
	}
	if *phase == "all" || *phase == "lessons" {
		g.runLessons(ctx, *workers)
	}
	log.Printf("synthgen: done in %s", time.Since(start).Round(time.Second))
}

type runner struct {
	pool   *pgxpool.Pool // the lesson cache (InsForge): learn.lessons reads/writes + the cap
	cpool  *pgxpool.Pool // the catalog (Supabase): courses/topics/units reads + structure writes; == pool when no CONTENT_DATABASE_URL
	capMB  int
	limit  int
	course string
	units  int
}

/* ------------------------- structure phase ------------------------ */

type courseRow struct {
	id, title, dept, faculty string
}

func (r *runner) sizeMB(ctx context.Context) int {
	var mb int
	_ = r.pool.QueryRow(ctx, `SELECT pg_database_size(current_database())/1048576`).Scan(&mb)
	return mb
}

func (r *runner) runStructure(ctx context.Context, workers int) {
	rows, err := r.cpool.Query(ctx, `
                SELECT c.course_id, c.title, COALESCE(d.name,''), COALESCE(d.faculty,'')
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary'
                ORDER BY c.course_id`)
	if err != nil {
		log.Fatalf("synthgen: courses query: %v", err)
	}
	defer rows.Close()
	courses := []courseRow{}
	for rows.Next() {
		var c courseRow
		if err := rows.Scan(&c.id, &c.title, &c.dept, &c.faculty); err == nil {
			if r.course == "" || strings.HasPrefix(c.id, r.course) {
				courses = append(courses, c)
			}
		}
	}
	log.Printf("synthgen: structure phase over %d courses", len(courses))

	var done, grown atomic.Int64
	ch := make(chan courseRow, workers*2)
	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for c := range ch {
				if r.sizeMB(ctx) >= r.capMB {
					return
				}
				n, err := r.structureCourse(ctx, c)
				if err != nil {
					log.Printf("synthgen: structure %s: %v", c.id, err)
					continue
				}
				grown.Add(int64(n))
				if done.Add(1)%500 == 0 {
					log.Printf("synthgen: structure %d/%d courses (+%d rows, db %d MB)",
						done.Load(), len(courses), grown.Load(), r.sizeMB(ctx))
				}
			}
		}()
	}
	for _, c := range courses {
		ch <- c
	}
	close(ch)
	wg.Wait()
	log.Printf("synthgen: structure phase complete: %d courses, %d new rows, db %d MB",
		done.Load(), grown.Load(), r.sizeMB(ctx))
}

// structureCourse tops one course up to the full unit ladder using
// batched multi row writes (one round trip per statement group: a
// single row insert loop costs ~30s per course over the pooler, the
// batched form costs ~1s for the whole course).
func (r *runner) structureCourse(ctx context.Context, c courseRow) (int, error) {
	// existing coverage and the next free sequence number, one query
	// (catalog pool: the structure phase owns the unit ladder)
	cover := map[int]int{}
	maxSeq := 0
	rows, err := r.cpool.Query(ctx,
		`SELECT unit, COUNT(*), MAX(seq) FROM learn.topics WHERE course_id=$1 GROUP BY unit`, c.id)
	if err != nil {
		return 0, err
	}
	for rows.Next() {
		var u, n int
		var m *int
		if err := rows.Scan(&u, &n, &m); err == nil {
			cover[u] = n
			if m != nil && *m > maxSeq {
				maxSeq = *m
			}
		}
	}
	rows.Close()

	type planRow struct {
		unit, pos  int
		title, cat string
	}
	var unitRows []int
	var unitTitles []string
	var topicRows []planRow

	total := 0
	for u := 2; u <= r.units; u++ {
		if cover[u] >= 10 {
			continue
		}
		title, tops := synth.UnitPlan(c.id, c.title, c.dept, c.faculty, u)
		unitRows = append(unitRows, u)
		unitTitles = append(unitTitles, title)
		skip := cover[u] // deterministic plan: skip positions already stored
		for i := skip; i < len(tops); i++ {
			topicRows = append(topicRows, planRow{unit: u, pos: i + 1, title: tops[i].Title, cat: tops[i].Category})
			total++
		}
	}
	if total == 0 {
		return 0, nil
	}

	batch := &pgx.Batch{}
	if len(unitRows) > 0 {
		var sb strings.Builder
		sb.WriteString(`INSERT INTO learn.course_units (course_id, unit, title) VALUES `)
		args := make([]any, 0, len(unitRows)*3)
		for i, u := range unitRows {
			if i > 0 {
				sb.WriteString(",")
			}
			sb.WriteString(fmt.Sprintf("($%d,$%d,$%d)", i*3+1, i*3+2, i*3+3))
			args = append(args, c.id, u, unitTitles[i])
		}
		sb.WriteString(` ON CONFLICT (course_id, unit) DO NOTHING`)
		batch.Queue(sb.String(), args...)
	}
	if len(topicRows) > 0 {
		var sb strings.Builder
		sb.WriteString(`INSERT INTO learn.topics (topic_id, course_id, seq, title, category, unit, keywords) VALUES `)
		args := make([]any, 0, len(topicRows)*6)
		for i, tr := range topicRows {
			if i > 0 {
				sb.WriteString(",")
			}
			base := i * 6
			sb.WriteString(fmt.Sprintf("($%d,$%d,$%d,$%d,$%d,$%d,'{}')", base+1, base+2, base+3, base+4, base+5, base+6))
			maxSeq++
			tid := fmt.Sprintf("%s-EU%02d%02d", c.id, tr.unit, tr.pos)
			args = append(args, tid, c.id, maxSeq, tr.title, tr.cat, tr.unit)
		}
		sb.WriteString(` ON CONFLICT (topic_id) DO NOTHING`)
		batch.Queue(sb.String(), args...)
	}
	if err := r.cpool.SendBatch(ctx, batch).Close(); err != nil {
		return total, err
	}
	return total, nil
}

/* -------------------------- lessons phase ------------------------- */

type topicRow struct {
	id, title, courseID, course, dept, faculty string
	unit                                       int
}

func (r *runner) runLessons(ctx context.Context, workers int) {
	var written atomic.Int64
	stop := atomic.Bool{}
	start := time.Now()

	// Pipeline: dispatchers stream topic rows, workers synthesize
	// (pure CPU), a single writer assembles multi row INSERTs (25
	// lessons per statement) because one INSERT per lesson over the
	// pooler is latency bound at ~25 lessons/s; the batched form runs
	// several times faster.
	type docRow struct {
		tid, title, summary, notes, kp, quiz string
	}
	topicCh := make(chan topicRow, workers*4)
	docCh := make(chan docRow, workers*4)
	var wg sync.WaitGroup
	var wsync sync.WaitGroup

	for w := 0; w < workers; w++ {
		wsync.Add(1)
		go func() {
			defer wsync.Done()
			for t := range topicCh {
				if stop.Load() {
					continue
				}
				out := synth.BuildLesson(t.id, t.course, t.dept, t.faculty, t.title, t.unit)
				notes, _ := json.Marshal(out.Notes)
				kp, _ := json.Marshal(out.KeyPoints)
				quiz, _ := json.Marshal(out.Quiz)
				docCh <- docRow{tid: t.id, title: out.Title, summary: out.Summary,
					notes: string(notes), kp: string(kp), quiz: string(quiz)}
			}
		}()
	}
	wg.Add(1)
	go func() {
		defer wg.Done()
		wsync.Wait()
		close(docCh)
	}()

	wg.Add(1)
	go func() {
		defer wg.Done()
		const batchN = 25
		var buf []docRow
		flush := func() {
			if len(buf) == 0 {
				return
			}
			var sb strings.Builder
			sb.WriteString(`INSERT INTO learn.lessons (topic_id, title, summary, notes, key_points, quiz, drawings, source) VALUES `)
			args := make([]any, 0, batchN*6)
			for i, d := range buf {
				if i > 0 {
					sb.WriteString(",")
				}
				b := i * 6
				sb.WriteString(fmt.Sprintf("($%d,$%d,$%d,$%d::jsonb,$%d::jsonb,$%d::jsonb,'[]'::jsonb,'agent-v1')",
					b+1, b+2, b+3, b+4, b+5, b+6))
				args = append(args, d.tid, d.title, d.summary, d.notes, d.kp, d.quiz)
			}
			sb.WriteString(` ON CONFLICT (topic_id) DO UPDATE SET title=excluded.title, summary=excluded.summary,
                          notes=excluded.notes, key_points=excluded.key_points, quiz=excluded.quiz, source='agent-v1', generated_at=now()`)
			if _, err := r.pool.Exec(ctx, sb.String(), args...); err != nil {
				if isStorageErr(err) {
					log.Printf("synthgen: storage cap hit (%v); stopping lessons phase", err)
					stop.Store(true)
				} else {
					log.Printf("synthgen: batch insert: %v", err)
				}
			} else {
				n := written.Add(int64(len(buf)))
				if n%1000 < batchN {
					log.Printf("synthgen: lessons %d written in %s (db %d MB)",
						n, time.Since(start).Round(time.Second), r.sizeMB(ctx))
				}
				if n%500 < batchN && r.sizeMB(ctx) >= r.capMB {
					log.Printf("synthgen: storage cap reached at %d MB", r.capMB)
					stop.Store(true)
				}
				if r.limit > 0 && int(n) >= r.limit {
					stop.Store(true)
				}
			}
			buf = buf[:0]
		}
		for d := range docCh {
			if stop.Load() {
				continue
			}
			buf = append(buf, d)
			if len(buf) >= batchN {
				flush()
			}
		}
		flush()
	}()

	// breadth first: unit 1 everywhere first (the entry topics), then
	// unit 2, and so on to unit 15
	for u := 1; u <= r.units && !stop.Load(); u++ {
		batch := 2000
		after := ""
		for {
			if stop.Load() {
				break
			}
			// Catalog pool reads the candidate topics; the
			// cached ones are filtered two-step (cache pool
			// ANY($1) probe below) because learn.lessons lives
			// on another database now - the old NOT EXISTS
			// join would cross the pools.
			q := `
                                SELECT t.topic_id, t.title, t.course_id, c.title, COALESCE(d.name,''), COALESCE(d.faculty,''), t.unit
                                FROM learn.topics t
                                JOIN learn.courses c ON c.course_id = t.course_id
                                JOIN learn.departments d ON d.dept_id = c.dept_id
                                WHERE t.unit = $1`
			args := []any{u}
			if r.course != "" {
				q += ` AND t.course_id LIKE $2`
				args = append(args, r.course+"%")
			}
			q += after + ` ORDER BY t.course_id, t.seq LIMIT ` + strconv.Itoa(batch)
			rows, err := r.cpool.Query(ctx, q, args...)
			if err != nil {
				log.Printf("synthgen: topics query unit %d: %v", u, err)
				break
			}
			var batchTopics []topicRow
			lastID := ""
			lastCourse := ""
			for rows.Next() {
				var t topicRow
				if err := rows.Scan(&t.id, &t.title, &t.courseID, &t.course, &t.dept, &t.faculty, &t.unit); err == nil {
					batchTopics = append(batchTopics, t)
					lastCourse = t.courseID
					lastID = t.id
				}
			}
			rows.Close()
			// Two-step cache check: which of the candidates
			// already have a lesson on the cache pool.
			cached := map[string]bool{}
			if len(batchTopics) > 0 {
				ids := make([]string, len(batchTopics))
				for i, t := range batchTopics {
					ids[i] = t.id
				}
				crows, cerr := r.pool.Query(ctx, `SELECT topic_id FROM learn.lessons WHERE topic_id = ANY($1)`, ids)
				if cerr == nil {
					for crows.Next() {
						var tid string
						if crows.Scan(&tid) == nil {
							cached[tid] = true
						}
					}
					crows.Close()
				}
			}
			n := 0
			for _, t := range batchTopics {
				if !cached[t.id] {
					topicCh <- t
					n++
				}
			}
			if n < batch {
				break // unit exhausted
			}
			// keyset pagination: continue after the last dispatched topic
			after = fmt.Sprintf(` AND (t.course_id, t.topic_id) > ('%s', '%s')`, lastCourse, lastID)
		}
		log.Printf("synthgen: unit %d dispatched (db %d MB)", u, r.sizeMB(ctx))
	}
	close(topicCh)
	wg.Wait()
	log.Printf("synthgen: lessons phase complete: %d lessons, db %d MB, %s",
		written.Load(), r.sizeMB(ctx), time.Since(start).Round(time.Second))
}

/* ------------------------- retitles phase ------------------------- */

// runRetitles repairs topic and unit titles written before the pack
// routing fix (title first, dept only as fallback). The engine is
// deterministic, so each course's CORRECT titles are recomputed and
// only rows that actually differ are UPDATEd in place: no delete and
// reinsert, no bloat, and correctly routed courses cost one read.
func (r *runner) runRetitles(ctx context.Context, workers int) {
	rows, err := r.cpool.Query(ctx, `
                SELECT c.course_id, c.title, COALESCE(d.name,''), COALESCE(d.faculty,'')
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.body = 'tertiary'
                ORDER BY c.course_id`)
	if err != nil {
		log.Fatalf("synthgen: courses query: %v", err)
	}
	defer rows.Close()
	courses := []courseRow{}
	for rows.Next() {
		var c courseRow
		if err := rows.Scan(&c.id, &c.title, &c.dept, &c.faculty); err == nil {
			if r.course == "" || strings.HasPrefix(c.id, r.course) {
				courses = append(courses, c)
			}
		}
	}
	log.Printf("synthgen: retitles phase over %d courses", len(courses))

	var done, changed atomic.Int64
	ch := make(chan courseRow, workers*2)
	var wg sync.WaitGroup
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for c := range ch {
				n, err := r.retitleCourse(ctx, c)
				if err != nil {
					log.Printf("synthgen: retitle %s: %v", c.id, err)
					continue
				}
				changed.Add(int64(n))
				if done.Add(1)%1000 == 0 {
					log.Printf("synthgen: retitles %d/%d courses (%d titles updated, db %d MB)",
						done.Load(), len(courses), changed.Load(), r.sizeMB(ctx))
				}
			}
		}()
	}
	for _, c := range courses {
		ch <- c
	}
	close(ch)
	wg.Wait()
	log.Printf("synthgen: retitles phase complete: %d courses, %d titles updated, db %d MB",
		done.Load(), changed.Load(), r.sizeMB(ctx))
}

// retitleCourse recomputes one course's plans and updates the rows
// whose stored titles differ from the corrected output.
func (r *runner) retitleCourse(ctx context.Context, c courseRow) (int, error) {
	// stored titles per unit, one query, seq order maps to plan order
	stored := map[int][]struct {
		id, title string
		unit      int
	}{}
	rows, err := r.cpool.Query(ctx,
		`SELECT topic_id, title, unit FROM learn.topics WHERE course_id=$1 AND unit >= 2 ORDER BY unit, seq`, c.id)
	if err != nil {
		return 0, err
	}
	for rows.Next() {
		var id, title string
		var u int
		if err := rows.Scan(&id, &title, &u); err == nil {
			stored[u] = append(stored[u], struct {
				id, title string
				unit      int
			}{id, title, u})
		}
	}
	rows.Close()
	unitTitles := map[int]string{}
	urows, err := r.cpool.Query(ctx, `SELECT unit, title FROM learn.course_units WHERE course_id=$1`, c.id)
	if err == nil {
		for urows.Next() {
			var u int
			var t string
			if err := urows.Scan(&u, &t); err == nil {
				unitTitles[u] = t
			}
		}
		urows.Close()
	}

	batch := &pgx.Batch{}
	updates := 0
	for u := 2; u <= r.units; u++ {
		title, tops := synth.UnitPlan(c.id, c.title, c.dept, c.faculty, u)
		if st, ok := unitTitles[u]; ok && st != title {
			batch.Queue(`UPDATE learn.course_units SET title=$2 WHERE course_id=$1 AND unit=$3`, c.id, title, u)
			updates++
		}
		sl := stored[u]
		for i, tp := range tops {
			if i >= len(sl) {
				break
			}
			if sl[i].title != tp.Title {
				batch.Queue(`UPDATE learn.topics SET title=$2, category=$3 WHERE topic_id=$1`,
					sl[i].id, tp.Title, tp.Category)
				updates++
			}
		}
	}
	if updates == 0 {
		return 0, nil
	}
	if err := r.cpool.SendBatch(ctx, batch).Close(); err != nil {
		return updates, err
	}
	return updates, nil
}

func isStorageErr(err error) bool {
	if err == nil {
		return false
	}
	s := err.Error()
	return strings.Contains(s, "disk full") ||
		strings.Contains(s, "No space left") ||
		strings.Contains(s, "exceeds") ||
		strings.Contains(s, "quota") ||
		strings.Contains(s, "storage")
}
