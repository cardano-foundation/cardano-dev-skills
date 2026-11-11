#!/usr/bin/env python3
"""Corpus manifest v1 for docs/sources/.

The manifest lists every regular file under <root>/docs/sources (sorted POSIX
paths relative to <root>) with the sha256 of its bytes. corpus_id is the sha256
of the "<path>\\0<sha256>\\n" lines, so any added, removed, renamed or edited
file changes it. Symlinks are not regular files and are left out.

Usage: python3 scripts/kb/corpus.py [--root DIR] [--json]
"""
import argparse
import hashlib
import json
import os
import sys

MANIFEST_VERSION = 1
SOURCES_SUBDIR = ("docs", "sources")


def default_root():
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_paths(root):
    """Sorted POSIX paths (relative to root) of regular files under docs/sources."""
    base = os.path.join(root, *SOURCES_SUBDIR)
    if not os.path.isdir(base):
        raise FileNotFoundError("corpus directory not found: %s" % base)
    found = []
    for dirpath, _dirnames, filenames in os.walk(base, followlinks=False):
        for name in filenames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full) or not os.path.isfile(full):
                continue
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            found.append(rel)
    found.sort()
    return found


def compute_corpus_id(entries):
    digest = hashlib.sha256()
    for entry in entries:
        digest.update(("%s\0%s\n" % (entry["path"], entry["sha256"])).encode("utf-8"))
    return digest.hexdigest()


def build_manifest(root=None):
    root = root or default_root()
    entries = [
        {"path": rel, "sha256": sha256_file(os.path.join(root, *rel.split("/")))}
        for rel in file_paths(root)
    ]
    return {
        "version": MANIFEST_VERSION,
        "corpus_id": compute_corpus_id(entries),
        "files": entries,
    }


def corpus_id(root=None):
    return build_manifest(root)["corpus_id"]


def main(argv=None):
    parser = argparse.ArgumentParser(description="Print the docs/sources corpus_id.")
    parser.add_argument("--root", help="directory containing docs/sources (default: repo root)")
    parser.add_argument("--json", action="store_true", help="print the full manifest")
    args = parser.parse_args(argv)
    try:
        manifest = build_manifest(args.root)
    except FileNotFoundError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(manifest, indent=2, sort_keys=True))
    else:
        print(manifest["corpus_id"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
