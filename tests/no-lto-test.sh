#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"

ROOT="$(icu_build_root)"
CLANG22="$ROOT/clang22"
LIB="$ROOT/target/lib"
[ -f "$LIB/libicuuc.a" ] && [ -x "$CLANG22/bin/llvm-otool" ] || { echo "no-lto-test: no build under $ROOT; run build/build.sh" >&2; exit 77; }

for a in libicuuc.a libicui18n.a; do
  members="$("$CLANG22/bin/llvm-ar" t "$LIB/$a" | wc -l | tr -d ' ')"
  objects="$("$CLANG22/bin/llvm-otool" -hv "$LIB/$a" 2>/dev/null | grep -c 'X86_64.*OBJECT' || true)"
  a_eq 1 "$([ "$members" -gt 0 ] && echo 1 || echo 0)" "$a has members"
  a_eq "$members" "$objects" "every $a member is an x86_64 Mach-O object, not LLVM bitcode: the target build turns off upstream's -flto (INGREDIENTS.md, Build)"
done
a_done
