# Stitch export — mapping & coverage

Source brief: [`DESIGN-BRIEF.md`](../DESIGN-BRIEF.md) (screen numbers `§x.y` below).
Two Stitch import rounds (2026-09-02) plus one agent-built pair. Every screen folder =
`code.html` (source of truth) + `screen.png` (preview). Long pages also carry
`screen_full.png` (full-page capture).

## Design decision record — 3-tier theme system (founder, via Stitch)

The export establishes a **3-tier theme architecture** that supersedes the brief's
light-only §2. Adopt as official:

1. **Light** — full `#F9F9FF` background (already in `theme.dart`).
2. **Mixed** — dark `#131B2E` containers/headers over light bodies (exam player does this).
3. **Full dark** — `#111C2D` page background throughout.

Consequences: `theme.dart` gains `buildRenanceDarkTheme()` + a mixed scheme; Settings
gains the 3-option theme toggle (handover note §5). Dark-tier near-miss colors found in
round-1 HTML are normalized on implementation:

| Stitch used | Normalizes to | Or adopt as dark-tier token |
| --- | --- | --- |
| `#1A243A` | `#131B2E` | — |
| `#D8E3FB` | `#D0E1FB` | — |
| `#C6C6C6` | `#C6C6CD` | — |
| `#23005C` | — | `violetDeep` (dark-tier violet container) |
| `#1B1B1B` / `#A2AAB8` | — | `darkBg` / `darkMuted` (if full-dark tier keeps them) |

## Coverage — 35/35 brief screens designed

### Round 1 (48 folders; light + mixed + full-dark tiers)

| Brief | Folders |
| --- | --- |
| 5.1 Splash | splash_screen_light/dark |
| 5.2 Onboarding | onboarding_light/dark |
| 5.3 Target selection | exam_target_light/dark |
| 5.4 Home JAMB | home_dashboard_jamb_light/dark (+full_dark; +weak-topic recap card — good addition) |
| 5.5 Home University | university_home_dashboard_light/dark; home_dashboard_mixed_mode |
| 5.7 Search | search_light/full_dark |
| 6.1 Pack library | practice_library_light/dark/full_dark |
| 6.3 Exam player | exam_player_light/dark/full_dark (mixed: dark card on light chrome) |
| 6.6 Results | score_report_light/dark |
| 6.7 Answer review | answer_review_light/full_dark |
| 6.8 Progress | progress_dashboard_light/dark/full_dark |
| 7.1 Gamification hub | gamification_hub_light/full_dark (Session A build-ready) |
| 7.5 Syllabus map | syllabus_map_light/full_dark |
| 7.6 AI tutor | ai_tutor_light/full_dark (Class B — waiting on key) |
| 8.1 Arena lobby | arena_lobby_light/full_dark |
| 8.3 Offline share | offline_share_light/full_dark |
| 8.6 Patron portal | patron_portal_light/full_dark |
| 9.1 Profile | profile_light/dark/full_dark |
| 9.2 Settings | settings_light/full_dark (add 3-option theme toggle) |
| 9.3 Downloads | downloads_light/full_dark |
| 9.4 Notifications | notifications_light/full_dark |
| — (new) | practice_mode_setup_light, exam_mode_setup_light, jamb_subject_selection_light/dark |
| — (assets) | renancemark_logo/, renance_learning_os/DESIGN.md, headshot |

### Round 2 (12 missing screens + 1 bonus; light tier, re-rendered by agent)

| Brief | Folders |
| --- | --- |
| 5.8 More sheet | more_features_sheet_light |
| 6.2 Pack detail | pack_detail_light |
| 6.4 Question navigator | question_navigator_light (**patched** — see repairs) |
| 6.5 Fatigue nudge | fatigue_nudge_light |
| 7.2 Badge detail | badge_detail_light |
| 7.3 Review queue | review_queue_light |
| 7.4 Voice flashcards | voice_flashcards_light |
| 7.7 AI question generator | ai_question_generator_light |
| 7.8 Study plan | study_plan_light |
| 8.4 Certificate wallet | certificate_wallet_light |
| 8.5 Career bridge | career_bridge_light |
| 9.5 Global state kit | global_state_kit_light |
| — (bonus, §7.1 streak repair) | results_recovery_light |

### Agent-built (same Tailwind config as the export)

| Brief | Folders | Note |
| --- | --- | --- |
| 8.2 Arena live match | arena_match_light, arena_match_full_dark | Built to close the last gap; founder may regenerate in Stitch if a different take is wanted |

## Repairs applied to round-2 export

- Stitch's PNG captures were inconsistent (widths 429–706px) and **broken for
  fixed-element screens** (`more_features_sheet`, `question_navigator` exported as
  mostly-void images). All 13 screens re-rendered from their `code.html` at uniform
  **693×1500 (9:16)** via `scripts/render_stitch.py` (Playwright, 390×844 CSS viewport).
- `question_navigator_light/code.html` also had a real CSS bug: the sheet wrapper used
  `h-full` inside a `min-h`-only parent → collapsed to 0 height → the sheet rendered
  above the viewport. Patched: wrapper → `absolute inset-0`; template tab bar removed
  (in-exam screens carry no tab nav). Patch script: `scripts/patch_navigator.py`.

## Tier debt (optional follow-up)

Round 2 screens exist in **light tier only**. If wanted, generate dark/mixed variants
for: more sheet, pack detail, navigator, fatigue nudge, badge detail, review queue,
voice flashcards, AI generator, study plan, certificates, career bridge, state kit.
