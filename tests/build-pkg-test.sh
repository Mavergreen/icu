#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/icu-build-pkg.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
. "$ROOT/build/msc.sh"; mkdir -p "$t/sy"; cp -R "$SHIPYARD_SCRIPTS"/. "$t/sy/"
for s in stage_product build_component_pkg; do printf '#!/bin/sh\n:\n' > "$t/sy/$s.sh"; done
printf '#!/bin/sh\nwhile [ "$1" != --out ]; do shift; done; : > "$2"\n' > "$t/sy/set_install_floor.sh"
mkdir -p "$t/out/include/unicode" "$t/updater/icu-updater.app/Contents/MacOS" "$t/dist"
: > "$t/out/libicucore.dylib"; : > "$t/out/include/unicode/uconfig.h"; : > "$t/out/LICENSE"
printf 'build-make=GNU Make 9\n' > "$t/out/build-tools.txt"; printf 'updater-cmake=cmake version 9\n' > "$t/updater/build-tools.txt"
printf '#!/bin/sh\n' > "$t/updater/icu-updater.app/Contents/MacOS/icu-updater"; chmod +x "$t/updater/icu-updater.app/Contents/MacOS/icu-updater"
: > "$t/dist/icu-78.2-mavericks.4.pkg"
SHIPYARD_SCRIPTS="$t/sy" sh "$ROOT/packaging/build-pkg.sh" "$t/updater/icu-updater.app" "$t/out/libicucore.dylib" 78.3-mavericks.1 "$t/dist" >/dev/null \
  || fail "build-pkg.sh failed"
[ "$(cd "$t/dist" && ls icu-*.pkg | xargs)" = icu-78.3-mavericks.1.pkg ] \
  || fail "OUT-DIR must hold only this build's pkg: an older one makes package-test blame the build (holds: $(cd "$t/dist" && ls | xargs))"
echo "PASS: build-pkg"
