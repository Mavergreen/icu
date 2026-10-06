#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
MAVERICKS_ROOT="$(cd "$HERE/.." && pwd)"; export MAVERICKS_ROOT
. "$HERE/helpers/assert.sh"
. "$MAVERICKS_ROOT/build/lib.sh"

t_tmp T
API="$MAVERICKS_ROOT/build/public-api.sh"

mkdir -p "$T/fx/unicode" "$T/empty/unicode"
cat > "$T/fx/unicode/x.h" <<'H'
#define U_CAPI U_CFUNC U_EXPORT
/** @stable ICU 2.0 */
U_CAPI int32_t U_EXPORT2 pub_one(const char *s);
/** @stable ICU 2.0 */
U_CAPI UChar32 U_EXPORT2
pub_two(int32_t c);
/** @internal */
U_CAPI int32_t U_EXPORT2 int_marked(void);
#ifndef U_HIDE_INTERNAL_API
/** @stable ICU 2.0 */
U_CAPI void U_EXPORT2 int_hidden(void);
#endif
/** @stable ICU 2.0 */
U_CAPI const uint8_t U_EXPORT2 pub_data[256];
U_CFUNC void not_capi(void);
/* U_CAPI void in_comment(void); */
/** @internal */
typedef int X;
U_CAPI void U_EXPORT2 pub_after(void);
#ifndef U_HIDE_INTERNAL_API
#else
/** @stable ICU 2.0 */
U_CAPI void U_EXPORT2 pub_else(void);
#endif
#if 1
#ifndef U_HIDE_INTERNAL_API
U_CAPI void U_EXPORT2 int_nested(void);
#endif
U_CAPI void U_EXPORT2 pub_after_nested(void);
#endif
/** @stable ICU 2.0 */
U_CAPI void U_EXPORT2 pub_fp(void (*cb)(int));
/** @internal */
U_CAPI void U_EXPORT2 int_imm(void);
/** @stable ICU 2.0 */
U_CAPI void U_EXPORT2 pub_next(void);
H
out="$(sh "$API" "$T/fx/unicode")"
a_eq "_pub_after
_pub_after_nested
_pub_data
_pub_else
_pub_fp
_pub_next
_pub_one
_pub_two" "$out" "fixture public declarations"

a_fails "empty directory" sh "$API" "$T/empty/unicode"
a_fails "no directory" sh "$API"
a_fails "missing directory" sh "$API" "$T/nope"

SRC="$(icu_build_root)/src/icu/source"
if [ ! -d "$SRC/common/unicode" ]; then
  echo "skip: extracted ICU source not under $SRC" >&2
  exit 77
fi
real="$(sh "$API" "$SRC/common/unicode" "$SRC/i18n/unicode")"
a_contains "
$real
" "
_ubrk_open
" "ubrk_open public"
a_contains "
$real
" "
_u_strlen
" "u_strlen public"
a_contains "
$real
" "
_ulistfmt_openForType
" "ulistfmt_openForType public"
a_contains "
$real
" "
_unumf_openForSkeletonAndLocale
" "unumf_openForSkeletonAndLocale public"
case "
$real
" in *"
_utf8_nextCharSafeBody
"*) a_eq absent present "utf8_nextCharSafeBody is internal" ;; *) a_eq 1 1 "utf8_nextCharSafeBody excluded" ;; esac

a_done
