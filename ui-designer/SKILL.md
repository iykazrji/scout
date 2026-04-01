---
name: ui-designer
description: Platform-agnostic UI design orchestrator — produces visual mockups, design systems, and screen specs via a multi-agent pipeline. Works standalone or as a peer agent dispatched by Scout. Use when user wants UI/UX design, says "design this", "ui-designer", or when Scout detects UI-heavy features.
---

# /ui-designer - Platform-Agnostic UI Design Orchestrator

Takes a raw idea or Scout-dispatched feature brief and drives it through design interrogation, codebase reconnaissance, design system creation, screen-by-screen specification with visual mockups, and automated visual verification — producing a complete design package ready for implementation. Manages a roster of named, color-coded agents that run in dedicated cmux tabs when available, or in-process when not.

## When to Use

- `/ui-designer` — starts full interactive design pipeline
- `/ui-designer --express` — skip grill, use existing context (grill summary, Scout context, or user description)
- `/ui-designer --auto` — minimal gates, auto-approve most phases, pause only at VERIFY
- `/ui-designer verify` — run Inspector only on existing build (compare mockups to implementation)
- `/ui-designer:settings` — opens interactive settings menu
- Dispatched by Scout when UI-heavy features detected in PRD

## Agent Roster

| Agent | Color | Hex | Icon | Role | Own Tab? |
|-------|-------|-----|------|------|----------|
| **Designer** | Pink | `#EC4899` | 🩷 | Orchestrator — manages phases, state, user interaction | Original tab |
| **Griller** | Red | `#DC2626` | 🔴 | UI-specific interview via custom grill template | No — runs in Designer tab |
| **Reconn** | Yellow | `#EAB308` | 🟡 | Shared with Scout — project context + design trends | Yes (cmux only) |
| **Stylist** | Cyan | `#06B6D4` | 🩵 | Design system — tokens, palette, typography, components | Yes (cmux only) |
| **Specifier** | Indigo | `#6366F1` | 🟪 | Screen-by-screen specs with mockups | Yes (cmux only) |
| **Inspector** | Teal | `#14B8A6` | 🔍 | Playwright verification — mockup capture + build comparison | Yes (cmux only) |

## Settings

### Settings file: `~/.claude/skills/ui-designer/settings.json`

Persistent settings that Designer reads on every startup. Defaults if file doesn't exist:

```json
{
  "quality": "balanced",
  "mode": "interactive",
  "cmux": "auto"
}
```

### `/ui-designer:settings` — Interactive Settings Menu

Use `/ui-designer:settings` to configure settings interactively. This is a separate sub-skill for fast invocation — see `settings.md`.

### Quality Profiles

Each profile maps agents to models via the Agent tool's `model` parameter:

| Agent | `high` | `balanced` | `budget` |
|-------|--------|------------|----------|
| **Designer** | opus | opus | sonnet |
| **Griller** | opus | opus | sonnet |
| **Reconn** | opus | sonnet | sonnet |
| **Stylist** | opus | opus | sonnet |
| **Specifier** | opus | sonnet | sonnet |
| **Inspector** | opus | sonnet | sonnet |

When dispatching an agent via the Agent tool, pass the `model` parameter:
```
Agent tool call:
  model: "sonnet"  (or "opus" based on quality profile)
  subagent_type: "general-purpose"
  prompt: <agent task prompt>
```

### Execution Modes

| Behavior | `interactive` | `express` | `auto` |
|----------|--------------|-----------|--------|
| Grill interview | Yes | **Skipped** — use existing context | Skipped |
| Grill approval gate | Yes | Skipped | Skipped |
| Reconn research | Yes | Yes | Yes (auto-extended) |
| Design system approval | Yes | Yes | Auto-approved |
| Per-screen spec approval | Yes | Yes | Auto-approved |
| VERIFY gate | Yes | Yes | **Pauses here** — mandatory human review |
| Handoff approval | Yes | Auto-approved | Auto-approved |
| Phase transition reports | Wait for input | Report status, continue | Report status, continue |

**`express` mode** is the sweet spot for iteration: you already know what you want (from a prior grill, a Scout PRD, or your own brief), so skip the interrogation and jump straight to design. All design artifacts still get approval.

**`auto` mode verification gate rationale**: Even in fully autonomous mode, the VERIFY phase pauses for human review. Visual design is subjective — an LLM can check structural correctness (layout matches spec, components present, states covered) but cannot judge aesthetic quality, brand alignment, or emotional impact. The Inspector presents its findings and the user decides whether the build matches the design intent.

## Startup Protocol

On `/ui-designer` invocation:

### 1. Parse arguments and load settings

Read `~/.claude/skills/ui-designer/settings.json` if it exists, otherwise use defaults.

Check for mode overrides in the user's prompt:
- `--auto` or "autonomously" → override mode to `auto`
- `--express` or "express mode" or "skip grill" → override mode to `express`
- `verify` → jump directly to VERIFY phase (run Inspector only)

For settings, use `/ui-designer:settings` directly (separate sub-skill for fast invocation).

### 2. Detect project technology

Check for project markers and set technology flags in state:

**Flutter detection:**
```bash
ls pubspec.yaml 2>/dev/null && grep -q "flutter:" pubspec.yaml 2>/dev/null
```
Also set `flutter: true` if the user's idea explicitly mentions Flutter or Dart.

**React Native detection:**
```bash
# Check for React Native / Expo project markers
(ls package.json 2>/dev/null && grep -q '"react-native"' package.json 2>/dev/null) || ls app.json 2>/dev/null || ls expo-env.d.ts 2>/dev/null
```
Also set `reactNative: true` if the user's idea explicitly mentions React Native, Expo, or RN.

If detected, determine if Expo-based:
```bash
grep -q '"expo"' package.json 2>/dev/null && echo "expo"
```

**Next.js detection:**
```bash
# Check for Next.js project markers
ls next.config.js next.config.mjs next.config.ts 2>/dev/null || (ls package.json 2>/dev/null && grep -q '"next"' package.json 2>/dev/null)
```
Also set `nextjs: true` if the user's idea explicitly mentions Next.js or Next.

**React detection (client-side SPA — not Next.js or React Native):**
```bash
# Check for React project that is NOT Next.js or React Native
(ls package.json 2>/dev/null && grep -q '"react"' package.json 2>/dev/null) && \
  ! grep -q '"next"' package.json 2>/dev/null && \
  ! grep -q '"react-native"' package.json 2>/dev/null
```
Also check for common React SPA tooling:
```bash
ls vite.config.ts vite.config.js 2>/dev/null  # Vite
ls webpack.config.js 2>/dev/null  # Webpack
grep -q '"react-router"' package.json 2>/dev/null  # Client-side routing
```
Set `react: true` if detected, or if the user's idea explicitly mentions React (without Next.js/RN context).

**Web vanilla detection:**
```bash
# Check for vanilla web project (no framework)
ls index.html 2>/dev/null && ! ls package.json 2>/dev/null
# OR has package.json but no framework
(ls package.json 2>/dev/null && \
  ! grep -q '"react"' package.json 2>/dev/null && \
  ! grep -q '"vue"' package.json 2>/dev/null && \
  ! grep -q '"svelte"' package.json 2>/dev/null && \
  ! grep -q '"angular"' package.json 2>/dev/null && \
  ! grep -q '"next"' package.json 2>/dev/null && \
  ! grep -q '"react-native"' package.json 2>/dev/null)
```
Set `web: true` if no other frontend framework detected but HTML/CSS/JS files exist.

**Express.js detection:**
```bash
ls package.json 2>/dev/null && grep -q '"express"' package.json 2>/dev/null
```
Also set `express: true` if the user's idea explicitly mentions Express or Express.js.

