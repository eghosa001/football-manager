#define MyAppName "Football Dynasty"
#define MyAppVersion "1.0.0-rc3"
#define MyAppPublisher "Football Dynasty"
#define MyAppExeName "FootballDynasty.exe"

[Setup]
AppId={{D736C7B7-69B2-46B9-B25C-1C4790AF8A42}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Football Dynasty
DefaultGroupName=Football Dynasty
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=FootballDynasty-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion=1.0.0.3
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Files]
Source: "..\..\build\windows\FootballDynasty.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "FootballDynasty.exe"

[Icons]
Name: "{group}\Football Dynasty"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Football Dynasty"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Football Dynasty"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  { User saves live outside the install directory under Godot user:// and are intentionally preserved across upgrades/uninstall. }
end;
