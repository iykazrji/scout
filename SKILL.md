---
name: scout
description: End-to-end feature orchestrator — grills the user on their idea, writes a PRD, breaks it into issues, and executes them with verified PRs. Supports cmux tab mode and autonomous execution. Use when user wants to go from idea to implementation, says "scout this", or wants the full product development pipeline.
---

# /scout - Idea-to-Implementation Orchestrator

Takes a raw idea and drives it through interrogation, PRD creation, issue breakdown, and parallel execution — producing verified PRs. Manages a roster of named, color-coded agents.

## When to Use
- User says "/scout" or "scout this" — starts the pipeline with a prompt
- `/scout settings` — opens interactive settings menu
- `/scout --auto` or `/scout --yolo` — starts with that mode override
- User has an idea and wants to go from concept to shipped code

## Agent Roster

| Agent | Color | Hex | Icon | Role | Own Tab? |
|-------|-------|-----|------|------|----------|
| **Scout** | Orange | `#FF8C00` | 🟠 | Orchestrator — manages phases, state, handoffs, user interaction | Original tab |
| **Griller** | Red | `#DC2626` | 🔴 | Interviews user via `/scout:grill-me` protocol | No — runs in Scout tab |
| **Reconn** | Yellow | `#EAB308` | 🟡 | Deep research — codebase, web, QMD, claude-mem | Yes (cmux only) |
| **Architect** | Blue | `#2563EB` | 🔵 | Writes PRD via `/scout:write-a-prd` | Yes (cmux only) |
| **Slicer** | Purple | `#7C3AED` | 🟣 | Breaks PRD into issues via `/scout:prd-to-issues` | Yes (cmux only) |
| **Builder-N** | Green | `#16A34A` | 🟢 | Executes issues — one per parallel issue | Yes (cmux only) |
| **Designer** | Pink | `#EC4899` | 🩷 | UI design orchestrator — dispatched for UI-heavy PRDs via `/scout:ui-designer` | Yes (cmux only) |
| **Bursar** | Amber | `#F59E0B` | 💰 | Token cost estimator — estimates implementation spend after PRD, presents budget options | No — runs in Scout tab |

## Settings

### Settings file: `~/.claude/skills/scout/settings.json`

Persistent settings that Scout reads on every startup. Defaults if file doesn't exist:

```json
{
  "quality": "balanced",
  "mode": "interactive",
  "cmux": "auto"
}
```

### `/scout:settings` — Interactive Settings Menu

Use `/scout:settings` to configure settings interactively. This is a separate sub-skill for fast invocation — see `settings.md`.

### Quality Profiles

Each profile maps agents to models via the Agent tool's `model` parameter:

| Agent | `high` | `balanced` | `budget` |
|-------|--------|------------|----------|
| **Scout** | opus | opus | sonnet |
| **Griller** | opus | opus | sonnet |
| **Reconn** | opus | sonnet | sonnet |
| **Architect** | opus | opus | sonnet |
| **Slicer** | opus | sonnet | sonnet |
| **Builder-N** | opus | sonnet | sonnet |
| **Bursar** | sonnet | sonnet | haiku |

When dispatching an agent via the Agent tool, pass the `model` parameter:
```
Agent tool call:
  model: "sonnet"  (or "opus" based on quality profile)
  subagent_type: "general-purpose"
  prompt: <agent task prompt>
```

### Execution Modes

| Behavior | `interactive` | `yolo` | `auto` |
|----------|--------------|--------|--------|
| Grill interview | Yes | Yes | Skipped |
| Grill approval gate | Yes | **Last checkpoint** — after this, hands-off | Skipped |
| PRD approval | Yes | Auto-approved | Auto-approved |
| Issue breakdown approval | Yes | Auto-approved | Auto-approved |
| HITL issues | Pause for user | Pause for user | Treated as AFK |
| Wave approval | Yes | Auto-approved | Auto-approved |
| Phase transition reports | Wait for input | Report status, continue | Report status, continue |

**`yolo` mode** is the sweet spot: you still get to shape the design through the grill, approve the decision summary, then Scout takes over and builds everything without further interruption. HITL issues still pause because they genuinely need human judgment.

## Startup Protocol

On `/scout` invocation:

### 1. Parse arguments and load settings

Read `~/.claude/skills/scout/settings.json` if it exists, otherwise use defaults.

Check for mode overrides in the user's prompt:
- `--auto` or "autonomously" → override mode to `auto`
- `--yolo` or "yolo mode" → override mode to `yolo`

For settings, use `/scout:settings` directly (separate sub-skill for fast invocation).

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
ls craco.config.js 2>/dev/null  # CRA with CRACO
grep -q '"react-router"' package.json 2>/dev/null  # Client-side routing
```
Set `react: true` if detected, or if the user's idea explicitly mentions React (without Next.js/RN context).

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

Note: Express and Fastify are backend frameworks — they can co-exist with frontend flags (e.g., a Next.js project may also have an Express API server, or a monorepo may have both).

Announce detected technology:
```
SCOUT [flutter: yes] — using /scout:flutter-expert + /scout:senior-architect for Flutter-aware agents
SCOUT [react-native: yes, expo: yes] — using /scout:react-native-best-practices + /scout:senior-architect + Expo skills
SCOUT [nextjs: yes] — using /scout:react-best-practices + /scout:senior-architect for Next.js-aware agents
SCOUT [react: yes] — using /scout:react-best-practices + /scout:senior-architect for React-aware agents
SCOUT [express: yes] — using /scout:expressjs-best-practices + /scout:senior-architect for Express-aware agents
SCOUT [fastify: yes] — using /scout:fastify-best-practices + /scout:senior-architect for Fastify-aware agents
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
SCOUT [cmux: active] — agents will spawn in dedicated tabs
```
or:
```
SCOUT [cmux: off] — agents will run in-process
```

### 4. Check for interrupted session

Check if `/tmp/scout-state.json` exists with a non-DONE phase:
- If found: report what was in progress, ask user to resume or start fresh
- If not found or DONE: proceed with new session

### 5. Initialize state

Write initial state to `/tmp/scout-state.json`:
```json
{
  "mode": "cmux",
  "phase": "GRILL",
  "auto": false,
  "flutter": false,
  "reactNative": false,
  "expo": false,
  "nextjs": false,
  "react": false,
  "express": false,
  "fastify": false,
  "idea": "<from user prompt>",
  "grillSummary": null,
  "prdIssue": null,
  "issues": [],
  "prs": [],
  "agents": {},
  "workspace": "<workspace ref or null>",
  "startedAt": "<ISO timestamp>"
}
```

Display initial state.

## cmux Tab Management

### Spawning an agent tab

```bash
# 1. Capture current workspace
CURRENT_WS=$(cmux current-workspace 2>&1 | awk '{print $1}')

# 2. Write agent task to file
cat > /tmp/scout-task-<agent>.md << 'EOF'
<task content>
EOF

# 3. Create new tab in current workspace
NEW_SURFACE=$(cmux new-surface --workspace "$CURRENT_WS" 2>&1 | awk '{print $2}')

# 4. Launch Claude in the tab
cmux send --surface "$NEW_SURFACE" "claude \"$(cat /tmp/scout-task-<agent>.md)\""
cmux send-key --surface "$NEW_SURFACE" enter

