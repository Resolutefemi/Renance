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