**Fastify detection:**
```bash
ls package.json 2>/dev/null && grep -q '"fastify"' package.json 2>/dev/null
```
Also set `fastify: true` if the user's idea explicitly mentions Fastify.

Note: Express and Fastify are backend frameworks — they can co-exist with frontend flags. For UI design purposes, the frontend framework flag drives platform-specific design decisions.

**If dispatched by Scout:** Read the Scout context file at `/tmp/ui-designer-context.json` to inherit platform detection, grill summary, and PRD reference. Skip manual detection when context file provides the flags.

Announce detected technology:
```
DESIGNER [flutter: yes] — design system will use Material 3 / Cupertino patterns
DESIGNER [react-native: yes, expo: yes] — design system will use cross-platform mobile patterns
DESIGNER [nextjs: yes] — design system will use web-first responsive patterns
DESIGNER [react: yes] — design system will use React component patterns
DESIGNER [web: yes] — design system will use vanilla web standards
```

### 3. Detect cmux

```bash
# Try to identify cmux environment
cmux identify --json 2>/dev/null
```

If succeeds: cmux mode active. Capture workspace ref.
If fails: in-process mode.

Announce:
```
DESIGNER [cmux: active] — agents will spawn in dedicated tabs
```
or:
```
DESIGNER [cmux: off] — agents will run in-process
```

### 4. Check for interrupted session

Check if `/tmp/ui-designer-state.json` exists with a non-COMPLETE phase:
- If found: report what was in progress, ask user to resume or start fresh
- If not found or COMPLETE: proceed with new session

### 5. Initialize state

Write initial state to `/tmp/ui-designer-state.json`:
```json
{
  "mode": "cmux",
  "executionMode": "interactive",
  "phase": "GRILL",
  "quality": "balanced",
  "flutter": false,
  "reactNative": false,
  "expo": false,
  "nextjs": false,
  "react": false,
  "web": false,
  "express": false,
  "fastify": false,
  "idea": "<from user prompt>",
  "scoutContext": null,
  "grillSummary": null,
  "reconnFindings": null,
  "designSystem": null,
  "screens": [],
  "screenSpecs": [],
  "verifyResults": null,
  "agents": {},
  "workspace": "<workspace ref or null>",
  "startedAt": "<ISO timestamp>"
}
```

### 6. Display initial state

```
DESIGNER STATE:
  Mode: [interactive | express | auto]
  Quality: [high | balanced | budget]
  cmux: [active | off]
  Platform: [flutter | react-native (expo) | nextjs | react | web | unknown]
  Phase: [GRILL | RECONN | DESIGN | SPEC | VERIFY | HANDOFF | COMPLETE]
  Idea: <one-line summary>
  Scout Context: <file path or "none">
  Grill Summary: <file path or "pending">
  Reconn Findings: <file path or "pending">
  Design System: <directory path or "pending">
  Screens: <count> designed, <count> pending
  Verify: <status or "pending">
```

## cmux Tab Management

### Spawning an agent tab

```bash
# 1. Capture current workspace
CURRENT_WS=$(cmux current-workspace 2>&1 | awk '{print $1}')

# 2. Write agent task to file
cat > /tmp/ui-designer-task-<agent>.md << 'EOF'
<task content>
EOF

# 3. Create new tab in current workspace
NEW_SURFACE=$(cmux new-surface --workspace "$CURRENT_WS" 2>&1 | awk '{print $2}')

# 4. Launch Claude in the tab
cmux send --surface "$NEW_SURFACE" "claude \"$(cat /tmp/ui-designer-task-<agent>.md)\""
cmux send-key --surface "$NEW_SURFACE" enter

# 5. Name and color the tab
cmux rename-tab --surface "$NEW_SURFACE" "<Agent Name>"
cmux set-status --surface "$NEW_SURFACE" --icon "<icon>" --color "<hex>"
```

### Completion detection

Agents write result files on completion:
```bash
# Designer polls for this file
cat /tmp/ui-designer-result-<agent>.json
# {"status": "done", "result": "<output path>"}
# or {"status": "failed", "error": "..."}
```

### Tab status updates

On agent completion:
- Success: update tab icon to checkmark
```bash
cmux set-status --surface "$SURFACE" --icon "✅" --color "#16A34A"
```
- Failure: update tab icon to X
```bash
cmux set-status --surface "$SURFACE" --icon "❌" --color "#DC2626"
```

### Non-cmux fallback

When cmux is not available, dispatch agents via the Agent tool:
- Use `subagent_type: "general-purpose"` for all agents
- Pass the full task prompt directly
- Agent tool returns results inline (no file polling needed)
- Stylist, Specifier, and Inspector run sequentially in-process

## Phase 1: GRILL — Interrogate the Design Requirements

**Goal**: Turn a vague idea into concrete design requirements with all major visual and UX decisions resolved.

**Skip in express/auto mode** — use existing context (Scout context file, prior grill summary, or user description).

### 1a. Capture the idea

Summarize the user's prompt back to confirm scope. If too vague, ask 1-2 clarifying questions.

**Vague prompt guard**: If the user's prompt is < 2 sentences, ask 2-3 clarifying questions before proceeding — design without requirements produces generic output.

### 1b. Dispatch Griller (in-process)

Dispatch Griller as an IN-PROCESS subagent (NOT in a cmux tab — needs user Q&A). The Griller uses the UI-specific grill template from `~/.claude/skills/ui-designer/templates/grill-template.md`.

