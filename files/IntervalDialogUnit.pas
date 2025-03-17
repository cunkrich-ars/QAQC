unit IntervalDialogUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, DateUtils;

type
  TIntervalDialog = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    Panel1: TPanel;
    StartCalendar: TMonthCalendar;
    EndCalendar: TMonthCalendar;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    StartDayEdit: TEdit;
    Label4: TLabel;
    EndDayEdit: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure StartDayEditUpdate( NewDate: TDate );
    procedure StartDayEditChange(Sender: TObject);
    procedure EndDayEditUpdate( NewDate: TDate );
    procedure EndDayEditChange(Sender: TObject);
    procedure StartCalendarClick(Sender: TObject);
    procedure StartCalendarGetMonthInfo(Sender: TObject; Month: Cardinal; var MonthBoldInfo: Cardinal);
    procedure EndCalendarClick(Sender: TObject);
    procedure EndCalendarGetMonthInfo(Sender: TObject; Month: Cardinal; var MonthBoldInfo: Cardinal);
    procedure OKBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    StartYear: word;
    StartDOY:  word;
    EndYear:   word;
    EndDOY:    word;
  end;

var
  IntervalDialog: TIntervalDialog;

implementation

{$R *.DFM}

var
  ChangeStartMonth:    boolean;
  ChangeEndMonth:      boolean;
  UpdateStartCalendar: boolean;
  UpdateEndCalendar:   boolean;

  StartMonthCalls: integer; { number of consecutive calls to StartCalendarGetMonthInfo }
  OldStartYear:    word;
  OldStartMonth:   word;
  OldStartDay:     word;

  EndMonthCalls: integer; { number of consecutive calls to EndCalendarGetMonthInfo }
  OldEndYear:    word;
  OldEndMonth:   word;
  OldEndDay:     word;

procedure TIntervalDialog.FormCreate(Sender: TObject);
begin
  ChangeStartMonth    := False;
  ChangeEndMonth      := False;
  UpdateStartCalendar := False;
  UpdateEndCalendar   := False;

  StartCalendar.Date := Date;
  EndCalendar.Date   := Date;

  DecodeDateDay( StartCalendar.Date, StartYear, StartDOY );
  DecodeDateDay( EndCalendar.Date, EndYear, EndDOY );

  StartDayEdit.Text := IntToStr( StartDOY );
  EndDayEdit.Text   := IntToStr( EndDOY );

  ChangeStartMonth    := True;
  ChangeEndMonth      := True;
  UpdateStartCalendar := True;
  UpdateEndCalendar   := True;

  StartMonthCalls := 0;
  EndMonthCalls   := 0;
end;

{ Start calendar event handlers ------------------------------------------------------------------ }

procedure TIntervalDialog.StartDayEditUpdate( NewDate: TDate );
begin
  DecodeDateDay( NewDate, StartYear, StartDOY );
{ ------------------------------------------------------------------------------------------------
  Don't let the edit control event handler update the calendar
  ------------------------------------------------------------------------------------------------ }
  UpdateStartCalendar := False;
  StartDayEdit.Text   := IntToStr( StartDOY );
  UpdateStartCalendar := True;
end;

procedure TIntervalDialog.StartDayEditChange(Sender: TObject);
begin
  if UpdateStartCalendar then
  try
    StartDOY := StrToInt( StartDayEdit.Text );
{ ------------------------------------------------------------------------------------------------
    Don't let the calendar month event handler update the edit control
  ------------------------------------------------------------------------------------------------ }
    ChangeStartMonth := False;
{ ------------------------------------------------------------------------------------------------
    Put EncodeDateDay call in try block in case EndDOY is not valid (e.g. = 0)
  ------------------------------------------------------------------------------------------------ }
    StartCalendar.Date := EncodeDateDay( StartYear, StartDOY );
    ChangeStartMonth := True;
  except
{ ------------------------------------------------------------------------------------------------
    Catch exception but don't do anything
  ------------------------------------------------------------------------------------------------ }
  end;
end;

procedure TIntervalDialog.StartCalendarClick(Sender: TObject);
begin
  StartDayEditUpdate( StartCalendar.Date );
end;

procedure TIntervalDialog.StartCalendarGetMonthInfo(Sender: TObject; Month: Cardinal; var MonthBoldInfo: Cardinal);
var
  NewDate:  TDateTime;
  MaxDays:  word;
begin
{ ------------------------------------------------------------------------------------------------
  This event handler gets called 3 consecutive times when the following parts of the calendar
  control are clicked:

  Month label
  Year label
  Forward/Backward arrows

  The value of the Month argument in the 3 calls brackets the new month, so the desired value is
  obtained from the 2nd call.  Watch out that the old day value is not greater than the number of
  days in the new month, e.g. if day = 31 and the new month only has 30 days
  ------------------------------------------------------------------------------------------------ }
  if ChangeStartMonth then
  begin
    Inc( StartMonthCalls );
    case StartMonthCalls of
      1: DecodeDate( StartCalendar.Date, OldStartYear, OldStartMonth, OldStartDay );
      2: begin
           MaxDays := DaysInAMonth( OldStartYear, Month );
           if OldStartDay > MaxDays then
             NewDate := EncodeDate( OldStartYear, Month, MaxDays )
           else
             NewDate := EncodeDate( OldStartYear, Month, OldStartDay );
           StartDayEditUpdate( NewDate );
         end;
      3: StartMonthCalls := 0;
    end;
  end;
end;

{ End calendar event handlers -------------------------------------------------------------------- }

procedure TIntervalDialog.EndDayEditUpdate( NewDate: TDate );
begin
  DecodeDateDay( NewDate, EndYear, EndDOY );
  UpdateEndCalendar := False;
  EndDayEdit.Text   := IntToStr( EndDOY );
  UpdateEndCalendar := True;
end;

procedure TIntervalDialog.EndDayEditChange(Sender: TObject);
begin
  if UpdateEndCalendar then
  try
    EndDOY := StrToInt( EndDayEdit.Text );
    ChangeEndMonth := False;
    EndCalendar.Date := EncodeDateDay( EndYear, EndDOY );
    ChangeEndMonth := True;
  except

  end;
end;

procedure TIntervalDialog.EndCalendarClick(Sender: TObject);
begin
  EndDayEditUpdate( EndCalendar.Date );
end;

procedure TIntervalDialog.EndCalendarGetMonthInfo(Sender: TObject; Month: Cardinal; var MonthBoldInfo: Cardinal);
var
  NewDate:  TDateTime;
  MaxDays:  word;
begin
  if ChangeEndMonth then
  begin
    Inc( EndMonthCalls );
    case EndMonthCalls of
      1: DecodeDate( EndCalendar.Date, OldEndYear, OldEndMonth, OldEndDay );
      2: begin
           MaxDays := DaysInAMonth( OldEndYear, Month );
           if OldStartDay > MaxDays then
             NewDate := EncodeDate( OldEndYear, Month, MaxDays )
           else
             NewDate := EncodeDate( OldEndYear, Month, OldEndDay );
           EndDayEditUpdate( NewDate );
         end;
      3: EndMonthCalls := 0;
    end;
  end;
end;

procedure TIntervalDialog.OKBtnClick(Sender: TObject);
begin
  StartDayEditUpdate( StartCalendar.Date );
  EndDayEditUpdate( EndCalendar.Date );
end;

end.
