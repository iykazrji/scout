#!/bin/bash
# Install scout sub-skills as standalone commands
# Run from ~/.claude/skills/scout/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")"

for skill in "$SCRIPT_DIR"/skills/*/; do
  name=$(basename "$skill")
  target="$SKILLS_DIR/$name"
  if [ -L "$target" ] || [ -d "$target" ]; then
    echo "SKIP: $name (already exists)"
  else
    ln -s "scout/skills/$name" "$target"
    echo "OK: /$name -> /scout:$name"
  fi
done

echo ""
echo "Done. Sub-skills are now available as standalone commands."
