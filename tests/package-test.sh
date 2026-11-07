#!/bin/sh
# platform: host-agnostic
#   usage: package-test.sh [PKG DYLIB]     (default: the one dist/icu-*.pkg, and build/build.sh's dylib)
#          The pkg must be named icu-<version>.pkg and its icu component must carry exactly the dylib,
#          the include/unicode headers that sit beside it (uconfig.h defining U_DISABLE_RENAMING 1), ICU's
#          LICENSE and the README under share/doc/icu, the mavergreen.plist manifest, and the updater
#          app (Sparkle framework aside) with its LaunchAgent;
#          every file in it is world-readable and every directory world-searchable (a non-root compile must
#          be able to read the headers); the packaged dylib must be
#          byte-identical to the one that was tested.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"
BUILT_HERE=no
if [ $# -ge 2 ]; then PKG="$1"; DYLIB="$2"; else
  BUILT_HERE=yes
  set -- "$MAVERICKS_ROOT"/dist/icu-*.pkg
  [ -f "$1" ] || { echo "package-test: not packaged (no dist/icu-*.pkg) -- run build/build.sh, build/build-updater.sh, then packaging/build-pkg.sh; skipping" >&2; exit 77; }
  [ "$#" -eq 1 ] || { echo "package-test: dist/ holds $# icu pkgs; one build makes one" >&2; exit 1; }
  PKG="$1"; DYLIB="$(icu_build_root)/out/libicucore.dylib"
fi

case "$(basename "$PKG")" in icu-[0-9]*.pkg) _n=ok ;; *) _n=bad ;; esac
a_eq ok "$_n" "the pkg is named icu-<version>.pkg"
a_file_exists "the pkg exists" "$PKG"
a_file_exists "the dylib exists" "$DYLIB"

t_tmp T
SD="$(sh "$SHIPYARD/fetch_stevedore.sh")"
"$SD" expand "$PKG" "$T/x" >/dev/null
C="$(grep -l 'identifier="dev.mavergreen.icu"' "$T"/x/*/PackageInfo | sed 1q)"
a_eq 1 "$([ -n "$C" ] && echo 1 || echo 0)" "the product archive carries the icu component"
C="$(dirname "$C")"
mkdir "$T/out"
gzip -dc < "$C/Payload" > "$T/payload.cpio" || _a_fail "the pkg's payload must decompress"
( cd "$T/out" && cpio -id --quiet < "$T/payload.cpio" ) || _a_fail "cpio must extract the pkg's payload"
( cd "$T/out" && find . -type f | sed 's|^\./||' ) > "$T/bom"
a_eq 1 "$(grep -c 'icu-updater\.app/Contents/Frameworks/Sparkle\.framework/Versions/A/Sparkle$' "$T/bom")" "the Sparkle binary is in the payload"
a_eq "" "$(cd "$T/out" && { find . -type f ! -perm -004; find . -type d ! -perm -001; })" "every payload file is world-readable and every directory world-searchable"
a_eq "./usr/local/mavergreen/icu/lib/libicucore.dylib" "$(cd "$T/out" && find ./usr/local/mavergreen/icu/lib/libicucore.dylib -perm 0755)" "the dylib keeps the mode it was built with"
grep -v '/Sparkle\.framework/' "$T/bom" | LC_ALL=C sort > "$T/payload"
a_file_exists "the built include dir has uconfig.h" "$(dirname "$DYLIB")/include/unicode/uconfig.h"
(cd "$(dirname "$DYLIB")/include" && find unicode -type f | sed 's|^|usr/local/mavergreen/icu/include/|') > "$T/headers"
a_eq 1 "$([ -s "$T/headers" ] && echo 1 || echo 0)" "the built include dir lists headers"
grep "^usr/local/mavergreen/icu/include/" "$T/payload" | LC_ALL=C sort > "$T/payload-headers"
LC_ALL=C sort "$T/headers" > "$T/built-headers"
a_eq "$(cat "$T/built-headers")" "$(cat "$T/payload-headers")" "the payload headers are exactly the built include dir"
grep -v "^usr/local/mavergreen/icu/include/" "$T/payload" > "$T/payload-rest"

a_eq "Library/Application Support/Mavergreen/icu-updater.app/Contents/Info.plist
Library/Application Support/Mavergreen/icu-updater.app/Contents/MacOS/icu-updater
Library/LaunchAgents/dev.mavergreen.icu-updatecheck.plist
usr/local/mavergreen/icu/lib/libicucore.dylib
usr/local/mavergreen/icu/mavergreen.plist
usr/local/mavergreen/icu/share/doc/icu/LICENSE
usr/local/mavergreen/icu/share/doc/icu/README.md" "$(cat "$T/payload-rest")" "the payload is the dylib, docs, manifest, updater and its LaunchAgent"

a_file_exists "the dylib extracts" "$T/out/usr/local/mavergreen/icu/lib/libicucore.dylib"
cmp "$T/out/usr/local/mavergreen/icu/lib/libicucore.dylib" "$DYLIB" && _s=same || _s=differs
a_eq same "$_s" "the packaged dylib is byte-identical to the tested one"
a_eq 1 "$(grep -c '^#define U_DISABLE_RENAMING 1$' "$T/out/usr/local/mavergreen/icu/include/unicode/uconfig.h")" "the packaged uconfig.h defines U_DISABLE_RENAMING 1"

INFO="$(dirname "$PKG")/build-info-release.txt"
a_file_exists "packaging writes build-info-release.txt beside the pkg" "$INFO"
TOOLS="$(dirname "$DYLIB")/build-tools.txt"
a_file_exists "build-tools.txt beside the dylib records the tools that built it" "$TOOLS"
while IFS= read -r l; do
  a_eq "$(printf '%s' "${l#*=}" | tr -s '[:space:]' '_')" "$(sed -n "s/^${l%%=*}=//p" "$INFO")" "build-info carries ${l%%=*} as build-tools.txt beside the dylib records it"
done < "$TOOLS"
keys="build-make updater-cmake updater-build-tool"
if [ "$BUILT_HERE" = yes ] && [ "$(icu_mode)" = cross ] || grep -q '^build-host-' "$TOOLS"; then
  keys="$keys build-host-cc build-host-cxx"
fi
for k in $keys; do
  a_eq 1 "$(grep -c "^$k=." "$INFO")" "build-info names $k, a tool that built what ships"
done
a_done