# 5. Name and color the tab
cmux rename-tab --surface "$NEW_SURFACE" "<Agent Name>"
cmux set-status --surface "$NEW_SURFACE" --icon "<icon>" --color "<hex>"
```

### Completion detection

Agents write result files on completion:
```bash
# Scout polls for this file
cat /tmp/scout-result-<agent>.json
# {"status": "done", "result": "/tmp/scout-<output>.md"}
# or {"status": "failed", "error": "..."}
```

### Tab status updates

On agent completion:
- Success: update tab icon to ✅
- Failure: update tab icon to ❌

```bash
cmux set-status --surface "$SURFACE" --icon "✅" --color "#16A34A"
```

### Non-cmux fallback

When cmux is not available, dispatch agents via the Agent tool:
- Use `subagent_type: "general-purpose"` for all agents
- Pass the full task prompt directly
- Agent tool returns results inline (no file polling needed)
- Parallel builders use multiple Agent tool calls in a single message

## Phase 1: GRILL — Interrogate the Idea

**Goal**: Turn a vague idea into a concrete design with all major decisions resolved.

### 1a. Capture the idea

Summarize the user's prompt back to confirm scope. If too vague, ask 1-2 clarifying questions.

### 1b. Dispatch Reconn (proactive research)

Spawn Reconn agent to research the codebase before grilling:

**Reconn task prompt:**
```
You are Reconn 🟡, a deep research agent. Research the following topic across codebase, web, and notes.

Topic: <user's idea — what parts of the codebase are relevant?>

Follow the /scout:reconn research protocol:
1. Search the codebase for relevant files, patterns, conventions (Grep, Glob, Read)
2. Search the web for relevant docs, APIs, best practices (WebSearch, WebFetch)
3. Search notes for prior decisions (QMD search, claude-mem search)
4. Synthesize findings into /tmp/scout-reconn-initial.md
5. Write completion signal to /tmp/scout-result-reconn.json

Output format: follow the Reconn output format (Summary, Codebase Findings, Web Findings, Notes Findings, Implications).
```

If auto mode: add `mode: auto-extended` to produce Synthetic Decision Document.

Wait for Reconn to complete. Read findings.

### 1c. Run Griller (in-process)

**Skip in auto mode** — use Reconn's Synthetic Decision Document instead.

Dispatch Griller as an IN-PROCESS subagent (NOT in a cmux tab — needs user Q&A):

**Griller task prompt:**
```
You are Griller 🔴, a relentless technical interviewer. Your job is to interrogate the user about their plan/design until EVERY decision branch is resolved.

## The Idea Under Review

<user's idea description>

## Codebase Research (from Reconn)

<contents of /tmp/scout-reconn-initial.md>

## Interview Protocol

Follow the /scout:grill-me protocol:
- Use the Decision Tree Method (identify decision, ask WHY, probe alternatives, find edges, resolve or flag)
- Work through categories: goals & constraints, architecture, data flow, error cases, scale, dependencies, sequencing, unknowns
- Ask 1-3 focused questions per turn via AskUserQuestion
- Track resolved vs open branches
- When done, produce a Decision Summary with all resolved decisions, open items, risks, and next steps

Save the Decision Summary to /tmp/scout-grill-summary.md when complete.
```

### 1d. Approval gate

Present the Decision Summary. Ask:
> "Are you happy with these decisions? Should we proceed to writing the PRD, or revisit any points?"

**Mode behavior:**
- `interactive`: wait for explicit approval
- `yolo`: wait for approval — **this is the last human checkpoint before full autonomy**
- `auto`: skip gate (grill was already skipped)

Update state: `phase: "PRD"`, `grillSummary: "/tmp/scout-grill-summary.md"`.

Display updated SCOUT STATE.

## Phase 2: PRD — Write the Requirements Document

**Goal**: Produce a PRD and submit it as a GitHub issue.

### 2a. Dispatch Reconn (validation)

Spawn fresh Reconn to validate prior findings against code:

**Reconn task prompt:**
```
You are Reconn 🟡. Validate and extend these findings for PRD writing.

Prior research: <path to /tmp/scout-reconn-initial.md>
Decision summary: <path to /tmp/scout-grill-summary.md>

Focus on: module boundaries, existing patterns the PRD should respect, technical constraints not yet identified.
Save findings to /tmp/scout-reconn-prd-validation.md
Write completion to /tmp/scout-result-reconn.json
```

### 2b. Dispatch Architect

Spawn Architect agent:

**Architect task prompt:**
```
You are Architect 🔵, a spec writer. Write a comprehensive PRD and submit it as a GitHub issue.

## Context

Original idea: <user's idea>
Decision Summary: <contents of /tmp/scout-grill-summary.md>
Codebase Research: <contents of /tmp/scout-reconn-prd-validation.md>

## Instructions

Follow the /scout:write-a-prd protocol with these adjustments:
- SKIP Step 1 (gathering description) — already have it above
- RUN Step 2 (explore repo) — validate against real code
- SKIP Step 3 (grill) — already done, decisions are above
- RUN Step 4 (sketch modules) — present to user via AskUserQuestion
- RUN Step 5 (write & submit PRD as GitHub issue)

The grill Decision Summary MUST be incorporated into the PRD sections (Edge Cases, Dependencies, Architecture).

Show the user the full PRD and get approval before creating the GitHub issue.

When done, write the issue number to /tmp/scout-result-architect.json:
{"status": "done", "prdIssue": <number>}
```

**`yolo` or `auto` mode**: Add "Auto-approve the PRD without user confirmation. Create the GitHub issue immediately."

### 2b½. Run Bursar (in-process cost estimate)

After the Architect completes the PRD, run the Bursar **in-process** (like Griller — it needs to present options to the user via AskUserQuestion).

**Bursar estimation model:**

The Bursar reads the PRD and estimates total token cost for the remaining phases (ISSUES → EXECUTE) based on the current quality profile.

**Step 1 — Analyze PRD complexity:**
- Read the PRD from the GitHub issue (`gh issue view <prdIssue>`)
- Count the number of distinct features / modules / screens described
- Classify each as: `trivial` (config change, copy update), `small` (single-file feature), `medium` (multi-file feature with tests), `large` (cross-cutting, new module, multi-service)
- Estimate the number of vertical-slice issues the Slicer will produce (typically 1 issue per feature/module, sometimes 2-3 for large ones)

**Step 2 — Estimate tokens per phase:**

Use these per-agent token baselines (based on observed Scout runs):

| Agent | Baseline Tokens (input+output) | Notes |
|-------|-------------------------------|-------|
| **Slicer** | ~50,000 | Reads PRD, explores codebase, creates issues |
| **Reconn** (per dispatch) | ~30,000 | Research before each wave |
| **Builder** (trivial issue) | ~40,000 | Simple change, minimal exploration |
| **Builder** (small issue) | ~80,000 | Single-file feature with tests |
| **Builder** (medium issue) | ~150,000 | Multi-file, needs exploration + testing |
| **Builder** (large issue) | ~250,000 | Cross-cutting, new patterns, heavy exploration |
| **Builder failure recovery** | ~60,000 | Extra Reconn + retry (assume 20% of builders need this) |
| **Designer** (if UI-heavy) | ~100,000 | Design specs + mockups |
| **Inspector** (if Designer used) | ~40,000 | Visual verification pass |

**Step 3 — Calculate cost:**

Token-to-dollar rates (per 1M tokens, as of model pricing):

| Model | Input (per 1M) | Output (per 1M) | Assume I/O ratio |
|-------|----------------|-----------------|------------------|
| `opus` | $15.00 | $75.00 | 70/30 |
| `sonnet` | $3.00 | $15.00 | 70/30 |
| `haiku` | $0.80 | $4.00 | 70/30 |

Map each agent to its model using the current quality profile, then compute:
```
agent_cost = total_tokens × (0.70 × input_rate + 0.30 × output_rate) / 1,000,000
```

Sum all agent costs for the total estimated spend.

Also compute what the cost would be under `budget` profile for comparison.

**Step 4 — Present to user via AskUserQuestion:**

Format the estimate as a clear table and present options:

```
💰 BURSAR — Estimated Implementation Cost

