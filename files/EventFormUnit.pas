unit EventFormUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Math, ComCtrls, Menus, ExtCtrls, DataTypes;

type
  TPlotBox = class(TPaintBox)
  private
    procedure DrawPlot( Sender: TObject );
    procedure CrossHair(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure CMMouseLeave(var msg: TMessage); message CM_MOUSELEAVE;
    procedure CMMouseEnter(var msg: TMessage); message CM_MOUSEENTER;
    procedure MouseClick( Sender: TObject );
  end;

  TEventForm = class(TForm)
    TimeScrollBar: TScrollBar;
    ScalePopup: TPopupMenu;
    ScaleMenu: TMenuItem;
    Sixty: TMenuItem;
    Thirty: TMenuItem;
    Fifteen: TMenuItem;
    Five: TMenuItem;
    One: TMenuItem;
    EditPopup: TPopupMenu;
    DischargeMenu: TMenuItem;
    EndEventMenu: TMenuItem;
    RecessionMenu: TMenuItem;
    DeleteMenu: TMenuItem;
    ShiftMenu: TMenuItem;
    procedure FormShow(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure TimeScrollBarChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure SetScale(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure ShowModalEx( Gage, Event: integer; DataType: TDataType );
    procedure TimeScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
    procedure DischargeMenuClick(Sender: TObject);
    procedure RecessionMenuClick(Sender: TObject);
    procedure DeleteMenuClick(Sender: TObject);
    procedure EndEventMenuClick(Sender: TObject);
    procedure ShiftMenuClick(Sender: TObject);
  private
    GageIndex:  integer;
    EventIndex: integer;
    DataType: TDataType;
    procedure SetTimeTickSpacing;
    procedure SetVertTickSpacing;
    procedure ConfigScrollBar;
  public
{ ------------------------------------------------------------------------------------------------
    We will be drawing the data onto a bitmap (PlotArea, see below) which in turn will be drawn
    onto a PaintBox control which has been modified to process CM_MOUSEENTER and CM_MOUSELEAVE
    messages. When the mouse is over the plot, we will be using a custom crosshair style cursor
    and drawing horizontal and vertical reference lines from the cursor to the edges of the plot.
    This means the plot must be redrawn every time the mouse moves, hence the bitmap instead of
    drawing the plot directly on the client area. We use the PaintBox control with the additional
    mouse messages so we can refresh the plot after the mouse leaves the area, otherwise we can
    be left with residual reference lines.
  ------------------------------------------------------------------------------------------------ }
    PlotBox: TPlotBox;
  end;

var
  EventForm: TEventForm;

implementation

uses
  HydroSensor, RainData, RunoffData, ShiftDialogUnit;

{$R *.dfm}

const
{ ------------------------------------------------------------------------------------------------
  Time scale
  ------------------------------------------------------------------------------------------------ }
  MINIMUM_TIME_TICK_SPACING = 10; { pixels }
  TIMETICKINTERVALS: array [1..5] of integer = (60, 30, 15,  5, 1); { minutes }
  TIMETICKLENGTHS:   array [1..5] of integer = (15, 15, 10,  6, 3); { pixels }
{ ------------------------------------------------------------------------------------------------
  Vertical scale
  ------------------------------------------------------------------------------------------------ }
  MINIMUM_VERT_TICK_SPACING = 5;   { pixels }
  VERTTICKINTERVALS: array [1..4] of integer = (50, 10,  5, 1); { 1/100's or 1/1000's }
  VERTTICKLENGTHS:   array [1..4] of integer = (15, 15, 10, 5); { pixels }
//  VERTLABELFORMATS:  array [1..3] of string  = ('%2.0f', '%2.1f', '%3.2f');
//  VERTBASE:          array [1..3] of integer = (10, 100, 1000);
//  VERT_THRESHOLDS:   array [1..3] of single  = (1.0, 0.1, 0.0); { lower bounds for each VERTBASE }
{ ------------------------------------------------------------------------------------------------
  Plot
  ------------------------------------------------------------------------------------------------ }
  MARGIN = 15;
  BOX    =  4; { 1/2 x side dimension of square box drawn over each point }
{ ------------------------------------------------------------------------------------------------
  Recession estimation
  ------------------------------------------------------------------------------------------------ }
  REGRESS = 10; { number of data points used to compute initial slope of curve }

type

  TBox = record
    x1: integer;
    y1: integer;
    x2: integer;
    y2: integer;
  end;

var
  Sensor:             THydroSensor;
  PlotArea:           TBitmap;
  PlotHeight:         integer;
{ ------------------------------------------------------------------------------------------------
  Time scale
  ------------------------------------------------------------------------------------------------ }
  XScaleHeight:       integer; { pixels }
  PixelsperTimeTick:  integer; { pixels }
  TimeTickIndex:      integer;
  MajorTimeTickIndex: integer; { 60 or 30 minutes }
  TimeLabelWidth:     integer; { pixels }
  TicksperEvent:      integer;
  Duration:           integer; { event duration, minutes }
  ts,te:              integer; { beginning, ending time of plot }
  tw:                 integer; { time at left edge of window }
  TimeScaleFactor:    single;
  MaxScrollPosition:  integer;
  TimeScaleTop:       integer;
{ ------------------------------------------------------------------------------------------------
  Vertical scale
  ------------------------------------------------------------------------------------------------ }
  YScaleWidth:        integer; { pixels }
  PixelsperVertTick:  integer; { pixels }
  VertTickIndex:      integer;
  VertLabel_x:        integer; { where to draw labels }
  VertLabelOffset:    integer; { pixels }
  VertScaleFactor:    single;
  VertIndex:          integer; { 1 or 2 }
  VertBase:           single;
  VertFormat:         string;
{ ------------------------------------------------------------------------------------------------
  Mouse
  ------------------------------------------------------------------------------------------------ }
  XRect:              TRect;
  YRect:              TRect;
  PointOver:          integer; { set to index of data point when mouse is moved over a box }
  PointIndex:         integer; { index of currently selected data point }
  Editable:           boolean; { can you select a point for editing }
  Recessable:         boolean; { can you estimate a recession }
{ ------------------------------------------------------------------------------------------------
  Plot
  ------------------------------------------------------------------------------------------------ }
  Boxes:              array of TBox;
  FirstPoint:         integer; { index of first visible data point }
  LastPoint:          integer; { index of last visible data point }
  ShowDischarge:      boolean; { True = plot rate instead of depth }
{ ------------------------------------------------------------------------------------------------
  Recession estimation
  ------------------------------------------------------------------------------------------------ }
  t_est:              array of single;
  d_est:              array of single;
  q_est:              array of single;
  Boxes_est:          array of TBox;
  EstPoint:           integer; { index of point after which estimation begins }
  nEstPoints:         integer; { number of estimated ponts }
{ ------------------------------------------------------------------------------------------------
  Point deletion
  ------------------------------------------------------------------------------------------------ }
  BackedUp:           boolean; { True = event was copied to back up tables }

procedure TEventForm.FormCreate(Sender: TObject);
begin
  {$R Crosshair.res}
  Screen.Cursors[1] := LoadCursor( HInstance, 'CROSSHAIR' );
  {$R Crosshair_Over.res}
  Screen.Cursors[2] := LoadCursor( HInstance, 'CROSSHAIR_OVER' );

  PlotArea := TBitmap.Create;
{ ------------------------------------------------------------------------------------------------
  Representative width for time labels
  ------------------------------------------------------------------------------------------------ }
  TimeLabelWidth := Canvas.TextWidth( '0123' );
{ ------------------------------------------------------------------------------------------------
  Height of time scale
  ------------------------------------------------------------------------------------------------ }
  XScaleHeight := TIMETICKLENGTHS[1] + 3 * Canvas.TextHeight( '0123' ) div 2;
{ ------------------------------------------------------------------------------------------------
  Vertical scale formatting
  ------------------------------------------------------------------------------------------------ }
  VertLabel_x     := Canvas.TextWidth( '5' );
  VertLabelOffset := Canvas.TextHeight( '5' ) div 2;
  YScaleWidth     := VertLabel_x + Canvas.TextWidth( '5.55' ) + VERTTICKLENGTHS[1];

  PlotBox             := TPlotBox.Create( Self );
  PlotBox.Parent      := Self;
  PlotBox.SendToBack;
  PlotBox.Top         := MARGIN + 1;
  PlotBox.OnMouseMove := PlotBox.CrossHair;
  PlotBox.OnPaint     := PlotBox.DrawPlot;
  PlotBox.OnClick     := PlotBox.MouseClick;
end;

procedure TEventForm.SetTimeTickSpacing;
var
  TicksperHour:   integer;
  PixelsperHour:  integer;
begin
  TicksperEvent := Duration div TIMETICKINTERVALS[TimeTickIndex];
  PixelsperTimeTick := MINIMUM_TIME_TICK_SPACING;
  TicksperHour := 60 div TIMETICKINTERVALS[TimeTickIndex];
  PixelsperHour := TicksperHour * MINIMUM_TIME_TICK_SPACING;
{ ------------------------------------------------------------------------------------------------
  Start with labels on 60-minute ticks
  ------------------------------------------------------------------------------------------------ }
  MajorTimeTickIndex := 1;

  if PixelsperHour < 2 * TimeLabelWidth then
{ ------------------------------------------------------------------------------------------------
    Tick labels too crowded - expand tick spacing
  ------------------------------------------------------------------------------------------------ }
    PixelsperTimeTick := 2 * TimeLabelWidth div TicksperHour

  else if PixelsperHour > 5 * TimeLabelWidth then
{ ------------------------------------------------------------------------------------------------
    Tick labels too sparse - add labels to 30-minute ticks
  ------------------------------------------------------------------------------------------------ }
    MajorTimeTickIndex := 2;

  TimeScaleFactor := PixelsperTimeTick / TIMETICKINTERVALS[TimeTickIndex]; {pixels per minute }
end;

procedure TEventForm.SetVertTickSpacing;
var
  i:               integer;
  nPoints:         integer;
  y_max:           single;
  MaxY:            integer;
  y:               single;
  TicksperWindow:  integer;
  IntervalperTick: integer;
begin
  nPoints := Sensor.Events[EventIndex].Points.nPoints;
  y_max := 0;
  for i := 1 to nPoints do
  begin
    if ShowDischarge then
      y := Sensor.Events[EventIndex].Points[i].Rate
    else
      y := Sensor.Events[EventIndex].Points[i].Depth;
    if y > y_max then y_max := y;
  end;
{ ------------------------------------------------------------------------------------------------
  Set scale maximum to 1.05 * maximum depth of event in 1/100's or 1/1000's
  ------------------------------------------------------------------------------------------------ }

//  VertIndex := 1;
//  while y_max < VERT_THRESHOLDS[VertIndex] do Inc( VertIndex );

//  MaxY := Max( 1, Trunc( y_max * 1.05 * VERTBASE[VertIndex] ) );

  VertIndex := 1;
  while y_max < 1 / Power( 10, VertIndex-1 ) do Inc( VertIndex );
  VertBase := Power( 10, VertIndex );
  MaxY := Max( 1, Round( y_max * 1.05 * VertBase ) );
  VertFormat := '%' + IntToStr( VertIndex + 1 ) + '.' + IntToStr( VertIndex ) + 'f';
  YScaleWidth := VertLabel_x + Canvas.TextWidth( Format( VertFormat, [1/3] ) ) + VERTTICKLENGTHS[1];

  TicksperWindow := PlotHeight div MINIMUM_VERT_TICK_SPACING;
  IntervalperTick := MaxY div TicksperWindow + 1; { 1/100's or 1/1000's }

  VertTickIndex := 4;
  for i := 4 downto 2 do
    if VERTTICKINTERVALS[i] < IntervalperTick then Dec( VertTickIndex );

  TicksperWindow := MaxY div VERTTICKINTERVALS[VertTickIndex];
  PixelsperVertTick := PlotHeight div TicksperWindow;
  VertScaleFactor := PixelsperVertTick / VERTTICKINTERVALS[VertTickIndex]; {pixels per 1/100 or 1/1000 }
  PlotBox.Left := YScaleWidth + 1;
end;

procedure TEventForm.ConfigScrollBar;
var
  TicksperWindow: integer;
begin
{ ------------------------------------------------------------------------------------------------
  Configure scroll bar
  ------------------------------------------------------------------------------------------------ }
  TimeScrollBar.Position := 1;
  tw := ts;
  TicksperWindow := (ClientWidth - YScaleWidth) div PixelsperTimeTick;
  if TicksperWindow < TicksperEvent then
  begin
    TimeScrollBar.Visible := True;
    TimeScrollBar.PageSize := 1; { in case current PageSize > new Max }
    TimeScrollBar.Max := TicksperEvent;
    TimeScrollBar.PageSize := TicksperWindow;
    TimeScrollBar.LargeChange := Min( TicksperWindow, TicksperEvent - TicksperWindow );
    MaxScrollPosition := TimeScrollBar.Max - TimeScrollBar.PageSize + 1;
    PlotHeight := ClientHeight - TimeScrollBar.Height - XScaleHeight - MARGIN - 1;
    TimeScaleTop := ClientHeight - XScaleHeight - TimeScrollBar.Height
  end
  else
  begin
    TimeScrollBar.Visible := False;
    TimeScrollBar.PageSize := 1;
    TimeScrollBar.Max := 100;
    TimeScrollBar.LargeChange := 1;
    MaxScrollPosition := 100;
    PlotHeight := ClientHeight - XScaleHeight - MARGIN - 1;
    TimeScaleTop := ClientHeight - XScaleHeight;
  end;
end;

procedure TEventForm.FormShow(Sender: TObject);
var
  DOY:            integer;
  t0:             single;
  Hour:           integer;
  Minute:         integer;
  tn:             single;
  nPoints:        integer;
  PixelsperEvent: integer;
  min_dt:         integer;
  dt:             integer;
  i:              integer;
  PlotWidth:      integer;
begin
  DOY    := Sensor.Events[EventIndex].DOY;
  t0     := Sensor.Events[EventIndex].Time;
  Hour   := Round(t0) div 60;
  Minute := Round(t0) mod 60;
{ ------------------------------------------------------------------------------------------------
  Form caption
  ------------------------------------------------------------------------------------------------ }
  Caption := Format('DOY %d  %d:%.2d', [DOY, Hour, Minute] );
{ ------------------------------------------------------------------------------------------------
  Start and end plot on whole hours
  ------------------------------------------------------------------------------------------------ }
  nPoints := Sensor.Events[EventIndex].Points.nPoints;
  tn      := t0 + Sensor.Events[EventIndex].Points[nPoints].Time;
  ts := (Trunc( t0 ) div 60) * 60;
  te := (Trunc( tn ) div 60 + 1) * 60;
  Duration := te - ts;
{ ------------------------------------------------------------------------------------------------
  Pick tick interval such that event duration in pixels is closest to the window client width
  ------------------------------------------------------------------------------------------------ }
  TimeTickIndex := 1;
  PixelsperEvent := Duration div TIMETICKINTERVALS[1] * MINIMUM_TIME_TICK_SPACING;
  PlotWidth := ClientWidth - YScaleWidth - MARGIN - 1;
  min_dt := Abs( PlotWidth - PixelsperEvent );
  for i := 1 to 5 do
  begin
    PixelsperEvent := Duration div TIMETICKINTERVALS[i] * MINIMUM_TIME_TICK_SPACING;
    dt := Abs( PlotWidth - PixelsperEvent );
    if dt < min_dt then
    begin
      TimeTickIndex := i;
      min_dt := dt;
    end;
  end;
{ ------------------------------------------------------------------------------------------------
  Finalize time tick spacing, configure scrollbar and determine depth tick spacing
  ------------------------------------------------------------------------------------------------ }
  SetTimeTickSpacing;
  ConfigScrollBar;
  SetVertTickSpacing;

  PlotArea.Height := PlotHeight;
  PlotArea.Width  := ClientWidth - YScaleWidth - MARGIN - 1;
  PlotBox.Height  := PlotArea.Height;
  PlotBox.Width   := PlotArea.Width;
  XRect.Left      := 0;
  XRect.Top       := 0;
  XRect.Right     := PlotArea.Width;
  XRect.Bottom    := 0;
  YRect.Left      := 0;
  YRect.Top       := 0;
  YRect.Right     := 0;
  YRect.Bottom    := PlotArea.Height;
{ ------------------------------------------------------------------------------------------------
  Indicate current tick spacing on popup menu
  ------------------------------------------------------------------------------------------------ }
  ScaleMenu.Items[TimeTickIndex-1].Checked := True;
end;

procedure TEventForm.FormResize(Sender: TObject);
begin
  ConfigScrollBar;
  SetVertTickSpacing;
  PlotArea.Height := PlotHeight;
  PlotArea.Width  := ClientWidth - YScaleWidth - MARGIN - 1;
  PlotBox.Height  := PlotArea.Height;
  PlotBox.Width   := PlotArea.Width;
  YRect.Bottom    := PlotArea.Height;
  XRect.Right     := PlotArea.Width;
  FormPaint( Self );
end;

procedure TEventForm.FormPaint(Sender: TObject);
var
  i:         integer;
  t:         integer;
  tr:        integer;
  dt:        integer;
  tick_x:    integer;
  label_x:   integer;
  label_y:   integer;
  Hour:      integer;
  Minute:    integer;
  TickLabel: string;
  tick_y:    integer;
  x:         integer;
  y:         integer;
  dy:        integer;
begin
{ ------------------------------------------------------------------------------------------------
  Draw time scale area and axis
  ------------------------------------------------------------------------------------------------ }
  Canvas.Pen.Color := clBtnFace;
  Canvas.Brush.Color := clBtnFace;
  Canvas.Rectangle( 0, TimeScaleTop, ClientWidth, ClientHeight );
  Canvas.Pen.Color := clBlack;
  Canvas.MoveTo( YScaleWidth, TimeScaleTop );
  Canvas.LineTo( ClientWidth, TimeScaleTop );
{ ------------------------------------------------------------------------------------------------
  Draw time scale ticks
  ------------------------------------------------------------------------------------------------ }
  tick_x  := YScaleWidth;
  label_y := TimeScaleTop + TIMETICKLENGTHS[1];
  t       := tw;
  dt      := TIMETICKINTERVALS[TimeTickIndex];
  while (tick_x < ClientWidth) and (t <= te) do
  begin
{ ------------------------------------------------------------------------------------------------
    Determine which tick to draw by finding the largest interval which divides the current time
  ------------------------------------------------------------------------------------------------ }
    for i := 1 to TimeTickIndex do
      if t mod TIMETICKINTERVALS[i] = 0 then
      begin
        Canvas.MoveTo( tick_x, TimeScaleTop );
        Canvas.LineTo( tick_x, TimeScaleTop + TIMETICKLENGTHS[i] );
        if i = MajorTimeTickIndex then
{ ------------------------------------------------------------------------------------------------
        Draw tick label
  ------------------------------------------------------------------------------------------------ }
        begin
          tr := t mod 1440; { minutes from beg. of current day }
          if tr > 0 then
          begin
            Hour := tr div 60;
            Minute := tr mod 60;
            TickLabel := Format( '%.2d%.2d', [Hour, Minute] );
            Canvas.Font.Color := clBlue;
          end
          else
          begin
            TickLabel := IntToStr( Sensor.Events[EventIndex].DOY + (t div 1440) );
            Canvas.Font.Color := clRed;
          end;
          label_x := tick_x - Canvas.TextWidth( TickLabel ) div 2;
          Canvas.TextOut( label_x, label_y, TickLabel );
        end;
      end;
    tick_x := tick_x + PixelsperTimeTick;
    t := t + dt;
  end;
{ ------------------------------------------------------------------------------------------------
  Draw depth scale area and axis
  ------------------------------------------------------------------------------------------------ }
  Canvas.Pen.Color := clBtnFace;
  Canvas.Rectangle( 0, 0, YScaleWidth, TimeScaleTop );
  Canvas.Pen.Color := clBlack;
  Canvas.MoveTo( YScaleWidth, 0 );
  Canvas.LineTo( YScaleWidth, TimeScaleTop );
{ ------------------------------------------------------------------------------------------------
  Draw depth scale ticks
  ------------------------------------------------------------------------------------------------ }
  Canvas.Font.Color := clBlue;
  tick_y := TimeScaleTop;
  y      := 0;
  dy     := VERTTICKINTERVALS[VertTickIndex];
  while tick_y > 0 do
  begin
{ ------------------------------------------------------------------------------------------------
    Determine which tick to draw by finding the largest interval which divides the current depth
  ------------------------------------------------------------------------------------------------ }
    for i := 1 to VertTickIndex do
      if y mod VERTTICKINTERVALS[i] = 0 then
      begin
        Canvas.MoveTo( YScaleWidth, tick_y );
        Canvas.LineTo( YScaleWidth - VERTTICKLENGTHS[i], tick_y );
        if i < 3 then
{ ------------------------------------------------------------------------------------------------
        Draw depth label
  ------------------------------------------------------------------------------------------------ }
        begin
//          TickLabel := Format( VERTLABELFORMATS[VertIndex], [y / VERTBASE[VertIndex]] );
          TickLabel := Format( VertFormat, [y / VertBase] );
          label_y := tick_y - VertLabelOffset;
          Canvas.TextOut( VertLabel_x, label_y, TickLabel );
        end;
      end;
    tick_y := tick_y - PixelsperVertTick;
    y := y + dy;
  end;
{ ------------------------------------------------------------------------------------------------
  Draw right margin area
  ------------------------------------------------------------------------------------------------ }
  Canvas.Pen.Color := clBtnFace;
  x := PlotBox.BoundsRect.Right; // + 1;
  y := TimeScaleTop; // - 1;
  Canvas.Rectangle( x, 0, ClientWidth, y );
  Canvas.Pen.Color := clBlack;
  Canvas.MoveTo( x, MARGIN );
  Canvas.LineTo( x, y );
{ ------------------------------------------------------------------------------------------------
  Draw top margin area
  ------------------------------------------------------------------------------------------------ }
  Canvas.Pen.Color := clBtnFace;
  Canvas.Rectangle( YScaleWidth + 1, 0, x, MARGIN );
  Canvas.Pen.Color := clBlack;
  Canvas.MoveTo( YScaleWidth + 1, MARGIN );
  Canvas.LineTo( x, MARGIN );
{ ------------------------------------------------------------------------------------------------
  Plot data
  ------------------------------------------------------------------------------------------------ }
//  PlotBox.Canvas.Draw( 0, 0, PlotArea );
  PlotBox.DrawPlot( Self );
end;

procedure TEventForm.TimeScrollBarScroll(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
  if ScrollPos > MaxScrollPosition then ScrollPos := MaxScrollPosition;
end;

procedure TEventForm.TimeScrollBarChange(Sender: TObject);
begin
  if TimeScrollBar.Position <= MaxScrollPosition then
  begin
    tw := ts + (TimeScrollBar.Position - 1) * TIMETICKINTERVALS[TimeTickIndex];
    FormPaint( Self );
  end;
end;

procedure TEventForm.SetScale( Sender: TObject );
begin
{ ------------------------------------------------------------------------------------------------
  Remove checkmark from menu item indicating current tick spacing
  ------------------------------------------------------------------------------------------------ }
  ScaleMenu.Items[TimeTickIndex-1].Checked := False;
{ ------------------------------------------------------------------------------------------------
  New tick spacing corresponds to menu item position
  ------------------------------------------------------------------------------------------------ }
  TimeTickIndex := TMenuItem(Sender).MenuIndex + 1;
{ ------------------------------------------------------------------------------------------------
  Put checkmark next to menu item indicating new tick spacing
  ------------------------------------------------------------------------------------------------ }
  TMenuItem(Sender).Checked := True;
  SetTimeTickSpacing;
  FormResize( Self );
end;

procedure TEventForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
  i:    integer;
  Note: word;
begin
  if (nEstPoints > 0) and
     (MessageDlg( 'Apply estimated points?', mtConfirmation, [mbYes, mbNo], 0 ) <> mrYes) then
        nEstPoints := 0;

  PlotBox.DrawPlot( Self );
  Screen.Cursor := crHourGlass;

  if not BackedUp and (nEstPoints > 0) then
{ ------------------------------------------------------------------------------------------------
    Copy event to backup tables
  ------------------------------------------------------------------------------------------------ }
    Runoffgages[GageIndex].Backup( EventIndex );

  if nEstPoints > 0 then
{ ------------------------------------------------------------------------------------------------
    Delete runoff points from database and replace with estimated points
  ------------------------------------------------------------------------------------------------ }
    with Runoffgages[GageIndex].Events[EventIndex].Points do
    begin
      Delete( EstPoint+1, nPoints );
      Note := 1;
      for i := 0 to nEstPoints - 1 do Append( t_est[i], d_est[i], Note );
    end;
{ ------------------------------------------------------------------------------------------------
  Remove checkmark from menu item indicating current tick spacing
  ------------------------------------------------------------------------------------------------ }
  ScaleMenu.Items[TimeTickIndex-1].Checked := False;
  Screen.Cursor := crDefault;
end;

procedure TEventForm.FormMouseMove( Sender: TObject; Shift: TShiftState; X,Y: Integer );
begin
  if (Y > PlotHeight) and (X > YScaleWidth) then
    PopupMenu := ScalePopup
  else
    PopupMenu := nil;
end;

procedure TEventForm.ShowModalEx( Gage, Event: integer; DataType: TDataType );
begin
  GageIndex  := Gage;
  EventIndex := Event;
  EventForm.DataType := DataType;
  PointOver  := -1;
  PointIndex := -1;
  nEstPoints := 0;
  case DataType of
    Precip: begin
              Sensor              := Raingages[Gage];
              EditPopup.AutoPopup := False;
              Editable            := False;
              ShiftMenu.Enabled   := False;
              Recessable          := False;
            end;
    Runoff: begin
              Sensor := Runoffgages[Gage];
              if Runoffgages[Gage].Structure = Flume then
              begin
                EditPopup.AutoPopup := True;
                Editable            := True;
                ShiftMenu.Enabled   := True;
                Recessable          := True;
              end
              else if Runoffgages[Gage].Structure = Weir then
              begin
                EditPopup.AutoPopup := True;
                Editable            := True;
                ShiftMenu.Enabled   := True;
                Recessable          := False;
              end
              else
              begin
                EditPopup.AutoPopup := False;
                Editable            := False;
                ShiftMenu.Enabled   := False;
                Recessable          := False;
              end;
            end;
  end;
  EndEventMenu.Enabled  := False;
  DeleteMenu.Enabled    := False;
  RecessionMenu.Enabled := False;
  ShowDischarge         := False;
  DischargeMenu.Caption := 'Show Discharge';
  PlotBox.PopupMenu     := EditPopup;
  BackedUp              := False;
  SetLength( Boxes, Sensor.Events[Event].Points.nPoints + 1 );
  ShowModal;
end;

procedure TPlotBox.DrawPlot( Sender: TObject );
var
  i,x,y: integer;
  q:     single;
begin
{ ------------------------------------------------------------------------------------------------
  Clear bitmap to white
  ------------------------------------------------------------------------------------------------ }
  PlotArea.Canvas.Pen.Color := clWhite;
  PlotArea.Canvas.Brush.Color := clWhite;
  PlotArea.Canvas.Rectangle( 0, 0, PlotArea.Width, PlotArea.Height );
{ ------------------------------------------------------------------------------------------------
  Draw data onto bitmap
  ------------------------------------------------------------------------------------------------ }
  PlotArea.Canvas.Pen.Color := clBlue;
  with Sensor.Events[EventForm.EventIndex] do
  begin
    for i := 1 to Points.nPoints do
    begin
      x := Round( (Time + Points[i].Time - tw) * TimeScaleFactor );
      if x > 0 then Break
    end;
    FirstPoint := i - 1;
    if FirstPoint = 0 then FirstPoint := 1;

    if ShowDischarge then
      q := Points[FirstPoint].Rate
    else
      q := Points[FirstPoint].Depth;

    x := Round( (Time + Points[FirstPoint].Time - tw) * TimeScaleFactor );
//    y := PlotHeight - Round( q * VertScaleFactor * VERTBASE[VertIndex] );
    y := PlotHeight - Round( q * VertScaleFactor * VertBase );
    PlotArea.Canvas.MoveTo( x, y );

    Boxes[FirstPoint].x1 := x - BOX;
    Boxes[FirstPoint].y1 := y - BOX;
    Boxes[FirstPoint].x2 := x + BOX;
    Boxes[FirstPoint].y2 := y + BOX;

    for i := FirstPoint + 1 to Points.nPoints do
    begin
      if ShowDischarge then
        q := Points[i].Rate
      else
        q := Points[i].Depth;

      x := Round( (Time + Points[i].Time - tw) * TimeScaleFactor );
//      y := PlotHeight - Round( q * VertScaleFactor * VERTBASE[VertIndex] );
      y := PlotHeight - Round( q * VertScaleFactor * VertBase );

      PlotArea.Canvas.LineTo( x, y );

      if x > PlotArea.Width then Break;

      Boxes[i].x1 := x - BOX;
      Boxes[i].y1 := y - BOX;
      Boxes[i].x2 := x + BOX;
      Boxes[i].y2 := y + BOX;
    end;
    
    LastPoint := i - 1;
  end;
{ ------------------------------------------------------------------------------------------------
  Draw boxes
  ------------------------------------------------------------------------------------------------ }
  for i := FirstPoint to LastPoint do
  begin
    if i = PointIndex then
      PlotArea.Canvas.Brush.Color := clBlue
    else
      PlotArea.Canvas.Brush.Color := clWhite;
    PlotArea.Canvas.Rectangle( Boxes[i].x1, Boxes[i].y1, Boxes[i].x2, Boxes[i].y2 );
  end;

  if nEstPoints > 0 then
  begin
{ ------------------------------------------------------------------------------------------------
    Draw estimated points
  ------------------------------------------------------------------------------------------------ }
    with Sensor.Events[EventForm.EventIndex] do
    begin
      PlotArea.Canvas.Pen.Color := clRed;

      if ShowDischarge then
        q := Points[EstPoint].Rate
      else
        q := Points[EstPoint].Depth;

      x := Round( (Time + Points[EstPoint].Time - tw) * TimeScaleFactor );
//      y := PlotHeight - Round( q * VertScaleFactor * VERTBASE[VertIndex] );
      y := PlotHeight - Round( q * VertScaleFactor * VertBase );
      PlotArea.Canvas.MoveTo( x, y );

      for i := 0 to nEstPoints - 1 do
      begin
        if ShowDischarge then
        q := q_est[i]
      else
        q := d_est[i];

        x := Round( (Time + t_est[i] - tw) * TimeScaleFactor );
//        y := PlotHeight - Round( q * VertScaleFactor * VERTBASE[VertIndex] );
        y := PlotHeight - Round( q * VertScaleFactor * VertBase );

        PlotArea.Canvas.LineTo( x, y );

        Boxes_est[i].x1 := x - BOX;
        Boxes_est[i].y1 := y - BOX;
        Boxes_est[i].x2 := x + BOX;
        Boxes_est[i].y2 := y + BOX;
      end;
    end;

    PlotArea.Canvas.Brush.Color := clWhite;
    for i := 0 to nEstPoints - 1 do
      PlotArea.Canvas.Rectangle( Boxes_est[i].x1, Boxes_est[i].y1, Boxes_est[i].x2, Boxes_est[i].y2 );
  end;
{ ------------------------------------------------------------------------------------------------
  Draw bitmap onto paintbox
  ------------------------------------------------------------------------------------------------ }
  Canvas.Draw( 0, 0, PlotArea );
end;

procedure TPlotBox.CrossHair( Sender: TObject; Shift: TShiftState; X,Y: Integer );
var
  i: integer;
begin
//  Canvas.Draw( 0, 0, PlotArea );
  Canvas.CopyRect( XRect, PlotArea.Canvas, XRect );
  Canvas.CopyRect( YRect, PlotArea.Canvas, YRect );

  Canvas.Pen.Color := clSilver;

  Canvas.MoveTo( 0, Y );
  Canvas.LineTo( Width, Y );

  Canvas.MoveTo( X, 0 );
  Canvas.LineTo( X, Height );

  XRect.Top    := Y;
  XRect.Bottom := Y + 1;
  YRect.Left   := X;
  YRect.Right  := X + 1;

{ ------------------------------------------------------------------------------------------------
  Check for cursor over a box
  ------------------------------------------------------------------------------------------------ }
  PointOver := -1;
  Screen.Cursor := 1; { crosshair }
  for i := FirstPoint to LastPoint do
    if (X >= Boxes[i].x1) and (X <= Boxes[i].x2) then
      if (Y >= Boxes[i].y1) and (Y <= Boxes[i].y2) then
      begin
        PointOver := i;
        Screen.Cursor := 2; { small crosshair }
        Break;
      end;
end;

procedure TPlotBox.MouseClick( Sender: TObject );
begin
  if Editable then
  begin
    PlotArea.Canvas.Pen.Color := clBlue;
    if PointIndex <> -1 then
    begin
{ ------------------------------------------------------------------------------------------------
      Unselect previously selected box
  ------------------------------------------------------------------------------------------------ }
      PlotArea.Canvas.Brush.Color := clWhite;
      PlotArea.Canvas.Rectangle( Boxes[PointIndex].x1, Boxes[PointIndex].y1, Boxes[PointIndex].x2, Boxes[PointIndex].y2 );
      EventForm.EndEventMenu.Enabled  := False;
      EventForm.DeleteMenu.Enabled    := False;
      EventForm.RecessionMenu.Enabled := False;
    end;

    if PointOver <> -1 then
    begin
{ ------------------------------------------------------------------------------------------------
      Highlight selected box
  ------------------------------------------------------------------------------------------------ }
      PlotArea.Canvas.Brush.Color := clBlue;
      PlotArea.Canvas.Rectangle( Boxes[PointOver].x1, Boxes[PointOver].y1, Boxes[PointOver].x2, Boxes[PointOver].y2 );
      EventForm.EndEventMenu.Enabled  := True;
      EventForm.DeleteMenu.Enabled    := True;
      if Recessable then EventForm.RecessionMenu.Enabled := True;
    end;
    PointIndex := PointOver;
{ ------------------------------------------------------------------------------------------------
    Draw bitmap onto paintbox
  ------------------------------------------------------------------------------------------------ }
    Canvas.Draw( 0, 0, PlotArea );
  end;
end;


procedure TPlotBox.CMMouseEnter(var msg: TMessage);
begin
  Screen.Cursor := 1; { crosshair }
end;

procedure TPlotBox.CMMouseLeave(var msg: TMessage);
begin
  Canvas.Draw( 0, 0, PlotArea );
  Screen.Cursor := crDefault;
end;

procedure TEventForm.DischargeMenuClick(Sender: TObject);
begin
  if ShowDischarge then
  begin
    ShowDischarge := False;
    DischargeMenu.Caption := 'Show Discharge';
  end
  else
  begin
    ShowDischarge := True;
    DischargeMenu.Caption := 'Show Depth';
  end;
  SetVertTickSpacing;
  FormPaint( Self );
end;

procedure TEventForm.RecessionMenuClick(Sender: TObject);
var
  i,j:    integer;
  sumx2:  single;
  sumxy:  single;
  sumx:   single;
  sumy:   single;
  m:      single;
  x1:     single;
  y1:     single;
  a:      single;
  b:      single;
  c:      single;
  x2:     single;
  dt:     single;
begin
  if PointIndex > REGRESS then
  begin
    EstPoint := PointIndex;
    dt := Runoffgages[GageIndex].TimeStep / 60; { time step in minutes }
    with Runoffgages[GageIndex].Events[EventIndex] do
    begin
{ ------------------------------------------------------------------------------------------------
      Compute initial slope of recession curve base on linear L-S regression
  ------------------------------------------------------------------------------------------------ }
      sumx2 := 0;
      sumxy := 0;
      sumx  := 0;
      sumy  := 0;
      for i := EstPoint - REGRESS + 1 to EstPoint do
      begin
        sumx2 := sumx2 + Points[i].Time * Points[i].Time;
        sumxy := sumxy + Points[i].Time * Points[i].Depth;
        sumx  := sumx + Points[i].Time;
        sumy  := sumy + Points[i].Depth;
      end;
      m := (sumxy - sumx * sumy / REGRESS) / (sumx2 - sumx * sumx / REGRESS);

      x1 := Points[EstPoint].Time;
      y1 := Points[EstPoint].Depth;

      a := m * m / (4 * y1);
      b := m - 2 * a * x1;
      c := y1 - ( a * x1 * x1 + b * x1);

      x2 := x1 - m / (2 * a); { y(x2) = 0 }

      nEstPoints := Trunc( (x2 - Points[EstPoint].Time) / dt ) + 1;

      SetLength( t_est, nEstPoints );
      SetLength( d_est, nEstPoints );
      SetLength( q_est, nEstPoints );
      SetLength( Boxes_est, nEstPoints );

      j := 0;
      for i := EstPoint + 1 to EstPoint + nEstPoints do
      begin

        t_est[j] := Points[EstPoint].Time + (j + 1) * dt;

        if t_est[j] < x2 then
          d_est[j] := a * t_est[j] * t_est[j] + b * t_est[j] + c
        else
          d_est[j] := 0;

        q_est[j] := Runoffgages[GageIndex].D2Q( d_est[j] );

        Inc( j );
      end;

      if Time + t_est[nEstPoints-1] > te then
      begin
{ ------------------------------------------------------------------------------------------------
        Extend time scale and refresh both plot and scales
  ------------------------------------------------------------------------------------------------ }
        te := (Trunc( Time + t_est[nEstPoints-1] ) div 60 + 1) * 60;
        Duration := te - ts;
        SetTimeTickSpacing;
        FormResize( Self );
      end
      else
{ ------------------------------------------------------------------------------------------------
        Redraw plot only
  ------------------------------------------------------------------------------------------------ }
        PlotBox.DrawPlot( Self );
    end;
  end;
end;

procedure TEventForm.DeleteMenuClick(Sender: TObject);
var
  dt:   single;
  dt12: single;
  j,n:  integer;
begin
  if MessageDlg( 'Delete point?', mtConfirmation, [mbYes, mbNo], 0 ) = mrYes then
  begin
    PlotBox.DrawPlot( Self );
    Screen.Cursor := crHourGlass;

    dt := Runoffgages[GageIndex].TimeStep / 60; { time step in minutes }

    with Sensor.Events[EventIndex] do
      if Points.nPoints > 2 then { minimum of 2 points to define an event }
        if PointIndex = 1 then
        begin
          if (Points[2].Depth > 0) and (Runoffgages[GageIndex].Structure = Flume) then
          begin
            dt12 := Points[2].Time - Points[1].Time;
            if Round( dt12 / dt ) > 1 then { move first pt rather than deleting it and adding a new pt }
            begin
              if not BackedUp then
              begin
{ ------------------------------------------------------------------------------------------------
                Save event to backup table before deleting point
  ------------------------------------------------------------------------------------------------ }
                Runoffgages[GageIndex].Backup( EventIndex );
                BackedUp := True;
              end;
              dt12 := dt12 - dt;
              Time := Time + dt12;
              for j := 2 to Points.nPoints do
                Points[j].Time := Points[j].Time - dt12;
            end;
          end
          else
          begin
            if not BackedUp then
            begin
{ ------------------------------------------------------------------------------------------------
              Save event to backup table before deleting point
  ------------------------------------------------------------------------------------------------ }
              Runoffgages[GageIndex].Backup( EventIndex );
              BackedUp := True;
            end;
            Points.Delete( PointIndex, PointIndex );
          end;
        end
        else if PointIndex = Points.nPoints then
        begin
          n := Points.nPoints;
          if (Points[n-1].Depth > 0) and (Runoffgages[GageIndex].Structure = Flume) then
          begin
            if not BackedUp then
            begin
{ ------------------------------------------------------------------------------------------------
              Save event to backup table before deleting point
  ------------------------------------------------------------------------------------------------ }
              Runoffgages[GageIndex].Backup( EventIndex );
              BackedUp := True;
            end;
            dt12 := Points[n].Time - Points[n-1].Time;
            if Round( dt12 / dt ) > 1 then { move final pt rather than deleting it and adding a new pt }
              Points[n].Time := Points[n-1].Time + dt;
          end
          else
          begin
            if not BackedUp then
            begin
{ ------------------------------------------------------------------------------------------------
              Save event to backup table before deleting point
  ------------------------------------------------------------------------------------------------ }
              Runoffgages[GageIndex].Backup( EventIndex );
              BackedUp := True;
            end;
            Points.Delete( PointIndex, PointIndex );
          end;
        end
        else
        begin
          if not BackedUp then
          begin
{ ------------------------------------------------------------------------------------------------
            Save event to backup table before deleting point
  ------------------------------------------------------------------------------------------------ }
            Runoffgages[GageIndex].Backup( EventIndex );
            BackedUp := True;
          end;
          Points.Delete( PointIndex, PointIndex );
        end;

    Screen.Cursor := 1; { crosshair }
    EndEventMenu.Enabled  := False;
    DeleteMenu.Enabled    := False;
    RecessionMenu.Enabled := False;
    PointIndex := -1;
    PlotBox.DrawPlot( Self );
  end;
end;

procedure TEventForm.EndEventMenuClick(Sender: TObject);
var
  dt:       single;
  i:        integer;
  Zero:     single;
  Note:     word;
  t:        single;
  interval: single;
begin
  if MessageDlg( 'End event at selected point?', mtConfirmation, [mbYes, mbNo], 0 ) = mrYes then
    with Sensor.Events[EventIndex] do
      if PointIndex < Points.nPoints then
      begin
        dt := Runoffgages[GageIndex].TimeStep / 60; { time step in minutes }
        interval := Points[PointIndex+1].Time - Points[PointIndex].Time;
        if (((Points[PointIndex].Depth > 0) and (Points[PointIndex+1].Depth > 0)) and (interval < 3 * dt)) or
           (((Points[PointIndex].Depth > 0) or  (Points[PointIndex+1].Depth > 0)) and (interval < 2 * dt)) then
        begin { each event needs to begin/end at zero depth }
          MessageDlg( 'Points are too crowded', mtInformation, [mbOK], 0 );
          PlotBox.DrawPlot( Self );
        end
        else
        begin
          PlotBox.DrawPlot( Self );
          Screen.Cursor := crHourGlass;
          if not BackedUp then
          begin
{ ------------------------------------------------------------------------------------------------
            Save event to backup table before splitting
  ------------------------------------------------------------------------------------------------ }
            Runoffgages[GageIndex].Backup( EventIndex );
            BackedUp := True;
          end;
          i := PointIndex + 1;
          if Runoffgages[GageIndex].Structure = Flume then
          begin
{ ------------------------------------------------------------------------------------------------
            Insert zero begin/end points if necessary
  ------------------------------------------------------------------------------------------------ }
            Zero := 0;
            Note := 0;
            if Points[PointIndex].Depth > 0 then
            begin
              t := Points[PointIndex].Time + dt;
              Points.Insert( i, t, Zero, Note );
              Inc(i);
            end;
            if Points[i].Depth > 0 then
            begin
              t := Points[i].Time - dt;
              Points.Insert( i, t, Zero, Note );
            end;
          end;
          Sensor.Split( EventIndex, i );
          Screen.Cursor         := 1; { crosshair }
          EndEventMenu.Enabled  := False;
          DeleteMenu.Enabled    := False;
          RecessionMenu.Enabled := False;
          PointIndex            := -1;
          PlotBox.DrawPlot( Self );
        end;
      end;
end;

procedure TEventForm.ShiftMenuClick(Sender: TObject);
var
  i: integer;
begin
  if ShiftDialog.ShowModal = mrOK then
    with Sensor.Events[EventIndex] do
    begin
      PlotBox.DrawPlot( Self );
      Screen.Cursor := crHourGlass;
      if not BackedUp then
      begin
{ ------------------------------------------------------------------------------------------------
        Save event to backup table before splitting
  ------------------------------------------------------------------------------------------------ }
        Runoffgages[GageIndex].Backup( EventIndex );
        BackedUp := True;
      end;
{ ------------------------------------------------------------------------------------------------
    Shift all points up/down according to value of ShiftDialog.Shift (ft)
  ------------------------------------------------------------------------------------------------ }
      for i := 1 to Points.nPoints do
        Points[i].Depth := Max( Points[i].Depth + ShiftDialog.Shift, 0 );

      Screen.Cursor         := 1; { crosshair }
      EndEventMenu.Enabled  := False;
      DeleteMenu.Enabled    := False;
      RecessionMenu.Enabled := False;
      PointIndex            := -1;
      PlotBox.DrawPlot( Self );
    end;
end;

end.
