#!/bin/sh
# platform: macOS-only -- pkgutil expands the toolchain pkg
set -eu
MAVERICKS_ROOT="${MAVERICKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"; export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/lib.sh"

TAG="$(tr -d '\r\n\t ' < "$MAVERICKS_ROOT/components/clang22/version")"
[ -n "$TAG" ] || { echo "fetch-clang22: components/clang22/version is empty" >&2; exit 1; }
MODE="$(icu_mode)"
case "$MODE" in
  cross) DEFAULT_VARIANT=clang22-cross ;;
  *) DEFAULT_VARIANT=clang22 ;;
esac
VARIANT="${CLANG22_VARIANT:-$DEFAULT_VARIANT}"
case "$VARIANT" in
  *-cross) KIND=cross ;;
  *) KIND=native ;;
esac
BASE="${CLANG22_RELEASE_BASE:-https://github.com/Mavergreen/clang-22/releases/download}/$TAG"
FIRST="$VARIANT-$TAG.pkg"
SECOND="mavericks-clang-22-$KIND-$TAG.pkg"
ROOT="$(icu_build_root)"
DL="$ROOT/dl"
mkdir -p "$DL"

SUMS="$DL/SHA256SUMS.$$"
EXP="$ROOT/clang22-expand.$$"
NEW="$ROOT/clang22.new.$$"
OLD="$ROOT/clang22.old.$$"
cleanup() {
  if [ -d "$OLD" ]; then rm -rf "$ROOT/clang22"; mv "$OLD" "$ROOT/clang22"; fi
  rm -rf "$SUMS" "$EXP" "$NEW" "$DL"/*.$$
}
trap cleanup EXIT
curl -fsSL -o "$SUMS" "$BASE/SHA256SUMS" || { echo "fetch-clang22: cannot fetch $BASE/SHA256SUMS" >&2; exit 1; }

digest_of() {
  tr -d '\r' < "$SUMS" | awk -v a="$1" '{n=$2; sub(/^\*/,"",n)} n==a {print $1; exit}' | tr 'A-F' 'a-f'
}
ASSET=""; want=""
for cand in "$FIRST" "$SECOND"; do
  d="$(digest_of "$cand")"
  [ -n "$d" ] || continue
  case "$d" in
    *[!0-9a-f]*) d="" ;;
  esac
  [ "${#d}" -eq 64 ] || { echo "fetch-clang22: $cand has a malformed digest in $BASE/SHA256SUMS" >&2; exit 1; }
  ASSET="$cand"; want="$d"; break
done
[ -n "$ASSET" ] || { echo "fetch-clang22: neither $FIRST nor $SECOND listed in $BASE/SHA256SUMS" >&2; exit 1; }

if [ ! -f "$DL/$ASSET" ]; then
  curl -fsSL -o "$DL/$ASSET.$$" "$BASE/$ASSET" || { echo "fetch-clang22: cannot fetch $BASE/$ASSET" >&2; exit 1; }
  mv "$DL/$ASSET.$$" "$DL/$ASSET"
fi
got="$(shasum -a 256 "$DL/$ASSET" | awk '{print $1}')"
if [ "$got" != "$want" ]; then
  rm -f "$DL/$ASSET"
  echo "fetch-clang22: $ASSET checksum mismatch: expected $want, got $got" >&2
  exit 1
fi

rm -rf "$EXP"
pkgutil --expand "$DL/$ASSET" "$EXP" || { echo "fetch-clang22: cannot expand $ASSET" >&2; exit 1; }
comp=""
for info in "$EXP"/*/PackageInfo; do
  [ -f "$info" ] || continue
  if grep -F "identifier=\"dev.mavergreen.clang.$VARIANT\"" "$info" >/dev/null; then comp="$(dirname "$info")"; break; fi
done
[ -n "$comp" ] || { echo "fetch-clang22: $ASSET has no component with identifier dev.mavergreen.clang.$VARIANT" >&2; exit 1; }

mkdir -p "$NEW"
tar -xf "$comp/Payload" -C "$NEW"
[ -d "$NEW/usr/local/mavergreen/$VARIANT" ] || { echo "fetch-clang22: $ASSET payload lacks usr/local/mavergreen/$VARIANT" >&2; exit 1; }
[ ! -d "$ROOT/clang22" ] || mv "$ROOT/clang22" "$OLD"
mv "$NEW/usr/local/mavergreen/$VARIANT" "$ROOT/clang22"
rm -rf "$OLD"
printf '%s\n' "$ROOT/clang22"
