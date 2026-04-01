# Scout Skills — Development Guide

## Repo Location

`~/.claude/skills/scout/` — the git repo for the orchestrator.

Sub-skills live as **standalone directories** at `~/.claude/skills/<name>/` and are **symlinked into scout** so they're shared.

## Structure

```
~/.claude/skills/
├── scout/                      ← git repo
│   ├── SKILL.md                ← /scout orchestrator
│   ├── settings.md             ← /scout:settings
│   ├── settings.json           ← user config (gitignored)
│   ├── overview.html
│   ├── CLAUDE.md, README.md, .gitignore
│   ├── docs/
│   ├── reconn -> ../reconn              ← symlink
│   ├── grill-me -> ../grill-me          ← symlink
│   ├── write-a-prd -> ../write-a-prd    ← symlink
│   ├── prd-to-issues -> ../prd-to-issues
│   ├── execute-issues -> ../execute-issues
│   ├── ui-designer -> ../ui-designer
│   ├── agent-device -> ../agent-device
│   ├── senior-architect -> ../senior-architect
│   ├── flutter-expert -> ../flutter-expert
│   ├── react-best-practices -> ../react-best-practices
│   ├── react-native-best-practices -> ...
│   ├── rn-animations-performance -> ...
│   ├── using-react-native-skia -> ...
│   ├── expressjs-best-practices -> ...
│   └── fastify-best-practices -> ...
├── reconn/SKILL.md             ← standalone /reconn
├── grill-me/SKILL.md           ← standalone /grill-me
├── write-a-prd/SKILL.md        ← standalone /write-a-prd
├── prd-to-issues/SKILL.md
├── execute-issues/SKILL.md
├── ui-designer/
├── agent-device/
├── senior-architect/
├── flutter-expert/
├── react-best-practices/
└── ... (remaining knowledge skills)
```

## How It Works

- Each skill is a **real directory** at `~/.claude/skills/<name>/` — invokable standalone as `/<name>`
- Scout contains **relative symlinks** (`../reconn`, `../grill-me`, etc.) — making them also available as `/scout:<name>`
- Git tracks the symlinks, so cloning the repo preserves the link structure

## Adding a New Skill

1. Create the standalone skill: `~/.claude/skills/<new-skill>/SKILL.md`
2. Symlink it into scout:
   ```bash
   cd ~/.claude/skills/scout
   ln -s ../<new-skill> <new-skill>
   ```
3. Commit and push:
   ```bash
   git add <new-skill> && git commit -m "feat: link <new-skill>" && git push origin main
   ```

## Editing Skills

Edit the **standalone directory** at `~/.claude/skills/<name>/`. Changes are visible through the symlink in scout automatically.

Note: only scout's own files (SKILL.md, settings.md, docs/, etc.) are tracked by git. The symlinked skills are tracked as symlink references, not file contents.

## Conventions

- **`settings.json` is gitignored** — user-specific runtime config.
- **Symlinks use relative paths** (`../reconn`) so the structure is portable.
- **Skills are independent** — removing a symlink from scout doesn't delete the standalone skill.
