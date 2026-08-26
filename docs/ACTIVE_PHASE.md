# ACTIVE PHASE — single source of progress

Update this file at the END of every coding session. Completion gates, not
dates. Rule: do not open the next gate until this one's exit criteria pass.

## Phase 0 — Foundations                    [DRAINING]
Exit criteria:
- [x] repo pushed to GitHub (github.com/Resolutefemi/Renance, private) — CI runs on first PR/push pair
- [x] Neon project provisioned via agent API: id orange-fog-53847933, ep-snowy-base-axf83q3b; bootstrap + migration 0000 APPLIED, journal current
- [x] apps/api health endpoint responds locally             <- verified in paired sandbox 2026-08-27
- [ ] apps/web renders home page locally                    <- code present; your boot pending
- [ ] mobile: flutter create done (empty shell acceptable)

## Phase 1 — Thin Core Service              [ACTIVE]
identity/auth · multi-role · organizations · memberships · RBAC ·
verification states. Serial gates:

### Gate 1.1 — Walking skeleton (auth)      [CODE COMPLETE 2026-08-27]
core.users table (citext unique email, bcrypt cost 12, status enum) ·
POST /auth/register · POST /auth/login · GET /auth/me (JWT HS256, 12h) ·
ZodValidationPipe contracts in @renance/shared · 7 unit tests green ·
typecheck green x4 workspaces · migration SQL generated (drizzle 0000).
REMAINING FOR EXIT: apply migration against real Neon, live round-trip,
repo pushed so CI sees it.

### Gate 1.2 — Organizations + memberships  [next]
orgs table + members join (roles: owner/admin/member) · create-org endpoint ·
invite-by-email stub · tests. Scope guard: NO billing, NO custom role UI.

### Gate 1.3 — RBAC enforcement              [locked]
RolesGuard + decorator pair · protect a stub resource route · matrix tests
(owner>admin>member>anon).

### Gate 1.4 — Verification states           [locked]
draft/pending/verified/rejected state machine doc + service + transition
guards · admin review endpoints · full Phase 1 exit test suite.

## Phase 2 — CBT MVP                        [locked]
First real-user milestone (existing renancecbt users migrate here).
Gate list comes from roadmap §Phase 2.

## Phase 3 — Parallel modules               [locked]
school(results/PIN/fees) → sme → skills → utilities → payroll, serialised,
each behind its own embarrassment-small MVP line.

## Phase 4 — Hardening                      [locked]
verification flow polish · install-size optimisation · store submissions.
refresh-token story revisit + FCM wiring land here or end of Phase 2.
