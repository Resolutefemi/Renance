package learn

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// Activity + voice-of-the-learner endpoints (founder directive
// 2026-10-17). Three small writes the admin dashboard reads:
//
//   - Heartbeat: presence + time-on-app. It deliberately NEVER touches
//     the streak - opening the app is presence, not a flame (the
//     streak doctrine only counts quiz/lesson activity).
//   - FlagQuestion: a learner reports a wrong/broken question.
//   - SubmitCourse: a learner cannot find their course (or the content
//     is wrong) and submits what they expected, with topics.

const (
	// MaxHeartbeatSeconds caps one POST: the web pings every 60s with
	// 60, so anything larger is a client bug, not truth.
	MaxHeartbeatSeconds = 180
	// DailyFlagCap / DailySubmissionCap keep the tables human-sized.
	DailyFlagCap       = 30
	DailySubmissionCap = 10
)

// Heartbeat stamps presence and accumulates time. One UPSERT - cheap
// enough to call every minute per active tab.
func (s *Service) Heartbeat(ctx context.Context, userID string, seconds int) error {
	if seconds < 0 {
		seconds = 0
	}
	if seconds > MaxHeartbeatSeconds {
		seconds = MaxHeartbeatSeconds
	}
	if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
		return err
	}
	_, err := s.Pool.Exec(ctx, `
		UPDATE learn.learners
		SET last_seen_at = now(),
		    time_spent_seconds = time_spent_seconds + $2
		WHERE user_id = $1`, userID, seconds)
	if err != nil {
		return fmt.Errorf("learn: heartbeat: %w", err)
	}
	return nil
}

// FlagInput is one reported question.
type FlagInput struct {
	Source     string `json:"source"`
	QuestionID string `json:"questionId"`
	CourseCode string `json:"courseCode"`
	Reason     string `json:"reason"`
	Details    string `json:"details"`
}

// FlagQuestion stores a learner's report. Returns the new row id.
func (s *Service) FlagQuestion(ctx context.Context, userID string, in FlagInput) (int64, error) {
	in.Source = strings.TrimSpace(in.Source)
	if in.Source == "" {
		in.Source = "lesson"
	}
	in.Reason = strings.TrimSpace(in.Reason)
	if in.Reason == "" {
		return 0, fmt.Errorf("learn: flag reason required")
	}
	if len(in.Details) > 4000 {
		in.Details = in.Details[:4000]
	}
	var today int
	if err := s.Pool.QueryRow(ctx, `
		SELECT count(*) FROM learn.question_flags
		WHERE user_id = $1 AND created_at > now() - interval '24 hours'`,
		userID).Scan(&today); err != nil {
		return 0, err
	}
	if today >= DailyFlagCap {
		return 0, fmt.Errorf("learn: too many reports today")
	}
	var id int64
	err := s.Pool.QueryRow(ctx, `
		INSERT INTO learn.question_flags (user_id, source, question_id, course_code, reason, details)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id`,
		userID, in.Source, in.QuestionID, in.CourseCode, in.Reason, in.Details).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("learn: flag: %w", err)
	}
	return id, nil
}

// CourseSubmissionInput is a learner's "I cannot find my course" report.
type CourseSubmissionInput struct {
	InstitutionType string `json:"institutionType"`
	SchoolName      string `json:"schoolName"`
	Department      string `json:"department"`
	CourseCode      string `json:"courseCode"`
	CourseTitle     string `json:"courseTitle"`
	Topics          string `json:"topics"`
	Details         string `json:"details"`
}

// SubmitCourse stores the submission. Returns the new row id.
func (s *Service) SubmitCourse(ctx context.Context, userID string, in CourseSubmissionInput) (int64, error) {
	in.SchoolName = strings.TrimSpace(in.SchoolName)
	in.CourseCode = strings.TrimSpace(in.CourseCode)
	if in.SchoolName == "" {
		return 0, fmt.Errorf("learn: school name required")
	}
	if in.CourseCode == "" && in.CourseTitle == "" {
		return 0, fmt.Errorf("learn: course code or title required")
	}
	if len(in.Topics) > 8000 {
		in.Topics = in.Topics[:8000]
	}
	if len(in.Details) > 4000 {
		in.Details = in.Details[:4000]
	}
	var today int
	if err := s.Pool.QueryRow(ctx, `
		SELECT count(*) FROM learn.course_submissions
		WHERE user_id = $1 AND created_at > now() - interval '24 hours'`,
		userID).Scan(&today); err != nil {
		return 0, err
	}
	if today >= DailySubmissionCap {
		return 0, fmt.Errorf("learn: too many submissions today")
	}
	var id int64
	err := s.Pool.QueryRow(ctx, `
		INSERT INTO learn.course_submissions
		    (user_id, institution_type, school_name, department, course_code, course_title, topics, details)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id`,
		userID, in.InstitutionType, in.SchoolName, in.Department,
		in.CourseCode, in.CourseTitle, in.Topics, in.Details).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("learn: course submission: %w", err)
	}
	return id, nil
}

// ActiveToday is the admin dashboard's DAU probe (same helper the
// health surface may reuse): learners seen since the Lagos day started.
func (s *Service) ActiveToday(ctx context.Context) (int, error) {
	var n int
	err := s.Pool.QueryRow(ctx, `
		SELECT count(*) FROM learn.learners
		WHERE last_seen_at >= date_trunc('day', now() AT TIME ZONE 'Africa/Lagos') AT TIME ZONE 'Africa/Lagos'`).Scan(&n)
	return n, err
}

var _ = time.Now // keep time imported for future probes
