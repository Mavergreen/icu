#!/bin/sh
# platform: macOS-only -- links with clang22
#   usage: link-libicucore.sh CLANG22 LIBDIR OUT
set -eu
MAVERICKS_ROOT="${MAVERICKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"

[ $# -eq 3 ] || { echo "usage: link-libicucore.sh CLANG22 LIBDIR OUT" >&2; exit 2; }
CLANG22="$1"; LIBDIR="$2"; OUT="$3"
for a in libicuuc.a libicui18n.a libicudata.a; do
  [ -f "$LIBDIR/$a" ] || { echo "link-libicucore: $LIBDIR/$a is missing; run build/build-icu.sh" >&2; exit 1; }
done
mkdir -p "$(dirname "$OUT")"
EXPORTS="$(dirname "$OUT")/exports.txt"

GEN_ERR="$EXPORTS.err"
if ! sh "$MAVERICKS_ROOT/build/gen-exports.sh" "$CLANG22/bin/llvm-nm" \
    "$LIBDIR/libicuuc.a" "$LIBDIR/libicui18n.a" "$LIBDIR/libicudata.a" > "$EXPORTS.new" 2> "$GEN_ERR"; then
  cat "$GEN_ERR" >&2
  rm -f "$EXPORTS.new" "$GEN_ERR"
  exit 1
fi
rm -f "$GEN_ERR"
mv "$EXPORTS.new" "$EXPORTS"
SDK="$(sh "$SHIPYARD/fetch_sdk.sh")"
"$CLANG22/bin/clang++" --no-default-config --target=x86_64-apple-macos10.9 -mmacosx-version-min=10.9 \
  -isysroot "$SDK" --ld-path="$CLANG22/bin/ld64.lld" -nostdlib++ -dynamiclib \
  -install_name "$ICU_INSTALL_NAME" -compatibility_version "$ICU_DYLIB_VERSION" \
  -current_version "$ICU_DYLIB_VERSION" \
  -Wl,-force_load,"$LIBDIR/libicui18n.a" -Wl,-force_load,"$LIBDIR/libicuuc.a" \
  -Wl,-force_load,"$LIBDIR/libicudata.a" \
  "$CLANG22/lib/libc++.a" "$CLANG22/lib/libc++abi.a" -Wl,-dead_strip \
  -Wl,-exported_symbols_list,"$EXPORTS" -o "$OUT"
