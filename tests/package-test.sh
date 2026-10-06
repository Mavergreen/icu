#!/bin/sh
# platform: macOS-only -- pkgutil expands the product archive and lsbom lists the component's payload
#   usage: package-test.sh PKG DYLIB
#          The pkg must be named icu-<version>.pkg and its icu component must carry exactly the dylib,
#          the include/unicode headers that sit beside it (uconfig.h defining U_DISABLE_RENAMING 1), ICU's
#          LICENSE and the README under share/doc/icu, the mavergreen.plist manifest, and the updater
#          app (Sparkle framework aside) with its LaunchAgent; the packaged dylib must be
#          byte-identical to the one that was tested.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers/assert.sh"
PKG="${1:-}"; DYLIB="${2:-}"
[ -n "$PKG" ] && [ -n "$DYLIB" ] || { echo "package-test: usage: package-test.sh PKG DYLIB" >&2; exit 77; }

case "$(basename "$PKG")" in icu-[0-9]*.pkg) _n=ok ;; *) _n=bad ;; esac
a_eq ok "$_n" "the pkg is named icu-<version>.pkg"
a_file_exists "the pkg exists" "$PKG"
a_file_exists "the dylib exists" "$DYLIB"

t_tmp T
pkgutil --expand "$PKG" "$T/x"
C="$T/x/icu-component.pkg"
a_file_exists "the product archive carries the icu component" "$C/Bom"
lsbom -s -f "$C/Bom" | sed 's|^\./||' > "$T/bom"
a_eq 1 "$(grep -c 'icu-updater\.app/Contents/Frameworks/Sparkle\.framework/Versions/A/Sparkle$' "$T/bom")" "the Sparkle binary is in the payload"
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

mkdir "$T/out"
( cd "$T/out" && gzip -dc < "$C/Payload" | cpio -id 2>/dev/null )
a_file_exists "the dylib extracts" "$T/out/usr/local/mavergreen/icu/lib/libicucore.dylib"
cmp "$T/out/usr/local/mavergreen/icu/lib/libicucore.dylib" "$DYLIB" && _s=same || _s=differs
a_eq same "$_s" "the packaged dylib is byte-identical to the tested one"
a_eq 1 "$(grep -c '^#define U_DISABLE_RENAMING 1$' "$T/out/usr/local/mavergreen/icu/include/unicode/uconfig.h")" "the packaged uconfig.h defines U_DISABLE_RENAMING 1"
a_done
