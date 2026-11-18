#!/usr/bin/env python3
"""Validate cardano-dev-skills repo: SKILL.md files and sources.yaml."""

# Annotations are never evaluated with this import, so `X | Y` costs nothing at
# import time and this file runs on 3.9 — which matters because `--paths-only`
# below must work on whatever python3 a contributor happens to have. The other
# scripts in this directory carry it for the same reason.
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import re
from pathlib import Path

# Only the skill/registry checks need pyyaml. `--paths-only` must stay runnable
# on a bare python3 with nothing installed, so the refresh workflow can gate on
# path portability without a setup step. `validate.yml` runs that mode on the
# oldest supported interpreter to keep both halves of that true.
try:
    import yaml
except ModuleNotFoundError:
    yaml = None

REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = REPO_ROOT / "skills"
SOURCES_FILE = REPO_ROOT / "registry" / "sources.yaml"
PINS_FILE = REPO_ROOT / "registry" / "pins.yaml"
DOCS_SOURCES_DIR = REPO_ROOT / "docs" / "sources"
CLAUDE_MANIFEST = REPO_ROOT / ".claude-plugin" / "plugin.json"
CODEX_MANIFEST = REPO_ROOT / ".codex-plugin" / "plugin.json"
COMPATIBILITY_DOC = REPO_ROOT / "docs" / "AGENT_COMPATIBILITY.md"

MAX_SKILL_LINES = 500
MAX_NAME_LEN = 64
NAME_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
SEMVER_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$")

# Shared skill bodies must not depend on adapter-only paths or tool names.
# Host-specific frontmatter remains allowed and is validated separately.
FORBIDDEN_SHARED_VARIABLES = {"${CLAUDE_SKILL_DIR}", "${CLAUDE_PLUGIN_ROOT}"}
# Fences here quote shipped history verbatim: comparison data, never instructions.
HISTORICAL_BLOCKS_FILE = (SKILLS_DIR / "cardano-context" / "references"
                          / "previous-blocks.md")
HOST_TOOL_REFERENCE_RE = re.compile(
    r"`(?:Read|Grep|Glob|Edit|Write|WebFetch|WebSearch)`")

# Citations of the bundled corpus resolve relative to the active SKILL.md
# (docs/AGENT_COMPATIBILITY.md), so each must start with ../../ and name a path
# that exists. A bare "docs/sources/" with nothing after it names the corpus and
# is fine. Fenced code is skipped: it is text a skill writes into the user's
# project, not a citation the agent follows.
BARE_DOC_PATH_RE = re.compile(r"(?<![./\w-])docs/sources/(?=[\w<])")
DOC_PATH_RE = re.compile(r"\.\./\.\./docs/sources/([^\s`'\"()\[\]]*)")

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
# recency rule of the source-vetting bar for document-of-record repos, where
# commit cadence says nothing about health. Waiving the bar is a security
# decision, so it requires an explicit entry here, reviewed in the same PR
# that adds it — a reason string alone is self-service.
# Keyed name -> owner/repo: `name` is contributor-chosen free text, so a
# name-only grant would follow an entry to whatever upstream it is later
# repointed at. The waiver takes effect in scripts/check-pr-policy.py.
VETTING_EXCEPTIONS: dict[str, str] = {
    "Cardano Constitution": "IntersectMBO/cardano-constitution",
}

# Claude Code tool-grant policy. `allowed-tools` entries are PRE-APPROVED in
# Claude Code, so widening this set is a security decision, not a convenience.
# Codex does not use these fields as the portable contract; required behavior
# must also be present in the Markdown body.
BASE_ALLOWED_TOOLS = {"Read", "Grep", "Glob"}
# Exceptions list only the EXTRA tools a skill needs beyond the base set;
# they are unioned with BASE_ALLOWED_TOOLS, so a skill never has to re-declare
# the read-only tools to gain one more.
ALLOWED_TOOLS_EXCEPTIONS = {
    # cardano-context writes the context block into the user's AGENTS.md and an
    # import line into their CLAUDE.md;
    # Bash is scoped to `pwd` (used to resolve the project root).
    "cardano-context": {"Edit", "Write", "Bash(pwd)"},
}
# Skills read bundled docs with Read/Grep/Glob, so no skill turn needs the
# agent to fetch a URL of its own. Requiring these keeps a poisoned doc read
# during a skill turn from reaching out. This bans the *undirected* network:
# `give-feedback` still reaches GitHub, but only through `gh` with a fixed
# repository and a draft the user has read and approved (DESIGN Decision 14).
REQUIRED_DISALLOWED_TOOLS = {"WebFetch", "WebSearch"}

