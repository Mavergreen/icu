#!/bin/sh
# platform: macOS-only -- reads the x86_64 Mach-O libicucore.dylib
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"

SYMS="$MAVERICKS_ROOT/symbols.txt"
a_file_exists "symbols.txt is committed" "$SYMS"
a_eq 1 "$([ -s "$SYMS" ] && echo 1 || echo 0)" "symbols.txt is non-empty"
LC_ALL=C sort -c "$SYMS" 2>/dev/null && sorted=1 || sorted=0
a_eq 1 "$sorted" "symbols.txt is LC_ALL=C sorted"
for s in _ubrk_clone _ulistfmt_openForType _unumf_openForSkeletonAndLocale; do
  a_eq 1 "$(grep -cx "$s" "$SYMS")" "symbols.txt lists $s"
done
a_eq 0 "$(grep -c '^__Z' "$SYMS" || true)" "symbols.txt has no C++ name"
a_eq 0 "$(grep -cx '_utf8_nextCharSafeBody' "$SYMS" || true)" "symbols.txt is the public API, not the export list"
a_eq 0 "$(grep -c '^_icudt' "$SYMS" || true)" "symbols.txt has no version-named data symbol"

ROOT="$(icu_build_root)"
DYLIB="${ICU_DYLIB:-$ROOT/out/libicucore.dylib}"
CLANG22="$ROOT/clang22"
[ -f "$DYLIB" ] && [ -x "$CLANG22/bin/llvm-nm" ] || { echo "symbols-test: no dylib or clang22 under $ROOT; run build/build.sh" >&2; exit 77; }
a_contains "$(sh "$MAVERICKS_ROOT/build/check-symbols.sh" "$CLANG22/bin/llvm-nm" "$DYLIB" "$SYMS" 2>&1)" "all exported" "the dylib exports every public symbol"
a_done
