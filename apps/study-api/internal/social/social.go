// Package social - the Renance feed + follows (founder directive
// 2026-10-14): Duolingo-style milestone posts the platform writes on
// the student's behalf ("hits 400 streak", "scored 360 in JAMB",
// "reached Platinum league", "won an arena duel"), freeform user
// posts, likes, comments, the follow graph and the public profile every
// leaderboard/feed row opens. Plain functions over the pgx pool, the
// same house style as the rest of study-api. Every identity rides the
// REAL study.users id (uuid - see the 0028 FK fix).
package social

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"renance.dev/study-api/internal/store"
)

// ─── Shapes ───────────────────────────────────────────────────────────────

// Author is the public identity of a post owner or profile subject.
type Author struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Name     string `json:"name"`
	Premium  bool   `json:"premium"`
}

// Post is one feed row.
type Post struct {
	ID          int64           `json:"id"`
	Author      *Author         `json:"author"`
	Kind        string          `json:"kind"` // user | milestone
	Body        string          `json:"body"`
	Meta        json.RawMessage `json:"meta,omitempty"`
	Likes       int             `json:"likes"`
	Comments    int             `json:"comments"`
	LikedByMe   bool            `json:"likedByMe"`
	Mine        bool            `json:"mine"`
	CreatedAtMS int64           `json:"createdAtMs"`
}

// Comment is one feed comment row.
type Comment struct {
	ID          int64   `json:"id"`
	Author      *Author `json:"author"`
	Body        string  `json:"body"`
	Mine        bool    `json:"mine"`
	CreatedAtMS int64   `json:"createdAtMs"`
}

// CoursePulse is one course on a public profile.
type CoursePulse struct {
	Title   string `json:"title"`
	Body    string `json:"body"`
	Topics  int    `json:"topics"`
	Done    int    `json:"done"`
	Percent int    `json:"percent"`
}

// PublicProfile is everything /u/{username} renders.
type PublicProfile struct {
	Author
	Level       int    `json:"level"`
	XP          int    `json:"xp"`
	Streak      int    `json:"streak"`
	League      string `json:"league"`
	TopicsDone  int    `json:"topicsDone"`
	Perfect     int    `json:"perfectCount"`
	Followers   int    `json:"followers"`
	Following   int    `json:"following"`
	IsFollowing bool   `json:"isFollowing"`
	// FollowsYou: they already follow the viewer - the profile
	// button reads "Follow back" instead of "Follow" (founder
	// directive 2026-10-16: follow/follow-back parity everywhere).
	FollowsYou bool          `json:"followsYou"`
	IsSelf     bool          `json:"isSelf"`
	JoinedMS   int64         `json:"joinedMs"`
	Courses    []CoursePulse `json:"courses"`
}

// FollowRow is one follower/following line.
type FollowRow struct {
	Author
	FollowsYou bool `json:"followsYou"`
	Following  bool `json:"following"` // viewer → row
}

// Connections bundles the two follow lists for one viewer.
type Connections struct {
	Followers []FollowRow `json:"followers"`
	Following []FollowRow `json:"following"`
}

// ─── Writing ──────────────────────────────────────────────────────────────

// Milestone writes the platform post for one milestone. Deduped by the
// unique (user_id, milestone) index: the 400-streak post is written
// once, ever. Safe to call inside any hot path - failures never
// surface to the student.
func Milestone(ctx context.Context, pool store.Pool, userID, milestone, body string, meta map[string]any) {
	if userID == "" || milestone == "" {
		return
	}
	raw, _ := json.Marshal(meta)
	if len(raw) == 0 {
		raw = []byte(`{}`)
	}
	_, _ = pool.Exec(ctx, `
                INSERT INTO social.posts (user_id, kind, milestone, body, meta)
                VALUES ($1, 'milestone', $2, $3, $4::jsonb)
                ON CONFLICT (user_id, milestone) WHERE milestone <> '' DO NOTHING`,
		userID, milestone, body, string(raw))
}

