program QAQC;

uses
  Forms,
  Windows,
  Main in 'Main.pas' {MainForm},
  IntervalDialogUnit in 'IntervalDialogUnit.pas' {IntervalDialog},
  misc in 'misc.pas',
  HydroSensor in 'HydroSensor.pas',
  EventDialogUnit in 'EventDialogUnit.pas' {EventDialog},
  Connect in 'Connect.pas' {ConnectBanner},
  Passwd in 'Passwd.pas' {PasswordDlg},
  EventFormUnit in 'EventFormUnit.pas' {EventForm},
  RainData in 'RainData.pas',
  DataTypes in 'DataTypes.pas',
  RunoffData in 'RunoffData.pas',
  ShiftDialogUnit in 'ShiftDialogUnit.pas' {ShiftDialog};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'QA/QC';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TEventForm, EventForm);
  Application.CreateForm(TShiftDialog, ShiftDialog);
  Application.Run;
end.
