#!/bin/sh
# platform: host-agnostic
#   usage: smoke-test.sh     compiles and links tests/smoke/icu-smoke.c and a header-only program against the built
#          libicucore.dylib on any host; on a Mac that runs x86_64 it also runs the smoke program and compiles with
#          Apple's clang. On Linux the vm-test job runs the smoke program, in a 10.9 guest.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"

ROOT="$(icu_build_root)"
DYLIB="${ICU_DYLIB:-$ROOT/out/libicucore.dylib}"
CLANG22="$ROOT/clang22"
INC="$(dirname "$DYLIB")/include"
[ -d "$INC" ] || INC="$(dirname "$DYLIB")/../include"
[ -f "$DYLIB" ] && [ -x "$CLANG22/bin/clang" ] && [ -f "$INC/unicode/uconfig.h" ] || { echo "smoke-test: no dylib, clang22 or shipped headers under $ROOT; run build/build.sh" >&2; exit 77; }
a_eq "" "$(find "$INC" -type f ! -perm -004)" "every shipped header is world-readable"
t_tmp T

SDK="$(sh "$SHIPYARD/fetch_sdk.sh")"
FL="--no-default-config --target=x86_64-apple-macos10.9 -mmacosx-version-min=10.9 -isysroot $SDK"
rc=0; sh "$HERE/smoke/build.sh" "$DYLIB" "$T/icu-smoke" || rc=$?
a_eq 0 "$rc" "clang22 compiles and links the smoke program against the dylib"

cat > "$T/apple.c" <<'C'
#include <unicode/ustring.h>
int main(void) { static const UChar s[] = { 'a', 0 }; return (int)u_strlen(s) - 1; }
C
rc=0; "$CLANG22/bin/clang" $FL --ld-path="$CLANG22/bin/ld64.lld" -I "$INC" -o "$T/apple" "$T/apple.c" "$DYLIB" || rc=$?
a_eq 0 "$rc" "clang22 compiles and links a program against the shipped headers, no -D flag"

if [ "$(uname -s)" = Darwin ]; then
  printf '%s\n' 'int main(void) { return 0; }' > "$T/probe.c"
  "$CLANG22/bin/clang" $FL --ld-path="$CLANG22/bin/ld64.lld" -o "$T/probe" "$T/probe.c"
  if ! "$T/probe" >/dev/null 2>&1; then
    if [ "$(uname -m)" = arm64 ]; then echo "smoke-test: this Apple Silicon host cannot run x86_64 (no Rosetta)" >&2; exit 77; fi
    _a_fail "the x86_64 probe program ran"
  fi
  rc=0
  got="$(DYLD_LIBRARY_PATH="$(dirname "$DYLIB")" "$T/icu-smoke" 2>&1)" || rc=$?
  a_eq 0 "$rc" "the smoke program exits 0 (output: $got)"
  a_eq "$(cat "$HERE/smoke/expected.txt")" "$got" "the smoke program's output"
  rc=0
  /usr/bin/clang -arch x86_64 -mmacosx-version-min=10.9 -isysroot "$SDK" -I "$INC" -o "$T/apple" "$T/apple.c" "$DYLIB" || rc=$?
  a_eq 0 "$rc" "Apple clang compiles and links a program against the shipped headers, no -D flag"
fi
a_done
