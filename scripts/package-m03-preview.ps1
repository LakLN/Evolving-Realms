param([Parameter(Mandatory=$true)][string]$Destination)
## Stages the verified builds/windows export (run export.ps1 -Verify first) as a separate
## M03 internal playtest folder. Saves are isolated twice: override.cfg moves user:// to
## %APPDATA%\EvolvingRealms-M03-Preview (so even a double-clicked exe never opens the personal
## Godot\app_userdata\Evolving Realms\realms.sqlite), and the launcher passes that database
## explicitly after `--`. The official builds/windows folder is never written.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$build = Join-Path $projectRoot 'builds/windows'
foreach ($file in @('EvolvingRealms.exe', 'EvolvingRealms.pck', 'libgdsqlite.windows.template_release.x86_64.dll')) {
    if (!(Test-Path -LiteralPath (Join-Path $build $file))) { throw "Missing $file; run scripts/export.ps1 -Verify first." }
}
$Destination = [IO.Path]::GetFullPath($Destination)
if ((Split-Path $Destination -Leaf) -eq 'windows') { throw 'Refusing to stage into an official builds/windows folder.' }
$marker = 'M03-PREVIEW.txt'
if ((Test-Path -LiteralPath $Destination) -and (Get-ChildItem -LiteralPath $Destination -Force | Select-Object -First 1)) {
    if (!(Test-Path -LiteralPath (Join-Path $Destination $marker))) { throw "$Destination is not an M03 preview folder; not overwriting it." }
    Remove-Item -LiteralPath $Destination -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -Path (Join-Path $build '*') -Destination $Destination -Recurse

@'
[application]

config/use_custom_user_dir=true
config/custom_user_dir_name="EvolvingRealms-M03-Preview"
'@ | Set-Content -Encoding ASCII -LiteralPath (Join-Path $Destination 'override.cfg')

@'
param([string]$Database = (Join-Path $env:APPDATA 'EvolvingRealms-M03-Preview\realms.sqlite'), [switch]$Wait, [switch]$PassThru)
## Starts the M03 preview on its own SQLite database. Godot only reads game options after a
## literal `--`, so the database is passed as one quoted argument: -- "--database=<path>".
$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'EvolvingRealms.exe'
if (!(Test-Path -LiteralPath $exe)) { throw "EvolvingRealms.exe not found beside this launcher." }
$Database = [IO.Path]::GetFullPath($Database)
$personal = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Godot\app_userdata\Evolving Realms')) + '\'
if ($Database.StartsWith($personal, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing the personal save folder: $Database" }
if ($Database.Contains('"') -or $Database.EndsWith('\')) { throw "Unsupported database path: $Database" }
New-Item -ItemType Directory -Force -Path (Split-Path $Database -Parent) | Out-Null
$arguments = '-- "--database=' + $Database + '"'
Write-Host "Evolving Realms M03 preview - database: $Database"
$process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -PassThru -Wait:$Wait
if ($PassThru) { $process }
'@ | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Destination 'Launch-M03-Preview.ps1')

@'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-M03-Preview.ps1" %*
'@ | Set-Content -Encoding ASCII -LiteralPath (Join-Path $Destination 'Launch-M03-Preview.cmd')

$commit = (& git -C $projectRoot rev-parse --short HEAD)
@"
Evolving Realms - M03 internal playtest preview (Windows x64), commit $commit

Start with Launch-M03-Preview.cmd (double-click) or:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Launch-M03-Preview.ps1
Optional: -Database "D:\some folder\other.sqlite" to use another preview database.

Preview saves: %APPDATA%\EvolvingRealms-M03-Preview\realms.sqlite
This preview never uses the personal save of the official build
(%APPDATA%\Godot\app_userdata\Evolving Realms\realms.sqlite): override.cfg in this folder
moves the game's data folder, and the launcher passes the preview database explicitly.
Keep override.cfg beside the exe. Do not copy preview saves into the official build:
M03 runs store a map waypoint that the Milestone 02 build does not accept.

New Worlds default to structured regions and new Runs to real time (M to open the map,
N for the minimap). See README.txt for the remaining controls.
"@ | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Destination $marker)
Write-Host "PASS M03 preview staged: $Destination"
Get-ChildItem -LiteralPath $Destination | ForEach-Object { Write-Host ("  {0,-52} {1,12:N0}" -f $_.Name, $_.Length) }
