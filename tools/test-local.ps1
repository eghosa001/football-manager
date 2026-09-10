param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string[]]$Suites = @('player_stats_test', 'registration_safety_test', 'save_safety_test', 'career_ui_test', 'rc2_integration_test', 'test_runner', 'phase3_test_runner', 'phase45_test_runner', 'phase67_test_runner', 'phase89_test_runner', 'phase1011_test_runner', 'career_session_test', 'player_scouting_test', 'match_engine_v2_test', 'world_inspector_test'),
    [int]$TimeoutSeconds = 600
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$runRoot = Join-Path $repo ('.local-tests/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $runRoot | Out-Null
function Invoke-Check([string]$Name, [string]$Arguments) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Godot
    $info.Arguments = '--headless --path "' + $repo + '" ' + $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    # Each suite gets its own user:// directory, separate from actual careers.
    $suiteData = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Force $suiteData | Out-Null
    $info.EnvironmentVariables['APPDATA'] = $suiteData
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        & taskkill /PID $process.Id /T /F | Out-Null
        $process.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $runRoot ($Name + '.log')), $stdout.Result + $stderr.Result)
        throw "$Name timed out after $TimeoutSeconds seconds. Logs: $runRoot"
    }
    $log = $stdout.Result + $stderr.Result
    [IO.File]::WriteAllText((Join-Path $runRoot ($Name + '.log')), $log)
    if ($process.ExitCode -ne 0 -or $log -match '(?m)(SCRIPT ERROR:|ERROR:|Assertion failed)' -or ($Name -ne 'import' -and $log -notmatch 'PASS')) {
        Write-Output $log
        throw "$Name failed. Logs: $runRoot"
    }
    Write-Output "PASS $Name"
}
Invoke-Check 'import' '--editor --import --quit'
foreach ($suite in $Suites) { Invoke-Check $suite ('--script res://tests/' + $suite + '.gd') }
Write-Output "Logs: $runRoot"
