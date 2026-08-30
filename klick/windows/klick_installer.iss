; Inno Setup Script for KLICK Windows App
#define MyAppName "KLICK"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "KLICK"
#define MyAppExeName "klick.exe"

[Setup]
; Unique identifier for this application
AppId={{5D467B10-A9C3-4E87-A1B9-2A2B0E8D7F91}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\build\windows\installer
OutputBaseFilename=Klick-Setup-v{#MyAppVersion}
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
