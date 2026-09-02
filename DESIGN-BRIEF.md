# Renance — Stitch Design Brief (Mobile)

**Companion to:** `ROADMAP.md` · **Scope:** every student-facing screen of the Flutter app
**Excluded on purpose:** Login / Sign-up / Google sign-in — those are already designed and shipped.
**Last updated:** 2026-09-02

---

## How to use this document with Stitch (stitch.withgoogle.com)

1. **Work screen by screen.** Stitch behaves best when each prompt describes exactly one screen. Do not paste the whole document at once — generate screens in the order given (Core shell → Learning loop → Growth → Social → System), because later screens reuse components established by earlier ones.
2. **Always open with the brand frame.** Start every prompt with: *"Mobile app screen for Renance, a student learning OS. 9:16 phone frame, light theme, Material 3."* Then paste that screen's **Paste into Stitch** block.
3. **Pin the design language once per session.** Before your first screen in a new Stitch session, paste the "Design language" section (§2) so colors, type, and the RenanceMark loader carry through every generation.
4. **Iterate, don't restart.** When a generation is 80% right, reply with *"Keep everything, only change X"* instead of re-prompting from scratch. Stitch preserves layout across edit turns far better than fresh prompts.
5. **Export on approval.** Export each approved screen (Figma or HTML) and file it under the screen number used here, so designs map 1:1 to the implementation tickets in ROADMAP.md.

---

## 1. The Name — Renance

> **[FOUNDER — WRITE YOUR STORY HERE]** *You chose to author the name's origin yourself. Replace this block with the real story before pasting §1 into Stitch. Until then, the fallback paragraph below is safe to use.*

**Fallback positioning (used until you replace the above):**

Renance is the learning OS for every student. One app that carries a student from "what am I preparing for?" to "I walked into that exam hall ready" — practice packs, spaced review, syllabus tracking, an AI tutor, and the motivation layer (streaks, XP, badges) that keeps them coming back daily. It is offline-first, because data shouldn't decide who gets to prepare properly. The name reads like *renaissance* stripped to its stem: a fresh start for how students in Nigeria and everywhere else prepare — personal, adaptive, and honest about what they know and don't.

**Tagline options (pick one, keep it everywhere):**
- **Learn. Practice. Rise.**
- **The learning OS for every student.**
- **Prepare like it matters.**

---

## 2. Design language (LOCKED — matches the shipped app)

These are not suggestions. They are lifted verbatim from the founder's approved mockups and already implemented in `apps/mobile/lib/ui/theme.dart`. Stitch must reproduce them exactly.

### 2.1 Color tokens

| Token | Hex | Use |
| --- | --- | --- |
| Background | `#F9F9FF` | Every screen background (blue-tinted white, never pure white) |
| Surface container | `#E7EEFF` | Section fills, inset panels |
| Surface container low | `#F0F3FF` | Input fields, subtle chips |
| Surface container high | `#DEE8FF` | Hover/pressed fills, highlighted rows |
| Card | `#FFFFFF` | All cards, 12px radius, faint shadow `#141C2D34` |
| Ink (text primary) | `#111C2D` | Headings, body, icons |
| Text secondary | `#45464D` | Supporting copy, captions |
| Primary action | `#000000` | Primary buttons (black fill, white label) |
| Primary container | `#131B2E` | Dark panels, player header zones |
| Secondary container | `#D0E1FB` | Selected chips, active states |
| Outline | `#76777D` / `#C6C6CD` | Dividers, inactive borders |
| Error | `#BA1A1A` on `#FFDAD6` | Errors, destructive actions |
| **Violet accent** | `#8B5CF6` | AI features (tutor, generator) |
| **Emerald accent** | `#10B981` | Success, streaks alive, correct answers |
| **Amber accent** | `#F59E0B` | Streak flame, warnings, XP |

### 2.2 Typography — Inter

- **Display / page titles:** Inter 24–28px, w700, ink.
- **Section titles / card titles:** Inter 18px, w600, ink.
- **Body:** Inter 15px, w400, ink; secondary copy in `#45464D`.
- **Captions / meta:** Inter 12–13px, w400–500.
- **Numbers (scores, XP, streaks):** Inter w700, prefer emerald/amber/violet accents.

### 2.3 Shape, elevation, components

- Cards: white, **12px radius**, elevation 1, no tint.
- Buttons: primary = black fill, white label, **52px tall, 10px radius**, w600; secondary = outlined, `#C6C6CD` border, ink label.
- Inputs: filled `#F0F3FF`, **10px radius**, no border until focus (ink 1.4px) / error (`#BA1A1A` 1.2px).
- Chips: pill (20px radius), `#F0F3FF` idle, `#D0E1FB` selected.
- Snackbars: floating, ink `#111C2D` background, white text.
- Icons: rounded-outline style, ~2px stroke, ink; **filled variant only when the item is active**.

### 2.4 The RenanceMark — the ONLY loader (founder rule)

There is **no circular spinner anywhere in Renance**. Every loading, syncing, grading, or processing state is expressed by the **RenanceMark**: the brand logomark drawn as a custom vector that gently pulses (scale breathing, ~3–6% amplitude) while three thin orbit arcs chase each other around it with phase-shifted opacity — a Bybit-style brand transition, 1.8s loop, centered on a `#F9F9FF` veil. During active work (grading, downloading) the amplitude increases so it "tries harder". When generating Stitch screens, say: *"loading state shown as a pulsing brand logomark with three thin orbiting arcs — never a circular spinner."*

### 2.5 Motion & feel

- Micro-interactions 150–250ms, ease-out; page transitions subtle fades/slides.
- Correct/incorrect answer feedback: quick spring + emerald/red tint flash — instant, never blocking.
- Streak flame and XP counters count up with a short tick animation.

---

## 3. Navigation model — the Launcher Home (no hamburger)

**Founder decision, binding for every screen:** Renance does **not** use a full-screen hamburger drawer as its primary navigation. The home page **is** the menu: a grid of feature icons arranged like the app grid on a phone's home screen — familiar, thumb-reachable, and it puts all 19 features one tap away without hiding the product behind a burger menu.

