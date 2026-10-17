// ledger.go - the completion ledger and the reward economy: everything
// that happens when a student finishes a topic quiz (XP, gems, hearts,
// streak, mistakes, daily stats, league rollover), plus quests, shop,
// league board, chests and mistakes practice. Direct port of Supreme's
// /api/progress + /api/quests + /api/shop + /api/leaderboard +
// /api/practice + /api/chests routes.
package learn

import (
        "context"
        "encoding/json"
        "fmt"
        "math"
        "time"

        "renance.dev/study-api/internal/learn/synth"
        "renance.dev/study-api/internal/social"
)

// ─── Completion ledger ────────────────────────────────────────────────────

type MistakeIn struct {
        ID          string            `json:"id"`
        Stem        string            `json:"stem"`
        Type        string            `json:"type"`
        Options     map[string]string `json:"options,omitempty"`
        Answer      string            `json:"answer"`
        Explanation string            `json:"explanation,omitempty"`
        UserAnswer  json.RawMessage   `json:"userAnswer,omitempty"`
        Year        int               `json:"year,omitempty"`
}

type CompleteRequest struct {
        TopicID   string      `json:"topicId"`
        Correct   int         `json:"correct"`
        Total     int         `json:"total"`
        MaxCombo  int         `json:"maxCombo"`
        Mistakes  []MistakeIn `json:"mistakes"`
        Abandoned bool        `json:"abandoned"`
}

type CompleteResult struct {
        XPEarned     int  `json:"xpEarned"`
        GemsEarned   int  `json:"gemsEarned"`
        Perfect      bool `json:"perfect"`
        FirstClear   bool `json:"firstClear"`
        ComboBonus   int  `json:"comboBonus"`
        Boosted      bool `json:"boosted"`
        Streak       int  `json:"streak"`
        StreakUp     bool `json:"streakUp"`
        // StreakForgiven is true when THIS completion restored a lost
        // 7+ day streak through the forgiveness pool (founder directive
        // 2026-10-17: no freeze available, back within 3 quiet days, at
        // most three restores ever) - the streak celebration says so.
        StreakForgiven     bool `json:"streakForgiven,omitempty"`
        StreakForgivesLeft int  `json:"streakForgivesLeft,omitempty"`
        Hearts       int  `json:"hearts"`
        Unlimited    bool `json:"unlimitedHearts"`
        Gems         int  `json:"gems"`
        XPTotal      int  `json:"xp"`
        CompletedPct int  `json:"completedPercent"`
        // Chest is the reward chest the finished topic opened (founder
        // directive 2026-10-16): gems (capped at 30), a streak freeze,
        // or a 2x XP boost. Nil when the chest was already opened or
        // the run was abandoned.
        Chest *ChestDrop `json:"chest,omitempty"`
        // Milestone is the achievement this completion just posted to
        // the Renance feed (7/14/30/50/100+ day streaks, course
        // completion, league promotions) - the client turns it into the
        // celebration popup with the share buttons.
        Milestone *MilestoneInfo `json:"milestone,omitempty"`
}

// ChestDrop is one topic chest's randomized reward.
type ChestDrop struct {
        Kind   string `json:"kind"` // gems | freeze | boost
        Amount int    `json:"amount"`
        Icon   string `json:"icon"`
        Label  string `json:"label"`
}

// MilestoneInfo names the achievement the platform just posted.
type MilestoneInfo struct {
        Code  string `json:"code"`
        Label string `json:"label"`
}

