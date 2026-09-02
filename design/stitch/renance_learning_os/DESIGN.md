---
name: Renance Learning OS
colors:
  surface: '#f9f9ff'
  surface-dim: '#cfdaf2'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#F0F3FF'
  surface-container: '#E7EEFF'
  surface-container-high: '#DEE8FF'
  surface-container-highest: '#d8e3fb'
  on-surface: '#111c2d'
  on-surface-variant: '#4c4546'
  inverse-surface: '#263143'
  inverse-on-surface: '#ecf1ff'
  outline: '#7e7576'
  outline-variant: '#cfc4c5'
  surface-tint: '#5e5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1b1b1b'
  on-primary-container: '#848484'
  inverse-primary: '#c6c6c6'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#d8dff9'
  on-secondary-container: '#5a6278'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#23005c'
  on-tertiary-container: '#9466ff'
  error: '#BA1A1A'
  on-error: '#ffffff'
  error-container: '#FFDAD6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c6'
  on-primary-fixed: '#1b1b1b'
  on-primary-fixed-variant: '#474747'
  secondary-fixed: '#dae2fc'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465b'
  tertiary-fixed: '#e9ddff'
  tertiary-fixed-dim: '#d0bcff'
  on-tertiary-fixed: '#23005c'
  on-tertiary-fixed-variant: '#5516be'
  background: '#F9F9FF'
  on-background: '#111c2d'
  surface-variant: '#d8e3fb'
  card: '#FFFFFF'
  text-secondary: '#45464D'
  selection-blue: '#D0E1FB'
  accent-violet: '#8B5CF6'
  accent-emerald: '#10B981'
  accent-amber: '#F59E0B'
  outline-light: '#C6C6CD'
  outline-dark: '#76777D'
  dark-surface: '#131B2E'
  dark-card: '#1A243A'
  dark-surface-low: '#17223B'
  dark-text-primary: '#F0F3FF'
  dark-text-secondary: '#A2AAB8'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  display-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  section-title:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-base:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: '0'
  body-medium:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: '0'
  body-secondary:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: '0'
  caption:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: '0'
  stat-number:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 28px
    letterSpacing: -0.02em
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: '0'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system for this student learning OS is rooted in a **Corporate/Modern** aesthetic with a distinctive **Minimalist** focus on intellectual clarity. It is designed to feel like a high-performance "Operating System" for education rather than a simple app, prioritizing focus, discipline, and quiet optimism.

The visual language balances a professional, authoritative tone with energetic gamification elements. It uses a "One home, many faces" philosophy, where the underlying structural skeleton remains consistent while adapting to different exam targets.

**Key Brand Pillars:**
- **No-Friction Navigation:** Replaces hidden menus with a thumb-reachable 4-column launcher grid.
- **Honest Feedback:** Rejects generic loading spinners in favor of the signature pulsing brand logomark.
- **Functional Gamification:** Uses vibrant gem-tone accents strictly for habit loops, AI intelligence, and mastery feedback.
- **Offline-First Utility:** Designed to look and feel fast, reliable, and "always-on" even without a network connection.

## Colors

The color palette is built on functional layering to reduce eye strain during long study sessions.

**Light Mode (Default):**
- **Foundation:** The canvas uses a blue-tinted white (`#F9F9FF`) to reduce glare, paired with pure white (`#FFFFFF`) for interactive cards.
- **Interaction:** High-contrast obsidian (`#000000`) is reserved for primary actions to communicate seriousness of purpose.
- **Semantics:** 
    - **Violet (`#8B5CF6`):** Dedicated to AI-powered features and tutor interactions.
    - **Emerald (`#10B981`):** Used for success, mastery, and positive reinforcement.
    - **Amber (`#F59E0B`):** Signals habit vitality, streaks, and offline alerts.

**Dark Mode:**
- The dark variant transitions to a deep midnight foundation (`#131B2E`) with elevated surfaces in `#1A243A`. Text shifts to a soft blue-tinted white (`#F0F3FF`) to maintain legibility without harsh contrast.