**Griller task prompt:**
```
You are Griller 🔴, a relentless UI/UX interviewer. Your job is to interrogate the user about their design requirements until EVERY visual and interaction decision is resolved.

## The Idea Under Review

<user's idea description>

## Platform Context

Platform: <detected platform>
Technology flags: <flutter, reactNative, expo, nextjs, react, web>

## Interview Protocol

You are interviewing the user about UI/UX design requirements. Use the UI-specific grill template categories below instead of the standard technical categories.

### Mindset
- You are skeptical but constructive — challenge weak aesthetic thinking, don't just poke holes
- Assume nothing about visual preferences. "Make it look good" is not a decision.
- Your goal is SHARED UNDERSTANDING of the visual and interaction design
- When the user gives a good answer, acknowledge it and move on — don't grill for sport

### Decision Tree Method

Treat the design as a tree of decisions. For each node:

1. **Identify the decision** — What visual/UX choice was made (or left unmade)?
2. **Ask WHY** — What drove this choice over alternatives?
3. **Probe alternatives** — "What about X instead?" / "Why not Y?"
4. **Find edges** — "What happens when Z?" / "What if the user does this?"
5. **Resolve or flag** — Either reach agreement or mark as needing more thought

### Question Categories

Work through these systematically. Skip categories that don't apply to the detected platform.

**Category 1: User Personas**
- Who is the primary user? Tech comfort level?
- What devices will they primarily use?
- What's the typical usage context? (On-the-go, focused work, casual browsing?)
- Are there distinct user types with different needs?
- What's the user's emotional state when they arrive?
Decision points: Primary device/viewport, user sophistication, usage context.

**Category 2: Brand & Tone**
- Are there existing brand guidelines, colors, or fonts?
- What visual tone? (Minimal/refined, bold/maximalist, playful, corporate, editorial, brutalist?)
- 2-3 existing products whose visual style you admire?
- Should this feel premium, accessible, or utilitarian?
- Existing design system or component library to extend?
Decision points: Aesthetic direction, brand constraints vs creative freedom, extend vs create.

**Category 3: Screen Inventory**
- What are the core screens/views that need design?
- Primary user flow?
- Navigation model? (Tab bar, sidebar, hamburger, breadcrumbs?)
- Which screens are most critical?
- Is there a "hero" screen that defines the product's visual identity?
Decision points: Complete screen list, navigation model, priority screens.

**Category 4: States Matrix**
- Empty states — what does each screen look like with no data?
- Loading pattern — skeleton screens, spinners, shimmer, progressive?
- Error states — inline, toast, full-page, retry?
- Edge cases — extremely long content, single item, thousands of items, offline?
Decision points: Empty state strategy, loading pattern, error handling, edge cases.

**Category 5: Interaction Patterns**
- Expected gestures? (Swipe, pull-to-refresh, pinch, long press?)
- Screen transitions? (Slide, fade, shared element, instant?)
- Micro-interactions? (Button feedback, success animations, progress indicators?)
- Drag-and-drop, reorderable lists, complex touch patterns?
- Hover states? (Web only)
Decision points: Gesture vocabulary, transition style, micro-interaction priority.

**Category 6: Accessibility**
- WCAG level target? (A, AA, AAA?)
- Screen reader support scope?
- Color contrast requirements beyond minimums?
- Reduced motion preferences?
- Motor accessibility? (Large touch targets, alternative inputs?)
Decision points: WCAG level, screen reader scope, reduced motion strategy, min touch targets.

**Category 7: Responsive Behavior** (skip for native mobile unless targeting tablets)
- Key breakpoints?
- Responsive (same layout adapts) or adaptive (different layouts)?
- How do dense desktop layouts simplify for mobile?
- Landscape orientation important?
Decision points: Breakpoint strategy, responsive vs adaptive, layout transformation rules.

**Category 8: Content Density**
- Data-heavy or content-light?
- List display format? (Cards, rows, grid, compact?)
- Pagination strategy? (Infinite scroll, load more, numbered pages?)
- Information visible at once vs hidden behind expand/detail?
- Data visualization needs?
Decision points: Density level, list/grid format, pagination, data viz requirements.

**Category 9: Existing Design Context**
- Existing design system, theme, or component library in the codebase?
- Specific colors, fonts, spacing values already in use?
- Existing screens that new design should feel consistent with?
- Style guide, Figma file, or design documentation?
- Third-party UI libraries in use?
Decision points: Extend vs create, existing constraints, library compatibility.

### Platform Adaptation

Adapt categories to the detected platform:

| Platform | Skip | Add |
|----------|------|-----|
| React Native / Expo | Responsive breakpoints | Gesture navigation, safe areas, platform-specific UI (iOS vs Android) |
| Flutter | Responsive breakpoints (unless targeting web) | Material 3 / Cupertino adaptation, platform channels |
| Web (React/Next.js) | Native gestures | Responsive breakpoints, keyboard navigation, SEO considerations |
| Web (vanilla) | Native gestures | Progressive enhancement, browser compatibility |

### Pacing

- Ask 1-3 focused questions per turn (never more)
- Group related questions together
- After each answer, either dig deeper on that branch OR mark it resolved and move to the next
- Use AskUserQuestion for structured choices when the decision has clear options
- Use plain text questions when open-ended exploration is needed

### Early Scope Signal (Mid-Grill Reconn Trigger)

Once you have answers for categories 1-3 (User Personas, Brand & Tone, Screen Inventory), write a scope file to /tmp/ui-designer-grill-scope.json:

{
  "platform": "<detected>",
  "screens": ["<list of screens>"],
  "userTypes": ["<list of user types>"],
  "tone": "<visual tone keyword>"
}

This signals the Designer orchestrator to start Reconn research in parallel while you continue grilling through the remaining categories.

### Completion

When all relevant categories are resolved, produce a **Design Decision Summary**:

1. **Resolved Decisions** — every decision with its rationale
2. **Platform** — detected platform and implications
3. **Screen List** — all screens to design, in priority order
4. **Aesthetic Direction** — the committed visual tone and differentiation
5. **Design Constraints** — brand, accessibility, existing system requirements
6. **Open Items** — anything that still needs answers or research
7. **Risks** — concerns surfaced during grilling

Save to /tmp/ui-designer-grill-summary.md.
```

### 1c. Mid-grill Reconn trigger

While the Griller is running, poll for `/tmp/ui-designer-grill-scope.json`. When it appears (after categories 1-3 are resolved):

1. Read the scope file
2. Dispatch Reconn agent with a design-focused research brief (see Phase 2 for Reconn task prompt)
3. Reconn runs in parallel while the Griller finishes categories 4-9

This allows research to complete by the time the grill finishes, reducing total pipeline time.

### 1d. Approval gate

Present the Design Decision Summary. Ask:
> "Are you happy with these design decisions? Should we proceed to research and design, or revisit any points?"

**Mode behavior:**
- `interactive`: wait for explicit approval
- `express`: skipped (grill was skipped)
- `auto`: skipped (grill was skipped)

Update state: `phase: "RECONN"`, `grillSummary: "/tmp/ui-designer-grill-summary.md"`.

Display updated DESIGNER STATE.

## Phase 2: RECONN — Design-Focused Research

**Goal**: Gather codebase context, design trends, and existing patterns to inform the design system and screen specs.

### 2a. Dispatch Reconn

Spawn Reconn agent via `/reconn` protocol (shared with Scout). The research brief has 3 layers with a design focus.

If Reconn was already started during the mid-grill trigger (1c), wait for it to complete and read its findings. If not yet started (express/auto mode), dispatch now.

**Reconn task prompt:**
```
You are Reconn 🟡, a deep research agent. Research the following topic across codebase, web, and notes with a DESIGN focus.

## Research Brief

Idea: <user's idea description>
Platform: <detected platform>
Aesthetic direction: <from grill summary or user description>
Screens to design: <screen list from grill or user description>

## Design-Focused Research — 3 Layers

### Layer 1: Codebase (existing design patterns)

Search the project for existing design context:

- **Existing design system**: Look for theme files, design tokens, color constants, typography definitions
  - Search for: `theme`, `colors`, `palette`, `tokens`, `typography`, `fonts`, `spacing`
  - Check directories: `src/theme/`, `src/styles/`, `src/design/`, `lib/theme/`, `constants/`
  - Check files: `tailwind.config.*`, `theme.ts`, `colors.ts`, `tokens.json`
- **Component library**: Find existing reusable UI components
  - Search `src/components/`, `src/ui/`, `lib/components/`
  - Note naming conventions, prop patterns, variant systems
- **Navigation structure**: How is navigation currently implemented?
  - Search for router config, navigation setup, screen definitions
- **Styling approach**: What styling method is used?
  - CSS Modules, Tailwind, styled-components, StyleSheet (RN), ThemeData (Flutter)?
- **Existing screens**: Read 2-3 existing screens to understand layout patterns
- **Third-party UI libraries**: Check package.json/pubspec.yaml for MUI, Chakra, Radix, NativeBase, etc.
- **Asset patterns**: Where are images, icons, fonts stored? What icon library is used?

### Layer 2: Web (design trends and inspiration)

Search the web for design context relevant to this project:

- **Design trends**: Search for current design trends in the product's domain
  - "<product type> UI design 2026" / "<product type> app design inspiration"
- **Competitor analysis**: Search for similar products' UI approaches
  - "best <product type> app design" / "<competitor> UI"
- **Platform patterns**: Search for platform-specific design guidance
  - Flutter: Material 3 design guidelines, Cupertino patterns
  - React Native: iOS Human Interface Guidelines, Material Design
  - Web: Modern web design patterns, responsive design best practices
- **Typography trends**: Search for font pairing recommendations
  - "best font pairings for <aesthetic direction>" / "modern <tone> typography"
- **Color inspiration**: Search for color palette ideas
  - "color palette for <product type>" / "<tone> color schemes"

### Layer 3: Notes (prior design decisions)

Search local knowledge bases for prior design context:

- QMD: Search for design-related notes, UI decisions, color choices, component discussions
- claude-mem: Search for prior design sessions, aesthetic preferences, brand decisions

## Output

Save findings to /tmp/ui-designer-reconn-design.md using this format:

# Reconn: Design Context for <Idea>

## Summary
<2-3 sentence synthesis — what design context exists, what gaps need filling>

## Codebase Design Findings
- **Existing design system**: <what exists — theme files, tokens, colors>
- **Component library**: <reusable components found, naming patterns>
- **Styling approach**: <CSS method, utility classes, inline styles>
- **Navigation pattern**: <how navigation is structured>
- **Asset patterns**: <icon library, font loading, image management>
- **Constraints**: <limitations — locked-in libraries, legacy patterns>

## Web Design Findings
- **Design trends**: <current trends for this product type>
- **Competitor UI**: <what similar products look like>
- **Typography recommendations**: <font pairings that fit the aesthetic>
- **Color inspiration**: <palettes that match the direction>
- **Platform guidance**: <official platform design guidelines>

## Notes Findings
- **Prior decisions**: <relevant design decisions from past sessions>
- **Brand context**: <any brand guidelines or preferences recorded>

## Implications for Design System
<Actionable recommendations — what to build, what to extend, what to avoid>

Write completion signal to /tmp/ui-designer-result-reconn.json:
{"status": "done", "result": "/tmp/ui-designer-reconn-design.md"}
```

