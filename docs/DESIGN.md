# Scout Agent Orchestrator — Design Spec

## Overview

`/scout` is an end-to-end feature orchestrator that takes a raw idea and drives it through interrogation, PRD creation, issue breakdown, and parallel execution — producing verified PRs. It manages a roster of named, color-coded agents that run as cmux tabs when available, or as in-process subagents otherwise.

## Agent Roster

| Agent | Color | Hex | Role | Own Tab? |
|-------|-------|-----|------|----------|
| **Scout** | Orange | `#FF8C00` | Orchestrator — manages phases, state, handoffs, user interaction | Original tab |
| **Griller** | Red | `#DC2626` | Interviews user via `/grill-me` protocol | No — runs in Scout tab |
| **Reconn** | Yellow | `#EAB308` | Deep research — codebase, web, QMD, claude-mem | Yes (cmux only) |
| **Architect** | Blue | `#2563EB` | Writes PRD via `/write-a-prd` | Yes (cmux only) |
| **Slicer** | Purple | `#7C3AED` | Breaks PRD into issues via `/prd-to-issues` | Yes (cmux only) |
| **Builder-N** | Green | `#16A34A` | Executes issues — one per parallel issue | Yes (cmux only) |

## Execution Model

### Two modes, one interface

Regardless of cmux availability, every agent runs as a **separate Claude Code process**. The difference is only in how they are hosted:

| Mode | How agents run | Communication |
|------|---------------|---------------|
| **cmux mode** | Each agent is a separate Claude process in its own cmux tab within the current workspace | File-based coordination via `/tmp/scout-*` files. Scout polls completion via `cmux read-screen`. |
| **In-process mode** | Each agent is dispatched via the Agent tool as a subagent | Agent tool returns results directly to Scout. |

**Key distinction:** cmux tabs host independent Claude Code processes. They do NOT use the cmux-multi-agent envelope protocol (HELLO/REQ/ACK/RES). Instead, coordination is file-based — Scout writes task files, agents read them and write result files, Scout polls for completion.

### Why not the envelope protocol?

The cmux-multi-agent protocol is designed for persistent peer-to-peer collaboration between long-lived agents. Scout's agents are short-lived and task-oriented — they receive a task, complete it, and exit. File-based coordination is simpler and sufficient.

## cmux Integration

### Detection

On startup, Scout runs `cmux identify --json`. If it succeeds, cmux mode is active. Scout announces:

```
SCOUT [cmux: active] — agents will spawn in dedicated tabs
```

or:

```
SCOUT [cmux: off] — agents will run in-process
```

### Tab Spawning

To create an agent tab in the current workspace:

```bash
# 1. Capture current workspace and surface
CURRENT_WS=$(cmux current-workspace 2>&1 | awk '{print $1}')
CURRENT_SURFACE=$(cmux identify --json 2>&1 | jq -r '.caller.surface_ref')

# 2. Write the agent's task to a file
cat > /tmp/scout-task-reconn.md << 'EOF'
<task content here>
EOF

# 3. Create a new tab (surface) in the current workspace
NEW_SURFACE=$(cmux new-surface --workspace "$CURRENT_WS" 2>&1 | awk '{print $2}')

# 4. Launch Claude in the new tab with the task
cmux send --surface "$NEW_SURFACE" "claude \"$(cat /tmp/scout-task-reconn.md)\""
cmux send-key --surface "$NEW_SURFACE" enter

# 5. Name and color the tab
cmux rename-tab --surface "$NEW_SURFACE" "Reconn"
cmux set-status --surface "$NEW_SURFACE" --icon "🟡" --color "#EAB308"
```

### Tab Lifecycle

- Scout captures the current workspace ref on startup
- Each agent (except Griller) gets a new tab in the SAME workspace
- Tabs are named (`Reconn`, `Architect`, `Builder-1`, etc.) via `cmux rename-tab`
- Tabs get color-coded status via `cmux set-status`
- On agent completion: agent writes result to `/tmp/scout-result-<agent>.md` and exits
- Scout detects completion by polling for the result file (not `read-screen`)
- On completion, tab status updates to green checkmark or red X
- Completed tabs persist until Scout finishes (for reference)

### Completion Detection

Scout polls for agent completion using result files:

```bash
# Agent writes this on completion:
echo '{"status": "done", "result": "/tmp/scout-reconn-findings.md"}' > /tmp/scout-result-reconn.json

# Or on failure:
echo '{"status": "failed", "error": "..."}' > /tmp/scout-result-reconn.json
```

