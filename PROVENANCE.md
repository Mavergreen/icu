# Provenance

The build reproduces Wowfunhappy's recipe, `icu_wrapper_build.md` in
[Wowfunhappy/Mavericks-Porting-Resources](https://github.com/Wowfunhappy/Mavericks-Porting-Resources),
with three differences:

- the install name is absolute (`/usr/local/mavergreen/icu/lib/libicucore.dylib`), not `@loader_path`-relative;
- libc++ and libc++abi are linked statically and hidden, not shipped beside it with `@loader_path`;
- the exports come from an export list (`symbols.txt` is checked against it), not from whatever the link leaves visible.

`symbols.txt` is ICU's public C API, extracted from ICU's own headers. The first release was
checked once to export every non-C++ ICU symbol of Wowfunhappy's shipped `libicucoreWrapper.dylib`
(sha256 `0b664a16311d10b5d49a289779c2c962ca924a88cb08738e9902dab853bba2ea`): 1,633 names, being his
non-`__Z` exports minus the four `___sincos*` functions and their `.eh` twins, which his
legacy-support objects contributed and are not ICU's.
