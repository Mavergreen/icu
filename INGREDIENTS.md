# Build ingredients

Everything baked into what ICU for Mavericks ships, and how a change to it reaches a release.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| ICU source (own upstream; its public headers ship too, under `include/unicode`) | `UPSTREAM_VERSION` | ✅ `github-releases` on `unicode-org/icu` | a push to main cuts `-mavericks.1` |
| MacOSX10.9 SDK, CMake modules, compat guard, packaging and signing scripts | `Mavergreen/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` moves without the pin changing, so nothing repackages by itself |
| clang22 toolchain (builds libicucore.dylib) | `components/clang22/version` | ✅ `github-releases` on `Mavergreen/clang-22`, `-mavericks.N` versioning | a bump repackages: libc++/libc++abi are linked into the dylib |
| Sparkle, in the updater | shipyard's `fetch_sparkle_framework.sh`, pinned by hash there | ❌ untrackable here: shipyard owns that pin | follows shipyard |
| `symbols.txt` | committed | ❌ untrackable: changed only by deliberate commits | never bumped by a bot; a change is its own commit saying why |

## Declared state

- upstream: UPSTREAM_VERSION
- clang22: components/clang22/version

## Conformance deviations