Scout checks for these files periodically. This avoids the need for read-screen polling or envelope messaging.

### Non-cmux Fallback

When cmux isn't available:
- Agents dispatch as in-process subagents via the Agent tool
- No tabs, no color coding
- Builders within a wave still run in parallel via multiple Agent tool calls
- State file and context handoff work identically

## Communication Model

### File-Based Coordination

All agents communicate through files in `/tmp/scout-*`. No direct agent-to-agent messaging.

```
Scout writes task:     /tmp/scout-task-<agent>.md
Agent reads task:      /tmp/scout-task-<agent>.md
Agent writes result:   /tmp/scout-result-<agent>.json  (status + result path)
Agent writes output:   /tmp/scout-<agent>-<output>.md  (actual deliverable)
```

### Reconn On-Demand Dispatch

When an agent needs Reconn mid-task:

- **In-process mode**: The agent spawns Reconn as its own subagent via the Agent tool. Every agent prompt includes the `/reconn` skill instructions so it can self-dispatch.
- **cmux mode**: The agent spawns Reconn as its own subagent (in-process within its tab). It does NOT message the existing Reconn tab — it creates a local research subagent. This keeps things simple and avoids cross-tab messaging.

### Scout-to-Agent Communication

Scout never sends messages to running agents. Instead:
1. Scout writes a complete task file before spawning the agent
2. Agent reads the task file, does the work, writes the result
3. Scout reads the result after the agent completes

This is fire-and-forget — if Scout needs to change course mid-agent, it waits for the current agent to finish.

## Phases

### Phase 1: GRILL

1. Scout spawns **Reconn** (tab or background agent) for proactive codebase/web research
2. Scout waits for Reconn to complete and reads findings
3. Scout runs **Griller** in-process — interviews user with Reconn's findings as context
4. Griller completes — Decision Summary saved to `/tmp/scout-grill-summary.md`
5. Scout asks user: proceed to PRD?

### Phase 2: PRD

1. Scout spawns a fresh **Reconn** (new tab or agent) to validate findings against code
2. Scout waits for Reconn, then spawns **Architect** (tab or agent) with grill output + Reconn findings
3. Architect completes — PRD submitted as GitHub issue
4. Scout asks user: proceed to issues?

Note: Reconn is short-lived — each invocation is a fresh agent. In cmux mode, the previous Reconn tab is closed before spawning a new one (or the tab is reused by closing the old process and launching a new one).

### Phase 3: ISSUES

1. Scout spawns **Slicer** (tab or agent) to read PRD issue and draft vertical slices
2. Slicer completes — issues created on GitHub
3. Scout asks user: proceed to execution?

### Phase 4: EXECUTE

1. Scout parses wave plan from issue dependencies
2. Per wave:
   - Scout spawns **Builder-N** tabs/agents (one per issue in the wave)
   - Builders work in parallel, each on their own branch
   - On failure: self-heal (2 attempts) -> call Reconn (self-dispatch) -> escalate to Scout
   - Wave completes -> Scout reports status
3. All waves done -> final summary

## Auto Mode

Invoked via `/scout --auto` or "scout this autonomously".

| Behavior | Normal | Auto |
|----------|--------|------|
| Grill interview | Interactive Q&A with user | Skipped |
| Reconn before grill | Standard research | Extended research (see below) |
| PRD approval | User confirms | Auto-approved |
| Issue breakdown approval | User confirms | Auto-approved |
| HITL issues | Pause for user | Treated as AFK |
| Phase transition reporting | Waits for input | Reports status, continues immediately |
| User interrupt | N/A | User can interrupt at any time to take back control |

### Auto Mode Extended Research

When the grill is skipped, Reconn compensates by producing a **Synthetic Decision Document** that covers the same categories the grill would have explored:

1. **Goals & constraints** — inferred from the user's prompt and codebase analysis
2. **Architecture decisions** — recommended approach based on existing patterns
3. **Data flow** — mapped from existing code
4. **Error cases** — common failure modes for this type of feature
5. **Scope boundaries** — v1 scope inferred from prompt, with explicit assumptions listed
6. **Dependencies** — identified from codebase exploration

The synthetic document is clearly marked as "auto-inferred" so downstream agents know these are assumptions, not user-confirmed decisions. The user's initial prompt must be detailed enough to seed this — if the prompt is too vague (< 2 sentences), Scout falls back to asking 2-3 clarifying questions even in auto mode.

## Reconn Agent

### Dispatch Model

**Proactive** (Scout auto-dispatches):
- Before Phase 1 (GRILL): research codebase for relevant patterns, constraints, integration points
- Before Phase 4 (EXECUTE): research per-issue technical context

