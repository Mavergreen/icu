# platform: host-agnostic
: "${MAVERICKS_ROOT:=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd || pwd)}"
export MAVERICKS_ROOT
. "$MAVERICKS_ROOT/build/msc.sh"
. "$SHIPYARD/lib.sh"

ICU_INSTALL_NAME=/usr/local/mavergreen/icu/lib/libicucore.dylib
ICU_DYLIB_VERSION=76.1

icu_mode() {
  case "${ICU_MODE:-}" in
    '') sh "$SHIPYARD/mavericks_mode.sh" ;;
    native|cross) printf '%s\n' "$ICU_MODE" ;;
    *) echo "icu_mode: ICU_MODE must be native or cross, not '$ICU_MODE'" >&2; exit 2 ;;
  esac
}

icu_build_root() {
  _ibr_mode="$(icu_mode)" || return $?
  printf '%s\n' "${MAVERICKS_BUILD_ROOT:-${TMPDIR:-/tmp}/mm-build}/$(basename "$MAVERICKS_ROOT")-icu-$_ibr_mode"
}

icu_src_dir() {
  _isd_root="$(icu_build_root)" || return $?
  printf '%s\n' "$_isd_root/src/icu/source"
}

icu_major() {
  _im_v="$(upstream_version)"
  printf '%s\n' "${_im_v%%.*}"
}
