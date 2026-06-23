# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This repository (`alibain`) is in its initial stage. It contains **no application source or root build system yet** — the only substantive content is the [libarchive](https://github.com/libarchive/libarchive) library vendored as a git submodule under `libarchive/` (pinned to `v3.7.5-1118-gca1e27dd`).

The `.gitignore` is set up for a C/C++ project built with **CMake** (it ignores `build/`, `CMakeFiles/`, MSVC artifacts like `*.pdb`/`*.ilk`, and also has a `vcpkg_installed/` entry). New code added here is expected to follow a CMake toolchain. Note: alibain itself has no dependency-management tooling wired up yet — the `vcpkg_installed/` ignore line is just a placeholder, not an active setup (see below).

## Submodule setup

`libarchive/` is a submodule and is empty after a plain `git clone`. Before building anything, initialize it:

```sh
git submodule update --init --recursive
```

When cloning fresh, use `git clone --recursive <url>` to pull it in one step.

## Building libarchive (reference)

libarchive has its own CMake build under `libarchive/`. On this Windows host, a typical out-of-source build:

```sh
cmake -S libarchive -B libarchive/build
cmake --build libarchive/build --config Release
```

Run its test suite (CTest) after building:

```sh
ctest --test-dir libarchive/build -C Release
# single test by name:
ctest --test-dir libarchive/build -C Release -R <test_name>
```

libarchive can also be built with autotools on POSIX (`cd libarchive && ./build/autogen.sh && ./configure && make`), but CMake is the path that matches this repo's `.gitignore` and Windows environment.

### Optional compression dependencies (vcpkg)

libarchive's core (tar/cpio containers, the read/write API) builds with no external dependencies. Its compression *filters* each need a backing library, and CMake auto-detects whichever are present — missing ones are simply compiled out. The libraries are: `zlib` (gzip/zip deflate), `bzip2`, `liblzma` (xz/lzma), and `zstd`.

The only vcpkg usage in this repo is libarchive's own Windows CI manifest, `libarchive/build/ci/github_actions/vcpkg.json`, which fetches exactly those four libraries before building (on Windows they aren't system packages). If you want those filters enabled in a local Windows build, install the same packages via vcpkg and point CMake at the vcpkg toolchain file; otherwise libarchive still builds with reduced format/filter support.

## libarchive architecture (the submodule)

When working inside `libarchive/`, the layout matters because the codebase is large but highly regular:

- `libarchive/libarchive/` — the core library. The public API is `archive.h` and `archive_entry.h`. Internals are split into orthogonal, pluggable modules whose filenames encode their role:
  - `archive_read_support_format_*.c` / `archive_write_set_format_*.c` — container formats (tar, zip, 7zip, iso9660, cpio, mtree, …).
  - `archive_read_support_filter_*.c` / `archive_write_add_filter_*.c` — compression/encoding filters (gzip, bzip2, xz, lz4, zstd, …) layered independently of the format.
  - Reading and writing are symmetric: most features exist as a matched read/write pair.
- `libarchive/tar/`, `cpio/`, `cat/`, `unzip/` — the command-line front-ends (bsdtar, bsdcpio, bsdcat, bsdunzip) built on top of the library.
- `libarchive/libarchive_fe/` — shared front-end helper code.
- `libarchive/test_utils/` and each component's `test/` directory — the test harness; tests are typically self-contained C files registered with the build.
- `libarchive/examples/` — small standalone programs demonstrating the API; the clearest entry point for understanding usage.

To add support for a new format or filter inside libarchive, add the matching `archive_read_support_*` / `archive_write_*` source, register it in `CMakeLists.txt` and the autotools `Makefile.am`, and add a paired test.
