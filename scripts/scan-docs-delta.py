#!/usr/bin/env python3
"""Security scanner for changes to bundled third-party docs (docs/sources/).

Bundled docs are read by AI agents on every consumer's machine, so a doc
delta is an attack surface: agent-targeted prompt injection, and poisoned
reference content (swapped addresses, typosquatted packages, pipe-to-shell
installs). This script scans ONLY the changed lines between two git refs —
read via git plumbing, PR content is never executed — and reports findings
per source.

Finding severities:
  BLOCK — exits 1; the PR check goes red until a human clears it
  WARN  — reported for human review; does not fail the check

Checks on added lines:
  1. Agent-targeted injection phrasing            -> BLOCK
  2. curl/wget piped to a shell                    -> BLOCK
  3. Changed bech32 address in a modified file     -> BLOCK (swap) / WARN (new)
  4. Changed package-install command               -> BLOCK (swap) / WARN (new)
  5. Long base64 blob                              -> WARN
  6. URL on a domain the source never used before  -> WARN

Usage:
  python3 scripts/scan-docs-delta.py                       # HEAD vs origin/main
  python3 scripts/scan-docs-delta.py --base origin/main --head refs/remotes/pr/head
  python3 scripts/scan-docs-delta.py --output-md report.md --github-output "$GITHUB_OUTPUT"
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = "docs/sources"

TEXT_EXTS = {".md", ".mdx", ".rst", ".txt", ".html", ".htm", ".yaml", ".yml",
             ".json", ".toml", ".ak"}

INJECTION_PATTERNS = [
    (re.compile(r"ignore\s+(all\s+|any\s+)?(previous|prior|earlier|above)\s+"
                r"(instructions|context|rules|prompts)", re.I),
     "instruction-override phrasing"),
    (re.compile(r"disregard\s+(all\s+|any\s+)?(previous|prior|your)\s+"
                r"(instructions|rules|guidelines)", re.I),
     "instruction-override phrasing"),
    (re.compile(r"\byou\s+are\s+an?\s+(ai|llm|language\s+model|assistant|"
                r"coding\s+agent)\b", re.I),
     "text addressed to an AI agent"),
    (re.compile(r"\b(if\s+you\s+are|when\s+read\s+by)\s+(an?\s+)?"
                r"(ai|llm|assistant|agent|claude|copilot)\b", re.I),
     "text addressed to an AI agent"),
    (re.compile(r"\b(assistant|claude|copilot|agent)\b[^.\n]{0,40}\b"
                r"(must|should|will)\s+(now\s+)?(run|execute|fetch|download|"
                r"install|ignore|delete)", re.I),
     "instruction directed at an AI agent"),
    (re.compile(r"\b(do\s+not|don'?t|never)\s+(tell|inform|alert|notify|ask)\s+"
                r"the\s+user", re.I),
     "concealment instruction"),
    (re.compile(r"without\s+(telling|informing|asking|alerting)\s+the\s+user",
                re.I),
     "concealment instruction"),
    (re.compile(r"<\|im_(start|end)\|>|<\|(system|user|assistant)\|>"),
     "chat-template control tokens"),
]

PIPE_TO_SHELL_RE = re.compile(
    r"\b(curl|wget)\b[^\n|]{0,200}\|\s*(sudo\s+)?(ba|z|fi)?sh\b", re.I)

BECH32_RE = re.compile(
    r"\b(addr|addr_test|stake|stake_test|pool|drep|cc_cold|cc_hot)"
    r"1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{8,}\b")

INSTALL_RE = re.compile(
    r"\b(npm\s+i(nstall)?|npx\s|yarn\s+add|pnpm\s+(add|i(nstall)?)|"
    r"pip3?\s+install|cargo\s+(add|install)|go\s+get|brew\s+install|"
    r"apt(-get)?\s+install)\b[^\n]*|<artifactId>[^<]+</artifactId>|"
    r"^\s*implementation\s*[('\"]", re.I | re.M)

BASE64_BLOB_RE = re.compile(r"[A-Za-z0-9+/]{200,}={0,2}")

URL_DOMAIN_RE = re.compile(r"https?://([a-zA-Z0-9.-]+)")


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=REPO_ROOT,
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def source_slug(path: str) -> str:
    parts = Path(path).parts
    return parts[2] if len(parts) > 2 else "(root)"


def parse_diff(base: str, head: str) -> dict[str, dict]:
    """Return {path: {"added": [(line_no, text)], "removed": [text],
    "new_file": bool}} for changed files under docs/sources/."""
    raw = git("diff", "--no-color", "-U0", f"{base}..{head}", "--", DOCS_DIR)
    files: dict[str, dict] = {}
    current = None
    line_no = 0
    for line in raw.splitlines():
        if line.startswith("+++ b/"):
            path = line[6:]
            current = files.setdefault(
                path, {"added": [], "removed": [], "new_file": False})
        elif line.startswith("--- /dev/null") and current is None:
            pass
        elif line.startswith("--- "):
            pass
        elif line.startswith("new file mode") and current is None:
            pass
        elif line.startswith("@@") and current is not None:
            m = re.search(r"\+(\d+)", line)
            line_no = int(m.group(1)) if m else 0
        elif current is not None and line.startswith("+") and not line.startswith("+++"):
            current["added"].append((line_no, line[1:]))
            line_no += 1
        elif current is not None and line.startswith("-") and not line.startswith("---"):
            current["removed"].append(line[1:])
    # mark new files (no removed lines AND absent at base)
    name_status = git("diff", "--name-status", f"{base}..{head}", "--", DOCS_DIR)
    for entry in name_status.splitlines():
        parts = entry.split("\t")
        if len(parts) >= 2 and parts[0].startswith("A") and parts[1] in files:
            files[parts[1]]["new_file"] = True
    return files


def base_domains_for_slug(base: str, slug: str) -> set[str] | None:
    """Domains already present in this source at the base ref; None if the
    source is brand new at head."""
    try:
        out = git("grep", "-hIo", "-E", r"https?://[a-zA-Z0-9.-]+",
                  base, "--", f"{DOCS_DIR}/{slug}")
    except RuntimeError as exc:
        # git grep exits 1 on no matches; distinguish "no dir" via ls-tree
        try:
            tree = git("ls-tree", "-d", base, f"{DOCS_DIR}/{slug}")
        except RuntimeError:
            tree = ""
        return None if not tree.strip() else set()
    domains = set()
    for m in URL_DOMAIN_RE.finditer(out):
        domains.add(m.group(1).lower())
    return domains


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--output-md", metavar="PATH")
    parser.add_argument("--github-output", metavar="PATH")
    args = parser.parse_args()

    files = parse_diff(args.base, args.head)
    findings: list[tuple[str, str, str, str]] = []  # (severity, slug, path, msg)
    domain_cache: dict[str, set[str] | None] = {}

    for path, info in sorted(files.items()):
        if Path(path).suffix.lower() not in TEXT_EXTS:
            continue
        slug = source_slug(path)
        added, removed = info["added"], info["removed"]
        removed_text = "\n".join(removed)
        removed_bech32_full = set(
            m.group(0) for m in BECH32_RE.finditer(removed_text)) if removed else set()
        removed_installs = set(
            m.group(0).strip() for m in INSTALL_RE.finditer(removed_text))

        seen_msgs = set()

        def add(severity: str, msg: str):
            key = (severity, path, msg)
            if key not in seen_msgs:
                seen_msgs.add(key)
                findings.append((severity, slug, path, msg))

        for line_no, text in added:
            for pattern, label in INJECTION_PATTERNS:
                if pattern.search(text):
                    add("BLOCK", f"L{line_no}: {label}: `{text.strip()[:120]}`")
            if PIPE_TO_SHELL_RE.search(text):
                add("BLOCK", f"L{line_no}: command piped to shell: "
                             f"`{text.strip()[:120]}`")
            if BASE64_BLOB_RE.search(text):
                add("WARN", f"L{line_no}: long base64-like blob "
                            f"({len(text)} chars)")

            for m in BECH32_RE.finditer(text):
                value = m.group(0)
                if value in removed_bech32_full:
                    continue  # unchanged address moved around
                if not info["new_file"] and removed_bech32_full:
                    add("BLOCK", f"L{line_no}: bech32 address CHANGED in "
                                 f"existing file: `{value[:24]}…` (removed "
                                 f"lines contained a different address)")
                elif not info["new_file"]:
                    add("WARN", f"L{line_no}: new bech32 address in existing "
                                f"file: `{value[:24]}…`")

            for m in INSTALL_RE.finditer(text):
                cmd = m.group(0).strip()
                if cmd in removed_installs:
                    continue
                if not info["new_file"] and removed_installs:
                    add("BLOCK", f"L{line_no}: install command CHANGED: "
                                 f"`{cmd[:120]}`")
                elif not info["new_file"]:
                    add("WARN", f"L{line_no}: new install command in existing "
                                f"file: `{cmd[:120]}`")

            for m in URL_DOMAIN_RE.finditer(text):
                domain = m.group(1).lower()
                if slug not in domain_cache:
                    domain_cache[slug] = base_domains_for_slug(args.base, slug)
                base_domains = domain_cache[slug]
                if base_domains is None:
                    continue  # brand-new source: whole-content review instead
                if domain not in base_domains:
                    add("WARN", f"L{line_no}: URL on domain never used by this "
                                f"source before: `{domain}`")

    new_sources = sorted({source_slug(p) for p, i in files.items()
                          if domain_cache.get(source_slug(p), set()) is None})

    blocks = [f for f in findings if f[0] == "BLOCK"]
    warns = [f for f in findings if f[0] == "WARN"]

    lines = [f"## Docs-delta security scan ({args.base} → {args.head})", ""]
    lines.append(f"Changed doc files: {len(files)} · findings: "
                 f"{len(blocks)} blocking / {len(warns)} advisory")
    lines.append("")
    if new_sources:
        lines.append(f"New sources (full-content review, domain check "
                     f"skipped): {', '.join(new_sources)}")
        lines.append("")

    by_slug: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    for severity, slug, path, msg in findings:
        by_slug[slug].append((severity, path, msg))

    if blocks:
        lines.append("### ⛔ Blocking findings")
        for slug in sorted(by_slug):
            for severity, path, msg in by_slug[slug]:
                if severity == "BLOCK":
                    lines.append(f"- **{slug}** `{path}` — {msg}")
        lines.append("")
    if warns:
        lines.append("### ⚠️ Advisory findings (verify in review)")
        for slug in sorted(by_slug):
            for severity, path, msg in by_slug[slug]:
                if severity == "WARN":
                    lines.append(f"- **{slug}** `{path}` — {msg}")
        lines.append("")
    if not findings:
        lines.append("✅ No security findings in the docs delta.")

    report = "\n".join(lines)
    print(report)
    if args.output_md:
        Path(args.output_md).write_text(report + "\n", encoding="utf-8")
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as fh:
            fh.write(f"docs_changed={len(files)}\n")
            fh.write(f"scan_blocks={len(blocks)}\n")

    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main())