// Complete records a topic attempt and pays every reward. Abandoned
// runs bank mistakes but pay nothing (Supreme parity).
func (s *Service) Complete(ctx context.Context, userID string, req CompleteRequest) (*CompleteResult, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                return nil, err
        }
        // The league seat before this attempt lands (promotion detection
        // for the feed milestone after commit).
        prevLeague := s.leagueIndex(ctx, userID)

        // Topic + course context.
        var courseID string
        err = s.Pool.QueryRow(ctx, `SELECT course_id FROM learn.topics WHERE topic_id=$1`, req.TopicID).Scan(&courseID)
        if err != nil {
                return nil, fmt.Errorf("learn: unknown topic %s", req.TopicID)
        }

        res := &CompleteResult{Unlimited: s.UnlimitedHearts || l.SuperActive}

        // Mistakes bank: every wrong answer becomes practice material.
        for _, m := range req.Mistakes {
                payload, _ := json.Marshal(m)
                if _, err := s.Pool.Exec(ctx, `
                        INSERT INTO learn.mistakes (user_id, question_id, topic_id, payload, resolved, misses, updated_at)
                        VALUES ($1,$2,$3,$4,FALSE,1,now())
                        ON CONFLICT (user_id, question_id) DO UPDATE
                          SET resolved = FALSE, misses = learn.mistakes.misses + 1,
                              payload = EXCLUDED.payload, updated_at = now()`,
                        userID, m.ID, req.TopicID, string(payload)); err != nil {
                        return nil, err
                }
        }

        if req.Abandoned || req.Total <= 0 {
                return res, nil
        }

        percent := int(math.Round(float64(req.Correct) * 100 / float64(req.Total)))
        res.Perfect = percent == 100

        // First clear?
        var priorBest int
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(MAX(best_score),-1) FROM learn.progress WHERE user_id=$1 AND topic_id=$2`,
                userID, req.TopicID).Scan(&priorBest)
        res.FirstClear = priorBest < 0
        improved := percent > priorBest

        // ── XP: per correct + perfect bonus + combo bonus, doubled in boost.
        xp := req.Correct * XPPerCorrect
        if res.Perfect {
                xp += PerfectBonusXP
        }
        if req.MaxCombo >= ComboTarget {
                res.ComboBonus = ((req.MaxCombo / ComboTarget) - 0) * ComboBonusXP
                if res.ComboBonus < 0 {
                        res.ComboBonus = 0
                }
                xp += res.ComboBonus
        }
        if l.BoostActive {
                xp *= 2
                res.Boosted = true
        }
        res.XPEarned = xp

        // ── Gems: 3 first clear / 1 repeat, +2 perfect (Supreme parity).
        res.GemsEarned = RepeatClearGems
        if res.FirstClear {
                res.GemsEarned = FirstClearGems
        }
        if res.Perfect {
                res.GemsEarned += PerfectGemsBonus
        }

        day := LagosToday()
        week := weekKey(time.Now())

        // Bank the progress row + ledger writes in one transaction.
        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return nil, err
        }
        defer tx.Rollback(ctx)

        if improved {
                if res.FirstClear {
                        if _, err := tx.Exec(ctx, `
                                INSERT INTO learn.progress (user_id, topic_id, status, best_score, xp_earned, attempts)
                                VALUES ($1,$2,'completed',$3,$4,1)`, userID, req.TopicID, percent, xp); err != nil {
                                return nil, err
                        }
                } else {
                        if _, err := tx.Exec(ctx, `
                                UPDATE learn.progress SET best_score=$3, xp_earned = xp_earned + $4, attempts = attempts + 1
                                WHERE user_id=$1 AND topic_id=$2`, userID, req.TopicID, percent, xp); err != nil {
                                return nil, err
                        }
                }
        } else {
                if _, err := tx.Exec(ctx, `
                        UPDATE learn.progress SET attempts = attempts + 1 WHERE user_id=$1 AND topic_id=$2`,
                        userID, req.TopicID); err != nil {
                        return nil, err
                }
        }

        if _, err := tx.Exec(ctx, `
                INSERT INTO learn.xp_events (user_id, amount, kind, week_key, day_key)
                VALUES ($1,$2,'lesson',$3,$4)`, userID, xp, week, day); err != nil {
                return nil, err
        }

        if _, err := tx.Exec(ctx, `
                INSERT INTO learn.daily_stats (user_id, day_key, xp, correct, lessons, perfect, max_combo)
                VALUES ($1,$2,$3,$4,$5,$6,$7)
                ON CONFLICT (user_id, day_key) DO UPDATE SET
                  xp = learn.daily_stats.xp + $3,
                  correct = learn.daily_stats.correct + $4,
                  lessons = learn.daily_stats.lessons + $5,
                  perfect = learn.daily_stats.perfect + $6,
                  max_combo = GREATEST(learn.daily_stats.max_combo, $7)`,
                userID, day, xp, req.Correct, 1, boolInt(res.Perfect), req.MaxCombo); err != nil {
                return nil, err
        }

        // Streak (Supreme touchStreak: today → unchanged, else compute).
        // The compute carries the founder's forgiveness rules (2026-10-17):
        // one quiet day keeps the streak alive, freezes bridge 2-3 day
        // gaps, and a 7+ day streak without freeze cover is FORGIVEN -
        // restored free, at most three times in a lifetime.
        streakBefore := l.Streak
        freezeNow := l.FreezeCount
        today := LagosToday()
        if l.LastActive != today {
                sr := ComputeStreak(l.Streak, l.LastActive, l.FreezeCount, l.StreakForgiven, time.Now())
                res.Streak = sr.Count
                freeze := l.FreezeCount - sr.FreezesUsed
                forgiven := l.StreakForgiven
                if sr.Forgiven {
                        forgiven++
                        res.StreakForgiven = true
                }
                res.StreakForgivesLeft = MaxStreakForgiveness - forgiven
                freezeNow = freeze
                if _, err := tx.Exec(ctx, `
                        UPDATE learn.learners SET streak_count=$2, last_active_on=$3, freeze_count=$4, streak_forgiven_count=$5
                        WHERE user_id=$1`, userID, sr.Count, today, freeze, forgiven); err != nil {
                        return nil, err
                }
                l.Streak = sr.Count
        } else {
                res.Streak = l.Streak
        }
        res.StreakUp = res.Streak > streakBefore

        // The topic chest (founder directive 2026-10-16): finishing a
        // topic opens a reward chest - streak freezes, gems (capped at
        // 30), or an XP boost. Rolled ONCE per user+topic (the PK keeps
        // a replayed completion from double-paying), paid in the same
        // transaction as the progress row.
        if res.FirstClear {
                kind, amount := rollChestDrop(userID, req.TopicID, freezeNow)
                tag, err := tx.Exec(ctx, `
                        INSERT INTO learn.topic_chests (user_id, topic_id, reward_kind, reward_amount)
                        VALUES ($1,$2,$3,$4) ON CONFLICT (user_id, topic_id) DO NOTHING`,
                        userID, req.TopicID, kind, amount)
                if err != nil {
                        return nil, err
                }
                if tag.RowsAffected() > 0 {
                        switch kind {
                        case "freeze":
                                if _, err := tx.Exec(ctx, `
                                        UPDATE learn.learners SET freeze_count = LEAST(freeze_count + 1, $2)
                                        WHERE user_id=$1`, userID, MaxFreezes); err != nil {
                                        return nil, err
                                }
                                res.Chest = &ChestDrop{Kind: "freeze", Amount: 1, Icon: "ac_unit", Label: "Streak Freeze"}
                        case "boost":
                                if _, err := tx.Exec(ctx, `
                                        UPDATE learn.learners
                                        SET boost_until = GREATEST(COALESCE(boost_until, 'epoch'::timestamptz), now()) + ($2 * interval '1 minute')
                                        WHERE user_id=$1`, userID, BoostMinutes); err != nil {
                                        return nil, err
                                }
                                res.Chest = &ChestDrop{Kind: "boost", Amount: BoostMinutes, Icon: "bolt", Label: fmt.Sprintf("%d-min 2x XP boost", BoostMinutes)}
                        default:
                                if _, err := tx.Exec(ctx, `
                                        UPDATE learn.learners SET gems = gems + $2 WHERE user_id=$1`, userID, amount); err != nil {
                                        return nil, err
                                }
                                res.Chest = &ChestDrop{Kind: "gems", Amount: amount, Icon: "diamond", Label: fmt.Sprintf("%d gems", amount)}
                        }
                        // Chest opens feed the daily chest stat too.
                        if _, err := tx.Exec(ctx, `
                                INSERT INTO learn.daily_stats (user_id, day_key, chests_opened) VALUES ($1,$2,1)
                                ON CONFLICT (user_id, day_key) DO UPDATE SET chests_opened = learn.daily_stats.chests_opened + 1`,
                                userID, day); err != nil {
                                return nil, err
                        }
                }
        }

        // League membership for the week (rollover finalize lives here too).
        if err := s.ensureLeague(ctx, tx, userID); err != nil {
                return nil, err
        }

        // Pay the learner.
        if _, err := tx.Exec(ctx, `
                UPDATE learn.learners SET xp = xp + $2, gems = gems + $3 WHERE user_id=$1`,
                userID, xp, res.GemsEarned); err != nil {
                return nil, err
        }

        if err := tx.Commit(ctx); err != nil {
                return nil, err
        }

        // Course completion percentage for the done screen. The original
        // read `COALESCE(int(round(100.0 * (done), (total))), 0)` - two
        // bugs: Postgres has no int() function, and the DIVISION between
        // the done and total counts was missing (that comma made the
        // total round's "decimal places" argument). The statement failed
        // on every call and the swallowed error left CompletedPct at 0
        // forever. Fixed: a real division with a zero-total guard.
        // Two-step pool-safe rewrite (topics on the content database,
        // progress on the user database): the topic ids come from the
        // content pool, the done count from the user pool.
        {
                var total int
                if err := s.Pool.QueryRow(ctx, `
                SELECT COUNT(*) FROM learn.topics WHERE course_id=$1`, courseID).Scan(&total); err == nil && total > 0 {
                        var ids []string
                        if rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.topics WHERE course_id=$1`, courseID); err == nil {
                                for rows.Next() {
                                        var id string
                                        if rows.Scan(&id) == nil {
                                                ids = append(ids, id)
                                        }
                                }
                                rows.Close()
                                done, _ := s.progressDoneSet(ctx, userID, ids)
                                res.CompletedPct = 100 * len(done) / total
                        }
                }
        }

        l, _ = s.loadLearner(ctx, s.Pool, userID)
        if l != nil {
                res.Hearts, res.Gems, res.XPTotal, res.Unlimited = l.Hearts, l.Gems, l.XP, s.UnlimitedHearts || l.SuperActive
        }

        // Feed milestones (best-effort, never fail the completion): the
        // platform posts the big moments - streaks, league promotions,
        // and now full COURSE completions - to the Renance feed (founder
        // directives 2026-10-14 + 2026-10-16). Exam scores post from the
        // grading engine; arena wins from the hub.
        s.postFeedMilestones(ctx, userID, prevLeague, courseID, res)

        // The seamless background loop (founder directive 2026-10-16):
        // the moment a topic lands, the NEXT topic's lesson and the
        // next unit of the course tree pre-generate silently - the
        // student never waits on the AI.
        go s.PrefetchAfterComplete(req.TopicID, courseID)
        go s.EnsureUnitsAhead(userID, courseID)
        return res, nil
}

