# Build ingredients

Everything baked into what ICU for Mavericks ships, and how a change to it reaches a release.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| ICU source (own upstream; its public headers ship too, under `include/unicode`) | `UPSTREAM_VERSION` | ✅ `github-releases` on `unicode-org/icu` | a push to main cuts `-mavericks.1` |
| MacOSX10.9 SDK, CMake modules, compat guard, packaging and signing scripts | `Mavergreen/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` moves without the pin changing, so nothing repackages by itself |
| clang22 toolchain (builds libicucore.dylib and the updater) | `components/clang22/version`, plus the Linux archive's digest in `components/clang22/linux-sha256` | ✅ `github-releases` on `Mavergreen/clang-22`, `-mavericks.N` versioning; the pins bot (`.github/workflows/pins-bot.yml`) verifies the new release's Linux archive against its `SHA256SUMS` and writes `linux-sha256` on Renovate's branch | a bump repackages: libc++ is linked into the dylib |
| Sparkle, in the updater | shipyard's `fetch_sparkle_framework.sh`, pinned by hash there | ❌ untrackable here: shipyard owns that pin | follows shipyard |
| Linux host make, C and C++ compilers, and CMake (run ICU's build, compile ICU's host tools, which generate its data, and configure and build the updater, on Linux; a Mac's builds use the make on `PATH`, and a modern Mac's host tools use Apple's clang) | runner-provided, unpinned; build-info records each `--version` (`build-make`, `build-host-cc`, `build-host-cxx`, `updater-cmake`, `updater-build-tool`) | ❌ untrackable here: the runner image provides them, so no pin exists to track. Exit: a pinned toolchain on Linux hosts (shipyard QUEUE) | none; a runner image update can change them |
| `symbols.txt` | committed | ❌ untrackable: changed only by deliberate commits | never bumped by a bot; a change is its own commit saying why |

## Declared state

- upstream: UPSTREAM_VERSION
- clang22: components/clang22/version

## Build

ICU is configured as a cross build for `x86_64-apple-darwin13` and compiled by clang22 against MacOSX10.9.sdk:
on Linux its host tools are built first for Linux with the host compiler (`runConfigureICU Linux`), on a modern
Mac with Apple's clang, and nothing the target build makes is run on the build host. On 10.9 the same recipe
builds natively, with no host stage. The updater is configured by the host's `cmake` on Linux and
`shipyard-cmake` on a Mac, and compiled by clang22 for x86_64 10.9. Packaging runs on shipyard's stevedore
seams, so CI builds, tests, packages and signs on Linux.

## Running what ships

Nothing shipped runs on the Linux build host. The `vm-test` job boots Mac OS X 10.9.5 with
`Mavergreen/mavericks-vm`, installs the built pkg, runs `tests/on-target.sh` (the smoke program the build job
compiled, against the installed dylib) and launches the updater check-only. Publishing waits for it.

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
