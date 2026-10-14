-- 0030_course_desk.sql - the course desk (founder directive 2026-10-14:
-- "make sure users department are saved to the dB"). The tertiary desk
-- gates on the kind of institution, then the department, and both ride
-- the learner row so the choice survives every device.

ALTER TABLE learn.learners ADD COLUMN IF NOT EXISTS institution_type TEXT NOT NULL DEFAULT ''; -- University | Polytechnic | College of Education
ALTER TABLE learn.learners ADD COLUMN IF NOT EXISTS department TEXT NOT NULL DEFAULT '';      -- learn.departments.dept_id
