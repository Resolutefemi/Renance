# School Platform API

The school platform rides on the same study API (`apps/study-api`) as
the candidate world. Every school endpoint is prefixed `/school/`, is
authorized with the normal bearer token (unless marked PUBLIC), and
speaks JSON. Errors return `{ "error": "<code>", "message": "<human
text>" }` with a fitting HTTP status.

Conventions:

- `schoolId` travels as a query parameter on GET/DELETE and in the
  JSON body on PUT/POST. The server resolves the caller's membership
  and answers 403 when they are not an active member.
- Role gates: endpoints marked MANAGEMENT check the caller's role and
  answer 403 for teachers. Unmarked endpoints serve management and
  teachers alike.
- Text stored anywhere in the school world passes the house rule: no
  long dashes, no `--` runs. The server collapses them silently.
- Sessions are strings like `2025/2026`; terms are 1, 2 or 3.

## Auth and identity

### POST /school/auth/register

PUBLIC. Registers a school and its management owner in one call.

```json
{
  "schoolName": "Government College",
  "schoolType": "both",
  "fullName": "Ada Principal",
  "email": "ada@school.ng",
  "password": "correct-horse"
}
```

Response: `{ token, user, school: { id, name, schoolType, memberId, role } }`.
The school lands with no classes; call seed-curriculum next.

### GET /school/me

Lists every school the caller belongs to:
`{ schools: [{ member, school }] }`. The portal stores the picked
membership client-side (`renance.school.v1`).

### GET /school/profile?schoolId=

Returns `{ school }` with name, type, address and logo URL.

### PUT /school/profile  (MANAGEMENT)

Body `{ name?, address?, logoUrl?, clearLogo? }`. The logo is a small
data URL or an https URL; it stamps report cards, the portal chrome
and the ID card sheet.

## Curriculum and classes

### POST /school/seed-curriculum

MANAGEMENT. Installs the NERDC class ladder (Primary 1 to SSS 3) and
the subject catalog with departments. Idempotent. Response:
`{ seededClasses, seededSubjects }`.

### GET /school/classes?schoolId=

`{ classes: [{ id, name, level, seq }] }`, level is `primary`,
`junior` or `senior`.

### GET /school/subjects?schoolId=

`{ subjects: [{ id, name, code, level, seq, department, isCore }] }`.
`department` is empty for junior/primary subjects and one of
`art | science | commercial` for the senior band. `isCore` marks the
subjects every SSS student offers.

### POST /school/subject  (MANAGEMENT)

Adds a custom subject: `{ name, code, level, department, isCore }`.

### PUT /school/subject  (MANAGEMENT)

Edits one: `{ id, name?, code?, department?, isCore? }`.

### POST /school/class-subject  (MANAGEMENT)

Wires a subject to a class: `{ classId, subjectId, remove? }`. The
pair list feeds the timetable picker, the syllabus desk and the
result sheets.

### GET /school/class-subjects?schoolId=

`{ pairs: [{ classId, className, subjectId, subjectName }] }`.

## People: students, teachers, assignments

### POST /school/students

Enrolls a student: `{ classId, fullName, admissionNo, sex, session }`.

### GET /school/students?schoolId=&classId=

Lists students, optionally scoped to a class.

### GET /school/student-detail?schoolId=&studentId=

Full enrollment record: DOB, guardian name and phone, address, photo
URL, status and the per-student subject offering.

### PUT /school/student

Updates any detail field of one student.

### GET /school/student-subjects?schoolId=&studentId=

The student's subject offering. Empty means "everything the class
does" (the primary and JSS default).

### PUT /school/student-subjects

Sets the offering: `{ studentId, subjectIds: [] }`. Once set, the
student's result sheet shows exactly these subjects.

### POST /school/teachers  (MANAGEMENT)

Creates a staff account: `{ fullName, email, password, staffCode }`.
The new member holds the teacher role and signs in like any user.

### GET /school/members?schoolId=

All staff with their usernames and emails.

### POST /school/assignments

Hands a class+subject to a member: `{ memberId, classId, subjectId,
remove? }`. Assignments bound what a teacher sees and may edit.

