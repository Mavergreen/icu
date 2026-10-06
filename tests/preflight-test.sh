#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"

t_tmp T
mkdir -p "$T/bin"
stub() { printf '#!/bin/sh\necho "%s"\n' "$2" > "$1"; chmod +x "$1"; }
stub "$T/notgnu" "make: stub"
stub "$T/gnu" "GNU Make 3.81"
stub "$T/bin/gmake" "GNU Make 4.4.1"

run() { sh -c '. "$MAVERICKS_ROOT/build/lib.sh"; PATH="$1"; shift; icu_require_gnu_make; printf "%s\n" "$MAKE"' sh "$@"; }

rc=0; err="$(MAKE="$T/notgnu" run "$PATH" 2>&1 >/dev/null)" || rc=$?
a_eq 2 "$rc" "explicit non-GNU MAKE exits 2"
a_contains "$err" "GNU make is required" "explicit non-GNU MAKE says so"

rc=0; out="$(MAKE="$T/gnu" run "$PATH" 2>/dev/null)" || rc=$?
a_eq 0 "$rc" "explicit GNU MAKE accepted"
a_eq "$T/gnu" "$out" "explicit GNU MAKE kept"

rc=0; out="$(sh -c 'unset MAKE; . "$MAVERICKS_ROOT/build/lib.sh"; PATH="$1"; icu_require_gnu_make; printf "%s\n" "$MAKE"' sh "$T/bin" 2>/dev/null)" || rc=$?
a_eq 0 "$rc" "gmake on PATH accepted when MAKE is unset"
a_eq gmake "$out" "gmake chosen"
rc=0; sh -c '. "$MAVERICKS_ROOT/build/lib.sh"; icu_first_gnu_make "$1" "$2"' sh "$T/notgnu" "$T/missing" >/dev/null 2>&1 || rc=$?
a_eq 1 "$rc" "no candidate qualifies"
out="$(sh -c '. "$MAVERICKS_ROOT/build/lib.sh"; icu_first_gnu_make "$1" "$2" "$3"' sh "$T/notgnu" "$T/gnu" "$T/bin/gmake")"
a_eq "$T/gnu" "$out" "first GNU candidate wins"

rc=0; err="$(sh -c 'unset MAKE; . "$MAVERICKS_ROOT/build/lib.sh"; icu_first_gnu_make() { return 1; }; icu_require_gnu_make' sh 2>&1 >/dev/null)" || rc=$?
a_eq 2 "$rc" "no GNU make anywhere exits 2"
a_contains "$err" "GNU make is required" "missing GNU make says so"
a_done
