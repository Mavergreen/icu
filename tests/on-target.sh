#!/bin/sh
# platform: macOS-only -- runs an x86_64 Mach-O against the installed libicucore.dylib, and PlistBuddy reads its manifest
#   usage: on-target.sh [VERSION SMOKE]     checks the icu pkg installed at /usr/local/mavergreen/icu, which must be
#          VERSION (<upstream>-mavericks.N): its headers are world-readable, and SMOKE (tests/smoke/build.sh's
#          program) runs against the installed dylib and prints tests/smoke/expected.txt. The release's vm-test job
#          installs the run's pkg in a 10.9 guest and runs this. With no VERSION it skips: the build host's icu is
#          not this build.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
V="${1:-}"; SMOKE="${2:-}"
[ -n "$V" ] || { echo "no VERSION given: on-target.sh checks an installed pkg of a known version; skipping"; exit 77; }
[ -n "$SMOKE" ] || fail "usage: on-target.sh VERSION SMOKE"
P=/usr/local/mavergreen/icu
[ -f "$P/mavergreen.plist" ] || fail "no icu pkg is installed at $P (no mavergreen.plist)"
got="$(/usr/libexec/PlistBuddy -c 'Print :version' "$P/mavergreen.plist")"
[ "$got" = "$V" ] || fail "$P holds icu $got, not $V: install this run's pkg first"
[ -f "$P/lib/libicucore.dylib" ] || fail "the pkg must install $P/lib/libicucore.dylib"
[ -f "$P/include/unicode/uconfig.h" ] || fail "the pkg must install $P/include/unicode"
bad="$(find "$P/include" -type f ! -perm -004)"
[ -z "$bad" ] || fail "every installed header must be world-readable: $bad"
rc=0; out="$("$SMOKE" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] || fail "the smoke program exited $rc: $out"
[ "$out" = "$(cat "$HERE/smoke/expected.txt")" ] || fail "the smoke program printed
$out
not
$(cat "$HERE/smoke/expected.txt")"
echo "PASS: on-target ($(sw_vers -productVersion), $V)"
