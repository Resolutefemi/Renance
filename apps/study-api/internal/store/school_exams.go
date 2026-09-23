// Exam-question bank store. Questions live in a per-school pool keyed
// by subject + term + session + band. Publishing an exam pins a paper
// for one class: the composition (class, subject, term, how many
// questions, duration) is stored, and the paper endpoint draws that
// many questions from the matching pool at print time.

package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"renance.dev/study-api/internal/school"
)

// SchoolExamQuestion is one bank entry: a multiple-choice question
// with its options, the zero-based answer index, explanation, marks
// and the source tag (renance-original or an import tag).
type SchoolExamQuestion struct {
	ID          string   `json:"id"`
	SchoolID    string   `json:"-"`
	SubjectID   string   `json:"subjectId"`
	SubjectName string   `json:"subjectName"`
	Band        string   `json:"band"`
	Term        int      `json:"term"`
	Session     string   `json:"session"`
	Question    string   `json:"question"`
	Options     []string `json:"options"`
	AnswerIndex int      `json:"answerIndex"`
	Explanation string   `json:"explanation"`
	Marks       int      `json:"marks"`
	Source      string   `json:"source"`
}

// SchoolExam is one published paper.
type SchoolExam struct {
	ID              string `json:"id"`
	SchoolID        string `json:"-"`
	ClassID         string `json:"classId"`
	ClassName       string `json:"className"`
	SubjectID       string `json:"subjectId"`
	SubjectName     string `json:"subjectName"`
	Term            int    `json:"term"`
	Session         string `json:"session"`
	Title           string `json:"title"`
	DurationMinutes int    `json:"durationMinutes"`
	QuestionCount   int    `json:"questionCount"`
	Status          string `json:"status"`
}

// CountExamQuestions sizes a pool before an add or a publish.
func (s *Store) CountExamQuestions(ctx context.Context, schoolID, subjectID string, term int, session, band string) (int, error) {
	var n int
	err := s.Pool.QueryRow(ctx, `
                SELECT count(*) FROM school.exam_questions
                WHERE school_id = $1 AND subject_id = $2 AND term = $3
                  AND session = $4 AND ($5 = '' OR band = $5)`,
		schoolID, subjectID, term, session, band,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("store: count exam questions: %w", err)
	}
	return n, nil
}

// AddExamQuestion inserts one bank question. A verbatim duplicate for
// the same subject+term is refused so double-taps never inflate the
// pool; the existing row's id comes back instead.
func (s *Store) AddExamQuestion(ctx context.Context, q *SchoolExamQuestion) (*SchoolExamQuestion, error) {
	var existing string
	err := s.Pool.QueryRow(ctx, `
		SELECT id::text FROM school.exam_questions
		WHERE school_id = $1 AND subject_id = $2 AND term = $3 AND question = $4
		LIMIT 1`,
		q.SchoolID, q.SubjectID, q.Term, q.Question,
	).Scan(&existing)
	if err == nil {
		q.ID = existing
		return q, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("store: exam dedupe: %w", err)
	}
	opts, err := json.Marshal(q.Options)
	if err != nil {
		return nil, fmt.Errorf("store: exam options marshal: %w", err)
	}
	err = s.Pool.QueryRow(ctx, `
                INSERT INTO school.exam_questions
                      (school_id, subject_id, band, term, session, question, options,
                       answer_index, explanation, marks, source)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING id, school_id::text`,
		q.SchoolID, q.SubjectID, q.Band, q.Term, q.Session, q.Question,
		string(opts), q.AnswerIndex, q.Explanation, q.Marks, q.Source,
	).Scan(&q.ID, &q.SchoolID)
	if err != nil {
		return nil, fmt.Errorf("store: add exam question: %w", err)
	}
	return q, nil
}

