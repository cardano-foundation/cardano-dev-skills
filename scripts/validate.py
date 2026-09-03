#!/usr/bin/env python3
"""Validate cardano-dev-skills repo: SKILL.md files and sources.yaml."""

import argparse
import subprocess
import sys
import re
from pathlib import Path

# Only the skill/registry checks need pyyaml. `--paths-only` must stay
# runnable on a bare python3 so the refresh workflow can gate on path
# portability without installing anything.
try:
    import yaml
except ModuleNotFoundError:
    yaml = None

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
SOURCES_FILE = REPO_ROOT / "registry" / "sources.yaml"
DOCS_SOURCES_DIR = REPO_ROOT / "docs" / "sources"

MAX_SKILL_LINES = 500
MAX_NAME_LEN = 64
NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

# Windows path portability (issue #36). git aborts the ENTIRE checkout when a
# tree contains a path Windows can't create — not just that file — so one bad
# name locks every Windows user out of the repo. `scripts/_fetch_docs.py`
# normalizes these at fetch time; this check is the backstop for hand-added
# files and for snapshots fetched before that logic existed.
# Backslash is included because it is a legal POSIX filename character but a
# path separator on Windows — it breaks the checkout while looking harmless
# in a Linux-side review.
WIN_ILLEGAL_CHARS_RE = re.compile(r'[<>:"|?*\\\x00-\x1f]')
WIN_RESERVED_NAMES = (
    {"con", "prn", "aux", "nul"}
    | {f"com{i}" for i in range(1, 10)}
    | {f"lpt{i}" for i in range(1, 10)}
)
# Windows' default MAX_PATH is 260 chars including the clone directory, so a
# repo-relative path this long is a warning, not yet a failure.
MAX_PORTABLE_PATH_LEN = 200

VALID_CATEGORIES = {
    "infrastructure", "smart-contracts", "sdk", "standards",
    "governance", "scaling", "testing", "oracles",
}
VALID_FORMATS = {"markdown", "mdx", "rst", "openapi", "aiken", "python", "toml",
                 "go"}
VALID_PRIORITIES = {"high", "medium", "low"}

# Vetting-waiver policy. A `vetting_exception` on a registry entry waives the
# recency/activity rules (1-2) of the source-vetting bar for document-of-
# record repos, where commit cadence says nothing about health. Waiving the
# bar is a security decision, so it requires an explicit entry here, reviewed
# in the same PR that adds it — a reason string alone is self-service.
# Keyed name -> owner/repo: `name` is contributor-chosen free text, so a
# name-only grant would follow an entry to whatever upstream it is later
# repointed at. The waiver takes effect in scripts/check-pr-policy.py.
VETTING_EXCEPTIONS: dict[str, str] = {
}

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


def check_snapshot_matches_globs(prefix: str, name: str, src: dict) -> None:
    """Flag a source whose glob patterns appear to match nothing upstream.

    `glob_patterns` is include-only and silent: a pattern matching zero files
    produces exactly the same snapshot as a project that genuinely ships one
    README, so a mis-specified pattern can sit undetected indefinitely. That is
    how `cardano-client-lib` and `Yaci Store` each spent months vendored as a
    README while their real documentation — 66 and 85 pages — sat behind a
    `docs/**/*.md` glob against upstreams whose pages are all `.mdx`.

    The signal used here is intent versus result: a recursive glob says the
    source expects a documentation *tree*, so a snapshot holding at most a
    README means the pattern did not find it. Warn rather than error — a source
    can legitimately be mid-migration upstream, and this check must never block
    a refresh on its own.
    """
    globs = [str(p) for p in (src.get("glob_patterns") or [])]
    tree_globs = [p for p in globs if "**" in p]
    if not (name and tree_globs):
        return

    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    snapshot = DOCS_SOURCES_DIR / slug
    if not snapshot.is_dir():
        return

    file_count = sum(1 for p in snapshot.rglob("*") if p.is_file())
    if file_count > 1:
        return

    warn(
        f"{prefix}: requests a documentation tree ({', '.join(tree_globs)}) "
        f"but docs/sources/{slug}/ holds {file_count} file(s) — the pattern "
        f"probably matches nothing upstream. Check the file extension "
        f"(.md vs .mdx) and the directory the docs actually live in."
    )


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

        if "vetting_exception" in src:
            check_vetting_exception(prefix, name, repo, src["vetting_exception"])

        check_snapshot_matches_globs(prefix, name, src)