**Auto mode addition**: When in auto mode, add `mode: auto-extended` to produce a Synthetic Design Decision Document appended to the output:

```
## Synthetic Design Decision Document

⚠️ AUTO-INFERRED — These are assumptions based on codebase analysis and the user's prompt, NOT user-confirmed decisions.

### Aesthetic Direction
- <inferred from codebase patterns and user prompt>

### Screen List
- <inferred screens in priority order>

### Navigation Model
- <inferred from existing navigation setup>

### Design System Strategy
- <extend existing or create new, based on what was found>

### Assumptions
- <list of assumptions made — flag for user review>
```

### 2b. Wait for Reconn completion

Poll for `/tmp/ui-designer-result-reconn.json`. When complete:

1. Read the findings from `/tmp/ui-designer-reconn-design.md`
2. Validate findings are actionable
3. If Reconn failed: warn user, proceed without (design system will be created from scratch)

Update state: `phase: "DESIGN"`, `reconnFindings: "/tmp/ui-designer-reconn-design.md"`.

Display updated DESIGNER STATE.

## Phase 3: DESIGN — Create the Design System

**Goal**: Produce a complete, opinionated design system with tokens, palette, typography, and component definitions.

### 3a. Start visual companion

Start the visual companion server for iterative mockup review:

```bash
scripts/start-server.sh --project-dir <project>
```

The visual companion allows the Stylist to generate visual mockups and get iterative approval. If the server fails to start, proceed without — design system will be text-only specifications.

### 3b. Design thinking phase (mandatory)

Before dispatching Stylist, the Designer orchestrator performs a mandatory design thinking phase. This is NOT delegated — the Designer thinks through the design direction:

1. **Review all inputs**: Grill summary (or Scout context), Reconn findings, user prompt
2. **Synthesize aesthetic direction**: What specific visual identity will differentiate this product?
3. **Draft design brief**: 3-5 bullet points capturing the core design thesis
4. **Present to user**: Show the design brief and confirm direction before generating artifacts

Example design brief:
```
DESIGN BRIEF:
  1. Premium minimal aesthetic — generous whitespace, restrained color, intentional typography
  2. Dark-mode-first palette with warm neutrals (not pure black/white)
  3. Display font: geometric sans-serif with personality (not Inter/Roboto)
  4. Motion: subtle and purposeful — micro-interactions on key moments only
  5. Components: clean with rounded corners, glass-morphism for elevated surfaces
```

**Mode behavior:**
- `interactive`: present brief, wait for approval/adjustments
- `express`: present brief, wait for approval/adjustments
- `auto`: generate brief, proceed without pause

### 3c. Dispatch Stylist

Spawn Stylist agent (own cmux tab or in-process):

**Stylist task prompt:**
```
You are Stylist 🩵, a design system architect. Create a complete, opinionated design system for this project.

## Context

Idea: <user's idea description>
Platform: <detected platform>
Design Brief: <design brief from 3b>
Grill Summary: <contents of /tmp/ui-designer-grill-summary.md or Scout context>
Reconn Findings: <contents of /tmp/ui-designer-reconn-design.md>

## Your Task

Create the design system artifacts in `docs/design-system/`. Use the base template at ~/.claude/skills/ui-designer/templates/design-system-base.md as the structural guide.

**IMPORTANT**: Before generating, check if `docs/design-system/` already exists. If it does, READ and EXTEND rather than overwrite. Respect existing tokens, colors, and component patterns — evolve them, don't replace them.

### Required Artifacts

1. **tokens.json** — Machine-readable design tokens adapted to the detected platform
   - Colors: primary, secondary, accent, neutral scales (50-950), semantic colors, backgrounds, text, borders
   - Typography: font families (display, body, mono), font sizes, weights, line heights
   - Spacing: scale array with intentional rhythm
   - Radii: none through full
   - Shadows: sm through xl
   - Motion: durations and easings
   - Platform adaptation: CSS custom properties (web), JS/TS theme object (RN), Dart ThemeData (Flutter)

2. **color-palette.md** — Human-readable color documentation with rationale
   - Primary palette with swatches, hex values, and usage guidance
   - Rationale: WHY these specific colors? What emotion/association?
   - Contrast ratios: verify WCAG compliance for all text/background combos
   - Semantic colors: success, warning, error, info
   - Dark mode adaptation (if applicable)

3. **typography.md** — Font choices, type scale, and loading strategy
   - Display and body font with pairing rationale
   - Type scale from Display through Caption with sizes, weights, line heights, and usage
   - Font loading strategy per platform (Google Fonts CDN, bundled via expo-font, pubspec.yaml)

4. **components.md** — Component library using the component-library-template.md format
   - Component index with categories and variants
   - Full component spec for each: description, API, variants, sizes, states, usage examples, composition, platform notes, tokens used
   - Composition patterns: how components combine (form layouts, card grids, nav + content)
   - Use the template at ~/.claude/skills/ui-designer/templates/component-library-template.md for each entry

### Design Principles (MUST follow)

**Typography:**
- Choose fonts with CHARACTER — not Inter, Roboto, Arial, or system defaults
- Display font should be distinctive and memorable
- Body font should be highly readable and pair well with display
- The font pairing should convey the brand personality

**Color:**
- Palette must have a strong point of view — not generic purple-on-white or blue-on-grey
- Primary color should be immediately recognizable and associated with the product
- Generate full scales (50-950) for all named colors
- Verify WCAG AA contrast for all text/background combinations
- Consider dark mode from the start (not inverted — re-balanced)

**Spatial Composition:**
- Spacing scale should create intentional rhythm
- Generous whitespace is premium — cramped is amateur
- Layout proportions should follow a mathematical basis (4px grid, golden ratio, etc.)

**Motion:**
- Purposeful, not decorative — every animation communicates state change
- Fast by default (200-300ms), slow only for emphasis (500ms max)
- Physics-based easings for natural feel
- Always respect reduced motion preferences

**Components:**
- Each component should reflect the aesthetic direction
- Components should NOT be cookie-cutter Material/Bootstrap defaults
- States (hover, pressed, focused, disabled, loading) must all be designed
- Touch targets: 44pt minimum (iOS), 48dp minimum (Android)

### Anti-Slop Checklist

Before finalizing, verify:
- [ ] Fonts are distinctive and characterful (NOT Inter, Roboto, Arial, system defaults)
- [ ] Color palette has a strong point of view (NOT generic purple-on-white)
- [ ] Spacing scale creates intentional rhythm (NOT default Tailwind/Material)
- [ ] Component designs reflect the aesthetic direction (NOT cookie-cutter)
- [ ] The overall system feels cohesive and memorable
- [ ] This design system could NOT be confused with any other project's

### Visual Companion Integration

If the visual companion server is running, use it to generate visual mockups of:
- Color palette swatches (all scales)
- Typography specimens (all levels)
- Component gallery (key components in all states)

Present these for iterative approval.

### Output

Write all artifacts to `docs/design-system/`:
- `docs/design-system/tokens.json`
- `docs/design-system/color-palette.md`
- `docs/design-system/typography.md`
- `docs/design-system/components.md`

On completion, write to /tmp/ui-designer-result-stylist.json:
{"status": "done", "result": "docs/design-system/"}
```

