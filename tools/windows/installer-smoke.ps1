param(
  [Parameter(Mandatory=$true)][string]$InstallerPath,
  [string]$InstallDir = "$env:TEMP\FootballDynastyAcceptance",
  [string]$SaveProbe = "$env:APPDATA\Godot\app_userdata\Football Dynasty"
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $InstallerPath)) { throw "Installer not found: $InstallerPath" }
Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue

Write-Host "Installing to $InstallDir"
$proc = Start-Process -FilePath $InstallerPath -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$InstallDir" -Wait -PassThru
if ($proc.ExitCode -ne 0) { throw "Installer exited with $($proc.ExitCode)" }
$exe = Join-Path $InstallDir 'FootballDynasty.exe'
if (-not (Test-Path $exe)) { throw 'Installed executable missing.' }

$log = Join-Path $InstallDir 'acceptance-runtime.log'
& $exe --headless --quit-after 8 --verbose *> $log
if ($LASTEXITCODE -ne 0) { throw "Installed game smoke failed with $LASTEXITCODE" }
if ((Get-Item $exe).Length -le 0) { throw 'Installed executable is empty.' }

# Save data is intentionally external to the installation directory. If a save probe exists,
# remember its hashes so a subsequent upgrade/uninstall job can prove preservation.
$manifest = @{}
if (Test-Path $SaveProbe) {
  Get-ChildItem $SaveProbe -Recurse -File | ForEach-Object {
    $manifest[$_.FullName.Substring($SaveProbe.Length)] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  }
}
$manifest | ConvertTo-Json | Set-Content (Join-Path $InstallDir 'pre-upgrade-save-hashes.json')
Write-Host 'Installer smoke passed.'
