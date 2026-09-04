-- 0006: adaptive ordering (ROADMAP #5) — weak-topic-first question order.
-- When a student starts a paper with adaptive: true, the API ranks the
-- pack's topics by weakness (the same SM-2 signal the review queue keeps:
-- ease, lapses, last accuracy, due-ness), orders topics weakest-first and
-- walks each topic easy -> hard. The resulting question id order is
-- persisted on the attempt so grading, review and the paper history all
-- see exactly the paper the student answered. NULL = pack's natural
-- order (every attempt created before this migration, and every
-- non-adaptive one after it).
ALTER TABLE study.attempts ADD COLUMN IF NOT EXISTS question_order text[];
ALTER TABLE study.attempts ADD COLUMN IF NOT EXISTS adaptive boolean NOT NULL DEFAULT false;
