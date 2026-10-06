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

- rosetta:tests/smoke-test.sh: compiles `tests/smoke/icu-smoke.c` and executes it against the shipped x86_64 `libicucore.dylib`, which the arm64 CI runner can only do translated by Rosetta; it cannot run natively there. CI runs it, it is not skipped; native 10.9 runs it natively. Reconsider when it can move to an x86_64 host (the 10.9 box or the Mavericks VM runner), at the latest before macOS 28 removes Rosetta.
- rosetta:.github/workflows/release.yml: the release job runs on an Apple Silicon (arm64) runner and primes Rosetta ("Ensure this runner can run x86_64 (Rosetta)") so `tests/smoke-test.sh` can execute the shipped x86_64 `libicucore.dylib` before it ships. It cannot run natively there. The build itself runs before the prime and nothing in it is translated, which `tests/rosetta-free-test.sh` checks. CI runs it, it is not skipped; native 10.9 runs it natively. Reconsider when it can move to an x86_64 host (the 10.9 box or the Mavericks VM runner), at the latest before macOS 28 removes Rosetta.

## Link notes

The dylib links with no legacy-support archive: the compat guard is clean on the linked library without one, so the link needs neither that archive nor any extra load-command flag (lld writes `LC_VERSION_MIN_MACOSX` for a 10.9 target on its own).

## Releasing

A merged `UPSTREAM_VERSION` bump releases itself: the push to `main` cuts `-mavericks.1`.

A packaging-only release of the same source (a new `.N`):

    gh workflow run release.yml -R Mavergreen/icu --ref main -f local_release=true

A `symbols.txt` failure on a Renovate PR means upstream removed a public C function. Decide whether that is acceptable, and change `symbols.txt` by a commit saying why.

`symbols.txt` is read from the headers the package ships (ICU's own `install-headers` output, `include/unicode` beside the built dylib). To regenerate it after a build:

    sh build/public-api.sh "$(MAVERICKS_ROOT="$PWD" sh -c '. build/lib.sh; icu_build_root')/out/include/unicode" > symbols.txt

This works even after a `check-symbols` failure, because the headers are installed before that check runs.