// ListExamQuestions pours a pool, oldest first, capped at 500 so a
// fat bank cannot drag the portal.
func (s *Store) ListExamQuestions(ctx context.Context, schoolID, subjectID string, term int, session, band string) ([]SchoolExamQuestion, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT q.id, q.school_id::text, q.subject_id::text, COALESCE(su.name, ''),
                       q.band, q.term, q.session, q.question, q.options, q.answer_index,
                       q.explanation, q.marks, q.source
                FROM school.exam_questions q
                LEFT JOIN school.subjects su ON su.id = q.subject_id
                WHERE q.school_id = $1 AND q.subject_id = $2 AND q.term = $3
                  AND q.session = $4 AND ($5 = '' OR q.band = $5)
                ORDER BY q.created_at
                LIMIT 500`,
		schoolID, subjectID, term, session, band)
	if err != nil {
		return nil, fmt.Errorf("store: list exam questions: %w", err)
	}
	defer rows.Close()
	return scanExamQuestions(rows)
}

// DeleteExamQuestion removes one bank question the caller owns.
func (s *Store) DeleteExamQuestion(ctx context.Context, schoolID, questionID string) (bool, error) {
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM school.exam_questions WHERE id = $1 AND school_id = $2`,
		questionID, schoolID)
	if err != nil {
		return false, fmt.Errorf("store: delete exam question: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// PublishExam pins a paper row for a class + subject + term. Republish
// with a different count updates the existing paper (unique key).
func (s *Store) PublishExam(ctx context.Context, e *SchoolExam, createdBy string) (*SchoolExam, error) {
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.exams
                      (school_id, class_id, subject_id, term, session, title,
                       duration_minutes, question_count, status, created_by)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'published', NULLIF($9,'')::uuid)
                ON CONFLICT (class_id, subject_id, term, session)
                DO UPDATE SET title = EXCLUDED.title,
                              duration_minutes = EXCLUDED.duration_minutes,
                              question_count = EXCLUDED.question_count,
                              status = 'published'
                RETURNING id, school_id::text`,
		e.SchoolID, e.ClassID, e.SubjectID, e.Term, e.Session, e.Title,
		e.DurationMinutes, e.QuestionCount, createdBy,
	).Scan(&e.ID, &e.SchoolID)
	if err != nil {
		return nil, fmt.Errorf("store: publish exam: %w", err)
	}
	return e, nil
}

// ListExams returns the published papers of a session, newest first.
func (s *Store) ListExams(ctx context.Context, schoolID string, term int, session string) ([]SchoolExam, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT e.id, e.school_id::text, e.class_id::text, COALESCE(c.name, ''),
                       e.subject_id::text, COALESCE(su.name, ''),
                       e.term, e.session, e.title, e.duration_minutes, e.question_count, e.status
                FROM school.exams e
                LEFT JOIN school.classes c ON c.id = e.class_id
                LEFT JOIN school.subjects su ON su.id = e.subject_id
                WHERE e.school_id = $1 AND e.term = $2 AND e.session = $3
                ORDER BY e.created_at DESC`,
		schoolID, term, session)
	if err != nil {
		return nil, fmt.Errorf("store: list exams: %w", err)
	}
	defer rows.Close()

	var out []SchoolExam
	for rows.Next() {
		var e SchoolExam
		if err := rows.Scan(&e.ID, &e.SchoolID, &e.ClassID, &e.ClassName,
			&e.SubjectID, &e.SubjectName, &e.Term, &e.Session, &e.Title,
			&e.DurationMinutes, &e.QuestionCount, &e.Status); err != nil {
			return nil, fmt.Errorf("store: list exams scan: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ExamPaper draws the bank questions behind a published paper. The
// draw is random per request but capped at the paper's question_count,
// so a print run is self-consistent; marks sum to the total score.
func (s *Store) ExamPaper(ctx context.Context, schoolID, examID string) (*SchoolExam, []SchoolExamQuestion, error) {
	var (
		e         SchoolExam
		classID   string
		subjectID string
		count     int
	)
	err := s.Pool.QueryRow(ctx, `
                SELECT e.id, e.school_id::text, e.class_id::text, e.subject_id::text,
                       e.term, e.session, e.title, e.duration_minutes, e.question_count, e.status,
                       COALESCE(c.name, ''), COALESCE(su.name, '')
                FROM school.exams e
                LEFT JOIN school.classes c ON c.id = e.class_id
                LEFT JOIN school.subjects su ON su.id = e.subject_id
                WHERE e.id = $1 AND e.school_id = $2`,
		examID, schoolID,
	).Scan(&e.ID, &e.SchoolID, &classID, &subjectID,
		&e.Term, &e.Session, &e.Title, &e.DurationMinutes, &count, &e.Status,
		&e.ClassName, &e.SubjectName)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, nil
	}
	if err != nil {
		return nil, nil, fmt.Errorf("store: exam paper: %w", err)
	}
	e.ClassID, e.SubjectID, e.QuestionCount = classID, subjectID, count

	// The class band picks the pool: senior classes draw senior-tagged
	// questions when the bank has them, else any band.
	rows, err := s.Pool.Query(ctx, `
                WITH band AS (
                        SELECT CASE WHEN c.name LIKE 'Primary%' THEN 'primary'
                                    WHEN c.name LIKE 'JSS%' THEN 'junior'
                                    ELSE 'senior' END AS b
                        FROM school.classes c WHERE c.id = $3
                )
                SELECT q.id, q.school_id::text, q.subject_id::text, COALESCE(su.name, ''),
                       q.band, q.term, q.session, q.question, q.options, q.answer_index,
                       q.explanation, q.marks, q.source
                FROM school.exam_questions q
                JOIN band ON true
                LEFT JOIN school.subjects su ON su.id = q.subject_id
                WHERE q.school_id = $1 AND q.subject_id = $2 AND q.term = $4 AND q.session = $5
                  AND (q.band = (SELECT b FROM band) OR q.band = '')
                ORDER BY random()
                LIMIT $6`,
		schoolID, subjectID, classID, e.Term, e.Session, count)
	if err != nil {
		return nil, nil, fmt.Errorf("store: exam paper draw: %w", err)
	}
	defer rows.Close()

	qs, err := scanExamQuestions(rows)
	if err != nil {
		return nil, nil, err
	}
	return &e, qs, nil
}

// SeedExamBank pours the original starter questions into a school's
// pool. Subject codes resolve against the school's own subjects
// (installed by the curriculum seed); a question already present, same
// subject + term + question text, is skipped, so re-seeding is safe.
func (s *Store) SeedExamBank(ctx context.Context, schoolID string) (int, error) {
	// Resolve code -> subject id for this school.
	subjectIDs := map[string]string{}
	rows, err := s.Pool.Query(ctx, `
                SELECT code, id::text FROM school.subjects WHERE school_id = $1`, schoolID)
	if err != nil {
		return 0, fmt.Errorf("store: seed exam subjects: %w", err)
	}
	for rows.Next() {
		var code, id string
		if err := rows.Scan(&code, &id); err != nil {
			rows.Close()
			return 0, fmt.Errorf("store: seed exam subjects scan: %w", err)
		}
		subjectIDs[code] = id
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, fmt.Errorf("store: seed exam subjects rows: %w", err)
	}

	poured := 0
	for _, q := range school.ExamBank() {
		subjectID, ok := subjectIDs[q.SubjectCode]
		if !ok {
			continue
		}
		var exists bool
		if err := s.Pool.QueryRow(ctx, `
                        SELECT EXISTS (
                                SELECT 1 FROM school.exam_questions
                                WHERE school_id = $1 AND subject_id = $2 AND term = $3 AND question = $4
                        )`, schoolID, subjectID, q.Term, q.Question,
		).Scan(&exists); err != nil {
			return poured, fmt.Errorf("store: seed exam exists: %w", err)
		}
		if exists {
			continue
		}
		opts, err := json.Marshal(q.Options)
		if err != nil {
			return poured, fmt.Errorf("store: seed exam options: %w", err)
		}
		if _, err := s.Pool.Exec(ctx, `
                        INSERT INTO school.exam_questions
                              (school_id, subject_id, band, term, session, question, options,
                               answer_index, explanation, marks, source)
                        VALUES ($1, $2, $3, $4, '', $5, $6, $7, $8, 1, 'renance-original')`,
			schoolID, subjectID, q.Band, q.Term, q.Question, string(opts), q.AnswerIndex, q.Explanation,
		); err != nil {
			return poured, fmt.Errorf("store: seed exam insert: %w", err)
		}
		poured++
	}
	return poured, nil
}

// scanExamQuestions is the shared row scanner for the bank.
func scanExamQuestions(rows pgx.Rows) ([]SchoolExamQuestion, error) {
	var out []SchoolExamQuestion
	for rows.Next() {
		var (
			q       SchoolExamQuestion
			options []byte
		)
		if err := rows.Scan(&q.ID, &q.SchoolID, &q.SubjectID, &q.SubjectName,
			&q.Band, &q.Term, &q.Session, &q.Question, &options, &q.AnswerIndex,
			&q.Explanation, &q.Marks, &q.Source); err != nil {
			return nil, fmt.Errorf("store: exam question scan: %w", err)
		}
		if len(options) > 0 {
			if err := json.Unmarshal(options, &q.Options); err != nil {
				return nil, fmt.Errorf("store: exam options unmarshal: %w", err)
			}
		}
		out = append(out, q)
	}
	return out, rows.Err()
}

// SeedSchemes fills empty schemes of work for a session from the
// NERDC-aligned seed table. Matching runs on subject code so custom
// subject names still resolve. Rows already present are never touched.
func (s *Store) SeedSchemes(ctx context.Context, schoolID, session string) (int, error) {
	if strings.TrimSpace(session) == "" {
		return 0, errors.New("session is required")
	}
	// code -> subject id
	codeIDs := map[string]string{}
	rows, err := s.Pool.Query(ctx, `SELECT code, id::text FROM school.subjects WHERE school_id = $1`, schoolID)
	if err != nil {
		return 0, fmt.Errorf("store: scheme seed subjects: %w", err)
	}
	for rows.Next() {
		var code, id string
		if err := rows.Scan(&code, &id); err != nil {
			rows.Close()
			return 0, fmt.Errorf("store: scheme seed subjects scan: %w", err)
		}
		codeIDs[code] = id
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, fmt.Errorf("store: scheme seed subjects rows: %w", err)
	}

	// Walk every class+subject pair, resolve its subject code, and
	// draft the scheme wherever a term's scheme is still empty.
	pairs, err := s.Pool.Query(ctx, `
		SELECT cs.class_id::text, cs.subject_id::text
		FROM school.class_subjects cs
		WHERE cs.school_id = $1`, schoolID)
	if err != nil {
		return 0, fmt.Errorf("store: scheme seed pairs: %w", err)
	}
	type pair struct{ classID, subjectID string }
	var plist []pair
	for pairs.Next() {
		var pr pair
		if err := pairs.Scan(&pr.classID, &pr.subjectID); err != nil {
			pairs.Close()
			return 0, fmt.Errorf("store: scheme seed pairs scan: %w", err)
		}
		plist = append(plist, pr)
	}
	pairs.Close()
	if err := pairs.Err(); err != nil {
		return 0, fmt.Errorf("store: scheme seed pairs rows: %w", err)
	}

	idCodes := map[string]string{}
	for code, id := range codeIDs {
		idCodes[id] = code
	}

	filled := 0
	for _, pr := range plist {
		code, ok := idCodes[pr.subjectID]
		if !ok {
			continue
		}
		terms, ok := school.SchemeSeeds[code]
		if !ok {
			continue
		}
		for term, topics := range terms {
			syl, err := s.EnsureSyllabus(ctx, schoolID, pr.classID, pr.subjectID, term, session)
			if err != nil || syl == nil {
				continue
			}
			if len(syl.SchemeOfWork) > 0 && string(syl.SchemeOfWork) != "[]" && string(syl.SchemeOfWork) != "null" {
				continue
			}
			scheme := make([]map[string]any, 0, len(topics))
			for i, t := range topics {
				scheme = append(scheme, map[string]any{
					"week":  i + 1,
					"topic": t,
				})
			}
			raw, err := json.Marshal(scheme)
			if err != nil {
				continue
			}
			if err := s.UpdateSchemeOfWork(ctx, syl.ID, raw, ""); err != nil {
				return filled, fmt.Errorf("store: scheme seed write: %w", err)
			}
			filled++
		}
	}
	return filled, nil
}
