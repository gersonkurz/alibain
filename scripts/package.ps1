# Zip the staged SDK dist\stage\<Platform> into dist\alibain-libarchive-<Platform>.zip.
#
# A script run with -File, not an inline `powershell -Command "..."` in the justfile: just hands
# that line to cmd /c with the inner quotes escaped as \", which cmd does not understand, so
# PowerShell received the whole command as one string literal, echoed it, and exited 0 without
# writing a zip.
#
# Entries are added one by one with '/'-separated names. Under Windows PowerShell 5.1 both
# Compress-Archive and ZipFile.CreateFromDirectory store names with backslashes (the .NET
# Framework only uses '/' for applications targeting 4.6.1+, which powershell.exe is not), and
# non-Windows unzip tools then do not treat them as directories. v1.0.0's zips have this defect.
param([Parameter(Mandatory)][string]$Platform)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $root "dist\stage\$Platform"
$zip = Join-Path $root "dist\alibain-libarchive-$Platform.zip"

if (-not (Test-Path (Join-Path $stage 'bin\archive.dll'))) { throw "nothing staged in $stage" }
$stage = (Resolve-Path $stage).Path.TrimEnd('\')
if (Test-Path $zip) { Remove-Item -Force $zip }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -Path $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
        $name = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $_.FullName, $name, [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose() }

# Check what was written, from the raw entry names (tools such as Python's zipfile rewrite '\'
# to '/' when reading on Windows, which hides exactly this defect).
$check = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
    $names = @($check.Entries | ForEach-Object { $_.FullName })
} finally { $check.Dispose() }
$bad = @($names | Where-Object { $_.Contains('\') })
if ($bad.Count) { throw "backslash in zip entry names: $($bad -join ', ')" }
if ($names -notcontains 'bin/archive.dll') { throw "bin/archive.dll missing from $zip" }
"wrote dist\alibain-libarchive-$Platform.zip ($($names.Count) files, $((Get-Item $zip).Length) bytes)"
