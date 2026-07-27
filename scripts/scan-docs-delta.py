#!/usr/bin/env python3
"""Security scanner for changes to bundled third-party docs (docs/sources/).

Bundled docs are read by AI agents on every consumer's machine, so a doc
delta is an attack surface: agent-targeted prompt injection, and poisoned
reference content (swapped addresses, typosquatted packages, pipe-to-shell
installs). This scans the change between two git refs — read via git
plumbing, PR content is never executed — and reports findings per source.

File enumeration and per-file content come from `git diff --name-status -z`
plus `git show <ref>:<path>` (not a hand-parsed unified diff), so crafted
filenames, deleted files, and added lines that mimic diff syntax cannot
desync attribution. Added lines are computed with difflib against the full
base blob, and address/package "swap" detection compares the head file's
full content against the base file's full content — an example value already
present at base is never flagged, which is where a naive diff-line
comparison produced false positives.

Severities:
  BLOCK — exits 1; the PR check goes red until a human clears it
  WARN  — reported for review; does not fail the check

Usage:
  python3 scripts/scan-docs-delta.py                       # HEAD vs origin/main
  python3 scripts/scan-docs-delta.py --base origin/main --head refs/remotes/pr/head
  python3 scripts/scan-docs-delta.py --output-md report.md --github-output "$GITHUB_OUTPUT"
"""

from __future__ import annotations

import argparse
import difflib
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = "docs/sources"

# Everything that isn't clearly a binary asset is scanned — agents Read
# source/example files (.py/.ts/.java/…) too, so an extension allowlist left
# holes. Binary blobs (and any file git reports with a NUL byte) are skipped.
BINARY_EXTS = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".bmp", ".tiff",
    ".pdf", ".zip", ".gz", ".tar", ".tgz", ".bz2", ".xz", ".7z", ".rar",
    ".woff", ".woff2", ".ttf", ".otf", ".eot", ".mp4", ".webm", ".mov",
    ".mp3", ".wav", ".ogg", ".wasm", ".so", ".dylib", ".dll", ".exe",
    ".bin", ".pyc", ".class", ".jar", ".node",
}

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

# Allows intermediate pipeline stages (curl … | base64 -d | sh) and the
# command-substitution form (bash -c "$(curl …)").
PIPE_TO_SHELL_RE = re.compile(
    r"\b(curl|wget)\b[^\n]{0,200}\|\s*[^\n]{0,80}\b(sudo\s+)?(ba|z|fi|da|c)?sh\b"
    r"|\b(ba|z|c)?sh\b[^\n]{0,20}-c[^\n]{0,20}\$\((curl|wget)\b", re.I)

# re.I so all-uppercase bech32 (spec-valid, wallet-decodable) is caught too.
BECH32_RE = re.compile(
    r"\b(addr|addr_test|stake|stake_test|pool|drep|cc_cold|cc_hot)"
    r"1[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{8,}\b", re.I)

INSTALL_RE = re.compile(
    r"\b(npm\s+i(nstall)?|npx\s|yarn\s+add|pnpm\s+(add|i(nstall)?)|"
    r"pip3?\s+install|cargo\s+(add|install)|go\s+get|brew\s+install|"
    r"apt(-get)?\s+install)\b[^\n]*|<artifactId>[^<]+</artifactId>", re.I)

# Requires a dot and real label boundaries, so placeholders like "https://..."
# don't register as a domain.
URL_DOMAIN_RE = re.compile(
    r"https?://([a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9-]+)+)", re.I)

# Ubiquitous infrastructure/standards domains that appear across ordinary doc
# links; a source linking to one for the first time is not a signal. Matched
# by exact host or dot-suffix (so sub.github.io matches github.io).
DOMAIN_ALLOWLIST = {
    "github.com", "raw.githubusercontent.com", "githubusercontent.com",
    "github.io", "gitlab.com", "npmjs.com", "pypi.org", "crates.io",
    "docs.rs", "w3.org", "ietf.org", "datatracker.ietf.org", "rfc-editor.org",
    "iana.org", "unicode.org", "json.org", "schema.org", "creativecommons.org",
    "apache.org", "mozilla.org", "wikipedia.org", "stackoverflow.com",
    "example.com", "example.org", "localhost", "cardano.org",
    "developers.cardano.org", "docs.cardano.org", "intersectmbo.org",
    "input-output.io", "iohk.io", "shields.io", "img.shields.io",
    "mermaid.js.org", "youtube.com", "youtu.be", "medium.com",
}

