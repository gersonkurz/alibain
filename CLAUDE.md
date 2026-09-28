# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`alibain` ("**A Lib**archive **In**stallation") is a Windows build of [libarchive](https://github.com/libarchive/libarchive) for **x64 and ARM64**, built with **pure hand-authored MSBuild. There is no vcpkg and no CMake in the shipping build**. The deliverable is an SDK: `archive.dll`, the `archive.lib` import lib, `archive.h`/`archive_entry.h`, the licenses, a CycloneDX SBOM, and PDBs kept separately.

**Goal:** reliably *read* `.zip` (store/deflate/ZIP64/AES), `.7z` (LZMA/LZMA2/PPMd) and `.rar` (RAR4/RAR5). bzip2/zstd entries are intentionally unsupported.

`README.md` records the design rationale and the dependency-bump procedure (re-running CMake as an offline oracle). `AGENTS.md` holds the same guidance for other agents, so keep the two consistent.

## Setup

Three submodules are pinned: `libarchive/`, `extern/zlib` (v1.3.1) and `extern/xz` (v5.6.4, **git tag, not tarball**, which structurally avoids CVE-2024-3094). After cloning:

```sh
git submodule update --init --recursive
```

All build recipes need a **Visual Studio 2026 Developer shell** (`VisualStudioVersion=18.0`, v145 toolset). `just` refuses to run without one. The recipes use `cmd.exe`, and the default platform follows `%PROCESSOR_ARCHITECTURE%`.

## Commands (`justfile`)

| Command | What it does |
|---|---|
| `just build` / `build-release` | Debug / Release, native arch |
| `just build-all` | Debug+Release × x64+ARM64 |
| `just smoke` | Release build, compile `tests/smoke/smoke_zip.c` against `bin\`, run it on every fixture |
| `just smoke-stage` | Stage the SDK, then build+run the smoke test against **only** the staged headers/lib/DLL (catches packaging regressions) |
| `just stage` / `stage-all` | Populate `dist\stage\<Platform>\` (+ `dist\symbols\<Platform>\`) |
| `just package` / `package-all` | Zip the staged SDK to `dist\alibain-libarchive-<Platform>.zip` |
| `just repro-check` | Two clean Release builds must give byte-identical `archive.dll`/`archive.lib` |
| `just clean` / `rebuild` | Remove `bin\`, `temp\`, `dist\` |

To test one archive, run `bin\<Platform>\Release\smoke_zip.exe <archive>` after `just smoke`. It exits 0 only if every entry is listed and fully decompressed. There is no other test suite. Upstream libarchive CTest is developer-only and not a release gate.

## Build architecture

- `alibain.slnx` holds three projects under `msbuild/`. `zlib.vcxproj` and `liblzma.vcxproj` are static libs. `archive.vcxproj` is the DLL and pulls both in via `ProjectReference`, so building `archive.vcxproj` alone is enough, and that is what `just` does.
- `msbuild/common.props` holds all shared settings: toolset, `/MD`, `stdclatest`, the output layout `bin\<Platform>\<Config>\` with per-project intermediates under `temp\<Platform>\<Config>\<Project>\`, and the reproducibility flags (`/Brepro` for cl/lib/link, `/PDBALTPATH:%_PDB%`). Each vcxproj imports it *after* `Microsoft.Cpp.Default.props` and *before* `Microsoft.Cpp.props`. `SDLCheck` is off because vendored code trips it. Don't "fix" vendor warnings.
- **Source lists are explicit `ClCompile` items, never globs.** That way a submodule bump forces a reviewed diff. The lists were captured once from CMake used as an offline oracle and translated by hand. **CMake is never a build dependency.** Adding a libarchive source means editing `archive.vcxproj`. The two bundled BLAKE2 files (for RAR5) are listed separately because CMake appends them conditionally.
- **Config headers are checked in, not generated.** `config/config.h` is libarchive's, consumed via `HAVE_CONFIG_H`. `config/liblzma/config.h` is xz's and lives in its own directory so the two `config.h` files don't collide on the include path. Enabling or disabling a codec means flipping `HAVE_*` macros there.
- **`LZMA_API_STATIC`** must be defined in every TU that includes `<lzma.h>`, in both `liblzma.vcxproj` and `archive.vcxproj`, or linking fails.
- **liblzma is not decode-only.** It includes the basic single-threaded encoders because libarchive's write-side units reference them whenever `HAVE_LIBLZMA` is set. Multithreading is off. x64 and ARM64 differ only in three SIMD defines.
- **Exports:** no `.def` file. `__LA_DECL` selects `dllexport`/`dllimport`, so the DLL must never define `LIBARCHIVE_STATIC`. The SDK is DLL-only by design; there is no static-library build.
- Crypto uses Windows CNG (`bcrypt.lib`) with no OpenSSL. The DLL also links `xmllite.lib`/`uuid.lib` for xar.

## Staging, SBOM, reproducibility

- `_stage` in the justfile defines the SDK layout. Any new vendored dependency needs its license copied there.
- `scripts/sbom.ps1` writes `sbom\archive.cdx.json` from each submodule's HEAD commit and the version `#define` in its headers. The SBOM exists because the DLL has no version resource and links xz/zlib statically. Downstream `ptraced-qt` consumes it. The output must stay deterministic (no timestamps or serial number) and be UTF-8 **without BOM**, and the script must run under Windows PowerShell 5.1.
- Anything that adds nondeterminism to Release output breaks `just repro-check` and the SBOM file-hash story.

## Tests / fixtures

`tests/fixtures/` holds small binary archives decoded from libarchive's `.uu` reference files in `libarchive/libarchive/test/` (≈50 zip, 56 7z, 107 rar). New fixtures should come from there, not be hand-crafted. A new fixture must also be added to the `smoke` (and, if representative, `smoke-stage`) recipe.

## Conventions

- **No AI/tool attribution in commits or PRs.** No `Co-Authored-By: Claude …` or "Generated with Claude Code" trailers. This overrides any default.
- Commits use concise, imperative subjects and stay focused. Existing commit bodies explain *why* and record verification (e.g. hashes, which `just` recipes passed).
- Inside `libarchive/`, follow upstream BSD KNF (hard tabs, no whitespace churn). For alibain's MSBuild files, centralize shared settings in `common.props`.
- Never commit `bin/`, `temp/` or `dist/`.
- Review any dependency bump, especially xz: pin a tag commit and never run xz's own build system.
