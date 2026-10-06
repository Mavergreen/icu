# ICU for Mavericks

**This README has not been read or edited by a human yet.** Until it has, this project cannot cut its first release.

Upstream [ICU](https://icu.unicode.org/), built for Mac OS X 10.9 as one `libicucore.dylib` that exports Apple's unversioned C API names (ICU is built with `--disable-renaming`). It is for binaries that [drydock](https://github.com/Mavergreen/drydock) adapts to link it. It does not replace `/usr/lib/libicucore.A.dylib`, which stays as it is.

## Install

The `.pkg` installs `/usr/local/mavergreen/icu/lib/libicucore.dylib` (install name the same path, version 76.1, depending only on `/usr/lib/libSystem.B.dylib`) and ICU's `LICENSE` at `/usr/local/mavergreen/icu/share/doc/icu/LICENSE`. It also installs an updater app and a per-user LaunchAgent (`dev.mavergreen.icu-updatecheck`).

## How to build

    sh build/build.sh

This builds ICU and links the dylib, then prints its path on stdout. Set `ICU_MODE=native` (on Mac OS X 10.9) or `ICU_MODE=cross`; `MAVERICKS_BUILD_ROOT` optionally moves the build root. Output goes under `$TMPDIR/mm-build/<checkout>-icu-<mode>/out/`.

Cross mode needs an Apple Silicon Mac: it uses `pkgutil` and the arm64-only clang22-cross toolchain. It does not run on Linux or on an Intel Mac.

ICU's build needs GNU make. On 10.9 that comes from the Command Line Tools, which provide it as `/usr/bin/make`; run that one. This is a declared exception to "no Command Line Tools needed", until the Mavergreen/gmake follow-up ships a family GNU make.

The updater and the package go through CMake and the packaging script:

    shipyard-cmake -DICU_BUILD_UPDATER=ON ...
    sh packaging/build-pkg.sh ...

## Disclaimer

This is an unofficial community build. It is not affiliated with or endorsed by the Unicode Consortium.