# Invisible/format-control codepoints. The fetch-time sanitizer strips these
# from the bundle, so any occurrence in an added line is anomalous by
# construction — safe to BLOCK with near-zero false positives.
INVISIBLE_RE = re.compile(
    "[​-‏"      # zero-width space/joiners, LRM/RLM
    "‪-‮"       # bidi embedding/override
    "⁠-⁤"       # word-joiner, invisible math operators
    "⁦-⁩"       # bidi isolates
    "﻿]"             # zero-width no-break space / BOM
    "|[\U000e0000-\U000e007f]")  # unicode tag chars (ASCII smuggling)

# Long base64-ish blob: mixed-case with base64 alphabet, not pure hex (CBOR
# hex is expected in this ecosystem). Advisory only.
BASE64_BLOB_RE = re.compile(r"(?=[A-Za-z0-9+/]{256,})(?=[A-Za-z0-9+/]*[A-Z])"
                            r"(?=[A-Za-z0-9+/]*[a-z])"
                            r"(?=[A-Za-z0-9+/]*[0-9+/])[A-Za-z0-9+/]{256,}={0,2}")

MAX_WARNS_SHOWN = 40


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=REPO_ROOT,
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def git_z(*args: str) -> list[str]:
    """git with -z output → NUL-split token list (trailing empty dropped)."""
    result = subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}")
    toks = result.stdout.split(b"\x00")
    return [t.decode("utf-8", "surrogateescape") for t in toks if t]


def blob(ref: str, path: str) -> bytes | None:
    """Raw bytes of ref:path, or None if it doesn't exist there."""
    result = subprocess.run(["git", "show", f"{ref}:{path}"],
                            cwd=REPO_ROOT, capture_output=True)
    return result.stdout if result.returncode == 0 else None


def source_slug(path: str) -> str:
    parts = Path(path).parts
    return parts[2] if len(parts) > 2 else "(root)"


def decode_text(data: bytes | None) -> str | None:
    """Decode a blob as text, or None if it looks binary (NUL byte)."""
    if data is None:
        return ""
    if b"\x00" in data:
        return None
    return data.decode("utf-8", "replace")


def added_lines(base_text: str, head_text: str) -> list[tuple[int, str]]:
    """(head_line_no, text) for lines inserted/changed in head vs base."""
    base_lines = base_text.splitlines()
    head_lines = head_text.splitlines()
    sm = difflib.SequenceMatcher(a=base_lines, b=head_lines, autojunk=False)
    out = []
    for tag, _i1, _i2, j1, j2 in sm.get_opcodes():
        if tag in ("insert", "replace"):
            for j in range(j1, j2):
                out.append((j + 1, head_lines[j]))
    return out


def domain_allowed(domain: str) -> bool:
    domain = domain.lower()
    return any(domain == a or domain.endswith("." + a)
               for a in DOMAIN_ALLOWLIST)


def source_base_domains(base: str, slug: str) -> set[str]:
    """Domains already present anywhere in this source at the base ref."""
    result = subprocess.run(
        ["git", "grep", "-hIoE", r"https?://[A-Za-z0-9.-]+", base,
         "--", f"{DOCS_DIR}/{slug}"], cwd=REPO_ROOT, capture_output=True,
        text=True)
    if result.returncode > 1:  # 1 == no matches; >1 == real error
        return set()  # fail toward MORE warnings, never fewer
    return {m.group(1).lower() for m in URL_DOMAIN_RE.finditer(result.stdout)}