## Typography

The system relies on **Inter** for its exceptional legibility in dense academic content. **JetBrains Mono** is used selectively for technical data, course codes, and countdown timers to provide a "computational" feel.

- **Scale:** Maintain a tight vertical rhythm. Headings should sit close to their related content (max 8px gap).
- **Legibility:** Body copy uses a relaxed 1.46x line height (22px on 15px text) to facilitate rapid reading during extended sessions.
- **Numbers:** Use tabular figures (`tabular-nums`) for all monospaced timers and scores to prevent layout shifting during countdowns.

## Layout & Spacing

This design system uses a **Fluid Grid** model optimized for mobile-first interaction (9:16 aspect ratio). 

**Key Layout Rules:**
- **The Launcher Grid:** A 4-column responsive grid replaces the standard drawer menu for main feature navigation. Use a 12px gap between tiles.
- **Content Constraint:** On desktop, content should be constrained to a centered 640px column for reading and 1024px for dashboards.
- **Safe Zones:** Navigation elements (Bottom Nav) float with a 12px margin above the system gesture indicator.
- **Rhythm:** All spacing is derived from a 4px/8px base unit. Use 16px margins for mobile as the standard gutter.

## Elevation & Depth

Visual hierarchy is primarily established through **Tonal Layers** and extremely subtle **Ambient Shadows**.

- **Surface Layering:** Use the light-blue tinted backgrounds (`#F9F9FF`) as the "ground" and pure white (`#FFFFFF`) cards as the "elevated" interactive surface. 
- **Shadows:** Only Elevation 1 is used for cards, defined as a soft, tinted shadow: `0px 1px 3px 0px rgba(20, 28, 45, 0.20)`. 
- **Floating Elements:** Snackbars and Bottom Sheets use a more diffused shadow (`rgba(17, 28, 45, 0.12)`) to indicate higher Z-index.
- **Overlays:** A 92% opacity veil in the background color is used for loading states, ensuring the user remains oriented within the app's context.

## Shapes

The design system uses a **Rounded** (Level 2) language to balance professional structure with approachable softness.

- **Standard Cards:** 12px radius.
- **Buttons & Inputs:** 10px radius (creating a slightly sharper look for functional components).
- **Chips:** Full pill-shaped (20px+) for categorical elements.
- **Launcher Tiles:** 72x72px squares with 12px rounding.
- **Bottom Navigation:** 12px top-only rounding for the container.

## Components

### Buttons
- **Primary:** 52px tall, solid black fill (`#000000`), 10px radius, white Inter w600 text.
- **Secondary:** 52px tall, 1px solid border (`#C6C6CD`), 10px radius, `#111C2D` text.
- **Destructive:** 52px tall, `#BA1A1A` background or border.

### Inputs & Chips
- **Text Inputs:** 10px radius, filled with `#F0F3FF`. Use a 1.4px solid `#111C2D` border only on focus.
- **Chips:** Pill-shaped. Unselected use `#F0F3FF` fill; selected use `#D0E1FB` (Soft Blue) with w600 text.

### Cards
- **Standard Card:** 12px radius, white background, Elevation 1 shadow.
- **Option Cards (Quiz):** 1px border `#E7EEFF`. Immediate feedback on select: 2px border transition to `#111C2D` (Idle), `#10B981` (Correct), or `#BA1A1A` (Incorrect).

### Navigation
- **Bottom Nav:** 5-tab layout, white background, 12px top radius. Active tabs use a filled icon variant with a 4px circular pip below.
- **Top Bar:** Background-colored (`#F9F9FF`), zero elevation. Features the streak flame (Amber) and user avatar prominently.

### The RenanceMark (Signature Loader)
- **Mandate:** NO circular spinners.
- **Animation:** A pulsing brand mark with three orbiting arcs. The mark should scale breathe (1.8s loop) while arcs rotate with phase-shifted opacity. Use this for all "Active Syncing" or "Grading" states.