# Every skill carries one grounding block whose text is fixed by the fenced
# blocks in docs/SOURCE_GROUNDING.md; a skill listed in GROUNDING_VARIANTS
# carries its variant instead. The mapping is fixed here, not read from the
# doc, so adding a variant there cannot silently move a skill off the general
# text. cardano-context writes no block of its own into its body: the general
# text lives inside the context block it installs. give-feedback answers no
# Cardano question. A block inside a code fence is an example, not live text,
# so markers there are rejected.
GROUNDING_DOC = REPO_ROOT / "docs" / "SOURCE_GROUNDING.md"
GROUNDING_EXEMPT = {"cardano-context", "give-feedback"}
GROUNDING_VARIANTS: dict[str, str] = {
    "review-contract": "review-contract",
    "assess-constitutionality": "assess-constitutionality",
}
GROUNDING_BEGIN_RE = re.compile(
    r"<!-- cds:grounding begin(?: variant=([a-z0-9-]+))? -->")
GROUNDING_END = "<!-- cds:grounding end -->"
GROUNDING_REGION_RE = re.compile(
    GROUNDING_BEGIN_RE.pattern + r"(.*?)" + re.escape(GROUNDING_END), re.S)
GROUNDING_MARKER_RE = re.compile(r"<!--\s*cds:grounding\b")
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})")
# CommonMark fence: at most three leading spaces, no tab indentation.
COMMONMARK_FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
CONTEXT_BLOCK_RE = re.compile(
    r"<!-- BEGIN cardano-dev-skills v(\d+) -->(.*?)"
    r"<!-- END cardano-dev-skills v(\d+) -->", re.S)
# The new-skill template must open every new skill with the general text, so a
# template that drifted would seed each new skill with a stale block. Only the
# heredoc that writes the scaffolded SKILL.md is checked: a block anywhere
# else in the script never reaches a new skill.
NEW_SKILL_TEMPLATE = REPO_ROOT / "scripts" / "new-skill.sh"
# A heredoc operator (not a `<<<` here-string) and its delimiter word, quoted
# ('D', "D" or \D) or bare.
HEREDOC_RE = re.compile(
    r"(?<!<)<<(?!<)(-?)[ \t]*"
    r"(?:'([^'\n]+)'|\"([^\"\n]+)\"|(\\?)([A-Za-z_][A-Za-z0-9_]*))")
SKILL_MD_REDIRECT_RE = re.compile(r">[ \t]*\"[^\"\n]*SKILL\.md\"")
# Every context block shipped before the canonical vN is kept as a `## vK`
# section of HISTORICAL_BLOCKS_FILE: a user's unedited older block that is
# missing there would be treated as the user's own edit.
HISTORY_HEADING_RE = re.compile(r"## v(\d+)[ \t]*")
HEADING_LEVEL_1_2_RE = re.compile(r"#{1,2}(?:[ \t]|$)")

# Line kinds yielded by fence_lines().
TEXT, OPEN, CODE, CLOSE = "text", "open", "code", "close"

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


def check_bundled_doc_paths(path: Path, text: str) -> None:
    """Flag bare or dead citations of docs/sources/ outside fenced code."""
    for lineno, (kind, line) in enumerate(
            fence_lines(text, backtick_toggle=True), 1):
        if kind != TEXT:
            continue
        if BARE_DOC_PATH_RE.search(line):
            error(f"{path}:{lineno}: cite bundled docs as ../../docs/sources/..., "
                  "relative to SKILL.md")
        for match in DOC_PATH_RE.finditer(line):
            target = match.group(1).rstrip(".,:;")
            if not target or any(c in target for c in "<*{"):
                continue
            if not (DOCS_SOURCES_DIR / target).exists():
                error(f"{path}:{lineno}: ../../docs/sources/{target} does not exist")


