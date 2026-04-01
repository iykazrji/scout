---
name: ui-designer:settings
description: Configure UI Designer agent settings — quality profile, execution mode, and cmux preference. Opens an interactive menu.
---

# /ui-designer:settings — UI Designer Settings Menu

Opens an interactive settings menu for configuring the UI Designer's behavior.

## On Invocation

1. Read `~/.claude/skills/ui-designer/settings.json`. If it doesn't exist, use defaults: `{"quality":"balanced","mode":"interactive","cmux":"auto"}`
2. Walk through each setting using `AskUserQuestion`, one at a time
3. Save updated settings to `~/.claude/skills/ui-designer/settings.json`

## Step 1: Quality Profile

Use `AskUserQuestion`:

Title: "DESIGNER SETTINGS (1/3) — Quality Profile"
Description: "Controls which model each agent uses."

Show a table in the question text:

```
| Agent       | high   | balanced | budget |
|-------------|--------|----------|--------|
| Designer    | opus   | opus     | sonnet |
| Griller     | opus   | opus     | sonnet |
| Reconn      | opus   | sonnet   | sonnet |
| Stylist     | opus   | opus     | sonnet |
| Specifier   | opus   | sonnet   | sonnet |
| Inspector   | sonnet | sonnet   | sonnet |
```

Options (mark current with `(current)`):
- `high` — opus everywhere except Inspector (best quality, highest cost)
- `balanced` — opus for creative work, sonnet for execution (recommended)
- `budget` — sonnet everywhere (fastest, lowest cost)

## Step 2: Execution Mode

Use `AskUserQuestion`:

Title: "DESIGNER SETTINGS (2/3) — Execution Mode"
Description: "Controls how much human interaction is required."

Show a table in the question text:

```
| Behavior                | interactive        | express             | auto              |
|-------------------------|--------------------|---------------------|-------------------|
| Grill interview         | Full               | Skipped             | Skipped           |
| Grill approval gate     | Yes                | Skipped             | Skipped           |
| Reconn research         | Yes                | Yes (auto-scoped)   | Yes (auto-scoped) |
| Design system approval  | Yes (iterative)    | Yes (single gate)   | Auto-approved     |
| Screen spec approval    | Yes (per-screen)   | Yes (per-screen)    | Auto-approved     |
| Verification results    | Yes                | Auto-approved       | Pause for approval|
| Handoff                 | Yes                | Yes                 | Yes               |
```

Options (mark current with `(current)`):
- `interactive` — approval gates at every phase transition (default)
- `express` — skip grill, pause at design and spec approval
- `auto` — fully autonomous, pause only at final verification

## Step 3: cmux

Use `AskUserQuestion`:

Title: "DESIGNER SETTINGS (3/3) — cmux Tab Spawning"
Description: "Controls whether agents get their own terminal tabs."

Options (mark current with `(current)`):
- `auto` — detect cmux on startup, use tabs if available
- `on` — always spawn cmux tabs (fails if cmux not running)
- `off` — always run in-process, no tabs

## Step 4: Save and Confirm

Write the updated settings to `~/.claude/skills/ui-designer/settings.json`:

```bash
echo '{"quality":"<value>","mode":"<value>","cmux":"<value>"}' > ~/.claude/skills/ui-designer/settings.json
```

Display the summary showing what changed:

```
Settings saved to ~/.claude/skills/ui-designer/settings.json

  Quality: balanced → high
  Mode: interactive → express
  cmux: auto (unchanged)
```

Only show the arrow for values that changed. Show "(unchanged)" for values that stayed the same.
