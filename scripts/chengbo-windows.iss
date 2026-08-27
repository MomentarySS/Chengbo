; Chengbo Windows Installer - Inno Setup 7
#define AppName "澄波"
#define AppExeName "Chengbo.exe"
#define AppVersion "1.5.0"
#define AppPublisher "Chengbo"
#define AppURL "https://github.com/yourname/chengbo"
#define AppDescription "听国内广播与 RSS 播客"
#define SourceDir "..\build\windows\x64\runner\Release"
#define OutputDir ".."
#define OutputBaseFilename "chengbo-windows-1.5.0"

[Setup]
; Basic Application Information
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
; Output installer file
OutputBaseFilename={#OutputBaseFilename}
OutputDir={#OutputDir}
; Compression
Compression=lzma2
SolidCompression=yes
; UI Settings
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Uninstall settings
UninstallDisplayIcon={app}\Chengbo.exe
UninstallDisplayName={#AppName}
; Version information
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppDescription}
VersionInfoCopyright=Copyright (C) 2024 Chengbo
; Privileges
PrivilegesRequired=none
; Architecture
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Other settings
DisableProgramGroupPage=no
DisableReadyMemo=no
DisableDirPage=no

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startmenu"; Description: "创建开始菜单快捷方式"; GroupDescription: "快捷方式:"
Name: "quicklaunch"; Description: "创建快速启动栏快捷方式"; GroupDescription: "快捷方式:"

[Files]
; Main executable and DLLs
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
; Data directory (local storage, caches, etc.)
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu Program Folder
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Comment: "{#AppDescription}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
; Desktop Icon
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Comment: "{#AppDescription}"; Tasks: desktopicon
; Start Menu Icon (always created if startmenu task is checked)
Name: "{userstartmenu}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Comment: "{#AppDescription}"; Tasks: startmenu

[Run]
; Launch application after installation
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// Initialize and register the application uninstall entry
function InitializeUninstall(): Boolean;
begin
  Result := True;
end;