1. **Top bar (compact, every screen):** left — screen title or "Renance" wordmark on Home; right — streak flame (amber), notification bell, avatar chip (opens Profile). No hamburger icon.
2. **Home = launcher grid (4 columns):** white rounded icon tiles with labels, grouped under three row-headings — *Practice*, *Grow*, *More*. Primary tiles: Exams, Review due, Progress, Syllabus, Tutor (violet), Badges, Flashcards, Arena. The last tile is **More (···)** which opens a bottom sheet grid with the long tail (Downloads, Offline share, Certificates, Career, Patron portal, Settings, AI generator…). That sheet is the hamburger's replacement — lighter, faster, and it keeps the home page as a real dashboard.
3. **Bottom navigation (5 tabs, white bar, 12px top radius):** **Home · Practice · Review · Progress · Profile.** Active tab = ink icon filled + small dot; inactive = outline `#76777D`. Review shows an emerald count badge when cards are due.
4. **Personalization — "one home, many faces":** the entire interface adapts to what the student is preparing for (chosen at onboarding, changeable in Profile). A JAMB student sees a UTME countdown hero, subject tiles and JAMB packs; a university student sees course codes (COS101…), semester progress and lecture-style bundles; a WAEC student sees WASSCE subjects. Same skeleton, different content, different copy. §5.4–5.6 spec the variants explicitly.

---

## 4. Global rules for every screen

- **Loading = RenanceMark**, always (§2.4). Never a spinner, never a skeleton that outlives 2s without the mark appearing.
- **Empty states:** soft blue-tinted illustration (flat, `#E7EEFF`/`#DEE8FF` shapes), one-line explanation, one black action button. Friendly, never apologetic.
- **Error states:** white card, error icon, human sentence ("Couldn't reach the exam server"), retry outlined button; banner variant uses `#FFDAD6`.
- **Offline:** slim amber banner under the top bar ("Offline — answers will sync when you reconnect"). Product must remain fully usable; sync happens silently in the background.
- **Safe areas:** respect notch/home-indicator insets; bottom nav floats above the home indicator with 12px padding.
- **Microcopy:** buttons start with verbs ("Start practice", "Review 12 cards"); scores and dates use Nigerian conventions (₦, UTC+1, "UTME 2027 · 142 days").
- **Numbers everywhere:** streaks, XP and countdowns are the emotional core — render them big, w700, accent-colored.

---

## 5. Screen specs — A. Core shell

> Format per screen: **Purpose → Layout zones → Components → States → Edge cases → Paste into Stitch.** All states obey §4 (RenanceMark loader, empty/error patterns).

### 5.1 Splash & global loading veil
**Purpose:** first three seconds of the brand; doubles as the universal loading veil.
**Layout:** full-bleed `#F9F9FF`; RenanceMark at 44px dead-center; wordmark "Renance" in Inter w700 20px ink 24px below; bottom-center caption "Learn. Practice. Rise." 12px `#45464D`. No status-bar clutter.
**Components:** RenanceMark (busy amplitude), wordmark, tagline.
**States:** cold start shows mark pulsing until the session resolves; signed-in → Home; signed-out → Login (existing screen); first-run → Onboarding.
**Edge cases:** no network at cold start is NOT an error here — offline users proceed straight into cached content; the mark simply keeps orbiting if a background sync retries.
**Paste into Stitch:** *Splash screen, blue-tinted white background #F9F9FF, centered small brand logomark pulsing with three thin orbiting arcs (never a spinner), wordmark "Renance" beneath, tiny tagline "Learn. Practice. Rise." at the bottom. Minimal, premium, calm.*

### 5.2 Onboarding carousel (3 slides)
**Purpose:** sell the promise before asking anything.
**Layout:** full-screen swipeable pages; centered flat illustration (blue-tinted `#E7EEFF`/`#DEE8FF` shapes, no photos); title Inter w700 24px; body 15px `#45464D` max 3 lines; page dots; bottom "Continue" black button + "Skip" text button.
**Slides:** ① *Your exam, your plan* — pick what you're preparing for and the whole app reshapes around it. ② *Practice that remembers* — every wrong answer becomes a review card, resurfaced at the right moment. ③ *Proof of the grind* — streaks, XP and badges that make consistency visible.
**States:** dots reflect position; back-swipe allowed.
**Edge cases:** returning users who force-close mid-onboarding land back on the slide they left.
**Paste into Stitch:** *Three-slide onboarding carousel for a student learning OS: flat blue-tinted illustrations, short headline + two-line body, page dots, black Continue button, Skip link. Calm, premium, no photos.*

