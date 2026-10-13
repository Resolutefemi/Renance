// ledger.go — the completion ledger and the reward economy: everything
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
)

// ─── Completion ledger ────────────────────────────────────────────────────

type MistakeIn struct {
        ID         string          `json:"id"`
        Stem       string          `json:"stem"`
        Type       string          `json:"type"`
        Options    map[string]string `json:"options,omitempty"`
        Answer     string          `json:"answer"`
        Explanation string         `json:"explanation,omitempty"`
        UserAnswer json.RawMessage `json:"userAnswer,omitempty"`
        Year       int             `json:"year,omitempty"`
}

type CompleteRequest struct {
        TopicID   string       `json:"topicId"`
        Correct   int          `json:"correct"`
        Total     int          `json:"total"`
        MaxCombo  int          `json:"maxCombo"`
        Mistakes  []MistakeIn  `json:"mistakes"`
        Abandoned bool         `json:"abandoned"`
}

type CompleteResult struct {
        XPEarned      int    `json:"xpEarned"`
        GemsEarned    int    `json:"gemsEarned"`
        Perfect       bool   `json:"perfect"`
        FirstClear    bool   `json:"firstClear"`
        ComboBonus    int    `json:"comboBonus"`
        Boosted       bool   `json:"boosted"`
        Streak        int    `json:"streak"`
        Hearts        int    `json:"hearts"`
        Unlimited     bool   `json:"unlimitedHearts"`
        Gems          int    `json:"gems"`
        XPTotal       int    `json:"xp"`
        CompletedPct  int    `json:"completedPercent"`
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
                        userID, m.ID, req.TopicID, payload); err != nil {
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
        today := LagosToday()
        if l.LastActive != today {
                sr := ComputeStreak(l.Streak, l.LastActive, l.FreezeCount, time.Now())
                res.Streak = sr.Count
                freeze := l.FreezeCount
                if sr.ConsumedOne {
                        freeze--
                }
                if _, err := tx.Exec(ctx, `
                        UPDATE learn.learners SET streak_count=$2, last_active_on=$3, freeze_count=$4
                        WHERE user_id=$1`, userID, sr.Count, today, freeze); err != nil {
                        return nil, err
                }
                l.Streak = sr.Count
        } else {
                res.Streak = l.Streak
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

        // Course completion percentage for the done screen.
        _ = s.Pool.QueryRow(ctx, `
                SELECT COALESCE(int(round(100.0 * (
                  SELECT COUNT(*) FROM learn.progress pr
                  JOIN learn.topics t ON t.topic_id = pr.topic_id
                  WHERE pr.user_id=$1 AND t.course_id=$2), (
                  SELECT COUNT(*) FROM learn.topics t WHERE t.course_id=$2))), 0)`,
                userID, courseID).Scan(&res.CompletedPct)

        l, _ = s.loadLearner(ctx, s.Pool, userID)
        if l != nil {
                res.Hearts, res.Gems, res.XPTotal, res.Unlimited = l.Hearts, l.Gems, l.XP, s.UnlimitedHearts || l.SuperActive
        }
        return res, nil
}

func boolInt(b bool) int {
        if b {
                return 1
        }
        return 0
}

// ─── Weekly league (rollover + board) ─────────────────────────────────────

type LeagueEntry struct {
        Name    string `json:"name"`
        XP      int    `json:"xp"`
        Color   string `json:"color"`
        IsYou   bool   `json:"isYou"`
}

type LeagueBoard struct {
        League       string        `json:"league"`
        LeagueIndex  int           `json:"leagueIndex"`
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
// the current week's board.
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

        // Finalize the previous week: your XPEvent sum vs the deterministic
        // rivals at full-week pace.
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
                rank := 1
                for _, r := range RivalsFor(prev, effLeague, 1.0) {
                        if r.XP > mine {
                                rank++
                        }
                }
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

// League renders the weekly board: you + 30 deterministic rivals,
// promote/demote zones and the countdown.
func (s *Service) League(ctx context.Context, userID string) (*LeagueBoard, error) {
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
        var mine int
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM learn.xp_events WHERE user_id=$1 AND week_key=$2`,
                userID, week).Scan(&mine)

        // Week progress drives rival pacing (Supreme weekProgress).
        start := weekStart(now)
        progress := now.Sub(start).Hours() / (7 * 24)

        board := &LeagueBoard{
                League: Leagues[clamp(league, 0, len(Leagues)-1)], LeagueIndex: league,
                EndsInMs: WeekEndsIn().Sub(now).Milliseconds(),
                PromotedCut: PromoteCut, DemotedFrom: DemoteFrom,
        }
        board.Entries = append(board.Entries, LeagueEntry{Name: "You", XP: mine, IsYou: true})
        for _, r := range RivalsFor(week, league, progress) {
                board.Entries = append(board.Entries, LeagueEntry{Name: r.Name, XP: r.XP, Color: r.Color})
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

func weekStart(now time.Time) time.Time {
        n := now.In(lagos)
        weekday := int(n.Weekday())
        if weekday == 0 {
                weekday = 7
        }
        return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, lagos).AddDate(0, 0, -(weekday - 1))
}

func minInt(a, b int) int { if a < b { return a }; return b }
func maxInt(a, b int) int { if a > b { return a }; return b }

// ─── Quests ───────────────────────────────────────────────────────────────

type QuestOut struct {
        QuestDef
        PeriodKey string `json:"periodKey"`
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
                s.fillClaimState(ctx, userID, &o.QuestDef, day)
                resp.Daily = append(resp.Daily, o)
        }

        week := weekKey(now)
        var weekXP int
        _ = s.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount),0) FROM learn.xp_events WHERE user_id=$1 AND week_key=$2`,
                userID, week).Scan(&weekXP)
        resp.Weekly = QuestOut{QuestDef: weeklyQuest, PeriodKey: week}
        resp.Weekly.Progress = weekXP
        s.fillClaimState(ctx, userID, &resp.Weekly.QuestDef, week)

        month := monthKey(now)
        var monthXP int
        _ = s.Pool.QueryRow(ctx, `
                SELECT COALESCE(SUM(amount),0) FROM learn.xp_events
                WHERE user_id=$1 AND day_key LIKE $2 || '-%'`, userID, month).Scan(&monthXP)
        resp.Monthly = QuestOut{QuestDef: monthlyQuest, PeriodKey: month}
        resp.Monthly.Progress = monthXP
        s.fillClaimState(ctx, userID, &resp.Monthly.QuestDef, month)
        return resp, nil
}

func (s *Service) fillClaimState(ctx context.Context, userID string, q *QuestDef, periodKey string) {
        var claimed bool
        _ = s.Pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM learn.quest_claims WHERE user_id=$1 AND quest_key=$2 AND period_key=$3)`,
                userID, q.Key, periodKey).Scan(&claimed)
        q.Claimed = claimed
        q.Complete = q.Progress >= q.Target && !claimed
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
        Key        string `json:"key"`
        Title      string `json:"title"`
        Desc       string `json:"desc"`
        Gems       int    `json:"gems"`
        Icon       string `json:"icon"`
        Owned      int    `json:"owned"`
        Max        int    `json:"max"`
        SoldOut    bool   `json:"soldOut"`
}

type ShopResponse struct {
        Gems  int        `json:"gems"`
        Items []ShopItem `json:"items"`
        Super ShopItem   `json:"superTrial"`
}

func (s *Service) Shop(ctx context.Context, userID string) (*ShopResponse, error) {
        if err := s.ensureLearner(ctx, s.Pool, userID); err != nil {
                return nil, err
        }
        l, err := s.loadLearner(ctx, s.Pool, userID)
        if err != nil {
                return nil, err
        }
        resp := &ShopResponse{Gems: l.Gems}
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
                _, err = s.Pool.Exec(ctx, `UPDATE learn.learners SET gems = gems - $2, boost_until = now() + interval '%d minutes' WHERE user_id=$1`, userID, BoostPrice)
        case "super_trial":
                if l.SuperActive {
                        return nil, fmt.Errorf("learn: super already active")
                }
                _, err = s.Pool.Exec(ctx, `UPDATE learn.learners SET super_until = now() + interval '%d days' WHERE user_id=$1`, userID, SuperTrialDays)
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
        ChestKey string `json:"chestKey"`
        Gems     int    `json:"gems"`
        GemsTotal int   `json:"gemsTotal"`
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

        // Top up from cached lesson quizzes.
        rows2, err := s.Pool.Query(ctx, `
                SELECT l.quiz FROM learn.lessons l
                JOIN learn.topics t ON t.topic_id = l.topic_id
                JOIN learn.user_courses uc ON uc.course_id = t.course_id
                WHERE uc.user_id=$1 AND jsonb_array_length(l.quiz) > 0
                ORDER BY l.hit_count DESC, random() LIMIT 12`, userID)
        if err != nil {
                return set, nil
        }
        defer rows2.Close()
        for rows2.Next() && len(set.Questions) < 8 {
                var raw []byte
                if err := rows2.Scan(&raw); err != nil {
                        continue
                }
                var qs []PracticeQuestion
                if json.Unmarshal(raw, &qs) != nil {
                        continue
                }
                for _, q := range qs {
                        if len(set.Questions) >= 8 {
                                break
                        }
                        if q.ID != "" && !seen[q.ID] && q.Answer != "" {
                                seen[q.ID] = true
                                set.Questions = append(set.Questions, q)
                        }
                }
        }
        return set, nil
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
        rows, err := s.Pool.Query(ctx, `
                SELECT l.quiz FROM learn.lessons l
                JOIN learn.topics t ON t.topic_id = l.topic_id
                JOIN learn.progress pr ON pr.user_id=$1 AND pr.topic_id = t.topic_id
                WHERE t.course_id=$2 AND t.unit=$3 AND jsonb_array_length(l.quiz) > 0
                ORDER BY random() LIMIT 3`, userID, courseID, unit)
        if err != nil {
                return set, nil
        }
        defer rows.Close()
        seen := map[string]bool{}
        for rows.Next() {
                var raw []byte
                if err := rows.Scan(&raw); err != nil {
                        continue
                }
                var qs []PracticeQuestion
                if json.Unmarshal(raw, &qs) != nil {
                        continue
                }
                for _, q := range qs {
                        if len(set.Questions) >= 8 {
                                break
                        }
                        if q.ID != "" && !seen[q.ID] {
                                seen[q.ID] = true
                                set.Questions = append(set.Questions, q)
                        }
                }
        }
        return set, rows.Err()
}