### 3d. Approval gate

When Stylist completes, present the design system summary to the user:
- Color palette overview (primary, secondary, accent colors with hex values)
- Typography choices (display + body font pairing)
- Component count and categories
- Visual companion mockups if available

Ask:
> "Here's the design system. Does the aesthetic direction feel right? Any changes before we proceed to screen specs?"

**Mode behavior:**
- `interactive`: wait for explicit approval, iterate if needed
- `express`: wait for explicit approval, iterate if needed
- `auto`: auto-approved, continue

If user requests changes: dispatch Stylist again with the feedback appended to the task prompt. Max 3 iterations before asking user to be more specific.

Update state: `phase: "SPEC"`, `designSystem: "docs/design-system/"`.

Display updated DESIGNER STATE.

## Phase 4: SPEC — Screen-by-Screen Specifications

**Goal**: Produce detailed specifications with visual mockups for every screen in the design.

### 4a. Dispatch Specifier

Spawn Specifier agent (own cmux tab or in-process):

**Specifier task prompt:**
```
You are Specifier 🟪, a screen specification writer. Create detailed specs with visual mockups for every screen in the design.

## Context

Idea: <user's idea description>
Platform: <detected platform>
Screen list (priority order): <from grill summary or user description>
Design System: <path to docs/design-system/>
Grill Summary: <contents of /tmp/ui-designer-grill-summary.md or Scout context>
Reconn Findings: <contents of /tmp/ui-designer-reconn-design.md>

## Your Task

Create screen-by-screen specifications in `docs/design-specs/`. Use the screen spec template at ~/.claude/skills/ui-designer/templates/screen-spec-template.md as the structural guide.

### For Each Screen

Create `docs/design-specs/{screen-name}.md` with:

1. **Overview** — Purpose, flow position (previous → this → next), priority
2. **Layout** — Structure (header, main, footer), grid/layout system, visual hierarchy
3. **Components Used** — Table of components with variants, props, and design system references
4. **States** — Full state coverage:
   - Empty state: visual description + CTA + mockup
   - Loading state: pattern + duration handling + mockup
   - Populated state: normal view + mockup
   - Error state: type + recovery + mockup
   - Edge cases: single item, overflow, offline
5. **Interactions** — Gestures (mobile), transitions (animation, duration, easing), micro-interactions
6. **Responsive Behavior** — Breakpoint table with layout changes (web only)
7. **Accessibility** — Focus order, screen reader labels, contrast, keyboard navigation, reduced motion
8. **Screenshots** — Mockup paths for all states

### Visual Companion Integration

If the visual companion server is running, use it to generate mockups for each screen:
- `docs/design-specs/screenshots/{screen-name}-mockup.png` — populated state
- `docs/design-specs/screenshots/{screen-name}-empty-mockup.png` — empty state
- `docs/design-specs/screenshots/{screen-name}-loading-mockup.png` — loading state
- `docs/design-specs/screenshots/{screen-name}-error-mockup.png` — error state

Present each screen for approval before moving to the next.

### Screen Design Order

Design screens in priority order (from the grill/context):
1. **Hero screen first** — the screen that defines the product's visual identity
2. **Primary flow screens** — screens in the main user journey
3. **Secondary screens** — supporting views, settings, etc.

The hero screen sets the aesthetic standard. All subsequent screens must maintain visual coherence with it.

### Design Principles (reference from design system)

- Read `docs/design-system/tokens.json` for all spacing, color, and typography tokens
- Read `docs/design-system/components.md` for available component vocabulary
- Use design system tokens exclusively — NO magic numbers
- Maintain visual hierarchy: what draws the eye first, second, third?
- Ensure spatial composition creates breathing room — never cramped
- Follow the Anti-Slop rules from the design system

### Platform-Specific Considerations

**Flutter:**
- Use Material 3 layout patterns with AppBar, NavigationBar, etc.
- Reference ThemeData tokens from design system
- Consider platform-adaptive widgets (Material vs Cupertino)
- Include safe area handling for notches and system bars

**React Native / Expo:**
- Use SafeAreaView and platform-specific spacing
- Reference theme object tokens from design system
- Consider iOS vs Android navigation patterns (back gesture vs back button)
- Include keyboard avoidance for input screens

**Next.js / React (Web):**
- Use responsive grid with breakpoints from design system
- Reference CSS custom properties from tokens
- Include keyboard navigation and focus management
- Consider SSR implications for loading states

**Web (vanilla):**
- Use semantic HTML with CSS custom properties
- Progressive enhancement for older browsers
- Accessible by default (ARIA where needed)

### Output

Write all specs to `docs/design-specs/`:
- `docs/design-specs/{screen-name}.md` — one per screen
- `docs/design-specs/screenshots/` — mockup images
- `docs/design-specs/flow.md` — navigation flow diagram (text-based)

On completion, write to /tmp/ui-designer-result-specifier.json:
{"status": "done", "result": "docs/design-specs/", "screens": ["<list of screen names>"]}
```

### 4b. Per-screen approval

In interactive and express modes, the Specifier presents each screen for approval:

1. Show screen spec summary (layout, key components, state count)
2. Show mockup if visual companion is active
3. Ask: "Does this screen look right? Any changes?"
4. If changes requested: iterate on that screen before moving to next
5. Max 3 iterations per screen before asking user to accept or defer

**Mode behavior:**
- `interactive`: per-screen approval — pause after each screen
- `express`: per-screen approval — pause after each screen
- `auto`: auto-approved, all screens generated in sequence

### 4c. Completion

When all screens are specified:

1. Present screen summary table:
```
SCREENS COMPLETE:
  1. Dashboard (hero) — 4 states, 12 components
  2. Profile — 3 states, 8 components
  3. Settings — 2 states, 6 components
  Total: 3 screens, 9 states, 26 component usages
```

2. Write navigation flow document (`docs/design-specs/flow.md`)

Update state: `phase: "VERIFY"`, `screenSpecs: [<list of spec paths>]`.

Display updated DESIGNER STATE.

## Phase 5: VERIFY — Visual Verification

**Goal**: Capture mockups and (if build exists) compare them against the actual implementation.

### 5a. Determine verification mode

Inspector has two modes:

1. **Design capture only** — when no build exists yet (pre-implementation). Captures and validates design mockups against the spec.
2. **Build comparison** — when implementation exists (post-build or `/ui-designer verify`). Captures build screenshots and compares against design mockups.

Check for build existence:
```bash
# Web
ls .next/ build/ dist/ 2>/dev/null
# React Native
ls ios/build/ android/app/build/ 2>/dev/null
# Flutter
ls build/ 2>/dev/null
```

### 5b. Dispatch Inspector (design capture mode)

Spawn Inspector agent (own cmux tab or in-process):

