#!/bin/sh
# platform: macOS-only -- reads the x86_64 Mach-O libicucore.dylib
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"

ROOT="$(icu_build_root)"
DYLIB="${ICU_DYLIB:-$ROOT/out/libicucore.dylib}"
CLANG22="$ROOT/clang22"
[ -f "$DYLIB" ] && [ -x "$CLANG22/bin/llvm-nm" ] || { echo "dylib-shape-test: no dylib or clang22 under $ROOT; run build/build.sh" >&2; exit 77; }
EXPORTS="$(dirname "$DYLIB")/exports.txt"
t_tmp T

"$CLANG22/bin/llvm-otool" -L "$DYLIB" | sed 1d | sed 's/^[ 	]*//' > "$T/deps"
a_eq "/usr/local/mavergreen/icu/lib/libicucore.dylib (compatibility version 76.1.0, current version 76.1.0)" "$(sed -n 1p "$T/deps")" "the install name and versions"
a_contains "$(sed -n 2p "$T/deps")" "/usr/lib/libSystem.B.dylib (" "the second entry is libSystem"
a_eq 2 "$(wc -l < "$T/deps" | tr -d ' ')" "exactly two load entries"

"$CLANG22/bin/llvm-nm" -gU "$DYLIB" 2>/dev/null | awk 'NF >= 3 {print $3}' | LC_ALL=C sort -u > "$T/exported"
a_eq 0 "$(grep -cE '^(__Z|___cxa_|___gxx_|___dynamic_cast|__Unwind_)' "$T/exported" || true)" "no C++ runtime or unwinder name is exported"
a_eq 0 "$("$CLANG22/bin/llvm-nm" "$DYLIB" 2>/dev/null | awk '$2 ~ /^[TtDdSsBb]$/ && $3 == "__Unwind_RaiseException"' | wc -l | tr -d ' ')" "libunwind is not linked in"
a_file_exists "exports.txt sits beside the dylib" "$EXPORTS"
a_eq "$(cat "$EXPORTS")" "$(cat "$T/exported")" "the exported set equals exports.txt"
a_eq 1 "$(grep -cx '_utf8_countTrailBytes' "$T/exported")" "the data symbol utf8_countTrailBytes is exported"
a_eq 1 "$(grep -cx '_utf8_nextCharSafeBody' "$T/exported")" "the internal function utf8_nextCharSafeBody is exported"
a_done
