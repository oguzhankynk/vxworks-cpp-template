cmake_minimum_required(VERSION 3.25)

project(hello
  VERSION 0.1.0
  DESCRIPTION "A modern C++ project template for VxWorks 7: RTP and DKM builds, tests in QEMU, and host-side quality gates"
  LANGUAGES CXX)

# PREPEND: when this project is a subproject (FetchContent, add_subdirectory),
# its own modules must win over same-named modules of the parent project.
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
find_package(Doxygen QUIET)

option(BUILD_SHARED_LIBS "Build hello as a shared library" OFF)
option(HELLO_BUILD_TESTS "Build unit tests" ${PROJECT_IS_TOP_LEVEL})
option(HELLO_BUILD_EXAMPLES "Build example programs" ${PROJECT_IS_TOP_LEVEL})
# Docs only for the top-level project: as a subproject, its "docs" targets
# would clash with the parent's.
if(PROJECT_IS_TOP_LEVEL AND DOXYGEN_FOUND)
  set(_hello_docs_default ON)
else()
  set(_hello_docs_default OFF)
endif()
option(HELLO_BUILD_DOCS "Build the Doxygen API reference ('docs' / 'docs-check' targets)" ${_hello_docs_default})
option(HELLO_ENABLE_CLANG_TIDY "Run clang-tidy on the hello target while building" OFF)
option(HELLO_ENABLE_CPPCHECK "Run cppcheck on the hello target while building" OFF)
option(HELLO_ENABLE_COVERAGE "Build hello and its tests with --coverage instrumentation" OFF)
option(HELLO_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
set(HELLO_SANITIZER "" CACHE STRING
  "Semicolon-separated sanitizers to enable, e.g. 'address;undefined' or 'thread'")

# VxWorks builds: output naming, test runner (QEMU) and HELLO_VX_RTP/DKM.
if(VXWORKS)
  include(VxWorksSupport)
endif()

include(CompilerWarnings)
include(Sanitizers)
include(Coverage)
include(ClangTidy)
include(Cppcheck)
include(Doxygen)
include(Dependencies)

add_subdirectory(src)

if(HELLO_VX_RTP AND HELLO_BUILD_TESTS)
  add_subdirectory(tools)
endif()

if(HELLO_BUILD_TESTS)
  enable_testing()
  # Kernel-module tests are plain functions called from the kernel shell; only
  # host and RTP builds use GoogleTest.
  if(NOT HELLO_VX_DKM)
    hello_fetch_test_dependencies()
  endif()
  add_subdirectory(tests)
endif()

if(HELLO_BUILD_EXAMPLES)
  add_subdirectory(examples)
endif()

if(HELLO_BUILD_DOCS)
  hello_add_doxygen_targets()
endif()

# ---------------------------------------------------------------------------
# Install / export
# ---------------------------------------------------------------------------
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS hello
  EXPORT helloTargets
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(DIRECTORY include/hello DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT helloTargets
  FILE helloTargets.cmake
  NAMESPACE hello::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/hello)

configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/helloConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/helloConfig.cmake"
  INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/hello)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/helloConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/helloConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/helloConfigVersion.cmake"
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/hello)