// rollChestDrop picks a topic chest's reward deterministically from
// user+topic. Weights: 12% a streak freeze (when the stash has room -
// a full stash rolls gems instead), 18% a 2x XP boost, 70% gems
// between 8 and 30 (the founder's cap).
func rollChestDrop(userID, topicID string, freezeCount int) (string, int) {
        r := hashStr(userID+"#"+topicID) % 100
        switch {
        case r < 12 && freezeCount < MaxFreezes:
                return "freeze", 1
        case r < 30:
                return "boost", BoostMinutes
        default:
                return "gems", 8 + int(hashStr(topicID+"#gems")%23)
        }
}

// PrefetchAfterComplete silently generates the very next topic's
// lesson after a completion (cache-miss only - the NOT EXISTS guard
// makes repeats free), so "the next course/topic content is generated
// immediately and silently in the background" (founder directive).
func (s *Service) PrefetchAfterComplete(topicID, courseID string) {
        ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
        defer cancel()
        // Two-step pool-safe rewrite (content step for the seq anchor and
        // the next candidates, cache step for the already-cached filter).
        var seq int
        if err := s.Pool.QueryRow(ctx, `
                SELECT seq FROM learn.topics WHERE topic_id=$1`, topicID).Scan(&seq); err != nil {
                return
        }
        rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.topics
                WHERE course_id=$1 AND seq > $2
                ORDER BY seq LIMIT 4`, courseID, seq)
        if err != nil {
                return
        }
        var candidates []string
        for rows.Next() {
                var id string
                if rows.Scan(&id) == nil {
                        candidates = append(candidates, id)
                }
        }
        rows.Close()
        if err := rows.Err(); err != nil {
                return
        }
        cached, _ := s.cachedTopicSet(ctx, candidates)
        var nid string
        for _, id := range candidates {
                if !cached[id] {
                        nid = id
                        break
                }
        }
        if nid == "" {
                return
        }
        _ = err
        nt, err := s.loadTopicCtx(ctx, nid)
        if err != nil {
                return
        }
        s.kickOff(nt)
}

// streakMilestones: the streak counts big enough to announce. The
// milestone dedup index writes each of these once, ever.
var streakMilestones = map[int]bool{
        3: true, 7: true, 14: true, 21: true, 30: true, 50: true, 75: true,
        100: true, 150: true, 200: true, 250: true, 300: true, 365: true,
        400: true, 500: true, 600: true, 700: true, 730: true, 800: true,
        900: true, 1000: true,
}

func (s *Service) postFeedMilestones(ctx context.Context, userID string, prevLeague int, courseID string, res *CompleteResult) {
        defer func() { _ = recover() }() // a feed hiccup never breaks a lesson
        if res.Streak > 0 && streakMilestones[res.Streak] {
                social.Milestone(ctx, s.Pool, userID, fmt.Sprintf("streak_%d", res.Streak),
                        fmt.Sprintf("just hit a %d-day streak! 🔥", res.Streak),
                        map[string]any{"streak": res.Streak})
                res.Milestone = &MilestoneInfo{
                        Code:  fmt.Sprintf("streak_%d", res.Streak),
                        Label: fmt.Sprintf("%d-day streak", res.Streak),
                }
        }
        if res.CompletedPct >= 100 && courseID != "" && res.FirstClear {
                var title string
                _ = s.Pool.QueryRow(ctx, `SELECT title FROM learn.courses WHERE course_id=$1`, courseID).Scan(&title)
                if title == "" {
                        title = "a full course"
                }
                social.Milestone(ctx, s.Pool, userID, "course_"+courseID,
                        fmt.Sprintf("just completed the entire %s course! 🎓", title),
                        map[string]any{"course": title, "courseId": courseID})
                if res.Milestone == nil {
                        res.Milestone = &MilestoneInfo{
                                Code:  "course_" + courseID,
                                Label: fmt.Sprintf("%s completed", title),
                        }
                }
        }
        if newLeague := s.leagueIndex(ctx, userID); newLeague > prevLeague && newLeague > 0 {
                name := Leagues[clamp(newLeague, 0, len(Leagues)-1)]
                social.Milestone(ctx, s.Pool, userID, fmt.Sprintf("league_%d", newLeague),
                        fmt.Sprintf("just reached the %s League! 🏆", name),
                        map[string]any{"league": name})
                if res.Milestone == nil {
                        res.Milestone = &MilestoneInfo{
                                Code:  fmt.Sprintf("league_%d", newLeague),
                                Label: fmt.Sprintf("%s League reached", name),
                        }
                }
        }
}

func boolInt(b bool) int {
        if b {
                return 1
        }
        return 0
}

// ─── Weekly league (rollover + board) ─────────────────────────────────────

type LeagueEntry struct {
        Name  string `json:"name"`
        XP    int    `json:"xp"`
        Color string `json:"color"`
        IsYou bool   `json:"isYou"`
        // Username is set on REAL members: the board links those rows
        // to the public profile. Every row is real now - no fillers.
        Username string `json:"username,omitempty"`
        IsReal   bool   `json:"isReal"`
}

type LeagueBoard struct {
        League       string        `json:"league"`
        LeagueIndex  int           `json:"leagueIndex"`
        Leagues      []string      `json:"leagues"`
        Viewing      bool          `json:"viewing"`
        Entries      []LeagueEntry `json:"entries"`
        EndsInMs     int64         `json:"endsInMs"`
        PromotedCut  int           `json:"promotedCut"`
        DemotedFrom  int           `json:"demotedFrom"`
        PromotedLast bool          `json:"promotedLastWeek"`
        DemotedLast  bool          `json:"demotedLastWeek"`
        YourRank     int           `json:"yourRank"`
}

// ensureLeague finalizes last week when the learner's first touch of
// the new week happens (promotion pays 50 gems), then seats them in
// the current week's board. Promotion and demotion rank the learner
// against the REAL members of their league only.
func (s *Service) ensureLeague(ctx context.Context, q querier, userID string) error {
        now := time.Now()
        thisWeek := weekKey(now)
        var league int
        err := q.QueryRow(ctx, `SELECT COALESCE(MAX(league),0) FROM learn.league_members WHERE user_id=$1`, userID).Scan(&league)
        if err != nil {
                // learner row must exist; league_members may be empty
                league = 0
        }

        var seated bool
        _ = q.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM learn.league_members WHERE user_id=$1 AND week_key=$2)`,
                userID, thisWeek).Scan(&seated)
        if seated {
                return nil
        }

        // Finalize the previous week: rank the live XPEvent sum against
        // the REAL members seated in that week's league (founder directive
        // 2026-10-14: no synthetic rivals anywhere).
        prev := weekKey(now.AddDate(0, 0, -7))
        var mine int
        _ = q.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM learn.xp_events WHERE user_id=$1 AND week_key=$2`,
                userID, prev).Scan(&mine)
        var prevRow struct{ league, promoted, demoted int }
        _ = q.QueryRow(ctx, `SELECT league, promoted::int, demoted::int FROM learn.league_members WHERE user_id=$1 AND week_key=$2`,
                userID, prev).Scan(&prevRow.league, &prevRow.promoted, &prevRow.demoted)
        effLeague := league
        if prevRow.league > 0 {
                effLeague = prevRow.league
        }

        promoted, demoted := false, false
        if mine > 0 || prevRow.league > 0 {
                var ahead int
                _ = q.QueryRow(ctx, `
                        SELECT COUNT(*) FROM (
                                SELECT lm.user_id
                                FROM learn.league_members lm
                                LEFT JOIN learn.xp_events x ON x.user_id = lm.user_id AND x.week_key = lm.week_key
                                WHERE lm.week_key = $1 AND lm.league = $2 AND lm.user_id <> $3
                                GROUP BY lm.user_id
                                HAVING COALESCE(SUM(x.amount), 0) > $4
                        ) t`, prev, effLeague, userID, mine).Scan(&ahead)
                rank := ahead + 1
                if rank <= PromoteCut {
                        promoted = true
                        if _, err := q.Exec(ctx, `UPDATE learn.learners SET gems = gems + $2 WHERE user_id=$1`,
                                userID, LeaguePromotionGems); err != nil {
                                return err
                        }
                        if _, err := q.Exec(ctx, `
                                INSERT INTO learn.xp_events (user_id, amount, kind, week_key, day_key)
                                VALUES ($1,0,'league',$2,$3)`, userID, weekKey(now), LagosToday()); err != nil {
                                return err
                        }
                } else if rank >= DemoteFrom {
                        demoted = true
                }
        }

        newLeague := effLeague
        if promoted {
                newLeague = minInt(effLeague+1, len(Leagues)-1)
        } else if demoted {
                newLeague = maxInt(effLeague-1, 0)
        }

        _, err = q.Exec(ctx, `
                INSERT INTO learn.league_members (user_id, week_key, league, promoted, demoted)
                VALUES ($1,$2,$3,$4,$5)
                ON CONFLICT (user_id, week_key) DO UPDATE SET league=EXCLUDED.league`,
                userID, thisWeek, newLeague, promoted, demoted)
        return err
}

func (s *Service) leagueIndex(ctx context.Context, userID string) int {
        var idx int
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(MAX(league),0) FROM learn.league_members WHERE user_id=$1`, userID).Scan(&idx)
        return idx
}

