#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"

t_tmp T
CHECK="$MAVERICKS_ROOT/build/check-symbols.sh"

cat > "$T/nm-ok" <<'STUB'
#!/bin/sh
printf '_a T 10 0\n_b T 20 0\n_c D 30 0\n'
STUB
printf '#!/bin/sh\nprintf "_a T 10 0\\n"\nexit 1\n' > "$T/nm-fail"
chmod +x "$T/nm-ok" "$T/nm-fail"

printf '_a\n_b\n' > "$T/ok.txt"
out="$(sh "$CHECK" "$T/nm-ok" lib.dylib "$T/ok.txt")"
a_eq "symbols: 2 required, all exported (3 exported)" "$out" "success line"

printf '_a\n\n_z\n' > "$T/miss.txt"
rc=0; err="$(sh "$CHECK" "$T/nm-ok" lib.dylib "$T/miss.txt" 2>&1 >/dev/null)" || rc=$?
a_eq 1 "$rc" "missing symbol exits 1"
a_contains "$err" "missing: _z" "names the missing symbol"

: > "$T/empty.txt"
rc=0; sh "$CHECK" "$T/nm-ok" lib.dylib "$T/empty.txt" >/dev/null 2>&1 || rc=$?
a_eq 2 "$rc" "empty symbols file exits 2"
rc=0; sh "$CHECK" "$T/nm-ok" lib.dylib "$T/none.txt" >/dev/null 2>&1 || rc=$?
a_eq 2 "$rc" "unreadable symbols file exits 2"

rc=0; sh "$CHECK" "$T/nm-fail" lib.dylib "$T/ok.txt" >/dev/null 2>&1 || rc=$?
a_eq 1 "$rc" "failing NM exits 1"

a_done
