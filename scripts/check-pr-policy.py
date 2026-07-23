#!/usr/bin/env python3
"""PR policy checks for cardano-dev-skills.

Compares a head ref against a base ref (both read via git plumbing — no PR
code is ever executed) and enforces the mechanically-checkable parts of
docs/CONTRIBUTING.md:

  1. Source vetting: every NEW entry in registry/sources.yaml must point to a
     GitHub repo that is not archived, pushed to within 6 months, and shows a
     release or issue/PR activity within 3 months (checked live via the
     GitHub API).
  2. Skill naming: a NEW skill named after a registered source/project brand
     fails (skills are task-oriented: build-transaction, connect-wallet, ...).
     Non-verb-first names produce a warning.
  3. Doc-bundle smells: NEW files under docs/sources/ whose names look like
     product/marketing pages, or that duplicate generic Cardano-101 content,
     produce warnings.

Failures exit 1; warnings alone exit 0. Judgment calls (the scope borderline
rule) are NOT decided here — they go to the advisory AI scope review.

Usage:
  python3 scripts/check-pr-policy.py                       # HEAD vs origin/main
  python3 scripts/check-pr-policy.py --base origin/main --head refs/remotes/pr/head
  python3 scripts/check-pr-policy.py --output-md report.md --github-output "$GITHUB_OUTPUT"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent

SOURCES_PATH = "registry/sources.yaml"
SKILLS_DIR = "skills"
DOCS_DIR = "docs/sources"

MAX_PUSH_AGE = timedelta(days=183)   # "last commit < 6 months"
MAX_ACTIVITY_AGE = timedelta(days=92)  # "activity in the last 3 months"

# First words of source names that are generic, not brands — a skill name
# containing one of these is not evidence of a brand-named skill.
GENERIC_BRAND_WORDS = {
    "cardano", "cip", "cips", "cip113", "smart", "developer", "ouroboros",
}

# Task verbs seen across the existing skill set; new skills should normally
# start with one (warning only — the convention, not a hard rule).
TASK_VERBS = {
    "build", "connect", "debug", "design", "explain", "optimize", "query",
    "review", "scaffold", "setup", "suggest", "write", "create", "deploy",
    "migrate", "test", "audit", "monetize", "integrate", "generate", "choose",
    "plan", "estimate", "monitor", "govern", "governance", "stake",
}

# Filename patterns that smell like marketing-only pages rather than
# developer documentation (CONTRIBUTING.md scope: marketing-only material is
# always out; operational pages of an integration-first project are fine).
SMELL_PATTERN = re.compile(
    r"(marketing|press|brand-assets|tokenomics|roadmap)", re.IGNORECASE)

# Basenames that duplicate generic Cardano-101 content already bundled from
# canonical sources (Cardano Docs, Developer Portal, CIPs).
GENERIC_101_PATTERN = re.compile(
    r"^(utxos?|wallets?|blockchain|tokens?|transaction-fees"
    r"|what-is-cardano)\.(md|mdx)$", re.IGNORECASE)

failures: list[str] = []
warnings: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


# ---------------------------------------------------------------- git helpers

def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=REPO_ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def git_show(ref: str, path: str) -> str | None:
    try:
        return git("show", f"{ref}:{path}")
    except RuntimeError:
        return None


def git_ls_dirs(ref: str, path: str) -> set[str]:
    try:
        out = git("ls-tree", "--name-only", ref, f"{path}/")
    except RuntimeError:
        return set()
    return {Path(line).name for line in out.splitlines() if line.strip()}


def git_ls_files(ref: str, path: str) -> set[str]:
    try:
        out = git("ls-tree", "-r", "--name-only", ref, f"{path}/")
    except RuntimeError:
        return set()
    return {line for line in out.splitlines() if line.strip()}


# ------------------------------------------------------------------- sources

def load_sources(ref: str) -> list[dict]:
    text = git_show(ref, SOURCES_PATH)
    if text is None:
        return []
    data = yaml.safe_load(text) or []
    if isinstance(data, dict):
        data = data.get("sources", []) or []
    return [entry for entry in data if isinstance(entry, dict)]


def parse_github_repo(url: str) -> tuple[str, str] | None:
    m = re.search(r"github\.com[:/]([^/]+)/([^/.]+?)(?:\.git)?/?$", url or "")
    return (m.group(1), m.group(2)) if m else None


def gh_api(path: str) -> object | None:
    """GET a GitHub API path; returns parsed JSON or None on any error."""
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={"Accept": "application/vnd.github+json",
                 "User-Agent": "cardano-dev-skills-policy-check"})
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.load(resp)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


def parse_iso(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def vet_source(entry: dict) -> None:
    """Apply the CONTRIBUTING.md source-vetting bar to one new entry."""
    name = entry.get("name", "<unnamed>")
    parsed = parse_github_repo(entry.get("repo", ""))
    if not parsed:
        warn(f"source `{name}`: repo is not a github.com URL — "
             "vetting bar must be verified manually in the PR")
        return
    owner, repo = parsed
    slug = f"{owner}/{repo}"

    info = gh_api(f"/repos/{slug}")
    if not isinstance(info, dict) or "archived" not in info:
        warn(f"source `{name}` ({slug}): could not query the GitHub API — "
             "verify the vetting bar manually (archived? last commit? activity?)")
        return

    now = datetime.now(timezone.utc)

    if info.get("archived"):
        fail(f"source `{name}` ({slug}): repository is ARCHIVED — "
             "fails vetting rule 3 (no archived/deprecated/sunset sources)")

    pushed_at = info.get("pushed_at")
    if pushed_at and now - parse_iso(pushed_at) > MAX_PUSH_AGE:
        fail(f"source `{name}` ({slug}): last push {pushed_at} is older than "
             "6 months — fails vetting rule 1")

    if info.get("fork"):
        warn(f"source `{name}` ({slug}): repo is a fork — vetting rule 4 "
             "requires justifying in the PR that this is the maintained canonical")

    # Rule 2: ≥1 release OR issue/PR activity in the last 3 months.
    releases = gh_api(f"/repos/{slug}/releases?per_page=1")
    if isinstance(releases, list) and releases:
        return
    issues = gh_api(f"/repos/{slug}/issues?state=all&sort=updated"
                    "&direction=desc&per_page=1")
    if isinstance(issues, list) and issues:
        updated = issues[0].get("updated_at")
        if updated and now - parse_iso(updated) <= MAX_ACTIVITY_AGE:
            return
    fail(f"source `{name}` ({slug}): no release tag and no issue/PR activity "
         "in the last 3 months — fails vetting rule 2")


# -------------------------------------------------------------------- skills

def collapse(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


def check_skill_name(skill: str, source_names: list[str]) -> bool:
    """Returns True if the skill was flagged as brand-named."""
    words = set(skill.split("-"))

    for source_name in source_names:
        first = collapse(source_name.split()[0]) if source_name.split() else ""
        if not first or first in GENERIC_BRAND_WORDS:
            continue
        if first in words or collapse(skill) == collapse(source_name):
            fail(
                f"skill `{skill}`: named after the project/brand "
                f"`{source_name}`. Skills are task-oriented "
                "(build-transaction, connect-wallet, ...) — name it after "
                "what the developer is trying to do (e.g. `monetize-agent`, "
                "`integrate-oracle`) and teach the project as the "
                "implementation inside it.")
            return True
    return False


def check_skill_content(skill: str, head_ref: str,
                        head_doc_dirs: set[str]) -> bool:
    """Content checks on a new skill's SKILL.md (read as data, not executed).

    Returns True if the skill was flagged as brand-named."""
    brand_flagged = False
    text = git_show(head_ref, f"{SKILLS_DIR}/{skill}/SKILL.md") or ""

    # Brand-named skill whose project is not in the registry: the skill's
    # leading word matching a GitHub org/repo slug it links to is strong
    # evidence the skill is named after that project.
    first = skill.split("-")[0]
    if (len(first) >= 4 and first not in GENERIC_BRAND_WORDS
            and first not in TASK_VERBS):
        linked_slugs = re.findall(r"github\.com/([A-Za-z0-9_.-]+)", text)
        if any(first in slug.lower() for slug in linked_slugs):
            fail(
                f"skill `{skill}`: name matches the GitHub project it links "
                "to — skills are task-oriented (build-transaction, "
                "connect-wallet, ...), not brand-named. Rename to the "
                "developer task and teach the project as the implementation "
                "inside it.")
            brand_flagged = True

    # References to bundled docs that don't exist in this PR's tree.
    for slug in sorted(set(re.findall(r"docs/sources/([a-z0-9_-]+)", text))):
        if slug not in head_doc_dirs:
            fail(
                f"skill `{skill}`: SKILL.md points to `docs/sources/{slug}/` "
                "but that directory does not exist in this PR — either add "
                "the source to registry/sources.yaml and bundle its docs, or "
                "drop the reference. Skills must be self-contained "
                "(Read/Grep/Glob over bundled content only).")
    return brand_flagged


# ---------------------------------------------------------------- docs files

def check_new_doc_file(path: str) -> None:
    basename = Path(path).name
    if SMELL_PATTERN.search(basename):
        warn(f"`{path}`: filename suggests marketing-only content — "
             "CONTRIBUTING.md scope always excludes marketing material; "
             "consider excluding it via `glob_patterns`")
    elif GENERIC_101_PATTERN.match(basename):
        warn(f"`{path}`: looks like generic Cardano-101 content already "
             "covered by canonical sources (Cardano Docs, Developer Portal, "
             "CIPs) — consider excluding it via `glob_patterns`")


# --------------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main",
                        help="base git ref (default: origin/main)")
    parser.add_argument("--head", default="HEAD",
                        help="head git ref to check (default: HEAD)")
    parser.add_argument("--output-md", metavar="PATH",
                        help="also write a markdown report to PATH")
    parser.add_argument("--github-output", metavar="PATH",
                        help="write new_sources=/new_skills= counts to PATH "
                             "(for $GITHUB_OUTPUT)")
    args = parser.parse_args()

    base_sources = load_sources(args.base)
    head_sources = load_sources(args.head)
    base_names = {s.get("name") for s in base_sources}
    new_sources = [s for s in head_sources if s.get("name") not in base_names]

    new_skills = sorted(git_ls_dirs(args.head, SKILLS_DIR)
                        - git_ls_dirs(args.base, SKILLS_DIR))
    new_docs = sorted(git_ls_files(args.head, DOCS_DIR)
                      - git_ls_files(args.base, DOCS_DIR))

    for entry in new_sources:
        vet_source(entry)

    all_source_names = [s.get("name", "") for s in head_sources]
    head_doc_dirs = git_ls_dirs(args.head, DOCS_DIR)
    for skill in new_skills:
        if skill == "shared":
            continue
        brand_a = check_skill_name(skill, all_source_names)
        brand_b = check_skill_content(skill, args.head, head_doc_dirs)
        if not (brand_a or brand_b) and skill.split("-")[0] not in TASK_VERBS:
            warn(f"skill `{skill}`: name does not start with a task verb — "
                 "the convention is verb-first, task-oriented names "
                 "(build-, explain-, setup-, ...)")

    for path in new_docs:
        check_new_doc_file(path)

    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as fh:
            fh.write(f"new_sources={len(new_sources)}\n")
            fh.write(f"new_skills={len(new_skills)}\n")

    lines = [f"## PR policy check ({args.base} → {args.head})", ""]
    lines.append(f"New sources: {len(new_sources)} · new skills: "
                 f"{len(new_skills)} · new bundled doc files: {len(new_docs)}")
    lines.append("")
    if failures:
        lines.append("### ❌ Failures (policy violations)")
        lines += [f"- {f}" for f in failures] + [""]
    if warnings:
        lines.append("### ⚠️ Warnings (verify in review)")
        lines += [f"- {w}" for w in warnings] + [""]
    if not failures and not warnings:
        lines.append("✅ No mechanical policy issues found.")
    report = "\n".join(lines)

    print(report)
    if args.output_md:
        Path(args.output_md).write_text(report + "\n", encoding="utf-8")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
