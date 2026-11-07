#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $1"; exit 1; }
t="$(mktemp -d "${TMPDIR:-/tmp}/icu-updater-app.XXXXXX")"; trap 'rm -rf "$t"' EXIT INT TERM
mkdir -p "$t/out" "$t/empty.app/Contents/MacOS"; : > "$t/out/libicucore.dylib"
for app in "$t/nope.app" "$t/empty.app"; do
  if out="$(sh "$ROOT/packaging/build-pkg.sh" "$app" "$t/out/libicucore.dylib" 78.3-mavericks.1 "$t/dist" 2>&1)"; then
    fail "build-pkg.sh must refuse the updater $app"
  fi
  case "$out" in "build-pkg: $app"*) ;; *) fail "the refusal must name $app before anything else uses it (got: $out)" ;; esac
done
case "$out" in *"Contents/MacOS/icu-updater"*) ;; *) fail "an app with no executable must be refused for that (got: $out)" ;; esac
[ ! -e "$t/dist" ] || fail "a refused package must leave no OUT-DIR"
echo "PASS: updater-app"
