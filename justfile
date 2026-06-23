# Build automation for alibain — a Windows MSBuild build of libarchive.
# Pure hand-authored MSBuild (no vcpkg, no CMake in the build).
# Requires: just, and a Visual Studio 2026 Developer shell (msbuild + cl on PATH).

set windows-shell := ["cmd.exe", "/c"]

project := "msbuild\\archive.vcxproj"

# Map %PROCESSOR_ARCHITECTURE% to MSBuild platform: AMD64 -> x64, ARM64 -> ARM64.
_arch := env_var_or_default("PROCESSOR_ARCHITECTURE", "AMD64")
platform := if _arch == "ARM64" { "ARM64" } else { "x64" }

# Default: list recipes.
default:
    @just --list

# Fail early with a clear message when not in a VS 2026 Developer shell.
[private]
_require-devshell:
    @if not "%VisualStudioVersion%"=="18.0" (echo. & echo ERROR: needs a Visual Studio 2026 Developer shell. & echo Open "Developer Command Prompt/PowerShell for VS 2026" and retry. & echo Expected VisualStudioVersion=18.0 but found "%VisualStudioVersion%". & exit /b 1)

# Build one configuration/platform (zlib is pulled in via ProjectReference).
[private]
_msbuild configuration platform: _require-devshell
    msbuild {{project}} /p:Configuration={{configuration}} /p:Platform={{platform}} /m /nologo /v:minimal

# Build Debug (native arch).
build: (_msbuild "Debug" platform)

# Build Release (native arch).
build-release: (_msbuild "Release" platform)

# Build Debug+Release for x64+ARM64.
build-all: (_msbuild "Debug" "x64") (_msbuild "Release" "x64") (_msbuild "Debug" "ARM64") (_msbuild "Release" "ARM64")

# Build Release, then compile and run the ZIP smoke test (native arch).
smoke: build-release _require-devshell
    @if not exist temp\smoke mkdir temp\smoke
    cl /nologo /W3 /I libarchive\libarchive tests\smoke\smoke_zip.c /Fe:bin\{{platform}}\Release\smoke_zip.exe /Fo:temp\smoke\ /link bin\{{platform}}\Release\archive.lib
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_deflate.zip
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_store.zip
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_7z_copy.7z
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_7z_lzma1.7z
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_7z_lzma2.7z
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_rar4.rar
    bin\{{platform}}\Release\smoke_zip.exe tests\fixtures\sample_rar5.rar

# Stage the Release SDK (DLL + import lib + headers + licenses) for one platform,
# plus debug symbols under dist\symbols\<Platform> (joint-plan.md §10).
[private]
_stage platform: (_msbuild "Release" platform)
    @if exist dist\stage\{{platform}} rmdir /s /q dist\stage\{{platform}}
    @mkdir dist\stage\{{platform}}\bin dist\stage\{{platform}}\lib dist\stage\{{platform}}\include dist\stage\{{platform}}\licenses
    @copy /Y bin\{{platform}}\Release\archive.dll dist\stage\{{platform}}\bin\ >nul
    @copy /Y bin\{{platform}}\Release\archive.lib dist\stage\{{platform}}\lib\ >nul
    @copy /Y libarchive\libarchive\archive.h dist\stage\{{platform}}\include\ >nul
    @copy /Y libarchive\libarchive\archive_entry.h dist\stage\{{platform}}\include\ >nul
    @copy /Y COPYING dist\stage\{{platform}}\licenses\libarchive-COPYING.txt >nul
    @copy /Y extern\zlib\LICENSE dist\stage\{{platform}}\licenses\zlib-LICENSE.txt >nul
    @copy /Y extern\xz\COPYING dist\stage\{{platform}}\licenses\xz-COPYING.txt >nul
    @copy /Y extern\xz\COPYING.0BSD dist\stage\{{platform}}\licenses\xz-COPYING.0BSD.txt >nul
    @if exist dist\symbols\{{platform}} rmdir /s /q dist\symbols\{{platform}}
    @mkdir dist\symbols\{{platform}}
    @copy /Y bin\{{platform}}\Release\archive.pdb dist\symbols\{{platform}}\ >nul

# Stage the native-arch SDK.
stage: (_stage platform)

# Stage both architectures.
stage-all: (_stage "x64") (_stage "ARM64")

# Stage, then compile + run the smoke test against the STAGED SDK (staged headers
# and import lib) — catches staging/packaging regressions the dev-loop smoke misses.
smoke-stage: (_stage platform) _require-devshell
    @if exist temp\smoke-stage rmdir /s /q temp\smoke-stage
    @mkdir temp\smoke-stage
    cl /nologo /W3 /I dist\stage\{{platform}}\include tests\smoke\smoke_zip.c /Fe:temp\smoke-stage\smoke_zip.exe /Fo:temp\smoke-stage\ /link dist\stage\{{platform}}\lib\archive.lib
    @copy /Y dist\stage\{{platform}}\bin\archive.dll temp\smoke-stage\ >nul
    temp\smoke-stage\smoke_zip.exe tests\fixtures\sample_deflate.zip
    temp\smoke-stage\smoke_zip.exe tests\fixtures\sample_store.zip
    temp\smoke-stage\smoke_zip.exe tests\fixtures\sample_7z_lzma2.7z
    temp\smoke-stage\smoke_zip.exe tests\fixtures\sample_rar5.rar

# Zip the staged SDK for one platform.
[private]
_package platform: (_stage platform)
    @if exist dist\alibain-libarchive-{{platform}}.zip del /q dist\alibain-libarchive-{{platform}}.zip
    powershell -NoProfile -Command "Compress-Archive -Path dist\stage\{{platform}}\* -DestinationPath dist\alibain-libarchive-{{platform}}.zip -Force"

# Package the native-arch SDK zip.
package: (_package platform)

# Package both SDK zips.
package-all: (_package "x64") (_package "ARM64")

# Remove all build output.
clean:
    if exist bin rmdir /s /q bin
    if exist temp rmdir /s /q temp
    if exist dist rmdir /s /q dist

# Clean + build.
rebuild: clean build
