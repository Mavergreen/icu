#!/bin/sh
# platform: macOS-only -- reads Mach-O headers with clang22's llvm-otool
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"

[ "$(icu_mode)" = cross ] || { echo "rosetta-free-test: cross mode only" >&2; exit 77; }
ROOT="$(icu_build_root)"
CLANG22="$ROOT/clang22"
[ -d "$ROOT/target" ] && [ -x "$CLANG22/bin/llvm-otool" ] || { echo "rosetta-free-test: no cross build under $ROOT" >&2; exit 77; }

ctl="$("$CLANG22/bin/llvm-otool" -hv "$ROOT/target/lib/libicuuc.a" 2>/dev/null | grep -c "X86_64.*OBJECT" || true)"
a_eq 1 "$([ "$ctl" -gt 0 ] && echo 1 || echo 0)" "positive control: libicuuc.a members read as x86_64 objects"

bad=0
for f in $(find "$ROOT/target" -type f); do
  hdr="$("$CLANG22/bin/llvm-otool" -hv "$f" 2>/dev/null || true)"
  case "$hdr" in
    *X86_64*EXECUTE*) echo "rosetta-free-test: $f is an x86_64 executable" >&2; bad=$((bad + 1)) ;;
  esac
done
a_eq 0 "$bad" "no x86_64 executable was built"
a_done