PRD: #<number> — <title>
Quality Profile: <current profile>
Estimated Issues: <N> (<breakdown by complexity>)

┌──────────────────────┬────────────┬──────────┐
│ Phase                │ Est. Tokens│ Est. Cost│
├──────────────────────┼────────────┼──────────┤
│ Slicer               │   50,000   │  $X.XX   │
│ Reconn (×N dispatches│   XX,000   │  $X.XX   │
│ Builders (×N issues) │  XXX,000   │  $XX.XX  │
│ Failure recovery (20%│   XX,000   │  $X.XX   │
│ Designer (if UI)     │  XXX,000   │  $X.XX   │
│ Inspector (if UI)    │   XX,000   │  $X.XX   │
├──────────────────────┼────────────┼──────────┤
│ TOTAL                │  XXX,000   │  $XX.XX  │
└──────────────────────┴────────────┴──────────┘

Budget mode alternative: ~$X.XX (saves ~XX%)

How would you like to proceed?

a) ✅ Proceed — continue with current quality profile
b) ✂️ Scale down — reduce scope to a subset of requirements (tell me which features to keep)
c) 💸 Budget mode — switch to budget profile to save on spend
d) ✂️+💸 Both — scale down AND switch to budget mode
```

**User response handling:**

- **a) Proceed**: Continue to 2c approval gate as normal
- **b) Scale down**: Ask user which features/modules to keep. Update the PRD issue with a comment noting the descoped items. Set `bursarDescoped: [<list of removed features>]` in state. The Slicer will only create issues for the kept features.
- **c) Budget mode**: Update `settings.json` to `"quality": "budget"`. Update scout state. Announce: `SCOUT [quality: budget] — switched to budget profile to reduce spend`. Continue to 2c.
- **d) Both**: Apply both b) and c).

Update state: `bursarEstimate: { totalTokens: N, totalCost: N, profile: "...", issueBreakdown: [...] }`.

Write estimate to `/tmp/scout-bursar-estimate.json` for reference.

**Mode behavior:**
- `interactive`: always run Bursar, wait for user choice
- `yolo`: run Bursar, show estimate, but auto-select (a) Proceed unless estimated cost exceeds $10 — then pause for user input
- `auto`: run Bursar silently, log estimate to `/tmp/scout-bursar-estimate.json`, auto-select (a) Proceed

### 2c. Approval gate

Confirm with user: "PRD created as issue #X. Ready to break it into implementation issues?"

**Mode behavior:**
- `interactive`: wait for explicit approval
- `yolo`: skip gate — auto-approved after grill
- `auto`: skip gate

Update state: `phase: "ISSUES"`, `prdIssue: <number>`.

Display updated SCOUT STATE.

### 2d. UI Detection — Dispatch Designer (optional)

After PRD is created, scan the PRD content for UI-heavy indicators:
- References to screens, views, pages, modals, or UI components
- Design requirements (colors, typography, layout, animations, responsive behavior)
- Frontend implementation tasks that would benefit from a design system

If UI-heavy:
1. Write context file to `/tmp/scout:ui-designer-context.json`:
```json
{
  "source": "scout",
  "scoutState": "/tmp/scout-state.json",
  "prdIssue": "<GitHub issue number>",
  "grillSummary": "/tmp/scout-grill-summary.md",
  "reconnFindings": "/tmp/scout-reconn-initial.md",
  "platform": { "<detected platform flags>" },
  "screens": ["<screen list from PRD>"],
  "aestheticHints": "<any aesthetic notes from the grill>",
  "callback": "/tmp/scout-result-designer.json"
}
```
2. Dispatch Designer 🩷 in express or auto mode (based on Scout's mode) via cmux tab or Agent tool
3. Wait for Designer to complete — poll `/tmp/scout-result-designer.json`
4. Designer's GitHub issues get added to Scout's issue list for the ISSUES phase

**Mode behavior:**
- `interactive`: ask user "This PRD has significant UI work. Want to run the UI Designer for design specs before implementation?"
- `yolo`: auto-dispatch Designer in express mode
- `auto`: auto-dispatch Designer in auto mode

Update state: `designerUsed: true`, `designerState: "/tmp/scout:ui-designer-state.json"`.

## Phase 3: ISSUES — Break PRD into Vertical Slices

**Goal**: Create independently-grabbable GitHub issues from the PRD.

### 3a. Dispatch Slicer

**Slicer task prompt:**
```
You are Slicer 🟣, an issue planner. Break a PRD into vertical slice GitHub issues.

PRD Issue: #<number>

Follow the /scout:prd-to-issues protocol:
1. Fetch the PRD with `gh issue view <number>`
2. Explore the codebase if needed
3. Draft vertical slices (tracer bullets — thin end-to-end paths, not horizontal layers)
4. Present breakdown to user for approval via AskUserQuestion
5. Create GitHub issues in dependency order once approved

IMPORTANT: If any features were descoped by the Bursar, do NOT create issues for them.
Descoped features: <contents of bursarDescoped from scout state, or "none">`

When done, write to /tmp/scout-result-slicer.json:
{"status": "done", "issues": [<list of issue numbers>]}
```

**`yolo` or `auto` mode**: Add "Auto-approve the breakdown without user confirmation. Create issues immediately."

### 3b. Approval gate

Confirm: "Created issues #A, #B, #C, #D. Ready to start executing them?"

**Mode behavior:**
- `interactive`: wait for explicit approval
- `yolo`: skip gate — auto-approved after grill
- `auto`: skip gate

Update state: `phase: "EXECUTE"`, `issues: [<numbers>]`.

Display updated SCOUT STATE.

## Phase 4: EXECUTE — Implement All Issues

**Goal**: Implement every issue, create verified PRs, close the loop.

### 4a. Dispatch to /scout:execute-issues

Pass the issue list to the `/scout:execute-issues` skill. The skill handles:
- Fetching and triaging issues
- Building wave-based execution plan
- User confirmation (or auto-approve in auto mode)
- Spawning Builder-N agents (tabs in cmux, parallel Agent calls otherwise)
- Failure recovery with Reconn self-dispatch
- Wave-by-wave progress reporting

