#!/usr/bin/env python3
"""Fetch documentation from all sources in registry/sources.yaml."""

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


def clone_and_extract(source, tmp_dir, docs_dir):
    """Clone a repo and extract only documentation files."""
    name = source['name']
    slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    repo = source.get('repo', '')
    docs_path = source.get('docs_path', 'docs')
    fmt = source.get('format', 'markdown')
    branch = source.get('branch', '')
    glob_patterns = source.get('glob_patterns', [])

    if not repo:
        print(f"  SKIP {name}: no repo URL")
        return 0

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
        return 0
    except subprocess.TimeoutExpired:
        print(f"  ERROR cloning {name}: timeout")
        return 0

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
    # Clear previous snapshot so files removed upstream don't linger
    shutil.rmtree(dest_dir, ignore_errors=True)
    os.makedirs(dest_dir, exist_ok=True)

    file_count = 0

    if glob_patterns:
        for pattern in glob_patterns:
            full_pattern = os.path.join(src_dir, pattern)
            for filepath in globmod.glob(full_pattern, recursive=True):
                if os.path.isfile(filepath) and not should_skip(filepath):
                    rel = os.path.relpath(filepath, src_dir)
                    dest = os.path.join(dest_dir, rel)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    shutil.copy2(filepath, dest)
                    file_count += 1
    else:
        for ext_pattern in default_exts:
            full_pattern = os.path.join(src_dir, '**', ext_pattern)
            for filepath in globmod.glob(full_pattern, recursive=True):
                if os.path.isfile(filepath) and not should_skip(filepath):
                    rel = os.path.relpath(filepath, src_dir)
                    dest = os.path.join(dest_dir, rel)
                    os.makedirs(os.path.dirname(dest), exist_ok=True)
                    shutil.copy2(filepath, dest)
                    file_count += 1

    if file_count == 0:
        shutil.rmtree(dest_dir, ignore_errors=True)
        print(f"  WARN {name}: no documentation files found")
    else:
        print(f"  OK   {name}: {file_count} files")

    return file_count


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
    if len(sys.argv) < 4:
        print("Usage: _fetch_docs.py <sources.yaml> <docs_dir> <tmp_dir> [source_filter]")
        sys.exit(1)

    sources_yaml = sys.argv[1]
    docs_dir = sys.argv[2]
    tmp_dir = sys.argv[3]
    filter_source = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None

    all_sources = parse_sources_yaml(sources_yaml)
    print(f"Parsed {len(all_sources)} sources from registry")

    if filter_source:
        sources = [s for s in all_sources if s['name'].lower() == filter_source.lower()]
        if not sources:
            print(f"Error: source '{filter_source}' not found")
            sys.exit(1)
    else:
        # Full refresh: clear existing docs
        if os.path.exists(docs_dir):
            shutil.rmtree(docs_dir)
        sources = all_sources

    os.makedirs(docs_dir, exist_ok=True)

    run_files = 0
    run_fetched = []

    for source in sources:
        count = clone_and_extract(source, tmp_dir, docs_dir)
        run_files += count
        if count > 0:
            run_fetched.append(source['name'])

    total_sources, total_files = write_manifest_from_disk(all_sources, docs_dir)

    print(f"\nDone: {run_files} files from {len(run_fetched)} sources this run")
    print(f"Manifest: {total_sources} sources, {total_files} files on disk")
    print(f"Output: {docs_dir}")


if __name__ == '__main__':
    main()
