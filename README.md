# ICU for Mavericks

Modern [ICU](https://icu.unicode.org/) for Mac OS X 10.9 Mavericks.

Programs built for newer macOS often need these updated Unicode text functions to handle word breaks, list and number formatting, collation, etc.

## How to use

Given source code:

```sh
cc -I/usr/local/mavergreen/icu/include \
   myprogram.c /usr/local/mavergreen/icu/lib/libicucore.dylib
```

Given a binary, relink it with [drydock-macho-rewrite](https://github.com/Mavergreen/drydock):

```
dylib  replace  /usr/lib/libicucore.A.dylib  /usr/local/mavergreen/icu/lib/libicucore.dylib
```

Exported names are Apple's unversioned ones (`ubrk_open`, not `ubrk_open_78`), covering all of ICU's C functions.
The headers also declare ICU's C++ API, but only its C functions are exported, so C++ code must stick to the C API.

Sometimes a program linked with this library will also end up loading Apple's `/usr/lib/libicucore.A.dylib` via a system framework such as CoreFoundation.
This is fine.
Each caller uses the library it was linked with.
