#!/bin/sh
# platform: host-agnostic
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
PY="$(command -v python3 || command -v python)" || { echo "no python" >&2; exit 77; }
"$PY" - "$HERE/../.github/renovate.json" <<'PYEOF'
import json, re, sys
cfg = json.load(open(sys.argv[1]))
ms = [m for m in cfg.get("customManagers", []) if m.get("depNameTemplate") == "unicode-org/icu"]
assert len(ms) == 1, "one unicode-org/icu manager"
m = ms[0]
assert m["managerFilePatterns"] == ["/^UPSTREAM_VERSION$/"], m["managerFilePatterns"]
assert m["datasourceTemplate"] == "github-releases"
mm = re.search(m["matchStrings"][0].replace("(?<", "(?P<"), "78.2\n", re.M)
assert mm and mm.group("currentValue") == "78.2", "matchStrings captures the version"
rx = re.compile(m["extractVersionTemplate"].replace("(?<", "(?P<"))
def full(s):
    r = rx.match(s)
    return r and r.end() == len(s) and r.group("version")
for tag, ver in [("release-78.3", "78.3"), ("release-79.1", "79.1"), ("release-80.1.1", "80.1.1")]:
    assert full(tag) == ver, tag
for tag in ["release-79.1rc", "release-78.1rc", "release-77-1", "icu4x/2026-08-31/79.x", "cldr/2023-09-27"]:
    assert not full(tag), tag
cm = [m for m in cfg["customManagers"] if m.get("depNameTemplate") == "Mavergreen/clang-22"]
assert len(cm) == 1, "one Mavergreen/clang-22 manager"
cm = cm[0]
assert cm["managerFilePatterns"] == ["/^components/clang22/version$/"]
assert cm["datasourceTemplate"] == "github-releases"
vm = re.match(cm["versioningTemplate"].replace("regex:", "", 1).replace("(?<", "(?P<"), "22.1.1-mavericks.6")
assert vm and vm.group("build") == "6", "versioningTemplate captures build"
vc = re.search(cm["matchStrings"][0].replace("(?<", "(?P<"), "22.1.1-mavericks.6\n", re.M)
assert vc and vc.group("currentValue") == "22.1.1-mavericks.6"
for r in cfg.get("packageRules", []):
    assert "automerge" not in r, "packageRules must not set automerge"
print("ok")
PYEOF
