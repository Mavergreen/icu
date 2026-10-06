#!/bin/sh
# platform: macOS-only -- drives ICU's GNU make install rules
#   usage: install-headers.sh BUILD-DIR INCLUDE-DIR
#          Runs ICU's own install-headers rule in common and i18n (nothing is compiled and no ICU tool
#          runs, so it works the same after a cross configure), then puts the configure-generated
#          uconfig.h.prepend at the top of the installed unicode/uconfig.h.
# spec: ICU source/configure, "The recommended way to do this is to prepend the following lines to source/common/unicode/uconfig.h"
set -eu
MAVERICKS_ROOT="${MAVERICKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"

[ $# -eq 2 ] || { echo "usage: install-headers.sh BUILD-DIR INCLUDE-DIR" >&2; exit 2; }
BUILD="$1"; INC="$2"
icu_require_gnu_make
[ -f "$BUILD/Makefile" ] || { echo "install-headers: $BUILD/Makefile is missing; run build/build-icu.sh" >&2; exit 1; }
[ -f "$BUILD/uconfig.h.prepend" ] || { echo "install-headers: $BUILD/uconfig.h.prepend is missing; configure did not write it" >&2; exit 1; }
grep -q '^#define U_DISABLE_RENAMING 1$' "$BUILD/uconfig.h.prepend" || { echo "install-headers: $BUILD/uconfig.h.prepend does not define U_DISABLE_RENAMING" >&2; exit 1; }

rm -rf "$INC"
mkdir -p "$INC"
INC="$(cd "$INC" && pwd)"
for d in common i18n; do
  "$MAKE" -C "$BUILD/$d" install-headers includedir="$INC"
done
H="$INC/unicode/uconfig.h"
[ -f "$H" ] || { echo "install-headers: $H was not installed" >&2; exit 1; }
NEW="$(mktemp "${TMPDIR:-/tmp}/uconfig.XXXXXX")"
trap 'rm -f "$NEW"' EXIT
cat "$BUILD/uconfig.h.prepend" "$H" > "$NEW"
cat "$NEW" > "$H"
