#!/usr/bin/env python3
"""Fetch documentation from all sources in registry/sources.yaml."""

import argparse
import json
import sys
import os
import subprocess
import shutil
import glob as globmod
import re
from datetime import datetime, timezone
from pathlib import Path


SKIP_DIRS = {'.git', 'node_modules', 'dist', 'build', '.next', '__pycache__',
             '.github', '.vscode', 'target', '.tox', 'vendor'}
SKIP_FILES = {'CHANGELOG.md', 'CONTRIBUTING.md', 'LICENSE.md', 'LICENSE',
              'CODE_OF_CONDUCT.md', 'SECURITY.md'}

# Supply-chain sanitization: bundled docs are read by AI agents, so strip the
# places where instructions hide from a human reviewer while staying visible
# to a model. Invisible/format-control characters (zero-width, bidi controls,
# and the U+E0000 tag-character block used for ASCII smuggling) are removed
# from every text file; HTML comments — which render invisibly but are read
# verbatim by an agent — are stripped from markup. `<script>` is intentionally
# NOT stripped: a bundled doc is read as inert text (never executed), so
# stripping it only mangles legitimate web-dev tutorials.
INVISIBLE_CHARS_RE = re.compile(
    '[​-‏'      # zero-width space/joiners, LRM/RLM
    '‪-‮'       # bidi embedding/override
    '⁠-⁤'       # word-joiner, invisible math operators
    '⁦-⁩'       # bidi isolates
    '﻿'             # zero-width no-break space / BOM
    '؜]'            # arabic letter mark
    '|[\U000e0000-\U000e007f]')  # unicode tag chars (ASCII smuggling)
HTML_COMMENT_RE = re.compile(r'<!--.*?-->', re.DOTALL)
MARKUP_EXTS = {'.md', '.mdx', '.html', '.htm'}


def copy_sanitized(src, dest):
    """Copy a doc file, sanitizing text content; binary files copy as-is.

    Decodes with errors='replace' rather than bailing out to a verbatim copy,
    so a single non-UTF-8 byte can't smuggle an un-sanitized payload past the
    filter. A file that is genuinely binary (contains a NUL byte) is copied
    unchanged — sanitizing it would corrupt it and it isn't agent-read text.
    """
    ext = os.path.splitext(src)[1].lower()
    try:
        with open(src, 'rb') as f:
            data = f.read()
    except OSError:
        shutil.copy2(src, dest)
        return
    if b'\x00' in data:  # binary asset — copy verbatim
        shutil.copy2(src, dest)
        return
    text = data.decode('utf-8', 'replace')
    text = INVISIBLE_CHARS_RE.sub('', text)
    if ext in MARKUP_EXTS:
        text = HTML_COMMENT_RE.sub('', text)
    with open(dest, 'w', encoding='utf-8') as f:
        f.write(text)


PINS_HEADER = """\
# Upstream commit pins for documentation sources — auto-generated, do not
# edit by hand.
#
# Records the upstream commit each source in sources.yaml was last vetted
# at. `scripts/fetch-docs.sh` checks out the pinned commit instead of the
# branch tip, so what ships in docs/sources/ is exactly what passed the
# refresh PR's security screening (delta scanner + AI review). The weekly
# refresh runs `fetch-docs.sh --update-pins`, which fetches branch tips and
# proposes new pins — one commit per source in the refresh PR, so a bad
# upstream delta can be reverted per source.
#
# A source with no entry here (e.g. newly added) fetches its branch tip;
# the next refresh records its first pin.
"""


def load_pins(path):
    """Parse pins.yaml into {source name: commit sha}."""
    pins = {}
    if not os.path.exists(path):
        return pins
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = re.match(r'^"(.+)":\s*([0-9a-f]{7,40})\s*$', line)
            if m:
                pins[m.group(1)] = m.group(2)
    return pins


def write_pins(path, pins):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(PINS_HEADER)
        for name in sorted(pins):
            f.write(f'"{name}": {pins[name]}\n')


