[Setup]
AppName=FuelFlow ERP
AppVersion=1.2.0
AppPublisher=FuelFlow ERP
DefaultDirName={autopf}\FuelFlow ERP
DefaultGroupName=FuelFlow ERP
OutputDir=installer_output
OutputBaseFilename=FuelFlowERP-Setup-v1.2.0
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\FuelFlowERP.exe
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FuelFlow ERP"; Filename: "{app}\FuelFlowERP.exe"
Name: "{group}\Uninstall FuelFlow ERP"; Filename: "{uninstallexe}"
Name: "{autodesktop}\FuelFlow ERP"; Filename: "{app}\FuelFlowERP.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\FuelFlowERP.exe"; Description: "Launch FuelFlow ERP"; Flags: postinstall nowait skipifsilent