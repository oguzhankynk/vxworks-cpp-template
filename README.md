# vxworks-cpp-template

**A modern C++17 CMake project template for [VxWorks 7](https://www.windriver.com/products/vxworks),
Wind River's real-time operating system, with unit tests that run on VxWorks.**

The same code builds for VxWorks in both of its execution models:

- **VxWorks RTP** (Real Time Process, `.vxe`): user-space applications with
  their own memory protection;
- **VxWorks DKM** (Downloadable Kernel Module, `.out`): code loaded into the
  VxWorks kernel at run time.

`ctest` runs the tests **on VxWorks**: it boots the VxWorks kernel in QEMU,
runs each test binary in an RTP or loads it as a kernel module, and reports
the result like any native test. You need neither a board nor Workbench, and
no FTP server or root access either. All you need is the free
[VxWorks SDK](https://forums.windriver.com/t/vxworks-software-development-kit-sdk/43)
and QEMU.

The library also builds as a host program, so the usual host gates run on
the same code: sanitizers, coverage, clang-tidy, cppcheck and Doxygen.

```
$ ctest --preset vx-rtp-debug
1/1 Test #1: hello_unit_tests .................   Passed    4.73 sec
100% tests passed, 0 tests failed out of 1
```

It is the VxWorks counterpart of
[cpp-project-template](https://github.com/oguzhankynk/cpp-project-template):
the layout, the presets and the quality gates are the same, with VxWorks
targets added.

## What's wired up

| | VxWorks presets | Host presets |
|---|---|---|
| Build | `vx-rtp-debug`, `vx-rtp-release`, `vx-rtp-shared`, `vx-dkm` | `debug`, `release` |
| Unit tests | GoogleTest suite, run on VxWorks in QEMU | the same suite, one ctest entry per `TEST()` |
| Kernel module test | `helloDkmSelfTest()`, loaded with `ld` and called from the VxWorks kernel shell | - |
| Sanitizers | `vx-rtp-ubsan` (UBSan, trap mode) | `asan` (ASan + UBSan), `tsan` |
| Coverage, clang-tidy, cppcheck, Doxygen | run on the host build | `coverage`, `tidy`, `cppcheck`, `docs` targets |
| Install + `find_package(hello)` | yes (`cmake --install` into a staging prefix) | yes |
| CI (GitHub Actions) | optional self-hosted runner with the SDK | every push |

Other pieces:

- **`cmake/toolchains/vxworks.cmake`**: one toolchain file for both the VxWorks
  SDK and a full VxWorks installation (see [Using a full VxWorks
  installation](#using-a-full-vxworks-installation)).
- **`tools/vxrun/vxrun.py`**: boots VxWorks in QEMU, runs one program or kernel
  module and exits with its status. ctest uses it as the
  `CMAKE_CROSSCOMPILING_EMULATOR`, and you can also run it by hand. It uses the
  Python standard library only.
- **`tools/vxrun/launcher.c`**: a small RTP that runs the program under test
  and reports its exit code or the signal that killed it. The VxWorks shell
  does not give the exit status of a process it launches.

## Requirements

- **The VxWorks SDK for QEMU (x86-64)**, free for non-commercial use. Download
  it from the
  [VxWorks SDK thread on the Wind River forums](https://forums.windriver.com/t/vxworks-software-development-kit-sdk/43)
  (the template is tested with release 26.09, `wrsdk-vxworks7-qemu-1.18.0`) and
  unpack it anywhere.
- CMake ≥ 3.25, Ninja, Python 3, `qemu-system-x86_64`
  (Debian/Ubuntu: `sudo apt install cmake ninja-build python3 qemu-system-x86`).
- For the host presets: GCC or Clang, plus clang-tidy, cppcheck, gcovr and
  Doxygen for the matching gates.

You do not need to source the SDK's `sdkenv.sh`: the toolchain file finds the
compiler from `WIND_HOME`. (`sdkenv.sh` also refuses to run when `/bin/sh` is
dash, which is the default on Ubuntu.)

## Quick start

Tell CMake where the SDK is, either in the shell:

```sh
export WIND_HOME=/opt/wrsdk-vxworks7-qemu-1.18.0
cmake --preset vx-rtp-debug
cmake --build --preset vx-rtp-debug
ctest --preset vx-rtp-debug
```

or once, in a `CMakeUserPresets.json` that git ignores:

```sh
cp CMakeUserPresets.json.example CMakeUserPresets.json   # then edit WIND_HOME in it
cmake --preset my-vx-rtp-debug
cmake --build --preset my-vx-rtp-debug
ctest --preset my-vx-rtp-debug
```

The `my-*` presets in the example inherit the project presets and only add
`WIND_HOME`.

Host builds need nothing VxWorks-specific:

```sh
cmake --preset debug && cmake --build --preset debug && ctest --preset debug
```

## Presets

| Preset | Builds | Notes |
|---|---|---|
| `debug`, `release` | host | |
| `asan`, `tsan`, `coverage`, `tidy`, `cppcheck` | host | the quality gates |
| `vx-rtp-debug`, `vx-rtp-release` | RTP | statically linked `.vxe` files |
| `vx-rtp-shared` | RTP | `libhello.so` plus dynamically linked programs |
| `vx-rtp-ubsan` | RTP | UBSan in trap mode, see [Sanitizers](#sanitizers-on-vxworks) |
| `vx-dkm` | DKM | `.out` kernel modules; GoogleTest is not used |

Each VxWorks test boots its own VxWorks instance (a few seconds, about 2 GB of
guest memory), so the VxWorks test presets run two tests at a time.

## Running things by hand

The build produces ordinary VxWorks binaries:

```
build/vx-rtp-debug/examples/greet_cli.vxe       RTP example
build/vx-rtp-debug/tests/hello_unit_tests.vxe   GoogleTest suite
build/vx-dkm/examples/greet_dkm.out             kernel module example (helloGreet "name")
build/vx-dkm/tests/hello_dkm_selftest.out       kernel module self-test
```

`vxrun` runs any of them in QEMU:

```sh
B=build/vx-rtp-debug
python3 tools/vxrun/vxrun.py --launcher $B/tools/vxrun_launcher.vxe $B/examples/greet_cli.vxe Ada
# Hello, Ada!

python3 tools/vxrun/vxrun.py --dkm --entry helloDkmSelfTest build/vx-dkm/tests/hello_dkm_selftest.out
```

`vxrun --help` lists every option. `-v` echoes the whole VxWorks console.
Exit status: the program's own status, 128+N if signal N killed it, 124 on a
timeout, and 125 if vxrun itself failed (QEMU or the kernel is missing, or
VxWorks did not boot).

To try things interactively, boot the SDK kernel the way the SDK's README
describes, with `-m 2048M`.

## How the tests run on VxWorks

1. ctest runs `vxrun.py <options> -- hello_unit_tests.vxe`. CMake adds the
   `vxrun` prefix because `CMAKE_CROSSCOMPILING_EMULATOR` is set in
   `cmake/VxWorksSupport.cmake`.
2. vxrun copies the program, the launcher and any shared libraries into a
   temporary directory. QEMU exposes that directory to VxWorks as a FAT disk
   (`-drive file=fat:<dir>`), and VxWorks mounts it as `/ata0a`. `-snapshot`
   keeps the directory unchanged.
3. vxrun waits for the kernel shell, switches to the `cmd` shell and runs
   `vxrun_launcher.vxe /ata0a/hello_unit_tests.vxe`.
4. It streams the program's output and reads the launcher's last line
   (`VXRUN-EXIT code=0`, or `signal=4`), then stops QEMU and exits with that
   status.

For a kernel module, vxrun runs `ld < module.out` in the kernel shell instead
and then calls the entry function. A module with undefined symbols fails the
test, and so does a non-zero return value.

With the SDK kernel a test takes about 5 seconds, almost all of it boot time.
This is why each test binary is one ctest entry: registering every `TEST()`
separately would boot VxWorks once per test case. GoogleTest's own output still
lists each case.

## Sanitizers on VxWorks

The SDK's compiler rejects `-fsanitize=address` and `-fsanitize=thread`, and
the SDK ships no sanitizer runtime. UndefinedBehaviorSanitizer still works in
**trap mode** (`-fsanitize=undefined -fsanitize-trap=undefined`): a failed
check runs an illegal instruction, VxWorks deletes the RTP with SIGILL, and
the test fails:

```
[ RUN      ] Negative.UndefinedShift
... RTP 0xffff800006a26000 has been deleted due to signal 4.
vxrun: hello_unit_tests.vxe was killed by SIGILL
```

Notes:

- VxWorks compiles with `-fwrapv`, so signed integer overflow is defined
  behaviour there and UBSan does not report it.
- A full VxWorks installation offers more: an RTP AddressSanitizer layer and
  KASAN for the kernel. Both need a VSB/VIP rebuild, which the SDK cannot do.
- For memory errors in the library code itself, run the host `asan` and
  `tsan` presets: it is the same code.

## Using a full VxWorks installation

The toolchain file is not tied to the SDK. It looks for the sysroot in this
order: `-DVXWORKS_SYSROOT`, then `$WIND_CC_SYSROOT`, then
`$WIND_HOME/vxsdk/sysroot` (the SDK layout). It looks for `wr-cc` in the SDK
first, then on `PATH`. With a full installation:

```sh
# in a wrenv shell (WIND_HOME set, wr-cc on PATH)
export WIND_CC_SYSROOT=/path/to/your/VSB
cmake -G Ninja -B build/vx -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/vxworks.cmake \
  -DVX_TARGET_TYPE=RTP \
  -DHELLO_VX_KERNEL=/path/to/your/VIP/default/vxWorks \
  "-DHELLO_VXRUN_OPTIONS=--machine;q35;--cpu;Broadwell-noTSX;--disk-if;nvme;--no-bootline;--no-network"
cmake --build build/vx && ctest --test-dir build/vx
```

`HELLO_VXRUN_OPTIONS` tells vxrun how to start your kernel in QEMU (see
`vxrun.py --help`). The kernel must include:

- RTP support and the `cmd` shell;
- a disk driver for the interface you choose (ATA or NVMe) and dosFs;
- for kernel modules: the loader, the symbol table and, for C++ modules, the
  C++ standard library components. Without the last one, loading fails with
  `undefined symbol _ZSt11_Xbad_allocv` and similar errors.

Static RTPs (the default) need no shared C library on the target.

## Consuming the installed library from another VxWorks project

`cmake --install build/vx-rtp-release --prefix <stage>` installs `libhello.a`,
the headers and the CMake package. The toolchain only searches the sysroot for
packages, so also add the staging prefix to `CMAKE_FIND_ROOT_PATH`:

```sh
cmake -G Ninja -B build -DCMAKE_TOOLCHAIN_FILE=<template>/cmake/toolchains/vxworks.cmake \
  -DCMAKE_PREFIX_PATH=<stage> -DCMAKE_FIND_ROOT_PATH=<stage>
```

## Repository layout

```
include/hello/        public headers
src/                  library implementation
tests/unit/           GoogleTest suite (host and RTP)
tests/dkm/            kernel-module self-test
examples/             greet_cli (host/RTP) and greet_dkm (DKM)
cmake/                helper modules (warnings, sanitizers, coverage, VxWorks support, ...)
cmake/toolchains/     VxWorks toolchain file and its CMake platform module
tools/vxrun/          QEMU test runner and its target-side launcher
scripts/              run_checks.sh
docs/                 Doxygen input
```

## Using this as a template

The `hello` library, `greet_cli` and `greet_dkm` are sample code. To start a
real project:

1. Replace `src/`, `include/hello/`, `tests/unit/` and `tests/dkm/` with your
   code.
2. Rename the project: the `project()` name, the targets, the `hello_*` CMake
   helpers, the `HELLO_*` options, the include directory and the namespace.
3. Keep `cmake/toolchains/`, `cmake/VxWorksSupport.cmake` and `tools/vxrun/`
   as they are. Any new `add_test(COMMAND <target>)` in an RTP build runs in
   QEMU automatically.

`scripts/run_checks.sh` runs every host gate. `scripts/run_checks.sh --vxworks`
also builds and tests every VxWorks preset (it needs `WIND_HOME`).

## Licensing notes

This repository contains no Wind River files: no headers, libraries, examples,
toolchain files or kernel images. You need your own copy of the VxWorks SDK,
under Wind River's license (the SDK's `NCLA.txt`), or a VxWorks installation.
VxWorks and Wind River are trademarks of Wind River Systems, Inc. This project
is not affiliated with or endorsed by Wind River.

The template's own code is MIT-licensed: see [LICENSE](LICENSE).
