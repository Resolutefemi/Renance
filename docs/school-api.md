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