def validate_skill(skill_dir: Path) -> None:
    """Validate a single skill directory."""
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        error(f"{skill_dir}: missing SKILL.md")
        return

    # Check line count
    raw_text = skill_md.read_text(encoding="utf-8")
    lines = raw_text.splitlines()
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
    body = raw_text.split("---", 2)[2]
    for variable in FORBIDDEN_SHARED_VARIABLES:
        if variable in body:
            error(
                f"{skill_md}: shared skill body uses host-specific variable "
                f"{variable}; resolve paths relative to SKILL.md instead"
            )
    check_bundled_doc_paths(skill_md, raw_text)
    tool_refs = sorted(set(HOST_TOOL_REFERENCE_RE.findall(body)))
    if tool_refs:
        error(
            f"{skill_md}: shared skill body requires host-specific tool "
            f"names {tool_refs}; describe the capability in neutral language"
        )

    text = raw_text.lower()
    for section in ["when to use", "when not to use", "workflow"]:
        if section not in text:
            warn(f"{skill_md}: missing recommended section '## {section.title()}'")

    # Check references exist if referenced
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref_file in refs_dir.iterdir():
            if ref_file.is_dir():
                error(
                    f"{ref_file}: nested reference directories are not "
                    "portable; keep references one level deep"
                )
                continue
            if ref_file.suffix not in (".md", ".txt", ".yaml", ".yml"):
                warn(f"{ref_file}: unexpected file type in references/")
                continue
            if ref_file.suffix in (".md", ".txt"):
                ref_text = ref_file.read_text(encoding="utf-8")
                check_bundled_doc_paths(ref_file, ref_text)
                checked_text = ref_text
                if ref_file.resolve() == HISTORICAL_BLOCKS_FILE.resolve():
                    checked_text = "\n".join(
                        part for inside, part in fence_segments(
                            ref_text, commonmark_indent=True)
                        if not inside)
                for variable in FORBIDDEN_SHARED_VARIABLES:
                    if variable in checked_text:
                        error(
                            f"{ref_file}: shared reference uses host-specific "
                            f"variable {variable}; resolve paths relative to "
                            "the active SKILL.md instead"
                        )


def normalize_grounding(text: str) -> str:
    """Collapse whitespace runs so re-wrapping or list indentation is not a diff."""
    return " ".join(text.split())


def load_grounding_texts() -> dict[str | None, str] | None:
    """Read the canonical grounding texts, keyed by variant (None = general).

    Only fenced blocks count, so prose in the doc that names the markers can
    never become a canonical text. The doc must define exactly the general
    text and one text per GROUNDING_VARIANTS entry.
    """
    if not GROUNDING_DOC.exists():
        error(f"Missing {GROUNDING_DOC} (canonical grounding texts)")
        return None
    fenced: list[str] = []
    current: list[str] = []
    for kind, line in fence_lines(GROUNDING_DOC.read_text(encoding="utf-8"),
                                  backtick_toggle=True):
        if kind == OPEN:
            current = []
        elif kind == CODE:
            current.append(line)
        elif kind == CLOSE:
            fenced.append("\n".join(current))
    texts: dict[str | None, str] = {}
    for block in fenced:
        for match in GROUNDING_REGION_RE.finditer(block):
            variant = match.group(1)
            if variant in texts:
                error(f"{GROUNDING_DOC}: grounding text "
                      f"{variant or 'general'!r} defined more than once")
            texts[variant] = normalize_grounding(match.group(2))
    expected = {None} | set(GROUNDING_VARIANTS.values())
    for variant in sorted(expected - texts.keys(), key=str):
        error(f"{GROUNDING_DOC}: missing the {variant or 'general'} grounding text")
    for variant in sorted(texts.keys() - expected, key=str):
        error(f"{GROUNDING_DOC}: unexpected grounding variant {variant!r} "
              "(variants are fixed by GROUNDING_VARIANTS in validate.py)")
    if texts.keys() != expected:
        return None
    return texts


