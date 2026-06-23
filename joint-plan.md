# joint-plan.md — Building libarchive on Windows with MSBuild

**Authors:** Claude & Codex (converged plan)
**Date:** 2026-06-23
**Status:** Agreed and **all decisions closed** (§13). Ready to implement Phase 1. No code written yet.

> This is the single authoritative plan. It supersedes `claude-plan.md` and `codex-plan.md`, which remain as the working history. Both agents independently reached the same architecture; the reconciliation is summarised in §0.

---

## 0. How this plan was reached

Two independent plans (`claude-plan.md`, `codex-plan.md`) converged after cross-review:

- **Build system — pure hand-authored MSBuild.** This is the user's explicit choice *and* the established house style: the reference project **`C:\Projects\environ`** is built with a hand-authored `.vcxproj` + `.slnx` and a `justfile` driving MSBuild — no CMake — and vendors deps as source under `extern/`. Verified environ settings adopted wholesale: `PlatformToolset=v145`, `WindowsTargetPlatformVersion=10.0`, `/MD` (`MultiThreadedDLL`), `stdclatest`, Unicode. (Codex's original CMake-as-generator idea is retained only as a documented fallback, §13.1.)
- **CMake as an offline oracle, not a build dependency** — run once to capture a known-good `config.h` + source list, then discard. This gives the safety of a generated reference while keeping the shipping build pure MSBuild (§6).
- **Scope — read `.zip` / `.7z` / `.rar`**, vendoring only `zlib` + `liblzma`; `bzip2`/`zstd` dropped; CNG for crypto; honest format promise; phased ZIP→7z sequencing; smoke tests that assert *real* codec support and clean failure on unsupported codecs.

Verified jointly against this tree: the 132-file core source list, the `PLATFORM_CONFIG_H` config hook, the Windows POSIX shim, CNG/`bcrypt`, and **50 `.zip.uu` / 56 `.7z.uu` / 107 `.rar.uu`** reusable test fixtures.

---

## 1. Objective & constraints

Build **libarchive** as a Windows SDK (DLL + import lib + headers) for **x64** and **ARM64**, matching the `environ` house style:

- **No vcpkg / Conan / NuGet-native / system package managers.**
- **Pure hand-authored MSBuild** — `.vcxproj` + `.slnx`, `PlatformToolset=v145`, driven by a `justfile`. **No CMake in the shipping build** (CMake is used only *offline, once*, as a reference oracle — §6).
- **Real goal: reliably READ the common Windows archive formats — `.zip`, `.7z`, `.rar`.**
- Vendor only the deps that goal needs, as **source under `extern/`**: **`zlib`** and **`liblzma` (xz)**. `bzip2` and `zstd` **dropped** (§2).
- Cross-built from an x64 host using the VS 2026 toolset.

Out of scope (phase 1): CLI tools (bsdtar/…), libarchive's CTest suite under MSBuild, write/compression support, installers (this is an SDK — a staged `.zip` is the artifact).

---

## 2. Why zlib + liblzma — format → codec → dependency

Established by reading `archive_read_support_format_{zip,7zip,rar,rar5}.c`:

| Format | Codec | Dependency | Notes |
|---|---|---|---|
| **ZIP** | deflate | **zlib** | Default Windows ZIP compression → mandatory. |
| ZIP | store / ZIP64 | none (zlib for deflate entries) | |
| ZIP | AES-encrypted | CNG / `bcrypt` | Windows system lib; no OpenSSL. |
| ZIP | bzip2 / zstd (ZIPX) | (dropped) | Rare; must **fail cleanly** (§10). |
| **7z** | **LZMA / LZMA2** | **liblzma** | 7-Zip default → mandatory for useful `.7z`. |
| 7z | PPMd | **built-in** (`archive_ppmd7_private.h`) | No external dep. |
| 7z | copy / deflate | none / zlib | |
| 7z | bzip2 / zstd | (dropped) | Rare; fail cleanly. |
| **RAR4 / RAR5** | RAR LZ + PPMd | **built-in** | Self-contained; only references zlib. Read-only, best-effort. |

**Net:** zlib + liblzma cover the overwhelmingly common real `.zip`/`.7z`/`.rar`. Accepted gap: bzip2-/zstd-compressed zip/7z entries. Of the two libs, **zlib is easy, liblzma is the hard/critical path** — dropping bzip2/zstd removed real work but not the dominant cost.

---

## 3. Mechanisms relied on (from the libarchive submodule)

