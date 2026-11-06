#!/bin/sh
# platform: host-agnostic
#   usage: build.sh DYLIB OUT     compiles icu-smoke.c with clang22 for x86_64 10.9 against DYLIB and the include/
#          beside it, linked by DYLIB's install name, into OUT. Running OUT prints expected.txt.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/../.." && pwd)"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"
[ $# -eq 2 ] || { echo "usage: build.sh DYLIB OUT" >&2; exit 2; }
DYLIB="$1"; OUT="$2"
INC="$(dirname "$DYLIB")/include"
[ -d "$INC" ] || INC="$(dirname "$DYLIB")/../include"
[ -f "$INC/unicode/uconfig.h" ] || { echo "smoke build: no headers at $INC" >&2; exit 1; }
CLANG22="$(sh "$MAVERICKS_ROOT/build/fetch-clang22.sh")"
SDK="$(sh "$SHIPYARD/fetch_sdk.sh")"
mkdir -p "$(dirname "$OUT")"
"$CLANG22/bin/clang" --no-default-config --target=x86_64-apple-macos10.9 -mmacosx-version-min=10.9 -isysroot "$SDK" \
  --ld-path="$CLANG22/bin/ld64.lld" -I "$INC" -o "$OUT" "$HERE/icu-smoke.c" "$DYLIB" -framework CoreFoundation
