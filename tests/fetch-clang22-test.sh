#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/icu-clang22-test.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
mkdir -p "$t/sy" "$t/inst/bin"
. "$ROOT/build/msc.sh"; cp -R "$SHIPYARD_SCRIPTS"/. "$t/sy/"
tools='clang clang++ ld64.lld llvm-lipo llvm-ar llvm-ranlib llvm-otool llvm-nm llvm-strings'
cat > "$t/sy/fetch_product_pkg.sh" <<EOF2
#!/bin/sh
echo "\$*" >> "$t/calls"; d="\$(eval echo "\\\${\$#}")"; mkdir -p "\$d/bin" "\$d/lib"
for b in $tools; do [ "\$b" = "\${FAKE_MISSING:-}" ] || { printf '#!/bin/sh\n' > "\$d/bin/\$b"; chmod +x "\$d/bin/\$b"; }; done
for l in libc++.a librecaulk.a; do [ "\$l" = "\${FAKE_MISSING:-}" ] || : > "\$d/lib/\$l"; done
EOF2
run() { SHIPYARD_SCRIPTS="$t/sy" MAVERGREEN_CLANG22_CACHE="$t/cache" CLANG22_INSTALLED="$t/inst" sh "$ROOT/build/fetch-clang22.sh"; }
V="$(cat "$ROOT/components/clang22/version")"

p="$(CLANG22_HOST=mac run)" || fail "a modern Mac's fetch failed"
grep -qx -- "--asset mavericks-clang-22-cross-$V.pkg clang22-cross $V $p" "$t/calls" || fail "a modern Mac must fetch clang22-cross $V (calls: $(cat "$t/calls"))"
: > "$t/calls"; p="$(CLANG22_HOST=mac109 run)" || fail "10.9's fetch failed"
grep -qx -- "--asset mavericks-clang-22-native-$V.pkg clang22 $V $p" "$t/calls" || fail "10.9 must fetch the native clang22 $V (calls: $(cat "$t/calls"))"
for missing in llvm-ranlib librecaulk.a; do
  rm -rf "$t/cache"
  if FAKE_MISSING=$missing CLANG22_HOST=mac run > "$t/out" 2>&1; then fail "a prefix lacking $missing must be refused"; fi
  grep -q "$missing" "$t/out" || fail "the refusal must name $missing (got: $(cat "$t/out"))"
done
if grep -n 'pkgutil' "$ROOT/build/fetch-clang22.sh" | grep -v '^[0-9]*:#'; then
  fail "fetch-clang22.sh reads no receipts: shipyard's fetch_clang22.sh reads the installed manifest through stevedore"
fi
echo "PASS: fetch-clang22"
