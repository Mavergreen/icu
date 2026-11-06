#!/bin/sh
# platform: host-agnostic
set -eu
MAVERICKS_ROOT="${MAVERICKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"

ROOT="$(icu_build_root)"
SRC="$(sh "$MAVERICKS_ROOT/build/fetch-icu.sh")"
CLANG22="$(sh "$MAVERICKS_ROOT/build/fetch-clang22.sh")"
rm -rf "$ROOT/clang22"
ln -s "$CLANG22" "$ROOT/clang22"
LIBDIR="$(sh "$MAVERICKS_ROOT/build/build-icu.sh" "$SRC" "$CLANG22")"
OUT="$ROOT/out/libicucore.dylib"
rm -rf "$ROOT/out"
sh "$MAVERICKS_ROOT/build/link-libicucore.sh" "$CLANG22" "$LIBDIR" "$OUT" >&2
sh "$MAVERICKS_ROOT/build/install-headers.sh" "$(dirname "$LIBDIR")" "$ROOT/out/include" >&2
cp "$SRC/../LICENSE" "$ROOT/out/LICENSE"
cp "$ROOT/build-tools.txt" "$ROOT/out/build-tools.txt"

MAVERICKS_DEVIATIONS_ROOT="$MAVERICKS_ROOT" \
OTOOL="$CLANG22/bin/llvm-otool" NM="$CLANG22/bin/llvm-nm" \
LIPO="$CLANG22/bin/llvm-lipo" STRINGS="$CLANG22/bin/llvm-strings" \
  sh "$SHIPYARD/assert_binary_compatible.sh" "$OUT" >&2
sh "$MAVERICKS_ROOT/build/check-symbols.sh" "$CLANG22/bin/llvm-nm" "$OUT" "$MAVERICKS_ROOT/symbols.txt" >&2
printf '%s\n' "$OUT"
