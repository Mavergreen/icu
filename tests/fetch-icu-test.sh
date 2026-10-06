#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"

t_tmp T
ICU_MODE=native; export ICU_MODE
MAVERICKS_BUILD_ROOT="$T/build"; export MAVERICKS_BUILD_ROOT
ICU_RELEASE_BASE="file://$(printf '%s' "$T/rel" | sed 's/ /%20/g')"; export ICU_RELEASE_BASE
ROOT="$T/build/$(basename "$MAVERICKS_ROOT")-icu-native"
FETCH="$MAVERICKS_ROOT/build/fetch-icu.sh"

sha512() { shasum -a 512 "$1" | awk '{print $1}'; }

mkrel() {
  d="$T/rel/release-$1"; mkdir -p "$d" "$T/stage-$1/icu/source"
  : > "$T/stage-$1/icu/source/runConfigureICU"
  tar -czf "$d/icu4c-$1-sources.tgz" -C "$T/stage-$1" icu
  printf '%s *icu4c-%s-sources.tgz\n' "$(sha512 "$d/icu4c-$1-sources.tgz")" "$1" > "$d/SHASUM512.txt"
}

mkrel 78.2
out="$(sh "$FETCH" 78.2)"
a_eq "$ROOT/src/icu/source" "$out" "prints the source dir"
a_file_exists "runConfigureICU extracted" "$out/runConfigureICU"

: > "$ROOT/src/stale"
sh "$FETCH" 78.2 >/dev/null
a_no_file "stale file removed" "$ROOT/src/stale"

rm -rf "$ROOT/dl"
echo tamper >> "$T/rel/release-78.2/icu4c-78.2-sources.tgz"
rc=0; err="$(sh "$FETCH" 78.2 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "tampered exits 1"
a_contains "$err" "icu4c-78.2-sources.tgz" "tampered names the asset"
a_no_file "tampered cache removed" "$ROOT/dl/icu4c-78.2-sources.tgz"

mkrel 78.2
printf '%s *other.tgz\n' "$(sha512 "$T/rel/release-78.2/icu4c-78.2-sources.tgz")" > "$T/rel/release-78.2/SHASUM512.txt"
rc=0; err="$(sh "$FETCH" 78.2 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "unlisted exits 1"
a_contains "$err" "not listed in SHASUM512.txt" "unlisted message"

mkrel 78.2
mkdir -p "$ROOT/dl"; echo poison > "$ROOT/dl/icu4c-78.2-sources.tgz"
rc=0; err="$(sh "$FETCH" 78.2 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "poisoned cache exits 1"
a_contains "$err" "checksum mismatch" "poisoned cache message"
a_no_file "poisoned cache removed" "$ROOT/dl/icu4c-78.2-sources.tgz"
out="$(sh "$FETCH" 78.2)"
a_file_exists "recovers after poison" "$out/runConfigureICU"

mkrel 78.2
t="$T/rel/release-78.2"
{ printf '%s *icu4c-78x2-sources.tgz\n' "$(printf 'x' | shasum -a 512 | awk '{print $1}')"; cat "$t/SHASUM512.txt"; } > "$t/s.new"
mv "$t/s.new" "$t/SHASUM512.txt"
rm -rf "$ROOT/dl"
out="$(sh "$FETCH" 78.2)"
a_file_exists "decoy ignored" "$out/runConfigureICU"

mkrel 78.2
t="$T/rel/release-78.2"
printf '%s *icu4c-78.2-sources.tgz\n' "$(sha512 "$t/icu4c-78.2-sources.tgz" | tr 'a-f' 'A-F')" > "$t/SHASUM512.txt"
rm -rf "$ROOT/dl"
out="$(sh "$FETCH" 78.2)"
a_file_exists "upper-case digest accepted" "$out/runConfigureICU"

mkrel 78.2
t="$T/rel/release-78.2"
printf '%s *icu4c-78.2-sources.tgz\r\n' "$(sha512 "$t/icu4c-78.2-sources.tgz")" > "$t/SHASUM512.txt"
rm -rf "$ROOT/dl"
out="$(sh "$FETCH" 78.2)"
a_file_exists "CRLF accepted" "$out/runConfigureICU"

mkrel 78.2
t="$T/rel/release-78.2"
printf 'abc123 *icu4c-78.2-sources.tgz\n' > "$t/SHASUM512.txt"
rm -rf "$ROOT/dl"
rc=0; err="$(sh "$FETCH" 78.2 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "short digest exits 1"
a_contains "$err" "not listed in SHASUM512.txt" "short digest message"

mkrel 78.2
: > "$T/rel/release-78.2/SHASUM512.txt"
rm -rf "$ROOT/dl"
rc=0; err="$(sh "$FETCH" 78.2 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "empty sums exits 1"
a_contains "$err" "not listed in SHASUM512.txt" "empty sums message"

mkrel 78.2
rm -f "$T/rel/release-78.2/SHASUM512.txt"
rm -rf "$ROOT/dl"
rc=0; sh "$FETCH" 78.2 >/dev/null 2>&1 || rc=$?
a_eq 1 "$rc" "missing sums exits 1"
a_no_file "nothing cached without sums" "$ROOT/dl/icu4c-78.2-sources.tgz"

mkrel 78.2
rm -rf "$ROOT/dl"
sh "$FETCH" 78.2 >/dev/null
: > "$ROOT/src/keep"
t="$T/rel/release-78.2"
echo notatar > "$T/bad.tgz"
cp "$T/bad.tgz" "$t/icu4c-78.2-sources.tgz"
printf '%s *icu4c-78.2-sources.tgz\n' "$(sha512 "$T/bad.tgz")" > "$t/SHASUM512.txt"
rm -rf "$ROOT/dl"
a_fails "bad tarball fails" sh "$FETCH" 78.2
a_file_exists "previous src kept on tar failure" "$ROOT/src/keep"

mkrel 79.1
out="$(sh "$FETCH" 79.1)"
a_file_exists "79.1 fetched" "$out/runConfigureICU"

a_done
