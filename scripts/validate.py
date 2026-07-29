#!/usr/bin/env python3
"""Validate cardano-dev-skills repo: SKILL.md files and sources.yaml."""

import sys
import re
import yaml
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
SOURCES_FILE = REPO_ROOT / "registry" / "sources.yaml"

MAX_SKILL_LINES = 500
MAX_NAME_LEN = 64
NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

VALID_CATEGORIES = {
    "infrastructure", "smart-contracts", "sdk", "standards",
    "governance", "scaling", "testing", "oracles",
}
VALID_FORMATS = {"markdown", "mdx", "rst", "openapi", "aiken", "python", "toml"}
VALID_PRIORITIES = {"high", "medium", "low"}

# Tool-grant policy. `allowed-tools` entries are PRE-APPROVED (they skip the
# user's permission prompt for one turn), so widening this set is a security
# decision, not a convenience. Skills needing more than the read-only base
# set require an explicit entry in ALLOWED_TOOLS_EXCEPTIONS, reviewed in the
# same PR that adds it.
BASE_ALLOWED_TOOLS = {"Read", "Grep", "Glob"}
# Exceptions list only the EXTRA tools a skill needs beyond the base set;
# they are unioned with BASE_ALLOWED_TOOLS, so a skill never has to re-declare
# the read-only tools to gain one more.
ALLOWED_TOOLS_EXCEPTIONS = {
    # cardano-context writes the context block into the user's CLAUDE.md;
    # Bash is scoped to `pwd` (used to resolve the project root).
    "cardano-context": {"Edit", "Write", "Bash(pwd)"},
}
# Skills are self-contained (Read/Grep/Glob over bundled docs), so no skill
# turn ever needs network access. Requiring these keeps a poisoned doc read
# during a skill turn from reaching out.
REQUIRED_DISALLOWED_TOOLS = {"WebFetch", "WebSearch"}

errors: list[str] = []
warnings: list[str] = []