def fence_lines(text: str, commonmark_indent: bool = False,
                backtick_toggle: bool = False) -> list[tuple[str, str]]:
    """Classify each line of `text` as (kind, line), kind one of TEXT, or the
    OPEN, CODE or CLOSE line of a fence. Every fence reader here uses this.

    By default a fence opens on FENCE_RE (an info string may follow). It
    closes only on a line holding optional indent, then a run of the opening
    character at least as long as the opening run, then nothing but spaces or
    tabs. Any other line stays code, including a fence line with an info
    string or of the other character. With `commonmark_indent`, an opener or
    closer counts only with at most three leading spaces and no tab, as in
    CommonMark; a line indented further is not a fence line.

    With `backtick_toggle`, any line whose first non-blank characters are
    three backticks opens a fence when outside one and closes it when inside,
    whatever follows; tildes never fence. That looser rule is what the
    citation check and the canonical grounding texts are read with.
    """
    if commonmark_indent and backtick_toggle:
        raise ValueError("commonmark_indent and backtick_toggle are exclusive")
    opener_re = COMMONMARK_FENCE_RE if commonmark_indent else FENCE_RE
    lines: list[tuple[str, str]] = []
    fence: str | None = None
    for line in text.splitlines():
        if backtick_toggle:
            if line.lstrip().startswith("```"):
                kind, fence = (OPEN, "```") if fence is None else (CLOSE, None)
            else:
                kind = TEXT if fence is None else CODE
        elif fence is None:
            match = opener_re.match(line)
            if match:
                kind, fence = OPEN, match.group(1)
            else:
                kind = TEXT
        else:
            kind = CODE
            closer = line.lstrip().rstrip(" \t")
            indent = line[:len(line) - len(line.lstrip())]
            if ((not commonmark_indent or re.fullmatch(" {0,3}", indent))
                    and len(closer) >= len(fence)
                    and closer == fence[0] * len(closer)):
                kind, fence = CLOSE, None
        lines.append((kind, line))
    return lines


def fence_segments(text: str, commonmark_indent: bool = False
                   ) -> list[tuple[bool, str]]:
    """Split `text` into consecutive (inside_fence, text) segments, reading
    fences as fence_lines() does. The fence lines belong to their fenced
    segment; an unclosed fence runs to the end of `text`."""
    segments: list[tuple[bool, str]] = []
    current: list[str] = []
    inside = False
    for kind, line in fence_lines(text, commonmark_indent=commonmark_indent):
        if kind == OPEN:
            segments.append((False, "\n".join(current)))
            current, inside = [line], True
        elif kind == CLOSE:
            current.append(line)
            segments.append((True, "\n".join(current)))
            current, inside = [], False
        else:
            current.append(line)
    segments.append((inside, "\n".join(current)))
    return segments


