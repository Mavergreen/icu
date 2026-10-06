#!/bin/sh
# platform: host-agnostic
# spec: unicode-org/icu release assets: tag release-<ver>, icu4c-<ver>-sources.tgz, SHASUM512.txt
#       with lines "<sha512> *<asset>"
set -eu
MAVERICKS_ROOT="${MAVERICKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"

VERSION="${1:-$(upstream_version)}"
BASE="${ICU_RELEASE_BASE:-https://github.com/unicode-org/icu/releases/download}/release-$VERSION"
ASSET="icu4c-$VERSION-sources.tgz"
ROOT="$(icu_build_root)"
DL="$ROOT/dl"
mkdir -p "$DL"

SUMS="$DL/SHASUM512.txt.$$"
trap 'rm -f "$SUMS" "$DL/$ASSET.$$"' EXIT
curl -fsSL -o "$SUMS" "$BASE/SHASUM512.txt" || { echo "fetch-icu: cannot fetch $BASE/SHASUM512.txt" >&2; exit 1; }
want="$(tr -d '\r' < "$SUMS" | awk -v a="$ASSET" '{n=$2; sub(/^\*/,"",n)} n==a {print $1; exit}' | tr 'A-F' 'a-f')"
case "$want" in
  *[!0-9a-f]*|"") want="" ;;
esac
[ "${#want}" -eq 128 ] || { echo "fetch-icu: $ASSET not listed in SHASUM512.txt" >&2; exit 1; }

if [ ! -f "$DL/$ASSET" ]; then
  curl -fsSL -o "$DL/$ASSET.$$" "$BASE/$ASSET" || { echo "fetch-icu: cannot fetch $BASE/$ASSET" >&2; exit 1; }
  mv "$DL/$ASSET.$$" "$DL/$ASSET"
fi
got="$(shasum -a 512 "$DL/$ASSET" | awk '{print $1}')"
if [ "$got" != "$want" ]; then
  rm -f "$DL/$ASSET"
  echo "fetch-icu: $ASSET checksum mismatch: expected $want, got $got" >&2
  exit 1
fi

NEW="$ROOT/src.new.$$"
trap 'rm -rf "$SUMS" "$DL/$ASSET.$$" "$NEW"' EXIT
rm -rf "$NEW"
mkdir -p "$NEW"
tar -xzf "$DL/$ASSET" -C "$NEW"
rm -rf "$ROOT/src"
mv "$NEW" "$ROOT/src"
icu_src_dir
