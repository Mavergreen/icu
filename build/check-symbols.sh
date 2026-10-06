#!/bin/sh
# platform: host-agnostic
set -eu

[ $# -eq 3 ] || { echo "usage: check-symbols.sh NM DYLIB SYMBOLS_FILE" >&2; exit 2; }
NM="$1"; DYLIB="$2"; SYMS="$3"

[ -r "$SYMS" ] && [ -n "$(tr -d ' \t\r\n' < "$SYMS")" ] || { echo "check-symbols: $SYMS is empty or unreadable" >&2; exit 2; }

raw="$("$NM" -g -U -P "$DYLIB")" || { echo "check-symbols: $NM failed on $DYLIB" >&2; exit 1; }

EXPORTED="${TMPDIR:-/tmp}/check-symbols.$$"
trap 'rm -f "$EXPORTED"' EXIT
printf '%s\n' "$raw" | awk 'NF {print $1}' > "$EXPORTED"

rc=0
awk '
  FNR == NR { if (!($1 in have)) { have[$1] = 1; m++ } next }
  /^[ \t\r]*$/ { next }
  { n++; if (!($1 in have)) { print "missing: " $1 > "/dev/stderr"; bad = 1 } }
  END {
    if (bad) exit 1
    printf "symbols: %d required, all exported (%d exported)\n", n, m
  }
' "$EXPORTED" "$SYMS" || rc=1
exit "$rc"