def parse_sources_yaml(path):
    """Parse sources.yaml without pyyaml - handles our specific format."""
    sources = []
    current = None
    last_list_key = None

    with open(path, encoding='utf-8') as f:
        lines = f.readlines()

    for line in lines:
        raw = line.rstrip('\n')
        stripped = raw.strip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith('#'):
            continue

        # New source entry: "- name: Foo"
        if raw.startswith('- name:'):
            if current is not None:
                sources.append(current)
            current = {'name': raw.split(':', 1)[1].strip().strip('"')}
            last_list_key = None
            continue

        if current is None:
            continue

        # List item: "    - value"
        if re.match(r'^    - ', raw):
            item = raw.strip()[2:].strip().strip('"')
            if last_list_key and last_list_key in current:
                current[last_list_key].append(item)
            continue

        # Nested mapping value: '    "**/*.yaml": openapi'
        if re.match(r'^    "', raw):
            m = re.match(r'^\s+"([^"]+)":\s*(.+)', raw)
            if m and last_list_key == 'format_overrides':
                if 'format_overrides' not in current:
                    current['format_overrides'] = {}
                current['format_overrides'][m.group(1)] = m.group(2).strip().strip('"')
            continue

        # Regular key: "  key: value"
        if re.match(r'^  [a-z]', raw) and ':' in stripped:
            key, val = stripped.split(':', 1)
            key = key.strip()
            val = val.strip().strip('"')

            if not val:
                current[key] = {} if key == 'format_overrides' else []
                last_list_key = key
            else:
                current[key] = val
                last_list_key = None
            continue

    if current is not None:
        sources.append(current)

    return sources


def slugify(name):
    """Convert source name to directory-safe slug."""
    return re.sub(r'[^a-z0-9]+', name.lower(), '-').strip('-')


def should_skip(filepath):
    """Check if a file should be skipped."""
    parts = Path(filepath).parts
    for part in parts:
        if part in SKIP_DIRS:
            return True
    if os.path.basename(filepath) in SKIP_FILES:
        return True
    if os.path.getsize(filepath) > 500_000:
        return True
    return False


