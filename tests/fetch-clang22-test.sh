#!/bin/sh
# platform: macOS-only -- pkgbuild and productbuild make the fixture pkg
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"

t_tmp T
ICU_MODE=native; export ICU_MODE
MAVERICKS_BUILD_ROOT="$T/build"; export MAVERICKS_BUILD_ROOT
CLANG22_RELEASE_BASE="file://$(printf '%s' "$T/rel" | sed 's/ /%20/g')"; export CLANG22_RELEASE_BASE
ROOT="$T/build/$(basename "$MAVERICKS_ROOT")-icu-native"
FETCH="$MAVERICKS_ROOT/build/fetch-clang22.sh"
TAG="$(tr -d '\r\n ' < "$MAVERICKS_ROOT/components/clang22/version")"
REL="$T/rel/$TAG"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

mkpkg() {
  _v="$1"
  rm -rf "$T/pk"; mkdir -p "$T/pk/base/usr/local/mavergreen/base" "$T/pk/c/usr/local/mavergreen/$_v/bin"
  : > "$T/pk/base/usr/local/mavergreen/base/marker"
  printf '#!/bin/sh\necho stub-%s\n' "$_v" > "$T/pk/c/usr/local/mavergreen/$_v/bin/clang"
  chmod +x "$T/pk/c/usr/local/mavergreen/$_v/bin/clang"
  pkgbuild --quiet --root "$T/pk/base" --identifier dev.mavergreen.base --version 1 "$T/pk/base.pkg"
  pkgbuild --quiet --root "$T/pk/c" --identifier "dev.mavergreen.clang.$_v" --version 1 "$T/pk/c.pkg"
  productbuild --package "$T/pk/base.pkg" --package "$T/pk/c.pkg" "$T/pk/product.pkg" >/dev/null
}

fresh() { rm -rf "$ROOT"; }

mkrel() {
  _v="$1"; _name="$2"
  mkpkg "$_v"
  rm -rf "$REL"; mkdir -p "$REL"
  cp "$T/pk/product.pkg" "$REL/$_name"
  printf '%s  %s\n' "$(sha256 "$REL/$_name")" "$_name" > "$REL/SHA256SUMS"
}

fresh; mkrel clang22-cross "clang22-cross-$TAG.pkg"
out="$(CLANG22_VARIANT=clang22-cross sh "$FETCH")"
a_eq "$ROOT/clang22" "$out" "prints the toolchain dir"
a_eq "stub-clang22-cross" "$("$out/bin/clang")" "bin/clang is the stub"
a_file_exists "base component not unpacked as the toolchain" "$out/bin/clang"
out="$(CLANG22_VARIANT=clang22-cross sh "$FETCH")"
a_eq "stub-clang22-cross" "$("$out/bin/clang")" "second run from cache"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
out="$(CLANG22_VARIANT=clang22-cross sh "$FETCH")"
a_eq "stub-clang22-cross" "$("$out/bin/clang")" "fallback asset name"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
cp "$REL/mavericks-clang-22-cross-$TAG.pkg" "$REL/clang22-cross-$TAG.pkg"
{ printf '%s  clang22-cross-%s.pkg\n' "$(sha256 "$REL/clang22-cross-$TAG.pkg")" "$TAG"; cat "$REL/SHA256SUMS"; } > "$REL/s.new"
mv "$REL/s.new" "$REL/SHA256SUMS"
out="$(CLANG22_VARIANT=clang22-cross sh "$FETCH")"
a_file_exists "contract name preferred" "$ROOT/dl/clang22-cross-$TAG.pkg"
a_no_file "fallback not fetched when contract name listed" "$ROOT/dl/mavericks-clang-22-cross-$TAG.pkg"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
printf '%s  other.pkg\n' "$(sha256 "$REL/mavericks-clang-22-cross-$TAG.pkg")" > "$REL/SHA256SUMS"
rc=0; err="$(CLANG22_VARIANT=clang22-cross sh "$FETCH" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "nothing listed exits 1"
a_contains "$err" "clang22-cross-$TAG.pkg" "names the contract asset"
a_contains "$err" "mavericks-clang-22-cross-$TAG.pkg" "names the fallback asset"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
printf '%s  decoy-mavericks-clang-22-cross-%s.pkg\n' "$(sha256 "$REL/mavericks-clang-22-cross-$TAG.pkg")" "$TAG" > "$REL/SHA256SUMS"
a_fails "substring of an asset name is not a match" env CLANG22_VARIANT=clang22-cross sh "$FETCH"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
printf '%s  mavericks-clang-22-cross-%s.pkg\r\n' "$(sha256 "$REL/mavericks-clang-22-cross-$TAG.pkg" | tr 'a-f' 'A-F')" "$TAG" > "$REL/SHA256SUMS"
out="$(CLANG22_VARIANT=clang22-cross sh "$FETCH")"
a_file_exists "CRLF and upper-case digest accepted" "$out/bin/clang"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
printf 'abc123  mavericks-clang-22-cross-%s.pkg\n' "$TAG" > "$REL/SHA256SUMS"
rc=0; err="$(CLANG22_VARIANT=clang22-cross sh "$FETCH" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "short digest exits 1"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
echo tamper >> "$REL/mavericks-clang-22-cross-$TAG.pkg"
rc=0; err="$(CLANG22_VARIANT=clang22-cross sh "$FETCH" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "tampered exits 1"
a_contains "$err" "checksum mismatch" "tampered message"
a_no_file "tampered cache removed" "$ROOT/dl/mavericks-clang-22-cross-$TAG.pkg"

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
rm -f "$REL/SHA256SUMS"
a_fails "missing sums exits nonzero" env CLANG22_VARIANT=clang22-cross sh "$FETCH"

