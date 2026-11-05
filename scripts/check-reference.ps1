## Bounded reference-area startup, traversal, controls, persistence and native captures.
param([switch]$Headless, [int]$TimeoutSeconds = 120)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engine)) { throw 'Pinned Godot engine missing under .tools/godot; see scripts/godot.ps1.' }
if ($TimeoutSeconds -lt 10 -or $TimeoutSeconds -gt 180) { throw 'Timeout must be 10..180 seconds.' }
function Invoke-BoundedReference {
    param([string]$Tag, [string[]]$EngineArgs)
    $outFile = Join-Path $projectRoot ".tools/$Tag.out.log"
    $errFile = Join-Path $projectRoot ".tools/$Tag.err.log"
    $arguments = @('--path', ('"' + $projectRoot + '"')) + $EngineArgs
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        throw "$Tag exceeded $TimeoutSeconds seconds; process stopped. Logs: $outFile, $errFile"
    }
    $process.Refresh()
    Get-Content -LiteralPath $outFile
    Get-Content -LiteralPath $errFile
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $errFile -Pattern 'SCRIPT ERROR:|^ERROR:')) { throw "$Tag failed (exit $($process.ExitCode))" }
    if ($Tag -eq 'reference-native' -and -not (Select-String -LiteralPath $outFile -Pattern 'REFERENCE AREA: \d+ checks, 0 failures')) { throw 'Reference suite did not report completion.' }
}
Invoke-BoundedReference 'reference-import' @('--headless', '--editor', '--import')
$referenceArgs = @('--script', 'res://tests/reference_area_suite.gd')
if ($Headless) { $referenceArgs = @('--headless') + $referenceArgs }
Invoke-BoundedReference 'reference-native' $referenceArgs
