#!/bin/sh
# platform: macOS-only -- runs clang22, a Mach-O toolchain
set -eu
MAVERICKS_ROOT="${MAVERICKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"

[ $# -eq 2 ] || { echo "build-icu: need SRC and CLANG22" >&2; exit 2; }
SRC="$1"; CLANG22="$2"
icu_require_gnu_make
MODE="$(icu_mode)"
ROOT="$(icu_build_root)"
MAJOR="$(icu_major)"
JOBS="$(sysctl -n hw.ncpu)"

rm -rf "$ROOT/host" "$ROOT/target"
mkdir -p "$ROOT/host" "$ROOT/target"
ROOT="$(cd "$ROOT" && pwd)"

COMMON="--disable-renaming --enable-static --disable-shared --with-data-packaging=static --disable-tests --disable-samples --disable-extras --disable-icuio --disable-layoutex"

if [ "$MODE" = cross ]; then
  (
    cd "$ROOT/host"
    ac_cv_prog_PYTHON= CFLAGS= CXXFLAGS= LDFLAGS= CC=/usr/bin/clang CXX=/usr/bin/clang++ \
      sh "$SRC/runConfigureICU" macOS $COMMON
    "$MAKE" -j"$JOBS"
  ) >&2
  EXTRA="--build=$(sh "$SRC/config.guess") --host=x86_64-apple-darwin13 --with-cross-build=$ROOT/host --disable-tools"
else
  EXTRA=""
fi

SDK="$(sh "$SHIPYARD/fetch_sdk.sh")"
FL="--no-default-config --target=x86_64-apple-macos10.9 -mmacosx-version-min=10.9 -isysroot $SDK"
CF="$FL -isystem $CLANG22/include/mavericks-compat"

(
  cd "$ROOT/target"
  ac_cv_prog_PYTHON= \
  CC="$CLANG22/bin/clang" CXX="$CLANG22/bin/clang++" \
  AR="$CLANG22/bin/llvm-ar" RANLIB="$CLANG22/bin/llvm-ranlib" \
  CFLAGS="$CF" CXXFLAGS="$CF" \
  LDFLAGS="$FL --ld-path=$CLANG22/bin/ld64.lld -nostdlib++" \
  LIBS="$CLANG22/lib/libc++.a $CLANG22/lib/libc++abi.a" \
    sh "$SRC/runConfigureICU" macOS $COMMON $EXTRA
  "$MAKE" -j"$JOBS"
) >&2

LIB="$ROOT/target/lib"
for a in libicuuc.a libicui18n.a libicudata.a; do
  [ -f "$LIB/$a" ] || { echo "build-icu: $LIB/$a was not built" >&2; exit 1; }
done
size="$(wc -c < "$LIB/libicudata.a" | tr -d ' ')"
[ "$size" -gt 10485760 ] || { echo "build-icu: libicudata.a is only $size bytes" >&2; exit 1; }
NM="$CLANG22/bin/llvm-nm"
[ -x "$NM" ] || { echo "build-icu: cannot run $NM" >&2; exit 1; }
syms="$("$NM" -gU "$LIB/libicudata.a")" || { echo "build-icu: $NM failed on $LIB/libicudata.a" >&2; exit 1; }
case "$syms" in
  *" _icudt${MAJOR}_dat"*) ;;
  *) echo "build-icu: libicudata.a does not define _icudt${MAJOR}_dat" >&2; exit 1 ;;
esac
printf '%s\n' "$LIB"
