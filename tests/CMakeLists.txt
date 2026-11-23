# ---------------------------------------------------------------------------
# Kernel module (DKM) build: a self-test function, run from the kernel shell.
# ---------------------------------------------------------------------------
if(HELLO_VX_DKM)
  add_executable(hello_dkm_selftest dkm/selftest.cpp)
  target_link_libraries(hello_dkm_selftest PRIVATE hello::hello)
  hello_set_warnings(hello_dkm_selftest)

  # vxrun loads the module with `ld` and calls helloDkmSelfTest(); a zero
  # return value passes.
  add_test(NAME hello_dkm_selftest
    COMMAND ${HELLO_VXRUN} --dkm --entry helloDkmSelfTest $<TARGET_FILE:hello_dkm_selftest>)
  return()
endif()

# ---------------------------------------------------------------------------
# Host and RTP builds: GoogleTest.
# ---------------------------------------------------------------------------
include(GoogleTest)

add_executable(hello_unit_tests
  unit/test_hello.cpp
  unit/test_version.cpp
)

target_link_libraries(hello_unit_tests PRIVATE hello::hello GTest::gtest GTest::gtest_main)

hello_set_warnings(hello_unit_tests)
hello_enable_sanitizers(hello_unit_tests)
hello_enable_coverage(hello_unit_tests)
hello_apply_sanitizer_test_wrapper(hello_unit_tests)

if(HELLO_VX_RTP)
  # One ctest entry per test binary: each entry boots VxWorks once, so
  # registering every TEST() separately (gtest_discover_tests) would boot it
  # once per test case. GoogleTest's own output lists each case.
  add_test(NAME hello_unit_tests COMMAND hello_unit_tests)
else()
  gtest_discover_tests(hello_unit_tests)
endif()

hello_add_coverage_target()
if(TARGET coverage)
  # The 'coverage' custom target has no implicit dependency on the test
  # binaries; without this, a clean build runs ctest before
  # hello_unit_tests exists and every test reports NOT_BUILT.
  add_dependencies(coverage hello_unit_tests)
endif()
