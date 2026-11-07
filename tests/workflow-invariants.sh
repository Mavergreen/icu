#!/bin/sh
# platform: host-agnostic
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
R="$ROOT/.github/workflows/release.yml"
fail() { echo "FAIL: $1"; exit 1; }
code="$(grep -v '^[[:space:]]*#' "$R" | sed 's/[[:space:]]#.*$//')"
line_of() { printf '%s\n' "$code" | grep -n -e "$1" | sed -n '1s/:.*//p'; }
has() { printf '%s\n' "$code" | grep -q -e "$1"; }
job() { printf '%s\n' "$code" | awk -v j="$1" '$0 ~ "^  "j":"{f=1;print;next} /^  [a-z][a-z-]*:$/{f=0} f'; }
step_if() { printf '%s\n' "$1" | awk -v p="$2" '/^      - /{if(m)print i; m=0; i=""} /^      - if: |^        if: /{i=$0; sub(/^ *(- )?if: /,"",i)} index($0,p){m=1} END{if(m)print i}'; }

printf '%s\n' "$code" | awk '/^  pull_request:/{f=1;next} f&&/branches:/{print;exit}' | grep -q '\[main\]' \
  || fail "release.yml must build pull requests to main: Renovate's automerge waits on that check"
printf '%s\n' "$code" | awk '/^  push:/{f=1;next} f&&/branches/{print;exit}' | grep -q "branches-ignore: \['renovate/\*\*'\]" \
  || fail "release.yml must build every branch push but Renovate's: a branch goes green before main does"
ver="$(job ver)"
printf '%s\n' "$ver" | grep -q 'runs-on: ubuntu-latest' || fail "the ver job must run on Linux: macOS runners are scarce"
printf '%s\n' "$ver" | grep -q 'release-needed.sh' || fail "a dispatch that is not a repackage must publish only a declared state no release carries (release-needed.sh)"
printf '%s\n' "$code" | awk '/^  workflow_dispatch:/{f=1;next} /^  [a-z_]+:/{f=0} f' | grep -q '^      reconcile:' \
  || fail "release.yml must accept reconcile.yml's dispatch-field, reconcile=true"
grep -q 'dispatch-field: reconcile=true' "$ROOT/.github/workflows/reconcile.yml" \
  || fail "reconcile.yml must dispatch with reconcile=true, so ver re-asks release-needed.sh and publishes a never-released upstream as N; its default, local_release=true, would cut N+1"

build="$(job build)"
printf '%s\n' "$build" | grep -q 'runs-on: ubuntu-latest' || fail "the build job must run on Linux: it builds, tests, packages and signs there, and macOS runners are scarce"
macos="$(printf '%s\n' "$code" | awk '/^  [a-z][a-z-]*:$/{j=$1} /runs-on: macos-/{print j}' | xargs)"
[ -z "$macos" ] || fail "icu ships x86_64 alone and tests it on 10.9, so no job runs on macOS (got '$macos')"
printf '%s\n' "$build" | grep -q 'run-repo-tests.sh" --strict-host' || fail "the Linux build must run every host-agnostic test, none skipping (--strict-host)"
keyed="$(printf '%s\n' "$code" | awk '
  /^  [a-z][a-z-]*:$/ { j = $1; s = "" }
  /^      - / { s = NR }
  /secrets\.SPARKLE_PRIVATE_KEY/ { print j " " s }')"
for k in $(printf '%s\n' "$keyed" | awk '{print $1}' | sort -u); do
  case "$k" in build:|scan:) ;; *) fail "only the build job's signing step and the scan job may see the signing key (job $k does)" ;; esac
done
signstep="$(printf '%s\n' "$code" | awk '/^  build:$/{f=1;next} /^  [a-z][a-z-]*:$/{f=0} f&&/^      - /{s=NR} f&&/sign_and_appcast\.sh/{print s; exit}')"
bsteps="$(printf '%s\n' "$keyed" | awk '$1 == "build:" {print $2}' | sort -u)"
[ -n "$signstep" ] && [ "$bsteps" = "$signstep" ] \
  || fail "in the build job the signing key belongs in the signing step's env alone, the step that runs sign_and_appcast.sh (key in steps at lines '$bsteps', signing step at '$signstep')"
