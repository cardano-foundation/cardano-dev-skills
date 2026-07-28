#!/usr/bin/env bash
#
# new-skill.sh - Scaffold a new skill from template
#
# Usage:
#   ./scripts/new-skill.sh <skill-name>
#
# Example:
#   ./scripts/new-skill.sh audit-plutus
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_ROOT/skills"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <skill-name>"
  echo ""
  echo "Example: $0 audit-plutus"
  exit 1
fi

SKILL_NAME="$1"

# Validate name (kebab-case, max 64 chars)
if ! echo "$SKILL_NAME" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "Error: skill name must be kebab-case (lowercase letters, numbers, hyphens)" >&2
  exit 1
fi

if [ ${#SKILL_NAME} -gt 64 ]; then
  echo "Error: skill name must be 64 characters or less" >&2
  exit 1
fi

SKILL_DIR="$SKILLS_DIR/$SKILL_NAME"

if [ -d "$SKILL_DIR" ]; then
  echo "Error: skill directory already exists: $SKILL_DIR" >&2
  exit 1
fi

# Create directories
mkdir -p "$SKILL_DIR/references"

# Create SKILL.md
cat > "$SKILL_DIR/SKILL.md" << 'TEMPLATE'
---
name: SKILL_NAME_PLACEHOLDER
description: >-
  TODO: Describe what this skill does. Include 3-5 trigger phrases
  that users would naturally say to invoke this skill.
allowed-tools: Read Grep Glob
disallowed-tools: WebFetch WebSearch
---

# SKILL_NAME_PLACEHOLDER

## When to use

- TODO: List specific scenarios that trigger this skill

## When NOT to use

- TODO: List scenarios where another skill is more appropriate

## Key principles

- TODO: List 3-6 domain-specific principles
- See shared/PRINCIPLES.md for cross-cutting safety guidelines

## Workflow

### Step 1: Understand the request

TODO: Describe the first step.

### Step 2: Research

TODO: Describe how to find relevant information.

### Step 3: Deliver

TODO: Describe what to produce.

## References

- See [shared/PRINCIPLES.md](../shared/PRINCIPLES.md) for safety guidelines
TEMPLATE

# Replace placeholder with actual name
sed -i '' "s/SKILL_NAME_PLACEHOLDER/$SKILL_NAME/g" "$SKILL_DIR/SKILL.md"

echo "Created skill scaffold at: $SKILL_DIR"
echo ""
echo "Files created:"
echo "  $SKILL_DIR/SKILL.md"
echo "  $SKILL_DIR/references/ (empty, add reference docs as needed)"
echo ""
echo "Next steps:"
echo "  1. Edit $SKILL_DIR/SKILL.md - fill in the TODO sections"
echo "  2. Add reference docs to $SKILL_DIR/references/ if needed"
echo "  3. Run: python3 scripts/validate.py"