### GET /school/assignments?schoolId=&memberId=

Assignment list with class, subject and member names resolved.

## Syllabus, scheme of work and notes

### GET /school/syllabus?schoolId=&classId=&subjectId=

`{ terms: [{ id, term, session, schemeOfWork, topics }] }`. The
scheme of work is an array of `{ week, topic, objectives?, activities?
}`; topics carry their note text.

### PUT /school/topic

Edits one topic: `{ topicId, title, content, week }`.

### PUT /school/scheme

Replaces a syllabus's scheme of work: `{ syllabusId, scheme: [...rows]
}`.

### POST /school/bulk-notes

Pours many topics at once: `{ classId, subjectId, term, session,
overwrite, topics: [{ title, week, content, source }] }`. Long dashes
are normalized on the way in. Response: `{ written, received }`.

### POST /school/seed-schemes  (MANAGEMENT)

Drafts the NERDC-aligned weekly scheme into every class+subject+term
whose scheme is still empty for the session. Response: `{ filled }`.
Safe to re-run: filled schemes are never touched.

## Attendance

### GET /school/attendance?schoolId=&classId=&day=

The day's register: `{ entries: [{ studentId, status, note }] }`.
Status is `present | absent | late | excused`.

### POST /school/attendance

Saves a register: `{ classId, day, entries: [...] }`. Upsert-safe: the
roster and the classroom kiosk can both write.

### GET /school/attendance-summary?schoolId=&classId=&from=&to=

Per-student roll-up over a date range: present, absent, late,
excused, total and rate.

## Results

### PUT /school/result-item

Fills one score cell: `{ studentId, classId, subjectId, term, session,
ca1, ca2, exam }`. The server computes total, grade and remark;
teachers may only write subjects assigned to them.

### GET /school/results?schoolId=&classId=&term=&session=

The class grid: one result per student with their subject items.

### POST /school/finalize  (MANAGEMENT)

Seals the term: positions, class averages and teacher/principal
remarks are computed, and each student gets a 6-digit result PIN.
Response: `{ finalized }`.

### GET /school/result-sheet?schoolId=&studentId=&term=&session=

One report card with the school name and logo stamped.

### GET /school/check-result?pin=&term=&session=

PUBLIC. The PIN checker parents use: returns the finalized report
card for a PIN, term and session.

## Fees

### GET /school/fees?schoolId=&term=&session=

Priced charges for a term: `{ fees: [{ id, classId, className, title,
description, amountKobo, term, session, seq }] }`. `classId` empty
means the charge applies to every class.

### PUT /school/fee  (MANAGEMENT)

Prices or re-prices a charge: `{ classId, title, description,
amountNaira, term, session, seq? }`. Amounts arrive as naira strings
and are stored as integer kobo.

### DELETE /school/fee  (MANAGEMENT)

Removes a charge with no receipts. A fee that already has payments
answers 409 and stays on the ledger.

### POST /school/fee-payment  (MANAGEMENT)

Records one receipt: `{ feeId, studentId, amountNaira, method,
reference?, paidOn? }`. Method is `cash | transfer | pos | other`.

### GET /school/fee-payments?schoolId=&studentId=&term=&session=

A student's receipts for the term, newest first.

### GET /school/fee-balances?schoolId=&classId=&term=&session=  (MANAGEMENT)

The money position of every active student: charged, paid and
outstanding, with the last payment date. Scope by class with
`classId`.

## ID cards

### POST /school/id-card  (MANAGEMENT)

Issues (or re-issues) one card: `{ studentId, session }`. Idempotent
per student per session; the serial is `REN-<year>-<6 digits>` and
school-unique.

### POST /school/id-cards  (MANAGEMENT)

Batch issue: every active student in scope (`classId` optional) who
lacks a card gets one. Response: `{ issued }`.

### GET /school/id-cards?schoolId=&classId=&session=

The card sheet join: card plus student, class, photo, guardian phone
and school identity, ready to print.

### PUT /school/id-card  (MANAGEMENT)

Flips status: `{ cardId, status: issued | revoked }`. Lost cards are
revoked, never deleted, so the serial history survives.
