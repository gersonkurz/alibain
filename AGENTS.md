# Repository Guidelines

`alibain` ("A Libarchive Installation") is a Windows build of the `libarchive` submodule for **x64 and ARM64**, using **pure hand-authored MSBuild. There is no vcpkg and no CMake in the shipping build**. Goal: reliably *read* `.zip`, `.7z` and `.rar`. The deliverable is an SDK: `archive.dll` + `archive.lib` import lib + headers + licenses + CycloneDX SBOM.

`README.md` covers the design rationale and the dependency-bump procedure. `CLAUDE.md` holds the same guidance as this file, so keep the two consistent.

## Project Structure

- `libarchive/`, `extern/zlib` (v1.3.1), `extern/xz` (v5.6.4) are pinned git submodules. Run `git submodule update --init --recursive` after cloning.
- `msbuild/` holds `common.props` (shared settings) and `zlib.vcxproj` and `liblzma.vcxproj` (static libs). It also holds `archive.vcxproj`, the DLL, which references both. `alibain.slnx` ties them together.
- `config/config.h` (libarchive) and `config/liblzma/config.h` (xz) are checked-in build configs, consumed via `HAVE_CONFIG_H`.
- `scripts/sbom.ps1` writes the SBOM, `scripts/package.ps1` zips the staged SDK, and `scripts/repro-check.ps1` backs `just repro-check`. Recipes call PowerShell with `-File`, never an inline `-Command "..."`: just escapes the inner quotes as `\"`, which cmd does not understand, so PowerShell only echoes the string and exits 0.
- `tests/smoke/smoke_zip.c` is a minimal consumer. `tests/fixtures/` holds sample archives.
- Build output goes to `bin\<Platform>\<Config>\`, intermediates to `temp\…`, and the staged SDK to `dist\` (all git-ignored).

## Build, Test, and Development Commands

Requires `just` and a VS 2026 Developer shell (`VisualStudioVersion=18.0`).

- `just build` / `build-release` / `build-all` build the native arch Debug / Release, or all configs × x64+ARM64.
- `just smoke` builds Release and reads every fixture with `smoke_zip.exe`. `just smoke-stage` does the same against the staged SDK only.
- `just stage` / `stage-all` and `just package` / `package-all` produce the SDK layout and zip.
- `just repro-check` requires two clean Release builds to be byte-identical.
- `just clean` / `rebuild`.

## Build Rules

- **No package managers** (vcpkg, Conan, NuGet-native). Dependencies are vendored as source and built as separate static libs. bzip2/zstd are intentionally dropped.
- **CMake is only an offline oracle** for capturing `config.h` and source lists when bumping a dependency (procedure in `README.md`). It is never a build dependency.
- Source lists are explicit `ClCompile` items with no globs. Shared settings belong in `common.props`.
- Define `LZMA_API_STATIC` in every project whose TUs include `<lzma.h>`. The DLL must not define `LIBARCHIVE_STATIC` (`__LA_DECL` handles exports, with no `.def` file). The SDK is DLL-only by design; there is no static-library build.
- liblzma includes the single-threaded encoders because libarchive's write side needs them to link. Multithreading is off.
- Keep Release output reproducible (`/Brepro`, `/PDBALTPATH` in `common.props`). Keep the SBOM deterministic, UTF-8 without BOM, and runnable under Windows PowerShell 5.1.

## Coding Style

Inside `libarchive/`, follow upstream BSD KNF: match surrounding style, use hard tabs, and avoid whitespace churn. `SDLCheck` is off for vendored code, so don't "fix" vendor warnings.

## Testing Guidelines

Validation is the smoke test, independent of upstream CTest, which stays developer-only. Take new fixtures from libarchive's `.uu` reference files in `libarchive/libarchive/test/` (≈50 `.zip`, 56 `.7z`, 107 `.rar`) rather than hand-crafting them, and add each to the `smoke` recipe.

## Commit & Pull Request Guidelines

- **Do not add AI/tool attribution.** No `Co-Authored-By: Claude …` or "Generated with Claude Code" trailers in commits or PRs.
- Use concise, imperative subjects and keep each commit focused. Bodies explain why and record the validation run. PRs state scope, target platform/arch, and validation.

## Security

- **xz supply chain:** pin a git tag (not a release tarball; CVE-2024-3094 lived only in the tarball) and never run xz's own build system. Review every bump.
- Crypto uses Windows CNG (`bcrypt.lib`). There is no OpenSSL. For archive-handling changes, review `libarchive/SECURITY.md` and exercise malformed or hostile inputs.
