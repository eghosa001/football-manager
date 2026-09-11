param(
    [Parameter(Mandatory=$true)][string]$ExePath,
    [string]$LogPath = 'build/windows/runtime.log',
    [int]$TimeoutMs = 180000
)

$ErrorActionPreference = 'Stop'

$err = "$LogPath.err"
$proc = Start-Process -FilePath (Resolve-Path $ExePath) -ArgumentList @('--headless','--','--release-smoke') -PassThru -NoNewWindow -RedirectStandardOutput $LogPath -RedirectStandardError $err
if (-not $proc.WaitForExit($TimeoutMs)) { try { $proc.Kill($true) } catch {}; throw 'Release smoke timed out.' }
$proc.Refresh()
$exitCode = $proc.ExitCode
$stdout = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { '' }
$stderr = if (Test-Path $err) { Get-Content $err -Raw } else { '' }
Write-Host $stdout
if ($stderr) { Write-Host $stderr }
if ($null -ne $exitCode -and $exitCode -ne 0) { throw "Release smoke exited with code $exitCode." }
if ($stdout -notmatch 'RELEASE SMOKE PASS') { throw 'Release smoke did not emit PASS marker.' }
if (($stdout + "`n" + $stderr) -match 'SCRIPT ERROR:') { throw 'Release smoke reported a script error.' }
