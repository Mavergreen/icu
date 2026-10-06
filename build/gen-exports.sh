#!/bin/sh
# platform: host-agnostic
set -eu

[ $# -ge 2 ] || { echo "usage: gen-exports.sh NM ARCHIVE..." >&2; exit 2; }
NM="$1"; shift

raw="$("$NM" -g -U -m "$@")" || { echo "gen-exports: $NM failed" >&2; exit 1; }

out="$(printf '%s\n' "$raw" | awk '
  /^[ \t]*$/ { next }
  /:$/ { next }
  index($0, " external ") == 0 { next }
  index($0, "private external") != 0 { next }
  { n = $NF; if (substr(n, 1, 3) != "__Z") print n }
' | LC_ALL=C sort -u)"

[ -n "$out" ] || { echo "gen-exports: no exported C symbols in the archives" >&2; exit 1; }
printf '%s\n' "$out"
