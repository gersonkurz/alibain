# Prove the Release build is reproducible: build from clean twice, in the same tree with the
# same toolchain, and require byte-identical archive.dll and archive.lib (common.props: /Brepro,
# /PDBALTPATH). Needs a VS 2026 Developer shell (msbuild on PATH). Exits 1 on any difference.
param([Parameter(Mandatory)][string]$Platform)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$outputs = @("bin\$Platform\Release\archive.dll", "bin\$Platform\Release\archive.lib")

function Build-Clean {
    foreach ($d in "bin\$Platform\Release", "temp\$Platform\Release") {
        $p = Join-Path $root $d
        if (Test-Path $p) { Remove-Item -Recurse -Force $p }
    }
    # Out-Host: anything msbuild prints must not become part of this function's return value.
    & msbuild (Join-Path $root 'msbuild\archive.vcxproj') /p:Configuration=Release "/p:Platform=$Platform" /m /nologo /v:minimal | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "msbuild failed ($LASTEXITCODE)" }
    $h = @{}
    foreach ($o in $outputs) {
        $h[$o] = (Get-FileHash -Algorithm SHA256 (Join-Path $root $o)).Hash
        if ($h[$o] -notmatch '^[0-9A-F]{64}$') { throw "no hash for $o" }
    }
    , $h
}

$first = Build-Clean
$second = Build-Clean
$bad = 0
foreach ($o in $outputs) {
    $same = $first[$o] -eq $second[$o]
    if (-not $same) { $bad++ }
    '{0}  {1}  {2}' -f ($(if ($same) { 'SAME' } else { 'DIFF' })), $first[$o], $o
    if (-not $same) { '      second build: {0}' -f $second[$o] }
}
if ($bad) { "NOT reproducible: $bad of $($outputs.Count) outputs differ between two clean builds"; exit 1 }
"reproducible: $($outputs.Count) outputs byte-identical across two clean builds"
