; Script generated for FlockKeeper Flutter Windows Application
; Bundles the compiled Flutter Windows application, assets, and dependencies.

#define MyAppName "FlockKeeper"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Clear Creek Kikos"
#define MyAppExeName "flockkeeper.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{5D0EF356-E6CA-4100-84E3-D6B60DEAA0B3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; The output directory for the compiled installer
OutputDir=..\build\installer
OutputBaseFilename=FlockKeeper_Setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "{#MyAppExeName}"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
