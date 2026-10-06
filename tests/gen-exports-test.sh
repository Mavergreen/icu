#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"

t_tmp T
GEN="$MAVERICKS_ROOT/build/gen-exports.sh"

cat > "$T/nm-ok" <<'STUB'
#!/bin/sh
cat <<'OUT'

libx.a(a.o):
0000000000000010 (__TEXT,__text) external _c_fn
0000000000000020 (__DATA,__data) external _c_data
0000000000000030 (__TEXT,__const) external _c_const
0000000000000040 (__TEXT,__text) private external _c_hidden
0000000000000050 (__TEXT,__text) external __Z6cxx_fnv
0000000000000060 (__TEXT,__text) non-external _local

libx.a(b.o):
0000000000000010 (__TEXT,__text) external _c_fn
OUT
echo "llvm-nm: warning: libx.a(c.o): no symbols" >&2
STUB
chmod +x "$T/nm-ok"
out="$(sh "$GEN" "$T/nm-ok" a.a b.a 2>/dev/null)"
a_eq "_c_const
_c_data
_c_fn" "$out" "C externals, sorted and unique"

printf '#!/bin/sh\necho "(__TEXT,__text) external _x"\nexit 1\n' > "$T/nm-fail"
chmod +x "$T/nm-fail"
rc=0; out="$(sh "$GEN" "$T/nm-fail" a.a 2>/dev/null)" || rc=$?
a_eq 1 "$rc" "failing NM exits 1"
a_eq "" "$out" "failing NM prints nothing"

cat > "$T/nm-cxx" <<'STUB'
#!/bin/sh
echo "0000000000000050 (__TEXT,__text) external __Z6cxx_fnv"
echo "0000000000000040 (__TEXT,__text) private external _c_hidden"
STUB
chmod +x "$T/nm-cxx"
rc=0; out="$(sh "$GEN" "$T/nm-cxx" a.a 2>/dev/null)" || rc=$?
a_eq 1 "$rc" "no C symbols exits 1"
a_eq "" "$out" "no C symbols prints nothing"

rc=0; sh "$GEN" >/dev/null 2>&1 || rc=$?
a_eq 2 "$rc" "usage error exits 2"

a_done
