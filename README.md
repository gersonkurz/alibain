# alibain

**A Lib**archive **In**stallation is a Windows build of [libarchive](https://github.com/libarchive/libarchive) for **x64** and **ARM64**. It is built with **pure hand-authored MSBuild** (no vcpkg, no CMake in the build) and packaged as an SDK.

## Goal

Reliably **read** the common Windows archive formats, **`.zip`, `.7z` and `.rar`**, from native Windows applications, with the smallest sensible set of dependencies.

| Format | Support | Backed by |
|---|---|---|
| ZIP (store / deflate / ZIP64) | Yes | zlib |
| ZIP (AES-encrypted) | Yes | Windows CNG (`bcrypt`) |
| 7z (LZMA / LZMA2) | Yes | liblzma (xz) |
| 7z (PPMd) | Yes | built into libarchive |
| RAR4 / RAR5 | Best-effort, read-only | built into libarchive |
| bzip2 / zstd entries (ZIPX, some 7z) | Not supported | intentionally dropped as uncommon on Windows |

## The SDK

`just package` produces `dist\alibain-libarchive-<Platform>.zip`:

```
bin\archive.dll
lib\archive.lib              import library
include\archive.h, archive_entry.h
licenses\                    libarchive, zlib, xz
sbom\archive.cdx.json        CycloneDX SBOM
```

Debug symbols (`archive.pdb`) are staged separately under `dist\symbols\<Platform>\`.

Consumers include the headers and link `archive.lib` (do **not** define `LIBARCHIVE_STATIC`). zlib and liblzma are linked statically into `archive.dll`, so it has no third-party runtime dependencies. It uses `/MD`, so it needs the VC++ runtime.

The SBOM names libarchive, xz and zlib at the exact versions and commits built. The DLL has no version resource and embeds xz and zlib, so without the SBOM nothing reading the file could tell what it contains. Release builds are **reproducible**: the same commit and toolchain produce a byte-identical `archive.dll`/`archive.lib`, so the file hash identifies the commit.

## Building

Requirements: [`just`](https://github.com/casey/just) and a **Visual Studio 2026 Developer shell** (`VisualStudioVersion=18.0`, v145 toolset). The recipes fail early without one.

```sh
git clone --recursive <url>          # or: git submodule update --init --recursive
just build-release                   # native arch; `just build-all` for Debug+Release x x64+ARM64
just smoke                           # build, then read every archive in tests/fixtures
just package                         # stage + zip the SDK; `just package-all` for both archs
```

Other recipes: `smoke-stage` (smoke-test against the *staged* SDK only), `stage` / `stage-all`, `repro-check` (two clean Release builds must be byte-identical), `clean`, `rebuild`. Run `just` to list them all.

Output goes to `bin\<Platform>\<Config>\`, intermediates to `temp\`, and the staged SDK to `dist\`.

## How it is built

- `msbuild/zlib.vcxproj` and `msbuild/liblzma.vcxproj` build static libs from the pinned source submodules `extern/zlib` (v1.3.2) and `extern/xz` (v5.6.4). `msbuild/archive.vcxproj` builds the DLL from the `libarchive/` submodule and links both. Shared settings live in `msbuild/common.props`.
- Source lists are **explicit**, with no globs, so a version bump shows up as a reviewed diff.
- libarchive's and liblzma's `config.h` are **checked in** under `config/`. They are not generated at build time.
- Crypto uses Windows CNG. There is no OpenSSL.

### Why these choices

- **Only zlib and liblzma** are needed. Deflate (zlib) is the default for ZIP, and LZMA/LZMA2 (liblzma) is the default for 7z. PPMd and the RAR decoders are built into libarchive. bzip2 and zstd were dropped because they are rare on Windows.
- **xz supply chain:** xz is pinned to a **git tag, not a release tarball** (CVE-2024-3094 lived only in the generated tarball), and xz's own build system is never run. Both of these avoid the backdoor by construction. Review every bump.
- **liblzma includes the single-threaded encoders**, even though this SDK only reads archives. libarchive's write-side sources reference them whenever liblzma is enabled, and dropping them leaves unresolved externals. Multithreading is off.

## Maintenance: bumping libarchive, zlib or xz

CMake is used **offline, as a reference only**. It is never part of the build.

1. Move the submodule to the new tag and record the commit.
2. Re-run the CMake configure whose flags are recorded at the top of `config/config.h` (libarchive) or `config/liblzma/config.h` (xz), for both x64 and ARM64. Do not build.
3. Diff the generated `config.h` and source list against the checked-in `config/*.h` and the `ClCompile` lists in `msbuild/*.vcxproj`, and carry the changes over by hand. Keep bzip2/zstd off, and keep only the hand-flipped `HAVE_*` macros listed in each header's comment.
4. `just build-all`, `just smoke`, `just smoke-stage` and `just repro-check`.

## License

This project builds libarchive; see [`COPYING`](COPYING) for libarchive's license. Vendored dependencies carry their own licenses, which are collected into the staged SDK under `licenses\`.