def check_vetting_exception(prefix: str, name: str, repo: str, reason) -> None:
    """A `vetting_exception` is valid only when granted in VETTING_EXCEPTIONS
    for this name AND this repo, and carries a non-empty reason."""
    granted = VETTING_EXCEPTIONS.get(name)
    if granted is None:
        error(f"{prefix}: carries vetting_exception but is not granted one in "
              "VETTING_EXCEPTIONS in scripts/validate.py — waiving the "
              "maintenance bar is a reviewed code change, not a registry field")
        return
    # GitHub owner/repo slugs are case-insensitive.
    slug = (repo or "").removeprefix("https://github.com/").rstrip("/")
    if slug.endswith(".git"):
        slug = slug[:-4]
    if slug.lower() != granted.lower():
        error(f"{prefix}: vetting_exception was granted for {granted}, not "
              f"{slug or repo!r} — repointing a waived entry needs the grant "
              "updated in the same PR")
    if not (isinstance(reason, str) and reason.strip()):
        error(f"{prefix}: vetting_exception must be a non-empty reason string")


def validate_path_portability() -> int:
    """Check every tracked path can be checked out on Windows.

    Returns the number of paths checked (0 if git isn't usable here)."""
    try:
        result = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "ls-files", "-z"],
            capture_output=True, text=True, timeout=60, check=True)
    except (OSError, subprocess.SubprocessError):
        warn("could not run 'git ls-files' — skipped Windows path portability check")
        return 0

    paths = [p for p in result.stdout.split("\0") if p]
    seen: dict[str, str] = {}

    for path in paths:
        for part in path.split("/"):
            bad = sorted(set(WIN_ILLEGAL_CHARS_RE.findall(part)))
            if bad:
                shown = ", ".join(repr(c) for c in bad)
                error(f"{path}: path component '{part}' contains {shown}, "
                      f"illegal on Windows — git cannot check out this repo there")
            if part != part.rstrip(" ."):
                error(f"{path}: path component '{part}' ends in a space or dot, "
                      f"which Windows strips — leaves the worktree permanently dirty")
            if part.split(".", 1)[0].lower() in WIN_RESERVED_NAMES:
                error(f"{path}: path component '{part}' is a reserved Windows "
                      f"device name")

        # Windows filesystems are case-insensitive: two paths differing only
        # in case collapse onto one file on checkout.
        key = path.casefold()
        if key in seen:
            error(f"{path}: collides case-insensitively with {seen[key]} — "
                  f"these cannot coexist on a Windows filesystem")
        else:
            seen[key] = path

        if len(path) > MAX_PORTABLE_PATH_LEN:
            warn(f"{path}: {len(path)} chars — risks exceeding Windows' "
                 f"260-char MAX_PATH once the clone directory is prepended")

    return len(paths)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--paths-only", action="store_true",
        help="run only the Windows path-portability check. Used by the docs "
             "refresh workflow: a refresh must not be blocked by an unrelated "
             "skill or registry error, and this mode needs no pyyaml.")
    args = parser.parse_args()

    print("Validating cardano-dev-skills...\n")

    skill_count = 0
    if not args.paths_only:
        if yaml is None:
            print("ERROR: pyyaml is required for the skill and registry "
                  "checks (pip install pyyaml), or pass --paths-only.")
            return 1

        # Validate skills (flat structure: skills/<skill-name>/SKILL.md)
        for skill_dir in sorted(SKILLS_DIR.iterdir()):
            if not skill_dir.is_dir() or skill_dir.name == "shared":
                continue
            if (skill_dir / "SKILL.md").exists():
                validate_skill(skill_dir)
                skill_count += 1

        # Validate sources
        validate_sources()

    # Validate that every tracked path is checkout-safe on Windows
    path_count = validate_path_portability()

    # Report
    if not args.paths_only:
        print(f"Skills validated: {skill_count}")
    print(f"Paths checked for Windows portability: {path_count}")

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
