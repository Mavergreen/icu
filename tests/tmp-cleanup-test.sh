#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/helpers/assert.sh"
S="$(mktemp -d "${TMPDIR:-/tmp}/icu-test.XXXXXX")"
trap 'rm -rf "$S"' EXIT
( TMPDIR="$S"; . "$HERE/helpers/assert.sh"; t_tmp D; printf '%s\n' "$D" > "$S/path"; touch "$D/x" )
a_file_exists "the child recorded its scratch dir" "$S/path"
a_no_file "t_tmp's dir is removed when the test exits" "$(cat "$S/path")"
a_fails "t_tmp with no variable name is refused" sh -c ". \"$HERE/helpers/assert.sh\"; t_tmp"
a_done
