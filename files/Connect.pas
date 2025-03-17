unit Connect;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, StdCtrls, jpeg;

type
  TConnectBanner = class(TForm)
    Image: TImage;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ConnectBanner: TConnectBanner;

implementation

{$R *.DFM}



procedure TConnectBanner.FormCreate(Sender: TObject);
begin
  HandleNeeded;
  SetWindowLong(Handle,GWL_STYLE,WS_BORDER);
  SetWindowLong(Handle,GWL_EXSTYLE,WS_EX_DLGMODALFRAME);
  Height := Image.Picture.Height;
  ClientWidth := Image.Picture.Width;
end;

end.