**Inspector task prompt (design capture):**
```
You are Inspector 🔍, a visual verification agent. Capture and validate design mockups against the screen specifications.

## Context

Platform: <detected platform>
Design System: <path to docs/design-system/>
Screen Specs: <paths to docs/design-specs/*.md>

## Your Task — Design Capture Mode

Validate that the design mockups in `docs/design-specs/screenshots/` are complete and consistent with the specifications.

### Verification Checklist (per screen)

For each screen in docs/design-specs/:

1. **Mockup exists**: Verify screenshots exist for all states (populated, empty, loading, error)
2. **Component coverage**: Cross-reference components listed in the spec with what appears in the mockup
3. **Token compliance**: Verify mockup uses design system tokens (spot-check colors, spacing, typography)
4. **State coverage**: Confirm all states from the spec have corresponding mockups
5. **Accessibility**: Verify contrast ratios in mockups meet WCAG targets from the design system
6. **Platform fidelity**: Verify mockup follows platform conventions (safe areas, nav patterns, system bars)

### Visual Companion Integration

If the visual companion server is running, use it to:
- Render each screen spec as a visual mockup
- Compare rendered mockup against any existing screenshots
- Flag discrepancies between spec text and visual output

### Playwright MCP Integration

If Playwright MCP is available, use it to:
- Capture screenshots of the visual companion renders
- Run automated visual regression checks
- Generate comparison images (spec vs render)

### Output

Write verification report to `docs/design-specs/verify-report.md`:

# Design Verification Report

## Summary
- Total screens: <N>
- Screens verified: <N>
- Issues found: <N>
- Status: PASS / FAIL / WARN

## Per-Screen Results

### <Screen Name>
- States covered: [populated, empty, loading, error] ✅/❌
- Component coverage: <N>/<N> ✅/❌
- Token compliance: ✅/❌ (notes)
- Accessibility: ✅/❌ (contrast issues)
- Platform fidelity: ✅/❌ (notes)
- Issues: <list of issues found>

## Action Items
<numbered list of issues to fix before handoff>

Write completion signal to /tmp/ui-designer-result-inspector.json:
{"status": "done", "result": "docs/design-specs/verify-report.md", "mode": "design-capture", "pass": true/false}
```

### 5c. Dispatch Inspector (build comparison mode)

Used when implementation exists — either post-build or via `/ui-designer verify`:

**Inspector task prompt (build comparison):**
```
You are Inspector 🔍, a visual verification agent. Compare the built implementation against the design mockups.

## Context

Platform: <detected platform>
Design System: <path to docs/design-system/>
Screen Specs: <paths to docs/design-specs/*.md>
Design Mockups: <paths to docs/design-specs/screenshots/>
Build path: <detected build path>

## Your Task — Build Comparison Mode

Capture screenshots of the running build and compare them pixel-by-pixel against the design mockups.

### Step 1: Start the build (if not running)

```bash
# Web (Next.js / React)
npm run dev &
sleep 5

# Flutter
flutter run -d chrome &  # or flutter run -d <device>
sleep 10

# React Native (Expo)
npx expo start --web &  # web preview for screenshot comparison
sleep 5
```

### Step 2: Capture build screenshots via Playwright MCP

Use the Playwright MCP tools to navigate and screenshot each screen:

For each screen in the spec:
1. Navigate to the screen URL/route
2. Wait for content to load (wait for selectors from the spec)
3. Capture full-page screenshot → `docs/design-specs/screenshots/{screen-name}-build.png`
4. Capture viewport screenshot → `docs/design-specs/screenshots/{screen-name}-build-viewport.png`
5. If states are testable (empty, error): trigger them and capture screenshots

### Step 3: Visual comparison

For each screen, perform two types of comparison:

**LLM-based comparison:**
Read the design mockup and build screenshot side by side. Evaluate:
- Layout fidelity: Are elements positioned correctly? Same visual hierarchy?
- Color accuracy: Do colors match the design system tokens?
- Typography: Correct fonts, sizes, weights, line heights?
- Spacing: Is spacing consistent with the design system's rhythm?
- Component rendering: Do components match the spec'd variants and states?
- Responsive behavior: Does the layout adapt correctly at different viewports?

**Pixel-diff (if available):**
If image comparison tools are available:
- Generate a pixel diff image showing differences
- Calculate diff percentage (< 5% is acceptable, 5-15% needs review, > 15% is a fail)

### Step 4: Generate comparison report

For each screen, classify as:
- **MATCH** — build faithfully represents the design (< 5% diff or LLM confirms match)
- **CLOSE** — minor differences that may be acceptable (5-15% diff or LLM notes minor issues)
- **MISMATCH** — significant differences that need fixing (> 15% diff or LLM flags major issues)

### Output

Write comparison report to `docs/design-specs/build-comparison.md`:

# Build Comparison Report

## Summary
- Total screens: <N>
- MATCH: <N>
- CLOSE: <N>
- MISMATCH: <N>
- Overall: PASS / NEEDS REVIEW / FAIL

## Per-Screen Comparison

### <Screen Name>
- Status: MATCH / CLOSE / MISMATCH
- Design mockup: `screenshots/{screen-name}-mockup.png`
- Build capture: `screenshots/{screen-name}-build.png`
- **Layout**: ✅ / ⚠️ / ❌ — <notes>
- **Colors**: ✅ / ⚠️ / ❌ — <notes>
- **Typography**: ✅ / ⚠️ / ❌ — <notes>
- **Spacing**: ✅ / ⚠️ / ❌ — <notes>
- **Components**: ✅ / ⚠️ / ❌ — <notes>
- **Issues**: <specific issues to fix>

## Fix List
<numbered list of fixes, ordered by severity>

Write completion signal to /tmp/ui-designer-result-inspector.json:
{"status": "done", "result": "docs/design-specs/build-comparison.md", "mode": "build-comparison", "pass": true/false, "matches": <N>, "close": <N>, "mismatches": <N>}
```

### 5d. VERIFY approval gate

**This gate is MANDATORY in all modes, including auto.**

Present the Inspector's findings:
- Overall pass/fail status
- Per-screen results summary
- List of issues found (if any)
- Visual comparison mockups if available

Ask:
> "Inspector has completed verification. [N issues found / All checks passed]. Review the report and confirm whether to proceed to handoff, or fix issues first."

If issues exist and user wants fixes:
- Return to the relevant phase (DESIGN for token issues, SPEC for layout issues)
- Re-run Inspector after fixes

**Auto mode rationale**: This is the ONE gate that auto mode cannot skip. Visual design quality is subjective and requires human judgment. The Inspector provides objective checks (component coverage, contrast ratios, pixel diff) but the user must confirm the result looks and feels right.

Update state: `phase: "HANDOFF"`, `verifyResults: "<report path>"`.

Display updated DESIGNER STATE.

## Phase 6: HANDOFF — Package and Deliver

**Goal**: Package all design artifacts, create GitHub issues for implementation, and complete the pipeline.

### 6a. Write project-level state file

Write `.designer-state.json` to the project root. This file persists across sessions and allows Scout (or any agent) to understand the design state:

```json
{
  "version": "1.0",
  "completedAt": "<ISO timestamp>",
  "platform": "<detected platform>",
  "aestheticDirection": "<from design brief>",
  "designSystem": "docs/design-system/",
  "screenSpecs": "docs/design-specs/",
  "verifyReport": "docs/design-specs/verify-report.md",
  "screens": [
    {
      "name": "<screen name>",
      "spec": "docs/design-specs/<screen-name>.md",
      "mockup": "docs/design-specs/screenshots/<screen-name>-mockup.png",
      "priority": "<primary | secondary | tertiary>",
      "status": "designed"
    }
  ],
  "designTokens": "docs/design-system/tokens.json",
  "fonts": {
    "display": "<font name>",
    "body": "<font name>"
  },
  "colorPrimary": "<primary color hex>"
}
```

