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
import unicodedata
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
    # `.` allowed between subject and verb so "Agent. You must run …" matches.
    # Requires an explicit AI-agent subject, so ordinary "fetch X and run Y"
    # technical prose (common in specs) does NOT match — only text that
    # directs an assistant/agent/automated-tool to act.
    (re.compile(r"\b(assistant|claude|copilot|coding\s+agent|ai\s+agent|"
                r"automated\s+tool|ai\s+tool)"
                r"\b[^\n]{0,40}?\b"
                r"(must|should|will|need\s+to)\s+(now\s+)?(run|execute|fetch|"
                r"download|install|ignore|delete|apply)", re.I),
     "instruction directed at an AI agent"),
    (re.compile(r"\bmust\s+be\s+(applied|executed|run)\s+by\s+"
                r"(any\s+)?(automated\s+tool|ai\s+tool|assistant|agent)\b", re.I),
     "instruction to automated tooling"),
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
    "github.com", "gitlab.com", "pypi.org", "crates.io",
    "docs.rs", "w3.org", "ietf.org", "datatracker.ietf.org", "rfc-editor.org",
    "iana.org", "unicode.org", "json.org", "schema.org", "creativecommons.org",
    "apache.org", "mozilla.org", "wikipedia.org", "stackoverflow.com",
    "example.com", "example.org", "localhost", "cardano.org",
    "developers.cardano.org", "docs.cardano.org", "intersectmbo.org",
    "input-output.io", "iohk.io", "shields.io", "img.shields.io",
    "mermaid.js.org", "youtube.com", "youtu.be", "medium.com",
}

# User-content hosts: anyone can publish arbitrary files here, so they are NOT
# trusted as pipe-to-shell targets — a curl|sh to one stays a prioritized WARN
# (the legit Mithril installer lives on raw.githubusercontent.com, so BLOCKing
# would false-positive; but it must never be silently treated as first-party).
USER_CONTENT_HOSTS = {
    "raw.githubusercontent.com", "githubusercontent.com", "github.io",
    "gist.github.com", "gitlab.io", "pages.dev", "vercel.app", "netlify.app",
    "s3.amazonaws.com", "storage.googleapis.com", "npmjs.com",
}


def _host_matches(domain: str, hosts: set[str]) -> bool:
    domain = domain.lower()
    return any(domain == h or domain.endswith("." + h) for h in hosts)


# Invisible/format-control detection. Strips-worthy at fetch; any occurrence in
# an added line is anomalous → BLOCK. Category-based (Cf format, Cc control
# except tab/newline/CR, Cn unassigned, Co private-use) catches the whole class
# generically; an explicit set adds the non-Cf smuggling codepoints (variation-
# selector supplement, combining grapheme joiner, and visible-blank fillers).
_EXPLICIT_INVISIBLE = (
    set(range(0xE0100, 0xE01F0))       # variation selectors supplement (VS17-256)
    | {0x034F,                          # combining grapheme joiner
       0x115F, 0x1160, 0x3164, 0xFFA0,  # hangul/halfwidth fillers (render blank)
       0x2800,                          # braille pattern blank
       0x2062, 0x2063, 0x2064}          # invisible times/separator/plus
)


def has_invisible(text: str) -> bool:
    for ch in text:
        if ch in "\t\n\r":
            continue
        o = ord(ch)
        if o in _EXPLICIT_INVISIBLE:
            return True
        if unicodedata.category(ch) in ("Cf", "Cc", "Cn", "Co"):
            return True
    return False


# Homoglyph attack signature: a single "word" mixing Latin with Cyrillic
# look-alike letters. Cyrillic-only — Greek letters (Ω, μ, π, Δ, …) appear
# legitimately in technical prose (kΩ, µF), so mixing Latin+Greek is not by
# itself suspicious; Cyrillic inside a Latin word essentially always is.
_LATIN = re.compile(r"[A-Za-z]")
_CYRILLIC = re.compile("[Ѐ-ӿԀ-ԯ]")
_WORD_RE = re.compile(r"[^\W\d_]{2,}", re.UNICODE)


def mixed_script_word(text: str) -> str | None:
    for m in _WORD_RE.finditer(text):
        w = m.group(0)
        if _LATIN.search(w) and _CYRILLIC.search(w):
            return w
    return None

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


def decode_bytes(data: bytes | None) -> tuple[str, bool]:
    """Decode blob bytes to text (NUL stripped). Returns (text, had_nul).

    A NUL used to make the scanner skip the whole file — an evasion. Now the
    NUL is stripped and the surrounding text is still scanned, with the caller
    flagging the anomaly."""
    if data is None:
        return "", False
    had_nul = b"\x00" in data
    text = data.decode("utf-8", "replace").replace("\x00", "")
    return text, had_nul


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


