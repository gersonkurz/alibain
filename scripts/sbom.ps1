# Write the CycloneDX SBOM for the staged archive.dll: libarchive plus the xz (liblzma) and zlib
# compiled into it, each at the version and commit this checkout builds from.
#
# The DLL carries no version resource and links xz and zlib statically, so nothing reading the
# file can tell what is in it; the build can. Consumers (ptraced-qt's installer) attach this
# document to archive.dll, which is what lets a vulnerability scanner match the three.
#
# Deterministic: no timestamps, no serial number - the same checkout writes the same bytes.
param([Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Get-Commit([string]$dir) {
    $c = (& git -C (Join-Path $root $dir) rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $c -notmatch '^[0-9a-f]{40}$') { throw "cannot read the commit of $dir" }
    $c
}
function Get-Define([string]$file, [string]$macro) {
    $line = Select-String -Path (Join-Path $root $file) -Pattern "#define\s+$macro\s+(\S+)" | Select-Object -First 1
    if (-not $line) { throw "$macro not found in $file" }
    $line.Matches[0].Groups[1].Value.Trim('"')
}

$libarchive = Get-Define 'libarchive\libarchive\archive.h' 'ARCHIVE_VERSION_ONLY_STRING'
$lzmaH = 'extern\xz\src\liblzma\api\lzma\version.h'
$xz = '{0}.{1}.{2}' -f (Get-Define $lzmaH 'LZMA_VERSION_MAJOR'), (Get-Define $lzmaH 'LZMA_VERSION_MINOR'), (Get-Define $lzmaH 'LZMA_VERSION_PATCH')
$zlib = Get-Define 'extern\zlib\zlib.h' 'ZLIB_VERSION'

function New-Component([string]$ref, [string]$name, [string]$version, [string]$license, [string]$cpe, [string]$repo, [string]$commit) {
    [ordered]@{
        type        = 'library'
        'bom-ref'   = $ref
        name        = $name
        version     = $version
        licenses    = @([ordered]@{ license = [ordered]@{ id = $license } })
        cpe         = $cpe
        purl        = "pkg:github/$repo@$commit"
        description = "built from $repo at $commit"
    }
}

$doc = [ordered]@{
    bomFormat    = 'CycloneDX'
    specVersion  = '1.6'
    version      = 1
    metadata     = [ordered]@{
        component = [ordered]@{
            type        = 'library'
            'bom-ref'   = 'archive-dll'
            name        = 'archive.dll'
            version     = $libarchive
            description = "alibain build of libarchive at $(Get-Commit '.')"
        }
    }
    components   = @(
        (New-Component 'libarchive' 'libarchive' $libarchive 'BSD-2-Clause' "cpe:2.3:a:libarchive:libarchive:${libarchive}:*:*:*:*:*:*:*" 'libarchive/libarchive' (Get-Commit 'libarchive'))
        (New-Component 'xz' 'xz' $xz '0BSD' "cpe:2.3:a:tukaani:xz:${xz}:*:*:*:*:*:*:*" 'tukaani-project/xz' (Get-Commit 'extern\xz'))
        (New-Component 'zlib' 'zlib' $zlib 'Zlib' "cpe:2.3:a:zlib:zlib:${zlib}:*:*:*:*:*:*:*" 'madler/zlib' (Get-Commit 'extern\zlib'))
    )
    dependencies = @([ordered]@{ ref = 'archive-dll'; dependsOn = @('libarchive', 'xz', 'zlib') })
}

New-Item -ItemType Directory -Force (Split-Path -Parent $Out) | Out-Null
# UTF-8 without a BOM: JSON parsers are not required to accept one, and Go's does not.
[IO.File]::WriteAllText($Out, ($doc | ConvertTo-Json -Depth 10) + "`n", (New-Object Text.UTF8Encoding $false))
"wrote $Out (libarchive $libarchive, xz $xz, zlib $zlib)"
