## Default: full regression (every suite). Lightweight runs during development
## (see docs/TESTING.md):
##   -Only skills,talents      only these checks (by name, e.g. rendered-skills)
##   -Smoke                    adds the invariant smoke set: data (persistence and
##                             migrations) and integration (real save/crash/load,
##                             no duplication, legacy saves)
## import and startup always run.
param([switch]$Render, [switch]$Service, [switch]$Export, [string[]]$Only = @(), [switch]$Smoke)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$selected = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
if ($Smoke) { $selected += @('data', 'integration') }

function Invoke-EngineCheck {
    param([string]$Name, [string[]]$EngineArgs, [string]$Summary = '', [string[]]$ExpectedErrors = @())
    if ($selected.Count -gt 0 -and $Name -notin @('import', 'startup') -and $Name -notin $selected) { return }
    $output = & "$PSScriptRoot/godot.ps1" @EngineArgs
    $code = $LASTEXITCODE
    $log = ($output | Out-String)
    $log | Set-Content -Encoding UTF8 -LiteralPath ".tools/test-$Name.log"
    $errors = [regex]::Matches($log, '(?m)^(ERROR:|SCRIPT ERROR:)').Count
    if ($code -ne 0 -or $errors -ne $ExpectedErrors.Count -or ($Summary -ne '' -and $log -notmatch $Summary)) {
        Write-Host $log
        throw "$Name failed (exit $code, native errors $errors). See .tools/test-$Name.log"
    }
    foreach ($expected in ($ExpectedErrors | Select-Object -Unique)) {
        $wanted = @($ExpectedErrors | Where-Object { $_ -eq $expected }).Count
        if ([regex]::Matches($log, "SQL error: $expected").Count -ne $wanted) { throw "Unexpected native errors in $Name" }
    }
    Write-Host "PASS $Name (exit $code). Log: .tools/test-$Name.log"
    if ($Summary -ne '') { Write-Host ([regex]::Match($log, $Summary).Value) }
}

try {
    Invoke-EngineCheck -Name 'import' -EngineArgs @('--headless', '--editor', '--import')
    Invoke-EngineCheck -Name 'data' -EngineArgs @('--headless', '--script', 'res://tests/data_suite.gd') -Summary 'CHECKPOINT B: \d+ checks, 0 failures' -ExpectedErrors @('injected failure', 'table content_definitions already exists')
    Invoke-EngineCheck -Name 'world' -EngineArgs @('--headless', '--script', 'res://tests/world_suite.gd') -Summary 'CHECKPOINT C WORLD: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'gameplay' -EngineArgs @('--headless', '--script', 'res://tests/gameplay_suite.gd') -Summary 'CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'interactions' -EngineArgs @('--headless', '--script', 'res://tests/interaction_suite.gd') -Summary 'CHECKPOINT D INTERACTIONS: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'interaction-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/interaction_gameplay_suite.gd') -Summary 'CHECKPOINT D GAMEPLAY: \d+ checks, 0 failures'
    # Three injected write locks (save, window close, Save & menu) are expected.
    Invoke-EngineCheck -Name 'integration' -EngineArgs @('--headless', '--script', 'res://tests/integration_suite.gd') -Summary 'CHECKPOINT E INTEGRATION: \d+ checks, 0 failures' -ExpectedErrors @('database is locked', 'database is locked', 'database is locked')
    Invoke-EngineCheck -Name 'combat' -EngineArgs @('--headless', '--script', 'res://tests/combat_suite.gd') -Summary 'M02 CHECKPOINT A COMBAT: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'combat-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/combat_gameplay_suite.gd') -Summary 'M02 CHECKPOINT A GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'survival' -EngineArgs @('--headless', '--script', 'res://tests/survival_suite.gd') -Summary 'M02 CHECKPOINT B SURVIVAL: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'survival-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/survival_gameplay_suite.gd') -Summary 'M02 CHECKPOINT B GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'equipment' -EngineArgs @('--headless', '--script', 'res://tests/equipment_suite.gd') -Summary 'M02 CHECKPOINT C EQUIPMENT: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'equipment-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/equipment_gameplay_suite.gd') -Summary 'M02 CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'talents' -EngineArgs @('--headless', '--script', 'res://tests/talent_suite.gd') -Summary 'M02 CHECKPOINT D TALENTS: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'talent-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/talent_gameplay_suite.gd') -Summary 'M02 CHECKPOINT D GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'skills' -EngineArgs @('--headless', '--script', 'res://tests/skill_suite.gd') -Summary 'M02 CHECKPOINT E SKILLS: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'skill-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/skill_gameplay_suite.gd') -Summary 'M02 CHECKPOINT E GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'effects' -EngineArgs @('--headless', '--script', 'res://tests/effect_suite.gd') -Summary 'M02 CHECKPOINT F EFFECTS: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'effect-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/effect_gameplay_suite.gd') -Summary 'M02 CHECKPOINT F GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'startup' -EngineArgs @('--headless', '--quit-after', '5')
    if ($Render) {
        Invoke-EngineCheck -Name 'rendered-effects' -EngineArgs @('--script', 'res://tests/effect_gameplay_suite.gd') -Summary 'M02 CHECKPOINT F GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-gameplay' -EngineArgs @('--script', 'res://tests/gameplay_suite.gd') -Summary 'CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-interactions' -EngineArgs @('--script', 'res://tests/interaction_gameplay_suite.gd') -Summary 'CHECKPOINT D GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-combat' -EngineArgs @('--script', 'res://tests/combat_gameplay_suite.gd') -Summary 'M02 CHECKPOINT A GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-survival' -EngineArgs @('--script', 'res://tests/survival_gameplay_suite.gd') -Summary 'M02 CHECKPOINT B GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-equipment' -EngineArgs @('--script', 'res://tests/equipment_gameplay_suite.gd') -Summary 'M02 CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-talents' -EngineArgs @('--script', 'res://tests/talent_gameplay_suite.gd') -Summary 'M02 CHECKPOINT D GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-skills' -EngineArgs @('--script', 'res://tests/skill_gameplay_suite.gd') -Summary 'M02 CHECKPOINT E GAMEPLAY: \d+ checks, 0 failures'
    }
    if ($Export) {
        # Rebuild builds/windows and run the acceptance on the exported release exe.
        & "$PSScriptRoot/export.ps1" -Verify -Render:$Render
        if ($LASTEXITCODE -ne 0) { throw 'Standalone export verification failed' }
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