def clone_and_extract(source, tmp_dir, docs_dir, pin=None):
    """Clone a repo (at the pinned commit if given) and extract only
    documentation files. Returns (file_count, head_sha, pin_ok).

    pin_ok is False only when a pin was requested but could not be honored
    (fetch or checkout failed) — the caller treats that as a hard error in
    consumer mode so unvetted branch-tip content is never shipped silently.
    Extraction stages into a temp dir and only replaces the existing snapshot
    when it yields files, so a failed/empty fetch never deletes good docs."""
    name = source['name']
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    repo = source.get('repo', '')
    docs_path = source.get('docs_path', 'docs')
    fmt = source.get('format', 'markdown')
    branch = source.get('branch', '')
    glob_patterns = source.get('glob_patterns', [])

    if not repo:
        print(f"  SKIP {name}: no repo URL")
        return 0, '', True

    print(f"  Fetching {name}...")

    clone_dir = os.path.join(tmp_dir, slug)
    cmd = ['git', 'clone', '--depth', '1', '--single-branch']
    if branch:
        cmd.extend(['--branch', branch])
    cmd.extend([repo, clone_dir])

    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=True)
    except subprocess.CalledProcessError as e:
        print(f"  ERROR cloning {name}: {e.stderr.strip()[:200]}")
        return 0, '', True
    except subprocess.TimeoutExpired:
        print(f"  ERROR cloning {name}: timeout")
        return 0, '', True

    pin_ok = True
    if pin:
        # Check out the vetted commit instead of the branch tip. GitHub allows
        # fetching reachable commits by sha; if the pin is gone (force-push
        # upstream) or the checkout fails, that is a hard failure — do NOT
        # silently ship the unvetted tip.
        fetched = subprocess.run(
            ['git', '-C', clone_dir, 'fetch', '--depth', '1', 'origin', pin],
            capture_output=True, text=True, timeout=120)
        checked_out = fetched.returncode == 0 and subprocess.run(
            ['git', '-C', clone_dir, 'checkout', '--quiet', 'FETCH_HEAD'],
            capture_output=True, text=True).returncode == 0
        if not checked_out:
            print(f"  ERROR {name}: pinned commit {pin[:12]} not fetchable/"
                  f"checkout failed (rewritten upstream?) — refusing to ship "
                  f"the unvetted branch tip")
            return 0, '', False

    head = subprocess.run(['git', '-C', clone_dir, 'rev-parse', 'HEAD'],
                          capture_output=True, text=True)
    head_sha = head.stdout.strip() if head.returncode == 0 else ''

    # Determine source directory
    if docs_path == '.':
        src_dir = clone_dir
    else:
        src_dir = os.path.join(clone_dir, docs_path)

    if not os.path.exists(src_dir):
        print(f"  WARN {name}: docs_path '{docs_path}' not found, using repo root")
        src_dir = clone_dir

    # File extensions by format
    ext_map = {
        'markdown': ['*.md'],
        'mdx': ['*.md', '*.mdx'],
        'rst': ['*.rst'],
        'openapi': ['*.yaml', '*.yml', '*.json'],
        'aiken': ['*.ak', '*.md'],
        'toml': ['*.toml', '*.md'],
    }
    default_exts = ext_map.get(fmt, ['*.md'])

    dest_dir = os.path.join(docs_dir, slug)
    # Stage into a sibling temp dir; only swap into place if extraction yields
    # files, so an empty/failed extraction can't delete the existing snapshot.
    stage_dir = os.path.join(tmp_dir, f"{slug}.stage")
    shutil.rmtree(stage_dir, ignore_errors=True)
    os.makedirs(stage_dir, exist_ok=True)

    patterns = glob_patterns or default_exts
    file_count = 0
    for pattern in patterns:
        if glob_patterns:
            full_pattern = os.path.join(src_dir, pattern)
        else:
            full_pattern = os.path.join(src_dir, '**', pattern)
        for filepath in globmod.glob(full_pattern, recursive=True):
            if os.path.isfile(filepath) and not should_skip(filepath):
                rel = os.path.relpath(filepath, src_dir)
                dest = os.path.join(stage_dir, rel)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                copy_sanitized(filepath, dest)
                file_count += 1

    if file_count == 0:
        shutil.rmtree(stage_dir, ignore_errors=True)
        print(f"  WARN {name}: no documentation files found — keeping "
              f"existing snapshot")
        return 0, head_sha, pin_ok

    shutil.rmtree(dest_dir, ignore_errors=True)
    shutil.move(stage_dir, dest_dir)
    print(f"  OK   {name}: {file_count} files @ {head_sha[:12]}")
    return file_count, head_sha, pin_ok


def write_manifest_from_disk(all_sources, docs_dir):
    """Build manifest from actual disk state, so it's correct after partial or full fetches."""
    present = []
    total_files = 0

    for source in all_sources:
        name = source['name']
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
        slug_dir = os.path.join(docs_dir, slug)
        if not os.path.isdir(slug_dir):
            continue
        count = 0
        for _root, _dirs, files in os.walk(slug_dir):
            count += sum(1 for f in files if not f.startswith('.'))
        if count > 0:
            present.append(name)
            total_files += count

    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    manifest_path = os.path.join(docs_dir, '.manifest.yaml')
    with open(manifest_path, 'w') as f:
        f.write("# Auto-generated by fetch-docs.sh\n")
        f.write(f'last_fetched: "{now}"\n')
        f.write(f"total_sources: {len(present)}\n")
        f.write(f"total_files: {total_files}\n")
        f.write("sources:\n")
        for name in sorted(present):
            f.write(f'  - "{name}"\n')

    return len(present), total_files


