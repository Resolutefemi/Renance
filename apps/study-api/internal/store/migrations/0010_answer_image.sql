-- 0010: worked-solution material for review answers (myschool harvest).
-- answer_image: a worked-solution diagram (image URL path under /qimages/).
-- video: optional walkthrough video link carried with the key.
ALTER TABLE study.answer_keys
  ADD COLUMN IF NOT EXISTS answer_image text NOT NULL DEFAULT '';
ALTER TABLE study.answer_keys
  ADD COLUMN IF NOT EXISTS video text NOT NULL DEFAULT '';