// League renders the weekly board: you + every REAL member seated in
// this week's league (founder directive 2026-10-14: the synthetic rival
// rows are gone - a small board is simply a small board), the
// promote/demote zones and the countdown.
//
// viewLeague (founder directive 2026-10-17): -1 renders the caller's
// own league; 0..19 renders ANY league's board so learners can browse
// the whole 20-tier ladder and open the profiles inside it. YourRank is
// only meaningful when viewing your own board.
func (s *Service) League(ctx context.Context, userID string, viewLeague int) (*LeagueBoard, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        if err := s.ensureLeague(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        now := time.Now()
        week := weekKey(now)
        var league int
        if err := s.Pool.QueryRow(ctx, `SELECT league FROM learn.league_members WHERE user_id=$1 AND week_key=$2`,
                userID, week).Scan(&league); err != nil {
                league = 0
        }
        viewing := viewLeague >= 0 && viewLeague < len(Leagues) && viewLeague != league
        if viewing {
                league = viewLeague
        }
        var mine int
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM learn.xp_events WHERE user_id=$1 AND week_key=$2`,
                userID, week).Scan(&mine)

        board := &LeagueBoard{
                League: Leagues[clamp(league, 0, len(Leagues)-1)], LeagueIndex: league,
                Leagues:  Leagues, Viewing: viewing,
                EndsInMs: WeekEndsIn().Sub(now).Milliseconds(),
                PromotedCut: PromoteCut, DemotedFrom: DemoteFrom,
                // Always a slice, never nil (the browsed-tier crash of
                // 2026-10-17): an empty tier serialized as
                // "entries":null and the web board died on .map().
                Entries: []LeagueEntry{},
        }
        if !viewing {
                board.Entries = append(board.Entries, LeagueEntry{Name: "You", XP: mine, IsYou: true, IsReal: true, Color: AvatarColor("you:" + userID)})
        }

        // Real members seated in this week's league, ranked by their live
        // weekly XPEvent sum. Every row is a real account: the board links
        // it to the public profile.
        realRows, err := s.Pool.Query(ctx, `
                SELECT u.username, COALESCE(SUM(x.amount),0)
                FROM learn.league_members lm
                JOIN study.users u ON u.id = lm.user_id
                LEFT JOIN learn.xp_events x ON x.user_id = lm.user_id AND x.week_key = lm.week_key
                WHERE lm.week_key = $1 AND lm.league = $2 AND lm.user_id <> $3
                GROUP BY u.id, u.username
                ORDER BY 2 DESC LIMIT 30`, week, league, userID)
        if err == nil {
                for realRows.Next() {
                        var name string
                        var xp int
                        if err := realRows.Scan(&name, &xp); err != nil {
                                break
                        }
                        board.Entries = append(board.Entries, LeagueEntry{Name: name, XP: xp, Username: name, IsReal: true, Color: AvatarColor(name)})
                }
                realRows.Close()
        }
        // Rank by XP desc (stable: ties keep insertion order).
        for i := 0; i < len(board.Entries); i++ {
                for j := i + 1; j < len(board.Entries); j++ {
                        if board.Entries[j].XP > board.Entries[i].XP {
                                board.Entries[i], board.Entries[j] = board.Entries[j], board.Entries[i]
                        }
                }
        }
        for i := range board.Entries {
                if board.Entries[i].IsYou {
                        board.YourRank = i + 1
                }
        }
        // Last week's flags for the banner pills.
        var promoted, demoted bool
        prev := weekKey(now.AddDate(0, 0, -7))
        _ = s.Pool.QueryRow(ctx, `SELECT promoted, demoted FROM learn.league_members WHERE user_id=$1 AND week_key=$2`,
                userID, prev).Scan(&promoted, &demoted)
        board.PromotedLast, board.DemotedLast = promoted, demoted
        return board, nil
}

func minInt(a, b int) int {
        if a < b {
                return a
        }
        return b
}
func maxInt(a, b int) int {
        if a > b {
                return a
        }
        return b
}

// ─── Quests ───────────────────────────────────────────────────────────────

// QuestOut is the serve shape: QuestDef carries the catalogue row,
// the three state fields ride the OUTSIDE because QuestDef's own
// Progress/Claimed/Complete are json:"-" (they exist only to be
// filled at serve time). Without these the API shipped quests with
// NO progress at all - every bar sat at zero and the founder read
// the page as mock data (founder report 2026-10-14: "make sure the
// quest is working live").
type QuestOut struct {
        QuestDef
        PeriodKey string `json:"periodKey"`
        Progress  int    `json:"progress"`
        Claimed   bool   `json:"claimed"`
        Complete  bool   `json:"complete"`
}

type QuestsResponse struct {
        Daily   []QuestOut `json:"daily"`
        Weekly  QuestOut   `json:"weekly"`
        Monthly QuestOut   `json:"monthly"`
}

func (s *Service) Quests(ctx context.Context, userID string) (*QuestsResponse, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        now := time.Now()
        resp := &QuestsResponse{}

        day := LagosToday()
        var dayXP, dayCorrect, dayLessons, dayPerfect, dayPractice, dayCombo int
        err := s.Pool.QueryRow(ctx, `
                SELECT COALESCE(SUM(xp),0), COALESCE(SUM(correct),0), COALESCE(SUM(lessons),0),
                       COALESCE(SUM(perfect),0), COALESCE(SUM(practice),0), COALESCE(MAX(max_combo),0)
                FROM learn.daily_stats WHERE user_id=$1 AND day_key=$2`, userID, day).Scan(
                &dayXP, &dayCorrect, &dayLessons, &dayPerfect, &dayPractice, &dayCombo)
        if err != nil {
                return nil, err
        }
        stat := func(kind string) int {
                switch kind {
                case "xp":
                        return dayXP
                case "correct":
                        return dayCorrect
                case "lessons":
                        return dayLessons
                case "perfect":
                        return dayPerfect
                case "practice":
                        return dayPractice
                case "combo":
                        return dayCombo
                }
                return 0
        }
        for _, q := range DailyQuestsFor(now) {
                o := QuestOut{QuestDef: q, PeriodKey: day}
                o.Progress = stat(o.Kind)
                s.fillQuestState(ctx, userID, &o, day)
                resp.Daily = append(resp.Daily, o)
        }

        week := weekKey(now)
        var weekXP int
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM learn.xp_events WHERE user_id=$1 AND week_key=$2`,
                userID, week).Scan(&weekXP)
        resp.Weekly = QuestOut{QuestDef: weeklyQuest, PeriodKey: week}
        resp.Weekly.Progress = weekXP
        s.fillQuestState(ctx, userID, &resp.Weekly, week)

        month := monthKey(now)
        var monthXP int
        _ = s.Pool.QueryRow(ctx, `
                SELECT COALESCE(SUM(amount),0) FROM learn.xp_events
                WHERE user_id=$1 AND day_key LIKE $2 || '-%'`, userID, month).Scan(&monthXP)
        resp.Monthly = QuestOut{QuestDef: monthlyQuest, PeriodKey: month}
        resp.Monthly.Progress = monthXP
        s.fillQuestState(ctx, userID, &resp.Monthly, month)
        return resp, nil
}

