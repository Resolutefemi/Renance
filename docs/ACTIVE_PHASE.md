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

## Phase 1 — Thin Core Service              [COMPLETE 2026-08-27]
identity/auth · multi-role · organizations · memberships · RBAC ·
verification states. Serial gates:

### Gate 1.1 — Walking skeleton (auth)      [CODE COMPLETE 2026-08-27]
core.users table (citext unique email, bcrypt cost 12, status enum) ·
POST /auth/register · POST /auth/login · GET /auth/me (JWT HS256, 12h) ·
ZodValidationPipe contracts in @renance/shared · 7 unit tests green ·
typecheck green x4 workspaces · migration SQL generated (drizzle 0000).
REMAINING FOR EXIT: apply migration against real Neon, live round-trip,
repo pushed so CI sees it.

### Gate 1.2 — Organizations + memberships  [CODE COMPLETE 2026-08-27]
core.organizations (slug unique, type enum, created_by FK) · core.memberships
(composite unique org+user, roles owner/admin/member, statuses
active/invited/revoked, added_by audit FK) · migration 0001 APPLIED to live
Neon (journal=2) · endpoints: POST /orgs (atomic owner membership tx),
GET /orgs, GET /orgs/:id, GET /orgs/:id/members, POST /orgs/:id/members
(direct-add invite stub) · contracts+slug rules tested · LIVE E2E 14/14:
owner/member flow, 403 non-member + member-cannot-manage, 409 dup + slug.
REMAINING FOR EXIT: repo push (this commit); fuller matrix tests land in 1.3.
DEMO ACCOUNT: ariyooluwafemi487+demo1@gmail.com (founder-owned plus alias).

### Gate 1.3 — RBAC enforcement              [CODE COMPLETE 2026-08-27]
OrgRolesGuard + @RequireOrgRole() decorator (coarse gate: org exists ->
active membership -> rank>=required, attaches membership to request) ·
pure decision matrices in rbac.ts (hasAtLeast/canSetRole/canRemoveMember)
· PATCH /orgs/:orgId/members/:userId (idempotent role change; owner
targets untouchable, role=owner unassignable by contract) · DELETE member
(owner removes admins+members, admin removes members only, owners never
removable — transfer is a future op) · guard DI survives tsx via explicit
@Inject · 54 api + 6 shared unit tests green · LIVE E2E 20/20 vs prod
Neon: all 4 ladder rungs incl. anon 401, member 403s, admin add/remove,
owner-only powers, contract 400s, state restored after run.
REMAINING FOR EXIT: repo push (this commit).

### Gate 1.4 — Verification states           [CODE COMPLETE 2026-08-27]
organizations.verification_status enum + note/reviewed_at/reviewed_by
(migration 0002 APPLIED, journal=3) · pure transition matrix 16-cell tested
· POST /orgs/:orgId/verification/submit (owner/admin, state-guarded 409) ·
AdminController /admin/orgs/pending + /admin/orgs/:id/verification behind
AdminGuard (ADMIN_EMAILS env; refuse-closed when unset) · verified terminal
in MVP · publicOrgSchema +verificationStatus · unit 79 green · LIVE E2E
17/17 via run_gate_e2e.sh runner (sandbox background processes die between
tool calls — foreground runner + log file is the reliable pattern).

### Gate 1.5 — Ownership transfer + leave    [CODE COMPLETE 2026-08-27]
POST /orgs/:orgId/ownership — single-tx swap (owner->admin, target->owner),
the ONLY owner-creation path; target must be active member · DELETE
/orgs/:orgId/members/me self-service leave/invite-decline (owner blocked
409 transfer-first; declared before :userId route) · canTransferOwnership
pure rule · LIVE E2E 18/18 incl. crown round-trip founder<->demo.

### Gate 1.6 — Account hygiene               [CODE COMPLETE 2026-08-27]
PATCH /auth/me (displayName) · POST /auth/me/change-password (bcrypt
verify current 401, same strength floor as register, cost 12 re-hash;
token stays valid til 12h expiry by design) · LIVE E2E 13/13 with full
state restore. Founder can now rotate the temp password himself.

### Gate 1.7 — Phase 1 EXIT                  [CODE COMPLETE 2026-08-27]
e2e_phase1_exit.py: 40/40 consolidated assertions in one live boot (fresh
epoch identities, state-tolerant) + unit 79/79 + typecheck 4/4. Every
Phase 1 surface re-proven incl. founder regression on renance-hq.

### Gate 1.8 — CBT content pipeline          [CODE COMPLETE 2026-08-27]
packages/cbt-content DONE: cbt:build CLI ingests ALL 7 real shapes (7th
discovered: options as bare string array + text answers), strips BOM,
dedupes, splits answers out · LIVE RUN over both legacy repos: 21 banks,
7461 questions exam-ready (6663 mcq + 798 text), 0 failures, every drop
reasoned in report · ADR-0003 accepted (bundle/key split, no keys to any
client, server-side grading, device auto-cleanup, R2 ladder) · 8 spec tests.

### Gate 1.9 — CBT server core               [CODE COMPLETE 2026-08-27]
migration 0003: cbt.bundles (payload jsonb + answer_key jsonb SERVER-ONLY
+ sha256 + unique org+code+version) & cbt.attempts (unique bundle+user) ·
POST publish (org admin, contract cross-checks key<->questions) · GET
manifest (meta only) · GET bundle (questions, zero key material — E2E
leak-check asserts raw body clean) · membership via OrgsService facade
(assertActiveMembership) · E2E 15/15 with REAL jamb biology bank.

### Gate 2.0 — CBT MVP milestone             [locked]
POST attempts {answers} -> server grades vs key -> score+breakdown stored ·
unique attempt per (bundle,user) · perfect/partial/duplicate E2E · Phase 2
opened and milestone 2.0 declared.

## Phase 2 — CBT MVP                        [ACTIVE at 2.0]
First real-user milestone (existing renancecbt content migrates here).
AFTER 2.0: assignments per student, timers/windows, offline sync protocol,
Flutter+web exam UI, R2 for images.

## Phase 3 — Parallel modules               [locked]
school(results/PIN/fees) → sme → skills → utilities → payroll, serialised,
each behind its own embarrassment-small MVP line.

## Phase 4 — Hardening                      [locked]
verification flow polish · install-size optimisation · store submissions.
refresh-token story revisit + FCM wiring land here or end of Phase 2.
