// ID card store. One card per student per session, serial-numbered
// per school. Issuing is idempotent (unique student + session), a lost
// card is revoked rather than deleted so the serial history stays.

package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// SchoolIDCard is one issued card. Serial is school-unique, formatted
// REN-<year>-<6 digits>.
type SchoolIDCard struct {
	ID        string    `json:"id"`
	SchoolID  string    `json:"-"`
	StudentID string    `json:"studentId"`
	Serial    string    `json:"serial"`
	Session   string    `json:"session"`
	Status    string    `json:"status"`
	IssuedBy  string    `json:"-"`
	IssuedAt  time.Time `json:"issuedAt"`
}

// IDCardRow is the printable join: card plus the student and school
// fields the card face carries.
type IDCardRow struct {
	Card          SchoolIDCard
	StudentName   string `json:"studentName"`
	AdmissionNo   string `json:"admissionNo"`
	ClassName     string `json:"className"`
	ClassID       string `json:"classId"`
	Sex           string `json:"sex"`
	DOB           string `json:"dob"`
	PhotoURL      string `json:"photoUrl"`
	GuardianPhone string `json:"guardianPhone"`
	SchoolName    string `json:"schoolName"`
	SchoolLogoURL string `json:"schoolLogoUrl"`
	Address       string `json:"address"`
}

// IssueIDCard creates (or reactivates) the card for one student. If
// the student already holds a card for the session it is flipped back
// to issued; otherwise the next sequential serial is minted.
func (s *Store) IssueIDCard(ctx context.Context, schoolID, studentID, session, issuedBy string) (*SchoolIDCard, error) {
	year := time.Now().Year()
	if session != "" {
		if tail := strings.Split(session, "/"); len(tail) == 2 {
			if y, err := fmt.Sscanf(tail[1], "%d", &year); err != nil || y == 0 {
				year = time.Now().Year()
			}
		}
	}

	scan := func(row pgx.Row) (*SchoolIDCard, error) {
		var card SchoolIDCard
		err := row.Scan(&card.ID, &card.SchoolID, &card.StudentID, &card.Serial, &card.Session,
			&card.Status, &card.IssuedBy, &card.IssuedAt)
		if err != nil {
			return nil, err
		}
		return &card, nil
	}

	// Existing card: reactivate and return it.
	card, err := scan(s.Pool.QueryRow(ctx, `
                SELECT id, school_id::text, student_id::text, serial, session, status,
                       COALESCE(issued_by::text, ''), issued_at
                FROM school.id_cards WHERE student_id = $1 AND session = $2`,
		studentID, session))
	if err == nil {
		if _, e := s.Pool.Exec(ctx,
			`UPDATE school.id_cards SET status = 'issued' WHERE id = $1`, card.ID); e != nil {
			return nil, fmt.Errorf("store: reactivate card: %w", e)
		}
		card.Status = "issued"
		return card, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("store: look up card: %w", err)
	}

	// Fresh card: next sequential serial for the school.
	var last int
	if err := s.Pool.QueryRow(ctx, `
                SELECT COALESCE(max(substring(serial from 10)::int), 0)
                FROM school.id_cards
                WHERE school_id = $1 AND serial LIKE 'REN-%'`, schoolID,
	).Scan(&last); err != nil {
		return nil, fmt.Errorf("store: next card serial: %w", err)
	}
	serial := fmt.Sprintf("REN-%d-%06d", year, last+1)

	card, err = scan(s.Pool.QueryRow(ctx, `
                INSERT INTO school.id_cards (school_id, student_id, serial, session, status, issued_by)
                VALUES ($1, $2, $3, $4, 'issued', NULLIF($5,'')::uuid)
                ON CONFLICT (student_id, session)
                DO UPDATE SET status = 'issued'
                RETURNING id, school_id::text, student_id::text, serial, session, status,
                          COALESCE(issued_by::text, ''), issued_at`,
		schoolID, studentID, serial, session, issuedBy))
	if err != nil {
		return nil, fmt.Errorf("store: issue id card: %w", err)
	}
	return card, nil
}

// IssueIDCardsBatch cards every active student in scope (a class, or
// the whole school) who does not hold one yet for the session. Existing
// cards are left alone, so re-running it only fills the gaps.
func (s *Store) IssueIDCardsBatch(ctx context.Context, schoolID, classID, session, issuedBy string) (int, error) {
	var studentIDs []string
	rows, err := s.Pool.Query(ctx, `
                SELECT st.id::text
                FROM school.students st
                WHERE st.school_id = $1 AND st.status = 'active'
                  AND ($2 = '' OR st.class_id::text = $2)
                  AND NOT EXISTS (
                        SELECT 1 FROM school.id_cards k
                        WHERE k.student_id = st.id AND k.session = $3
                  )`,
		schoolID, classID, session)
	if err != nil {
		return 0, fmt.Errorf("store: batch card candidates: %w", err)
	}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return 0, fmt.Errorf("store: batch card scan: %w", err)
		}
		studentIDs = append(studentIDs, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, fmt.Errorf("store: batch card rows: %w", err)
	}

	issued := 0
	for _, id := range studentIDs {
		if _, err := s.IssueIDCard(ctx, schoolID, id, session, issuedBy); err != nil {
			return issued, fmt.Errorf("store: batch issue %s: %w", id, err)
		}
		issued++
	}
	return issued, nil
}

// ListIDCards joins cards to their students for a session. classID
// scopes to one class when non-empty.
func (s *Store) ListIDCards(ctx context.Context, schoolID, classID, session string) ([]IDCardRow, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT k.id, k.school_id::text, k.student_id::text, k.serial, k.session, k.status,
                       COALESCE(k.issued_by::text, ''), k.issued_at,
                       st.full_name, st.admission_no, COALESCE(c.name, ''), COALESCE(c.id::text, ''),
                       st.sex, st.dob, st.photo_url, st.guardian_phone,
                       sc.name, sc.logo_url, sc.address
                FROM school.id_cards k
                JOIN school.students st ON st.id = k.student_id
                LEFT JOIN school.classes c ON c.id = st.class_id
                JOIN school.schools sc ON sc.id = k.school_id
                WHERE k.school_id = $1 AND k.session = $2
                  AND ($3 = '' OR st.class_id::text = $3)
                ORDER BY c.seq NULLS LAST, st.full_name`,
		schoolID, session, classID)
	if err != nil {
		return nil, fmt.Errorf("store: list id cards: %w", err)
	}
	defer rows.Close()

	var out []IDCardRow
	for rows.Next() {
		var r IDCardRow
		if err := rows.Scan(&r.Card.ID, &r.Card.SchoolID, &r.Card.StudentID, &r.Card.Serial,
			&r.Card.Session, &r.Card.Status, &r.Card.IssuedBy, &r.Card.IssuedAt,
			&r.StudentName, &r.AdmissionNo, &r.ClassName, &r.ClassID,
			&r.Sex, &r.DOB, &r.PhotoURL, &r.GuardianPhone,
			&r.SchoolName, &r.SchoolLogoURL, &r.Address); err != nil {
			return nil, fmt.Errorf("store: list id cards scan: %w", err)
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

// SetCardStatus flips a card between issued and revoked.
func (s *Store) SetCardStatus(ctx context.Context, schoolID, cardID, status string) error {
	tag, err := s.Pool.Exec(ctx,
		`UPDATE school.id_cards SET status = $3 WHERE id = $1 AND school_id = $2`,
		cardID, schoolID, status)
	if err != nil {
		return fmt.Errorf("store: set card status: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return errors.New("card not found")
	}
	return nil
}
