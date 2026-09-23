// Timetable store. One row per class per weekday per period; saving a
// week is a batch of upserts inside one transaction so the grid never
// shows a half-written day. subject_id NULL + a label renders the
// non-subject blocks (assembly, break, clubs).

package store

import (
	"context"
	"fmt"
)

// TimetableSlot is one grid cell: a class, a day (1 Monday..5 Friday),
// a period number and either a subject or a free-text label.
type TimetableSlot struct {
	ID        string `json:"id"`
	SchoolID  string `json:"-"`
	ClassID   string `json:"classId"`
	Day       int    `json:"day"`
	Period    int    `json:"period"`
	StartTime string `json:"startTime"`
	EndTime   string `json:"endTime"`
	SubjectID string `json:"subjectId"`
	Label     string `json:"label"`
}

// TimetableSubject names a slot's subject for rendering.
type TimetableSubject struct {
	SubjectID   string `json:"subjectId"`
	SubjectName string `json:"subjectName"`
	Code        string `json:"code"`
}

// TimetableWeek is everything the editor needs for one class: the
// slots plus the subject list the picker offers.
type TimetableWeek struct {
	ClassID  string             `json:"classId"`
	Slots    []TimetableSlot    `json:"slots"`
	Subjects []TimetableSubject `json:"subjects"`
}

// Timetable loads one class's week. Rows are day-then-period ordered
// so the UI can lay the grid straight out of the array.
func (s *Store) Timetable(ctx context.Context, schoolID, classID string) (*TimetableWeek, error) {
	slots, err := s.timetableSlots(ctx, schoolID, classID)
	if err != nil {
		return nil, err
	}
	subjects, err := s.timetableSubjects(ctx, schoolID, classID)
	if err != nil {
		return nil, err
	}
	return &TimetableWeek{ClassID: classID, Slots: slots, Subjects: subjects}, nil
}

func (s *Store) timetableSlots(ctx context.Context, schoolID, classID string) ([]TimetableSlot, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT id, school_id::text, class_id::text, day, period,
                       start_time, end_time, COALESCE(subject_id::text, ''), label
                FROM school.timetable
                WHERE school_id = $1 AND class_id = $2
                ORDER BY day, period`, schoolID, classID)
	if err != nil {
		return nil, fmt.Errorf("store: timetable slots: %w", err)
	}
	defer rows.Close()

	var out []TimetableSlot
	for rows.Next() {
		var t TimetableSlot
		if err := rows.Scan(&t.ID, &t.SchoolID, &t.ClassID, &t.Day, &t.Period,
			&t.StartTime, &t.EndTime, &t.SubjectID, &t.Label); err != nil {
			return nil, fmt.Errorf("store: timetable slots scan: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// timetableSubjects offers the class's subject list (its class_subjects
// rows) for the slot picker; an empty class-offering falls back to the
// school catalog at the class's level band.
func (s *Store) timetableSubjects(ctx context.Context, schoolID, classID string) ([]TimetableSubject, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT su.id::text, su.name, su.code
                FROM school.class_subjects cs
                JOIN school.subjects su ON su.id = cs.subject_id
                WHERE cs.school_id = $1 AND cs.class_id = $2
                UNION ALL
                SELECT su.id::text, su.name, su.code
                FROM school.subjects su
                WHERE su.school_id = $1
                  AND NOT EXISTS (
                        SELECT 1 FROM school.class_subjects cs2
                        WHERE cs2.school_id = $1 AND cs2.class_id = $2
                  )
                  AND su.level IN (
                        SELECT CASE WHEN c.name LIKE 'Primary%' THEN 'primary'
                                    WHEN c.name LIKE 'JSS%' THEN 'junior'
                                    ELSE 'senior' END
                        FROM school.classes c WHERE c.id = $2
                  )
                ORDER BY 2`, schoolID, classID)
	if err != nil {
		return nil, fmt.Errorf("store: timetable subjects: %w", err)
	}
	defer rows.Close()

	var out []TimetableSubject
	for rows.Next() {
		var t TimetableSubject
		if err := rows.Scan(&t.SubjectID, &t.SubjectName, &t.Code); err != nil {
			return nil, fmt.Errorf("store: timetable subjects scan: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// SaveTimetable rewrites one class's week in a single transaction: the
// existing rows go, the posted grid goes in. Simpler than diffing
// cells and always leaves the week consistent.
func (s *Store) SaveTimetable(ctx context.Context, schoolID, classID string, slots []TimetableSlot) (int, error) {
	tx, err := s.Pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("store: timetable tx: %w", err)
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx,
		`DELETE FROM school.timetable WHERE school_id = $1 AND class_id = $2`,
		schoolID, classID); err != nil {
		return 0, fmt.Errorf("store: timetable clear: %w", err)
	}
	saved := 0
	for _, t := range slots {
		if t.Day < 1 || t.Day > 7 || t.Period < 1 || t.Period > 15 {
			continue
		}
		if _, err := tx.Exec(ctx, `
                        INSERT INTO school.timetable
                              (school_id, class_id, day, period, start_time, end_time, subject_id, label)
                        VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7,'')::uuid, $8)`,
			schoolID, classID, t.Day, t.Period, t.StartTime, t.EndTime, t.SubjectID, t.Label,
		); err != nil {
			return 0, fmt.Errorf("store: timetable insert: %w", err)
		}
		saved++
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("store: timetable commit: %w", err)
	}
	return saved, nil
}