def error(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def parse_frontmatter(path: Path) -> dict | None:
    """Extract YAML frontmatter from a SKILL.md file."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        error(f"{path}: missing YAML frontmatter (must start with ---)")
        return None
    parts = text.split("---", 2)
    if len(parts) < 3:
        error(f"{path}: malformed frontmatter (missing closing ---)")
        return None
    try:
        return yaml.safe_load(parts[1])
    except yaml.YAMLError as e:
        error(f"{path}: invalid YAML frontmatter: {e}")
        return None


def validate_skill(skill_dir: Path) -> None:
    """Validate a single skill directory."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        error(f"{skill_dir}: missing SKILL.md")
        return

    # Check line count
    lines = skill_md.read_text(encoding="utf-8").splitlines()
    if len(lines) > MAX_SKILL_LINES:
        error(f"{skill_md}: {len(lines)} lines exceeds max {MAX_SKILL_LINES}")

    # Parse and validate frontmatter
    fm = parse_frontmatter(skill_md)
    if fm is None:
        return

    # Name validation
    name = fm.get("name")
    if not name:
        error(f"{skill_md}: frontmatter missing 'name'")
    elif not NAME_PATTERN.match(name):
        error(f"{skill_md}: name '{name}' must be kebab-case (lowercase, hyphens)")
    elif len(name) > MAX_NAME_LEN:
        error(f"{skill_md}: name '{name}' exceeds {MAX_NAME_LEN} chars")
    elif name != skill_dir.name:
        warn(f"{skill_md}: name '{name}' doesn't match directory '{skill_dir.name}'")

    # Description validation
    desc = fm.get("description")
    if not desc:
        error(f"{skill_md}: frontmatter missing 'description'")
    elif len(desc) > 1024:
        warn(f"{skill_md}: description is {len(desc)} chars (recommend < 1024)")

    # Tool-grant validation (see policy comment above BASE_ALLOWED_TOOLS)
    def parse_tools(value) -> list[str]:
        if value is None:
            return []
        if isinstance(value, list):
            return [str(t).strip() for t in value]
        # Split on whitespace/commas but NOT inside parentheses, so a scoped
        # grant like `Bash(git status)` stays one token.
        return re.findall(r"[^\s,()]+(?:\([^)]*\))?", str(value))

    permitted = BASE_ALLOWED_TOOLS | ALLOWED_TOOLS_EXCEPTIONS.get(
        skill_dir.name, set())
    allowed = parse_tools(fm.get("allowed-tools"))
    if not allowed:
        error(f"{skill_md}: frontmatter missing 'allowed-tools'")
    for tool in allowed:
        if tool not in permitted:
            error(
                f"{skill_md}: allowed-tools grants '{tool}', not permitted for "
                f"this skill (permitted: {sorted(permitted)}). Widening a grant "
                f"requires an ALLOWED_TOOLS_EXCEPTIONS entry in validate.py."
            )

    disallowed = set(parse_tools(fm.get("disallowed-tools")))
    missing = REQUIRED_DISALLOWED_TOOLS - disallowed
    if missing:
        error(
            f"{skill_md}: disallowed-tools must include {sorted(missing)} "
            f"(skills are self-contained; no network during skill turns)"
        )

    # Check required sections
    text = skill_md.read_text(encoding="utf-8").lower()
    for section in ["when to use", "when not to use", "workflow"]:
        if section not in text:
            warn(f"{skill_md}: missing recommended section '## {section.title()}'")

    # Check references exist if referenced
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref_file in refs_dir.iterdir():
            if ref_file.suffix not in (".md", ".txt", ".yaml", ".yml"):
                warn(f"{ref_file}: unexpected file type in references/")


def validate_sources() -> None:
    """Validate registry/sources.yaml."""
    if not SOURCES_FILE.exists():
        error(f"Missing {SOURCES_FILE}")
        return

    try:
        with open(SOURCES_FILE, encoding="utf-8") as f:
            sources = yaml.safe_load(f)
    except yaml.YAMLError as e:
        error(f"{SOURCES_FILE}: invalid YAML: {e}")
        return

    if not isinstance(sources, list):
        error(f"{SOURCES_FILE}: expected a list of sources at top level")
        return

    names_seen = set()
    for i, src in enumerate(sources):
        if not isinstance(src, dict):
            error(f"{SOURCES_FILE}[{i}]: expected a mapping, got {type(src).__name__}")
            continue

        prefix = f"{SOURCES_FILE}[{i}] ({src.get('name', '?')})"

        # Required fields
        for field in ("name", "repo", "docs_path", "format", "category", "priority"):
            if field not in src:
                error(f"{prefix}: missing required field '{field}'")

        name = src.get("name", "")
        if name in names_seen:
            error(f"{prefix}: duplicate source name '{name}'")
        names_seen.add(name)

        fmt = src.get("format")
        if fmt and fmt not in VALID_FORMATS:
            error(f"{prefix}: invalid format '{fmt}' (valid: {VALID_FORMATS})")

        cat = src.get("category")
        if cat and cat not in VALID_CATEGORIES:
            error(f"{prefix}: invalid category '{cat}' (valid: {VALID_CATEGORIES})")

        pri = src.get("priority")
        if pri and pri not in VALID_PRIORITIES:
            error(f"{prefix}: invalid priority '{pri}' (valid: {VALID_PRIORITIES})")

        repo = src.get("repo", "")
        if repo and not repo.startswith("https://"):
            warn(f"{prefix}: repo URL doesn't start with https://")


def main() -> int:
    print("Validating cardano-dev-skills...\n")

    # Validate skills (flat structure: skills/<skill-name>/SKILL.md)
    skill_count = 0
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if not skill_dir.is_dir() or skill_dir.name == "shared":
            continue
        if (skill_dir / "SKILL.md").exists():
            validate_skill(skill_dir)
            skill_count += 1

    # Validate sources
    validate_sources()

    # Report
    print(f"Skills validated: {skill_count}")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings:
            print(f"  WARNING: {w}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(f"  ERROR: {e}")
        print(f"\nValidation FAILED with {len(errors)} error(s).")
        return 1

    print("\nValidation PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
