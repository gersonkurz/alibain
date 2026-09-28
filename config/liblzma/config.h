/*
 * config/liblzma/config.h — liblzma (xz) build configuration for alibain.
 *
 * Encoders + decoders, single-threaded, MSVC/Windows. Lives in its own
 * directory so liblzma's `#include <config.h>` (src/common/sysdefs.h, under
 * HAVE_CONFIG_H) resolves here and never collides with libarchive's
 * config/config.h. (Encoders are included only because libarchive's write-side
 * files require the basic lzma encoders to link — see the encoder note below.)
 *
 * Derived from xz's own CMake "oracle" (README.md, Maintenance) run as:
 *   cmake -S extern/xz -A {x64|ARM64} -DBUILD_SHARED_LIBS=OFF \
 *     -DENABLE_THREADS=OFF -DENABLE_NLS=OFF -DENABLE_DOC=OFF -DXZ_TOOL_*=OFF
 * The x64 and ARM64 define sets differ ONLY in the three x86 SIMD macros
 * below; the source list is identical. Re-run the oracle on an xz bump.
 *
 * Carried to v5.8.4 by review instead of a re-run: no macro set here was
 * dropped, and the feature macros new since v5.6.4 (HAVE_CRC_X86_ASM,
 * HAVE_HWCAP_CRC32, HAVE_LOONGARCH_CRC32, HAVE_VASPRINTF, TUKLIB_MBSTR_*)
 * are 32-bit GCC asm, Linux, LoongArch or xz-tool only. 5.8 renamed the
 * options above to XZ_* (XZ_THREADS=no, XZ_NLS=OFF, XZ_DOC=OFF, ...); CMake
 * ignores the old names, so update them before any re-run.
 */

#ifndef ALIBAIN_LIBLZMA_CONFIG_H
#define ALIBAIN_LIBLZMA_CONFIG_H

/* Encoders. NOTE: not for our own use, but libarchive's write-side files
   (archive_write_add_filter_xz.c, archive_write_set_format_7zip.c) reference
   the basic lzma encoders unconditionally when HAVE_LIBLZMA is set, so the
   encoders must be present to link. Single-threaded only (ENABLE_THREADS=OFF;
   no lzma_stream_encoder_mt — HAVE_LZMA_STREAM_ENCODER_MT stays off). */
#define HAVE_ENCODERS 1
#define HAVE_ENCODER_LZMA1 1
#define HAVE_ENCODER_LZMA2 1
#define HAVE_ENCODER_DELTA 1
#define HAVE_ENCODER_X86 1
#define HAVE_ENCODER_ARM 1
#define HAVE_ENCODER_ARM64 1
#define HAVE_ENCODER_ARMTHUMB 1
#define HAVE_ENCODER_IA64 1
#define HAVE_ENCODER_POWERPC 1
#define HAVE_ENCODER_SPARC 1
#define HAVE_ENCODER_RISCV 1

/* Decoders. */
#define HAVE_DECODERS 1
#define HAVE_DECODER_LZMA1 1
#define HAVE_DECODER_LZMA2 1
#define HAVE_DECODER_DELTA 1
#define HAVE_DECODER_X86 1
#define HAVE_DECODER_ARM 1
#define HAVE_DECODER_ARM64 1
#define HAVE_DECODER_ARMTHUMB 1
#define HAVE_DECODER_IA64 1
#define HAVE_DECODER_POWERPC 1
#define HAVE_DECODER_SPARC 1
#define HAVE_DECODER_RISCV 1
#define HAVE_LZIP_DECODER 1

/* Integrity checks. */
#define HAVE_CHECK_CRC32 1
#define HAVE_CHECK_CRC64 1
#define HAVE_CHECK_SHA256 1

/* Match finders (referenced by shared headers even in decode-only). */
#define HAVE_MF_HC3 1
#define HAVE_MF_HC4 1
#define HAVE_MF_BT2 1
#define HAVE_MF_BT3 1
#define HAVE_MF_BT4 1

/* Platform / compiler features (MSVC, per the oracle). */
#define HAVE_INTTYPES_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDBOOL_H 1
#define HAVE__BOOL 1
#define HAVE___BUILTIN_ASSUME_ALIGNED 1
#define TUKLIB_FAST_UNALIGNED_ACCESS 1
#define TUKLIB_SYMBOL_PREFIX lzma_
#define HAVE_VISIBILITY 0

/* x86/x64-only SIMD (CLMUL CRC, SSE). ARM64 uses the generic paths. */
#if defined(_M_X64) || defined(_M_IX86)
#  define HAVE_IMMINTRIN_H 1
#  define HAVE_USABLE_CLMUL 1
#  define HAVE__MM_MOVEMASK_EPI8 1
#endif

#endif /* ALIBAIN_LIBLZMA_CONFIG_H */
