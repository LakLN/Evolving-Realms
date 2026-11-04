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
    Invoke-EngineCheck -Name 'm03-world' -EngineArgs @('--headless', '--script', 'res://tests/m03_world_suite.gd') -Summary 'M03 STRUCTURED WORLD: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'world' -EngineArgs @('--headless', '--script', 'res://tests/world_suite.gd') -Summary 'CHECKPOINT C WORLD: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'run01-world' -EngineArgs @('--headless', '--script', 'res://tests/run01_world_suite.gd') -Summary 'RUN01 WORLD: \d+ checks, 0 failures'
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
    Invoke-EngineCheck -Name 'ui-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/ui_gameplay_suite.gd') -Summary 'UI GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'build-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/build_gameplay_suite.gd') -Summary 'BUILD GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'systems-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/systems_gameplay_suite.gd') -Summary 'SYSTEMS GAMEPLAY: \d+ checks, 0 failures'
    if ($selected.Count -eq 0 -or 'ai-content' -in $selected -or 'ai-world' -in $selected -or 'discoveries' -in $selected) {
        # unittest reports on stderr; under 'Stop' Windows PowerShell 5.1 would throw on it.
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $pythonLog = & '.venv/Scripts/python.exe' -E -m unittest discover -s tests -p test_ai_service.py 2>&1
        $pythonCode = $LASTEXITCODE
        $ErrorActionPreference = $previous
        $pythonLog | Out-String | Set-Content -Encoding UTF8 -LiteralPath '.tools/test-ai-provider.log'
        if ($pythonCode -ne 0) { Write-Host ($pythonLog | Out-String); throw 'Offline AI provider tests failed' }
        Write-Host 'PASS offline AI provider tests (no paid calls). Log: .tools/test-ai-provider.log'
    }
    Invoke-EngineCheck -Name 'ai-content' -EngineArgs @('--headless', '--script', 'res://tests/ai_content_suite.gd') -Summary 'M02 CHECKPOINT G AI CONTENT: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'ai-world' -EngineArgs @('--headless', '--script', 'res://tests/ai_world_suite.gd') -Summary 'M02 CHECKPOINT H AI WORLD: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'discoveries' -EngineArgs @('--headless', '--script', 'res://tests/discovery_suite.gd') -Summary 'M02 CHECKPOINT I DISCOVERIES: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'discovery-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/discovery_gameplay_suite.gd') -Summary 'M02 CHECKPOINT I GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'map' -EngineArgs @('--headless', '--script', 'res://tests/map_gameplay_suite.gd') -Summary 'M03 MAP GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'run01-content' -EngineArgs @('--headless', '--script', 'res://tests/run01_content_suite.gd') -Summary 'RUN01 CONTENT: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'telemetry' -EngineArgs @('--headless', '--script', 'res://tests/telemetry_suite.gd') -Summary 'RUN 01 TELEMETRY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'realtime' -EngineArgs @('--headless', '--script', 'res://tests/realtime_suite.gd') -Summary 'M03 REALTIME: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'realtime-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/realtime_gameplay_suite.gd') -Summary 'M03 REALTIME GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'm03-integration' -EngineArgs @('--headless', '--script', 'res://tests/m03_integration_suite.gd') -Summary 'M03 INTEGRATION: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'land-package' -EngineArgs @('--headless', '--script', 'res://tests/land_package_suite.gd') -Summary 'M05 LAND PACKAGE: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'm04-world' -EngineArgs @('--headless', '--script', 'res://tests/m04_world_suite.gd') -Summary 'M04 WORLD: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'm04-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/m04_gameplay_suite.gd') -Summary 'M04 GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'snow-mountain' -EngineArgs @('--headless', '--script', 'res://tests/snow_mountain_suite.gd') -Summary 'M05 SNOW MOUNTAIN: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'snow-content' -EngineArgs @('--headless', '--script', 'res://tests/snow_content_suite.gd') -Summary 'M05 SNOW CONTENT: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'snow-gameplay' -EngineArgs @('--headless', '--script', 'res://tests/snow_mountain_gameplay_suite.gd') -Summary 'M05 SNOW GAMEPLAY: \d+ checks, 0 failures'
    Invoke-EngineCheck -Name 'art-import' -EngineArgs @('--headless', '--script', 'res://tools/art/import_check.gd') -Summary 'ART IMPORT: \d+ checks, 0 failures'
    # Keep smoke startup away from the player's database, including opt-in World tests.
    $startupDatabase = 'user://startup-tests/' + [guid]::NewGuid().ToString() + '.sqlite'
    Invoke-EngineCheck -Name 'startup' -EngineArgs @('--headless', '--quit-after', '5', '--', ('--database=' + $startupDatabase))
    if ($Render) {
        Invoke-EngineCheck -Name 'rendered-realtime' -EngineArgs @('--script', 'res://tests/realtime_gameplay_suite.gd') -Summary 'M03 REALTIME GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-snow-gameplay' -EngineArgs @('--script', 'res://tests/snow_mountain_gameplay_suite.gd') -Summary 'M05 SNOW GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-m04-gameplay' -EngineArgs @('--script', 'res://tests/m04_gameplay_suite.gd') -Summary 'M04 GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-m03-integration' -EngineArgs @('--script', 'res://tests/m03_integration_suite.gd') -Summary 'M03 INTEGRATION: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-discoveries' -EngineArgs @('--script', 'res://tests/discovery_gameplay_suite.gd') -Summary 'M02 CHECKPOINT I GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-effects' -EngineArgs @('--script', 'res://tests/effect_gameplay_suite.gd') -Summary 'M02 CHECKPOINT F GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-gameplay' -EngineArgs @('--script', 'res://tests/gameplay_suite.gd') -Summary 'CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-interactions' -EngineArgs @('--script', 'res://tests/interaction_gameplay_suite.gd') -Summary 'CHECKPOINT D GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-combat' -EngineArgs @('--script', 'res://tests/combat_gameplay_suite.gd') -Summary 'M02 CHECKPOINT A GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-survival' -EngineArgs @('--script', 'res://tests/survival_gameplay_suite.gd') -Summary 'M02 CHECKPOINT B GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-equipment' -EngineArgs @('--script', 'res://tests/equipment_gameplay_suite.gd') -Summary 'M02 CHECKPOINT C GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-talents' -EngineArgs @('--script', 'res://tests/talent_gameplay_suite.gd') -Summary 'M02 CHECKPOINT D GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-skills' -EngineArgs @('--script', 'res://tests/skill_gameplay_suite.gd') -Summary 'M02 CHECKPOINT E GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-ui' -EngineArgs @('--script', 'res://tests/ui_gameplay_suite.gd') -Summary 'UI GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-build' -EngineArgs @('--script', 'res://tests/build_gameplay_suite.gd') -Summary 'BUILD GAMEPLAY: \d+ checks, 0 failures'
        Invoke-EngineCheck -Name 'rendered-systems' -EngineArgs @('--script', 'res://tests/systems_gameplay_suite.gd') -Summary 'SYSTEMS GAMEPLAY: \d+ checks, 0 failures'
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