def main():
    parser = argparse.ArgumentParser(
        description="Fetch documentation from sources in registry/sources.yaml")
    parser.add_argument('sources_yaml')
    parser.add_argument('docs_dir')
    parser.add_argument('tmp_dir')
    parser.add_argument('source_filter', nargs='?', default='')
    parser.add_argument('--update-pins', action='store_true',
                        help="fetch branch tips and rewrite pins.yaml with "
                             "the new upstream commits (weekly refresh mode)")
    parser.add_argument('--pins-file', default=None,
                        help="pins file path (default: pins.yaml next to "
                             "sources.yaml)")
    parser.add_argument('--manifest-out', default=None,
                        help="write a JSON manifest of per-source old/new "
                             "commit shas (for per-source refresh commits)")
    args = parser.parse_args()

    sources_yaml = args.sources_yaml
    docs_dir = args.docs_dir
    tmp_dir = args.tmp_dir
    filter_source = args.source_filter or None
    pins_file = args.pins_file or os.path.join(
        os.path.dirname(os.path.abspath(sources_yaml)), 'pins.yaml')

    all_sources = parse_sources_yaml(sources_yaml)
    pins = load_pins(pins_file)
    print(f"Parsed {len(all_sources)} sources from registry "
          f"({len(pins)} pinned)")

    if filter_source:
        sources = [s for s in all_sources if s['name'].lower() == filter_source.lower()]
        if not sources:
            print(f"Error: source '{filter_source}' not found")
            sys.exit(1)
    else:
        sources = all_sources

    os.makedirs(docs_dir, exist_ok=True)

    run_files = 0
    run_fetched = []
    records = []
    pin_failures = []

    for source in sources:
        name = source['name']
        pin = None if args.update_pins else pins.get(name)
        count, head_sha, pin_ok = clone_and_extract(
            source, tmp_dir, docs_dir, pin=pin)
        if not pin_ok:
            pin_failures.append(name)
        run_files += count
        if count > 0:
            run_fetched.append(name)
        # Only sources that actually produced files are eligible for a pin
        # bump / manifest record — a failed or empty fetch must never be
        # ratified as "vetted at new_sha".
        if count > 0 and head_sha:
            records.append({
                'name': name,
                'slug': re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-'),
                'old_sha': pins.get(name, ''),
                'new_sha': head_sha,
                'files': count,
            })

    # Prune snapshots for sources no longer in the registry (replaces a blunt
    # up-front rmtree of everything, which destroyed good docs whenever a
    # single fetch failed). Only on a full run, never a single-source fetch.
    if not filter_source:
        registry_slugs = {re.sub(r'[^a-z0-9]+', '-', s['name'].lower()).strip('-')
                          for s in all_sources}
        for entry in os.listdir(docs_dir):
            full = os.path.join(docs_dir, entry)
            if (os.path.isdir(full) and entry not in registry_slugs):
                shutil.rmtree(full, ignore_errors=True)
                print(f"  PRUNED {entry}: no longer in registry")

    if args.update_pins:
        registry_names = {s['name'] for s in all_sources}
        # Drop pins for sources removed from the registry; bump the rest.
        new_pins = {n: sha for n, sha in pins.items() if n in registry_names}
        for rec in records:
            new_pins[rec['name']] = rec['new_sha']
        write_pins(pins_file, new_pins)
        bumped = sum(1 for r in records if r['old_sha'] != r['new_sha'])
        print(f"Pins updated: {bumped} of {len(records)} fetched sources "
              f"moved ({pins_file})")

    if args.manifest_out:
        with open(args.manifest_out, 'w', encoding='utf-8') as f:
            json.dump(records, f, indent=2)

    total_sources, total_files = write_manifest_from_disk(all_sources, docs_dir)

    print(f"\nDone: {run_files} files from {len(run_fetched)} sources this run")
    print(f"Manifest: {total_sources} sources, {total_files} files on disk")
    print(f"Output: {docs_dir}")

    # In consumer/pinned mode a pin that couldn't be honored is a hard error:
    # exit non-zero so a force-pushed-away pin surfaces instead of silently
    # shipping the unvetted tip. (--update-pins intentionally ignores pins.)
    if pin_failures and not args.update_pins:
        print(f"\nERROR: {len(pin_failures)} source(s) could not be fetched at "
              f"their pinned commit: {', '.join(pin_failures)}")
        sys.exit(2)


if __name__ == '__main__':
    main()