func (s *Service) fillQuestState(ctx context.Context, userID string, o *QuestOut, periodKey string) {
        var claimed bool
        _ = s.Pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM learn.quest_claims WHERE user_id=$1 AND quest_key=$2 AND period_key=$3)`,
                userID, o.Key, periodKey).Scan(&claimed)
        o.Claimed = claimed
        o.Complete = o.Progress >= o.Target && !claimed
}

// ClaimQuest pays a finished quest's gems (idempotent via the PK).
func (s *Service) ClaimQuest(ctx context.Context, userID, questKey string) (int, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return 0, err
        }
        now := time.Now()
        var def *QuestDef
        period := ""
        switch {
        case questKey == weeklyQuest.Key:
                d := weeklyQuest
                def, period = &d, weekKey(now)
        case questKey == monthlyQuest.Key:
                d := monthlyQuest
                def, period = &d, monthKey(now)
        default:
                for _, q := range DailyQuestsFor(now) {
                        if q.Key == questKey {
                                d := q
                                def = &d
                                period = LagosToday()
                                break
                        }
                }
        }
        if def == nil {
                return 0, fmt.Errorf("learn: unknown quest %s", questKey)
        }
        resp, err := s.Quests(ctx, userID)
        if err != nil {
                return 0, err
        }
        var live *QuestOut
        for i := range resp.Daily {
                if resp.Daily[i].Key == questKey {
                        live = &resp.Daily[i]
                }
        }
        if live == nil && resp.Weekly.Key == questKey {
                live = &resp.Weekly
        }
        if live == nil && resp.Monthly.Key == questKey {
                live = &resp.Monthly
        }
        if live == nil || live.Progress < live.Target {
                return 0, fmt.Errorf("learn: quest not complete")
        }
        tag, err := s.Pool.Exec(ctx, `
                INSERT INTO learn.quest_claims (user_id, quest_key, period_key) VALUES ($1,$2,$3)
                ON CONFLICT DO NOTHING`, userID, questKey, period)
        if err != nil {
                return 0, err
        }
        if tag.RowsAffected() == 0 {
                return 0, fmt.Errorf("learn: quest already claimed")
        }
        if _, err := s.Pool.Exec(ctx, `UPDATE learn.learners SET gems = gems + $2 WHERE user_id=$1`,
                userID, def.Gems); err != nil {
                return 0, err
        }
        return def.Gems, nil
}

// ─── Shop ─────────────────────────────────────────────────────────────────

type ShopItem struct {
        Key     string `json:"key"`
        Title   string `json:"title"`
        Desc    string `json:"desc"`
        Gems    int    `json:"gems"`
        Icon    string `json:"icon"`
        Owned   int    `json:"owned"`
        Max     int    `json:"max"`
        SoldOut bool   `json:"soldOut"`
}

type ShopResponse struct {
        Gems   int        `json:"gems"`
        Hearts int        `json:"hearts"` // the real count - the ∞ readout is retired (founder rule)
        Items  []ShopItem `json:"items"`
        Super  ShopItem   `json:"superTrial"`
}

func (s *Service) Shop(ctx context.Context, userID string) (*ShopResponse, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                return nil, err
        }
        resp := &ShopResponse{Gems: l.Gems, Hearts: l.Hearts}
        heartsFull := s.UnlimitedHearts || l.SuperActive || l.Hearts >= MaxHearts
        resp.Items = []ShopItem{
                {Key: "freeze", Title: "Streak Freeze", Desc: "Protects your streak for a day of rest", Gems: FreezePrice, Icon: "ac_unit", Owned: l.FreezeCount, Max: MaxFreezes, SoldOut: l.FreezeCount >= MaxFreezes},
                {Key: "heart_refill", Title: "Heart Refill", Desc: "Refills your hearts to full", Gems: HeartRefillPrice, Icon: "favorite", SoldOut: heartsFull},
                {Key: "boost", Title: "Double XP", Desc: fmt.Sprintf("2× XP for %d minutes", BoostMinutes), Gems: BoostPrice, Icon: "bolt", SoldOut: l.BoostActive},
        }
        resp.Super = ShopItem{Key: "super_trial", Title: "Super Renance", Desc: "Unlimited hearts & no ads - 7 day free trial", Gems: 0, Icon: "workspace_premium", SoldOut: l.SuperActive}
        return resp, nil
}

// Buy spends gems on a shop item.
func (s *Service) Buy(ctx context.Context, userID, item string) (*ShopResponse, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                return nil, err
        }
        switch item {
        case "freeze":
                if l.FreezeCount >= MaxFreezes {
                        return nil, fmt.Errorf("learn: freeze stash full")
                }
                if l.Gems < FreezePrice {
                        return nil, fmt.Errorf("learn: not enough gems")
                }
                _, err = s.Pool.Exec(ctx, `UPDATE learn.learners SET gems = gems - $2, freeze_count = freeze_count + 1 WHERE user_id=$1`, userID, FreezePrice)
        case "heart_refill":
                if s.UnlimitedHearts || l.SuperActive {
                        return nil, fmt.Errorf("learn: hearts are unlimited")
                }
                if l.Hearts >= MaxHearts {
                        return nil, fmt.Errorf("learn: hearts already full")
                }
                if l.Gems < HeartRefillPrice {
                        return nil, fmt.Errorf("learn: not enough gems")
                }
                _, err = s.Pool.Exec(ctx, `UPDATE learn.learners SET gems = gems - $2, hearts = $3, hearts_updated_at = now() WHERE user_id=$1`, userID, HeartRefillPrice, MaxHearts)
        case "boost":
                if l.BoostActive {
                        return nil, fmt.Errorf("learn: boost already running")
                }
                if l.Gems < BoostPrice {
                        return nil, fmt.Errorf("learn: not enough gems")
                }
                // ($2 * interval '1 minute') - the old `interval '%d minutes'`
                // literal was never Sprintf'd (pgx does not format SQL), so
                // every boost purchase died on a Postgres syntax error.
                _, err = s.Pool.Exec(ctx, `UPDATE learn.learners SET gems = gems - $2, boost_until = now() + ($2 * interval '1 minute') WHERE user_id=$1`, userID, BoostPrice)
        case "super_trial":
                if l.SuperActive {
                        return nil, fmt.Errorf("learn: super already active")
                }
                // Same fix as the boost: ($2 * interval '1 day').
                _, err = s.Pool.Exec(ctx, `UPDATE learn.learners SET super_until = now() + ($2 * interval '1 day') WHERE user_id=$1`, userID, SuperTrialDays)
        default:
                return nil, fmt.Errorf("learn: unknown shop item %s", item)
        }
        if err != nil {
                return nil, err
        }
        return s.Shop(ctx, userID)
}

// ─── Chests ───────────────────────────────────────────────────────────────

type ChestResult struct {
        ChestKey  string `json:"chestKey"`
        Gems      int    `json:"gems"`
        GemsTotal int    `json:"gemsTotal"`
}

// OpenChest pays the unit-1 treasure chest (idempotent per key).
func (s *Service) OpenChest(ctx context.Context, userID, chestKey string) (*ChestResult, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        gems := ChestReward(chestKey)
        tag, err := s.Pool.Exec(ctx, `
                INSERT INTO learn.chest_opens (user_id, chest_key, gems) VALUES ($1,$2,$3)
                ON CONFLICT DO NOTHING`, userID, chestKey, gems)
        if err != nil {
                return nil, err
        }
        if tag.RowsAffected() == 0 {
                return nil, fmt.Errorf("learn: chest already opened")
        }
        if _, err := s.Pool.Exec(ctx, `
                UPDATE learn.learners SET gems = gems + $2 WHERE user_id=$1`, userID, gems); err != nil {
                return nil, err
        }
        day := LagosToday()
        _, _ = s.Pool.Exec(ctx, `
                INSERT INTO learn.daily_stats (user_id, day_key, chests_opened) VALUES ($1,$2,1)
                ON CONFLICT (user_id, day_key) DO UPDATE SET chests_opened = learn.daily_stats.chests_opened + 1`, userID, day)
        if _, err := s.Pool.Exec(ctx, `
                INSERT INTO learn.xp_events (user_id, amount, kind, week_key, day_key) VALUES ($1,0,'chest',$2,$3)`,
                userID, weekKey(time.Now()), day); err != nil {
                return nil, err
        }
        var total int
        _ = s.Pool.QueryRow(ctx, `SELECT gems FROM learn.learners WHERE user_id=$1`, userID).Scan(&total)
        return &ChestResult{ChestKey: chestKey, Gems: gems, GemsTotal: total}, nil
}

// ─── Mistakes practice ────────────────────────────────────────────────────

type PracticeQuestion struct {
        ID          string            `json:"id"`
        Type        string            `json:"type"`
        Stem        string            `json:"stem"`
        Options     map[string]string `json:"options,omitempty"`
        Answer      string            `json:"answer"`
        Explanation string            `json:"explanation,omitempty"`
        TopicID     string            `json:"topicId,omitempty"`
}

type PracticeSet struct {
        Questions []PracticeQuestion `json:"questions"`
}

// PracticeSet serves unresolved mistakes first, then tops up from the
// cached lesson quizzes of the student's courses (Supreme parity).
func (s *Service) PracticeSet(ctx context.Context, userID string) (*PracticeSet, error) {
        set := &PracticeSet{Questions: []PracticeQuestion{}}
        seen := map[string]bool{}
        rows, err := s.Pool.Query(ctx, `
                SELECT question_id, payload FROM learn.mistakes
                WHERE user_id=$1 AND resolved=FALSE ORDER BY updated_at DESC LIMIT 8`, userID)
        if err != nil {
                return nil, err
        }
        for rows.Next() {
                var id string
                var payload []byte
                if err := rows.Scan(&id, &payload); err != nil {
                        rows.Close()
                        return nil, err
                }
                var q PracticeQuestion
                if json.Unmarshal(payload, &q) == nil && q.Stem != "" {
                        if !seen[q.ID] {
                                seen[q.ID] = true
                                set.Questions = append(set.Questions, q)
                        }
                }
        }
        rows.Close()
        if len(set.Questions) >= 8 {
                return set, rows.Err()
        }

        // Top up from cached lesson quizzes. Two-step pool-safe rewrite
        // (user_courses on the user database, topics on the content
        // database, lessons on the cache database): enrolled course ids
        // from the user pool, topic ids from the content pool, quizzes
        // from the cache pool.
        tqs, terr := func() ([]topicQuiz, error) {
                courses, err := s.enrolledCourseIDs(ctx, userID, 40)
                if err != nil {
                        return nil, err
                }
                tmap, err := s.topicIDsForCourses(ctx, courses)
                if err != nil {
                        return nil, err
                }
                var ids []string
                for _, list := range tmap {
                        ids = append(ids, list...)
                }
                if len(ids) > 3000 {
                        ids = ids[:3000]
                }
                return s.lessonQuizzesByTopic(ctx, ids, 12)
        }()
        if terr != nil {
                return set, nil
        }
        for _, tq := range tqs {
                if len(set.Questions) >= 8 {
                        break
                }
                raw := []byte(tq.Raw)
                var qs []LessonQuizQ
                if json.Unmarshal(raw, &qs) != nil {
                        continue
                }
                // Same serve-time sweep as the lesson itself: every quiz
                // question that reaches a student has an answer that points
                // at one of its own options (the option count itself is
                // never rewritten).
                qs, _ = sanitizeQuiz(qs)
                for _, q := range qs {
                        if len(set.Questions) >= 8 {
                                break
                        }
                        if q.ID != "" && !seen[q.ID] && q.Answer != "" {
                                seen[q.ID] = true
                                set.Questions = append(set.Questions, practiceFromLesson(q))
                        }
                }
        }
        return set, nil
}

// practiceFromLesson carries one sanitized lesson question into the
// practice payload (identical wire shape, kept explicit for the reader).
func practiceFromLesson(q LessonQuizQ) PracticeQuestion {
        return PracticeQuestion{
                ID:          q.ID,
                Type:        q.Type,
                Stem:        q.Stem,
                Options:     q.Options,
                Answer:      q.Answer,
                Explanation: q.Explanation,
        }
}

// GradePractice pays the small practice reward: 2 XP per correct
// (+5 perfect), resolves mistakes, ≥80% accuracy refills hearts.
func (s *Service) GradePractice(ctx context.Context, userID string, correct, total int, resolvedIDs []string) (*CompleteResult, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                return nil, err
        }
        res := &CompleteResult{Unlimited: s.UnlimitedHearts || l.SuperActive}
        if total <= 0 {
                return res, nil
        }
        percent := int(math.Round(float64(correct) * 100 / float64(total)))
        xp := correct * PracticeXPPerCorrect
        if percent == 100 {
                xp += 5
        }
        res.XPEarned = xp
        day := LagosToday()

        for _, id := range resolvedIDs {
                _, _ = s.Pool.Exec(ctx, `UPDATE learn.mistakes SET resolved=TRUE WHERE user_id=$1 AND question_id=$2`, userID, id)
        }

        tx, err := s.Pool.Begin(ctx)
        if err != nil {
                return nil, err
        }
        defer tx.Rollback(ctx)
        if xp > 0 {
                if _, err := tx.Exec(ctx, `
                        INSERT INTO learn.xp_events (user_id, amount, kind, week_key, day_key) VALUES ($1,$2,'practice',$3,$4)`,
                        userID, xp, weekKey(time.Now()), day); err != nil {
                        return nil, err
                }
        }
        if _, err := tx.Exec(ctx, `
                INSERT INTO learn.daily_stats (user_id, day_key, xp, correct, practice)
                VALUES ($1,$2,$3,$4,1)
                ON CONFLICT (user_id, day_key) DO UPDATE SET
                  xp = learn.daily_stats.xp + $3, correct = learn.daily_stats.correct + $4, practice = learn.daily_stats.practice + 1`,
                userID, day, xp, correct); err != nil {
                return nil, err
        }
        heartsFull := false
        if percent >= 80 && !s.UnlimitedHearts && !l.SuperActive && l.Hearts < MaxHearts {
                if _, err := tx.Exec(ctx, `UPDATE learn.learners SET hearts=$2, hearts_updated_at=now() WHERE user_id=$1`,
                        userID, MaxHearts); err != nil {
                        return nil, err
                }
                heartsFull = true
        }
        if _, err := tx.Exec(ctx, `UPDATE learn.learners SET xp = xp + $2 WHERE user_id=$1`, userID, xp); err != nil {
                return nil, err
        }
        if err := tx.Commit(ctx); err != nil {
                return nil, err
        }
        res.Hearts = MaxHearts
        _ = heartsFull
        l2, _ := s.loadLearner(ctx, s.Pool, userID)
        if l2 != nil {
                res.Hearts, res.Gems, res.XPTotal = l2.Hearts, l2.Gems, l2.XP
        }
        return res, nil
}

// ─── Unit review (trophy node) ────────────────────────────────────────────

// ReviewSet mixes the cached quizzes of a unit's completed topics.
func (s *Service) ReviewSet(ctx context.Context, userID, courseID string, unit int) (*PracticeSet, error) {
        set := &PracticeSet{Questions: []PracticeQuestion{}}
        // Two-step pool-safe rewrite (progress on the user database,
        // topics on the content database, lessons on the cache
        // database): the unit's completed topic ids come from the user +
        // content pools, the quizzes from the cache pool.
        tqs, terr := func() ([]topicQuiz, error) {
                var ids []string
                if rows, err := s.Pool.Query(ctx, `
                SELECT topic_id FROM learn.topics
                WHERE course_id=$1 AND unit=$2 ORDER BY seq`, courseID, unit); err == nil {
                        for rows.Next() {
                                var id string
                                if rows.Scan(&id) == nil {
                                        ids = append(ids, id)
                                }
                        }
                        rows.Close()
                }
                done, err := s.progressDoneSet(ctx, userID, ids)
                if err != nil {
                        return nil, err
                }
                var doneIDs []string
                for _, id := range ids {
                        if done[id] {
                                doneIDs = append(doneIDs, id)
                        }
                }
                if len(doneIDs) == 0 {
                        return nil, nil
                }
                return s.lessonQuizzesRandom(ctx, doneIDs, 3)
        }()
        if terr != nil {
                return set, nil
        }
        seen := map[string]bool{}
        for _, tq := range tqs {
                raw := []byte(tq.Raw)
                var qs []LessonQuizQ
                if json.Unmarshal(raw, &qs) != nil {
                        continue
                }
                // Serve-time sweep (founder 2026-10-15): the review quiz
                // obeys the same answer-alignment doctrine (option counts
                // are never rewritten).
                qs, _ = sanitizeQuiz(qs)
                for _, q := range qs {
                        if len(set.Questions) >= 8 {
                                break
                        }
                        if q.ID != "" && !seen[q.ID] {
                                seen[q.ID] = true
                                set.Questions = append(set.Questions, practiceFromLesson(q))
                        }
                }
        }
        return set, nil
}

// ─── Unit revision (the special last section of every unit) ──────────────

// RevisionTarget is the size of the unit revision exam (founder
// directive 2026-10-16: "build a section at the last place of each
// unit, a special unit, 50 revision questions fetched from the topics
// under that unit"). Ten topics carry 20 questions each, a 200 item
// pool; the exam draws an equal spread across ALL of the unit's
// topics so it revises the whole unit, not three lucky rows.
const RevisionTarget = 50

// RevisionSet assembles the 50 question revision exam for one unit.
// Every topic under the unit contributes: its cached quiz when the
// lesson cache holds one, otherwise the deterministic engine writes
// the quiz on the spot (pure CPU - no AI call, no budget, no cache
// write). Each topic donates an equal share, donations rotate so
// repeat visits meet different questions, and the final order shuffles
// deterministically per course+unit+UTC day: a mid exam refresh never
// rearranges the paper, the next day does.
func (s *Service) RevisionSet(ctx context.Context, userID, courseID string, unit int) (*PracticeSet, error) {
        set := &PracticeSet{Questions: []PracticeQuestion{}}
        if unit < 1 {
                unit = 1
        }

        // The course context the synthesis engine needs.
        var title, dept, faculty string
        err := s.Pool.QueryRow(ctx, `
                SELECT c.title, COALESCE(d.name,''), COALESCE(d.faculty,'')
                FROM learn.courses c JOIN learn.departments d ON d.dept_id = c.dept_id
                WHERE c.course_id=$1`, courseID).Scan(&title, &dept, &faculty)
        if err != nil {
                return set, nil
        }

        type unitTopic struct {
                id, title string
                unit      int
        }
        rows, err := s.Pool.Query(ctx, `
                SELECT topic_id, title, unit FROM learn.topics
                WHERE course_id=$1 AND unit=$2 ORDER BY seq`, courseID, unit)
        if err != nil {
                return set, nil
        }
        topics := []unitTopic{}
        for rows.Next() {
                var t unitTopic
                if err := rows.Scan(&t.id, &t.title, &t.unit); err == nil {
                        topics = append(topics, t)
                }
        }
        rows.Close()
        if len(topics) == 0 {
                return set, nil
        }

        // One round trip for every cached quiz under the unit.
        ids := make([]string, 0, len(topics))
        for _, t := range topics {
                ids = append(ids, t.id)
        }
        cached := map[string][]LessonQuizQ{}
        crows, err := s.Pool.Query(ctx, `
                SELECT topic_id, quiz FROM learn.lessons
                WHERE topic_id = ANY($1) AND jsonb_array_length(quiz) > 0`, ids)
        if err == nil {
                for crows.Next() {
                        var tid string
                        var raw []byte
                        if err := crows.Scan(&tid, &raw); err != nil {
                                continue
                        }
                        var qs []LessonQuizQ
                        if json.Unmarshal(raw, &qs) != nil {
                                continue
                        }
                        cached[tid] = qs
                }
                crows.Close()
        }

        // Equal share per topic, the remainder spread from the front.
        // Ten topics donate exactly 5 each; a short unit gives what it
        // has and the spread tops up from the strongest donors.
        per := RevisionTarget / len(topics)
        if per == 0 {
                per = 1
        }
        rem := RevisionTarget - per*len(topics)

        seen := map[string]bool{}
        pool := []PracticeQuestion{}
        for i, t := range topics {
                quiz := cached[t.id]
                if len(quiz) == 0 {
                        // The deterministic agent engine writes the quiz on
                        // the spot - instant and identical to what the topic
                        // open would serve, so the revision never waits on
                        // the cache and never grows it either.
                        out := synth.BuildLesson(t.id, title, dept, faculty, t.title, t.unit)
                        quiz = make([]LessonQuizQ, 0, len(out.Quiz))
                        for _, q := range out.Quiz {
                                quiz = append(quiz, LessonQuizQ{
                                        ID: q.ID, Type: q.Type, Stem: q.Stem,
                                        Options: q.Options, Answer: q.Answer, Explanation: q.Explanation,
                                })
                        }
                }
                // Same serve-time sweep the lesson and review paths use.
                quiz, _ = sanitizeQuiz(quiz)
                if len(quiz) == 0 {
                        continue
                }
                take := per
                if i < rem {
                        take++
                }
                if take > len(quiz) {
                        take = len(quiz)
                }
                start := (i * take) % len(quiz)
                for k := 0; k < take; k++ {
                        q := quiz[(start+k)%len(quiz)]
                        if q.ID == "" || q.Stem == "" || q.Answer == "" || seen[q.ID] {
                                continue
                        }
                        seen[q.ID] = true
                        pq := practiceFromLesson(q)
                        pq.TopicID = t.id
                        pool = append(pool, pq)
                }
        }

        // Deterministic shuffle keyed on course+unit+UTC day.
        g := synth.NewRNG(fmt.Sprintf("%s|revision|%d|%s", courseID, unit, time.Now().UTC().Format("2006-01-02")))
        for i := len(pool) - 1; i > 0; i-- {
                j := g.Intn(i + 1)
                pool[i], pool[j] = pool[j], pool[i]
        }
        if len(pool) > RevisionTarget {
                pool = pool[:RevisionTarget]
        }
        set.Questions = pool
        return set, nil
}
