// Kernel-module self-test for the hello library.
//
// GoogleTest needs a process to run in, so the DKM build tests the library
// with a plain function instead. Call it from the kernel shell after loading
// the module:
//
//   -> ld < hello_dkm_selftest.out
//   -> helloDkmSelfTest
//   value = 0 = 0x0          (0 = every check passed)
//
// ctest does the same through tools/vxrun/vxrun.py --dkm.

#include "hello/hello.hpp"
#include "hello/version.hpp"

#include <cstdio>
#include <cstring>
#include <string>

namespace {

int failures = 0;

void check(bool ok, const char* what) {
  std::printf("[%s] %s\n", ok ? "  OK  " : " FAIL ", what);
  if (!ok) {
    ++failures;
  }
}

// Runs once when the module is loaded; proves static constructors run in a DKM.
struct LoadMarker {
  LoadMarker() noexcept : loaded(true) {}
  bool loaded;
};
const LoadMarker load_marker;

}  // namespace

extern "C" int helloDkmSelfTest() {
  failures = 0;
  check(load_marker.loaded, "static constructors ran at load time");
  check(hello::greeting("Ada") == "Hello, Ada!", "greeting(\"Ada\")");
  check(hello::greeting("") == "Hello, World!", "greeting(\"\") greets the world");
  check(hello::version() != nullptr && std::strlen(hello::version()) > 0, "version() is not empty");
  std::printf("%d check(s) failed\n", failures);
  return failures;
}