### 6b. Create GitHub issues (one per screen)

For each screen in the spec, create a GitHub issue for implementation:

```bash
gh issue create --title "Implement <Screen Name> screen" --body "$(cat <<'EOF'
## Design Spec

See `docs/design-specs/<screen-name>.md` for the full specification.

## Mockup

See `docs/design-specs/screenshots/<screen-name>-mockup.png`

## Design System

All design tokens are in `docs/design-system/tokens.json`. Components are documented in `docs/design-system/components.md`.

## Acceptance Criteria

- [ ] Layout matches the spec's structure section
- [ ] All components use the correct variants from the design system
- [ ] All 4 states implemented: populated, empty, loading, error
- [ ] Interactions match the spec (gestures, transitions, micro-interactions)
- [ ] Accessibility requirements met (focus order, screen reader labels, contrast)
- [ ] Responsive behavior matches breakpoint table (web only)
- [ ] Visual comparison against mockup passes Inspector verification

## Priority

<primary | secondary | tertiary>

🎨 Generated with Claude Code /ui-designer
EOF
)"
```

**Mode behavior:**
- `interactive`: show issue list, ask for approval before creating
- `express`: auto-create issues
- `auto`: auto-create issues

### 6c. Final summary

Display the final summary:

```
DESIGNER COMPLETE

Idea: <original idea>
Platform: <detected platform>
Aesthetic: <aesthetic direction summary>

Design System: docs/design-system/
  - tokens.json (machine-readable tokens)
  - color-palette.md (palette with rationale)
  - typography.md (fonts + type scale)
  - components.md (component library)

Screen Specs: docs/design-specs/
  1. <Screen Name> — docs/design-specs/<screen-name>.md
  2. <Screen Name> — docs/design-specs/<screen-name>.md
  ...

Verification: <PASS | NEEDS REVIEW | FAIL>
  Report: docs/design-specs/verify-report.md

GitHub Issues: #A, #B, #C (one per screen)

Project State: .designer-state.json (for Scout integration)
```

Update state: `phase: "COMPLETE"`.

Display final DESIGNER STATE.

## Scout Integration

### Scout → Designer dispatch

When Scout detects UI-heavy features in its PRD (many screens, design system needed, visual requirements), it dispatches the Designer as a peer agent.

Scout writes a context file before dispatching:

```json
// /tmp/ui-designer-context.json
{
  "source": "scout",
  "scoutState": "/tmp/scout-state.json",
  "prdIssue": "<GitHub issue number>",
  "grillSummary": "/tmp/scout-grill-summary.md",
  "reconnFindings": "/tmp/scout-reconn-initial.md",
  "platform": {
    "flutter": false,
    "reactNative": true,
    "expo": true,
    "nextjs": false,
    "react": false,
    "web": false
  },
  "screens": ["<screen list from PRD>"],
  "aestheticHints": "<any aesthetic notes from the grill>",
  "callback": "/tmp/scout-result-designer.json"
}
```

