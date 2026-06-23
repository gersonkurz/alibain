# Repository Guidelines

`alibain` ("A Libarchive Installation") is a Windows build of the `libarchive` submodule for **x64 and ARM64**, using **pure hand-authored MSBuild — no vcpkg, no CMake in the shipping build**. Goal: reliably *read* `.zip`, `.7z`, and `.rar`. The deliverable is an SDK (DLL + import lib + headers).

**The authoritative design is `joint-plan.md` — read it before writing build files.** All build decisions there are closed.

## Project Structure & Module Organization

- `libarchive/` — the upstream library, a git submodule (the implementation we build).
- `joint-plan.md` — agreed build plan (authoritative). `claude-plan.md` / `codex-plan.md` are untracked working drafts.
- Planned, not yet created (see plan §4): `justfile`, `alibain.slnx`, `msbuild/` (`common.props`, `zlib.vcxproj`, `liblzma.vcxproj`, `archive.vcxproj`), `config/` (`config.h`, `liblzma-config.h`), `extern/` (vendored `zlib`, `xz` as pinned submodules), `tests/{smoke,fixtures}/`. Outputs go to `bin\<Platform>\<Config>\`, intermediates to `temp\<Platform>\<Config>\<Project>\`, staged SDK to `dist\`.

After cloning, initialize submodules: `git submodule update --init --recursive`.

## Build, Test, and Development Commands

The shipping build is **pure MSBuild driven by a `justfile`**, mirroring `C:\Projects\environ` (`PlatformToolset=v145`, Windows SDK 10.0, `/MD`, Unicode). This is **not yet implemented**; once it lands the surface mirrors environ: `just build` / `build-release` / `build-all`, `just stage` / `stage-all`, `just package`, `just smoke`, `just clean`. Requires a VS 2026 Developer shell (`VisualStudioVersion=18.0`).

- **No vcpkg / Conan / NuGet-native / package managers.** Deps (`zlib` v1.3.1, `xz`/liblzma v5.6.4) are vendored as source under `extern/`, built as separate static libs. `bzip2`/`zstd` are dropped.
- **CMake is only an offline oracle** — run once to capture libarchive's generated `config.h` + source list, then hand-translate into `config/config.h` + explicit `.vcxproj`. Never a build dependency.
- To explore the submodule standalone (reference only): `cmake -S libarchive -B libarchive/build && cmake --build libarchive/build`; tests via `ctest --test-dir libarchive/build`.

## Coding Style & Naming Conventions

For changes inside `libarchive/`, follow upstream BSD KNF: match surrounding style, hard tabs in C files, no whitespace churn. For alibain's own MSBuild/config files, match the `environ` conventions (centralize shared settings in `msbuild/common.props`; explicit source lists, no globs, so version bumps force a reviewed diff).

## Testing Guidelines

Validation is small and targeted, independent of upstream CTest. **Reuse libarchive's shipped `.uu` fixtures** in `libarchive/libarchive/test/` (50 `.zip`, 56 `.7z`, 107 `.rar`) rather than hand-crafting. Smoke tests must assert *real* codec support (store/deflate/ZIP64/AES zip, LZMA2 + PPMd 7z, RAR4/RAR5) and that unsupported bzip2/zstd entries **fail cleanly, not crash**. The full libarchive CTest suite stays a developer-only path, not a release gate.

## Commit & Pull Request Guidelines

- **Do not add AI/tool attribution** — no `Co-Authored-By: Claude …` or "Generated with Claude Code" trailers in commits or PRs.
- Use concise, imperative subjects (e.g. `Add zlib static-lib project`); keep each commit focused. PRs should state scope, the target platform/arch, and validation run.

## Security & Configuration Tips

- **xz supply chain:** pin the **git tag (v5.6.4), not a release tarball** (CVE-2024-3094 lived only in the generated tarball), and never run xz's own build system — these structurally avoid the backdoor. Record the exact commit; review before any bump.
- Crypto uses Windows CNG (`bcrypt.lib`); no OpenSSL. For archive-handling changes, review `libarchive/SECURITY.md` and exercise malformed/hostile inputs.
- Do not commit generated output (`bin/`, `temp/`, `dist/`) or dependency build artifacts.
