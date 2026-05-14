#!/usr/bin/env bash
#
# SessionStart hook: check docs corpus freshness and project-level Cardano
# context. All checks are fail-open: any failure exits 0 silently.
#
set -u
# Note: no `set -e` — we want this script to never block a session.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
DOCS_DIR="${PLUGIN_ROOT}/docs/sources"
MANIFEST="${DOCS_DIR}/.manifest.yaml"
STALE_DAYS=30

# Install topology: local clone (has .git) vs marketplace cache install.
if [ -n "${PLUGIN_ROOT}" ] && [ -d "${PLUGIN_ROOT}/.git" ]; then
    IS_LOCAL_CLONE=1
else
    IS_LOCAL_CLONE=0
fi

refresh_hint() {
    if [ "${IS_LOCAL_CLONE}" -eq 1 ]; then
        echo "  cd ${PLUGIN_ROOT} && git pull && ./scripts/fetch-docs.sh"
    else
        echo "  Refresh via: /plugin marketplace update easy1staking-com"
    fi
}

# Check if docs exist at all
if [ ! -d "$DOCS_DIR" ] || [ ! -f "$MANIFEST" ]; then
  echo "[Cardano Dev Skills] Documentation sources not found."
  echo ""
  echo "The skills plugin works but will produce better results with local docs."
  echo "To fetch all 40+ Cardano documentation sources (~23MB), run:"
  echo ""
  refresh_hint
else
  # Check freshness
  LAST_FETCHED=$(grep 'last_fetched:' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/')

  FETCH_EPOCH=0
  if [ -n "${LAST_FETCHED}" ]; then
    if [[ "$(uname 2>/dev/null)" == "Darwin" ]]; then
      FETCH_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_FETCHED" "+%s" 2>/dev/null || echo 0)
    else
      FETCH_EPOCH=$(date -d "$LAST_FETCHED" "+%s" 2>/dev/null || echo 0)
    fi
  fi

  # If date parsing failed, use manifest file mtime as fallback
  if [ "${FETCH_EPOCH:-0}" -eq 0 ] 2>/dev/null; then
    if [[ "$(uname 2>/dev/null)" == "Darwin" ]]; then
      FETCH_EPOCH=$(stat -f %m "$MANIFEST" 2>/dev/null || echo 0)
    else
      FETCH_EPOCH=$(stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)
    fi
  fi

  NOW_EPOCH=$(date "+%s" 2>/dev/null || echo 0)
  TOTAL_SOURCES=$(grep 'total_sources:' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*: *//')
  TOTAL_FILES=$(grep 'total_files:' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*: *//')

  # Sanity check
  if [ "${FETCH_EPOCH:-0}" -eq 0 ] 2>/dev/null || [ "${FETCH_EPOCH:-0}" -gt "${NOW_EPOCH:-0}" ] 2>/dev/null; then
    echo "[Cardano Dev Skills] Docs loaded: ${TOTAL_SOURCES} sources, ${TOTAL_FILES} files"
  else
    AGE_DAYS=$(( (NOW_EPOCH - FETCH_EPOCH) / 86400 ))
    if [ "${AGE_DAYS}" -gt "${STALE_DAYS}" ] 2>/dev/null; then
      echo "[Cardano Dev Skills] Docs are ${AGE_DAYS} days old (${TOTAL_SOURCES} sources, ${TOTAL_FILES} files). Consider refreshing:"
      refresh_hint
    else
      echo "[Cardano Dev Skills] Docs loaded: ${TOTAL_SOURCES} sources, ${TOTAL_FILES} files (updated ${AGE_DAYS}d ago)"
    fi
  fi
fi

# ----------------------------------------------------------------------------
# Addition A: CLAUDE.md block detection (cwd nudge)
# ----------------------------------------------------------------------------
# Suppress if cwd IS the plugin root itself (plugin author working on plugin).
CWD_REAL=$( { cd . && pwd -P; } 2>/dev/null || echo "" )
PLUGIN_REAL=$( { cd "${PLUGIN_ROOT}" && pwd -P; } 2>/dev/null || echo "__plugin_unreachable__" )

if [ -n "${CWD_REAL}" ] && [ "${CWD_REAL}" != "${PLUGIN_REAL}" ]; then
    if [ -f "./CLAUDE.md" ] && grep -q '<!-- BEGIN cardano-dev-skills' "./CLAUDE.md" 2>/dev/null; then
        echo "[Cardano Dev Skills] Cardano context active in this project."
    elif [ -d "./.git" ] || [ -f "./CLAUDE.md" ] || [ -d "./.claude" ]; then
        echo "[Cardano Dev Skills] Tip: run /cardano-context to enable auto-consultation in this project."
    fi
fi

# ----------------------------------------------------------------------------
# Addition C: local-clone behind-upstream check (opportunistic, no network)
# ----------------------------------------------------------------------------
if [ "${IS_LOCAL_CLONE}" -eq 1 ] && [ -f "${PLUGIN_ROOT}/.git/FETCH_HEAD" ]; then
    BEHIND=$(git -C "${PLUGIN_ROOT}" rev-list HEAD..FETCH_HEAD --count 2>/dev/null || echo 0)
    if [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null; then
        echo "[Cardano Dev Skills] Plugin clone is ${BEHIND} commit(s) behind FETCH_HEAD — consider 'git pull' in ${PLUGIN_ROOT}"
    fi
fi

exit 0