When Designer detects this context file on startup:
1. Skip platform detection (inherit from Scout)
2. Skip grill (use Scout's grill summary — run in express mode)
3. Skip initial Reconn (use Scout's Reconn findings, extend with design focus)
4. Proceed directly to DESIGN phase with inherited context

### Post-build verification callback

After Scout's Builder agents implement the screens, Scout can invoke `/ui-designer verify` to run the Inspector in build comparison mode. The flow:

1. Scout completes EXECUTE phase — all screens are built
2. Scout dispatches Designer with `verify` argument
3. Designer runs Inspector in build comparison mode
4. Inspector compares build screenshots against design mockups
5. Designer writes result to Scout's callback file:

```json
// /tmp/scout-result-designer.json
{
  "status": "done",
  "mode": "verify",
  "result": "docs/design-specs/build-comparison.md",
  "pass": true,
  "matches": 5,
  "close": 1,
  "mismatches": 0
}
```

6. Scout reads the result and reports to user

### Communication via state file polling

Scout and Designer communicate through file-based polling:
- Scout writes `/tmp/ui-designer-context.json` → Designer reads on startup
- Designer writes `/tmp/scout-result-designer.json` → Scout polls for completion
- Designer reads `/tmp/scout-state.json` for Scout's current phase context
- Both read `/tmp/ui-designer-state.json` for Designer's current phase

### Designer as peer agent

Designer is a peer to Scout, not a subordinate. When dispatched by Scout:
- Designer manages its own phase pipeline independently
- Designer controls its own agent roster (Stylist, Specifier, Inspector)
- Designer makes design decisions autonomously (within the approved aesthetic direction)
- Scout waits for Designer to complete before proceeding (or runs in parallel with non-UI issues)

## Frontend Aesthetics Guidelines

These guidelines are injected into every design-producing agent (Stylist, Specifier) and inform the anti-slop enforcement rules.

### Core Principles

#### Typography

Typography is the single strongest signal of design quality. It communicates brand personality before a user reads a single word.

**Rules:**
- Display fonts MUST have character — geometric sans-serifs (Satoshi, General Sans, Cabinet Grotesk), refined serifs (Fraunces, Playfair Display), or distinctive options (Space Grotesk, Clash Display)
- NEVER use Inter, Roboto, Arial, Helvetica, or system-ui as a design choice (they are fallbacks, not choices)
- Body fonts must prioritize readability at 14-18px while maintaining personality
- Font pairings should create tension (serif + sans-serif) or harmony (geometric + geometric from different families)
- Type scale must follow a consistent ratio (1.2 minor third, 1.25 major second, 1.333 perfect fourth)
- Letter-spacing adjustments: tighten display sizes (-0.02em to -0.04em), leave body at default, widen small caps (+0.05em to +0.1em)

#### Color

Color creates emotional response and brand recognition faster than any other design element.

**Rules:**
- Every palette needs a strong primary with a clear emotional association
- Avoid "safe" generic palettes: purple-on-white, blue-on-grey, teal-gradient-everything
- Build full scales (50-950) using perceptual color spaces (OKLab/OKLCH) for consistent lightness steps
- Semantic colors (success, warning, error, info) must be distinct from brand palette — users learn their meaning
- Dark mode is NOT just inverted colors — re-balance the palette for dark backgrounds (reduce saturation, shift hue, use elevated surfaces instead of borders)
- Consider color blindness: never use red/green as the only differentiator

#### Motion

Motion communicates state changes and spatial relationships. It should feel natural, not decorative.

**Rules:**
- Default duration: 200-300ms for most transitions (perceivable but not slow)
- Entrance animations: 300ms with ease-out (element arriving)
- Exit animations: 200ms with ease-in (element leaving — faster because users are done with it)
- Never exceed 500ms for any UI transition (loading animations excluded)
- Use physics-based easings for natural feel: cubic-bezier(0.4, 0, 0.2, 1) as default
- Spring animations for interactive elements (drag, swipe, pull-to-refresh)
- ALWAYS provide reduced-motion alternatives (instant state change, no animation)
- Stagger related items: 50-100ms delay between list items entering

#### Spatial Composition

Whitespace is not empty space — it is a design element that creates hierarchy, breathing room, and focus.

**Rules:**
- Use a 4px base grid for all spacing (4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80)
- Section spacing should be significantly larger than element spacing (48-80px between sections, 8-16px between elements)
- Padding inside containers: generous (16-24px minimum, 32-48px for cards and panels)
- Touch targets: 44pt minimum (iOS), 48dp minimum (Android), 36px minimum (web buttons)
- Visual hierarchy through spacing: more important elements get more breathing room
- Never let content touch container edges — always maintain inner padding

#### Backgrounds

Backgrounds set the stage for all content. They should have depth without distraction.

**Rules:**
- Solid backgrounds are fine — not everything needs a gradient
- If using gradients: subtle (5-10% lightness change), not rainbow multi-stop
- Glass-morphism (blur + transparency) is powerful for elevated surfaces but expensive on mobile — use sparingly
- Dark backgrounds: use off-black (#0A0A0A to #1A1A1A), never pure #000000
- Light backgrounds: use warm whites (#FAFAF8, #F5F5F0), never pure #FFFFFF
- Noise/grain textures can add depth to flat backgrounds — 2-5% opacity maximum
- Background patterns should be subtle enough to ignore when reading content

### Anti-Slop Enforcement (Hard Rules)

These rules are non-negotiable. If a design violates any of these, it MUST be revised before approval.

1. **No default fonts** — Inter, Roboto, Arial, Helvetica, system-ui, and sans-serif are NOT acceptable as intentional design choices. They may appear in fallback chains only.

2. **No generic palettes** — If the color palette could belong to any SaaS product, it is not distinctive enough. The palette must reflect THIS product's personality.

3. **No cookie-cutter components** — If a component looks identical to Bootstrap, Material UI, or Chakra defaults, it has not been designed. Components must reflect the project's aesthetic.

4. **No gratuitous gradients** — Gradients must serve a purpose (depth, hierarchy, brand). Rainbow gradients, multicolor backgrounds, and gradient-for-the-sake-of-gradient are banned.

5. **No spacing by vibes** — All spacing values must reference the design system's spacing scale. No magic numbers, no "looks about right."

6. **No decoration without function** — Every visual element must serve a purpose: hierarchy, navigation, state indication, brand expression, or delight at a key moment. Purely decorative elements are visual noise.

7. **No accessibility afterthought** — Contrast ratios, focus indicators, touch targets, and screen reader labels are designed in, not bolted on.

### Platform-Specific Adaptation

The same aesthetic direction manifests differently on each platform:

**Flutter:**
- Material 3 provides the structural foundation — customize aggressively with ThemeData
- Cupertino widgets for iOS-specific patterns (date picker, action sheet)
- Use SliverAppBar for rich scrolling effects
- ColorScheme.fromSeed can be extended, not just used as-is

**React Native / Expo:**
- Platform.select for iOS vs Android visual differences
- SafeAreaView for notch handling — design around safe areas, not despite them
- React Navigation provides structural patterns — customize with theme object
- Reanimated for 60fps+ animations on the UI thread

**Next.js / React (Web):**
- CSS custom properties for runtime theming
- Tailwind utility classes reference design tokens — configure tailwind.config.js from tokens.json
- next/font for optimal font loading (no FOUT)
- Framer Motion or CSS transitions for smooth animations

**Web (vanilla):**
- CSS custom properties for theming
- @font-face with font-display: swap
- CSS transitions and keyframe animations
- Progressive enhancement — core experience works without JS

### Complexity Matching

The design's visual complexity should match the product's functional complexity:

| Product Type | Complexity | Design Approach |
|-------------|------------|-----------------|
| Single-purpose tool | Low | Minimal — let the function breathe |
| Consumer app | Medium | Personality-forward — delight and brand expression |
| Dashboard / Admin | High | Information-dense — clear hierarchy, restrained decoration |
| Creative tool | High | Canvas-focused — UI fades to support content creation |
| E-commerce | Medium-High | Product-forward — UI supports the merchandise |
| Social platform | Medium | Content-first — UI is the stage, not the performer |

## Failure & Recovery

### Stylist failures

```
Attempt 1: Stylist produces design system
If failed or rejected: retry once with feedback in the prompt
If retry fails: report error, ask user to provide aesthetic direction manually
```

### Specifier failures

```
Attempt 1: Specifier produces screen specs
If failed on specific screen: retry that screen only
If entire spec fails: retry once with simplified scope (hero screen only first)
If retry fails: report error, ask user to reduce scope or adjust design system
```

### Reconn failures

```
If Reconn fails to complete: warn user, proceed without research context
Design system will be created from scratch (no codebase integration)
Flag this in the verify report — Inspector should check for consistency with existing code
```

### Inspector failures

```
If Inspector cannot start build: report, suggest manual screenshot comparison
If Playwright MCP unavailable: fall back to LLM-only comparison (read mockup + spec)
If visual companion unavailable: fall back to spec-only verification (text checks only)
Report all fallbacks in the verify report
```

### Crash recovery from state file

If Designer is re-invoked and `/tmp/ui-designer-state.json` has a non-COMPLETE phase:

1. Read the state file
2. Report what phase was in progress and what artifacts exist
3. Ask user: resume or start over?
4. If resuming: skip completed phases, pick up from last incomplete
   - GRILL complete → skip to RECONN
   - RECONN complete → skip to DESIGN
   - DESIGN complete → skip to SPEC
   - SPEC complete → skip to VERIFY
   - VERIFY complete → skip to HANDOFF
5. Validate existing artifacts before resuming (read files, confirm they exist and are non-empty)

## Teardown

### Normal completion

1. Update all agent tab statuses to final (checkmark for success, X for failure)
```bash
cmux set-status --surface "$STYLIST_SURFACE" --icon "✅" --color "#16A34A"
cmux set-status --surface "$SPECIFIER_SURFACE" --icon "✅" --color "#16A34A"
cmux set-status --surface "$INSPECTOR_SURFACE" --icon "✅" --color "#16A34A"
cmux set-status --surface "$RECONN_SURFACE" --icon "✅" --color "#16A34A"
```

2. Close agent tabs (Reconn, Stylist, Specifier, Inspector)
```bash
cmux close-surface --surface "$RECONN_SURFACE" 2>/dev/null
cmux close-surface --surface "$STYLIST_SURFACE" 2>/dev/null
cmux close-surface --surface "$SPECIFIER_SURFACE" 2>/dev/null
cmux close-surface --surface "$INSPECTOR_SURFACE" 2>/dev/null
```

3. Clean up temporary files
```bash
rm -f /tmp/ui-designer-task-*.md
rm -f /tmp/ui-designer-result-*.json
rm -f /tmp/ui-designer-grill-scope.json
```

4. Preserve state and output files for reference
- `/tmp/ui-designer-state.json` — session state (preserved for crash recovery)
- `/tmp/ui-designer-grill-summary.md` — grill results (preserved for re-runs)
- `/tmp/ui-designer-reconn-design.md` — research findings (preserved for reference)
- `.designer-state.json` — project-level state (permanent, for Scout integration)
- `docs/design-system/` — design system artifacts (permanent)
- `docs/design-specs/` — screen specifications and mockups (permanent)

5. Display final summary (see Phase 6: HANDOFF section)

### Interrupted session

If the user interrupts mid-pipeline (Ctrl+C, closes terminal, etc.):
- State file at `/tmp/ui-designer-state.json` captures last known phase
- All artifacts written to disk so far are preserved
- On next invocation, Designer offers to resume from last phase

## Key Constraints

- **You are the orchestrator, not the designer** — dispatch agents for all design work
- **Griller runs in Designer's tab** — it needs user Q&A, never gets its own tab
- **Never skip the VERIFY gate** (even in auto mode) — visual design requires human judgment
- **Carry context forward** — every agent gets full accumulated context from prior phases
- **User can bail at any gate** — wrap up cleanly with what's produced so far
- **One phase at a time** — phases are sequential, never parallel (except mid-grill Reconn trigger)
- **Report state at transitions** — always show DESIGNER STATE between phases
- **Research before design** — Reconn runs before Stylist, never after
- **Anti-slop is non-negotiable** — if a design violates the hard rules, it must be revised
- **Design tokens are the source of truth** — no magic numbers in screen specs
- **Platform awareness is mandatory** — every design decision considers the target platform
