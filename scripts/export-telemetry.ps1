param(
    [Parameter(Mandatory=$true)][string]$RunId,
    [string]$DatabasePath = 'user://realms.sqlite',
    [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
$godotArgs = @(
    '--headless',
    '--script',
    'res://tools/export_run_telemetry.gd',
    '--',
    "--run-id=$RunId",
    "--database=$DatabasePath"
)
if ($OutputPath -ne '') { $godotArgs += "--output=$OutputPath" }
& (Join-Path $PSScriptRoot 'godot.ps1') @godotArgs
exit $LASTEXITCODE
