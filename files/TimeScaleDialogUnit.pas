unit TimeScaleDialogUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls;

type
  TTimeScaleDialog = class(TForm)
    Slider: TTrackBar;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  TimeScaleDialog: TTimeScaleDialog;

implementation

{$R *.dfm}

end.