def source_is_new(base: str, slug: str) -> bool:
    result = subprocess.run(
        ["git", "cat-file", "-t", f"{base}:{DOCS_DIR}/{slug}"],
        cwd=REPO_ROOT, capture_output=True)
    return result.returncode != 0


def collect_changed(base: str, head: str):
    """Yield (status, base_path, head_path) for docs/sources changes."""
    toks = git_z("diff", "--name-status", "-M", "-z", base, head,
                 "--", DOCS_DIR)
    i = 0
    while i < len(toks):
        status = toks[i]
        if status and status[0] in ("R", "C"):
            yield status, toks[i + 1], toks[i + 2]
            i += 3
        else:
            yield status, toks[i + 1], toks[i + 1]
            i += 2


def _swap_check(add, slug, path, base_text, head_text, pattern, label,
                first_line):
    """Flag a value newly introduced to an existing file (WARN), or a swap —
    a new value appearing while an existing one disappeared (BLOCK). Compares
    full file contents, so a value already present at base never fires."""
    base_vals = {m.group(0) for m in pattern.finditer(base_text)}
    head_vals = {m.group(0) for m in pattern.finditer(head_text)}
    introduced = head_vals - base_vals
    if not introduced:
        return
    removed = base_vals - head_vals
    for value in sorted(introduced):
        shown = value[:28] + ("…" if len(value) > 28 else "")
        if removed:
            add("BLOCK", slug, path,
                f"~L{first_line}: {label} CHANGED — `{shown}` introduced "
                f"while another was removed from the same file")
        else:
            add("WARN", slug, path, f"~L{first_line}: new {label} `{shown}`")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--output-md", metavar="PATH")
    parser.add_argument("--github-output", metavar="PATH")
    args = parser.parse_args()

    # Anchor on the merge-base so changes that landed on the base branch after
    # this PR forked don't show up inverted as PR changes.
    try:
        base = git("merge-base", args.base, args.head).strip() or args.base
    except RuntimeError:
        base = args.base

    findings: list[tuple[str, str, str, str]] = []  # (sev, slug, path, msg)
    seen = set()
    base_domain_cache: dict[str, set[str]] = {}
    new_domains: dict[str, set[str]] = defaultdict(set)
    changed_files = 0
    deletions = 0
    new_source_slugs: set[str] = set()
    new_files_by_slug: dict[str, int] = defaultdict(int)

    def add(severity, slug, path, msg):
        key = (severity, path, msg)
        if key not in seen:
            seen.add(key)
            findings.append((severity, slug, path, msg))

    for status, base_path, head_path in collect_changed(base, args.head):
        changed_files += 1
        slug = source_slug(head_path)

        if status and status[0] == "D":
            deletions += 1
            continue
        if Path(head_path).suffix.lower() in BINARY_EXTS:
            continue

        head_text = decode_text(blob(args.head, head_path))
        if head_text is None:  # binary content
            continue
        base_text = decode_text(blob(base, base_path)) or ""
        is_new_file = bool(status and status[0] == "A")
        if is_new_file:
            new_files_by_slug[slug] += 1

        adds = added_lines(base_text, head_text)
        added_text = "\n".join(t for _, t in adds)
        first_line = adds[0][0] if adds else 1

        # Injection: run on the joined added text (whitespace/newlines
        # collapsed) so a payload split across added lines still matches.
        collapsed = re.sub(r"\s+", " ", added_text)
        for pattern, label in INJECTION_PATTERNS:
            if pattern.search(collapsed):
                add("BLOCK", slug, head_path,
                    f"~L{first_line}: {label} in added text")

        # Invisible/control unicode is the one hidden-text signal worth a
        # BLOCK: legitimate docs never contain it, whereas HTML comments and
        # <script> are common in real tutorials and carry no execution risk
        # when an agent reads the file as text — their only danger is
        # concealed instructions, already covered by the injection pass.
        for line_no, text in adds:
            if INVISIBLE_RE.search(text):
                add("BLOCK", slug, head_path,
                    f"L{line_no}: invisible/format-control unicode in added "
                    f"line (ASCII-smuggling vector; not present in clean docs)")
            if BASE64_BLOB_RE.search(text):
                add("WARN", slug, head_path,
                    f"L{line_no}: long mixed base64-like blob")

        if slug not in base_domain_cache:
            base_domain_cache[slug] = source_base_domains(base, slug)
        base_domains = base_domain_cache[slug]

        # Pipe-to-shell: WARN normally (legit installers exist), escalated to
        # BLOCK when it targets a domain newly introduced for this source.
        for line_no, text in adds:
            if PIPE_TO_SHELL_RE.search(text):
                dm = URL_DOMAIN_RE.search(text)
                dom = dm.group(1).lower() if dm else None
                if dom and dom not in base_domains and not domain_allowed(dom):
                    add("BLOCK", slug, head_path,
                        f"L{line_no}: pipe-to-shell targeting NEW domain "
                        f"`{dom}`: `{text.strip()[:100]}`")
                else:
                    add("WARN", slug, head_path,
                        f"L{line_no}: pipe-to-shell install "
                        f"(known target): `{text.strip()[:80]}`")

        # Address / install: a brand-new file has no base to diff against, so
        # swap detection is impossible and every example value would WARN —
        # such files are listed once for whole-content review instead.
        # Existing files get full swap detection against base content.
        if not is_new_file:
            _swap_check(add, slug, head_path, base_text, head_text,
                        BECH32_RE, "bech32 address", first_line)
            _swap_check(add, slug, head_path, base_text, head_text,
                        INSTALL_RE, "install command", first_line)

        # New external domains: one WARN per (source, domain), allowlist-
        # filtered, skipped for brand-new files (a whole new page is expected
        # to bring links and is surfaced as a new file instead).
        if source_is_new(base, slug):
            new_source_slugs.add(slug)
        if not is_new_file:
            for dm in URL_DOMAIN_RE.finditer(added_text):
                dom = dm.group(1).lower()
                if dom not in base_domains and not domain_allowed(dom):
                    new_domains[slug].add(dom)

    for slug in sorted(new_domains):
        for dom in sorted(new_domains[slug]):
            add("WARN", slug, f"{DOCS_DIR}/{slug}",
                f"URL on a domain new to this source: `{dom}`")

    blocks = [f for f in findings if f[0] == "BLOCK"]
    warns = [f for f in findings if f[0] == "WARN"]

    lines = [f"## Docs-delta security scan ({args.base} → {args.head})", ""]
    lines.append(f"Changed doc files: {changed_files} ({deletions} deletions) "
                 f"· findings: {len(blocks)} blocking / {len(warns)} advisory")
    lines.append("")
    if new_source_slugs:
        lines.append("**New sources** (whole-content review — every file is "
                     f"new): {', '.join(sorted(new_source_slugs))}")
        lines.append("")
    if new_files_by_slug:
        summary = ", ".join(f"{s} ({n})" for s, n in
                            sorted(new_files_by_slug.items()))
        lines.append("**New files** (no base to diff — review content; "
                     "example addresses/installs in them are not flagged "
                     f"individually): {summary}")
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
        shown = 0
        for slug in sorted(by_slug):
            for severity, path, msg in by_slug[slug]:
                if severity == "WARN":
                    if shown < MAX_WARNS_SHOWN:
                        lines.append(f"- **{slug}** `{path}` — {msg}")
                    shown += 1
        if shown > MAX_WARNS_SHOWN:
            lines.append(f"- …and {shown - MAX_WARNS_SHOWN} more advisory "
                         f"findings (truncated).")
        lines.append("")
    if not findings:
        lines.append("✅ No security findings in the docs delta.")

    report = "\n".join(lines)
    print(report)
    if args.output_md:
        Path(args.output_md).write_text(report + "\n", encoding="utf-8")
    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as fh:
            fh.write(f"docs_changed={changed_files}\n")
            fh.write(f"scan_blocks={len(blocks)}\n")

    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main())