def skill_md_heredoc(script: str, label: str) -> str | None:
    """Return the body of the one heredoc in `script` whose redirect target
    ends in `SKILL.md"`: the text the script writes into a new skill.

    Heredocs are read in order, so a line inside one heredoc's body is never
    taken for a command. A body runs to the line that is exactly its
    delimiter (`<<-` also strips leading tabs, from the body as well). Lines
    starting with `#` outside a body are comments. A missing, duplicated or
    unterminated template heredoc, or one whose delimiter is unquoted (its
    body would undergo expansion, so it is not the text written), is an
    error naming `label`, and returns None."""
    found: list[tuple[int, str, bool, list[str] | None]] = []
    # Heredocs opened on the current command line, waiting for their bodies:
    # (start line, delimiter, strip tabs, body lines or None if not the
    # template).
    pending: list[tuple[int, str, bool, list[str] | None]] = []
    for number, line in enumerate(script.splitlines(), 1):
        if pending:
            start, delimiter, strip_tabs, body = pending[0]
            text = line.lstrip("\t") if strip_tabs else line
            if text == delimiter:
                pending.pop(0)
            elif body is not None:
                body.append(text)
            continue
        if line.lstrip().startswith("#"):
            continue
        operators = list(HEREDOC_RE.finditer(line))
        writes_skill_md = bool(SKILL_MD_REDIRECT_RE.search(line))
        if writes_skill_md and len(operators) != 1:
            error(f"{label}: line {number} writes SKILL.md with "
                  f"{len(operators)} heredocs; expected exactly one")
            return None
        for match in operators:
            strip_tabs = match.group(1) == "-"
            delimiter = (match.group(2) or match.group(3)
                         or match.group(5))
            quoted = bool(match.group(2) or match.group(3)
                          or match.group(4))
            template_body: list[str] | None = None
            if writes_skill_md:
                if not quoted:
                    error(f"{label}: the SKILL.md heredoc on line {number} "
                          f"has an unquoted delimiter {delimiter}; quote it "
                          "so the template is written verbatim")
                    return None
                template_body = []
                found.append((number, delimiter, strip_tabs, template_body))
            pending.append((number, delimiter, strip_tabs, template_body))
    if not found:
        error(f"{label}: no heredoc writes SKILL.md (expected one whose "
              "redirect target ends in SKILL.md\")")
        return None
    if len(found) > 1:
        lines = ", ".join(str(entry[0]) for entry in found)
        error(f"{label}: {len(found)} heredocs write SKILL.md (lines "
              f"{lines}); exactly one is allowed")
        return None
    start, delimiter = found[0][0], found[0][1]
    if any(entry[0] == start for entry in pending):
        error(f"{label}: the SKILL.md heredoc on line {start} is "
              f"unterminated (no {delimiter} line closes it)")
        return None
    return "\n".join(found[0][3])


def check_grounding_region(label: str, parts: list[str],
                           expected_variant: str | None,
                           canonical: dict[str | None, str]) -> None:
    """Require exactly one grounding region across `parts` matching the
    canonical text. A region must sit wholly inside one part."""
    begins = sum(len(GROUNDING_BEGIN_RE.findall(part)) for part in parts)
    ends = sum(part.count(GROUNDING_END) for part in parts)
    regions = [m for part in parts for m in GROUNDING_REGION_RE.finditer(part)]
    wanted = expected_variant or "general"
    if not begins:
        error(f"{label}: grounding block missing (expected the {wanted} text "
              f"from docs/SOURCE_GROUNDING.md)")
        return
    if begins > 1:
        error(f"{label}: grounding block duplicated ({begins} begin markers; "
              "exactly one is allowed)")
        return
    if len(regions) != 1 or ends != 1:
        error(f"{label}: grounding block malformed (begin marker without "
              f"exactly one matching end marker)")
        return
    found = regions[0].group(1)
    if found != expected_variant:
        error(f"{label}: grounding block is the {found or 'general'} text, "
              f"expected the {wanted} text")
        return
    if normalize_grounding(regions[0].group(2)) != canonical[expected_variant]:
        error(f"{label}: grounding block text differs from the {wanted} text "
              "in docs/SOURCE_GROUNDING.md")


