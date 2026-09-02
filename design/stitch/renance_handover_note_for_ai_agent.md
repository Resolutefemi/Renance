# Renance Design Handover & Continuity Brief

**Project:** Renance — Student Learning OS
**Last Updated:** 2024-09-02
**Design System:** {{DATA:DESIGN_SYSTEM:DESIGN_SYSTEM_1}}

## 1. Project Context
Renance is an offline-first learning OS for students (JAMB, WAEC, University). The design is centered on high-fidelity, high-performance CBT (Computer Based Testing) experiences combined with a gamified growth layer (streaks, XP, badges).

## 2. Brand & Visual Language
*   **Colors:** 
    *   Background (Light): `#F9F9FF` (never pure white)
    *   Ink (Primary Text): `#111C2D`
    *   Accent Colors: Amber (`#F59E0B`) for streaks/XP, Emerald (`#10B981`) for success/mastery, Violet (`#8B5CF6`) for AI/Tutor features.
*   **Typography:** Inter (Display w700, Body w400/w600).
*   **Corner Radius:** 12px for cards, 10px for primary buttons.
*   **Loading Pattern:** The **RenanceMark** — a pulsing logomark with three orbiting arcs. No circular spinners.

## 3. Theme Architecture (Crucial)
The user has established a 3-tier theme system that must be maintained:
1.  **Light Mode:** Full `#F9F9FF` background.
2.  **Mixed Mode (Dark + Light):** Dark primary containers/headers (`#111C2D`) with light content bodies.
3.  **Full Dark Mode:** Entire page uses the `#111C2D` background.

## 4. Completed Screens Checklist
*   **Onboarding & Entry:** Splash, Onboarding Carousel, Target Selection.
*   **Dashboards:** Home Launcher (JAMB & University variants), Practice Library.
*   **Learning Loop:** Practice Mode Setup, Exam Mode Setup, JAMB Subject Selection, Exam Player.
*   **Analytics:** Score Reports, Progress Dashboards.
*   **System:** Profile, Settings (needs update for 3-tier theme), Downloads.

## 5. Outstanding Roadmap Items (Prioritize Next)
*   **Socratic AI Tutor:** Violet-accented chat interface for "Why is this wrong?" logic.
*   **Syllabus Map:** Comprehensive topic tree with mastery bars and confidence dots.
*   **Gamification Hub:** Badge grid, level tracking, and "Streak Repair" flows.
*   **Arena:** 1v1 match-making and live quiz match screens.
*   **Settings Update:** Add the specific 3-option theme toggle (Light, Dark, Mixed).

## 6. Design Constraints for AI Agent
*   **Fidelity:** Stick to the 12px card/10px button rhythm established in `{{DATA:DESIGN_SYSTEM:DESIGN_SYSTEM_1}}`.
*   **Personalization:** The "Home" screen should adapt based on the selected target (JAMB vs. University).
*   **Navigation:** No hamburger menu. The Home Dashboard *is* the launcher. Access more features via the "More" bottom sheet.
