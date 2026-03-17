# Scout Skills

An agent orchestrator for Claude Code that takes ideas from concept to shipped PRs.

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **Scout** | `/scout` | End-to-end orchestrator — grill, PRD, issues, execute |
| **Reconn** | `/reconn` | Deep research agent — codebase, web, notes |
| **Execute Issues** | `/execute-issues` | Implement GitHub issues with verified PRs |

## Agent Roster

| Agent | Color | Role |
|-------|-------|------|
| Scout | 🟠 Orange | Orchestrator — manages phases, state, handoffs |
| Griller | 🔴 Red | Interviews user via `/grill-me` protocol |
| Reconn | 🟡 Yellow | Deep research — codebase, web, QMD, claude-mem |
| Architect | 🔵 Blue | Writes PRD via `/write-a-prd` |
| Slicer | 🟣 Purple | Breaks PRD into issues via `/prd-to-issues` |
| Builder-N | 🟢 Green | Executes issues — one per parallel issue |

## Installation

Copy (or symlink) skills into your Claude Code skills directory:

```bash
# Symlink each skill
ln -s $(pwd)/skills/scout ~/.claude/skills/scout
ln -s $(pwd)/skills/reconn ~/.claude/skills/reconn
ln -s $(pwd)/skills/execute-issues ~/.claude/skills/execute-issues
```

## Usage

```
# Full pipeline (interactive)
/scout Add a user profile API with avatar upload

# Full pipeline (autonomous)
/scout --auto Add a user profile API with avatar upload

# Standalone research
/reconn How does authentication work in this project?

# Execute existing issues
/execute-issues
```

## Features

- **cmux integration** — auto-detects cmux and spawns color-coded tabs per agent
- **Auto mode** — runs autonomously with Reconn compensating for skipped grilling
- **Crash recovery** — resumes interrupted sessions from state file
- **Reconn-assisted failure recovery** — builders self-dispatch research agents on failure
- **Wave-based parallel execution** — independent issues execute simultaneously

## Dependencies

These skills reference other Claude Code skills that should be installed separately:

- `/grill-me` — used by Scout's Griller agent
- `/write-a-prd` — used by Scout's Architect agent
- `/prd-to-issues` — used by Scout's Slicer agent

## Docs

- [Design Spec](docs/DESIGN.md) — full architecture and design decisions
