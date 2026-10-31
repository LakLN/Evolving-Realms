param([switch]$Render, [switch]$Service)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot

function Invoke-EngineCheck {
    param([string]$Name, [string[]]$EngineArgs, [string]$Summary = '', [int]$ExpectedNativeErrors = 0)
    $output = & "$PSScriptRoot/godot.ps1" @EngineArgs
    $code = $LASTEXITCODE
    $log = ($output | Out-String)
    $log | Set-Content -Encoding UTF8 -LiteralPath ".tools/test-$Name.log"
    $errors = [regex]::Matches($log, '(?m)^(ERROR:|SCRIPT ERROR:)').Count
    if ($code -ne 0 -or $errors -ne $ExpectedNativeErrors -or ($Summary -ne '' -and $log -notmatch $Summary)) {
        Write-Host $log
        throw "$Name failed (exit $code, native errors $errors). See .tools/test-$Name.log"
    }
    if ($ExpectedNativeErrors -gt 0 -and ($log -notmatch 'SQL error: injected failure' -or $log -notmatch 'SQL error: table content_definitions already exists')) {
        throw 'Unexpected native errors in data suite'
    }
    Write-Host "PASS $Name (exit $code). Log: .tools/test-$Name.log"
    if ($Summary -ne '') { Write-Host ([regex]::Match($log, $Summary).Value) }
}

try {
    Invoke-EngineCheck -Name 'import' -EngineArgs @('--headless', '--editor', '--import')
    Invoke-EngineCheck -Name 'data' -EngineArgs @('--headless', '--script', 'res://tests/data_suite.gd') -Summary 'CHECKPOINT B: \d+ checks, 0 failures' -ExpectedNativeErrors 2
    Invoke-EngineCheck -Name 'world' -EngineArgs @('--headless', '--script', 'res://tests/world_suite.gd') -Summary 'CHECKPOINT C WORLD: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'gameplay' -EngineArgs @('--headless', '--script', 'res://tests/gameplay_suite.gd') -Summary 'CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'startup' -EngineArgs @('--headless', '--quit-after', '5')
    if ($Render) {
        Invoke-EngineCheck -Name 'rendered-gameplay' -EngineArgs @('--script', 'res://tests/gameplay_suite.gd') -Summary 'CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
    }
    if ($Service) {
        & '.venv/Scripts/python.exe' -E scripts/check_service.py
        if ($LASTEXITCODE -ne 0) { throw 'Optional service test failed' }
        & '.venv/Scripts/python.exe' -I -m pip check
        if ($LASTEXITCODE -ne 0) { throw 'Optional service dependency check failed' }
    }
    Write-Host 'All requested checks passed.'
    exit 0
} catch {
    Write-Error $_
    exit 1
}