fresh; mkrel clang22-cross "clang22-$TAG.pkg"
rc=0; err="$(CLANG22_VARIANT=clang22 sh "$FETCH" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "clang22 never matches a clang22-cross component"
a_contains "$err" "dev.mavergreen.clang.clang22" "names the identifier"

fresh; mkrel clang22 "mavericks-clang-22-native-$TAG.pkg"
out="$(sh "$FETCH")"
a_eq "stub-clang22" "$("$out/bin/clang")" "native mode defaults to the clang22 variant"

fresh; mkrel clang22-cross "clang22-cross-$TAG.pkg"
printf '%s  clang22-cross-%s.pkg\n%s  mavericks-clang-22-cross-%s.pkg\n' abc123 "$TAG" "$(sha256 "$REL/clang22-cross-$TAG.pkg")" "$TAG" > "$REL/SHA256SUMS"
rc=0; err="$(CLANG22_VARIANT=clang22-cross sh "$FETCH" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "malformed contract-name digest exits 1, no fallthrough"
a_contains "$err" "malformed digest" "malformed digest message"

fresh; mkrel clang22-cross "clang22-cross-$TAG.pkg"
CLANG22_VARIANT=clang22-cross sh "$FETCH" >/dev/null
mkrel clang22 "clang22-cross-$TAG.pkg"
rc=0; CLANG22_VARIANT=clang22-cross sh "$FETCH" >/dev/null 2>&1 || rc=$?
a_eq 1 "$rc" "bad payload layout exits 1"
a_eq "stub-clang22-cross" "$("$ROOT/clang22/bin/clang")" "previous good tree survives a failed run"
a_no_file "no swap leftovers" "$ROOT/clang22.new"
a_eq 0 "$(ls "$ROOT" | grep -c 'clang22\.\(old\|new\)')" "no temp trees left behind"

fresh; mkrel clang22-cross "clang22-cross-$TAG.pkg"
CLANG22_VARIANT=clang22-cross sh "$FETCH" >/dev/null
echo notapkg > "$REL/clang22-cross-$TAG.pkg"
printf '%s  clang22-cross-%s.pkg\n' "$(sha256 "$REL/clang22-cross-$TAG.pkg")" "$TAG" > "$REL/SHA256SUMS"
rm -rf "$ROOT/dl"
rc=0; err="$(CLANG22_VARIANT=clang22-cross sh "$FETCH" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "unexpandable pkg exits 1"
a_contains "$err" "cannot expand" "expand failure message"
a_eq "stub-clang22-cross" "$("$ROOT/clang22/bin/clang")" "previous good tree survives a corrupt pkg"

FAKE="$T/fake"; mkdir -p "$FAKE/components/clang22"
cp -R "$MAVERICKS_ROOT/build" "$FAKE/build"
for v in "" "   "; do
  printf '%s\n' "$v" > "$FAKE/components/clang22/version"
  rc=0; err="$(MAVERICKS_ROOT="$FAKE" sh "$FAKE/build/fetch-clang22.sh" 2>&1 >/dev/null)" || rc=$?
  a_eq 1 "$rc" "blank version exits 1"
  a_contains "$err" "version is empty" "blank version message"
done

fresh; mkrel clang22-cross "mavericks-clang-22-cross-$TAG.pkg"
out="$(ICU_MODE=cross sh "$FETCH")"
a_eq "stub-clang22-cross" "$("$out/bin/clang")" "cross mode defaults to clang22-cross"
a_eq "$T/build/$(basename "$MAVERICKS_ROOT")-icu-cross/clang22" "$out" "cross mode uses the cross build root"

a_done
