#!/usr/bin/env python3
"""Turn a weekly docs refresh into one commit per changed source.

Run by refresh-docs.yml after `fetch-docs.sh --update-pins --manifest-out M`
has rewritten docs/sources/ and registry/pins.yaml in the working tree.
Each changed source becomes one commit bumping its doc files together with
its pin line, so a bad upstream delta can be reverted per source with a
single `git revert`. Sources whose pin moved without any doc-file change
are batched into one trailing commit; the docs manifest goes last.

Writes a per-source summary table (markdown) for the PR body.

Usage:
  python3 scripts/_commit_refresh.py --manifest /tmp/manifest.json \
      [--pins-file registry/pins.yaml] [--summary-out /tmp/summary.md]
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = "docs/sources"


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=REPO_ROOT,
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def dirty(path: str) -> bool:
    return bool(git("status", "--porcelain", "--", path).strip())


def _pin_name(line: str) -> str | None:
    m = re.match(r'^"(.+)":\s*[0-9a-f]+\s*$', line)
    return m.group(1) if m else None


def set_pin(pins_path: Path, name: str, sha: str) -> None:
    """Update (or insert) one source's pin line, leaving the rest alone.

    Insert position is chosen by comparing bare source *names*, matching the
    name-sorted order write_pins() produces — comparing whole lines instead
    put prefix pairs (e.g. "Aiken" vs "Aiken Stdlib") out of order and left
    the file perpetually dirty."""
    text = pins_path.read_text(encoding="utf-8") if pins_path.exists() else ""
    lines = text.splitlines(keepends=True)
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"
    entry = f'"{name}": {sha}\n'
    for i, line in enumerate(lines):
        if _pin_name(line) == name:
            lines[i] = entry
            break
    else:
        insert_at = len(lines)
        for i, line in enumerate(lines):
            other = _pin_name(line)
            if other is not None and other > name:
                insert_at = i
                break
        lines.insert(insert_at, entry)
    pins_path.write_text("".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--pins-file", default="registry/pins.yaml")
    parser.add_argument("--summary-out")
    args = parser.parse_args()

    records = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    pins_path = REPO_ROOT / args.pins_file

    # a stray staged file must never ride along in a per-source commit
    git("reset", "-q")

    # fetch wrote the fully-updated pins file; rebuild it incrementally so
    # each per-source commit carries exactly its own pin bump. Tolerate a
    # missing or previously-untracked pins file (first refresh / bootstrap).
    new_pins = pins_path.read_text(encoding="utf-8") if pins_path.exists() else ""
    tracked = bool(git("ls-files", "--", args.pins_file).strip())
    if tracked:
        git("checkout", "--", args.pins_file)
    elif pins_path.exists():
        pins_path.unlink()  # untracked: reset to "absent", rebuilt per source

    summary_rows = []
    pin_only = []

    for rec in sorted(records, key=lambda r: r["slug"]):
        slug_path = f"{DOCS_DIR}/{rec['slug']}"
        moved = rec["old_sha"] != rec["new_sha"]
        if not dirty(slug_path):
            if moved:
                pin_only.append(rec)
            continue

        set_pin(pins_path, rec["name"], rec["new_sha"])
        git("add", "--", args.pins_file, slug_path)
        stat = git("diff", "--cached", "--shortstat").strip()
        old = rec["old_sha"][:7] or "(none)"
        git("commit", "-q", "-m",
            f"docs({rec['slug']}): bump {old} → {rec['new_sha'][:7]}\n\n"
            f"Automated weekly refresh. {stat}",
            "--", args.pins_file, slug_path)
        summary_rows.append((rec["slug"], old, rec["new_sha"][:7], stat))
        print(f"committed {rec['slug']}: {old} → {rec['new_sha'][:7]} ({stat})")

    if pin_only:
        for rec in pin_only:
            set_pin(pins_path, rec["name"], rec["new_sha"])
        git("add", "--", args.pins_file)
        names = ", ".join(r["slug"] for r in pin_only)
        git("commit", "-q", "-m",
            f"chore(pins): record vetted upstream commits with no doc-file "
            f"changes\n\nSources: {names}", "--", args.pins_file)
        print(f"committed pin-only bumps: {names}")

    # anything left under docs/sources (the .manifest.yaml timestamp, or a
    # source that changed without appearing in the manifest) goes last so
    # nothing is silently dropped.
    if dirty(DOCS_DIR) or dirty(args.pins_file):
        # restore any pins the loop above didn't claim (e.g. removed sources)
        pins_path.write_text(new_pins, encoding="utf-8")
        git("add", "--", DOCS_DIR, args.pins_file)
        if git("diff", "--cached", "--name-only").strip():
            git("commit", "-q", "-m",
                "chore: update docs manifest and residual refresh state",
                "--", DOCS_DIR, args.pins_file)
            print("committed residual refresh state")

    if args.summary_out:
        lines = ["| Source | Upstream bump | Delta |", "|---|---|---|"]
        for slug, old, new, stat in summary_rows:
            lines.append(f"| {slug} | `{old}` → `{new}` | {stat} |")
        if pin_only:
            names = ", ".join(r["slug"] for r in pin_only)
            lines.append(f"| _(pin-only)_ | {names} | no doc-file changes |")
        if not summary_rows and not pin_only:
            lines = ["No source changes this week."]
        Path(args.summary_out).write_text("\n".join(lines) + "\n",
                                          encoding="utf-8")

    return 0


if __name__ == "__main__":
    sys.exit(main())
