# ICU for Mavericks

**This README has not been read or edited by a human yet.** Until it has, this project cannot cut its first release.

Upstream [ICU](https://icu.unicode.org/), built for Mac OS X 10.9 as one `libicucore.dylib` that exports Apple's unversioned C API names (ICU is built with `--disable-renaming`). It is for binaries that [drydock](https://github.com/Mavergreen/drydock) adapts to link it. It does not replace `/usr/lib/libicucore.A.dylib`, which stays as it is.

## Install

The `.pkg` installs `/usr/local/mavergreen/icu/lib/libicucore.dylib` (install name the same path, version 76.1, depending only on `/usr/lib/libSystem.B.dylib`) and ICU's `LICENSE` beside it.

## How to build

Cross (any recent Mac, or Linux with the shipyard toolchain):

    shipyard-cmake --preset cross && shipyard-cmake --build --preset cross

Native (Mac OS X 10.9):

    shipyard-cmake --preset native && shipyard-cmake --build --preset native

ICU's build needs GNU make. On 10.9 that comes from the Command Line Tools, which provide it as `/usr/bin/make`; run that one. This is a declared exception to "no Command Line Tools needed", until the Mavergreen/gmake follow-up ships a family GNU make. Builds go out of tree, under `$MAVERICKS_BUILD_ROOT` or `$TMPDIR/mm-build`.

## Disclaimer

This is an unofficial community build. It is not affiliated with or endorsed by the Unicode Consortium.
