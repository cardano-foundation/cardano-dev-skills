#!/usr/bin/env bash
#
# Tests for hooks/check-docs.sh.
#
# check-docs.sh runs at SessionStart on every user's machine, so its one hard
# promise is that it never fails a session: every case below asserts exit 0.
# It is also the script whose bugs are least likely to be noticed, because
# `trap 'exit 0' EXIT` means a broken hook prints nothing rather than
# complaining — which is how a greedy sed disabled the staleness warning on
# every platform without anyone seeing it.
#
# The BSD/GNU split is exercised on either host with shims that provide only
# what the hook actually calls, because the real bug was a Mac carrying GNU
# coreutils, which no single CI runner reproduces on its own.
#
# Usage: hooks/test-check-docs.sh   (exits non-zero if any case fails)
set -u

HOOK="$(cd "$(dirname "$0")" && pwd)/check-docs.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Exported because the shims below are separate /bin/sh processes: an
# unexported REAL_DATE expands to the empty string inside them, so every
# shimmed call fails and the hook falls all the way through to epoch 0. Cases 8
# and 9 still passed like that, because they assert only exit 0 and the absence
# of the unbound-variable abort, and neither needs the shim to work — the split
# they exist to cover was never actually exercised.
export REAL_DATE="$(command -v date)"
export REAL_STAT="$(command -v stat)"

pass=0
fail=0

# --- assertions ---------------------------------------------------------

# run_hook <root> [path-prefix] -> sets OUT and RC
run_hook() {
  local root="$1" prefix="${2:-}"
  set +e
  if [ -n "${prefix}" ]; then
    OUT="$(cd / && PATH="${prefix}:${PATH}" CLAUDE_PLUGIN_ROOT="${root}" "${HOOK}" 2>&1)"
  else
    OUT="$(cd / && CLAUDE_PLUGIN_ROOT="${root}" "${HOOK}" 2>&1)"
  fi
  RC=$?
  # Deliberately left with errexit off: the script never enables it, and every
  # assertion below reads a non-zero status as a result rather than a fault.
}

check() {
  local name="$1" cond="$2"
  if [ "${cond}" -eq 0 ]; then
    pass=$((pass + 1)); printf '  ok   %s\n' "${name}"
  else
    fail=$((fail + 1)); printf '  FAIL %s\n' "${name}"
    printf '       exit=%s output:\n%s\n' "${RC}" "${OUT}" | sed 's/^/       /'
  fi
}

contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

# --- fixtures -----------------------------------------------------------

make_root() {  # make_root <name> <last_fetched-line>
  local root="${TMP}/$1"
  mkdir -p "${root}/docs/sources"
  {
    printf '%s\n' "$2"
    printf 'total_sources: 67\n'
    printf 'total_files: 3764\n'
  } > "${root}/docs/sources/.manifest.yaml"
  printf '%s' "${root}"
}

# Both shims below convert through the HOST's real date/stat, since the host may
# be either flavour. They validate the ISO shape themselves and exit 1 otherwise,
# so an unparseable timestamp fails the way the real tool fails rather than
# falling through to a flag the host reads as something else entirely.
# The two flavours differ in more than flag spelling: GNU `date -d` honours the
# trailing Z and returns UTC, while BSD `date -j -f` matches the Z as a literal
# and reads the timestamp in LOCAL time. Reproducing that difference is the
# point — a shim that parsed both the same way could not fail on the TZ bug.
if "${REAL_DATE}" --version >/dev/null 2>&1; then
  ISO_EPOCH_UTC='"${REAL_DATE}" -d "$1" +%s'
  # Drop the Z so GNU date stops honouring it: that is BSD's behaviour.
  ISO_EPOCH_LOCAL='"${REAL_DATE}" -d "$(iso_naive "$1")" +%s'
  HOST_MTIME='"${REAL_STAT}" -c %Y "$1"'
else
  ISO_EPOCH_UTC='TZ=UTC "${REAL_DATE}" -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s'
  ISO_EPOCH_LOCAL='"${REAL_DATE}" -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s'
  HOST_MTIME='"${REAL_STAT}" -f %m "$1"'
fi

write_shims() {  # write_shims <dir> <flavour>
  local d="$1" flavour="$2" iso_epoch
  case "${flavour}" in
    gnu) iso_epoch="${ISO_EPOCH_UTC}" ;;
    *)   iso_epoch="${ISO_EPOCH_LOCAL}" ;;
  esac
  mkdir -p "${d}"
  cat > "${d}/date" <<EOF
#!/bin/sh
# "2020-01-01T00:00:00Z" -> "2020-01-01 00:00:00", i.e. no timezone at all,
# which a parser then reads in local time.
iso_naive() { t="\${1%Z}"; printf '%s %s' "\${t%%T*}" "\${t#*T}"; }
iso_epoch() { ${iso_epoch}; }
is_iso() {
  case "\$1" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) return 0 ;;
    *) return 1 ;;
  esac
}
case "${flavour}:\$1" in
  gnu:--version) echo "date (GNU coreutils) 9.4"; exit 0 ;;
  bsd:--version) exit 1 ;;
  gnu:-d)  is_iso "\$2" || exit 1; iso_epoch "\$2" ;;
  gnu:-j)  exit 1 ;;
  bsd:-j)  is_iso "\$4" || exit 1; iso_epoch "\$4" ;;
  bsd:-d)  exit 1 ;;
  *) exec "${REAL_DATE}" "\$@" ;;
