'use client';

/**
 * VoiceOfLearner modals (founder directive 2026-10-17):
 *
 *  - FlagQuestionModal: report a wrong/broken question straight from a
 *    quiz. Lands in learn.question_flags, readable on the admin desk.
 *  - CourseRequestModal: "I cannot find my course" - the learner
 *    submits the course code/title plus the topics they expect. Lands
 *    in learn.course_submissions with their identity attached.
 *
 * Both are thin, styled like the rest of the learn chrome, and fail
 * loud (the founder wants to hear about broken content, not swallow it).
 */

import { useState } from 'react';
import { flagQuestion, submitCourseRequest } from '@/lib/learn';

const FLAG_REASONS = [
  'Wrong answer key',
  'Question is unclear',
  'Options are broken/duplicated',
  'Image or media missing',
  'Wrong course/topic',
] as const;

export function FlagQuestionModal({
  onClose,
  source = 'lesson',
  questionId = '',
  courseCode = '',
}: {
  onClose: () => void;
  source?: string;
  questionId?: string;
  courseCode?: string;
}) {
  const [reason, setReason] = useState<string>(FLAG_REASONS[0]);
  const [details, setDetails] = useState('');
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setBusy(true);
    setError(null);
    try {
      await flagQuestion({ source, questionId, courseCode, reason, details });
      setDone(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send the report');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[80] flex items-end justify-center bg-on-background/60 backdrop-blur-sm sm:items-center"
      onClick={done ? onClose : undefined}
    >
      <div
        className="w-full max-w-md rounded-t-2xl bg-card p-5 shadow-2xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {done ? (
          <>
            <h3 className="text-lg font-bold text-on-surface">Report sent</h3>
            <p className="mt-1 text-sm text-on-surface-variant">
              Thank you - the desk reviews every report. Your account keeps studying while it waits.
            </p>
            <button
              type="button"
              onClick={onClose}
              className="mt-4 h-11 w-full rounded-xl bg-primary text-[15px] font-semibold text-on-primary"
            >
              Back to the quiz
            </button>
          </>
        ) : (
          <>
            <h3 className="text-lg font-bold text-on-surface">Report this question</h3>
            <p className="mt-0.5 text-[13px] text-on-surface-variant">
              {courseCode ? `${courseCode} · ` : ''}
              {questionId ? `question ${questionId}` : 'the question on screen'}
            </p>
            <div className="mt-3 flex flex-col gap-1.5">
              {FLAG_REASONS.map((r) => (
                <button
                  key={r}
                  type="button"
                  onClick={() => setReason(r)}
                  className={`rounded-xl border px-3.5 py-2.5 text-left text-sm transition ${
                    reason === r
                      ? 'border-primary bg-selection-blue/40 font-semibold text-on-surface'
                      : 'border-outline-variant text-on-surface-variant hover:bg-surface-container-low'
                  }`}
                >
                  {r}
                </button>
              ))}
            </div>
            <textarea
              value={details}
              onChange={(e) => setDetails(e.target.value)}
              placeholder="Optional: what exactly is wrong?"
              rows={3}
              className="mt-3 w-full resize-none rounded-xl border border-outline-variant bg-surface-container-lowest p-3 text-sm text-on-surface outline-none placeholder:text-on-surface-variant/70 focus:border-primary"
            />
            {error && <p className="mt-2 text-[13px] font-semibold text-error">{error}</p>}
            <div className="mt-4 flex gap-2">
              <button
                type="button"
                onClick={onClose}
                className="h-11 flex-1 rounded-xl bg-surface-container-low text-[15px] font-semibold text-on-surface"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={submit}
                className="h-11 flex-1 rounded-xl bg-primary text-[15px] font-semibold text-on-primary disabled:opacity-60"
              >
                {busy ? 'Sending…' : 'Send report'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export function CourseRequestModal({
  onClose,
  defaultSchool = '',
}: {
  onClose: () => void;
  defaultSchool?: string;
}) {
  const [institutionType, setInstitutionType] = useState('university');
  const [schoolName, setSchoolName] = useState(defaultSchool);
  const [department, setDepartment] = useState('');
  const [courseCode, setCourseCode] = useState('');
  const [courseTitle, setCourseTitle] = useState('');
  const [topics, setTopics] = useState('');
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setBusy(true);
    setError(null);
    try {
      await submitCourseRequest({
        institutionType,
        schoolName,
        department,
        courseCode,
        courseTitle,
        topics,
      });
      setDone(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not send the course');
    } finally {
      setBusy(false);
    }
  };

  const field =
    'h-11 w-full rounded-xl border border-outline-variant bg-surface-container-lowest px-3.5 text-sm text-on-surface outline-none placeholder:text-on-surface-variant/70 focus:border-primary';

  return (
    <div
      className="fixed inset-0 z-[80] flex items-end justify-center bg-on-background/60 backdrop-blur-sm sm:items-center"
      onClick={done ? onClose : undefined}
    >
      <div
        className="max-h-[88dvh] w-full max-w-md overflow-y-auto rounded-t-2xl bg-card p-5 shadow-2xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {done ? (
          <>
            <h3 className="text-lg font-bold text-on-surface">Course submitted</h3>
            <p className="mt-1 text-sm text-on-surface-variant">
              The desk has your course and its topics. It lands in the review queue with your name
              on it - watch the app for the update.
            </p>
            <button
              type="button"
              onClick={onClose}
              className="mt-4 h-11 w-full rounded-xl bg-primary text-[15px] font-semibold text-on-primary"
            >
              Done
            </button>
          </>
        ) : (
          <>
            <h3 className="text-lg font-bold text-on-surface">Can&apos;t find your course?</h3>
            <p className="mt-0.5 text-[13px] text-on-surface-variant">
              Tell us the course and some of its topics - we&apos;ll build the question bank.
            </p>
            <div className="mt-3 flex flex-col gap-2">
              <select
                value={institutionType}
                onChange={(e) => setInstitutionType(e.target.value)}
                className={field}
              >
                <option value="university">University</option>
                <option value="polytechnic">Polytechnic</option>
                <option value="college-of-education">College of Education</option>
                <option value="college-of-nursing">College of Nursing</option>
                <option value="other">Other</option>
              </select>
              <input
                value={schoolName}
                onChange={(e) => setSchoolName(e.target.value)}
                placeholder="School name (e.g. FUTA)"
                className={field}
              />
              <input
                value={department}
                onChange={(e) => setDepartment(e.target.value)}
                placeholder="Department (e.g. Computer Science)"
                className={field}
              />
              <input
                value={courseCode}
                onChange={(e) => setCourseCode(e.target.value)}
                placeholder="Course code (e.g. CSC 101)"
                className={field}
              />
              <input
                value={courseTitle}
                onChange={(e) => setCourseTitle(e.target.value)}
                placeholder="Course title (e.g. Introduction to Computing)"
                className={field}
              />
              <textarea
                value={topics}
                onChange={(e) => setTopics(e.target.value)}
                placeholder="Some topics you expect in this course (one per line)"
                rows={4}
                className="w-full resize-none rounded-xl border border-outline-variant bg-surface-container-lowest p-3 text-sm text-on-surface outline-none placeholder:text-on-surface-variant/70 focus:border-primary"
              />
            </div>
            {error && <p className="mt-2 text-[13px] font-semibold text-error">{error}</p>}
            <div className="mt-4 flex gap-2">
              <button
                type="button"
                onClick={onClose}
                className="h-11 flex-1 rounded-xl bg-surface-container-low text-[15px] font-semibold text-on-surface"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={busy || !schoolName.trim() || (!courseCode.trim() && !courseTitle.trim())}
                onClick={submit}
                className="h-11 flex-1 rounded-xl bg-primary text-[15px] font-semibold text-on-primary disabled:opacity-60"
              >
                {busy ? 'Sending…' : 'Submit course'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