### 5.3 Exam-target selection — "What are you preparing for?"
**Purpose:** the single most important data point in the product — it personalizes everything (ROADMAP #5 adaptive UI).
**Layout:** top bar "Setup 1 of 2"; title "What are you preparing for?"; vertical list of selectable white cards, 12px radius, each with a rounded outline icon, name, one-line description: **JAMB UTME** ("Nigeria's university entrance exam"), **WAEC/WASSCE** ("Senior secondary certificate"), **NECO**, **Post-UTME**, **University course** ("COS101, MTH102 and your coursemates"), **Just practicing**. Selected card gets `#D0E1FB` fill + ink 1.4px border. Bottom black button "Continue" (disabled until pick).
**States:** loading targets = RenanceMark; selection persists instantly.
**Edge cases:** multi-prep students (JAMB + WAEC) — allow one primary target now; a "Add another later" text link under the list keeps the promise without complicating v1.
**Paste into Stitch:** *Setup screen, title 'What are you preparing for?', vertical list of white selectable cards with rounded icons — JAMB UTME, WAEC/WASSCE, NECO, Post-UTME, University course, Just practicing — each with a one-line caption. Selected card tinted #D0E1FB with dark border. Black Continue button pinned at bottom.*

### 5.4 Home launcher — JAMB variant (canonical home)
**Purpose:** the dashboard-as-menu; shows the whole product at a glance for the primary persona.
**Layout, top → bottom:** ① Compact top bar: "Renance" wordmark left; streak flame "12" (amber), bell, avatar right. ② **Hero card** (white, 12px): "UTME 2027 · 142 days" countdown in w700 28px ink, sub-line "Physics · 64% syllabus covered", emerald mini progress bar, black button "Continue practice". ③ Subject chips row (scrollable): English · Physics · Chemistry · Biology (selected = `#D0E1FB`). ④ **Launcher grid, 4 columns under heading "Practice":** Exams, Review due (emerald badge "12"), Flashcards, Syllabus. Under **"Grow":** Progress, Badges, Tutor (violet icon), Arena. Single **More (···)** tile under "More". ⑤ Bottom nav (5 tabs, Review tab badged).
**Components:** every tile = white rounded square (72px), rounded-outline ink icon, 12px label; tile press = subtle scale.
**States:** loading hero = RenanceMark in hero card only (grid renders cached instantly); empty grid state → §5.6; offline → amber banner under top bar, everything still tappable from cache.
**Edge cases:** countdown flips to exam week copy ("UTME is in 3 days — sleep well, review light"); after exam day the hero becomes a results recap card.
**Paste into Stitch:** *Home dashboard for a JAMB exam-prep student, no hamburger menu. Top bar with brand wordmark, amber streak flame count 12, bell, avatar. White hero card 'UTME 2027 · 142 days' with syllabus progress bar and black 'Continue practice' button. Below, a phone-home-screen style 4-column grid of white rounded feature icon tiles grouped 'Practice' (Exams, Review due with green badge 12, Flashcards, Syllabus) and 'Grow' (Progress, Badges, violet Tutor, Arena) plus a More tile. 5-tab bottom nav. Background #F9F9FF, ink #111C2D, Inter font.*

### 5.5 Home launcher — University variant (proof of personalization)
**Purpose:** demonstrate §3's "one home, many faces" — same skeleton, different student.
**Layout:** identical skeleton to 5.4 with swapped content: hero card becomes "COS101 · Introduction to Computing — Week 6 of 12" with semester progress and "Resume lecture notes"; chips row = course codes (COS101 · MTH102 · PHY101 · GST101); grid headings identical but tiles contextual — Exams→"Course quizzes", Syllabus→"Course outline"; hero secondary stat "CGPA tracker coming soon" is NOT shown (never ship placeholder stats).
**States/Edge cases:** same as 5.4; a student who switches target in Profile sees this home after one confirming dialog.
**Paste into Stitch:** *Same home dashboard skeleton but personalized for a university student: hero card 'COS101 · Introduction to Computing — Week 6 of 12' with semester progress and 'Resume lecture notes' button; course-code chips COS101, MTH102, PHY101, GST101; same 4-column feature icon grid and 5-tab bottom nav. Same tokens: #F9F9FF background, ink #111C2D, white cards 12px radius.*

### 5.6 Home launcher — first-run / empty state
**Purpose:** honest empty state before first download; sets expectation, offers the one action that matters.
**Layout:** top bar as usual; instead of hero + grid, a single centered composition: flat illustration of a grid of tiles with two lit; title "Your home fills up as you practice"; body one line "Download your first exam pack and this space becomes your command center."; black button "Browse exam packs"; text link "Import a pack with a code".
**States:** this state only appears with zero packs; after first download the full launcher renders.
**Edge cases:** if the student skipped target selection, this screen routes them back to 5.3 first (never show an un-personalized home).
**Paste into Stitch:** *Empty first-run home: centered flat blue-tinted illustration of app icon tiles, headline 'Your home fills up as you practice', one-line subtext, black 'Browse exam packs' button and a subtle text link 'Import a pack with a code'. Same top bar and bottom nav.*

### 5.7 Search
**Purpose:** one field that finds packs, topics, questions, badges.
**Layout:** top bar collapses into a focused search field (filled `#F0F3FF`, 10px radius, lens icon, "Search packs, topics, questions…"); below, when empty: "Recent" chips + "Trending for JAMB" list; results grouped with section headers — Packs / Topics / Questions / Badges — as white list rows (icon, title, meta line, chevron).
**States:** typing → results stream in with RenanceMark inline at list end; zero results → empty state "Nothing for 'q' yet — try 'photosynthesis'"; offline → cached packs only, banner explains.
**Edge cases:** question results deep-link straight into that question in review mode, not the pack.
**Paste into Stitch:** *Search screen with a focused filled search bar (#F0F3FF, 10px radius), recent-search chips, and grouped results list (Packs, Topics, Questions, Badges) as white rows with icons, titles, meta lines and chevrons. Ink on #F9F9FF, Inter.*

### 5.8 "More" feature sheet (the hamburger replacement)
**Purpose:** home for the long tail of features without a hamburger drawer.
**Layout:** modal bottom sheet, 12px top radius, drag handle; title "All features"; 4-column grid of the secondary tiles — Downloads, Offline share, Certificates, Career bridge, Patron portal, AI generator, Settings, Help — same tile anatomy as Home; sheet never covers more than 60% of screen.
**States:** tiles for features not yet shipped in the build render at 40% opacity with "Soon" chip — honest roadmap-in-UI, removed the day they ship.
**Edge cases:** sheet closes on outside tap or swipe-down; last position remembered per session.
**Paste into Stitch:** *Bottom sheet titled 'All features' with a 4-column grid of white rounded feature tiles (Downloads, Offline share, Certificates, Career bridge, Patron portal, AI generator, Settings, Help), some tiles at 40% opacity with a small 'Soon' chip. Drag handle, 12px top radius over dimmed home.*

---

## 6. Screen specs — B. Learning loop

### 6.1 Exam pack library (Practice tab)
**Purpose:** the shelf of everything practiceable, personalized to the target.
**Layout:** top bar "Practice" + filter icon; sticky chip row: All · Downloaded · In progress · Archived; **hero strip** "Daily quest" (amber-tinted card, quest text "Answer 20 questions today", progress "13/20", reward "+50 XP"); body = white pack cards in a 2-column grid: pack icon tile, title ("JAMB Biology 2024 Mock"), meta line ("120 questions · 45 min"), thin progress bar for started packs, download state icon (cloud / arrow / check).
**Components:** pack card 12px radius; filter chips per §2.3.
**States:** loading = RenanceMark centered over cached grid; empty (no packs) = §5.6-style illustration "No packs yet — pull down to refresh"; offline shows downloaded packs first with a "Show online packs" toggle.
**Edge cases:** long titles clamp to 2 lines; a pack mid-download shows a thin determinate bar — the RenanceMark only covers *unknown-duration* waits.
**Paste into Stitch:** *Practice library: sticky filter chips (All, Downloaded, In progress), an amber-tinted 'Daily quest' card with progress 13/20 and +50 XP, then a 2-column grid of white pack cards — icon tile, title 'JAMB Biology 2024 Mock', meta '120 questions · 45 min', thin progress bar, download icon. #F9F9FF background, Inter, 12px cards.*

### 6.2 Pack detail
**Purpose:** pre-flight briefing before committing time.
**Layout:** top bar back + bookmark; header block: pack icon, title, meta chips (topic count, question count, avg duration, difficulty pill); **black primary "Start practice"** + outlined "Download for offline"; body sections as white cards: "What's inside" (topic list with per-topic counts), "Your history" (last score ring drawn in emerald, attempts), "Syllabus coverage" (mini bar per topic, links to §7.5).
**States:** downloading replaces the outlined button with determinate progress; already-downloaded swaps to "Ready offline ✓" (emerald).
**Edge cases:** pack with 0 attempts hides history card entirely; error fetching details keeps cached header and shows retry inline.
**Paste into Stitch:** *Pack detail: header with icon, title, meta chips, black 'Start practice' button and outlined 'Download for offline'; below, white cards 'What's inside' (topic list), 'Your history' (emerald score ring, last attempts) and 'Syllabus coverage' (mini bars). Clean, calm, ink on #F9F9FF.*

### 6.3 Exam player — question
**Purpose:** the core loop; must feel faster than a native exam CBT with zero jitter.
**Layout:** **dark header zone** (`#131B2E`, full-width): back-x, question counter "Q 14/120", thin white progress bar, timer "00:41:12" w700 white; body: white card with question text Inter 17px w500 ink; options as full-width white rows (12px radius, `#C6C6CD` border, A/B/C/D letter tile) — selected = `#D0E1FB` fill + ink border; bottom action bar: outlined "Flag" (flag icon), outlined "Skip", black "Next".
**States:** loading next question = RenanceMark inline replacing the card (header stays put — never the whole screen); submitting all → grading veil (§5.1 full-screen mark with caption "Marking your paper…"); offline identical (grading happens locally, syncs later).
**Edge cases:** timer low (<2 min) turns amber, (<30s) red + haptic; app killed mid-exam resumes exactly at Q14 with a snackbar "Picked up where you left off"; image-based questions render with pinch-zoom.
**Paste into Stitch:** *CBT exam player: dark #131B2E header with question counter Q14/120, white progress bar and timer 00:41:12; white question card; four full-width option rows with A–D letter tiles, one selected in #D0E1FB; bottom bar with outlined Flag, outlined Skip and black Next. Focused, minimal, high contrast.*

### 6.4 Exam player — question navigator
**Purpose:** exam-craft screen: jump around, see the map of the paper.
**Layout:** opens as full-screen sheet over the dimmed player; grid of numbered squares (5 columns): answered = ink fill/white number, skipped = `#F0F3FF`, flagged = amber outline + flag pip, unseen = white; legend row; black "Resume" button; per-filter quick chips (All · Flagged · Unseen).
**States:** pure client state — instant; no loaders.
**Edge cases:** taps during grading are ignored; the square for the current question gets a 2px violet ring.
**Paste into Stitch:** *Question navigator sheet over a dimmed exam: 5-column grid of numbered squares — dark filled = answered, light = skipped, amber-outlined with flag pip = flagged, white = unseen; legend; filter chips; black Resume button.*

### 6.5 Fatigue nudge overlay (ROADMAP #6)
**Purpose:** protect the student from grinding into dead learning; gentle, never parental.
**Layout:** triggered in-player after answer-latency drift: soft `#F9F9FF` veil at 92%, RenanceMark idle-pulse, card "Your pace is dipping" body "You're 28% slower than 10 questions ago. A 5-minute break now protects your streak — the paper will wait." Buttons: black "Take 5 (timer starts)" + text link "Keep going".
**States:** dismissible; max one nudge per session; taking the break shows a 5:00 countdown with the mark, then auto-resumes.
**Edge cases:** never fires in the last 10 minutes of a timed paper; logged silently to `study.sessions` (no content data, timing only).
**Paste into Stitch:** *Gentle fatigue overlay in the exam player: soft white veil, centered card 'Your pace is dipping — a 5-minute break now protects your streak' with black 'Take 5' button and 'Keep going' text link, small pulsing brand mark above the card.*

### 6.6 Results / score report
**Purpose:** the emotional payoff — honest, motivating, instantly actionable.
**Layout:** **celebration header** (`#131B2E`): big score "68%" w700 white with emerald delta "+6 vs last attempt", pack title caption; confetti = a few blue-tinted geometric shapes (not rainbow); body cards: score breakdown (per-topic horizontal bars: emerald strong ≥70, amber mid 40–69, red weak <40); "Time used 38:12 · 12 flagged"; **XP earned counter** (amber, ticks up, "+85 XP · streak day 12"); bottom: black "Review answers" + outlined "Retry weak topics" (feeds adaptive UI #5) + text "Share score".
**States:** grading = §5.1 veil; partial sync (offline attempt) shows "Syncing to your profile" with inline mark.
**Edge cases:** failing score rewrites header copy honestly: "41% — the review list below is where the points are"; never shame, never inflate.
**Paste into Stitch:** *Results screen: dark header with huge white 68% score, green delta '+6 vs last attempt', subtle geometric confetti; white cards with per-topic colored bars (green/amber/red), time used, an amber '+85 XP · streak day 12' counter; black 'Review answers' button and outlined 'Retry weak topics'.*

### 6.7 Answer review with explanations
**Purpose:** where learning actually happens; every wrong answer one tap from understanding.
**Layout:** top bar "Review · 41 wrong" + filter chips (Wrong · Flagged · Skipped · All); list of question cards: question text (2-line clamp), your pick (red letter tile) vs correct (emerald letter tile), explanation preview, chevron; expanded card shows full explanation, "Ask tutor why" violet button (→ §7.6, ROADMAP #9) and topic chip linking to syllabus (§7.5).
**States:** explanations cached offline with the pack; AI follow-ups need network — button shows tiny "online" dot state.
**Edge cases:** 0 wrong = celebration empty state "Clean sheet. Go again?"; infinite scroll loads next 20 with inline RenanceMark row.
**Paste into Stitch:** *Answer review list: filter chips, question cards showing 'You picked B' in red tile vs 'Correct: D' in green tile, explanation preview, topic chip and a violet 'Ask tutor why' button. Ink text, white 12px cards, calm layout.*

### 6.8 Progress dashboard (Progress tab)
**Purpose:** the honest mirror — momentum, mastery, gaps; the screen that makes streaks meaningful.
**Layout:** top bar "Progress" + date-range chips (7d · 30d · All); **stat row**: 3 white mini-cards (Questions answered w700 number, Accuracy % emerald, Study time); **accuracy trend card** (line chart, ink line, emerald fill under, no gridlines clutter); **mastery by subject** (horizontal bars per §6.6 colors); **"Weakest topics" card**: top 3 topics with red bars + outlined "Practice this" buttons (feeds #4 syllabus + #5 adaptive UI); streak calendar strip (amber dots per active day).
**States:** loading = RenanceMark in each card independently (cards stream in); empty = "Answer your first questions and this page comes alive".
**Edge cases:** date-range switch animates bars (no full reload); all charts drawn in brand colors only, no chart-junk.
**Paste into Stitch:** *Progress dashboard: three white stat mini-cards (Questions, Accuracy %, Time), a smooth accuracy line chart with green fill, horizontal mastery bars per subject in green/amber/red, a 'Weakest topics' card with red bars and 'Practice this' buttons, and an amber streak calendar dot strip. Light theme #F9F9FF, Inter, 12px white cards.*

---

## 7. Screen specs — C. Growth & intelligence

### 7.1 Gamification hub — Badges & XP (ROADMAP #2)
**Purpose:** make consistency visible and lovable; the trophy room of the grind.
**Layout:** top bar "Badges" + total XP pill (amber); **streak hero card** (white): giant flame "12" w700, "day streak · best 19", 7-day dot row (today pulsing amber), "Frozen days used 1/2" caption; **level card**: "Level 7 · Exam Ready" with XP progress bar to Level 8 ("240/600 XP"); **badge grid** (3 columns): earned badges full-color rounded tiles with name, locked badges at 25% opacity with unlock hint ("Answer 500 questions"); **recent awards** list (icon, name, when, +XP).
**States:** badge unlock moment = full-screen dark `#131B2E` takeover: badge scales in with emerald ring burst, "+50 XP", black "Add to my wall" button; loading awards = RenanceMark in-grid.
**Edge cases:** lost streak shows repair card ("Streak ended yesterday — use a Freeze?") instead of hiding it; XP counters always tick up on arrival, never reset visually.
**Paste into Stitch:** *Gamification hub: white streak hero card with big amber flame count 12, best streak and 7-day dot row; level card 'Level 7 · Exam Ready' with XP progress bar 240/600; 3-column badge grid with some badges locked at low opacity and unlock hints; recent awards list. Light theme, amber/green accents, Inter.*

### 7.2 Badge collection detail
**Purpose:** one badge's story — what it demands, who earned it.
**Layout:** top bar back; hero: large badge art on `#E7EEFF` circle, name, rarity pill ("Rare · 4% of students"); description card ("Awarded for 30 correct answers in a row"); progress card if unearned ("23/30 · you're closer than you think") with amber bar; "Students who earned this also unlocked" horizontal badge strip.
**States:** earned = emerald "Earned 12 Mar 2026" chip + share button; locked = outlined "Set as goal" (adds to Home hero slot).
**Edge cases:** secret badges show "???" art with condition hidden until earned (delight on unlock).
**Paste into Stitch:** *Badge detail: large badge artwork on a #E7EEFF circle, name and rarity pill 'Rare · 4% of students', description card, progress card '23/30' with amber bar, and a horizontal strip of related badges. One variant earned with a green 'Earned 12 Mar 2026' chip.*

### 7.3 Spaced repetition — "Review due today" (Review tab, ROADMAP #3)
**Purpose:** the daily-ritual screen; converts yesterday's mistakes into today's points.
**Layout:** top bar "Review" (tab root); **hero card**: "12 cards due" w700, sub "≈ 6 minutes · 8 from Biology, 4 from Chemistry", black "Start review" button, emerald "All caught up ✓" state when zero; **queue preview list**: card rows (topic chip, front-text preview, due chip "due now"/"due in 3d", ease indicator dots); **forecast strip**: 7-day mini bar chart of upcoming dues.
**States:** syncing queue = RenanceMark in hero only; empty = "Nothing due. The algorithm says rest — or preview tomorrow's 8 cards."
**Edge cases:** huge backlogs (>100) auto-chunk into "Today's 20"; a card graded "again" reappears at queue end immediately.
**Paste into Stitch:** *Spaced review home: white hero card '12 cards due ≈ 6 minutes' with black 'Start review' button; queue preview rows with topic chips and due labels; a 7-day forecast mini bar chart; green 'All caught up' variant implied. Calm light theme, emerald + amber accents.*

### 7.4 Voice flashcards player (ROADMAP #7)
**Purpose:** hands-free, eyes-free review — bus stop, chores, dark room.
**Layout:** full-screen card stage: white 12px card centered (front text Inter w600 20px), speaker button (violet) reads it aloud via TTS; bottom controls: big black "Reveal" button; after reveal the back shows + "Got it" (emerald outline) / "Again" (red outline) row; top: deck title + position "4/20"; audio waveform flourish in `#D0E1FB` while speaking.
**States:** TTS loading = tiny mark inside the speaker button; offline fully supported (on-device TTS); no mic permission ever requested — playback only.
**Edge cases:** system TTS missing → card degrades to silent mode with a one-time snackbar; screen-off audio continues (audio service).
**Paste into Stitch:** *Voice flashcard player: centered white flashcard with large text, violet speaker button with a small blue waveform flourish, bottom black 'Reveal' button and after-reveal 'Got it / Again' buttons in green and red outline. Deck title '4/20' at top. Minimal, high contrast.*

### 7.5 Syllabus map (ROADMAP #4)
**Purpose:** the truth map — coverage and confidence against the official syllabus tree.
**Layout:** top bar "Syllabus · Physics" + exam chip; **coverage header card**: ring "64% covered" emerald, "38 of 59 topics practiced"; **topic tree**: collapsible white section rows ("1. Mechanics — 82%") with per-subtopic rows: topic name, mastery bar (brand colors), question count, chevron → topic detail (start quiz, review cards, lessons); confidence = filled dots (1–3).
**States:** tree cached offline; loading deeper levels = inline RenanceMark row; zero data subject shows "Not started — tap to preview topics".
**Edge cases:** syllabus version chip ("2026 latest") with update snackbar when the API ships a revision; mastery recalculates only after grading completes (never mid-quiz).
**Paste into Stitch:** *Syllabus map: header white card with a green coverage ring '64% covered', then an expandable topic tree — section rows like '1. Mechanics 82%' with subtopic rows showing mastery bars, question counts and confidence dots. Ink text, light theme, 12px cards.*

### 7.6 Socratic AI tutor chat (ROADMAP #9 — violet)
**Purpose:** "why is this wrong?" answered with questions that teach, not answers that spoil.
**Layout:** top bar violet-accented: "Tutor" + context chip ("Biology · Q14"); **context card pinned at top**: the original question, your pick vs correct (mini review-row); chat area: tutor bubbles white, user bubbles `#D0E1FB`, tutor avatar = violet RenanceMark chip; input bar: filled field "Ask why your answer was wrong…", violet send button; quick-prompt chips above input ("Give me a hint", "Explain simply", "Show the rule").
**States:** thinking = tutor bubble with the mark orbiting in violet; offline = composer disabled with "Tutor needs internet — your queue is safe" and queued messages send on reconnect.
**Edge cases:** token-capped hint mode (cheapest slice first); tutor never prints the final answer unless the student taps "Show the rule" twice (deliberate friction); safety: off-topic questions get a gentle redirect.
**Paste into Stitch:** *AI tutor chat screen with violet accents: pinned context card showing a question and 'you picked B / correct D' mini-rows, white tutor chat bubbles with a violet brand-mark avatar, blue-tinted user bubbles, quick-prompt chips ('Give me a hint', 'Explain simply'), filled input with violet send button.*

### 7.7 AI question generator (ROADMAP #13)
**Purpose:** infinite fresh practice on exactly the weak topic, human-reviewable before it lands.
**Layout:** top bar "Generate practice"; form card: topic picker (chips from syllabus), difficulty segmented control (Easy/Medium/Hard), count stepper (5/10/20), violet black-outlined "Generate" button; result list: generated questions with "AI" pip, per-question accept (emerald check) / discard; footer note "New items are reviewed before entering your main stats" (trust copy).
**States:** generating = full-card RenanceMark with caption "Writing 10 questions…"; empty = "Pick a topic and we'll write fresh questions for it".
**Edge cases:** generation failures fall back to "Use a curated pack instead" link; rejected items feed the review queue (ROADMAP gating).
**Paste into Stitch:** *AI question generator form: topic chips, Easy/Medium/Hard segmented control, count stepper, violet 'Generate' button; below, generated question list rows each with a small 'AI' pip and green-accept/red-discard icons; trust note 'reviewed before entering your stats'. Violet #8B5CF6 accents on light theme.*

### 7.8 Study plan (fatigue-aware scheduler, ROADMAP #5+#6)
**Purpose:** today's plan, adapted to the student's real energy — the adaptive UI made visible.
**Layout:** top bar "Today" + date; **plan hero**: "Today's plan · 42 min" with three stacked session blocks as white rows (icon, "Biology — 20 questions", "Review — 12 cards", "Flashcards — voice, 10 min"), reorderable via drag handles; **energy selector**: chips "Sharp / Normal / Tired" — plan re-flows instantly (Tired shrinks practice to 10 and grows review); **fatigue insight card** (from telemetry): "You fade after ~25 min in the evening — plan puts heavy topics first."
**States:** plan generated offline from local telemetry + server weights; empty = "Tell us how you feel and we'll shape today".
**Edge cases:** missed day does not guilt-trip — plan absorbs it ("Yesterday moved into today — lighter than it looks"); exam-week plans cap volume and prioritize sleep copy.
**Paste into Stitch:** *Daily study plan: white hero 'Today's plan · 42 min' with three reorderable session rows (practice, review cards, voice flashcards), an energy selector chip row 'Sharp / Normal / Tired', and an insight card 'You fade after ~25 min in the evening — heavy topics first'. Light theme, ink text, 12px cards.*

---

## 8. Screen specs — D. Social & beyond

### 8.1 Arena lobby (ROADMAP #14)
**Purpose:** the multiplayer front door — turn practice into sport.
**Layout:** top bar "Arena" + season chip ("Season 3 · ends in 9d"); **hero card** (ink `#131B2E` background, white text): "Head-to-head quizzes · 5 questions · 60 seconds", big black-on-white "Find a match" button; **mode cards**: Rapid (1v1), Blitz (3 players), Daily tournament (bracket icon, "Starts 16:00"); **leaderboard preview**: top 5 rows (rank, avatar, name, rating in emerald) + "Your rank #214" row highlighted with `#D0E1FB`.
**States:** matchmaking loading = full-screen veil: two RenanceMarks orbit each other, caption "Finding a worthy opponent…"; offline = entire screen locked with friendly "Arena needs internet — everything else still works".
**Edge cases:** rating below floor shows placement notice; disconnection mid-queue returns to lobby with snackbar.
**Paste into Stitch:** *Arena lobby: dark #131B2E hero card with white text 'Head-to-head quizzes · 5 questions · 60 seconds' and a white 'Find a match' button; mode cards for Rapid, Blitz and Daily tournament; leaderboard preview list with ranks and a highlighted 'Your rank #214' row. Light theme elsewhere.*

### 8.2 Arena live match
**Purpose:** the 60-second adrenaline room.
**Layout:** top bar: both avatars + names, live score "3 — 2" w700 center, timer ring; question card (same anatomy as 6.3 but compact); options as 4 big tappable rows; opponent pulse indicator (their avatar glows when they answer — pressure by design); after Q5: verdict card ("You won +18 rating" emerald / lost red / draw) with rematch + "Back to lobby".
**States:** opponent disconnected = grace card "Opponent lost connection — rating protected"; latency = thin amber bar "Slow connection — answers may lag".
**Edge cases:** tie-break question type auto-injects on draws; rage-quit counts as loss (tiny rules link).
**Paste into Stitch:** *Live 1v1 quiz match: top bar with two avatars and a big '3 — 2' score and timer ring; compact question card; four large answer rows; opponent avatar pulsing when they answer. Then a verdict card 'You won +18 rating' in green with Rematch and Back buttons.*

### 8.3 Offline pack sharing — Bluetooth mesh (ROADMAP #16)
**Purpose:** pack-sharing without internet — the feature that makes Renance spread school-to-school.
**Layout:** top bar "Share offline"; two big action cards: "Send a pack" (icon + "Works with no internet or data") / "Receive a pack"; sending flow: pack picker (downloaded only) → radar illustration (concentric `#DEE8FF` circles) with "Looking for nearby Renance phones…" → device found row (avatar chip, device name, "Connect"); transfer = determinate bar; received → success card "JAMB Biology Mock received — 120 questions".
**States:** radar search = the concentric-circles animation with the RenanceMark center (brand moment!); permissions denied = inline explainers with "Open settings".
**Edge cases:** incomplete transfer resumes via chunk manifest; version mismatch ("This pack needs the latest app") with update link.
**Paste into Stitch:** *Offline sharing screen: two large white action cards 'Send a pack' and 'Receive a pack' with icons; a radar view of concentric blue-tinted circles with the small brand mark in the center and caption 'Looking for nearby Renance phones…'; a found-device row with Connect button. Friendly, blue-tinted, no internet iconography.*

### 8.4 Certificate wallet (ROADMAP #17)
**Purpose:** verifiable proof of achievement, wallet-optional.
**Layout:** top bar "Certificates"; **featured cert card**: white card with subtle guilloche pattern in `#E7EEFF`, "Consistency 100 · Level 7", issue date, verification chip ("Verified ✓" emerald), actions "Share" / "Verify"; grid of earned certs below; locked rows hint what's coming ("Top 100 Arena season — not yet").
**States:** minting = RenanceMark with "Writing to base ledger…" caption; wallet connect = optional sheet (never blocks viewing/sharing as PDF).
**Edge cases:** no-web3 students can share a plain link certificate — same visual, minus chain chip.
**Paste into Stitch:** *Certificate wallet: featured white certificate card with a subtle light-blue guilloche pattern, title 'Consistency 100 · Level 7', green 'Verified' chip, Share and Verify buttons; grid of smaller earned certificates below and one locked row. Premium, calm, light theme.*

### 8.5 Career bridge (ROADMAP #18)
**Purpose:** connect today's practice to tomorrow's door — scholarships, cut-offs, pathways.
**Layout:** top bar "Career"; **pathway hero**: "Where can Biology take you?" card with flat illustration; list cards: "Scholarships open now" (3 rows with deadline chips), "Course cut-off explorer" (search + school rows), "Skills that pay" (starter tracks); each row: icon, title, meta ("Closes 30 Sep"), chevron.
**States:** content cached with packs; stale content shows "Updated 6d ago" honestly; empty region = "Curators are on it — check back".
**Edge cases:** external links open in-app browser with a persistent "Back to Renance" bar; dead links report silently.
**Paste into Stitch:** *Career screen: white hero card 'Where can Biology take you?' with flat blue illustration; sections 'Scholarships open now' (rows with deadline chips), 'Course cut-off explorer' and 'Skills that pay'; each row icon + title + meta + chevron. Light theme, Inter, calm layout.*

### 8.6 Patron portal (ROADMAP #19)
**Purpose:** sponsors fund exam fees/data for real students; transparent, ₦-first.
**Layout:** top bar "Patrons"; **impact hero** (ink background): "₦184,000 unlocked · 46 students", emerald tick list of what money does; **student stories** carousel (opt-in cards: first name, target exam, need); **fund cards**: "Exam fee · ₦21,500" with progress bar and black "Fund this" + "₦1,000 custom" outlined; transparency card: "Every disbursement posted here" with ledger rows (date, amount, student alias).
**States:** payment = Paystack sheet (external), success returns to a thank-you card with receipt chip; offline = read-only with banner.
**Edge cases:** student privacy: aliases only, opt-out respected; failed payments retry gracefully with saved intent.
**Paste into Stitch:** *Patron portal: dark hero card '₦184,000 unlocked · 46 students' with white text, a student stories carousel, fund cards like 'Exam fee · ₦21,500' with progress bars and black 'Fund this' buttons, and a transparency ledger list with dates and amounts. Light theme, trustworthy and warm.*

---

## 9. Screen specs — E. System

### 9.1 Profile (Profile tab)
**Layout:** header card: avatar (tap = picker), username, target chip ("JAMB 2027" → tap = retake §5.3), level pill; stat strip (XP, streak, accuracy); menu list (white grouped rows): My packs, Downloads, Certificates, Patron history, Settings, Help; sign-out (red text, confirm dialog).
**States:** profile edit = inline fields with save-on-blur; target change shows the personalization impact dialog ("Your home will reshape around WAEC").
**Edge cases:** account with Google has linked-provider row; deleting account = destructive red zone with typed confirmation.
**Paste into Stitch:** *Profile tab: header card with avatar, username, an exam-target chip 'JAMB 2027', level pill, stat strip (XP, streak, accuracy), then grouped white menu rows (My packs, Downloads, Certificates, Settings, Help) and a red Sign out row.*

### 9.2 Settings
**Layout:** grouped white lists: **Learning** (daily goal stepper, reminder time, energy defaults), **Data & offline** (sync over data toggle, auto-download next pack, storage meter with clear-cache), **Account** (Google link, change password), **About** (version, licenses, roadmap link). iOS-style switches in ink.
**States:** every toggle optimistic + snackbar undo where safe.
**Edge cases:** storage meter >80% suggests clearing reviewed packs; reminders push to local notifications only.
**Paste into Stitch:** *Settings screen with grouped white list sections 'Learning', 'Data & offline' (including a storage meter bar), 'Account' and 'About', using ink switches and 12px card groups on #F9F9FF.*

### 9.3 Downloads & offline manager
**Layout:** top bar "Downloads"; storage card (used/total, amber when >80%); pack rows: icon, title, size, status chip (Downloaded / Paused / Queued), swipe actions (pause, delete); bottom "Auto-download next in syllabus" explainer card.
**States:** active download = determinate bar in row; queue reorders drag-and-drop; offline fully functional.
**Edge cases:** delete asks once with size reminder; corrupted pack auto-repairs via manifest.
**Paste into Stitch:** *Downloads manager: storage card with used/total bar (amber warning state), list of downloaded packs with size and status chips (Downloaded, Paused, Queued), swipe action hints, and an 'Auto-download next in syllabus' explainer card.*

### 9.4 Notifications
**Layout:** top bar "Notifications" + "Mark all read"; grouped by day; row types: streak warning (flame icon, amber), review due (emerald), badge earned (badge art), arena result, patron receipt; unread = `#F0F3FF` fill; deep-links to source screen.
**States:** empty = "All quiet. Go make some noise."; permission denied explainer with settings link.
**Edge cases:** silent hours respected (22:00–07:00 local); digest mode merges review + streak into one morning card.
**Paste into Stitch:** *Notifications list grouped by day with row types — amber streak warning, green review-due, badge earned, arena result — unread rows tinted #F0F3FF, 'Mark all read' text button in top bar.*

### 9.5 Global state kit (build once, reuse everywhere)
**Purpose:** the reference sheet for empty, error, offline and loading in EVERY screen.
**Layout:** 4 stacked demo panels: ① **Empty** — illustration zone (flat blue shapes), title 18px w600, one line body, black action. ② **Error** — white card, red icon chip, human sentence, outlined Retry + "Repeat last action" hint. ③ **Offline banner** — amber strip with cloud-off icon under any top bar. ④ **Loading veil** — `#F9F9FF` 92% veil, RenanceMark busy, one-line caption ("Marking your paper…", "Finding a worthy opponent…", "Writing 10 questions…").
**Rule:** caption text changes per context, mark never does. No spinner exists in this product.
**Paste into Stitch:** *A 4-panel component sheet: empty state with flat blue illustration + headline + black button; error card with red icon and Retry; slim amber offline banner with cloud-off icon; loading veil with pulsing brand logomark and three orbiting arcs and caption 'Marking your paper…'. Never any circular spinner.*

---

## 10. State matrix — what each screen must ship with

| # | Screen | Empty | Loading | Error / edge |
| --- | --- | --- | --- | --- |
| 5.1 | Splash / veil | — | RenanceMark (this IS the loader) | offline proceeds to cached content |
| 5.2 | Onboarding | — | — | resumes at last slide |
| 5.3 | Target selection | — | RenanceMark | single-pick now, multi-prep later |
| 5.4 | Home (JAMB) | → 5.6 | hero-only mark, grid cached | exam-week copy; post-exam recap |
| 5.5 | Home (University) | → 5.6 | hero-only mark | target-switch confirm dialog |
| 5.6 | Home first-run | this IS empty | — | routes to 5.3 if no target |
| 5.7 | Search | zero-results state | inline mark at list end | offline = cached packs only |
| 5.8 | More sheet | — | — | unshipped tiles at 40% + "Soon" |
| 6.1 | Pack library | no-packs illustration | RenanceMark over cached grid | offline shows downloaded first |
| 6.2 | Pack detail | hides history card | determinate download bar | cached header + retry inline |
| 6.3 | Exam player | — | mark replaces question card only | timer amber→red; resume after kill |
| 6.4 | Navigator | — | — | locked during grading |
| 6.5 | Fatigue nudge | — | 5:00 break countdown | never in last 10 min |
| 6.6 | Results | — | grading veil (§5.1) | honest low-score copy; syncing chip |
| 6.7 | Answer review | clean-sheet celebration | inline mark per 20 rows | AI button reflects online state |
| 6.8 | Progress | first-question illustration | per-card marks | range switch animates, no reload |
| 7.1 | Gamification hub | — | mark in-grid | streak repair card, not silence |
| 7.2 | Badge detail | — | — | secret badges as "???" |
| 7.3 | Review queue | all-caught-up state | mark in hero only | backlog auto-chunks to 20 |
| 7.4 | Voice flashcards | empty deck state | mark inside speaker button | no-mic ever; TTS-missing fallback |
| 7.5 | Syllabus map | not-started subject state | inline mark per level | version chip + update snackbar |
| 7.6 | AI tutor | — | violet orbiting mark in bubble | offline queue-and-send on reconnect |
| 7.7 | AI generator | pick-topic empty state | generating veil | fallback to curated pack |
| 7.8 | Study plan | feel-today empty state | — | missed day absorbed, no guilt |
| 8.1 | Arena lobby | — | matchmaking veil (two marks) | hard offline lock with warmth |
| 8.2 | Arena match | — | — | disconnect = rating protected |
| 8.3 | BT mesh share | — | radar + determinate bar | permission explainers; resume chunks |
| 8.4 | Certificates | none-yet rows | minting veil | no-wallet share still works |
| 8.5 | Career bridge | curator empty state | — | stale-content honesty chip |
| 8.6 | Patron portal | — | — | offline read-only + banner |
| 9.1 | Profile | — | — | destructive delete = typed confirm |
| 9.2 | Settings | — | — | optimistic toggles + undo |
| 9.3 | Downloads | nothing-downloaded state | determinate per row | >80% storage nudge; auto-repair |
| 9.4 | Notifications | all-quiet state | — | silent hours; digest merge |
| 9.5 | State kit | — | — | the reusable reference |

---

## 11. Stitch workflow tips (read before generating)

1. **One screen per prompt, in document order.** Components defined by early screens (top bar, tile anatomy, chip styles) will be reused by Stitch in later ones if you generate in order and say "same top bar and tile style as before".
2. **Repeat the tokens, they drift.** Models forget hex values across turns. Re-state the two or three colors that matter per screen (e.g., "amber #F59E0B streak flame, ink #111C2D text, background #F9F9FF").
3. **Say "no circular spinner" explicitly** whenever a screen has a loading state — models default to spinners; the RenanceMark must be requested by description (pulsing logomark + three orbiting arcs).
4. **Ask for states as follow-ups on the same screen** ("now show this screen empty", "now the error state") rather than new sessions — this keeps the layout stable across states, which is exactly what the implementation will need.
5. **Export and name immediately:** `renance/s5.4-home-jamb.png` etc. — matching this document's numbering so design files map 1:1 to build tickets.
6. **When a screen fights you,** strip it back: paste only §2 tokens + that screen's Paste block, regenerate, then re-apply details one edit turn at a time.
