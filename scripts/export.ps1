param([switch]$Verify, [switch]$Render)
## Builds the standalone Windows x64 release into builds/windows. -Verify runs the
## opt-in acceptance on the exported exe (separate temp database, other working dir).
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$templates = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
if (!(Test-Path -LiteralPath (Join-Path $templates 'windows_release_x86_64.exe'))) {
    throw "Godot 4.7.2 export templates missing in $templates. See README.md (Standalone build)."
}
$build = Join-Path $projectRoot 'builds/windows'
if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build -Recurse -Force }
New-Item -ItemType Directory -Force -Path $build | Out-Null
$output = & "$PSScriptRoot/godot.ps1" --headless --export-release windows builds/windows/EvolvingRealms.exe
$code = $LASTEXITCODE
($output | Out-String) | Set-Content -Encoding UTF8 -LiteralPath '.tools/export.log'
foreach ($file in @('EvolvingRealms.exe', 'EvolvingRealms.pck', 'libgdsqlite.windows.template_release.x86_64.dll')) {
    if (!(Test-Path -LiteralPath (Join-Path $build $file))) { $code = 1 }
}
if ($code -ne 0 -or ($output | Out-String) -match '(?m)^(ERROR:|SCRIPT ERROR:)') { throw 'Export failed. See .tools/export.log' }

$licenses = New-Item -ItemType Directory -Force -Path (Join-Path $build 'licenses')
Copy-Item 'addons/godot-sqlite/LICENSE.md' (Join-Path $licenses 'godot-sqlite-LICENSE.md')
foreach ($notice in @('GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt')) {
    if (Test-Path -LiteralPath ".tools/$notice") { Copy-Item ".tools/$notice" (Join-Path $licenses $notice) }
    else { Write-Warning "Missing .tools/$notice; add Godot's license notices before distributing." }
}
@'
Evolving Realms - Milestone 01 (Windows x64)

Run EvolvingRealms.exe. Keep EvolvingRealms.pck and the libgdsqlite DLL beside it.
No Python, server, internet or account is needed.

Saves: %APPDATA%\Godot\app_userdata\Evolving Realms\realms.sqlite
(shared with runs started from the Godot editor; never stored in this folder).

Controls: WASD / arrows move (walk into a hostile creature to attack), E gather/open/pick up,
F attack adjacent target, Tab next target, Space wait, R rest, I inventory (U use/equip),
C character & gear (U unequip),
Ctrl+S save, Esc close inventory or save & return to menu.
Watch Hunger/Thirst under the HP bar: eat berries/meat, drink spring water, apply herbs.
Normal mode: autosaves when safe; death reloads your last save.
Permadeath: saves every risky action (and every 10 safe ones); death ends the run.
Closing the window saves first. If saving fails, close again to quit without saving.
'@ | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $build 'README.txt')
Write-Host "PASS export: $build"
Get-ChildItem -LiteralPath $build | ForEach-Object { Write-Host ("  {0,-52} {1,12:N0}" -f $_.Name, $_.Length) }

if (!$Verify) { exit 0 }
$exe = Join-Path $build 'EvolvingRealms.exe'
$work = Join-Path ([IO.Path]::GetTempPath()) ('evolving-realms-standalone-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $work | Out-Null
Write-Host "Standalone verification folder (outside build): $work"
function Invoke-Standalone([string]$Name, [string[]]$Arguments) {
    $stdout = Join-Path $work "$Name.out.log"
    $stderr = Join-Path $work "$Name.err.log"
    # Working directory is the temp folder, proving no dependency on the project/editor folder.
    $process = Start-Process -FilePath $exe -ArgumentList $Arguments -WorkingDirectory $work -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $log = (Get-Content -Raw -LiteralPath $stdout) + (Get-Content -Raw -LiteralPath $stderr)
    return @{ Code = $process.ExitCode; Log = $log }
}
$database = Join-Path $work 'acceptance.sqlite'
$display = @('--headless')
if ($Render) { $display = @() }
foreach ($phase in @('write', 'crash', 'verify')) {
    $result = Invoke-Standalone $phase ($display + @('--quit-after', '30000', '--', "--database=$database", "--acceptance=$phase"))
    $result.Log | Set-Content -Encoding UTF8 -LiteralPath ".tools/standalone-$phase.log"
    if ($phase -eq 'crash') {
        if ($result.Log -notmatch 'terminating without saving' -or $result.Log -match 'FAIL:') { throw "Standalone crash phase failed. See .tools/standalone-crash.log" }
        Write-Host 'PASS standalone crash (process terminated with unsaved actions)'
        continue
    }
    $summary = [regex]::Match($result.Log, "STANDALONE ACCEPTANCE ${phase}: \d+ checks, \d+ failures \(\w+\)").Value
    if ($result.Code -ne 0 -or $summary -notmatch ' 0 failures' -or $result.Log -match '(?m)^(ERROR:|SCRIPT ERROR:)') {
        Write-Host $result.Log
        throw "Standalone $phase failed (exit $($result.Code)). See .tools/standalone-$phase.log"
    }
    Write-Host "PASS standalone $phase - $summary"
}
$result = Invoke-Standalone 'refuse-default' @('--headless', '--quit-after', '30000', '--', '--acceptance=write')
if ($result.Code -ne 2) { throw 'Standalone acceptance did not refuse the personal save file' }
Write-Host 'PASS standalone refuses acceptance against the default save'
if ($Render) { Write-Host "Screenshots: $work\standalone-*.png" }
Write-Host 'Standalone verification passed.'
exit 0
