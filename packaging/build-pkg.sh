#!/bin/sh
# platform: host-agnostic
#   usage: build-pkg.sh UPDATER-APP DYLIB VERSION OUT-DIR
#          Stages libicucore.dylib (byte for byte as built and tested), the include/unicode directory and
#          ICU's LICENSE beside it, the README and the updater under /usr/local/mavergreen/icu, and wraps
#          them in a 10.9.5-floored product archive, OUT-DIR/icu-VERSION.pkg, whose path it prints.
#          OUT-DIR/build-info-release.txt records the build tools that build-tools.txt beside the dylib
#          and beside the updater name.
set -eu
APP=${1:?usage: build-pkg.sh UPDATER-APP DYLIB VERSION OUT-DIR}
DYLIB=${2:?usage: build-pkg.sh UPDATER-APP DYLIB VERSION OUT-DIR}
V=${3:?usage: build-pkg.sh UPDATER-APP DYLIB VERSION OUT-DIR}
OUTDIR=${4:?usage: build-pkg.sh UPDATER-APP DYLIB VERSION OUT-DIR}
REPO=$(cd "$(dirname "$0")/.." && pwd)
MAVERICKS_ROOT=$REPO; export MAVERICKS_ROOT
. "$REPO/build/lib.sh"
[ -f "$DYLIB" ] || { echo "build-pkg: no $DYLIB" >&2; exit 1; }
[ -d "$APP" ] || { echo "build-pkg: no updater $APP; run build/build-updater.sh" >&2; exit 1; }
HEADERS_SRC="$(dirname "$DYLIB")/include/unicode"
[ -f "$HEADERS_SRC/uconfig.h" ] || { echo "build-pkg: no $HEADERS_SRC; run build/build.sh" >&2; exit 1; }
LICENSE_SRC="$(dirname "$DYLIB")/LICENSE"
[ -f "$LICENSE_SRC" ] || { echo "build-pkg: no $LICENSE_SRC; run build/build.sh" >&2; exit 1; }
for f in "$(dirname "$DYLIB")/build-tools.txt" "$(dirname "$APP")/build-tools.txt"; do
  [ -s "$f" ] || { echo "build-pkg: no $f -- the build tools that built what ships must be recorded" >&2; exit 1; }
done
# platform: without it, cp on a Mac carries AppleDouble ._ files and extended attributes into the payload
COPYFILE_DISABLE=1; export COPYFILE_DISABLE
work=$(mktemp -d "${TMPDIR:-/tmp}/icu-pkg.XXXXXX")
trap 'rm -rf "$work"' EXIT
ROOT=$work/root
T=$ROOT/usr/local/mavergreen/icu
install -d "$T/lib" "$T/include/unicode" "$T/share/doc/icu"
cp -p "$DYLIB" "$T/lib/libicucore.dylib"
cp -p "$HEADERS_SRC"/*.h "$T/include/unicode/"
cp "$LICENSE_SRC" "$T/share/doc/icu/LICENSE"
cp "$REPO/README.md" "$T/share/doc/icu/"
find "$ROOT" -name '._*' -delete
sh "$SHIPYARD/stage_product.sh" --stage "$ROOT" --product icu --name "ICU for Mavericks" --version "$V" \
  --scripts-out "$work/scripts" --updater-app "$APP" >&2
sh "$SHIPYARD/build_component_pkg.sh" --root "$ROOT" --identifier dev.mavergreen.icu \
  --version "$V" --install-location / --scripts "$work/scripts" --out "$work/icu-component.pkg" >&2
mkdir -p "$OUTDIR"
OUT=$OUTDIR/icu-$V.pkg
sh "$SHIPYARD/set_install_floor.sh" --identifier dev.mavergreen.icu --title "ICU for Mavericks" \
  --component "$work/icu-component.pkg" --out "$OUT" --require-scripts --host-arch x86_64 >&2
set -- variant=release arch=x86_64 prefix=/usr/local/mavergreen/icu pkg="icu-$V.pkg" identifier=dev.mavergreen.icu \
  icu="$(upstream_version)" clang22="$(tr -d ' \t\n' < "$REPO/components/clang22/version")"
for f in "$(dirname "$DYLIB")/build-tools.txt" "$(dirname "$APP")/build-tools.txt"; do
  while IFS= read -r l; do set -- "$@" "$l"; done < "$f"
done
rm -f "$OUTDIR"/build-info-*.txt
sh "$SHIPYARD/build-info.sh" "$OUTDIR/build-info-release.txt" "$@"
echo "$OUT"