// UserPost writes a freeform post; returns the new post id.
func UserPost(ctx context.Context, pool store.Pool, userID, body string) (int64, error) {
	body = strings.TrimSpace(body)
	if body == "" {
		return 0, fmt.Errorf("social: empty post")
	}
	if len([]rune(body)) > 500 {
		body = string([]rune(body)[:500])
	}
	var id int64
	err := pool.QueryRow(ctx,
		`INSERT INTO social.posts (user_id, kind, body) VALUES ($1,'user',$2) RETURNING post_id`,
		userID, body).Scan(&id)
	return id, err
}

// DeletePost removes a post the caller owns.
func DeletePost(ctx context.Context, pool store.Pool, userID string, postID int64) (bool, error) {
	tag, err := pool.Exec(ctx, `DELETE FROM social.posts WHERE post_id=$1 AND user_id=$2`, postID, userID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// ToggleLike likes/unlikes; returns the like count + the new state.
func ToggleLike(ctx context.Context, pool store.Pool, userID string, postID int64) (int, bool, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, false, err
	}
	defer tx.Rollback(ctx)
	var exists bool
	_ = tx.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM social.post_likes WHERE post_id=$1 AND user_id=$2)`,
		postID, userID).Scan(&exists)
	if exists {
		if _, err := tx.Exec(ctx, `DELETE FROM social.post_likes WHERE post_id=$1 AND user_id=$2`, postID, userID); err != nil {
			return 0, false, err
		}
	} else {
		if _, err := tx.Exec(ctx, `INSERT INTO social.post_likes (post_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
			postID, userID); err != nil {
			return 0, false, err
		}
	}
	var likes int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*) FROM social.post_likes WHERE post_id=$1`, postID).Scan(&likes); err != nil {
		return 0, false, err
	}
	return likes, !exists, tx.Commit(ctx)
}

// AddComment appends a comment; returns the comment id.
func AddComment(ctx context.Context, pool store.Pool, userID string, postID int64, body string) (int64, error) {
	body = strings.TrimSpace(body)
	if body == "" {
		return 0, fmt.Errorf("social: empty comment")
	}
	if len([]rune(body)) > 300 {
		body = string([]rune(body)[:300])
	}
	var id int64
	err := pool.QueryRow(ctx,
		`INSERT INTO social.post_comments (post_id, user_id, body) VALUES ($1,$2,$3) RETURNING id`,
		postID, userID, body).Scan(&id)
	return id, err
}

// Follow toggles the edge viewer→subject; returns the new state.
func Follow(ctx context.Context, pool store.Pool, viewerID, subjectID string) (bool, error) {
	if viewerID == subjectID {
		return false, fmt.Errorf("social: cannot follow yourself")
	}
	var exists bool
	_ = pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM social.follows WHERE follower_id=$1 AND followee_id=$2)`,
		viewerID, subjectID).Scan(&exists)
	if exists {
		_, err := pool.Exec(ctx, `DELETE FROM social.follows WHERE follower_id=$1 AND followee_id=$2`, viewerID, subjectID)
		return false, err
	}
	_, err := pool.Exec(ctx, `INSERT INTO social.follows (follower_id, followee_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
		viewerID, subjectID)
	return true, err
}

// ─── Reading ──────────────────────────────────────────────────────────────

func authorSel(u, p string) string {
	return fmt.Sprintf(`%s.id, %s.username, COALESCE(%s.full_name,''), COALESCE(%s.account_kind,'') = 'premium'`, u, u, p, u)
}

// Feed reads one page of the global feed (newest first). before==0 means
// "from the top". Milestones and user posts interleave by time.
func Feed(ctx context.Context, pool store.Pool, viewer string, before int64, limit int) ([]Post, error) {
	if limit <= 0 || limit > 50 {
		limit = 25
	}
	where := "WHERE s.user_id IS NOT NULL"
	args := []any{viewer}
	if before > 0 {
		args = append(args, before)
		where += fmt.Sprintf(" AND s.post_id < $%d", len(args))
	}
	args = append(args, limit)
	sql := `
                SELECT s.post_id, s.kind, s.body, s.meta, s.created_at,
                       ` + authorSel(`u`, `p`) + `,
                       (SELECT COUNT(*) FROM social.post_likes l WHERE l.post_id = s.post_id),
                       (SELECT COUNT(*) FROM social.post_comments c WHERE c.post_id = s.post_id),
                       EXISTS (SELECT 1 FROM social.post_likes l2 WHERE l2.post_id = s.post_id AND l2.user_id = $1),
                       s.user_id = $1
                FROM social.posts s
                JOIN study.users u ON u.id = s.user_id
                LEFT JOIN study.profiles p ON p.user_id = u.id
                ` + where + `
                ORDER BY s.post_id DESC LIMIT ` + fmt.Sprintf("$%d", len(args))
	rows, err := pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Post{}
	for rows.Next() {
		p, err := scanPost(rows, viewer)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

// UserPosts reads one user's posts (public profile timeline).
func UserPosts(ctx context.Context, pool store.Pool, viewer, subjectID string, limit int) ([]Post, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	rows, err := pool.Query(ctx, `
                SELECT s.post_id, s.kind, s.body, s.meta, s.created_at,
                       `+authorSel(`u`, `p`)+`,
                       (SELECT COUNT(*) FROM social.post_likes l WHERE l.post_id = s.post_id),
                       (SELECT COUNT(*) FROM social.post_comments c WHERE c.post_id = s.post_id),
                       EXISTS (SELECT 1 FROM social.post_likes l2 WHERE l2.post_id = s.post_id AND l2.user_id = $2),
                       s.user_id = $2
                FROM social.posts s
                JOIN study.users u ON u.id = s.user_id
                LEFT JOIN study.profiles p ON p.user_id = u.id
                WHERE s.user_id = $1
                ORDER BY s.post_id DESC LIMIT $3`, subjectID, viewer, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Post{}
	for rows.Next() {
		p, err := scanPost(rows, viewer)
		if err != nil {
			return nil, err
		}
		out = append(out, *p)
	}
	return out, rows.Err()
}

func scanPost(row interface{ Scan(...any) error }, _ string) (*Post, error) {
	var p Post
	var author Author
	var meta []byte
	var createdAt time.Time
	if err := row.Scan(&p.ID, &p.Kind, &p.Body, &meta, &createdAt,
		&author.ID, &author.Username, &author.Name, &author.Premium,
		&p.Likes, &p.Comments, &p.LikedByMe, &p.Mine); err != nil {
		return nil, err
	}
	if author.Name == "" {
		author.Name = author.Username
	}
	p.Author = &author
	p.Meta = json.RawMessage(meta)
	p.CreatedAtMS = createdAt.UnixMilli()
	return &p, nil
}

// Comments lists a post's comments, oldest first.
func Comments(ctx context.Context, pool store.Pool, viewer string, postID int64) ([]Comment, error) {
	rows, err := pool.Query(ctx, `
                SELECT c.id, c.body, c.created_at,
                       `+authorSel(`u`, `p`)+`, c.user_id = $2
                FROM social.post_comments c
                JOIN study.users u ON u.id = c.user_id
                LEFT JOIN study.profiles p ON p.user_id = u.id
                WHERE c.post_id = $1
                ORDER BY c.id ASC`, postID, viewer)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Comment{}
	for rows.Next() {
		var c Comment
		var author Author
		var createdAt time.Time
		if err := rows.Scan(&c.ID, &c.Body, &createdAt,
			&author.ID, &author.Username, &author.Name, &author.Premium, &c.Mine); err != nil {
			return nil, err
		}
		if author.Name == "" {
			author.Name = author.Username
		}
		c.Author = &author
		c.CreatedAtMS = createdAt.UnixMilli()
		out = append(out, c)
	}
	return out, rows.Err()
}

// levelFor mirrors the gamification ladder (store.ApplyGrade): one step
// per 100 XP after the first 50. Kept coarse on purpose - the profile
// badge is cosmetic, the ledger stays authoritative.
func levelFor(xp int) int {
	if xp < 50 {
		return 1
	}
	return 1 + (xp-50)/100
}

var leagueNames = []string{"Bronze", "Copper", "Silver", "Gold", "Sapphire", "Ruby", "Emerald", "Amethyst", "Pearl", "Diamond"}

// LoadPublicProfile assembles /u/{username}.
func LoadPublicProfile(ctx context.Context, pool store.Pool, viewer, username string) (*PublicProfile, error) {
	p := &PublicProfile{}
	var joined time.Time
	err := pool.QueryRow(ctx, `
                SELECT u.id, u.username, COALESCE(pr.full_name,''), COALESCE(u.account_kind,'') = 'premium', u.created_at
                FROM study.users u
                LEFT JOIN study.profiles pr ON pr.user_id = u.id
                WHERE lower(u.username) = lower($1)`, username).
		Scan(&p.ID, &p.Username, &p.Name, &p.Premium, &joined)
	if err != nil {
		return nil, err
	}
	p.JoinedMS = joined.UnixMilli()
	if p.Name == "" {
		p.Name = p.Username
	}
	p.IsSelf = viewer == p.ID

	// Learn economy (the learn.learners row may not exist for an account
	// that never studied - every read is COALESCEd over the LEFT JOIN).
	var leagueIdx int
	_ = pool.QueryRow(ctx, `
                SELECT COALESCE(x.xp,0), COALESCE(x.streak_count,0),
                       COALESCE((SELECT MAX(lm.league) FROM learn.league_members lm WHERE lm.user_id = u2.id),0)
                FROM study.users u2
                LEFT JOIN learn.learners x ON x.user_id = u2.id
                WHERE u2.id = $1`, p.ID).
		Scan(&p.XP, &p.Streak, &leagueIdx)
	p.Level = levelFor(p.XP)
	if leagueIdx >= 0 && leagueIdx < len(leagueNames) {
		p.League = leagueNames[leagueIdx]
	}
	_ = pool.QueryRow(ctx, `
                SELECT COUNT(*), COUNT(*) FILTER (WHERE best_score >= 100)
                FROM learn.progress WHERE user_id = $1`, p.ID).Scan(&p.TopicsDone, &p.Perfect)

	// Follow graph.
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM social.follows WHERE followee_id=$1`, p.ID).Scan(&p.Followers)
	_ = pool.QueryRow(ctx, `SELECT COUNT(*) FROM social.follows WHERE follower_id=$1`, p.ID).Scan(&p.Following)
	if !p.IsSelf && viewer != "" {
		_ = pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM social.follows WHERE follower_id=$1 AND followee_id=$2)`,
			viewer, p.ID).Scan(&p.IsFollowing)
		// Follow-back awareness: do THEY follow the viewer?
		_ = pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM social.follows WHERE follower_id=$1 AND followee_id=$2)`,
			p.ID, viewer).Scan(&p.FollowsYou)
	}

	// The courses they are taking, with progress. Two-step
	// pool-safe rewrite (user_courses + progress on the user
	// database, titles + topic counts on the content database).
	if courseIDs, err := userCourseIDs(ctx, pool, p.ID, 12); err == nil && len(courseIDs) > 0 {
		type pulseBase struct {
			title, body string
			topics      int
		}
		bases := map[string]pulseBase{}
		if rows, err := pool.Query(ctx, `
                SELECT c.course_id, c.title, c.body,
                       (SELECT COUNT(*) FROM learn.topics t WHERE t.course_id = c.course_id)
                FROM learn.courses c WHERE c.course_id = ANY($1)`, courseIDs); err == nil {
			for rows.Next() {
				var id, title, body string
				var topics int
				if rows.Scan(&id, &title, &body, &topics) == nil {
					bases[id] = pulseBase{title: title, body: body, topics: topics}
				}
			}
			rows.Close()
		}
		// Done counts: the profile owner's progress rows over every
		// topic of their courses (user pool, one ANY query).
		type courseTopics struct {
			course string
			topic  string
		}
		var links []courseTopics
		var flat []string
		if rows, err := pool.Query(ctx, `
                SELECT t.course_id, t.topic_id FROM learn.topics t
                WHERE t.course_id = ANY($1) ORDER BY t.seq`, courseIDs); err == nil {
			for rows.Next() {
				var l courseTopics
				if rows.Scan(&l.course, &l.topic) == nil {
					links = append(links, l)
					flat = append(flat, l.topic)
				}
			}
			rows.Close()
		}
		doneByTopic := map[string]bool{}
		if len(flat) > 0 {
			if rows, err := pool.Query(ctx, `
                SELECT topic_id FROM learn.progress
                WHERE user_id = $1 AND topic_id = ANY($2)`, p.ID, flat); err == nil {
				for rows.Next() {
					var tid string
					if rows.Scan(&tid) == nil {
						doneByTopic[tid] = true
					}
				}
				rows.Close()
			}
		}
		doneByCourse := map[string]int{}
		for _, l := range links {
			if doneByTopic[l.topic] {
				doneByCourse[l.course]++
			}
		}
		for _, id := range courseIDs {
			b, ok := bases[id]
			if !ok || b.topics == 0 {
				continue
			}
			done := doneByCourse[id]
			pct := 0
			if b.topics > 0 {
				pct = done * 100 / b.topics
			}
			p.Courses = append(p.Courses, CoursePulse{
				Title: b.title, Body: b.body, Topics: b.topics, Done: done, Percent: pct,
			})
		}
	}
	return p, nil
}

