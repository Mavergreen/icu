#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <CoreFoundation/CoreFoundation.h>
#include <unicode/ubrk.h>
#include <unicode/ulistformatter.h>
#include <unicode/unumberformatter.h>
#include <unicode/ustring.h>
#include <unicode/utypes.h>

static int ends_with(const char *s, const char *suffix) {
  size_t n = strlen(s), m = strlen(suffix);
  return n >= m && strcmp(s + n - m, suffix) == 0;
}

static int fail(const char *step, UErrorCode st) {
  printf("failed: %s: %s\n", step, u_errorName(st));
  return 1;
}

int main(void) {
  UErrorCode st = U_ZERO_ERROR;
  UChar text[16];
  u_uastrcpy(text, "Hello world");

  UBreakIterator *bi = ubrk_open(UBRK_WORD, "en_US", text, -1, &st);
  UBreakIterator *clone = ubrk_clone(bi, &st);
  if (U_FAILURE(st)) return fail("ubrk_open/ubrk_clone", st);
  printf("break: %d", ubrk_first(clone));
  for (int32_t b; (b = ubrk_next(clone)) != UBRK_DONE;) printf(" %d", b);
  printf("\n");
  ubrk_close(clone);
  ubrk_close(bi);

  UChar red[4], green[6], blue[5], out[64];
  u_uastrcpy(red, "red");
  u_uastrcpy(green, "green");
  u_uastrcpy(blue, "blue");
  const UChar *items[3] = { red, green, blue };
  int32_t lens[3] = { 3, 5, 4 };
  UListFormatter *lf = ulistfmt_openForType("en_US", ULISTFMT_TYPE_AND, ULISTFMT_WIDTH_WIDE, &st);
  int32_t n = ulistfmt_format(lf, items, lens, 3, out, 64, &st);
  if (U_FAILURE(st)) return fail("ulistfmt", st);
  out[n] = 0;
  char buf[128];
  u_austrcpy(buf, out);
  printf("list: %s\n", buf);
  ulistfmt_close(lf);

  static const UChar skeleton[] = { 'p','r','e','c','i','s','i','o','n','-','i','n','t','e','g','e','r', 0 };
  UNumberFormatter *nf = unumf_openForSkeletonAndLocale(skeleton, -1, "en_US", &st);
  UFormattedNumber *fn = unumf_openResult(&st);
  unumf_formatInt(nf, 1234567, fn, &st);
  n = unumf_resultToString(fn, out, 64, &st);
  if (U_FAILURE(st)) return fail("unumf", st);
  out[n] = 0;
  u_austrcpy(buf, out);
  printf("number: %s\n", buf);
  unumf_closeResult(fn);
  unumf_close(nf);

  CFMutableStringRef cf = CFStringCreateMutable(NULL, 0);
  CFStringAppendCString(cf, "stra\xC3\x9F" "e", kCFStringEncodingUTF8);
  CFStringUppercase(cf, NULL);
  CFStringGetCString(cf, buf, sizeof buf, kCFStringEncodingUTF8);
  printf("cf: %s\n", buf);
  CFRelease(cf);

  Dl_info info;
  const char *ours_path = dladdr((void *)ubrk_clone, &info) ? info.dli_fname : "";
  int ours = 0, apple = 0;
  for (uint32_t i = 0; i < _dyld_image_count(); i++) {
    const char *name = _dyld_get_image_name(i);
    if (ends_with(name, "/libicucore.dylib") && strcmp(name, ours_path) == 0) ours = 1;
    if (strcmp(name, "/usr/lib/libicucore.A.dylib") == 0) apple = 1;
  }
  printf("images: %s %s\n", ours ? "ours" : "missing", apple ? "apple" : "missing");
  return 0;
}