1. **Hand-built config via `PLATFORM_CONFIG_H`** (`archive_platform.h:42`) bypasses CMake/autoconf feature detection — the supported static-config path on MSVC.
2. **Windows POSIX-shim already present**: `archive_windows.c/.h`, `archive_{read,write}_disk_windows.c`, `filter_fork_windows.c`; auto-included on `_WIN32` (`archive_platform.h:73`). No porting.
3. **Optional libs are macro-gated** — defining only zlib + lzma `HAVE_*` macros compiles bzip2/zstd codec paths out cleanly.
4. **Explicit 132-file core source list** in `libarchive/libarchive/CMakeLists.txt` → `.vcxproj` ItemGroup.
5. **CNG crypto** (`bcrypt.dll`, `CMakeLists.txt:824`) for AES-encrypted zip — set `ARCHIVE_CRYPTO_*_WIN` + `HAVE_BCRYPT_H`, link `bcrypt.lib`.
6. **Export model** (`archive.h:129`): `__LA_DECL` = `dllexport/dllimport` unless `LIBARCHIVE_STATIC` is defined.

---

## 4. Repository layout (matching environ conventions)

```
alibain/
├─ joint-plan.md                    (this file — authoritative)
├─ claude-plan.md / codex-plan.md   (working history)
├─ justfile                         (just-driven MSBuild, environ-style)
├─ alibain.slnx                     (XML solution; ARM64 + x64)
├─ libarchive/                      (existing submodule)
├─ extern/                          (vendored deps as source — environ uses extern/)
│  ├─ zlib/                         (submodule, pinned)
│  └─ xz/                           (submodule, pinned — liblzma)
├─ config/
│  ├─ config.h                      (hand-maintained libarchive config)
│  └─ liblzma-config.h              (hand-maintained liblzma config)
├─ msbuild/
│  ├─ common.props                  (v145, /MD, SDK 10.0, stdclatest, Unicode)
│  ├─ zlib.vcxproj                  (static lib)
│  ├─ liblzma.vcxproj               (static lib)
│  └─ archive.vcxproj               (DLL + static configs)
├─ tests/smoke/ + tests/fixtures/   (sample archives + tiny consumer)
├─ bin\<Platform>\<Config>\         (build output — environ convention)
├─ temp\<Platform>\<Config>\<Proj>\ (per-project intermediates)
└─ dist\stage\ , dist\symbols\      (SDK staging — environ convention)
```

Deps as **git submodules pinned to release tags** (matches how libarchive is vendored). Pins — must be byte-identical across both agents:

| Dep | Repo | Pinned tag | Notes |
|---|---|---|---|
| zlib | madler/zlib | **v1.3.1** | current stable, portable C. |
| xz (liblzma) | tukaani-project/xz | **v5.6.4** | audited post-CVE-2024-3094 release. Safe by construction: we pin the **git tag (not a tarball)** — the backdoor lived only in the generated tarball — and we **never run xz's build system** (hand-authored `liblzma.vcxproj`), so the malicious m4/test-blob delivery path never executes. Record exact commit at submodule-add; review before any bump. |

---

## 5. Per-dependency build notes

### 5.1 zlib *(flips `HAVE_ZLIB_H`, `HAVE_LIBZ`)* — easy
~15 portable `.c` → static lib; `zconf.h` ships in-tree (no generation). ARM64: build portable C, disable optional intrinsics, single source set both arches.

### 5.2 liblzma (xz) *(flips `HAVE_LZMA_H`, `HAVE_LIBLZMA`)* — hard, critical path
Sources across `src/liblzma/{api,common,check,lz,lzma,rangecoder,delta,simple}`. Hand-author `config/liblzma-config.h` for **decode-only** (LZMA1+LZMA2 decode, `.xz`+`.lzma` containers, CRC32/CRC64/SHA-256 checks) — sufficient for reading `.7z`, smaller surface, no threading needed (§14.4). C CRC tables (no `.S` asm) on both arches. **De-risk: build standalone and validate an LZMA2 decode round-trip before integrating.**

---

## 6. Config strategy — CMake as offline oracle

Rather than hand-author the source list / config / feature probes "from archaeology," **run CMake once, offline, purely to capture a known-good reference** — then hand-author clean MSBuild from it and discard CMake:

1. Configure libarchive with the agreed feature profile (`-DENABLE_TEST/TAR/CPIO/CAT/UNZIP=OFF`, `-DENABLE_BZip2/ZSTD/LZ4/LZO/OPENSSL/MBEDTLS/NETTLE/LIBXML2/EXPAT/PCRE*=OFF`, `-DENABLE_ZLIB=ON`, `-DENABLE_LZMA=ON|OFF` per phase, `ENABLE_CNG=ON`) for **x64 and ARM64**.
2. Capture the generated `config.h` (both arches — **diff to confirm identical**; expected yes given same MSVC/UCRT surface), the exact compiled source list, preprocessor defines, and link libs.
3. Hand-edit into checked-in `config/config.h` (turn on only zlib+lzma `HAVE_*` + probes + CNG defines; **verify bzip2/zstd are OFF**), and into `archive.vcxproj`'s explicit ItemGroup.
4. CMake is **not** retained — the shipping build is pure MSBuild. Consumed via `HAVE_CONFIG_H` + `config/` on the include path. Re-run the oracle when bumping libarchive or a dep.

