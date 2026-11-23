#!/usr/bin/env bash
# Runs every quality gate this template defines, in the same order CI does,
# stopping at the first failure. Run from anywhere; paths are resolved
# relative to this script's location.
#
#   scripts/run_checks.sh                 host gates only
#   scripts/run_checks.sh --vxworks       host gates, then every VxWorks preset
#   scripts/run_checks.sh --vxworks-only  VxWorks presets only
#
# The VxWorks presets need WIND_HOME (the VxWorks SDK directory) and QEMU.
set -euo pipefail

RUN_HOST=1
RUN_VXWORKS=0
case "${1:-}" in
  "") ;;
  --vxworks) RUN_VXWORKS=1 ;;
  --vxworks-only) RUN_HOST=0; RUN_VXWORKS=1 ;;
  *) echo "usage: $0 [--vxworks | --vxworks-only]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

step() {
  echo
  echo "==> $*"
}

run_vxworks_presets() {
  if [[ -z "${WIND_HOME:-}" ]]; then
    echo "WIND_HOME is not set; point it at the VxWorks SDK directory." >&2
    exit 1
  fi
  local preset
  for preset in vx-rtp-debug vx-rtp-release vx-rtp-shared vx-rtp-ubsan vx-dkm; do
    step "VxWorks (preset: ${preset})"
    cmake --preset "${preset}"
    cmake --build --preset "${preset}"
    ctest --preset "${preset}"
  done
}

if [[ "${RUN_HOST}" == 0 ]]; then
  run_vxworks_presets
  echo
  echo "All VxWorks checks passed."
  exit 0
fi

step "clang-format --dry-run"
mapfile -t sources < <(git ls-files '*.hpp' '*.cpp')
clang-format --dry-run --Werror "${sources[@]}"

step "clang-tidy (preset: tidy)"
cmake --preset tidy
cmake --build --preset tidy

step "cppcheck (preset: cppcheck)"
cmake --preset cppcheck
cmake --build --preset cppcheck

step "Doxygen documentation coverage (preset: debug)"
cmake --preset debug
cmake --build --preset debug --target docs-check

step "Unit tests (preset: debug)"
cmake --build --preset debug
ctest --preset debug

step "AddressSanitizer + UndefinedBehaviorSanitizer (preset: asan)"
cmake --preset asan
cmake --build --preset asan
ctest --preset asan

step "ThreadSanitizer (preset: tsan)"
cmake --preset tsan
cmake --build --preset tsan
ctest --preset tsan

step "Coverage (preset: coverage)"
cmake --preset coverage
cmake --build --preset coverage --target coverage

step "Install + find_package(hello)"
cmake --preset release
cmake --build --preset release

INSTALL_PREFIX="$(mktemp -d)"
CONSUMER_DIR="$(mktemp -d)"
trap 'rm -rf "${INSTALL_PREFIX}" "${CONSUMER_DIR}"' EXIT

cmake --install build/release --prefix "${INSTALL_PREFIX}"

cat > "${CONSUMER_DIR}/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.25)
project(hello_install_check LANGUAGES CXX)
find_package(hello CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE hello::hello)
EOF
cat > "${CONSUMER_DIR}/main.cpp" <<'EOF'
#include <hello/hello.hpp>
#include <hello/version.hpp>
int main() { return hello::version() != nullptr ? 0 : 1; }
EOF

cmake -S "${CONSUMER_DIR}" -B "${CONSUMER_DIR}/build" -G Ninja \
  -DCMAKE_PREFIX_PATH="${INSTALL_PREFIX}"
cmake --build "${CONSUMER_DIR}/build"
"${CONSUMER_DIR}/build/consumer"

if [[ "${RUN_VXWORKS}" == 1 ]]; then
  run_vxworks_presets
fi

echo
echo "All checks passed."
