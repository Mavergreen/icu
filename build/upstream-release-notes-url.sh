#!/bin/sh
# platform: host-agnostic
set -eu
printf 'https://github.com/unicode-org/icu/releases/tag/release-%s\n' "${1:?usage: upstream-release-notes-url.sh <upstream-version>}"
