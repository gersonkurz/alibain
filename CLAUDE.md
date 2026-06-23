# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`alibain` ("**A Lib**archive **In**stallation") is a Windows build of [libarchive](https://github.com/libarchive/libarchive) for **x64 and ARM64**, built with **pure hand-authored MSBuild — no vcpkg, no CMake in the shipping build**. The deliverable is an SDK (DLL + import lib + headers).

**Goal:** reliably *read* the common Windows archive formats — `.zip`, `.7z`, `.rar`.

libarchive itself is the `libarchive/` git submodule. This repo adds the Windows build around it.

## Authoritative design: `joint-plan.md`

**Read `joint-plan.md` before writing any build files.** It is the agreed, decisions-closed plan (jointly authored, supersedes the untracked `claude-plan.md`/`codex-plan.md`). Key locked decisions an agent must not silently violate:

- **Pure hand-authored MSBuild** (`.vcxproj` + `.slnx`) driven by a `justfile`, mirroring the `C:\Projects\environ` house style: `PlatformToolset=v145`, Windows SDK `10.0`, **`/MD`**, Unicode, `stdclatest`.
- **No vcpkg / package managers.** Dependencies **`zlib` (v1.3.1)** and **`liblzma`/xz (v5.6.4)** are vendored as **source** under `extern/` (pinned submodules), each built as a **separate static lib**. `bzip2` and `zstd` are **deliberately dropped** (rare on Windows; such entries must fail cleanly).
- **CMake is NOT part of the build.** It is used only *offline, once*, as a reference oracle to capture libarchive's generated `config.h` + source list, which are then hand-translated into checked-in `config/config.h` and an explicit `.vcxproj` ItemGroup. Do not add CMake as a build dependency.
- **liblzma is decode-only** (sufficient for reading `.7z`; no threading config needed).
- **Crypto via Windows CNG (`bcrypt`)** — no OpenSSL/mbedTLS/Nettle. Covers AES-encrypted zip.

### Status

**Planning / not yet implemented.** No `justfile`, `.vcxproj`, `.slnx`, `config/`, or `extern/` exist yet. The build lands in phases (see `joint-plan.md` §11): zlib+ZIP first, then liblzma+7z/RAR (both in the first package), then packaging.

### Implementation gotchas (verified — see `joint-plan.md` §14)

- **`LZMA_API_STATIC`** must be defined in every TU including `<lzma.h>` (`liblzma.vcxproj` *and* `archive.vcxproj`), or static liblzma link fails. zlib needs no analogue.
- The static lib must output **`archive_static.lib`** to avoid clobbering the DLL's `archive.lib` import lib.
- **No `.def` file needed**: `__LA_DECL` auto-selects `dllexport`/`dllimport`. Just ensure the DLL config does *not* define `LIBARCHIVE_STATIC` and the static config does.
- libarchive consumes the static config via `HAVE_CONFIG_H` + `config/` on the include path (`archive_platform.h:42` also supports `PLATFORM_CONFIG_H`).

## Submodule setup

After a plain `git clone` the submodule is empty. Initialize it before doing anything:

```sh
git submodule update --init --recursive
```

(or `git clone --recursive <url>`).

## libarchive architecture (the submodule)

The codebase is large but highly regular; filenames encode role:

- `libarchive/libarchive/` — the core library. Public API is `archive.h` + `archive_entry.h`.
  - `archive_read_support_format_*.c` / `archive_write_set_format_*.c` — container formats (zip, 7zip, rar/rar5, tar, …).
  - `archive_read_support_filter_*.c` / `archive_write_add_filter_*.c` — compression filters (gzip, xz, …), layered independently of format.
  - Each optional codec is gated behind a `HAVE_*` macro in `config.h`. RAR (rar/rar5) and 7z PPMd decoders are **built in** (no external lib).
- `libarchive/libarchive/test/` — reference test fixtures as `.uu` files (50 `.zip`, 56 `.7z`, 107 `.rar`). **Reuse these for smoke tests** rather than hand-crafting.
- `libarchive/{tar,cpio,cat,unzip}/` — CLI front-ends (out of scope here).

To explore the submodule standalone (reference only — **not** this project's build), libarchive has its own CMake build: `cmake -S libarchive -B libarchive/build && cmake --build libarchive/build`. Do not let this leak into alibain's MSBuild deliverable.

## Commit conventions

- **No AI/tool attribution in commits or PRs** — do not add `Co-Authored-By: Claude …` or "Generated with Claude Code" trailers.
- Concise, imperative subjects; keep each commit focused.