def validate_grounding(skill_dirs: list[Path]) -> None:
    """Check every skill's grounding block and the one in the context block."""
    for skill in GROUNDING_VARIANTS:
        if not (SKILLS_DIR / skill / "SKILL.md").exists():
            error(f"GROUNDING_VARIANTS names skill {skill!r}, which does not exist")
    canonical = load_grounding_texts()
    if canonical is None:
        return
    for skill_dir in skill_dirs:
        name = skill_dir.name
        if name in GROUNDING_EXEMPT:
            continue
        segments = fence_segments(
            (skill_dir / "SKILL.md").read_text(encoding="utf-8"))
        if any(inside and GROUNDING_MARKER_RE.search(part)
               for inside, part in segments):
            error(f"skill {name}: grounding marker inside a code fence; "
                  "the block must be live text")
        check_grounding_region(
            f"skill {name}", [part for inside, part in segments if not inside],
            GROUNDING_VARIANTS.get(name), canonical)

    if NEW_SKILL_TEMPLATE.exists():
        label = (f"{NEW_SKILL_TEMPLATE.relative_to(REPO_ROOT).as_posix()} "
                 "(new-skill template)")
        template = skill_md_heredoc(
            NEW_SKILL_TEMPLATE.read_text(encoding="utf-8"), label)
        if template is not None:
            check_grounding_region(label, [template], None, canonical)
    else:
        error(f"Missing {NEW_SKILL_TEMPLATE} (new-skill template)")

    context_md = SKILLS_DIR / "cardano-context" / "SKILL.md"
    if not context_md.exists():
        return
    blocks = list(CONTEXT_BLOCK_RE.finditer(
        context_md.read_text(encoding="utf-8")))
    if len(blocks) != 1:
        error(f"skill cardano-context: expected exactly one canonical context "
              f"block, found {len(blocks)}")
        return
    check_grounding_region("skill cardano-context (context block)",
                           [blocks[0].group(2)], None, canonical)


def validate_context_history() -> None:
    """Require HISTORICAL_BLOCKS_FILE to record every context block before
    the canonical vN in cardano-context's SKILL.md: a `## vK` section holding
    at least one fenced block for each 1 <= K < N, and no section for vN or
    later. Fences are read with CommonMark indentation, as the file's other
    check reads them; a heading counts only at the start of a line, outside
    fences, and runs to the next level-1 or level-2 heading."""
    context_md = SKILLS_DIR / "cardano-context" / "SKILL.md"
    if not context_md.exists():
        return
    blocks = list(CONTEXT_BLOCK_RE.finditer(
        context_md.read_text(encoding="utf-8")))
    if len(blocks) != 1:
        return  # validate_grounding reports the block count
    begin, end = blocks[0].group(1), blocks[0].group(3)
    if int(begin) != int(end):
        error(f"skill cardano-context: canonical context block opens as "
              f"v{begin} but closes as v{end}")
        return
    current_version = int(begin)
    label = HISTORICAL_BLOCKS_FILE.relative_to(REPO_ROOT).as_posix()
    if not HISTORICAL_BLOCKS_FILE.exists():
        if current_version > 1:
            error(f"Missing {label} (must record every context block before "
                  f"v{current_version})")
        return

    fenced_blocks: dict[int, int] = {}
    section: int | None = None
    for inside, part in fence_segments(
            HISTORICAL_BLOCKS_FILE.read_text(encoding="utf-8"),
            commonmark_indent=True):
        if inside:
            if section is not None:
                fenced_blocks[section] += 1
            continue
        for line in part.split("\n"):
            heading = HISTORY_HEADING_RE.fullmatch(line)
            if heading:
                section = int(heading.group(1))
                fenced_blocks.setdefault(section, 0)
            elif HEADING_LEVEL_1_2_RE.match(line):
                section = None
    for version in range(1, current_version):
        if not fenced_blocks.get(version):
            error(f"{label}: no '## v{version}' section with a fenced block; "
                  f"the canonical context block is v{current_version}, so "
                  "every earlier version must be recorded")
    for version in sorted(fenced_blocks):
        if version >= current_version:
            error(f"{label}: '## v{version}' section, but the canonical "
                  f"context block in SKILL.md is v{current_version}; only "
                  "earlier versions belong here")


def load_json(path: Path) -> dict | None:
    if not path.exists():
        error(f"Missing {path}")
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        error(f"{path}: invalid JSON: {exc}")
        return None
    if not isinstance(value, dict):
        error(f"{path}: expected a JSON object")
        return None
    return value


