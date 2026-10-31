param([Parameter(ValueFromRemainingArguments=$true)][string[]]$GodotArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$executable = Join-Path $projectRoot '.tools/godot/Godot_v4.7.2-stable_win64.exe'
if (!(Test-Path -LiteralPath $executable)) { throw 'Install Godot as described in README.md.' }
$stdout = Join-Path $projectRoot '.tools/godot-stdout.log'
$stderr = Join-Path $projectRoot '.tools/godot-stderr.log'
$arguments = @('--path', ('"' + $projectRoot + '"')) + $GodotArgs
$process = Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Get-Content -LiteralPath $stdout
Get-Content -LiteralPath $stderr
exit $process.ExitCode
