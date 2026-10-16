// splitq.go - the two-step query vocabulary for the split-horizon
// databases (founder directive 2026-10-16: users + progress on Neon
// and InsForge, the catalog on Supabase, the lesson cache on
// InsForge). A JOIN across two databases is impossible, so the
// former cross-domain statements run as a content/cache step plus a
// user step merged over an ANY($1) id set. These helpers are the
// shared merge moves; every rewrite site composes them.
package learn

import (
	"context"
	"encoding/json"
)

// progressBestByTopic returns best_score per topic for one user over
// a topic set (missing ids simply have no entry).
func (s *Service) progressBestByTopic(ctx context.Context, userID string, topicIDs []string) (map[string]int, error) {
	out := map[string]int{}
	if len(topicIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT topic_id, COALESCE(best_score, 0) FROM learn.progress
                WHERE user_id=$1 AND topic_id = ANY($2)`, userID, topicIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var best int
		if err := rows.Scan(&id, &best); err != nil {
			return nil, err
		}
		out[id] = best
	}
	return out, rows.Err()
}

// progressDoneSet returns the topic ids the user holds a progress row
// for, among the candidates.
func (s *Service) progressDoneSet(ctx context.Context, userID string, topicIDs []string) (map[string]bool, error) {
	out := map[string]bool{}
	if len(topicIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.progress
                WHERE user_id=$1 AND topic_id = ANY($2)`, userID, topicIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out[id] = true
	}
	return out, rows.Err()
}

// enrolledSet returns the user_courses membership among candidate
// course ids.
func (s *Service) enrolledSet(ctx context.Context, userID string, courseIDs []string) (map[string]bool, error) {
	out := map[string]bool{}
	if len(courseIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT course_id FROM learn.user_courses
                WHERE user_id=$1 AND course_id = ANY($2)`, userID, courseIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out[id] = true
	}
	return out, rows.Err()
}

// enrolledCourseIDs lists the courses on the student's own list, list
// order preserved (added_at DESC).
func (s *Service) enrolledCourseIDs(ctx context.Context, userID string, limit int) ([]string, error) {
	rows, err := s.Pool.Query(ctx, `
                SELECT course_id FROM learn.user_courses
                WHERE user_id=$1 ORDER BY added_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// topicIDsForCourses returns the topic ids per course (ordered by
// seq) for the candidate courses - the content-side half of the
// progress merges.
func (s *Service) topicIDsForCourses(ctx context.Context, courseIDs []string) (map[string][]string, error) {
	out := map[string][]string{}
	if len(courseIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT t.course_id, t.topic_id FROM learn.topics t
                WHERE t.course_id = ANY($1) ORDER BY t.seq`, courseIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var course, topic string
		if err := rows.Scan(&course, &topic); err != nil {
			return nil, err
		}
		out[course] = append(out[course], topic)
	}
	return out, rows.Err()
}

// lessonQuizzesByTopic pulls cached quizzes for a topic id set off
// the CACHE pool, hit_count DESC with the option of a random tail.
type topicQuiz struct {
	TopicID string
	Raw     json.RawMessage
}

func (s *Service) lessonQuizzesByTopic(ctx context.Context, topicIDs []string, limit int) ([]topicQuiz, error) {
	if len(topicIDs) == 0 {
		return nil, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT topic_id, quiz FROM learn.lessons
                WHERE topic_id = ANY($1) AND jsonb_array_length(quiz) > 0
                ORDER BY hit_count DESC, random()
                LIMIT $2`, topicIDs, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []topicQuiz
	for rows.Next() {
		var tq topicQuiz
		var raw []byte
		if err := rows.Scan(&tq.TopicID, &raw); err != nil {
			return nil, err
		}
		tq.Raw = json.RawMessage(raw)
		out = append(out, tq)
	}
	return out, rows.Err()
}

// cachedTopicSet returns the topic ids that hold a cached lesson
// among the candidates (the prefetch look-ahead's cache step).
func (s *Service) cachedTopicSet(ctx context.Context, topicIDs []string) (map[string]bool, error) {
	out := map[string]bool{}
	if len(topicIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.lessons WHERE topic_id = ANY($1)`, topicIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out[id] = true
	}
	return out, rows.Err()
}

// enrolledLearnerCounts returns, per course, the number of progress
// rows enrolled students hold in it - the catalog's "Learners"
// figure, computed on the user pool over a course id set.
func (s *Service) enrolledLearnerCounts(ctx context.Context, courseIDs []string) (map[string]int, error) {
	out := map[string]int{}
	if len(courseIDs) == 0 {
		return out, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT uc.course_id, COUNT(*) FROM learn.user_courses uc
                JOIN learn.progress pr ON pr.user_id = uc.user_id
                WHERE uc.course_id = ANY($1)
                GROUP BY uc.course_id`, courseIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var n int
		if err := rows.Scan(&id, &n); err != nil {
			return nil, err
		}
		out[id] = n
	}
	return out, rows.Err()
}

// lessonQuizzesRandom pulls cached quizzes for a topic id set in
// plain random order (the review paper's pool pick).
func (s *Service) lessonQuizzesRandom(ctx context.Context, topicIDs []string, limit int) ([]topicQuiz, error) {
	if len(topicIDs) == 0 {
		return nil, nil
	}
	rows, err := s.Pool.Query(ctx, `
                SELECT topic_id, quiz FROM learn.lessons
                WHERE topic_id = ANY($1) AND jsonb_array_length(quiz) > 0
                ORDER BY random()
                LIMIT $2`, topicIDs, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []topicQuiz
	for rows.Next() {
		var tq topicQuiz
		var raw []byte
		if err := rows.Scan(&tq.TopicID, &raw); err != nil {
			return nil, err
		}
		tq.Raw = json.RawMessage(raw)
		out = append(out, tq)
	}
	return out, rows.Err()
}
