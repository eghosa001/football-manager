param(
    [Parameter(Mandatory=$true)][string]$Script,
    [int]$TimeoutSeconds = 600,
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = 'Stop'

function Resolve-Godot {
    if ($env:GODOT_EXE -and (Test-Path $env:GODOT_EXE)) { return $env:GODOT_EXE }
    if ($env:GODOT_PATH -and (Test-Path $env:GODOT_PATH)) { return $env:GODOT_PATH }
    foreach ($name in @('godot','godot4')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, (Join-Path $env:USERPROFILE 'Desktop'), (Join-Path $env:USERPROFILE 'Downloads')) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($root in $roots) {
        $candidate = Get-ChildItem -Path $root -Filter 'Godot*.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object { if ($_.Name -match '4\.7\.2') { 0 } else { 1 } }, LastWriteTime -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    throw 'Godot is not installed or not visible to the self-hosted runner. Set GODOT_PATH or add Godot to PATH.'
}

$godot = Resolve-Godot
Write-Host "Using Godot: $godot"
& $godot --version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$log = Join-Path $env:RUNNER_TEMP ("godot-" + ([IO.Path]::GetFileNameWithoutExtension($Script)).Replace('/','_') + '.log')
if ($Script -eq 'import') { $args = @('--headless','--editor','--path','.', '--import','--quit') }
else { $args = @('--headless','--path','.', '--script', "res://$Script") + $ExtraArgs }
$proc = Start-Process -FilePath $godot -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError ($log + '.err')
if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) { try { $proc.Kill($true) } catch {}; throw "Godot timed out after $TimeoutSeconds seconds: $Script" }
if (Test-Path ($log + '.err')) { Get-Content ($log + '.err') | Add-Content $log }
Get-Content $log
$text = Get-Content $log -Raw
if ($proc.ExitCode -ne 0) { exit $proc.ExitCode }
if ($text -match 'SCRIPT ERROR:|ERROR:|Assertion failed') { throw "Godot reported errors in $Script" }
if ($Script -ne 'import' -and $text -notmatch 'PASS') { throw "No PASS marker found in $Script" }
