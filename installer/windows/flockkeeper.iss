; Inno Setup script for FlockKeeper (Windows desktop)
;
; Build the app first:    flutter build windows --release
; Then compile this:      "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\windows\flockkeeper.iss
; Output installer:       installer\windows\Output\FlockKeeper-Setup-<version>.exe
;
; Keep AppId constant across versions so upgrades replace the prior install.

#define MyAppName "FlockKeeper"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Clear Creek Forge"
#define MyAppExeName "flockkeeper.exe"
#define MyBuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{1D0A4B0A-5925-4AF6-B64A-B76865E48B7E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=FlockKeeper-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