printf '%s\n' "$build" | grep -q 'LIPO=$CL/bin/llvm-lipo' || fail "conformance must read Mach-O with clang22's llvm-lipo and llvm-otool"
printf '%s\n' "$build" | grep -q 'name: icu-binaries' || fail "the build must upload the dylib, headers and updater it packaged, so another host can repackage them byte for byte"
bi="$(step_if "$build" 'icu-binaries.tar')"
[ "$bi" = "github.event_name == 'workflow_dispatch'
github.event_name == 'workflow_dispatch'" ] \
  || fail "the icu-binaries tar and its upload run on workflow_dispatch alone, a release or a conversion proof dispatched on a branch, not on every push (got: $bi)"
printf '%s\n' "$build" | grep -q 'name: icu-smoke' || fail "the build must upload the smoke program vm-test runs on 10.9"
has 'sh build/build.sh' || fail "release.yml must build libicucore.dylib"
has 'sh build/build-updater.sh' || fail "release.yml must build the updater with clang22"
has 'sh packaging/build-pkg.sh' || fail "release.yml must package icu"
has 'run-repo-tests.sh' || fail "release.yml must run the repo's tests"
if has 'rosetta'; then fail "release.yml must not use Rosetta: the shipped x86_64 dylib runs on 10.9, in the vm-test job"; fi
if grep -q '^- rosetta:' "$ROOT/INGREDIENTS.md"; then fail "nothing uses Rosetta, so INGREDIENTS.md declares no Rosetta use"; fi
b="$(line_of 'sh build/build.sh')"; p="$(line_of 'sh packaging/build-pkg.sh')"; t="$(line_of 'run-repo-tests.sh')"
[ -n "$b" ] && [ -n "$p" ] && [ -n "$t" ] && [ "$b" -lt "$p" ] && [ "$p" -lt "$t" ] \
  || fail "build, then package, then run-repo-tests.sh: smoke-test and package-test check what the build made"
has 'check-artifact-conformance.sh' || fail "release.yml must check artifact conformance"

vm="$(job vm-test)"
printf '%s\n' "$vm" | grep -q 'uses: Mavergreen/mavericks-vm@v1' || fail "a vm-test job must boot Mac OS X 10.9 with Mavergreen/mavericks-vm"
printf '%s\n' "$vm" | grep -q 'needs: \[ver, build\]' || fail "vm-test must test the pkg the build job made"
printf '%s\n' "$vm" | grep -q 'installer -pkg "dist/icu-$ICU_FULL_VERSION.pkg"' || fail "vm-test must install this run's pkg in the guest"
un="$(printf '%s\n' "$vm" | grep -n -e '^ *if \[ -x /usr/local/bin/mavergreen \] && \[ -f /usr/local/mavergreen/icu/mavergreen.plist \]; then sudo /usr/local/bin/mavergreen uninstall icu; fi$' | cut -d: -f1)"
fg="$(printf '%s\n' "$vm" | grep -n -e '^ *if pkgutil --pkg-info dev.mavergreen.icu >/dev/null 2>&1; then sudo pkgutil --forget dev.mavergreen.icu; fi$' | cut -d: -f1)"
gone="$(printf '%s\n' "$vm" | grep -n -e '^ *if \[ -e /usr/local/mavergreen/icu \] || pkgutil --pkg-info dev.mavergreen.icu >/dev/null 2>&1; then' | cut -d: -f1)"
in="$(printf '%s\n' "$vm" | grep -n -e '^ *sudo installer -pkg "dist/icu-$ICU_FULL_VERSION.pkg"' | cut -d: -f1)"
[ -n "$un" ] && [ -n "$fg" ] && [ -n "$gone" ] && [ -n "$in" ] && [ "$un" -lt "$fg" ] && [ "$fg" -lt "$gone" ] && [ "$gone" -lt "$in" ] \
  || fail "vm-test must remove any icu the guest image carries, files and receipt, and check it is gone, before installing this run's pkg: on-target.sh's version check otherwise passes on the image's icu"
printf '%s\n' "$vm" | grep -q 'name: icu-smoke' || fail "vm-test must download the smoke program the build job compiled"
printf '%s\n' "$vm" | grep -q 'sh tests/on-target.sh "$ICU_FULL_VERSION" smoke/icu-smoke' || fail "vm-test must run tests/on-target.sh with the smoke program against the installed version: it is the only run of the x86_64 dylib"
printf '%s\n' "$vm" | grep -q 'packages: write' || fail "vm-test needs packages: write for mavericks-vm's shared guest cache"
printf '%s\n' "$vm" | grep -q 'sh build/launch-updater.sh' || fail "vm-test must launch the Linux-built updater on 10.9"
if printf '%s\n' "$vm" | grep -q 'SPARKLE_PRIVATE_KEY'; then fail "vm-test must not see the signing key"; fi
guard="github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository || startsWith(github.head_ref, 'renovate/')"
for j in vm-test; do
  jj="$(job "$j")"
  if printf '%s\n' "$jj" | grep -q 'continue-on-error'; then fail "$j must fail the run when it fails: no continue-on-error on the job or a step"; fi
  [ "$(printf '%s\n' "$jj" | sed -n 's/^    if: //p')" = "$guard" ] || fail "$j may skip only a fork's pull request: its if: must be the fork-PR guard alone"
  if printf '%s\n' "$jj" | grep -q -e '^      - if: ' -e '^        if: '; then fail "$j's steps run unconditionally: a skipped step is a smoke that did not run"; fi
done
if has 'secrets: inherit'; then fail "no job inherits every secret: the signing key reaches the build's signing step and scan alone"; fi
pn="$(printf '%s\n' "$code" | awk '/^  publish:/{f=1;next} /^  [a-z][a-z-]*:$/{f=0} f&&/needs:/')"
printf '%s\n' "$pn" | grep -q 'vm-test' || fail "publish must wait for vm-test: a dylib that did not run on 10.9 must not ship"
job retry | grep -q 'uses: Mavergreen/shipyard/.github/workflows/retry-release.yml@v1' || fail "a retry job must recover a publish that lost its tag"
req="$(job required)"
printf '%s\n' "$req" | grep -q 'name: required (release)' && printf '%s\n' "$req" | grep -q 'if: always()' \
  && printf '%s\n' "$req" | grep -q 'uses: Mavergreen/shipyard/.github/actions/required-gate@v1' \
  || fail "a 'required (release)' job must always run and judge the others with required-gate@v1"
jobs="$(printf '%s\n' "$code" | awk '/^jobs:/{f=1;next} f&&/^  [a-z][a-z-]*:$/{sub(/:$/,"");sub(/^  /,"");if($0!="required")print}' | sort | xargs)"
rneeds="$(printf '%s\n' "$req" | sed -n 's/^ *needs: \[\(.*\)\]$/\1/p' | tr ',' '\n' | tr -d ' ' | sort | xargs)"
[ -n "$jobs" ] && [ "$rneeds" = "$jobs" ] || fail "'required (release)' must need every other job ($jobs), or a failing one is not required (needs: $rneeds)"

notes="$(line_of 'release-notes.sh')"; state="$(line_of 'release-state-record.sh')"
sign="$(line_of 'sign_and_appcast.sh')"; publish="$(line_of 'publish-release.yml')"
[ -n "$notes" ] && [ -n "$state" ] && [ -n "$sign" ] && [ -n "$publish" ] \
  || fail "release.yml must generate notes, record the state, sign the appcast and publish"
[ "$notes" -lt "$state" ] && [ "$state" -lt "$sign" ] && [ "$sign" -lt "$publish" ] \
  || fail "notes, then the state marker, then signing, then publishing: the appcast and the Release must carry the same notes"
has 'sign_and_appcast.sh" --product icu --feed-dir dist' || fail "the appcast must be icu.xml, signed by sign_and_appcast.sh"
has 'scan-for-key.yml' || fail "a signing run must scan its logs for the key before publishing"
for j in scan publish; do
  job "$j" | grep -q 'artifact: icu$\|artifact: icu }' || fail "$j must use only the icu artifact"
done
echo "PASS: workflow invariants"
