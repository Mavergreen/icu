#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/linux-host.XXXXXX")"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/repo" "$t/sy"
cp -R "$ROOT/build" "$ROOT/components" "$t/repo/"; cp "$ROOT/UPSTREAM_VERSION" "$t/repo/"
. "$ROOT/build/msc.sh"; cp -R "$SHIPYARD_SCRIPTS"/. "$t/sy/"
cat > "$t/sy/fetch_product_tar.sh" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$CALLS"
mkdir -p "$4/bin" "$4/lib"
for b in clang clang++ ld64.lld llvm-lipo llvm-ar llvm-ranlib llvm-otool llvm-nm llvm-strings; do
  printf '#!/bin/sh\nexit 0\n' > "$4/bin/$b"; chmod +x "$4/bin/$b"
done
: > "$4/lib/libc++.a"; : > "$4/lib/librecaulk.a"
printf '%s\n' "$4"
SH
V="$(cat "$ROOT/components/clang22/version")"
SHA=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
printf '%s  clang22-%s-linux-x86_64.tar.gz\n' "$SHA" "$V" > "$t/repo/components/clang22/linux-sha256"
export CALLS="$t/calls" SHIPYARD_SCRIPTS="$t/sy" MAVERGREEN_CLANG22_CACHE="$t/cache" CLANG22_HOST=linux
prefix="$(sh "$t/repo/build/fetch-clang22.sh")"
[ "$(sed -n 1p "$CALLS")" = clang22 ] && [ "$(sed -n 2p "$CALLS")" = "$V" ] && [ "$(sed -n 3p "$CALLS")" = "$SHA" ] \
  && [ "$(sed -n 4p "$CALLS")" = "$prefix" ] || fail "Linux must fetch clang22 $V's archive by its pinned digest (calls: $(cat "$CALLS"))"
rm "$CALLS"
printf '%s  clang22-old-linux-x86_64.tar.gz\n' "$SHA" > "$t/repo/components/clang22/linux-sha256"
if sh "$t/repo/build/fetch-clang22.sh" >/dev/null 2>&1; then fail "a digest for another version must be refused"; fi
[ ! -e "$CALLS" ] || fail "a stale digest must be refused before anything is fetched"
echo 'PASS: Linux clang fetch uses matching version/digest and refuses stale pins'
