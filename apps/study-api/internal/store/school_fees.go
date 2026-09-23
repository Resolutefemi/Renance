// Fees ledger SQL. Management prices term charges per class (or
// school-wide with class_id NULL), then records receipts against
// students. All amounts are kobo (bigint): the naira number the UI
// shows is kobo / 100. Doctrine mirrors school.go: simple protocol,
// every access through this file.

package store

import (
	"context"
	"fmt"
)

// ------------------------------------------------------------ data types

// SchoolFee is one priced charge for a term. ClassID empty means the
// charge applies to every class in the school.
type SchoolFee struct {
	ID          string `json:"id"`
	SchoolID    string `json:"-"`
	ClassID     string `json:"classId"`
	ClassName   string `json:"className"`
	Title       string `json:"title"`
	Description string `json:"description"`
	AmountKobo  int64  `json:"amountKobo"`
	Term        int    `json:"term"`
	Session     string `json:"session"`
	Seq         int    `json:"seq"`
}

// SchoolFeePayment is one receipt: money taken from a student for a fee.
type SchoolFeePayment struct {
	ID         string `json:"id"`
	SchoolID   string `json:"-"`
	FeeID      string `json:"feeId"`
	StudentID  string `json:"studentId"`
	AmountKobo int64  `json:"amountKobo"`
	Method     string `json:"method"`
	Reference  string `json:"reference"`
	PaidOn     string `json:"paidOn"`
}

// FeeBalance is one student's money position for a term: what the
// school charges their class, what they have paid, what is left.
type FeeBalance struct {
	StudentID       string `json:"studentId"`
	StudentName     string `json:"studentName"`
	AdmissionNo     string `json:"admissionNo"`
	ClassName       string `json:"className"`
	ClassID         string `json:"classId"`
	ChargedKobo     int64  `json:"chargedKobo"`
	PaidKobo        int64  `json:"paidKobo"`
	OutstandingKobo int64  `json:"outstandingKobo"`
	LastPayment     string `json:"lastPayment"`
}

// ---------------------------------------------------------------- queries

// ListFees returns the priced charges for a term, school-wide rows
// first, then per-class rows, both in seq order.
func (s *Store) ListFees(ctx context.Context, schoolID string, term int, session string) ([]SchoolFee, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT f.id, f.school_id, COALESCE(f.class_id::text, ''), COALESCE(c.name, ''),
                       f.title, f.description, f.amount_kobo, f.term, f.session, f.seq
                FROM school.fees f
                LEFT JOIN school.classes c ON c.id = f.class_id
                WHERE f.school_id = $1 AND f.term = $2 AND f.session = $3
                ORDER BY (f.class_id IS NOT NULL), f.seq, f.title`,
		schoolID, term, session)
	if err != nil {
		return nil, fmt.Errorf("store: list fees: %w", err)
	}
	defer rows.Close()

	var out []SchoolFee
	for rows.Next() {
		var f SchoolFee
		if err := rows.Scan(&f.ID, &f.SchoolID, &f.ClassID, &f.ClassName,
			&f.Title, &f.Description, &f.AmountKobo, &f.Term, &f.Session, &f.Seq); err != nil {
			return nil, fmt.Errorf("store: list fees scan: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// SaveFee inserts or updates one fee row. The unique key
// (school, class, title, term, session) makes editing a price an
// upsert so re-typing the same charge never doubles it.
func (s *Store) SaveFee(ctx context.Context, f *SchoolFee) (*SchoolFee, error) {
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.fees (school_id, class_id, title, description, amount_kobo, term, session, seq)
                VALUES ($1, NULLIF($2,'')::uuid, $3, $4, $5, $6, $7, $8)
                ON CONFLICT (school_id, class_id, title, term, session)
                DO UPDATE SET description = EXCLUDED.description,
                              amount_kobo = EXCLUDED.amount_kobo,
                              seq = EXCLUDED.seq
                RETURNING id, school_id`,
		f.SchoolID, f.ClassID, f.Title, f.Description, f.AmountKobo, f.Term, f.Session, f.Seq,
	).Scan(&f.ID, &f.SchoolID)
	if err != nil {
		return nil, fmt.Errorf("store: save fee: %w", err)
	}
	return f, nil
}

