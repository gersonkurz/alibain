# alibain

**A Lib**archive **In**stallation — a Windows build of [libarchive](https://github.com/libarchive/libarchive) for **x64** and **ARM64**, built with **pure MSBuild** (no vcpkg, no CMake in the shipping build), packaged as an SDK (DLL + import library + headers, plus the licenses and a CycloneDX SBOM, `sbom\archive.cdx.json`, naming libarchive, xz and zlib at the commits built — the DLL has no version resource and links xz/zlib statically, so nothing reading the file can tell).

## Goal

Reliably **read** the common Windows archive formats — **`.zip`, `.7z`, and `.rar`** — from native Windows applications, with the smallest sensible dependency set.

| Format | Support | Backed by |
|---|---|---|
| ZIP (store / deflate / ZIP64) | Yes | zlib |
| ZIP (AES-encrypted) | Yes | Windows CNG (`bcrypt`) |
| 7z (LZMA / LZMA2) | Yes | liblzma (xz) |
| 7z (PPMd) | Yes | built into libarchive |
| RAR / RAR5 | Best-effort, read-only | built into libarchive |
| bzip2 / zstd entries (ZIPX, some 7z) | Not supported | *(intentionally dropped — uncommon on Windows; such entries fail cleanly)* |

## Approach

- **Pure hand-authored MSBuild** (`.vcxproj` + `.slnx`) driven by a `justfile`, mirroring the `environ` house style: `PlatformToolset=v145`, Windows SDK `10.0`, `/MD`, Unicode.
- Dependencies (**zlib**, **xz/liblzma**) vendored as **source** under `extern/` as pinned submodules — no package manager.
- libarchive itself is the `libarchive/` git submodule.
- Crypto via Windows CNG; **no OpenSSL**.

## Status

**Planning.** No build files have been written yet. The design is recorded in [`joint-plan.md`](joint-plan.md) (the authoritative plan, agreed by both planning agents); `claude-plan.md` and `codex-plan.md` are kept as working history.

Three decisions remain open before implementation: confirming pure MSBuild as final, whether `.7z` ships in the first package or follows ZIP, and the exact zlib/xz dependency pins.

## Building

> Not yet implemented — this section will describe the `just` workflow once the build lands.

The repository uses git submodules. After cloning:

```sh
git submodule update --init --recursive
```

## License

This project builds libarchive; see [`COPYING`](COPYING) for libarchive's license. Vendored dependencies carry their own licenses, aggregated into the staged SDK.
