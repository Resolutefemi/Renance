# Stitch export — mapping & gap analysis

Imported: 2026-09-02, from `stitch_renance_stitch_design_system.zip` (48 screen folders,
each = `code.html` + `screen.png`). Source brief: [`DESIGN-BRIEF.md`](../DESIGN-BRIEF.md)
(screen numbers `§x.y` below refer to it).

## Design decision record — 3-tier theme system (founder, via Stitch)

The export establishes a **3-tier theme architecture** that supersedes the brief's
light-only §2. Adopt as official:

1. **Light** — full `#F9F9FF` background (already in `theme.dart`).
2. **Mixed** — dark `#131B2E` containers/headers over light bodies (exam player does this).
3. **Full dark** — `#111C2D` page background throughout.

Consequences: `theme.dart` gains `buildRenanceDarkTheme()` + a mixed scheme; Settings
gains the 3-option theme toggle (handover note §5). Dark-tier near-miss colors found in
the HTML are normalized on implementation:

| Stitch used | Normalizes to | Or adopt as dark-tier token |
| --- | --- | --- |
| `#1A243A` | `#131B2E` | — |
| `#D8E3FB` | `#D0E1FB` | — |
| `#C6C6C6` | `#C6C6CD` | — |
| `#23005C` | — | `violetDeep` (dark-tier violet container) |
| `#1B1B1B` / `#A2AAB8` | — | `darkBg` / `darkMuted` (if full-dark tier keeps them) |

## Folder → brief mapping (designed ✓)

| Brief | Folders | Status |
| --- | --- | --- |
| 5.1 Splash | splash_screen_light/dark | ✓ |
| 5.2 Onboarding | onboarding_light/dark | ✓ |
| 5.3 Target selection | exam_target_light/dark | ✓ |
| 5.4 Home JAMB | home_dashboard_jamb_light/dark | ✓ (+weak-topic recap card — good addition) |
| 5.5 Home University | university_home_dashboard_light/dark | ✓ |
| 5.7 Search | search_light/full_dark | ✓ |
| 6.1 Pack library | practice_library_light/dark/full_dark | ✓ |
| 6.3 Exam player | exam_player_light/dark/full_dark | ✓ (mixed-mode: dark card on light chrome) |
| 6.6 Results | score_report_light/dark | ✓ |
| 6.7 Answer review | answer_review_light/full_dark | ✓ |
| 6.8 Progress | progress_dashboard_light/dark/full_dark | ✓ |
| 7.1 Gamification hub | gamification_hub_light/full_dark | ✓ (Session A build-ready) |
| 7.5 Syllabus map | syllabus_map_light/full_dark | ✓ |
| 7.6 AI tutor | ai_tutor_light/full_dark | ✓ (Class B — waiting on key) |
| 8.1 Arena lobby | arena_lobby_light/full_dark | ✓ |
| 8.3 Offline share | offline_share_light/full_dark | ✓ |
| 8.6 Patron portal | patron_portal_light/full_dark | ✓ |
| 9.1 Profile | profile_light/dark/full_dark | ✓ |
| 9.2 Settings | settings_light/full_dark | ✓ (add 3-option theme toggle) |
| 9.3 Downloads | downloads_light/full_dark | ✓ |
| 9.4 Notifications | notifications_light/full_dark | ✓ |
| — (new) | practice_mode_setup_light, exam_mode_setup_light | pre-practice config screens |
| — (new) | jamb_subject_selection_light/dark | JAMB subject picker flow step |
| — (new) | home_dashboard_mixed_mode | mixed-tier home demo |
| — (assets) | renancemark_logo/, renance_learning_os/DESIGN.md, headshot | brand assets |

## Gap — not yet designed (13 of 35; next Stitch round)

| Brief | Screen | Priority |
| --- | --- | --- |
| 5.8 | "More" feature sheet (hamburger replacement) | **high** — nav depends on it |
| 6.2 | Pack detail | **high** — core loop |
| 6.4 | Question navigator (flagged/review grid) | **high** — exam craft |
| 6.5 | Fatigue nudge overlay | medium |
| 7.2 | Badge detail | medium |
| 7.3 | Spaced repetition "Review due today" | **high** — Session B |
| 7.4 | Voice flashcards player | medium |
| 7.7 | AI question generator | low (Class B) |
| 7.8 | Study plan (fatigue-aware) | medium |
| 8.2 | Arena live match | low (Class C) |
| 8.4 | Certificate wallet | low (Class C) |
| 8.5 | Career bridge | low |
| 9.5 | Global state kit (empty/error/loading) | **high** — implement first in Flutter |

Coverage: **22/35 brief screens designed** (63%) + 4 bonus screens. The full core
learning loop (library → player → results → review → progress) and the entire
Session-A gamification surface are design-complete.