// DeleteFee removes a charge. Payments keep their row (they are the
// receipts history) via ON DELETE CASCADE on fee_id? No: the migration
// cascades, which would eat receipts. So the handler blocks deleting a
// fee that already has payments; this query just deletes when clean.
func (s *Store) DeleteFee(ctx context.Context, schoolID, feeID string) (bool, error) {
	var paid int
	if err := s.Pool.QueryRow(ctx,
		`SELECT count(*) FROM school.fee_payments WHERE fee_id = $1`, feeID,
	).Scan(&paid); err != nil {
		return false, fmt.Errorf("store: fee payment count: %w", err)
	}
	if paid > 0 {
		return false, nil
	}
	tag, err := s.Pool.Exec(ctx,
		`DELETE FROM school.fees WHERE id = $1 AND school_id = $2`, feeID, schoolID)
	if err != nil {
		return false, fmt.Errorf("store: delete fee: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// StudentBelongsToSchool guards the receipt desk: money is only
// recorded against a student of the same school.
func (s *Store) StudentBelongsToSchool(ctx context.Context, schoolID, studentID string) (bool, error) {
	var ok bool
	err := s.Pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM school.students WHERE id = $1 AND school_id = $2)`,
		studentID, schoolID,
	).Scan(&ok)
	return ok, err
}

// RecordPayment writes one receipt and returns it.
func (s *Store) RecordPayment(ctx context.Context, p *SchoolFeePayment) (*SchoolFeePayment, error) {
	err := s.Pool.QueryRow(ctx, `
                INSERT INTO school.fee_payments (school_id, fee_id, student_id, amount_kobo, method, reference, paid_on)
                VALUES ($1, $2, $3, $4, $5, $6, COALESCE(NULLIF($7,'')::date, current_date))
                RETURNING id, paid_on::text`,
		p.SchoolID, p.FeeID, p.StudentID, p.AmountKobo, p.Method, p.Reference, p.PaidOn,
	).Scan(&p.ID, &p.PaidOn)
	if err != nil {
		return nil, fmt.Errorf("store: record payment: %w", err)
	}
	return p, nil
}

// ListPayments returns the receipts of one student for a term, newest
// first.
func (s *Store) ListPayments(ctx context.Context, schoolID, studentID string, term int, session string) ([]SchoolFeePayment, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT p.id, p.school_id, p.fee_id, p.student_id, p.amount_kobo, p.method, p.reference, p.paid_on::text
                FROM school.fee_payments p
                JOIN school.fees f ON f.id = p.fee_id
                WHERE p.school_id = $1 AND p.student_id = $2 AND f.term = $3 AND f.session = $4
                ORDER BY p.paid_on DESC, p.created_at DESC`,
		schoolID, studentID, term, session)
	if err != nil {
		return nil, fmt.Errorf("store: list payments: %w", err)
	}
	defer rows.Close()

	var out []SchoolFeePayment
	for rows.Next() {
		var p SchoolFeePayment
		if err := rows.Scan(&p.ID, &p.SchoolID, &p.FeeID, &p.StudentID,
			&p.AmountKobo, &p.Method, &p.Reference, &p.PaidOn); err != nil {
			return nil, fmt.Errorf("store: list payments scan: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// FeeBalances walks every active student of a class (or the whole
// school when classID is empty) and returns what the term charges them,
// what they paid, and the gap. Class-scoped fees hit their class;
// school-wide fees hit everyone.
func (s *Store) FeeBalances(ctx context.Context, schoolID, classID string, term int, session string) ([]FeeBalance, error) {
	rows, err := s.Pool.Query(ctx, `
                WITH charged AS (
                    SELECT st.id AS sid,
                           COALESCE(sum(f.amount_kobo), 0) AS total
                    FROM school.students st
                    JOIN school.fees f
                      ON f.school_id = st.school_id
                     AND f.term = $2 AND f.session = $3
                     AND (f.class_id IS NULL OR f.class_id = st.class_id)
                    WHERE st.school_id = $1 AND st.status = 'active'
                    GROUP BY st.id
                ),
                paid AS (
                    SELECT p.student_id AS sid,
                           sum(p.amount_kobo) AS total,
                           max(p.paid_on)::text AS last_on
                    FROM school.fee_payments p
                    JOIN school.fees f ON f.id = p.fee_id
                    WHERE p.school_id = $1 AND f.term = $2 AND f.session = $3
                    GROUP BY p.student_id
                )
                SELECT st.id::text, st.full_name, st.admission_no,
                       COALESCE(st.class_id::text, ''), COALESCE(c.name, ''),
                       COALESCE(ch.total, 0), COALESCE(pd.total, 0), COALESCE(pd.last_on, '')
                FROM school.students st
                LEFT JOIN school.classes c ON c.id = st.class_id
                LEFT JOIN charged ch ON ch.sid = st.id
                LEFT JOIN paid pd ON pd.sid = st.id
                WHERE st.school_id = $1 AND st.status = 'active'
                  AND ($4 = '' OR st.class_id::text = $4)
                ORDER BY c.seq NULLS LAST, st.full_name`,
		schoolID, term, session, classID)
	if err != nil {
		return nil, fmt.Errorf("store: fee balances: %w", err)
	}
	defer rows.Close()

	var out []FeeBalance
	for rows.Next() {
		var b FeeBalance
		if err := rows.Scan(&b.StudentID, &b.StudentName, &b.AdmissionNo,
			&b.ClassID, &b.ClassName, &b.ChargedKobo, &b.PaidKobo, &b.LastPayment); err != nil {
			return nil, fmt.Errorf("store: fee balances scan: %w", err)
		}
		b.OutstandingKobo = b.ChargedKobo - b.PaidKobo
		if b.OutstandingKobo < 0 {
			b.OutstandingKobo = 0
		}
		out = append(out, b)
	}
	return out, rows.Err()
}