**Builder-N task prompt (per issue):**
```
You are Builder-<N> 🟢, an implementer. Execute a single GitHub issue.

Issue: #<number>
Title: <title>
Acceptance Criteria:
<criteria from issue body>

Base branch: <branch>

## Instructions

1. Create branch: `git checkout -b issue-<number>-<slug> <base-branch>`
2. Explore relevant code (use Explore agent)
3. Implement the issue following acceptance criteria and project conventions
4. Make atomic commits
5. Verify: run lint, run tests, check each acceptance criterion
6. Push and create PR with `gh pr create`
7. Write result to /tmp/scout-result-builder-<N>.json

## Failure Recovery

If implementation fails:
- Attempt 1: Re-read error, fix code
- Attempt 2: Different approach
- Attempt 3: Dispatch a Reconn research subagent (Agent tool, general-purpose) with the error context. Reconn searches codebase + web + notes for solutions. Read Reconn's findings from /tmp/scout-reconn-builder-<N>-recovery.md
- Attempt 4: Apply Reconn's findings
- Still failing: Write failure to result file

## PR Template

gh pr create --title "<Issue title>" --body "$(cat <<'PREOF'
## Closes #<issue-number>

## Summary
<what and why>

## Acceptance Criteria Verification
- [x] Criterion — verified by <how>

## Test Plan
- [ ] <manual test steps>

🤖 Generated with Claude Code /scout
PREOF
)"
```

### 4b. Design Verification (if Designer was used)

If `designerUsed: true` in Scout state, run post-build visual verification after all Builders complete:

1. Invoke `/scout:ui-designer verify` — dispatches Inspector to compare builds against design mockups
2. Inspector uses `/scout:agent-device` for all on-device interaction: launching the app, navigating to screens, capturing screenshots. Use `rn-debugger` only if React component state inspection is needed.
3. If any screens FAIL: re-dispatch relevant Builders with specific fix instructions from the Inspector report
4. If all screens PASS: proceed to completion

This step ensures implementation fidelity to the design specs. Skip if Designer was not used.

### 4c. Completion

When all waves are done, present final summary:

```
SCOUT COMPLETE

Idea: <original idea>
PRD: #<prd-issue-number>
Issues: #A, #B, #C, #D
PRs: #W, #X, #Y, #Z

All PRs are created and verified. Review and merge in wave order.
```

Update state: `phase: "DONE"`.

## Execution Modes (detailed)

Mode is set via `/scout settings`, or overridden per-run with `--yolo` or `--auto`.

### `interactive` (default)

Full human-in-the-loop. Every phase transition requires explicit approval. Best for learning the system or high-stakes features.

### `yolo`

**"Shape it, then ship it."** The grill runs normally — you shape the design, resolve decisions, approve the summary. After that, Scout takes over completely: writes the PRD, creates issues, and executes them all without further input. HITL issues still pause because they genuinely need human judgment.

### `auto`

Fully autonomous. Skips the grill entirely. Reconn runs in `auto-extended` mode to produce a Synthetic Decision Document. Everything is auto-approved. Only pauses on actual errors.

**Vague prompt guard**: If the user's prompt is < 2 sentences in `auto` or `yolo` mode, ask 2-3 clarifying questions before proceeding — garbage-in produces garbage-out.

## State Tracking

### State file: `/tmp/scout-state.json`

```json
{
  "mode": "cmux | in-process",
  "phase": "GRILL | PRD | ISSUES | EXECUTE | DONE",
  "auto": false,
  "flutter": false,
  "reactNative": false,
  "expo": false,
  "nextjs": false,
  "react": false,
  "express": false,
  "fastify": false,
  "idea": "Add user profile endpoints with avatar upload",
  "grillSummary": null,
  "prdIssue": null,
  "issues": [],
  "prs": [],
  "designerUsed": false,
  "designerState": null,
  "bursarEstimate": null,
  "bursarDescoped": [],
  "agents": {},
  "workspace": "workspace:1",
  "startedAt": "2026-03-16T23:00:00Z"
}
```

### Display format

Show at every phase transition:

```
SCOUT STATE:
  Mode: [interactive | yolo | auto]
  Quality: [high | balanced | budget]
  cmux: [active | off]
  Flutter: [yes | no]
  React Native: [yes | no]
  Expo: [yes | no]
  Next.js: [yes | no]
  React: [yes | no]
  Express: [yes | no]
  Fastify: [yes | no]
  Phase: [GRILL | PRD | ISSUES | EXECUTE | DONE]
  Idea: <one-line summary>
  Grill Summary: <file path or "pending">
  PRD Issue: <GitHub issue number or "pending">
  Issues Created: <list of issue numbers or "pending">
  PRs Created: <list of PR numbers or "pending">
  Bursar Estimate: <"$X.XX (N tokens)" or "pending" or "skipped">
  Descoped Features: <list or "none">
```

## Failure & Recovery

### Builder failures
```
Attempt 1: Re-read error, fix code, retry
Attempt 2: Different approach, retry
Attempt 3: Self-dispatch Reconn for research on the failure
Attempt 4: Fix with Reconn's findings, retry
Still failing: Write failure to result file -> Scout notifies user
```
Other builders continue unblocked.

### Non-Builder failures
```
Reconn/Architect/Slicer fails:
  Scout retries once with a fresh agent/tab.
  If retry fails: Scout reports error, asks user how to proceed.
```

## Teardown

### Normal completion
1. Update all agent tab statuses to final (✅/❌)
2. Close agent tabs (Reconn, Architect, Slicer, Builder-N)
3. Clean up `/tmp/scout-task-*`, `/tmp/scout-result-*`, and `/tmp/scout-bursar-estimate.json` files
4. Preserve `/tmp/scout-state.json` and `/tmp/scout-grill-summary.md` for reference
5. Display final summary

### Crash recovery
If Scout is re-invoked and `/tmp/scout-state.json` has a non-DONE phase:
1. Read the state file
2. Report what phase was in progress
3. Ask user: resume or start over?
4. If resuming: skip completed phases, pick up from last incomplete

## Technology Detection & Skill Integration

### Flutter Project Detection

On startup (after loading settings), detect if the project is Flutter-based:

```bash
# Check for Flutter project markers
ls pubspec.yaml 2>/dev/null && grep -q "flutter:" pubspec.yaml 2>/dev/null
```

