# Repository Guidelines

## Project Structure & Module Organization

This repository is a small wrapper around the `libarchive` Git submodule. Root-level files hold repository metadata: `README.md`, `COPYING`, and `.gitmodules`. The implementation lives in `libarchive/`:

- `libarchive/libarchive/` contains the core C library and public headers.
- `libarchive/tar/`, `libarchive/cpio/`, `libarchive/cat/`, and `libarchive/unzip/` contain command-line front ends.
- Component tests live beside each component, such as `libarchive/libarchive/test/` and `libarchive/tar/test/`.
- `libarchive/doc/` contains contributor docs; `libarchive/examples/` contains sample programs.

After cloning, initialize the submodule with `git submodule update --init --recursive`.

## Build, Test, and Development Commands

Run commands from the repository root unless noted:

- `cmake -S libarchive -B build -DENABLE_TEST=ON` configures a local CMake build with tests enabled.
- `cmake --build build` builds the library, tools, and test binaries.
- `ctest --test-dir build --output-on-failure` runs the registered CTest suite.
- `.\build\bin\libarchive_test.exe` runs the core library tests directly on Windows; use `./build/bin/libarchive_test` on Unix-like systems.
- From `libarchive/`, `./configure && make` is the upstream autotools path.

Keep generated output in ignored build directories such as `build/` or `build-*`.

## Coding Style & Naming Conventions

Libarchive is C code and generally follows BSD KNF. Match the surrounding file style, use hard tabs in new C files, and avoid whitespace-only churn. Test files use descriptive `test_*.c` names, for example `test_read_format_zip_mac_metadata.c`. Test functions are registered with `DEFINE_TEST(test_name)` and should usually match the filename.

## Testing Guidelines

Most functional changes should add or update tests in the relevant component `test/` directory. Add new C test files to the appropriate `CMakeLists.txt`; update `Makefile.am` as needed for autotools, keeping lists alphabetical. Store binary fixtures as `.uu` files and load them with helpers such as `extract_reference_file()`. Use the assertion helpers from `test_utils/test_common.h` so failures include useful diagnostics.

## Commit & Pull Request Guidelines

The visible history only contains `Initial commit`, so there is no established local commit convention. Use concise, imperative subjects such as `Fix zip64 size validation` and keep each commit focused on one issue. Pull requests should describe the bug or feature, include reproduction steps when relevant, list tests run, and mention the target platform/compiler. Link related issues and include fixtures or logs for archive-specific failures.

## Security & Configuration Tips

Do not commit generated binaries, archives from failed tests, local caches, or dependency build output. For security-sensitive archive handling changes, review `libarchive/SECURITY.md` and add regression tests that exercise malformed or hostile inputs.
