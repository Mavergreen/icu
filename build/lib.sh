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

icu_first_gnu_make() {
  for _fg_c in "$@"; do
    _fg_first="$("$_fg_c" --version 2>/dev/null | { IFS= read -r _l || true; printf '%s' "$_l"; })"
    case "$_fg_first" in *"GNU Make"*) printf '%s\n' "$_fg_c"; return 0 ;; esac
  done
  return 1
}

icu_require_gnu_make() {
  _igm_msg='GNU make is required to build ICU (on 10.9: install the Command Line Tools)'
  if [ -n "${MAKE:-}" ]; then
    icu_first_gnu_make "$MAKE" >/dev/null || { echo "$_igm_msg" >&2; exit 2; }
  else
    MAKE="$(icu_first_gnu_make gmake /usr/bin/make make)" || { echo "$_igm_msg" >&2; exit 2; }
  fi
  export MAKE
}
