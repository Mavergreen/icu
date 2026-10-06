#!/bin/sh
# platform: host-agnostic
set -eu

[ $# -ge 1 ] || { echo "usage: public-api.sh HEADER_DIR..." >&2; exit 2; }

all=""
for d in "$@"; do
  [ -d "$d" ] || { echo "public-api: $d is not a directory" >&2; exit 1; }
  found=""
  for h in "$d"/*.h; do
    [ -e "$h" ] && found=1
  done
  [ -n "$found" ] || { echo "public-api: no .h files in $d" >&2; exit 1; }
  part="$(awk '
    function lastident(s,   t) {
      if (match(s, /[A-Za-z_][A-Za-z0-9_]*[^A-Za-z0-9_]*$/) == 0) return ""
      t = substr(s, RSTART)
      sub(/[^A-Za-z0-9_]+$/, "", t)
      return t
    }
    function emit(text,   p, q, head, name) {
      p = index(text, "(")
      if (p > 0) head = substr(text, 1, p - 1)
      else {
        head = text
        q = index(head, ";"); if (q > 0) head = substr(head, 1, q - 1)
        q = index(head, "["); if (q > 0) head = substr(head, 1, q - 1)
        q = index(head, "="); if (q > 0) head = substr(head, 1, q - 1)
      }
      name = lastident(head)
      if (name != "" && !internal && hide == 0) print "_" name
    }
    function pp(line,   w) {
      sub(/^#[ \t]*/, "", line)
      w = line; sub(/[^A-Za-z].*$/, "", w)
      if (w == "if" || w == "ifdef" || w == "ifndef") {
        depth++
        hid[depth] = (w == "ifndef" && line ~ /^ifndef[ \t]+U_HIDE_INTERNAL_API([^A-Za-z0-9_]|$)/) ? 1 : 0
        if (hid[depth]) hide++
      } else if (w == "else" || w == "elif") {
        if (depth > 0 && hid[depth]) { hid[depth] = 0; hide-- }
      } else if (w == "endif") {
        if (depth > 0) { if (hid[depth]) hide--; depth-- }
      }
    }
    FNR == 1 { depth = 0; hide = 0; internal = 0; incom = 0; indecl = 0; ppcont = 0; decl = "" }
    {
      rem = $0; code = ""
      while (rem != "") {
        if (incom) {
          e = index(rem, "*/")
          if (e == 0) { cbuf = cbuf " " rem; rem = "" }
          else {
            cbuf = cbuf " " substr(rem, 1, e - 1); rem = substr(rem, e + 2); incom = 0
            if (isdoc) internal = (index(cbuf, "@internal") > 0) ? 1 : 0
          }
        } else {
          s = index(rem, "/*"); l = index(rem, "//")
          if (l > 0 && (s == 0 || l < s)) { code = code substr(rem, 1, l - 1); rem = "" }
          else if (s > 0) {
            code = code substr(rem, 1, s - 1) " "
            isdoc = (substr(rem, s, 3) == "/**" && substr(rem, s, 4) != "/**/") ? 1 : 0
            rem = substr(rem, s + 2); incom = 1; cbuf = ""
          } else { code = code rem; rem = "" }
        }
      }
      sub(/^[ \t]+/, "", code); sub(/[ \t\r]+$/, "", code)
      if (code == "") next
      if (ppcont || substr(code, 1, 1) == "#") {
        ppcont = (code ~ /\\$/) ? 1 : 0
        if (substr(code, 1, 1) == "#" && !indecl) pp(code)
        next
      }
      if (indecl) { decl = decl " " code }
      else if (code ~ /^U_CAPI([^A-Za-z0-9_]|$)/) { indecl = 1; decl = code }
      else { internal = 0; next }
      if (index(decl, "(") > 0 || index(decl, ";") > 0) { emit(decl); indecl = 0; decl = ""; internal = 0 }
    }
  ' "$d"/*.h)" || exit 1
  all="$all
$part"
done

out="$(printf '%s\n' "$all" | awk 'NF' | LC_ALL=C sort -u)"
[ -n "$out" ] || { echo "public-api: no public U_CAPI declarations found" >&2; exit 1; }
printf '%s\n' "$out"
