# Zip the staged SDK dist\stage\<Platform> into dist\alibain-libarchive-<Platform>.zip.
#
# A script run with -File, not an inline `powershell -Command "..."` in the justfile: just hands
# that line to cmd /c with the inner quotes escaped as \", which cmd does not understand, so
# PowerShell received the whole command as one string literal, echoed it, and exited 0 without
# writing a zip.
#
# ZipFile rather than Compress-Archive: Windows PowerShell 5.1's Compress-Archive stores entry
# names with backslashes, which non-Windows unzip tools do not treat as directories.
param([Parameter(Mandatory)][string]$Platform)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $root "dist\stage\$Platform"
$zip = Join-Path $root "dist\alibain-libarchive-$Platform.zip"

if (-not (Test-Path (Join-Path $stage 'bin\archive.dll'))) { throw "nothing staged in $stage" }
if (Test-Path $zip) { Remove-Item -Force $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
"wrote dist\alibain-libarchive-$Platform.zip ($((Get-Item $zip).Length) bytes)"