def _join_continuations(adds: list[tuple[int, str]]) -> list[tuple[int, str]]:
    """Merge backslash line-continuations, so a shell command split with `\\`
    across added lines is matched as one logical line (keeps the first line's
    number)."""
    out: list[tuple[int, str]] = []
    buf, buf_ln = None, None
    for ln, text in adds:
        piece = text.rstrip()
        cont = piece.endswith("\\")
        piece = piece[:-1] if cont else piece
        if buf is None:
            buf, buf_ln = piece, ln
        else:
            buf += " " + piece.lstrip()
        if not cont:
            out.append((buf_ln, buf))
            buf, buf_ln = None, None
    if buf is not None:
        out.append((buf_ln, buf))
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
    a new value appearing while an existing one disappeared (BLOCK).

    Two swap detectors, because either alone is evadable:
    - set-level: new value present in head, an old value absent from head
      (catches a plain replace).
    - line-level: a difflib 'replace' block where a base line held value X and
      the aligned head line holds a different value Y (catches an in-place edit
      even when the attacker RETAINS the old value elsewhere to empty the
      set-level 'removed' set — the confirmed retention-evasion).
    A value already present at base never fires either detector."""
    base_vals = {m.group(0) for m in pattern.finditer(base_text)}
    head_vals = {m.group(0) for m in pattern.finditer(head_text)}
    introduced = head_vals - base_vals
    if not introduced:
        return
    set_removed = bool(base_vals - head_vals)

    # line-level in-place change within replaced blocks
    line_swapped = False
    base_lines = base_text.splitlines()
    head_lines = head_text.splitlines()
    sm = difflib.SequenceMatcher(a=base_lines, b=head_lines, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "replace":
            continue
        b_vals = {m.group(0) for ln in base_lines[i1:i2]
                  for m in pattern.finditer(ln)}
        h_vals = {m.group(0) for ln in head_lines[j1:j2]
                  for m in pattern.finditer(ln)}
        if (h_vals - b_vals) & introduced and (b_vals - h_vals):
            line_swapped = True
            break

    for value in sorted(introduced):
        shown = value[:28] + ("…" if len(value) > 28 else "")
        if set_removed or line_swapped:
            add("BLOCK", slug, path,
                f"~L{first_line}: {label} CHANGED — `{shown}` introduced "
                f"while another was removed/replaced in the same file")
        else:
            add("WARN-HI", slug, path, f"~L{first_line}: new {label} `{shown}`")


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
    new_files: list[tuple[str, str, int, int, int]] = []  # slug,path,addr,inst,dom

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

        head_text, head_nul = decode_bytes(blob(args.head, head_path))
        base_text, _ = decode_bytes(blob(base, base_path))
        is_new_file = bool(status and status[0] == "A")
        if head_nul:
            add("WARN-HI", slug, head_path,
                "NUL byte in a text file (stripped before scanning; "
                "anomalous for docs)")

        adds = added_lines(base_text, head_text)
        added_text = "\n".join(t for _, t in adds)
        first_line = adds[0][0] if adds else 1

        # Injection: run on joined added text, whitespace collapsed AND NFKC-
        # normalized, so a payload split across lines or written with fullwidth
        # look-alikes still matches.
        collapsed = unicodedata.normalize(
            "NFKC", re.sub(r"\s+", " ", added_text))
        for pattern, label in INJECTION_PATTERNS:
            if pattern.search(collapsed):
                add("BLOCK", slug, head_path,
                    f"~L{first_line}: {label} in added text")

        for line_no, text in adds:
            if has_invisible(text):
                add("BLOCK", slug, head_path,
                    f"L{line_no}: invisible/format-control unicode in added "
                    f"line (ASCII-smuggling vector; not present in clean docs)")
            homoglyph = mixed_script_word(text)
            if homoglyph:
                add("BLOCK", slug, head_path,
                    f"L{line_no}: mixed-script (homoglyph) word `{homoglyph}` "
                    f"— Latin letters spoofed with Cyrillic/Greek look-alikes")
            if BASE64_BLOB_RE.search(text):
                add("WARN-HI", slug, head_path,
                    f"L{line_no}: long mixed base64-like blob")

        if slug not in base_domain_cache:
            base_domain_cache[slug] = source_base_domains(base, slug)
        base_domains = base_domain_cache[slug]

        # Pipe-to-shell. Join backslash line-continuations first, so
        # `curl … \\\n | sh` can't split the pattern across added lines.
        for line_no, text in _join_continuations(adds):
            if not PIPE_TO_SHELL_RE.search(text):
                continue
            dm = URL_DOMAIN_RE.search(text)
            dom = dm.group(1).lower() if dm else None
            new_dom = bool(dom and dom not in base_domains
                           and not domain_allowed(dom))
            user_host = bool(dom and _host_matches(dom, USER_CONTENT_HOSTS))
            if new_dom and not user_host:
                add("BLOCK", slug, head_path,
                    f"L{line_no}: pipe-to-shell targeting NEW domain "
                    f"`{dom}`: `{text.strip()[:100]}`")
            elif user_host:
                add("WARN-HI", slug, head_path,
                    f"L{line_no}: pipe-to-shell to user-content host `{dom}` "
                    f"(anyone can publish there): `{text.strip()[:80]}`")
            else:
                add("WARN-HI", slug, head_path,
                    f"L{line_no}: pipe-to-shell install: `{text.strip()[:80]}`")

        # Address / install swap detection needs a base to diff against; a
        # brand-new file has none. Existing files get full swap detection;
        # new files are surfaced with per-file counts (below) so poisoned
        # example values aren't silently invisible.
        if not is_new_file:
            _swap_check(add, slug, head_path, base_text, head_text,
                        BECH32_RE, "bech32 address", first_line)
            _swap_check(add, slug, head_path, base_text, head_text,
                        INSTALL_RE, "install command", first_line)

        if source_is_new(base, slug):
            new_source_slugs.add(slug)

        # New external domains from EXISTING files (one per source/domain,
        # allowlist-filtered). New files' domains are covered by their
        # per-file n_dom count instead, so a big refresh full of new pages
        # doesn't flood this tier.
        if not is_new_file:
            for dm in URL_DOMAIN_RE.finditer(added_text):
                dom = dm.group(1).lower()
                if dom not in base_domains and not domain_allowed(dom):
                    new_domains[slug].add(dom)

        if is_new_file:
            n_addr = len(BECH32_RE.findall(head_text))
            n_inst = len(INSTALL_RE.findall(head_text))
            n_dom = len({m.group(1).lower()
                         for m in URL_DOMAIN_RE.finditer(head_text)
                         if not domain_allowed(m.group(1))})
            new_files.append((slug, head_path, n_addr, n_inst, n_dom))

    # New-domain WARNs are the low-priority, high-volume tier — emit last so
    # the truncation cap only ever drops these, never a meaningful finding.
    for slug in sorted(new_domains):
        for dom in sorted(new_domains[slug]):
            add("WARN", slug, f"{DOCS_DIR}/{slug}",
                f"URL on a domain new to this source: `{dom}`")

    blocks = [f for f in findings if f[0] == "BLOCK"]
    hi_warns = [f for f in findings if f[0] == "WARN-HI"]
    lo_warns = [f for f in findings if f[0] == "WARN"]

    lines = [f"## Docs-delta security scan ({args.base} → {args.head})", ""]
    lines.append(
        f"Changed doc files: {changed_files} ({deletions} deletions) · "
        f"findings: {len(blocks)} blocking / "
        f"{len(hi_warns) + len(lo_warns)} advisory")
    lines.append("")
    if new_source_slugs:
        lines.append("**New sources** (whole-content review — every file is "
                     f"new): {', '.join(sorted(new_source_slugs))}")
        lines.append("")
    if new_files:
        rows = []
        for slug, path, n_addr, n_inst, n_dom in sorted(new_files):
            tags = []
            if n_addr:
                tags.append(f"{n_addr} addr")
            if n_inst:
                tags.append(f"{n_inst} install")
            if n_dom:
                tags.append(f"{n_dom} new-domain")
            note = f" [{', '.join(tags)}]" if tags else ""
            rows.append(f"`{path}`{note}")
        lines.append("**New files** (no base to diff — review content; "
                     "counts flag example addresses/installs/domains to check):")
        lines += [f"- {r}" for r in rows]
        lines.append("")

    def emit(title, sev, cap):
        by_slug: dict[str, list[tuple[str, str]]] = defaultdict(list)
        for s, slug, path, msg in findings:
            if s == sev:
                by_slug[slug].append((path, msg))
        if not by_slug:
            return
        lines.append(title)
        shown = 0
        total = sum(len(v) for v in by_slug.values())
        for slug in sorted(by_slug):
            for path, msg in by_slug[slug]:
                if cap is None or shown < cap:
                    lines.append(f"- **{slug}** `{path}` — {msg}")
                shown += 1
        if cap is not None and total > cap:
            lines.append(f"- …and {total - cap} more (run the scanner locally "
                         f"to see all).")
        lines.append("")

    # BLOCK and the high-priority advisory tier are never truncated; only the
    # noisy new-domain tier is capped.
    emit("### ⛔ Blocking findings", "BLOCK", None)
    emit("### ⚠️ Advisory — verify (installs, base64, NUL)", "WARN-HI", None)
    emit("### ⚠️ Advisory — new domains", "WARN", MAX_WARNS_SHOWN)
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