CMake-generated VS projects remain a fallback/debugging path only, never the shipping build.

---

## 7. MSBuild structure

- **`common.props`** (imported everywhere): `PlatformToolset=v145`, `WindowsTargetPlatformVersion=10.0`, `RuntimeLibrary=MultiThreaded[Debug]DLL` (**/MD**, matching environ), `LanguageStandard_C=stdclatest`, `CharacterSet=Unicode`, `_CRT_SECURE_NO_WARNINGS`/`_CRT_NONSTDC_NO_DEPRECATE`; `OutDir=$(SolutionDir)bin\$(Platform)\$(Configuration)\`, `IntDir=$(SolutionDir)temp\$(Platform)\$(Configuration)\$(ProjectName)\`.
- **`zlib.vcxproj`, `liblzma.vcxproj`** — static `.lib` each, own includes/defines (liblzma points at `config/liblzma-config.h`; **defines `LZMA_API_STATIC`** — §14.1).
- **`archive.vcxproj`** — 132 core sources; includes `config/`, `libarchive/libarchive/`, dep header dirs; `ProjectReference` to zlib+liblzma; links `bcrypt.lib`; defines `HAVE_CONFIG_H` (and `LZMA_API_STATIC`). **DLL config** (default SDK artifact, *not* `LIBARCHIVE_STATIC`) and **static config** (defines `LIBARCHIVE_STATIC`, outputs `archive_static.lib` — §14.2).
- **`alibain.slnx`** — platforms ARM64 + x64; Debug/Release; dep order zlib/liblzma → archive.
- Explicit source lists (no wildcards) so a version bump forces a reviewed update.

Decided: build zlib/liblzma as **separate static-lib projects** (clean config isolation — keeps liblzma's distinct config/includes from leaking) rather than compiling their sources into `archive.vcxproj`.

---

## 8. Architecture (x64 / ARM64)

Same compiler/sources both arches; zlib portable-C and liblzma C-CRC-tables mean **identical source sets** and **one `config.h`**. ARM64 cross-built from x64 host. (Dropping zstd also removed its x64-only `huf_decompress_amd64.S` asm headache.)

---

## 9. Crypto / DLL vs static / exports

- **Crypto:** Windows CNG (`bcrypt.lib`), `ARCHIVE_CRYPTO_*_WIN` + `HAVE_BCRYPT_H`. No OpenSSL/mbedTLS/Nettle.
- **DLL is the primary SDK artifact** (import lib + headers). Static config also produced; **document that static consumers must define `LIBARCHIVE_STATIC` and link `archive_static.lib` + zlib + liblzma + `bcrypt.lib`** — a static consumer is *not* one-file unless we explicitly merge libs, which phase 1 does **not** promise.

---

## 10. justfile + validation (environ-style)

`justfile` mirrors environ: VS 2026 dev-shell guard (`VisualStudioVersion=18.0`), `%PROCESSOR_ARCHITECTURE%`→platform map, recipes `build` / `build-release` / `build-all`, `stage` / `stage-all`, `package`(SDK zip) / `package-all`, `smoke`, `clean`, `rebuild`. No `configure` in the shipping flow (the CMake oracle is a private/documented maintenance task). Output under `bin\<Platform>\<Config>`, staging under `dist\stage\<Platform>` + `dist\symbols\<Platform>`.

**Smoke test** (tiny consumer `.exe`, not shipped) asserts *real* support, reusing libarchive's shipped `.uu` fixtures (§14.3):
- read stored ZIP, deflate ZIP, ZIP64, AES-encrypted ZIP (CNG),
- read `.7z` LZMA2, `.7z` PPMd (built-in),
- read RAR4 + RAR5 (best-effort),
- **unsupported bzip2/zstd ZIPX entry fails cleanly with an unsupported-compression error, not a crash.**

Full CTest stays a developer-only path; not a phase-1 gate.

---

## 11. Phasing

- **Phase 0 — Alignment** (this doc): lock pins, `/MD`, DLL+static, deferrals. ~0.5 day.
- **Phase 1 — ZIP SDK:** zlib submodule, `common.props`, `archive.vcxproj` (zlib only, lzma off in config), justfile, staging, ZIP smoke. ~1–2 days.
- **Phase 2 — 7z + RAR validation:** liblzma submodule + `liblzma-config.h`, flip lzma `HAVE_*`, `.7z`/RAR smoke. ~1–1.5 days (liblzma is the long pole). **Required for the first package** (decision §13.10) — Phase 1 and 2 ship together; the internal ZIP-first ordering is just build sequencing, not a separate release.
- **Phase 3 — Polish:** SDK `.zip` packaging recipes, staged README + license aggregation, oracle-rerun maintenance notes. ~0.5 day.

**Total ~3–4 days.** Pure-MSBuild from day one (per house style), informed by the §6 oracle.

---

## 12. Risks & accepted limitations

- **Accepted limitation:** bzip2/zstd zip & 7z entries won't decompress (rare); must fail cleanly + be documented.
- **liblzma config drift** — mitigated by standalone LZMA2 decode round-trip before integration.
- **Silent codec omission** — mitigated by per-format smoke asserts (§10).
- **Static-artifact confusion** — document required link set; no merged-lib promise in phase 1.
- **xz supply-chain** — pin vetted release, record commit, review before bump.
- **Version-bump maintenance** — explicit file lists surface breakage at build time; the §6 oracle is re-runnable to re-capture lists on a bump.
- **RAR expectation** — describe as best-effort extraction, not WinRAR-equivalent.

---

## 13. Decisions — status

| # | Decision | Resolution |
|---|---|---|
| 1 | Build system | **Pure hand-authored MSBuild** (user's choice + environ). CMake-generator = documented fallback only. |
| 2 | CRT linkage | **`/MD`** (environ). |
| 3 | Toolset / SDK | **v145 / SDK 10.0 / stdclatest** (environ). |
| 4 | Output | **DLL primary + static** (with documented link set). |
| 5 | Deps location | **`extern/` submodules**. |
| 6 | Dep build shape | **Separate static-lib vcxproj per dep**. |
| 7 | liblzma encoder | **Decode-only** for v1. |
| 8 | zlib vs zlib-ng | **Stock zlib**. |
| 9 | Format promise | **ZIP store/deflate/ZIP64/AES; common 7z (LZMA2/PPMd); best-effort RAR**. |
| **10** | **`.7z` in first release?** | **CLOSED — yes.** `.7z` ships in the first package; liblzma is part of the first deliverable. The "ship ZIP-only" fallback is off the table. |
| **11** | **Exact pins (zlib, xz)** | **CLOSED.** zlib **v1.3.1**, xz **v5.6.4** (§4). Commit hashes recorded at submodule-add. |
| 12 | ARM64 validation | Compile/link on host now; run on ARM64 HW/CI when available. |

**All decisions closed.** Build is pure MSBuild (final); `.7z` is in the first package (liblzma included from the start); pins are zlib v1.3.1 + xz v5.6.4.

---

## 14. Implementation gotchas (verified against the tree)

1. **`LZMA_API_STATIC` is mandatory for static liblzma.** libarchive includes `<lzma.h>` in `archive_read_support_filter_xz.c:43` and `archive_read_support_format_7zip.c:44`. With liblzma built static, `LZMA_API` defaults to `__declspec(dllimport)` → link mismatch. **Define `LZMA_API_STATIC` in every TU including `<lzma.h>`** — `liblzma.vcxproj` *and* `archive.vcxproj`. zlib needs no analogous macro (`<zlib.h>` included plainly, no `ZLIB_DLL`).
2. **Static-lib name collision.** The DLL's import lib defaults to `archive.lib`; the static config would too. Set the static configuration's output to **`archive_static.lib`** to avoid clobbering the import lib in a shared `dist\` dir.
3. **Reuse libarchive's shipped fixtures.** `libarchive/libarchive/test/` contains **50 `.zip.uu` / 56 `.7z.uu` / 107 `.rar.uu`** uuencoded reference archives (incl. encrypted + multivolume). Decode a chosen handful into `tests/fixtures/` rather than hand-crafting — authoritative and free.
4. **Decode-only liblzma needs no threading.** `HAVE_LZMA_STREAM_ENCODER_MT` is encoder-only; a decode-only `liblzma-config.h` can omit the `mythread` backend entirely (no Win32 threading-model selection), shrinking the config.
5. **No `.def` file needed** (verified non-issue). `__LA_DECL` (`archive.h:129`) auto-selects `dllexport` when building libarchive's own TUs (via `__LIBARCHIVE_BUILD`, `archive_platform.h:40`) and `dllimport` for consumers. Just ensure the **DLL config does not define `LIBARCHIVE_STATIC`**, and the **static config does**.
