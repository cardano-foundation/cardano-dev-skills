#!/usr/bin/env bash
#
# fetch-docs.sh - Clone all documentation sources and extract doc files
#
# Reads registry/sources.yaml, shallow-clones each repo, and copies
# only the documentation files into docs/sources/<source-name>/.
#
# Usage:
#   ./scripts/fetch-docs.sh                    # fetch all sources at pinned commits
#   ./scripts/fetch-docs.sh --source Aiken     # fetch a single source
#   ./scripts/fetch-docs.sh --update-pins --manifest-out /tmp/manifest.json
#                                              # weekly refresh: fetch branch
#                                              # tips, rewrite registry/pins.yaml
#
# Requires: python3, git
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCES_YAML="$REPO_ROOT/registry/sources.yaml"
DOCS_DIR="$REPO_ROOT/docs/sources"
TMP_DIR=$(mktemp -d)
FILTER_SOURCE=""

EXTRA_ARGS=()

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      FILTER_SOURCE="$2"
      shift 2
      ;;
    --update-pins)
      EXTRA_ARGS+=("--update-pins")
      shift
      ;;
    --manifest-out)
      EXTRA_ARGS+=("--manifest-out" "$2")
      shift 2
      ;;
    --update)
      shift
      ;;
    *)
      shift
      ;;
  esac
done

trap 'rm -rf "$TMP_DIR"' EXIT

if [ ! -f "$SOURCES_YAML" ]; then
  echo "Error: $SOURCES_YAML not found" >&2
  exit 1
fi

echo "Fetching Cardano documentation sources..."
echo "  Registry: $SOURCES_YAML"
echo "  Output:   $DOCS_DIR"
echo ""

python3 "$SCRIPT_DIR/_fetch_docs.py" "$SOURCES_YAML" "$DOCS_DIR" "$TMP_DIR" "$FILTER_SOURCE" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}

echo ""
du -sh "$DOCS_DIR" 2>/dev/null || true
