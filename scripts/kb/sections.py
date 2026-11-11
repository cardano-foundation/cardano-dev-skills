"""Section splitter for the evaluation corpus.

Markdown/MDX files split on ATX headings, ignoring "#" lines inside fenced code
blocks. Every other text file splits into fixed windows of WINDOW lines.
A section is (path, heading trail, start_line, end_line), 1-based inclusive.
Binary or undecodable files are skipped and counted.
"""
import os
import re
from typing import NamedTuple, Tuple

from scripts.kb import corpus

WINDOW = 80
MARKDOWN_EXTENSIONS = (".md", ".mdx")

_FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
_HEADING_RE = re.compile(r"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$")
_CLOSING_HASHES_RE = re.compile(r"(?:^|[ \t]+)#+[ \t]*$")


class Section(NamedTuple):
    path: str
    trail: Tuple[str, ...]
    start_line: int
    end_line: int


def read_text(abs_path):
    """Decoded text, or None for binary or undecodable files."""
    with open(abs_path, "rb") as handle:
        data = handle.read()
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return None


def text_lines(text):
    """Lines split on "\\n" only, so numbering matches an editor; no trailing empty line."""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [line[:-1] if line.endswith("\r") else line for line in lines]


def _fence_closes(line, opener):
    match = _FENCE_RE.match(line)
    if not match:
        return False
    marker = match.group(1)
    return marker[0] == opener[0] and len(marker) >= len(opener) and not match.group(2).strip()


def _front_matter_end(lines):
    """Index just past a leading '---' front matter block, or 0."""
    if lines and lines[0].strip() == "---":
        for index in range(1, len(lines)):
            if lines[index].strip() in ("---", "..."):
                return index + 1
    return 0


def _headings(lines):
    """Yield (line_index, level, title) for ATX headings outside fenced code."""
    fence = None
    for index in range(_front_matter_end(lines), len(lines)):
        line = lines[index]
        if fence is not None:
            if _fence_closes(line, fence):
                fence = None
            continue
        opener = _FENCE_RE.match(line)
        if opener and not (opener.group(1)[0] == "`" and "`" in opener.group(2)):
            fence = opener.group(1)
            continue
        heading = _HEADING_RE.match(line)
        if heading:
            title = _CLOSING_HASHES_RE.sub("", heading.group(2) or "").strip()
            yield index, len(heading.group(1)), title


def split_markdown(path, lines):
    if not lines:
        return []
    heads = list(_headings(lines))
    sections = []
    first = heads[0][0] if heads else len(lines)
    if any(line.strip() for line in lines[:first]):
        sections.append(Section(path, (), 1, first))
    stack = []
    for position, (index, level, title) in enumerate(heads):
        while stack and stack[-1][0] >= level:
            stack.pop()
        stack.append((level, title))
        end = heads[position + 1][0] if position + 1 < len(heads) else len(lines)
        sections.append(Section(path, tuple(t for _l, t in stack), index + 1, end))
    return sections


def split_windows(path, lines):
    return [
        Section(path, (), start + 1, min(start + WINDOW, len(lines)))
        for start in range(0, len(lines), WINDOW)
    ]


def split_text(path, text):
    lines = text_lines(text)
    if path.lower().endswith(MARKDOWN_EXTENSIONS):
        return split_markdown(path, lines)
    return split_windows(path, lines)


def iter_corpus_sections(root=None, stats=None):
    """Yield (Section, section_text) for every readable file in the corpus manifest.

    stats, if given, receives a "skipped" count of binary or undecodable files.
    """
    root = root or corpus.default_root()
    if stats is not None:
        stats.setdefault("skipped", 0)
    for rel in corpus.file_paths(root):
        text = read_text(os.path.join(root, *rel.split("/")))
        if text is None:
            if stats is not None:
                stats["skipped"] += 1
            continue
        lines = text_lines(text)
        for section in split_text(rel, text):
            yield section, "\n".join(lines[section.start_line - 1:section.end_line])


def split_corpus(root=None):
    """(sections, skipped_count) for the whole corpus."""
    stats = {}
    sections = [section for section, _text in iter_corpus_sections(root, stats)]
    return sections, stats["skipped"]
