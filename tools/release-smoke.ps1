param(
    [Parameter(Mandatory=$true)]
    [string]$Executable,
    [string]$LogPath = 'build/windows/runtime.log',
    [int]$TimeoutMilliseconds = 180000
)

$ErrorActionPreference = 'Stop'

$resolved = Resolve-Path $Executable
$stderrPath = $LogPath + '.err'
New-Item -ItemType Directory -Force -Path (Split-Path $LogPath -Parent) | Out-Null
Remove-Item $LogPath,$stderrPath -Force -ErrorAction SilentlyContinue

$proc = Start-Process -FilePath $resolved -ArgumentList @('--headless','--','--release-smoke') -PassThru -NoNewWindow -RedirectStandardOutput $LogPath -RedirectStandardError $stderrPath
if (-not $proc.WaitForExit($TimeoutMilliseconds)) {
    try { $proc.Kill($true) } catch {}
    throw 'Windows release smoke timed out.'
}

$proc.Refresh()
$exitCode = $proc.ExitCode
$stdout = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { '' }
$stderr = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { '' }
Write-Host $stdout
if ($stderr) { Write-Host $stderr }

if ($null -ne $exitCode -and $exitCode -ne 0) {
    throw "Windows release smoke exited with code $exitCode."
}
if ($stdout -notmatch 'RELEASE SMOKE PASS') {
    throw 'Windows release smoke did not emit PASS marker.'
}
if (($stdout + "`n" + $stderr) -match 'SCRIPT ERROR:') {
    throw 'Windows release smoke reported a script error.'
}

Write-Host '[CI] Windows packaged release smoke passed.'
