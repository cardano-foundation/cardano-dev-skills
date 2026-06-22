#!/usr/bin/env bash
#
# update-doc-counts.sh — Auto-derive count placeholders in CLAUDE.md and README.md
#                       from disk state. Run after adding/removing skills or sources.
#
# Sentinel format (inline HTML comments — invisible when rendered on GitHub):
#   <!-- COUNT:skills -->14<!-- /COUNT:skills -->
#   <!-- COUNT:sources -->55<!-- /COUNT:sources -->
#
# CI runs this in --check mode; drift fails the build.
#
# Usage:
#   ./scripts/update-doc-counts.sh           # update in place
#   ./scripts/update-doc-counts.sh --check   # exit non-zero if any file would change

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

SKILLS_DIR="$REPO_ROOT/skills"
DOCS_DIR="$REPO_ROOT/docs/sources"
SOURCES_YAML="$REPO_ROOT/registry/sources.yaml"

MODE="write"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
fi

skills_count=$(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
sources_count=$(grep -cE "^- name:" "$SOURCES_YAML" 2>/dev/null || echo 0)

TARGETS=("$REPO_ROOT/CLAUDE.md" "$REPO_ROOT/README.md")

drift=0

for file in "${TARGETS[@]}"; do
  [ -f "$file" ] || continue

  updated=$(python3 - "$file" "$skills_count" "$sources_count" <<'PY'
import re, sys
path, skills, sources = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    original = f.read()
new = original
new = re.sub(r'<!-- COUNT:skills -->.*?<!-- /COUNT:skills -->',
             f'<!-- COUNT:skills -->{skills}<!-- /COUNT:skills -->', new)
new = re.sub(r'<!-- COUNT:sources -->.*?<!-- /COUNT:sources -->',
             f'<!-- COUNT:sources -->{sources}<!-- /COUNT:sources -->', new)
print(new, end='')
PY
)
  current=$(cat "$file")
  if [ "$updated" != "$current" ]; then
    drift=1
    if [ "$MODE" = "write" ]; then
      printf '%s' "$updated" > "$file"
      echo "Updated: $file"
    else
      echo "Drift detected: $file"
    fi
  fi
done

echo ""
echo "Counts:"
echo "  skills:  $skills_count"
echo "  sources: $sources_count"

if [ "$MODE" = "check" ] && [ "$drift" -ne 0 ]; then
  echo ""
  echo "ERROR: --check failed. Run 'scripts/update-doc-counts.sh' to refresh." >&2
  exit 1
fi
