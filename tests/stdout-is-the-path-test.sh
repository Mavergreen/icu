#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"
. "$HERE/helpers/assert.sh"

for f in build/build.sh packaging/build-pkg.sh; do
  body="$(sed -e '/^#/d' -e ':a' -e '/\\$/{N;s/\\\n//;ba' -e '}' "$MAVERICKS_ROOT/$f" | sed '$d')"
  loud="$(printf '%s\n' "$body" | grep -E 'assert_binary_compatible|check-symbols\.sh|stage_product\.sh|link-libicucore\.sh|install-headers\.sh' | grep -v '>&2' || true)"
  a_eq "" "$loud" "$f: checks that print on stdout are redirected to stderr"
done
a_done