esac
EOF
  cat > "${d}/stat" <<EOF
#!/bin/sh
mtime() { ${HOST_MTIME}; }
case "${flavour}:\$1" in
  gnu:--version) echo "stat (GNU coreutils) 9.4"; exit 0 ;;
  bsd:--version) exit 1 ;;
  gnu:-c)  mtime "\$3" ;;
  # GNU stat -f means FILESYSTEM status: it SUCCEEDS while printing prose. That
  # is the whole bug — a BSD-shaped call on a GNU box returned 0 and text, and
  # the text reached \$(( )).
  gnu:-f)  printf '  File: "%s"\\n  ID: 0 Namelen: 255 Type: apfs\\n' "\$2"; exit 0 ;;
  bsd:-f)  mtime "\$3" ;;
  bsd:-c)  exit 1 ;;
  *) exec "${REAL_STAT}" "\$@" ;;
esac
EOF
}

write_shims "${TMP}/gnu" gnu
write_shims "${TMP}/bsd" bsd

chmod +x "${TMP}"/gnu/* "${TMP}"/bsd/*

echo "check-docs.sh"

# --- cases --------------------------------------------------------------

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. A current manifest reports loaded docs and says nothing about staleness.
root="$(make_root fresh "last_fetched: \"${NOW_ISO}\"")"
run_hook "${root}"
contains "${OUT}" "Docs loaded" && [ "${RC}" -eq 0 ]; check "fresh manifest reports loaded, exit 0" $?

# 2. THE REGRESSION GUARD. A stale manifest must say so. The greedy sed left
#    this branch unreachable on every platform: the timestamp never parsed, the
#    mtime fallback always won, and the file had just been written, so every
#    install reported "0d ago" no matter how old its docs were.
root="$(make_root stale 'last_fetched: "2020-01-01T00:00:00Z"')"
run_hook "${root}"
contains "${OUT}" "Docs are " && contains "${OUT}" "days old" && [ "${RC}" -eq 0 ]
check "stale manifest reports its age, exit 0" $?

# 3. The parsed timestamp keeps its own colons. Guards the greedy pattern
#    directly: `.*:` reduced 2026-08-24T06:15:41Z to 41Z.
got="$(sed -n 's/^last_fetched:[[:space:]]*"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' \
        "${TMP}/stale/docs/sources/.manifest.yaml" | head -1)"
[ "${got}" = "2020-01-01T00:00:00Z" ]; check "timestamp parses whole, not just the last field" $?

# 4. Counts parse.
root="$(make_root counts "last_fetched: \"${NOW_ISO}\"")"
run_hook "${root}"
contains "${OUT}" "67 sources" && contains "${OUT}" "3764 files"; check "source and file counts parse" $?

# 5. An unparseable timestamp must not fail the session.
root="$(make_root garbage 'last_fetched: not-a-date')"
run_hook "${root}"
[ "${RC}" -eq 0 ]; check "unparseable timestamp exits 0" $?

# 6. A missing manifest must not fail the session.
root="${TMP}/nomanifest"; mkdir -p "${root}/docs/sources"
run_hook "${root}"
contains "${OUT}" "not found" && [ "${RC}" -eq 0 ]; check "missing manifest exits 0" $?

# 7. A future timestamp trips the sanity branch rather than printing a
#    negative age.
root="$(make_root future 'last_fetched: "2099-01-01T00:00:00Z"')"
run_hook "${root}"
contains "${OUT}" "Docs loaded" && [ "${RC}" -eq 0 ]; check "future timestamp exits 0" $?

# 8. GNU date+stat, i.e. Linux, or a Mac with coreutils on PATH. This is the
#    case that aborted with `File: unbound variable` and exit 2.
root="$(make_root gnu 'last_fetched: "2020-01-01T00:00:00Z"')"
run_hook "${root}" "${TMP}/gnu"
[ "${RC}" -eq 0 ] && ! contains "${OUT}" "unbound variable"; check "GNU date/stat exits 0, no unbound variable" $?

# 9. BSD date+stat, i.e. a stock macOS.
root="$(make_root bsd 'last_fetched: "2020-01-01T00:00:00Z"')"
run_hook "${root}" "${TMP}/bsd"
[ "${RC}" -eq 0 ] && ! contains "${OUT}" "unbound variable"; check "BSD date/stat exits 0, no unbound variable" $?

# 10. THE TZ REGRESSION GUARD. BSD `date -j -f` reads the timestamp in local
#     time, so west of UTC a fetch from minutes ago parses as the future, the
#     sanity branch fires, and "(updated Xd ago)" vanishes from the status
#     line — the same silent degradation as the greedy sed, in a different
#     spelling. Only the hook's TZ=UTC keeps this correct. Fails against a
#     hook without it, on either host, because the BSD shim reproduces the
#     local-time read rather than the flag spelling alone.
root="$(make_root tzwest "last_fetched: \"${NOW_ISO}\"")"
OLD_TZ="${TZ-}"
export TZ=America/Los_Angeles
run_hook "${root}" "${TMP}/bsd"
if [ -n "${OLD_TZ}" ]; then export TZ="${OLD_TZ}"; else unset TZ; fi
contains "${OUT}" "updated" && [ "${RC}" -eq 0 ]
check "fresh fetch keeps its age west of UTC (BSD parses local time)" $?

# ------------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
[ "${fail}" -eq 0 ]
