# Scout Skills

An agent orchestrator for Claude Code that takes ideas from concept to shipped PRs. Scout manages a roster of specialized, color-coded agents through a 4-phase pipeline: interrogation, PRD creation, issue breakdown, and parallel execution.

## What It Does

You give Scout a raw idea. It:

1. **Grills you** on the design until every decision is resolved (Reconn researches your codebase first)
2. **Writes a PRD** and submits it as a GitHub issue
3. **Estimates the cost** of implementation and lets you adjust scope or budget
4. **Breaks the PRD** into vertical-slice GitHub issues
5. **Executes every issue** in parallel — creating branches, implementing, testing, and opening PRs

The result is a set of verified, ready-to-merge pull requests.

## Agent Roster

| Agent | Icon | Role | Runs In |
|-------|------|------|---------|
| **Scout** | 🟠 | Orchestrator — manages phases, state, handoffs | Original tab |
| **Griller** | 🔴 | Interviews user via `/grill-me` protocol | Scout tab |
| **Reconn** | 🟡 | Deep research — codebase, web, QMD, claude-mem | cmux tab |
| **Architect** | 🔵 | Writes PRD via `/write-a-prd` | cmux tab |
| **Bursar** | 💰 | Estimates token cost, presents budget options | Scout tab |
| **Slicer** | 🟣 | Breaks PRD into vertical-slice issues | cmux tab |
| **Builder-N** | 🟢 | Implements issues — one per parallel issue | cmux tab |
| **Designer** | 🩷 | UI design orchestrator for UI-heavy PRDs | cmux tab |

## Installation

### Quick install (symlinks)

```bash
git clone https://github.com/iykazrji/scout-skills.git
cd scout-skills

# Symlink each skill into Claude Code
ln -s "$(pwd)/skills/scout" ~/.claude/skills/scout
ln -s "$(pwd)/skills/reconn" ~/.claude/skills/reconn
ln -s "$(pwd)/skills/execute-issues" ~/.claude/skills/execute-issues
```

### Manual install (copy)

```bash
git clone https://github.com/iykazrji/scout-skills.git
cp -r scout-skills/skills/scout ~/.claude/skills/scout
cp -r scout-skills/skills/reconn ~/.claude/skills/reconn
cp -r scout-skills/skills/execute-issues ~/.claude/skills/execute-issues
```

### Verify installation

After installing, start a new Claude Code session and type `/scout` — you should see the skill activate.

## Usage

### Full pipeline

```bash
# Interactive mode (default) — approval gates at every phase
/scout Add a user profile API with avatar upload

# Yolo mode — you shape the design, then Scout builds everything
/scout --yolo Add real-time notifications with WebSocket support

# Auto mode — fully autonomous, skips grilling
/scout --auto Add pagination to the /users endpoint
```

### Standalone skills

```bash
# Deep research on a topic
/reconn How does authentication work in this project?

# Execute existing GitHub issues
/execute-issues

# Configure quality profile, execution mode, cmux preference
/scout:settings
```

### Execution Modes

| Mode | Grill | Approvals | Best For |
|------|-------|-----------|----------|
| `interactive` | Yes | All gates | Learning the system, high-stakes features |
| `yolo` | Yes | Grill only (last stop) | Day-to-day development — shape it, then ship it |
| `auto` | Skipped | None | Simple/well-defined tasks, batch work |

### Quality Profiles

Control cost vs quality by choosing which models agents use:

| Profile | Scout/Architect | Reconn/Slicer/Builders | Bursar |
|---------|----------------|----------------------|--------|
| `high` | opus | opus | sonnet |
| `balanced` | opus | sonnet | sonnet |
| `budget` | sonnet | sonnet | haiku |

Configure with `/scout:settings` or directly in `~/.claude/skills/scout/settings.json`.

### Cost Estimation (Bursar)

After the PRD is written, the Bursar agent estimates the token cost of the remaining work and presents options:

- **Proceed** — continue with current profile and full scope
- **Scale down** — remove features to reduce cost
- **Budget mode** — switch to cheaper models
- **Both** — scale down and switch to budget mode

In `yolo` mode, Bursar auto-proceeds unless the estimate exceeds $10. In `auto` mode, it logs silently.

## Features

- **cmux integration** — auto-detects cmux and spawns color-coded tabs per agent
- **Technology detection** — auto-detects Flutter, React Native, Expo, Next.js, React, Express, Fastify and injects framework-specific best practices into every agent
- **Cost estimation** — Bursar estimates token spend before execution, with options to adjust
- **Three execution modes** — interactive, yolo (shape then ship), auto (fully autonomous)
- **Quality profiles** — high, balanced, budget — control cost vs capability per agent
- **Crash recovery** — resumes interrupted sessions from `/tmp/scout-state.json`
- **Failure recovery** — builders self-dispatch Reconn research agents on implementation failures
- **Wave-based parallel execution** — independent issues execute simultaneously
- **UI design pipeline** — optional Designer agent for UI-heavy PRDs with visual verification

## Skills Included

| Skill | Command | Description |
|-------|---------|-------------|
| **Scout** | `/scout` | End-to-end orchestrator — grill, PRD, cost estimate, issues, execute |
| **Reconn** | `/reconn` | Deep research agent — codebase, web, notes |
| **Execute Issues** | `/execute-issues` | Implement GitHub issues with verified PRs |

## Dependencies

These skills reference other Claude Code skills that should be installed separately:

| Skill | Used By | Purpose |
|-------|---------|---------|
| `/grill-me` | Griller agent | Technical interrogation protocol |
| `/write-a-prd` | Architect agent | PRD writing and GitHub issue creation |
| `/prd-to-issues` | Slicer agent | Vertical-slice issue breakdown |
| `/ui-designer` | Designer agent (optional) | UI design specs for UI-heavy PRDs |

## Docs

- [Design Spec](docs/DESIGN.md) — full architecture and design decisions
- [Visual Overview](docs/scout-overview.html) — interactive HTML page showing agent roster, pipeline flow, cost model, and execution modes

## License

MIT
