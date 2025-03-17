unit EventDialogUnit;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls, 
  Buttons, ExtCtrls, Dialogs, DBTables;

type
  TEventDialog = class(TForm)
    Panel1:        TPanel;
    ReasonsBox: TComboBox;
    ApprovedBox: TCheckBox;
    NotApprovedBox: TCheckBox;
    procedure GetStatusCodes(DatabaseName, TableName: string);
    function  ShowModalEx(code: word): word;
    procedure ReasonsBoxCloseUp(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ApprovedBoxClick(Sender: TObject);
    procedure NotApprovedBoxClick(Sender: TObject);
  private
    Codes: TQuery;
    code: integer;
  public
  end;

var
  EventDialog: TEventDialog;

implementation

const
  AddCodeText = 'Add new status code';

var
  NewCode: boolean;

{$R *.DFM}

procedure TEventDialog.GetStatusCodes(DatabaseName, TableName: string);
{ ------------------------------------------------------------------------------------------------
  This method must be called first
  ------------------------------------------------------------------------------------------------ }
begin
  Codes.DatabaseName := DatabaseName;
  Codes.SQL.Add('select * from ' + TableName + ' order by code');
  Codes.RequestLive := True;
  Codes.Open;
  Codes.First;
  while not Codes.Eof do
  begin
    if Codes['code'] > 1 then ReasonsBox.Items.Add(Codes['descript']);
    Codes.Next;
  end;
  ReasonsBox.Items.Add(AddCodeText);
  Codes.First;
end;

function TEventDialog.ShowModalEx(code: word): word;
begin
{ ------------------------------------------------------------------------------------------------
  Don't do anything if code is less than zero (incomplete event) or GetStatusCodes wasn't called
  ------------------------------------------------------------------------------------------------ }
  if (code < 0) or not Codes.Active then
    Result := code
  else
  begin
    Self.code := code;

    ShowModal;

    if NotApprovedBox.Checked then
    begin
      if NewCode and (ReasonsBox.Text <> AddCodeText) then
{ ------------------------------------------------------------------------------------------------
      Add new code to database table
  ------------------------------------------------------------------------------------------------ }
      begin
        Codes.Append;
        Result := ReasonsBox.Items.Count + 1;
        Codes['code'] := Result;
        Codes['descript'] := ReasonsBox.Text;
        Codes.Post;
        ReasonsBox.Items[ReasonsBox.Items.Count-1] := ReasonsBox.Text;
        ReasonsBox.Items.Add(AddCodeText);
      end
      else
{ ------------------------------------------------------------------------------------------------
      Return status code indicating why the event was rejected
-------------------------------------------------------------------------------------------------- }
        Result := ReasonsBox.ItemIndex + 2;
    end
    else if ApprovedBox.Checked then
{ ------------------------------------------------------------------------------------------------
      Approved
  ------------------------------------------------------------------------------------------------ }
      Result := 1
    else
{ ------------------------------------------------------------------------------------------------
      Neither approved nor rejected
  ------------------------------------------------------------------------------------------------ }
      Result := 0;
  end;
end;

procedure TEventDialog.FormShow(Sender: TObject);
begin
  ReasonsBox.Style := csDropDownList; {read-only }
{ ------------------------------------------------------------------------------------------------
  Preset the dialog's controls to reflect the current event status code
  ------------------------------------------------------------------------------------------------ }
  case code of
    0: begin
{ ------------------------------------------------------------------------------------------------
         Event is currently neither approved nor rejected
  ------------------------------------------------------------------------------------------------ }
         ApprovedBox.Checked := False;
         NotApprovedBox.Checked := False;
         ReasonsBox.ItemIndex := 0;
         ReasonsBox.Enabled := False;
       end;
    1: begin
{ ------------------------------------------------------------------------------------------------
         Event is currently approved
  ------------------------------------------------------------------------------------------------ }
         ApprovedBox.Checked := True;
         NotApprovedBox.Checked := False;
         ReasonsBox.ItemIndex := 0;
         ReasonsBox.Enabled := False;
       end;
  else
{ ------------------------------------------------------------------------------------------------
    Event is currently rejected
  ------------------------------------------------------------------------------------------------ }
    ApprovedBox.Checked := False;
    NotApprovedBox.Checked := True;
    if code < ReasonsBox.Items.Count + 1 then
      ReasonsBox.ItemIndex := code - 2
    else
      ReasonsBox.ItemIndex := ReasonsBox.Items.Count - 1;
    ReasonsBox.Enabled := True;
  end;
  ReasonsBox.Text := ReasonsBox.Items.Strings[ReasonsBox.ItemIndex];
  NewCode := False;
end;

procedure TEventDialog.ApprovedBoxClick(Sender: TObject);
begin
  if ApprovedBox.Checked then
  begin
    NotApprovedBox.Checked := False;
    ReasonsBox.Enabled := False;
  end;
end;

procedure TEventDialog.NotApprovedBoxClick(Sender: TObject);
begin
  if NotApprovedBox.Checked then
  begin
    ApprovedBox.Checked := False;
    ReasonsBox.Enabled := True;
  end;
end;

procedure TEventDialog.ReasonsBoxCloseUp(Sender: TObject);
{ ------------------------------------------------------------------------------------------------
  Prevent the user from editing event status code descriptions UNLESS the last item,
  'Add new status code', was selected
  ------------------------------------------------------------------------------------------------ }
begin
  if ReasonsBox.ItemIndex = ReasonsBox.Items.Count - 1 then
{ ------------------------------------------------------------------------------------------------
  User elected to add a new event status code - allow user to type in description of new code
  ------------------------------------------------------------------------------------------------ }
  begin
    ReasonsBox.Style := csDropDown;
    NewCode := True;
  end
  else
{ ------------------------------------------------------------------------------------------------
  Don't allow user to edit existing code descriptions
  ------------------------------------------------------------------------------------------------ }
  begin
    ReasonsBox.Style := csDropDownList;
    NewCode := False;
  end;
end;

procedure TEventDialog.FormCreate(Sender: TObject);
begin
 Codes := TQuery.Create( Self );
end;

end.