def validate_agent_compatibility() -> None:
    """Validate the shared Claude/Codex packaging and authoring contract."""
    for required in (REPO_ROOT / "AGENTS.md", REPO_ROOT / "CLAUDE.md",
                     COMPATIBILITY_DOC):
        if not required.exists():
            error(f"Missing {required}")

    for link in (REPO_ROOT / ".claude" / "skills",
                 REPO_ROOT / ".agents" / "skills"):
        if not link.is_symlink():
            error(f"{link}: must be a symlink to ../skills")
            continue
        if link.readlink() != Path("../skills"):
            error(f"{link}: expected target ../skills, got {link.readlink()}")
        elif link.resolve() != SKILLS_DIR.resolve():
            error(f"{link}: does not resolve to the canonical skills directory")

    claude = load_json(CLAUDE_MANIFEST)
    codex = load_json(CODEX_MANIFEST)
    if claude is None or codex is None:
        return

    expected_name = "cardano-dev-skills"
    for path, manifest in ((CLAUDE_MANIFEST, claude),
                           (CODEX_MANIFEST, codex)):
        if manifest.get("name") != expected_name:
            error(f"{path}: name must be {expected_name!r}")

    if claude.get("name") != codex.get("name"):
        error("Claude and Codex plugin manifests must use the same name")

    version = codex.get("version")
    if not isinstance(version, str) or not SEMVER_PATTERN.fullmatch(version):
        error(f"{CODEX_MANIFEST}: version must be strict semver")
    if codex.get("skills") != "./skills/":
        error(f"{CODEX_MANIFEST}: skills must point to ./skills/")
    if not isinstance(codex.get("description"), str):
        error(f"{CODEX_MANIFEST}: missing description")
    author = codex.get("author")
    if not isinstance(author, dict) or not author.get("name"):
        error(f"{CODEX_MANIFEST}: missing author.name")
    interface = codex.get("interface")
    if not isinstance(interface, dict):
        error(f"{CODEX_MANIFEST}: missing interface object")
    else:
        for field in ("displayName", "shortDescription", "longDescription",
                      "developerName", "category"):
            if not interface.get(field):
                error(f"{CODEX_MANIFEST}: interface.{field} is required")


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


def load_pinned_names() -> set[str] | None:
    """Source names pinned in registry/pins.yaml, parsed by the same function
    scripts/fetch-docs.sh uses, so what validates here is what a fetch will
    actually honor. Returns None if the file is malformed (already reported),
    so callers skip per-source pin checks instead of cascading them."""
    sys.path.insert(0, str(REPO_ROOT / "scripts"))
    from _fetch_docs import load_pins
    try:
        return set(load_pins(str(PINS_FILE)))
    except SystemExit as e:  # load_pins reports a malformed pin line this way
        error(str(e))
        return None


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
    pinned = load_pinned_names()
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

        # A source with no pin fetches its branch tip, bypassing refresh-PR
        # screening. The registering PR carries the pin (CONTRIBUTING step 3).
        if pinned is not None and name and name not in pinned:
            error(f"{prefix}: no pin in registry/pins.yaml — run "
                  f"./scripts/fetch-docs.sh --source \"{name}\" --update-pins "
                  f"and commit the pin with the source")

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
        skill_dirs: list[Path] = []
        for skill_dir in sorted(SKILLS_DIR.iterdir()):
            if not skill_dir.is_dir():
                continue
            if not (skill_dir / "SKILL.md").exists():
                error(
                    f"{skill_dir}: every immediate directory under skills/ "
                    "must be a discoverable skill with SKILL.md"
                )
                continue
            validate_skill(skill_dir)
            skill_dirs.append(skill_dir)
            skill_count += 1

        # Validate the grounding block in every skill, the new-skill template
        # and the context block.
        validate_grounding(skill_dirs)

        # Validate that every earlier context block is still recorded.
        validate_context_history()

        # Validate the shared authoring contract and both host adapters.
        validate_agent_compatibility()

        # Validate sources
        validate_sources()

    # Validate that every tracked path is checkout-safe on Windows
    path_count = validate_path_portability()

    # Report
    if not args.paths_only:
        print(f"Skills validated: {skill_count}")
        print("Agent adapters validated: Claude Code, Codex")
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
