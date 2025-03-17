unit Passwd;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls, 
  Buttons, ExtCtrls, Dialogs;

type
  TPasswordDlg = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    GroupBox1: TGroupBox;
    Label2: TLabel;
    UsernameEdit: TEdit;
    PasswordEdit: TEdit;
    WatershedBox: TComboBox;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  PasswordDlg: TPasswordDlg;

implementation

{$R *.DFM}

procedure TPasswordDlg.FormShow(Sender: TObject);
begin
  PasswordEdit.Clear;
end;

end.
 
