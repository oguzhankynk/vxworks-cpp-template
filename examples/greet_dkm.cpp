// Kernel module (DKM) example: exposes the hello library to the kernel shell.
//
//   -> ld < greet_dkm.out
//   -> helloGreet "Ada"
//   Hello, Ada!
//   value = 0 = 0x0

#include "hello/hello.hpp"

#include <cstdio>
#include <string>

/// @brief Prints a greeting for `name` on the console.
/// @param name The name to greet; NULL or "" greets the world.
/// @return Always 0, so the kernel shell prints `value = 0`.
extern "C" int helloGreet(const char* name) {
  const std::string greeting = hello::greeting(name != nullptr ? name : "");
  std::printf("%s\n", greeting.c_str());
  return 0;
}