// userCourseIDs lists the courses on a profile's list (user pool).
func userCourseIDs(ctx context.Context, pool store.Pool, userID string, limit int) ([]string, error) {
	rows, err := pool.Query(ctx, `
                SELECT course_id FROM learn.user_courses
                WHERE user_id = $1 ORDER BY added_at DESC LIMIT $2`, userID, limit)
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

// LoadConnections lists the viewer's followers + following, flagged so
// the UI can offer follow-backs.
func LoadConnections(ctx context.Context, pool store.Pool, viewer string) (*Connections, error) {
	c := &Connections{Followers: []FollowRow{}, Following: []FollowRow{}}
	followers, err := pool.Query(ctx, `
                SELECT `+authorSel(`u`, `p`)+`,
                       EXISTS (SELECT 1 FROM social.follows b WHERE b.follower_id = u.id AND b.followee_id = $1),
                       EXISTS (SELECT 1 FROM social.follows b2 WHERE b2.follower_id = $1 AND b2.followee_id = u.id)
                FROM social.follows f
                JOIN study.users u ON u.id = f.follower_id
                LEFT JOIN study.profiles p ON p.user_id = u.id
                WHERE f.followee_id = $1
                ORDER BY f.created_at DESC LIMIT 200`, viewer)
	if err != nil {
		return nil, err
	}
	defer followers.Close()
	for followers.Next() {
		var r FollowRow
		if err := followers.Scan(&r.ID, &r.Username, &r.Name, &r.Premium, &r.FollowsYou, &r.Following); err != nil {
			return nil, err
		}
		if r.Name == "" {
			r.Name = r.Username
		}
		c.Followers = append(c.Followers, r)
	}
	following, err := pool.Query(ctx, `
                SELECT `+authorSel(`u`, `p`)+`,
                       EXISTS (SELECT 1 FROM social.follows b WHERE b.follower_id = u.id AND b.followee_id = $1),
                       TRUE
                FROM social.follows f2
                JOIN study.users u ON u.id = f2.followee_id
                LEFT JOIN study.profiles p ON p.user_id = u.id
                WHERE f2.follower_id = $1
                ORDER BY f2.created_at DESC LIMIT 200`, viewer)
	if err != nil {
		return nil, err
	}
	defer following.Close()
	for following.Next() {
		var r FollowRow
		if err := following.Scan(&r.ID, &r.Username, &r.Name, &r.Premium, &r.FollowsYou, &r.Following); err != nil {
			return nil, err
		}
		if r.Name == "" {
			r.Name = r.Username
		}
		c.Following = append(c.Following, r)
	}
	return c, nil
}

// UserIDByUsername resolves a handle → study.users.id (empty when unknown).
func UserIDByUsername(ctx context.Context, pool store.Pool, username string) string {
	var id string
	if err := pool.QueryRow(ctx, `SELECT id FROM study.users WHERE lower(username) = lower($1)`, username).Scan(&id); err != nil {
		return ""
	}
	return id
}
