---
name: scout
description: End-to-end feature orchestrator — grills the user on their idea, writes a PRD, breaks it into issues, and executes them with verified PRs. Supports cmux tab mode and autonomous execution. Use when user wants to go from idea to implementation, says "scout this", or wants the full product development pipeline.
---

# /scout - Idea-to-Implementation Orchestrator

Takes a raw idea and drives it through interrogation, PRD creation, issue breakdown, and parallel execution — producing verified PRs. Manages a roster of named, color-coded agents.

## When to Use
- User says "/scout" or "scout this"
- User has an idea and wants to go from concept to shipped code
- User wants the full product development pipeline
- With `--auto` flag for autonomous execution

## Agent Roster

| Agent | Color | Hex | Icon | Role | Own Tab? |
|-------|-------|-----|------|------|----------|
| **Scout** | Orange | `#FF8C00` | 🟠 | Orchestrator — manages phases, state, handoffs, user interaction | Original tab |
| **Griller** | Red | `#DC2626` | 🔴 | Interviews user via `/grill-me` protocol | No — runs in Scout tab |
| **Reconn** | Yellow | `#EAB308` | 🟡 | Deep research — codebase, web, QMD, claude-mem | Yes (cmux only) |
| **Architect** | Blue | `#2563EB` | 🔵 | Writes PRD via `/write-a-prd` | Yes (cmux only) |
| **Slicer** | Purple | `#7C3AED` | 🟣 | Breaks PRD into issues via `/prd-to-issues` | Yes (cmux only) |
| **Builder-N** | Green | `#16A34A` | 🟢 | Executes issues — one per parallel issue | Yes (cmux only) |

## Startup Protocol

On `/scout` invocation:

### 1. Parse arguments

Check for `--auto` flag in the user's prompt. If present or user says "autonomously" / "auto mode", set auto mode.

### 2. Detect cmux

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

### 3. Check for interrupted session

Check if `/tmp/scout-state.json` exists with a non-DONE phase:
- If found: report what was in progress, ask user to resume or start fresh
- If not found or DONE: proceed with new session

### 4. Initialize state

Write initial state to `/tmp/scout-state.json`:
```json
{
  "mode": "cmux",
  "phase": "GRILL",
  "auto": false,
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

Follow the /reconn research protocol:
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

Follow the /grill-me protocol:
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

**Auto mode**: skip gate, proceed immediately.

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

Follow the /write-a-prd protocol with these adjustments:
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

**Auto mode**: Add "Auto-approve the PRD without user confirmation. Create the GitHub issue immediately."

### 2c. Approval gate

Confirm with user: "PRD created as issue #X. Ready to break it into implementation issues?"

**Auto mode**: skip gate.

Update state: `phase: "ISSUES"`, `prdIssue: <number>`.

Display updated SCOUT STATE.

## Phase 3: ISSUES — Break PRD into Vertical Slices

**Goal**: Create independently-grabbable GitHub issues from the PRD.

### 3a. Dispatch Slicer

**Slicer task prompt:**
```
You are Slicer 🟣, an issue planner. Break a PRD into vertical slice GitHub issues.

PRD Issue: #<number>

Follow the /prd-to-issues protocol:
1. Fetch the PRD with `gh issue view <number>`
2. Explore the codebase if needed
3. Draft vertical slices (tracer bullets — thin end-to-end paths, not horizontal layers)
4. Present breakdown to user for approval via AskUserQuestion
5. Create GitHub issues in dependency order once approved

When done, write to /tmp/scout-result-slicer.json:
{"status": "done", "issues": [<list of issue numbers>]}
```

**Auto mode**: Add "Auto-approve the breakdown without user confirmation. Create issues immediately."

### 3b. Approval gate

Confirm: "Created issues #A, #B, #C, #D. Ready to start executing them?"

**Auto mode**: skip gate.

Update state: `phase: "EXECUTE"`, `issues: [<numbers>]`.

Display updated SCOUT STATE.

## Phase 4: EXECUTE — Implement All Issues

**Goal**: Implement every issue, create verified PRs, close the loop.

### 4a. Dispatch to /execute-issues

Pass the issue list to the `/execute-issues` skill. The skill handles:
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

### 4b. Completion

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

## Auto Mode

Invoked via `/scout --auto` or when user says "scout this autonomously".

| Behavior | Normal | Auto |
|----------|--------|------|
| Grill interview | Interactive Q&A | Skipped — Reconn produces Synthetic Decision Document |
| Reconn research | Standard | Extended (auto-extended mode) |
| PRD approval | User confirms | Auto-approved |
| Issue breakdown | User confirms | Auto-approved |
| HITL issues | Pause for user | Treated as AFK |
| Phase transitions | Wait for input | Report status, continue immediately |
| User interrupt | N/A | User can interrupt anytime to take control |

**Vague prompt guard**: If the user's prompt is < 2 sentences in auto mode, ask 2-3 clarifying questions before proceeding — even in auto mode, garbage-in produces garbage-out.

## State Tracking

### State file: `/tmp/scout-state.json`

```json
{
  "mode": "cmux | in-process",
  "phase": "GRILL | PRD | ISSUES | EXECUTE | DONE",
  "auto": false,
  "idea": "Add user profile endpoints with avatar upload",
  "grillSummary": null,
  "prdIssue": null,
  "issues": [],
  "prs": [],
  "agents": {},
  "workspace": "workspace:1",
  "startedAt": "2026-03-16T23:00:00Z"
}
```

### Display format

Show at every phase transition:

```
SCOUT STATE:
  Mode: [cmux: active | cmux: off]
  Phase: [GRILL | PRD | ISSUES | EXECUTE | DONE]
  Auto: [yes | no]
  Idea: <one-line summary>
  Grill Summary: <file path or "pending">
  PRD Issue: <GitHub issue number or "pending">
  Issues Created: <list of issue numbers or "pending">
  PRs Created: <list of PR numbers or "pending">
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
3. Clean up `/tmp/scout-task-*` and `/tmp/scout-result-*` files
4. Preserve `/tmp/scout-state.json` and `/tmp/scout-grill-summary.md` for reference
5. Display final summary

### Crash recovery
If Scout is re-invoked and `/tmp/scout-state.json` has a non-DONE phase:
1. Read the state file
2. Report what phase was in progress
3. Ask user: resume or start over?
4. If resuming: skip completed phases, pick up from last incomplete

## Key Constraints

- **You are the orchestrator, not the implementer** — dispatch agents for all work
- **Griller runs in Scout's tab** — it needs user Q&A, never gets its own tab
- **Never skip approval gates** (unless auto mode) — each phase needs explicit user approval
- **Carry context forward** — every agent gets full accumulated context from prior phases
- **User can bail at any gate** — wrap up cleanly with what's produced so far
- **One phase at a time** — phases are sequential, never parallel
- **Report state at transitions** — always show SCOUT STATE between phases
- **Research before action** — Reconn runs proactively before GRILL and EXECUTE
