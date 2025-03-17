unit ShiftDialogUnit;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls, 
  Buttons, ExtCtrls;

type
  TShiftDialog = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    Bevel1: TBevel;
    Label1: TLabel;
    Edit1: TEdit;
    procedure OKBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    Shift: single;
  end;

var
  ShiftDialog: TShiftDialog;

implementation

{$R *.dfm}

procedure TShiftDialog.OKBtnClick(Sender: TObject);
begin
  try
    Shift := StrToFloat( Edit1.Text );
  except
    Shift := 0;
  end;
end;

end.