If detected (or if the user's idea mentions Flutter/Dart), set `"flutter": true` in scout state and activate Flutter-aware mode for all downstream agents.

### Flutter-Aware Agent Prompts

When `flutter: true`, inject the following into agent task prompts:

**Reconn** (Phase 1b and 2a) — append to task prompt:
```
## Flutter Context
This is a Flutter project. When researching:
- Use /scout:flutter-expert knowledge: check for state management patterns (Riverpod, Bloc, Provider, etc.), architecture patterns (Clean Architecture, MVVM), and platform integration patterns already in use
- Identify the Dart version, Flutter SDK version, and key dependencies from pubspec.yaml
- Note any existing widget composition patterns, theming setup, and navigation approach
- Use /scout:senior-architect knowledge: analyze existing architecture layers, dependency graph, and module boundaries
- Check for platform channels, native plugins, and multi-platform targets
```

**Griller** (Phase 1c) — append to task prompt:
```
## Flutter-Specific Grill Areas
This is a Flutter project. In addition to standard grill categories, probe:
- State management choice and rationale (Riverpod vs Bloc vs Provider vs other)
- Architecture pattern (Clean Architecture layers, feature-driven structure, etc.)
- Multi-platform targets and platform-specific considerations
- Widget composition strategy (inheritance vs composition, custom render objects)
- Performance targets (60/120fps, Impeller vs Skia, isolate usage)
- Testing strategy (widget tests, golden files, integration tests with Patrol)
- Navigation approach (GoRouter, auto_route, Navigator 2.0)
```

**Architect** (Phase 2b) — append to task prompt:
```
## Flutter Architecture Guidelines
This is a Flutter project. When writing the PRD:
- Apply /scout:senior-architect patterns: define clear architecture layers, module boundaries, and dependency flow
- Apply /scout:flutter-expert best practices: use appropriate state management, widget composition patterns, and platform integration approaches
- Include architecture diagram showing layer separation (presentation, domain, data)
- Specify state management approach with rationale
- Define widget hierarchy and reusable component strategy
- Address multi-platform considerations if targeting web/desktop
- Include performance requirements (frame rate, app size, startup time)
- Specify testing strategy with coverage targets (unit, widget, integration, golden)
```

**Builder-N** (Phase 4a) — append to task prompt:
```
## Flutter Implementation Standards
This is a Flutter project. When implementing:
- Follow /scout:flutter-expert conventions:
  - Use const constructors wherever possible
  - Apply proper key management for widget identity
  - Use null safety with Dart 3 features (patterns, records, sealed classes)
  - Include comprehensive error handling and loading states
  - Add accessibility annotations (Semantics widgets)
  - Follow Material Design 3 / Cupertino guidelines as appropriate
- Follow /scout:senior-architect patterns:
  - Maintain clean architecture layer separation
  - Use repository pattern for data abstraction
  - Apply dependency injection (GetIt, Injectable, or Riverpod)
  - Keep business logic in domain layer, not in widgets
- Performance: minimize rebuilds, use Slivers for large lists, isolates for heavy computation
- Testing: write widget tests for new UI, unit tests for business logic
```

### React Native Project Detection

On startup (after loading settings), detect if the project is React Native-based:

```bash
# Check for React Native project markers
(ls package.json 2>/dev/null && grep -q '"react-native"' package.json 2>/dev/null) || ls app.json 2>/dev/null || ls expo-env.d.ts 2>/dev/null
```

If detected (or if the user's idea mentions React Native/Expo/RN), set `"reactNative": true` in scout state. Also check for Expo:
```bash
grep -q '"expo"' package.json 2>/dev/null && echo "expo"
```
If Expo detected, also set `"expo": true`.

Detect additional RN capabilities by checking dependencies:
```bash
grep -q '"react-native-reanimated"' package.json 2>/dev/null  # animations
grep -q '"@shopify/react-native-skia"' package.json 2>/dev/null  # Skia
grep -q '"react-native-gesture-handler"' package.json 2>/dev/null  # gestures
grep -q '"react-native-screen-transitions"' package.json 2>/dev/null  # screen transitions (zoom, shared element illusions)
```

### React Native-Aware Agent Prompts

When `reactNative: true`, inject the following into agent task prompts:

**Reconn** (Phase 1b and 2a) — append to task prompt:
```
## React Native Context
This is a React Native project. When researching:
- Use /scout:react-native-best-practices knowledge: check for performance patterns (FPS, TTI, bundle size, memory), Hermes engine usage, bridge vs JSI patterns
- Identify the React Native version, key dependencies, and native module usage from package.json
- Note existing navigation setup (React Navigation, Expo Router), state management, and styling approach
- Use /scout:senior-architect knowledge: analyze module boundaries, shared code structure, and platform-specific code organization
- Check for native modules, platform channels, and any iOS/Android specific implementations
- If Expo: check SDK version, managed vs bare workflow, and EAS configuration
- If Reanimated/Gesture Handler present: note animation patterns and gesture usage via /scout:rn-animations-performance
- If Skia present: note shader/canvas patterns via /scout:using-react-native-skia
- If screen-transitions present: note transition patterns, zoom configs, boundary triggers, and snap points via /scout:using-react-native-screen-transitions
- If loading animations or custom loaders are needed: check for math-curve-loader patterns via /scout:using-math-curve-loaders (Skia + Reanimated particle trails)
```

**Griller** (Phase 1c) — append to task prompt:
```
## React Native-Specific Grill Areas
This is a React Native project. In addition to standard grill categories, probe:
- Navigation architecture (React Navigation stack/tab/drawer vs Expo Router file-based)
- State management approach (Redux, Zustand, Jotai, React Query, context)
- Performance targets (JS thread FPS, startup time, bundle size budget)
- Animation strategy (Reanimated worklets vs Animated API vs CSS transitions)
- Screen transition approach (react-native-screen-transitions zoom/bounds vs shared elements vs native stack defaults)
- List rendering approach (FlashList vs FlatList vs Skia-based)
- Native module needs (Turbo Modules, Fabric components, Expo Modules API)
- Over-the-air updates strategy (EAS Update, CodePush)
- Platform-specific UI considerations (iOS vs Android design differences)
- Testing strategy (Jest, React Native Testing Library, Detox/Maestro E2E)
- If Expo: managed vs bare, EAS Build/Submit/Update usage
- Loading animation approach (math curve loaders via Skia vs stock ActivityIndicator vs Lottie)
```

**Architect** (Phase 2b) — append to task prompt:
```
## React Native Architecture Guidelines
This is a React Native project. When writing the PRD:
- Apply /scout:senior-architect patterns: define feature module boundaries, shared/platform-specific code split, and dependency flow
- Apply /scout:react-native-best-practices: address JS thread performance, bridge overhead minimization, and Hermes optimization
- Specify navigation architecture with screen hierarchy
- Define state management approach with data flow diagram
- Address platform-specific UI/UX differences (iOS Human Interface vs Material Design)
- Include performance requirements (startup time, FPS targets, bundle size limits)
- Specify animation approach (Reanimated worklets for 60fps+ animations)
- If Expo: specify SDK constraints, EAS workflow, and managed/bare considerations
- If Skia involved: define canvas/shader requirements via /scout:using-react-native-skia patterns
- If screen-transitions present: define transition architecture (zoom vs presets vs custom), boundary trigger strategy, gesture dismiss behavior, and backdrop approach via /scout:using-react-native-screen-transitions
- If loading animations needed: specify curve type, particle count, theming, and placement via /scout:using-math-curve-loaders patterns
- Specify testing strategy (unit, component, E2E with Detox/Maestro)
```

**Builder-N** (Phase 4a) — append to task prompt:
```
## React Native Implementation Standards
This is a React Native project. When implementing:
- Follow /scout:react-native-best-practices conventions:
  - Minimize JS thread work — offload to worklets (Reanimated) or native modules
  - Use FlashList over FlatList for large lists with proper getItemType and estimatedItemSize
  - Memoize components with React.memo, useMemo, useCallback where re-renders are measurable
  - Use Hermes-compatible code patterns (avoid eval, prefer static requires)
  - Avoid bridge overhead — batch native calls, use JSI when available
  - Handle platform differences with Platform.select or .ios.tsx/.android.tsx files
- Follow /scout:rn-animations-performance for animations:
  - Run animations on UI thread via Reanimated useAnimatedStyle/useSharedValue
  - Use gesture handler worklets for interactive animations
  - Never drive animations from React state — use shared values
- Follow /scout:senior-architect patterns:
  - Feature-based folder structure with clear module boundaries
  - Repository pattern for data layer abstraction
  - Proper error boundaries and loading/error states
- If Expo: follow Expo conventions (expo-router file-based routing, Expo config plugins, EAS)
- If Skia present: follow /scout:using-react-native-skia for shader and canvas code
- If screen-transitions present: follow /scout:using-react-native-screen-transitions for all screen transition code — use BlankStack navigator, bounds().navigation.zoom() for hero animations, Transition.Boundary.Trigger for source elements, useScreenGesture/useScreenAnimation for dismiss thresholds, and Transition.ScrollView for gesture-aware scrolling. Prefer active element animation (zoom) over shared element libraries.
- If loading animations needed: follow /scout:using-math-curve-loaders — use Skia Canvas + Circle with useFrameCallback time source and useDerivedValue worklets for parametric math. Mark curve functions with 'worklet' directive. Use declarative approach for ≤40 particles, imperative useDrawCallback for 64+.
- Testing: write component tests with RNTL, snapshot tests for UI, E2E for critical flows
```

### Next.js Project Detection

On startup (after loading settings), detect if the project is Next.js-based:

```bash
# Check for Next.js project markers
ls next.config.js next.config.mjs next.config.ts 2>/dev/null || (ls package.json 2>/dev/null && grep -q '"next"' package.json 2>/dev/null)
```

If detected (or if the user's idea mentions Next.js/Next), set `"nextjs": true` in scout state.

Detect additional capabilities by checking project structure:
```bash
ls app/ 2>/dev/null  # App Router
ls pages/ 2>/dev/null  # Pages Router
grep -q '"@vercel/analytics"' package.json 2>/dev/null  # Vercel deployment
grep -q '"prisma"' package.json 2>/dev/null  # Database ORM
grep -q '"@trpc/server"' package.json 2>/dev/null  # tRPC
```

### Next.js-Aware Agent Prompts

When `nextjs: true`, inject the following into agent task prompts:

**Reconn** (Phase 1b and 2a) — append to task prompt:
```
## Next.js Context
This is a Next.js project. When researching:
- Use /scout:react-best-practices knowledge: check for rendering patterns (SSR, SSG, ISR, RSC), data fetching approaches, and bundle optimization
- Identify if using App Router (app/) or Pages Router (pages/) — this fundamentally changes patterns
- Note the Next.js version, React version, and key dependencies from package.json
- Check for existing API routes, middleware, server actions, and data fetching patterns
- Use /scout:senior-architect knowledge: analyze route organization, shared layouts, module boundaries, and backend integration patterns
- Check for deployment target (Vercel, self-hosted, Docker) and any edge runtime usage
- Note styling approach (CSS Modules, Tailwind, styled-components, etc.)
```

**Griller** (Phase 1c) — append to task prompt:
```
## Next.js-Specific Grill Areas
This is a Next.js project. In addition to standard grill categories, probe:
- Router choice rationale (App Router vs Pages Router) and migration status if mixed
- Rendering strategy per route (SSR, SSG, ISR, client-side, streaming with Suspense)
- Server Components vs Client Components boundary decisions
- Data fetching approach (server actions, route handlers, tRPC, external API)
- Caching strategy (fetch cache, unstable_cache, revalidation timing, CDN)
- Authentication/authorization pattern (middleware, server-side, NextAuth/Clerk/custom)
- State management for client-side state (React Query, Zustand, context)
- SEO and metadata strategy (generateMetadata, sitemap, OpenGraph)
- Performance targets (Core Web Vitals — LCP, FID/INP, CLS)
- Deployment target and infrastructure (Vercel, self-hosted, edge vs Node runtime)
- Testing strategy (Jest, Playwright/Cypress E2E, React Testing Library)
```

**Architect** (Phase 2b) — append to task prompt:
```
## Next.js Architecture Guidelines
This is a Next.js project. When writing the PRD:
- Apply /scout:senior-architect patterns: define route structure, shared layouts, module boundaries, and API layer design
- Apply /scout:react-best-practices: specify rendering strategy per route, Server vs Client Component boundaries, and data fetching patterns
- Define route hierarchy with layouts, loading states, and error boundaries
- Specify data fetching approach (server actions for mutations, fetch with caching for reads)
- Address caching strategy (revalidation timing, static vs dynamic routes, CDN behavior)
- Include performance requirements (Core Web Vitals targets: LCP < 2.5s, INP < 200ms, CLS < 0.1)
- Specify SEO requirements (metadata, structured data, sitemap)
- Define API design (route handlers, server actions, or external API integration)
- Address authentication/authorization architecture
- Specify testing strategy (unit, integration, E2E with Playwright)
```

**Builder-N** (Phase 4a) — append to task prompt:
```
## Next.js Implementation Standards
This is a Next.js project. When implementing:
- Follow /scout:react-best-practices conventions:
  - Default to Server Components — only add 'use client' when needed (interactivity, hooks, browser APIs)
  - Use server actions for mutations, fetch with proper caching for data reads
  - Implement loading.tsx and error.tsx for route segments
  - Use React.Suspense boundaries for streaming and progressive rendering
  - Optimize images with next/image, fonts with next/font
  - Use dynamic imports (next/dynamic) for heavy client components
  - Minimize client-side JavaScript — keep the Client Component boundary as low as possible
- Follow /scout:senior-architect patterns:
  - Organize routes with shared layouts and route groups
  - Co-locate components, utils, and types with their routes
  - Use middleware for cross-cutting concerns (auth, redirects, headers)
  - Separate data access layer from route handlers and pages
- Performance: optimize for Core Web Vitals, use proper cache headers, leverage ISR where appropriate
- SEO: implement generateMetadata, add structured data, create sitemap.xml
- Testing: write component tests with RTL, E2E tests with Playwright for critical user flows
```

### Express.js Project Detection

On startup, detect if the project uses Express:

```bash
ls package.json 2>/dev/null && grep -q '"express"' package.json 2>/dev/null
```

If detected (or if the user's idea mentions Express), set `"express": true` in scout state. Express is a backend framework — it can co-exist with frontend flags (e.g., a monorepo with React frontend + Express API).

### Express.js-Aware Agent Prompts

When `express: true`, inject the following into agent task prompts:

**Reconn** (Phase 1b and 2a) — append to task prompt:
```
## Express.js Context
This is an Express.js project. When researching:
- Use /scout:expressjs-best-practices knowledge: check middleware chain ordering, error handling patterns, and route organization
- Identify Express version, TypeScript usage, and key middleware (helmet, cors, express-validator, passport)
- Note existing route structure, controller/service separation, and API versioning approach
- Use /scout:senior-architect knowledge: analyze layered architecture (routes → controllers → services → repositories), module boundaries, and dependency injection
- Check for database integration (Prisma, TypeORM, Knex, Mongoose), ORM patterns, and migration setup
- Note authentication approach (JWT, sessions, OAuth), validation library, and testing setup (Jest + Supertest)
```

**Griller** (Phase 1c) — append to task prompt:
```
## Express-Specific Grill Areas
This is an Express.js project. In addition to standard grill categories, probe:
- API design (REST conventions, versioning strategy, response envelope format)
- Middleware chain ordering (security → parsing → auth → routes → error handler)
- Error handling strategy (centralized error handler, custom error classes, operational vs programmer errors)
- Request validation approach (Zod, Joi, express-validator — validate at the boundary)
- Authentication/authorization architecture (JWT strategy, middleware guards, role-based access)
- Database integration (ORM choice, connection pooling, transaction patterns, migrations)
- Security posture (helmet, cors origins, rate limiting, input sanitization)
- Testing strategy (unit tests for services, integration tests with Supertest, E2E)
- Performance considerations (compression, caching headers, connection keep-alive, cluster mode)
- Graceful shutdown handling (SIGTERM, connection draining, database pool cleanup)
- Logging approach (structured logging with pino/winston, request correlation IDs)
```

**Architect** (Phase 2b) — append to task prompt:
```
## Express Architecture Guidelines
This is an Express.js project. When writing the PRD:
- Apply /scout:senior-architect patterns: define layered architecture (routes → controllers → services → repositories), module boundaries, and DI approach
- Apply /scout:expressjs-best-practices: specify middleware chain, error handling strategy, and security middleware
- Define API structure with versioning, route grouping, and response format
- Specify validation strategy with schema library (Zod/Joi) at every route boundary
- Define authentication/authorization architecture with middleware guards
- Address database layer (ORM, migrations, connection pooling, transaction boundaries)
- Include security requirements (helmet config, CORS origins, rate limits, input sanitization)
- Specify error handling (custom error classes, centralized handler, safe error messages in production)
- Define testing strategy (service unit tests, route integration tests with Supertest)
- Address deployment (graceful shutdown, health checks, environment config validation)
```

**Builder-N** (Phase 4a) — append to task prompt:
```
## Express Implementation Standards
This is an Express.js project. When implementing:
- Follow /scout:expressjs-best-practices conventions:
  - Wrap async handlers to catch rejected promises — never leave unhandled rejections
  - Use centralized error-handling middleware (4-param function) as the last middleware
  - Create custom AppError class with statusCode and isOperational flag
  - Validate all request input (body, params, query) with Zod/Joi at route boundaries
  - Keep route handlers thin — delegate to service layer for business logic
  - Use express.json({ limit: '10kb' }) to prevent payload abuse
  - Set security headers with helmet, configure CORS with explicit origins
- Follow /scout:senior-architect patterns:
  - Layered architecture: routes → controllers → services → repositories
  - Repository pattern for database abstraction
  - Dependency injection for testability
  - Environment config validation at startup (fail fast on missing config)
- Security: parameterized queries, never expose stack traces in production, rate limiting
- Testing: Supertest integration tests for routes, unit tests for services with mocked repositories
- Graceful shutdown: handle SIGTERM, drain connections, close database pools
```

### Fastify Project Detection

On startup, detect if the project uses Fastify:

```bash
ls package.json 2>/dev/null && grep -q '"fastify"' package.json 2>/dev/null
```

If detected (or if the user's idea mentions Fastify), set `"fastify": true` in scout state. Fastify is a backend framework — it can co-exist with frontend flags.

### Fastify-Aware Agent Prompts

When `fastify: true`, inject the following into agent task prompts:

**Reconn** (Phase 1b and 2a) — append to task prompt:
```
## Fastify Context
This is a Fastify project. When researching:
- Use /scout:fastify-best-practices knowledge: check plugin architecture, schema-based validation/serialization, and hooks lifecycle
- Identify Fastify version, TypeScript type provider usage (Typebox, Zod), and key plugins (@fastify/sensible, @fastify/cors, @fastify/helmet)
- Note existing plugin structure, encapsulation boundaries, and autoload patterns
- Use /scout:senior-architect knowledge: analyze plugin composition, shared vs encapsulated decorators, and service layer separation
- Check for database integration (plugin-based with decorators), schema organization, and route registration patterns
- Note if using @fastify/swagger for API documentation, @fastify/env for config validation
```

**Griller** (Phase 1c) — append to task prompt:
```
## Fastify-Specific Grill Areas
This is a Fastify project. In addition to standard grill categories, probe:
- Plugin architecture (encapsulated vs shared plugins, registration order, dependency management)
- Schema strategy (Typebox for TypeScript + JSON Schema, response serialization for performance)
- Type provider choice (Typebox, Zod, or JSON Schema — affects type inference in handlers)
- Hooks lifecycle usage (onRequest for auth, preHandler for authorization, preSerialization for transforms)
- Error handling (setErrorHandler, @fastify/sensible httpErrors, validation error formatting)
- Database integration (as plugin with decorators, connection lifecycle via onClose hook)
- Configuration management (@fastify/env with schema validation, fail-fast on startup)
- Testing approach (app.inject() for no-HTTP-overhead testing, plugin isolation testing)
- Performance targets (Fastify is already fast — response schemas for serialization boost, avoid middleware patterns)
- API documentation (@fastify/swagger + @fastify/swagger-ui for OpenAPI generation from schemas)
- Logging configuration (built-in pino, request logging, redaction of sensitive fields)
```

**Architect** (Phase 2b) — append to task prompt:
```
## Fastify Architecture Guidelines
This is a Fastify project. When writing the PRD:
- Apply /scout:senior-architect patterns: define plugin composition tree, encapsulation boundaries, and service layer
- Apply /scout:fastify-best-practices: specify schema-first validation with Typebox, plugin architecture, and hooks usage
- Define plugin hierarchy (shared infrastructure plugins → feature route plugins)
- Specify schema strategy with Typebox for type-safe request validation AND response serialization
- Define type provider for end-to-end TypeScript inference from schema to handler
- Address hooks lifecycle (which hook for auth, authorization, logging, transforms)
- Specify error handling (centralized setErrorHandler, @fastify/sensible for HTTP errors)
- Define database integration as a shared plugin with onClose cleanup
- Include configuration validation with @fastify/env (fail fast on startup)
- Specify testing strategy (app.inject() integration tests, plugin isolation tests)
- Address API documentation (auto-generated OpenAPI from route schemas)
```

**Builder-N** (Phase 4a) — append to task prompt:
```
## Fastify Implementation Standards
This is a Fastify project. When implementing:
- Follow /scout:fastify-best-practices conventions:
  - Define JSON Schema (via Typebox) for EVERY route — request validation AND response serialization
  - Use response schemas — they compile to fast serializers (2-3x faster than JSON.stringify)
  - Return values from handlers (`return data`) instead of `reply.send(data)` — it's faster
  - Use fastify-plugin (fp) wrapper only for plugins that need to share decorators with siblings
  - Register database connections as plugins with onClose hooks for cleanup
  - Use req.log for request-scoped logging (child logger with auto request ID)
  - Validate environment config at startup with @fastify/env — fail fast on missing vars
- Follow /scout:senior-architect patterns:
  - Plugin-based architecture — one plugin per feature/resource
  - Shared plugins for cross-cutting concerns (database, auth, config)
  - Service layer for business logic — keep route handlers thin
  - Use decorators to expose shared services (fastify.db, fastify.config)
- Use TypeBoxTypeProvider for full type inference from schema to handler
- Use @fastify/sensible for standard HTTP error helpers (fastify.httpErrors.notFound())
- Testing: use app.inject() — no HTTP overhead, no port binding needed
- Never use Express compatibility layer unless actively migrating — it removes perf benefits
```

### React (SPA) Project Detection

On startup (after loading settings), detect if the project is a client-side React app (not Next.js or React Native):

```bash
# Check for React without Next.js or React Native
(ls package.json 2>/dev/null && grep -q '"react"' package.json 2>/dev/null) && \
  ! grep -q '"next"' package.json 2>/dev/null && \
  ! grep -q '"react-native"' package.json 2>/dev/null
```

If detected (or if the user's idea mentions React without Next.js/RN context), set `"react": true` in scout state.

Detect build tooling and routing:
```bash
ls vite.config.ts vite.config.js 2>/dev/null  # Vite
ls webpack.config.js 2>/dev/null  # Webpack
grep -q '"react-router"' package.json 2>/dev/null  # React Router
grep -q '"@tanstack/react-router"' package.json 2>/dev/null  # TanStack Router
```

### React (SPA)-Aware Agent Prompts

When `react: true`, inject the following into agent task prompts:

**Reconn** (Phase 1b and 2a) — append to task prompt:
```
## React Context
This is a client-side React SPA. When researching:
- Use /scout:react-best-practices knowledge: check for component patterns, rendering optimization, and bundle size management
- Identify the React version, build tool (Vite, Webpack, CRA), and TypeScript usage from package.json
- Note existing routing setup (React Router, TanStack Router), state management (Redux, Zustand, Jotai, React Query), and styling approach
- Use /scout:senior-architect knowledge: analyze component hierarchy, feature module boundaries, shared utilities, and API integration patterns
- Check for data fetching approach (React Query, SWR, custom hooks), form handling (React Hook Form, Formik), and UI component library (MUI, Chakra, Radix, shadcn)
- Note testing setup (Jest, Vitest, React Testing Library, Cypress/Playwright)
```

**Griller** (Phase 1c) — append to task prompt:
```
## React-Specific Grill Areas
This is a client-side React SPA. In addition to standard grill categories, probe:
- Routing strategy (React Router v6 nested routes, TanStack Router, or custom)
- State management architecture (server state vs client state separation)
- Data fetching and caching approach (React Query, SWR, or manual)
- Component design system (existing library, custom components, headless UI)
- Bundle optimization strategy (code splitting, lazy loading, tree shaking)
- Authentication flow (token management, protected routes, session handling)
- Form handling approach (React Hook Form, controlled vs uncontrolled)
- Error handling strategy (error boundaries, toast notifications, retry logic)
- Performance targets (bundle size budget, LCP, interaction responsiveness)
- Testing strategy (unit, component, integration, E2E)
- Build and deployment pipeline (Vite, CI/CD, hosting — Vercel, Netlify, S3+CF)
```

**Architect** (Phase 2b) — append to task prompt:
```
## React Architecture Guidelines
This is a client-side React SPA. When writing the PRD:
- Apply /scout:senior-architect patterns: define feature module boundaries, shared component library, and API layer abstraction
- Apply /scout:react-best-practices: specify component composition patterns, memoization strategy, and bundle optimization approach
- Define routing structure with nested layouts, protected routes, and code-split boundaries
- Specify state management architecture (separate server state cache from UI state)
- Define component hierarchy (pages → features → shared components → primitives)
- Address data fetching patterns (query invalidation, optimistic updates, error/loading states)
- Include performance requirements (bundle size budget, lazy loading strategy, CWV targets)
- Specify API integration layer (typed client, interceptors, error handling)
- Define form handling patterns and validation approach
- Specify testing strategy (component tests with RTL, E2E with Playwright/Cypress)
```

**Builder-N** (Phase 4a) — append to task prompt:
```
## React Implementation Standards
This is a client-side React SPA. When implementing:
- Follow /scout:react-best-practices conventions:
  - Use React.memo only when re-renders are measurably expensive — don't premature-optimize
  - Lift state up minimally — colocate state with the components that use it
  - Use custom hooks to encapsulate complex logic and side effects
  - Apply code splitting with React.lazy and Suspense at route boundaries
  - Keep components focused — extract logic into hooks, presentation into subcomponents
  - Use proper key props for lists (stable IDs, never array index for dynamic lists)
  - Implement error boundaries at feature boundaries
- Follow /scout:senior-architect patterns:
  - Feature-based folder structure (feature/components, hooks, api, types)
  - Separate data access layer — typed API client with interceptors
  - Use barrel exports sparingly to avoid circular dependencies
  - Keep business logic in hooks, not in components
- Data fetching: use React Query/SWR for server state, keep cache keys organized
- Forms: use React Hook Form with Zod/Yup validation schemas
- Testing: write component tests with RTL (test behavior not implementation), E2E for critical flows
```

## On-Device Interaction Tools

When the task involves interacting with a running app (navigation, screenshots, visual verification, UI testing):

### Tool Selection Rules

| Task | Tool | Why |
|------|------|-----|
| **UI navigation** (tap tabs, buttons, dismiss modals) | `/scout:agent-device` | Accessibility tree refs (`@e85`) are deterministic and reliable |
| **Scrolling and swiping** | `/scout:agent-device` | Point-based coordinates, works first try |
| **Visual verification / screenshots** | `/scout:agent-device` | `snapshot` gives element tree + visual state |
| **React component inspection** (fiber tree, props, state) | `rn-debugger` MCP | Fiber tree access, component hierarchy |
| **Console logs, network requests, bundle errors** | `rn-debugger` MCP | Runtime debugging capabilities |
| **Execute JS in app runtime** | `rn-debugger` MCP | `execute_in_app` for runtime evaluation |

### Why agent-device is the default for interaction

Direct comparison (2026-03-26) showed:
- **agent-device**: Tab bar taps, modal dismissal, and scrolling all work on first attempt via accessibility refs
- **rn-debugger**: Fiber strategy matched wrong elements (found "Train" in banner text instead of tab bar), coordinate conversion between screenshots and native taps was inconsistent, accessibility/OCR strategies failed to find tab bar elements

### Usage in Scout phases

- **Phase 1 (GRILL)**: Use `/scout:agent-device` if investigating a visual bug — `snapshot` to read current UI state, `screenshot` for visual proof
- **Phase 4 (EXECUTE)**: Builders use `/scout:agent-device` for post-implementation visual verification
- **Phase 4b (Design Verification)**: Inspector uses `/scout:agent-device` for screenshot capture and UI comparison
- **Debugging failures**: Use `rn-debugger` for console logs, network inspection, and React component state when Builders hit issues

### agent-device quick reference

```bash
# Bootstrap
agent-device devices --platform ios
agent-device open "AppName" --platform ios --device "iPhone 17 Pro Max" --relaunch

# Inspect
agent-device snapshot        # Read-only element tree
agent-device snapshot -i     # Interactive refs for tapping
agent-device screenshot /tmp/screen.png

# Interact
agent-device press @e85      # Tap by accessibility ref
agent-device press 220 450   # Tap by point coordinates
agent-device swipe 220 450 220 100 500  # Scroll (points, duration ms)

# Cleanup
agent-device close
```

## Key Constraints

- **You are the orchestrator, not the implementer** — dispatch agents for all work
- **Griller runs in Scout's tab** — it needs user Q&A, never gets its own tab
- **Never skip approval gates** (unless auto mode) — each phase needs explicit user approval
- **Carry context forward** — every agent gets full accumulated context from prior phases
- **User can bail at any gate** — wrap up cleanly with what's produced so far
- **One phase at a time** — phases are sequential, never parallel
- **Report state at transitions** — always show SCOUT STATE between phases
- **Research before action** — Reconn runs proactively before GRILL and EXECUTE