**On-demand** (any agent self-dispatches):
- Builder hits unknown API/pattern -> spawns its own Reconn subagent
- Architect needs to verify a claim -> spawns its own Reconn subagent
- Each agent carries the `/reconn` skill instructions in its prompt, enabling self-dispatch

### Search Layers

1. **Codebase** — Grep, Glob, file reads across the project
2. **Web** — WebSearch, WebFetch for docs, API references, library patterns
3. **Notes** — QMD search for markdown knowledge bases, claude-mem search for prior decisions

### Standalone Usage

`/reconn` can be invoked independently outside of `/scout` for ad-hoc research tasks.

## Failure & Recovery

### Builder Failures

```
Builder fails on implementation:
  Attempt 1: Re-read error output, fix code, retry
  Attempt 2: Different approach, retry
  Attempt 3: Self-dispatch Reconn for research on the failure
  Attempt 4: Fix with Reconn's findings, retry
  Still failing: Write failure to result file -> Scout notifies user
```

Other builders continue working on their issues unblocked.

### Non-Builder Failures

```
Reconn fails:
  Scout retries once with a fresh agent/tab.
  If retry fails: Scout reports error, asks user how to proceed.

Architect fails:
  Scout retries once with a fresh agent/tab.
  If retry fails: Scout reports error, asks user how to proceed.

Slicer fails:
  Scout retries once with a fresh agent/tab.
  If retry fails: Scout reports error, asks user how to proceed.
```

All non-Builder agents get exactly one retry before escalating to the user.

## Context Handoff

All context passes through files, not agent memory:

| Artifact | Producer | Consumer |
|----------|----------|----------|
| `/tmp/scout-state.json` | Scout | All agents (state machine) |
| `/tmp/scout-task-<agent>.md` | Scout | Target agent (task input) |
| `/tmp/scout-result-<agent>.json` | Agent | Scout (completion signal) |
| `/tmp/scout-grill-summary.md` | Griller | Architect |
| `/tmp/scout-reconn-<topic>.md` | Reconn | Requesting agent |
| GitHub issues | Architect, Slicer | Slicer, Builders |
| Git branches | Builders | PRs |

## State Tracking

### State File Schema

```json
{
  "mode": "cmux | in-process",
  "phase": "GRILL | PRD | ISSUES | EXECUTE | DONE",
  "auto": false,
  "idea": "Add user profile endpoints with avatar upload",
  "grillSummary": "/tmp/scout-grill-summary.md",
  "prdIssue": null,
  "issues": [],
  "prs": [],
  "agents": {
    "reconn": { "surface": "surface:3", "status": "active" },
    "architect": { "surface": null, "status": "pending" }
  },
  "workspace": "workspace:1",
  "startedAt": "2026-03-16T23:00:00Z"
}
```

### Display Format

Scout displays state at each phase transition:

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

## Teardown

### Normal Completion

When Scout reaches DONE state:
1. Update all agent tab statuses to final (checkmark/X)
2. Close agent tabs (Reconn, Architect, Slicer, Builder-N)
3. Clean up `/tmp/scout-task-*` and `/tmp/scout-result-*` files
4. Preserve `/tmp/scout-state.json`, `/tmp/scout-grill-summary.md`, and `/tmp/scout-reconn-*` files (useful for reference)
5. Display final summary in Scout tab

### Crash Recovery

If Scout is re-invoked and `/tmp/scout-state.json` exists with a non-DONE phase:
1. Scout reads the state file
2. Reports what phase was in progress and what completed
3. Asks user: resume from current phase, or start over?
4. If resuming: skips completed phases, picks up from the last incomplete phase

## Migration Notes

Changes from the current `/scout` skill:
- Explore agents are replaced by the named **Reconn** agent
- In-process-only execution becomes cmux-aware with tab spawning
- Approval gates are preserved (with auto mode bypass option)
- Auto mode (`--auto`) is new
- Agent roster with names and colors is new
- File-based coordination protocol is new
- Failure recovery with Reconn-assisted healing is new

## Skills & Files to Create/Update

| File | Action | Description |
|------|--------|-------------|
| `~/.claude/skills/scout/SKILL.md` | Rewrite | Full orchestrator with agent roster, cmux integration, auto mode |
| `~/.claude/skills/reconn/SKILL.md` | Create | Deep research agent skill (standalone + embeddable) |
| `~/.claude/skills/execute-issues/SKILL.md` | Update | Add Builder agent naming, parallel tab spawning, Reconn self-dispatch |
