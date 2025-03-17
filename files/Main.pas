unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ExtCtrls, Math, ComCtrls, Menus, StdCtrls, DB, DBTables;
type
  TMainForm = class( TForm )
    MainBox:       TPaintBox;
    StatusBar:     TStatusBar;
    MainMenu1:     TMainMenu;
    SetInterval:   TMenuItem;
    TimeScrollBar: TScrollBar;
    MarchSelect:   TMenuItem;
    StartStop:     TMenuItem;
    theDB:         TDatabase;
    SensorData:    TQuery;
    ScalePopup: TPopupMenu;
    ScaleMaxMenu: TMenuItem;
    Nine: TMenuItem;
    Ten: TMenuItem;
    Eight: TMenuItem;
    Seven: TMenuItem;
    Six: TMenuItem;
    Five: TMenuItem;
    Four: TMenuItem;
    Three: TMenuItem;
    Two: TMenuItem;
    One: TMenuItem;
    EventPopup: TPopupMenu;
    Approve: TMenuItem;
    EventWindow: TMenuItem;
    DataTypeMenu: TMenuItem;
    ShowPrecip: TMenuItem;
    ShowFlumes: TMenuItem;
    ScaleUnitMenu: TMenuItem;
    Unity: TMenuItem;
    Tenth: TMenuItem;
    Hundredth: TMenuItem;
    MapPopup: TPopupMenu;
    RevertEvent: TMenuItem;
    Space1: TMenuItem;
    Space2: TMenuItem;
    Bevel1: TBevel;
    ListUnchecked: TMenuItem;
    GageQuery: TQuery;
    EventQuery: TQuery;
    FileDialog: TSaveDialog;
    procedure MainBoxPaint( Sender: TObject );
    procedure SetIntervalClick( Sender: TObject );
    procedure TimeScrollBarChange( Sender: TObject );
    procedure MainBoxDblClick( Sender: TObject );
    procedure FormResize( Sender: TObject );
    procedure MainBoxMouseMove( Sender: TObject; Shift: TShiftState; X, Y: Integer );
    procedure MainBoxClick( Sender: TObject );
    procedure FormKeyDown( Sender: TObject; var Key: Word; Shift: TShiftState );
    procedure StartStopClick( Sender: TObject );
    procedure FormShow( Sender: TObject );
    procedure MainBoxContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure SetScaleMax(Sender: TObject);
    procedure SetScaleUnit(Sender: TObject);
    procedure SetDataType(Sender: TObject);
    procedure SetGage( Sender: TObject );
    procedure ApproveClick(Sender: TObject);
    procedure EventWindowClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ScalePopupPopup(Sender: TObject);
    procedure RevertEventClick(Sender: TObject);
    procedure ListUncheckedClick(Sender: TObject);
  private
    procedure DrawMaps;
    procedure DrawTimeSeries;
    function  DepthToColor( index: integer; Depth: single ): TColor;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

uses Misc, HydroSensor, RainData, RunoffData, Passwd, Connect, IntervalDialogUnit,
     EventDialogUnit, EventFormUnit, DateUtils, DataTypes;

{$R *.DFM}

const
{ ------------------------------------------------------------------------------------------------
  Database tables - array index 1 = WG, 2 = SR
  ------------------------------------------------------------------------------------------------ }
  EVENT_STATUS_TABLE = 'eventCodes';
  PRECIP_SITE_POS: array [1..2] of integer = (6, 6); { position of first number in site.name }
  PRECIP_SITE_LEN: array [1..2] of integer = (3, 2); { length of numeric string in site.name }
  RUNOFF_SITE_POS: array [1..2] of integer = (8, 9); { position of first number in site.name }
  RUNOFF_SITE_LEN: array [1..2] of integer = (3, 2); { length of numeric string in site.name }
{ ------------------------------------------------------------------------------------------------
  GUI Layout
  ------------------------------------------------------------------------------------------------ }
  SPACE                    =  4; { vertical space between panels (pixels) }
  SELECTMARGIN             =  5; { for selecting events }
  BASELINE                 =  4; { height of zero line above bottom of panel (pixels) }

  MAX_PRECIP_DEPTH         =  3;    { initial maximum number of units on depth scale for precip data }
  MAX_PRECIP_RATE          = 10;    { initial maximum number of units on intensity scale for precip data }
  PRECIP_DEPTH_UNITS       =  1;    { inches }
  PRECIP_RATE_UNITS        =  1;    { in/hr }
  PRECIP_MID_COLOR_DEPTH   =  0.5;  { depth which displays as pure blue }
  PRECIP_MAX_COLOR_DEPTH   =  2.0;  { depth which displays as pure red }
  PRECIP_TRACE_COLOR_DEPTH =  0.05; { depth below which all are light gray }

  MAX_RUNOFF_DEPTH         = 2;     { initial maximum number of units on depth scale for flume data }
  MAX_RUNOFF_RATE          = 5;     { initial maximum number of units on discharge scale for flume data }
  RUNOFF_DEPTH_UNITS       = 1;     { feet }
  RUNOFF_RATE_UNITS        = 0.1;   { in/hr }
  RUNOFF_MID_COLOR_DEPTH   = 0.1;   { depth which displays as pure blue }
  RUNOFF_MAX_COLOR_DEPTH   = 0.2;   { depth which displays as pure red }
  RUNOFF_TRACE_COLOR_DEPTH = 0.001; { depth below which all are light gray }

  UNCHECKED:    TColor     = clBlue;
  APPROVED:     TColor     = clGreen;
  NOT_APPROVED: TColor     = clRed;

  ARRAY1:       TColor     = clYellow;

type
  TPolygon = record
    nPoints: integer;
    Points:  array of TPoint;
  end;

  TEventInfo = record     { an event falling within the 5-day window }
    EventIndex:  integer;
    BoundingBox: TRect;   { relative to MainBox }
    Hour:        integer;
    Minute:      integer;
    Depth:       single;
    Duration:    integer;
  end;

  TDisplayInfo = record
    DataType:       TDataType;
{ ------------------------------------------------------------------------------------------------
    Hydrologic data
  ------------------------------------------------------------------------------------------------ }
    nGages:         integer;                       { number of raingages or flumes }
    GageNumbers:    array of integer;
    GageIndex:      integer;                       { gage currently selected }
{ ------------------------------------------------------------------------------------------------
    Daily maps
  ------------------------------------------------------------------------------------------------ }
    Polygons:       array of TPolygon;
    E0,N0:          integer;
    Colors:         array of array of TColor;
    Maps:           array [0..2] of TBitmap;
    LocatorMap:     TBitmap;
    MidDepth:       single;
    MaxDepth:       single;
    TraceDepth:     single;
{ ------------------------------------------------------------------------------------------------
    Scaling
  ------------------------------------------------------------------------------------------------ }
    MapWidth:       integer;
    MapHeight:      integer;
    Aspect:         single;
    PanelWidth:     integer;
    PanelHeight:    integer;
    Divisor:        integer;
    MapPanelHeight: integer;
    MapPanelWidth:  integer;
    MapXOffset:     integer;
    MapYOffset:     integer;
{ ------------------------------------------------------------------------------------------------
    Time Series
  ------------------------------------------------------------------------------------------------ }
    PlotHeight:     integer;
    TimeSeries:     array [0..1] of TBitmap;
    EventInfo:      array [1..1000] of TEventInfo; { bounding boxes for events in 5-day window }
    nInfo:          integer;                       { number of events in EventInfo }
    Rate:           TRateType;
{ ------------------------------------------------------------------------------------------------
    Marching selection
  ------------------------------------------------------------------------------------------------ }
    Marching:       boolean;
    MarchIndex:     integer;
{ ------------------------------------------------------------------------------------------------
    Popup Menu
  ------------------------------------------------------------------------------------------------ }
    MaxScales:      array [0..1] of integer;       { maximum number of intervals on the vertical scale for each time series }
    ScaleUnits:     array [0..1] of single;        { magnitude of vertical scale intervals for each time series }
    ScaleUnitIndex: array [0..1] of integer;       { index of selected sub-submenu item in ScalePopup }
  end;

var
  Cancelled:   boolean;                     { true if user cancelled database login }
  Watershed:   integer;
  DataType:    TDataType;                   { data type currently displayed }
  DisplayInfo: array [1..2] of TDisplayInfo;
  IntervalSet: boolean;                     { set true after user specifies a time interval }
  Boundary:    TPolygon;                    { watershed boundary for precip daily totals map }
  StartDOY:    integer;
  EndDOY:      integer;
{ ------------------------------------------------------------------------------------------------
  Scrolling
  ------------------------------------------------------------------------------------------------ }
  DOY: integer;
{ ------------------------------------------------------------------------------------------------
  Mouse
  ------------------------------------------------------------------------------------------------ }
  GageOver:  integer; { set to index of gage when mouse is moved over polygon }
  EventOver: integer; { set to index of EventInfo when over an event trace    }
  Dotted:    boolean; { true after user double-clicks an event, denotes dotted line }
{ ------------------------------------------------------------------------------------------------
  Popup Menu
  ------------------------------------------------------------------------------------------------ }
  SeriesIndex: integer; { index (0 or 1) to the time series panel over which it appeared }


procedure TMainForm.FormCreate(Sender: TObject);
var
  Error:       boolean;
begin
{ ------------------------------------------------------------------------------------------------
  Create supporting forms - for some reason autocreation in the project file isn't working
  ------------------------------------------------------------------------------------------------ }
  PasswordDlg         := TPasswordDlg.Create( Self );
  ConnectBanner       := TConnectBanner.Create( Self );
  IntervalDialog      := TIntervalDialog.Create( Self );
  EventDialog         := TEventDialog.Create( Self );
{ ------------------------------------------------------------------------------------------------
  Database login
  ------------------------------------------------------------------------------------------------ }
  PasswordDlg.Caption := 'Logon to Database: ' + theDB.AliasName;
  Error := True;
  while Error do
    if PasswordDlg.ShowModal = mrOK then
      try
        ConnectBanner.Show;
        ConnectBanner.Repaint;
        Screen.Cursor := crHourGlass;
        theDB.Params.Clear;
        theDB.Params.Add( 'USER NAME=' + PasswordDlg.UsernameEdit.Text );
        theDB.Params.Add( 'PASSWORD='  + PasswordDlg.PasswordEdit.Text );
        theDB.Open;
        Error := False;
        Cancelled := False;
      except
        ConnectBanner.Close;
        Screen.Cursor := crDefault;
        MessageDlg( 'Invalid Username or Password', mtError, [mbOk], 0 );
      end
    else
    begin
      Error := False;
      Cancelled := True;
      Release;
    end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  PasswordDlg.Free;
  ConnectBanner.Free;
  IntervalDialog.Free;
  EventDialog.Free;
  Close;
end;

procedure TMainForm.FormShow( Sender: TObject );
var
  InFile:     TextFile;
  Emax:       integer;
  Nmax:       integer;
  i,j,n:      integer;
  GageNumber: integer;
  Sensor:     THydroSensor;
  NewItem:    TMenuItem;
begin
  if not Cancelled then
  begin
{ ------------------------------------------------------------------------------------------------
    1 = Walnut Gulch, 2 = Santa Rita
  ------------------------------------------------------------------------------------------------ }
    Watershed := PasswordDlg.WatershedBox.ItemIndex + 1;
{ ------------------------------------------------------------------------------------------------
    Allocate and populate Raingages array - only gage numbers <= 100
  ------------------------------------------------------------------------------------------------ }
    SensorData.SQL.Clear;
    SensorData.SQL.Add( 'select site.name,sensor.id from site,sensor where '
                      + 'sensor.siteID=site.id and site.watershed='
                      +  IntToStr( Watershed )
                      + 'and sensor.sensorType=10 order by site.id' );
    SensorData.Open;
    SetLength( Raingages, SensorData.RecordCount );
    SetLength( DisplayInfo[1].GageNumbers, SensorData.RecordCount );
    n := 0;
    SensorData.First;
    while not SensorData.Eof do
    begin
      GageNumber := StrToInt( Copy( SensorData['name'], PRECIP_SITE_POS[Watershed], PRECIP_SITE_LEN[Watershed] ) );
//      if GageNumber <= 100 then
//      begin
        Raingages[n] := TRaingage.Create( theDB.DatabaseName, SensorData['id'] );
        DisplayInfo[1].GageNumbers[n] := GageNumber;
        Inc( n );
//      end;
      SensorData.Next;
    end;
    DisplayInfo[1].DataType      := Precip;
    DisplayInfo[1].nGages        := n;
    DisplayInfo[1].MaxScales[0]  := MAX_PRECIP_DEPTH;
    DisplayInfo[1].MaxScales[1]  := MAX_PRECIP_RATE;
    DisplayInfo[1].ScaleUnits[0] := PRECIP_DEPTH_UNITS;
    DisplayInfo[1].ScaleUnits[1] := PRECIP_RATE_UNITS;
    DisplayInfo[1].Rate          := Average;
    DisplayInfo[1].MidDepth      := PRECIP_MID_COLOR_DEPTH;
    DisplayInfo[1].MaxDepth      := PRECIP_MAX_COLOR_DEPTH;
    DisplayInfo[1].TraceDepth    := PRECIP_TRACE_COLOR_DEPTH;
{ ------------------------------------------------------------------------------------------------
    Runoffgages array
  ------------------------------------------------------------------------------------------------ }
    SensorData.SQL.Clear;
    SensorData.SQL.Add( 'select site.name,sensor.id from site,sensor where '
                     +  'sensor.siteID=site.id and site.watershed='
                     +   IntToStr( Watershed )
                     + ' and (sensor.sensorType=20 or sensor.sensorType=30) order by site.id' );
    SensorData.Open;
    SetLength( Runoffgages, SensorData.RecordCount );
    SetLength( DisplayInfo[2].GageNumbers, SensorData.RecordCount );
    n := 0;
    SensorData.First;
    while not SensorData.Eof do
    begin
      GageNumber := StrToInt( Copy( SensorData['name'], RUNOFF_SITE_POS[Watershed], RUNOFF_SITE_LEN[Watershed] ) );
      Runoffgages[n] := TRunoffGage.Create( theDB.DatabaseName, SensorData['id'] );
      DisplayInfo[2].GageNumbers[n] := GageNumber;
      Inc( n );
      SensorData.Next;
    end;
    DisplayInfo[2].DataType      := Runoff;
    DisplayInfo[2].nGages        := n;
    DisplayInfo[2].MaxScales[0]  := MAX_RUNOFF_DEPTH;
    DisplayInfo[2].MaxScales[1]  := MAX_RUNOFF_RATE;
    DisplayInfo[2].ScaleUnits[0] := RUNOFF_DEPTH_UNITS;
    DisplayInfo[2].ScaleUnits[1] := RUNOFF_RATE_UNITS;
    DisplayInfo[2].Rate          := Instantaneous;
    DisplayInfo[2].MidDepth      := RUNOFF_MID_COLOR_DEPTH;
    DisplayInfo[2].MaxDepth      := RUNOFF_MAX_COLOR_DEPTH;
    DisplayInfo[2].TraceDepth    := RUNOFF_TRACE_COLOR_DEPTH;

    EventDialog.GetStatusCodes( theDB.DatabaseName, EVENT_STATUS_TABLE );
{ ------------------------------------------------------------------------------------------------
    Read boundary data from a file
  ------------------------------------------------------------------------------------------------ }
    AssignFile( InFile, 'boundary.dat' );
    Reset(InFile);
    try
      with Boundary do
      begin
        Readln( InFile, nPoints );
        SetLength( Points, nPoints );
        for i := 0 to nPoints - 1 do Readln( InFile, Points[i].x, Points[i].y );
      end;
    finally
      CloseFile( InFile );
    end;

    for n := 1 to 2 do
      with DisplayInfo[n] do
      begin
{ ------------------------------------------------------------------------------------------------
        Get polygon data and find the minimum and maximum limits
  ------------------------------------------------------------------------------------------------ }
        SetLength( Polygons, nGages );
        E0   := 1000000000;
        Emax := 0;
        N0   := 1000000000;
        Nmax := 0;
        for i := 0 to nGages - 1 do
          with Polygons[i] do
          begin
            case DataType of
              Precip: Sensor := Raingages[i];
              Runoff: Sensor := Runoffgages[i];
            end;
            nPoints := Sensor.nVertices;
            if nPoints > 0 then
            begin
              SetLength( Points, nPoints );
              for j := 0 to nPoints - 1 do
              begin
                Points[j] := Sensor.Vertices[j];
                if Points[j].x < E0   then E0   := Points[j].x;
                if Points[j].x > Emax then Emax := Points[j].x;
                if Points[j].y < N0   then N0   := Points[j].y;
                if Points[j].y > Nmax then Nmax := Points[j].y;
              end;
            end;
          end;
{ ------------------------------------------------------------------------------------------------
        Compute map dimensions in polygon units and height/width aspect ratio
  ------------------------------------------------------------------------------------------------ }
        MapWidth  := Emax - E0;
        MapHeight := Nmax - N0;
        Aspect    := MapHeight / MapWidth;
{ ------------------------------------------------------------------------------------------------
        Allocate array for daily depth colors and set to white for initial display
  ------------------------------------------------------------------------------------------------ }
        SetLength(Colors, nGages, 366);
        for i := 0 to nGages - 1 do
          for j := 0 to 365 do
            Colors[i,j] := clWhite;
{ ------------------------------------------------------------------------------------------------
        Create bitmaps on which to draw daily depth maps, time series and sensor locator map.
        Intensity of red color component (lowest order byte) corresponds to index of gage in
        Raingages[]
  ------------------------------------------------------------------------------------------------ }
        for i := 0 to 2 do Maps[i] := TBitmap.Create;
        for i := 0 to 1 do TimeSeries[i] := TBitmap.Create;
        LocatorMap := TBitmap.Create;
{ ------------------------------------------------------------------------------------------------
        Initialize working variables for this data type
  ------------------------------------------------------------------------------------------------ }
        GageIndex := -1;
        Marching  := False;
      end;
{ ------------------------------------------------------------------------------------------------
    Initialize global working variables
  ------------------------------------------------------------------------------------------------ }
    DOY                 :=  1;
    EventOver           := -1;
    GageOver            := -1;
    IntervalSet         := False;
    Dotted              := False;
    DataType            := Precip;
    RevertEvent.Enabled := False;
{ ------------------------------------------------------------------------------------------------
    Initialize gage map popup menu
  ------------------------------------------------------------------------------------------------ }
    MapPopup.Items.Clear;
    for i := 0 to DisplayInfo[1].nGages - 1 do
    begin
      NewItem := TMenuItem.Create(Self);
      NewItem.Caption := IntToStr( DisplayInfo[1].GageNumbers[i] );
      NewItem.OnClick := SetGage;
      if i mod 20 = 0 then NewItem.Break := mbBreak;
      MapPopup.Items.Add( NewItem );
    end;

    ConnectBanner.Close;
    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.SetIntervalClick(Sender: TObject);
var
  i,j,k,m,n: integer;
  Sensor:    THydroSensor;
  Error:     boolean;
begin
  if IntervalDialog.ShowModal = mrOK then
  begin
    Screen.Cursor := crHourGlass;
    n             := 0;
    Error         := False;
    StartDOY      := IntervalDialog.StartDOY;
{ ------------------------------------------------------------------------------------------------
    The display interval is truncated at the end of the year if it continues into the next year
  ------------------------------------------------------------------------------------------------ }
    if IntervalDialog.EndYear = IntervalDialog.StartYear then
      EndDOY := IntervalDialog.EndDOY
    else
      EndDOY := DaysInAYear( IntervalDialog.StartYear );

    for k := 1 to 2 do
      with DisplayInfo[k] do
      begin
        for i := 0 to nGages - 1 do
          for j := 0 to 365 do
            Colors[i,j] := clWhite;
        try
          m := 0;
          for i := 0 to nGages - 1 do
          begin
            case DataType of
              Precip: Sensor := Raingages[i];
              Runoff: Sensor := Runoffgages[i];
            end;
            Sensor.SetInterval( IntervalDialog.StartYear, IntervalDialog.StartDOY,
                                IntervalDialog.EndYear,   IntervalDialog.EndDOY );
                                
            m := m + Sensor.Events.nEvents;
            n := n + m;

            if Sensor.Events.nEvents > 0 then
            begin
{ ------------------------------------------------------------------------------------------------
              Compute polygon colors
  ------------------------------------------------------------------------------------------------ }
              for j := IntervalDialog.StartDOY to EndDOY do
                Colors[i,j-1] := DepthToColor( k, Sensor.DailyValue[j] );
            end;
          end;

          if m > 0 then
          begin
            if DataType = Main.DataType then
            begin
              MarchSelect.Enabled := True;
              MainBoxPaint(Self);
            end;
          end
          else if DataType = Main.DataType then
            MarchSelect.Enabled := False
            
        except
          MessageDlg( 'An error occurred while retrieving data', mtError, [mbOk], 0 );
          if DataType = Main.DataType then
            MarchSelect.Enabled := False;
        end;
      end;

    if not Error and (n = 0) then
    begin
      MessageDlg( 'No data in interval', mtInformation, [mbOk], 0 );
      IntervalSet := False
    end
    else
    begin
      StatusBar.Panels.Items[1].Text := IntToStr( IntervalDialog.StartYear );
      DOY := IntervalDialog.StartDOY;
      TimeScrollBar.Position := DOY;
      IntervalSet := True;
    end;

    Screen.Cursor := crDefault;
  end;
end;

procedure TMainForm.FormResize( Sender: TObject );
var
  i,j:    integer;
  Points: array [0..3000] of TPoint;
begin
  if not Cancelled then
{ ------------------------------------------------------------------------------------------------
  Compute display parameters for current data type
  ------------------------------------------------------------------------------------------------ }
  with DisplayInfo[Ord( DataType )] do
  begin
{ ------------------------------------------------------------------------------------------------
    Compute panel size based on three rows of equal size
  ------------------------------------------------------------------------------------------------ }
    PanelWidth := (ClientWidth - 1) div 3;
    PanelHeight := (ClientHeight - TimeScrollBar.Height - StatusBar.Height - 4 * SPACE) div 3;
{ ------------------------------------------------------------------------------------------------
    Map subpanels will span either the full height or full width of the panels
  ------------------------------------------------------------------------------------------------ }
    MapPanelHeight := PanelHeight;
    MapPanelWidth := Round( PanelHeight / Aspect );

    if MapPanelWidth > PanelWidth then
    begin
      MapPanelWidth  := PanelWidth;
      MapPanelHeight := Round( PanelWidth * Aspect );
    end;
{ ------------------------------------------------------------------------------------------------
    Divisor scales map units to pixels
  ------------------------------------------------------------------------------------------------ }
    Divisor := Max(MapWidth div MapPanelWidth, MapHeight div MapPanelHeight) + 1;
{ ------------------------------------------------------------------------------------------------
    Recompute panel dimensions
  ------------------------------------------------------------------------------------------------ }
    MapPanelWidth  := MapWidth  div Divisor;
    MapPanelHeight := MapHeight div Divisor;
{ ------------------------------------------------------------------------------------------------
    Map subpanels will be centered within their panels
  ------------------------------------------------------------------------------------------------ }
    MapXOffset := (PanelWidth  - MapPanelWidth)  div 2;
    MapYOffset := (PanelHeight - MapPanelHeight) div 2;
{ ------------------------------------------------------------------------------------------------
    Set width of paintbox to clip time series to three days
  ------------------------------------------------------------------------------------------------ }
    MainBox.Width  := 3 * PanelWidth  + 1;
    MainBox.Height := 3 * PanelHeight + 2 * SPACE;
{ ------------------------------------------------------------------------------------------------
    Center paintbox on client area
  ------------------------------------------------------------------------------------------------ }
    MainBox.Top  := SPACE;
    MainBox.Left := (ClientWidth - 3 * PanelWidth) div 2;
{ ------------------------------------------------------------------------------------------------
    Size/clear bitmaps
  ------------------------------------------------------------------------------------------------ }
    for i := 0 to 2 do
    begin
      Maps[i].Width  := MapPanelWidth;
      Maps[i].Height := MapPanelHeight;
      Maps[i].Canvas.Brush.Color := clWhite;
      Maps[i].Canvas.FillRect(Rect(0, 0, Width, Height));
    end;

    for i := 0 to 1 do
    begin
      TimeSeries[i].Width  := 5 * PanelWidth;
      TimeSeries[i].Height := PanelHeight;
    end;

    LocatorMap.Width  := MapPanelWidth;
    LocatorMap.Height := MapPanelHeight;
    LocatorMap.Canvas.Brush.Color := clRed; { Red = no gage }
    LocatorMap.Canvas.FillRect(Rect(0, 0, Width, Height));
{ ------------------------------------------------------------------------------------------------
    Height of plottable area on time series panels
  ------------------------------------------------------------------------------------------------ }
    PlotHeight := PanelHeight - BASELINE - 1;
{ ------------------------------------------------------------------------------------------------
    Draw sensor locator map
  ------------------------------------------------------------------------------------------------ }
    for i := 0 to nGages - 1 do
      if Polygons[i].nPoints > 0 then
      begin
        LocatorMap.Canvas.Pen.Color := TColor(i);
        LocatorMap.Canvas.Brush.Color := TColor(i);
        for j := 0 to Polygons[i].nPoints - 1 do
        begin
          Points[j].x := (Polygons[i].Points[j].x - E0) div Divisor;
          Points[j].y := MapPanelHeight - (Polygons[i].Points[j].y - N0) div Divisor;
        end;
        LocatorMap.Canvas.Polygon( Slice( Points, Polygons[i].nPoints ) );
      end;
  end;
end;

procedure TMainForm.MainBoxPaint( Sender: TObject );
begin
{ ------------------------------------------------------------------------------------------------
  Draw map panels and middle three time series panels
  ------------------------------------------------------------------------------------------------ }
  DrawMaps;
  DrawTimeSeries;
end;

procedure TMainForm.DrawMaps;
var
  i,j,k: integer;
  x_pixel,y_pixel: integer;
  Points: array [0..3000] of TPoint;
begin
  with DisplayInfo[Ord( DataType )] do
    for i := 0 to 2 do
      with Maps[i] do
      begin
{ ------------------------------------------------------------------------------------------------
      Draw polygons on map bitmap
  ------------------------------------------------------------------------------------------------ }
        Canvas.Pen.Color := clBlack;
        for j := 0 to nGages - 1 do
          if Polygons[i].nPoints > 0 then
          begin
            Maps[i].Canvas.Brush.Color := Colors[j, DOY+i-1];
            if j = GageIndex then
              Canvas.Pen.Width := 2
            else
              Canvas.Pen.Width := 1;
            for k := 0 to Polygons[j].nPoints - 1 do
            begin
              Points[k].X := (Polygons[j].Points[k].x - E0) div Divisor;
              Points[k].Y := Height - (Polygons[j].Points[k].y - N0) div Divisor - 1;
            end;
            Canvas.Polygon( Slice( Points, Polygons[j].nPoints ) );
          end;
        if DataType = Precip then
        begin
{ ------------------------------------------------------------------------------------------------
          Draw boundary on bitmap
  ------------------------------------------------------------------------------------------------ }
          Canvas.Pen.Color := clRed;
          Canvas.Pen.Width := 1;
          x_pixel := (Boundary.Points[0].x - E0) div Divisor;
          y_pixel := Height - (Boundary.Points[0].y - N0) div Divisor;
          Maps[i].Canvas.MoveTo( x_pixel, y_pixel );
          for j := 1 to Boundary.nPoints - 1 do
          begin
            x_pixel := (Boundary.Points[j].x - E0) div Divisor;
            y_pixel := Height - (Boundary.Points[j].y - N0) div Divisor;
            Canvas.LineTo( x_pixel, y_pixel )
          end;
        end;
{ ------------------------------------------------------------------------------------------------
        Draw map frame
  ------------------------------------------------------------------------------------------------ }
        Canvas.Brush.Style := bsClear;
        Canvas.Pen.Color := clBlack;
        Canvas.Rectangle(0, 0, Width, Height);
        Canvas.Brush.Style := bsSolid;
{ ------------------------------------------------------------------------------------------------
        Draw bitmap onto paintbox
  ------------------------------------------------------------------------------------------------ }
        MainBox.Canvas.Draw( MapXOffset + i * PanelWidth, MapYOffset, Maps[i] );
      end;
end;

procedure TMainForm.DrawTimeSeries;
var
  i,j,k:         integer;
  x_pixel:       integer;
  y_pixel:       integer;
  y_min:         integer;
  y_max:         integer;
  y_value:       integer;
  FmtStr:        string;
  yString:       string;
  DOYString:     string;
  x_offset:      integer;
  Beg_DOY:       integer;
  End_DOY:       integer;
  Sensor:        THydroSensor;
  Event_End_DOY: integer;
begin
  with DisplayInfo[Ord( DataType )] do
  begin
    for i := 0 to 1 do
      with TimeSeries[i] do
      begin
{ ------------------------------------------------------------------------------------------------
        Draw outer box of current time series
  ------------------------------------------------------------------------------------------------ }
        Canvas.Pen.Color := clBlack;
        Canvas.Brush.Color := clWhite;
        Canvas.Rectangle(0, 0, Width, Height);
{ ------------------------------------------------------------------------------------------------
        Draw baseline, scale lines and labels at one unit intervals
  ------------------------------------------------------------------------------------------------ }
        Canvas.Pen.Color := clSilver;
        y_pixel := Height - BASELINE;
        Canvas.MoveTo(1, y_pixel);
        Canvas.LineTo(Width - 1, y_pixel);
        y_value := 1;
        j := Round( -Log10( ScaleUnits[i] ) );
        if j = 0 then
          FmtStr := '%1.0f'
        else if j = 1 then
          FmtStr := '%1.1f'
        else if j = 2 then
          FmtStr := '%2.2f';
        while y_value < MaxScales[i] do
        begin
          y_pixel := Height - y_value * Height div MaxScales[i] - 1 - BASELINE;
          Canvas.MoveTo(1, y_pixel);
          Canvas.LineTo(Width - 1, y_pixel);
          yString := Format( FmtStr, [y_value * ScaleUnits[i]]);
          y_pixel := y_pixel - Canvas.TextHeight( yString ) div 2;
          Canvas.TextOut( PanelWidth + 5, y_pixel, yString );
          Inc( y_value );
        end;
{ ------------------------------------------------------------------------------------------------
        Draw day dividers
  ------------------------------------------------------------------------------------------------ }
        Canvas.Pen.Color := clBlack;
        for j := 1 to 4 do
        begin
          x_pixel := j * PanelWidth;
          Canvas.MoveTo(x_pixel, 0);
          Canvas.LineTo(x_pixel, Height);
        end;
      end;
{ ------------------------------------------------------------------------------------------------
    Put DOY's on top panel
  ------------------------------------------------------------------------------------------------ }
    for k := 0 to 2 do
    begin
      DOYString := IntToStr(DOY + k);
      x_pixel := (k + 1) * PanelWidth  + (TimeSeries[0].Canvas.TextWidth( DOYString ) + PanelWidth) div 2;
      TimeSeries[0].Canvas.TextOut( x_pixel, 10, DOYString );
    end;

    if IntervalSet and (GageIndex >= 0) then
    begin
{ ------------------------------------------------------------------------------------------------
      Data has been loaded and a gage selected from the map
      Draw traces on all five panels (except for DOY = 1 and DOY = 364)
  ------------------------------------------------------------------------------------------------ }
      if DOY > 1 then
        Beg_DOY := DOY - 1
      else
        Beg_DOY := DOY;

      if DOY < 364 then
        End_DOY := DOY + 3
      else
        End_DOY := DOY + 2;

      nInfo := 0;

      case DataType of
        Precip: Sensor := Raingages[GageIndex];
        Runoff: Sensor := Runoffgages[GageIndex];
      end;

      with Sensor do
      begin
{ ------------------------------------------------------------------------------------------------
        Indicate array 1's which lie within the specified interval
  ------------------------------------------------------------------------------------------------ }
        TimeSeries[0].Canvas.Pen.Color := ARRAY1;
        for j := 1 to ArrayOnes.nArrayOnes do
          if (ArrayOnes[j].DOY >= Beg_DOY) and (ArrayOnes[j].DOY <= End_DOY) then
          begin
            x_offset := (ArrayOnes[j].DOY - DOY + 1) * PanelWidth;
            x_pixel := x_offset + (Round( ArrayOnes[j].Time ) * PanelWidth) div 1440;
            TimeSeries[0].Canvas.MoveTo( x_pixel, 1 );
            TimeSeries[0].Canvas.LineTo( x_pixel, TimeSeries[0].Height - 1 );
          end
          else if ArrayOnes[j].DOY > End_DOY then
{ ------------------------------------------------------------------------------------------------
            Since array 1's are sorted by date, save some time by skipping the rest
  ------------------------------------------------------------------------------------------------ }
            Break;
{ ------------------------------------------------------------------------------------------------
        Identify events from the selected gage with data in the specified interval
  ------------------------------------------------------------------------------------------------ }
        for j := 1 to Events.nEvents do
        with Events[j] do
        begin
          Event_End_DOY := DOY + Trunc( Points[Points.nPoints].Time / 1440 );
          if ((DOY           >= Beg_DOY) and (DOY           <= End_DOY)) or { event begins in interval }
             ((Event_End_DOY >= Beg_DOY) and (Event_End_DOY <= End_DOY)) or { event ends in interval   }
             ((DOY            < Beg_DOY) and (Event_End_DOY  > End_DOY))    { event contains interval  }
          then
            begin
              Inc(nInfo);
              EventInfo[nInfo].Hour     := Round(Time) div 60;
              EventInfo[nInfo].Minute   := Round(Time) mod 60;
              EventInfo[nInfo].Depth    := Volume;
              EventInfo[nInfo].Duration := Round(Points[Points.nPoints].Time);
{ ------------------------------------------------------------------------------------------------
              Draw depth
  ------------------------------------------------------------------------------------------------ }
              with TimeSeries[0] do
              begin
                if Status <= 0 then
                  Canvas.Pen.Color := UNCHECKED
                else if Status = 1 then
                  Canvas.Pen.Color := APPROVED
                else
                  Canvas.Pen.Color := NOT_APPROVED;

                EventInfo[nInfo].EventIndex := j;

                if (nInfo = EventOver) and Dotted then { draw event with a dotted line }
                  Canvas.Pen.Style := psDot
                else
                  Canvas.Pen.Style := psSolid;

                x_offset := (DOY - Main.DOY + 1) * PanelWidth;

                x_pixel := x_offset + (Round( Time + Points[1].Time ) * PanelWidth) div 1440;
                y_pixel := PlotHeight - Round( Points[1].Depth * PlotHeight / (ScaleUnits[0] * MaxScales[0]) );
                Canvas.MoveTo( x_pixel, y_pixel );

                EventInfo[nInfo].BoundingBox.Left := x_pixel - PanelWidth;

                y_min := y_pixel;
                y_max := y_pixel;

                for k := 2 to Points.nPoints do
                begin
                  x_pixel := x_offset + (Round( Time + Points[k].Time ) * PanelWidth) div 1440;
                  y_pixel := PlotHeight - Round( Points[k].Depth * PlotHeight / (ScaleUnits[0] * MaxScales[0]) );
                  if y_pixel > y_min then y_min := y_pixel;
                  if y_pixel < y_max then y_max := y_pixel;
                  Canvas.LineTo( x_pixel, y_pixel );
                end;

                EventInfo[nInfo].BoundingBox.Right := x_pixel - PanelWidth;
                EventInfo[nInfo].BoundingBox.Top := y_max + PanelHeight + SPACE;
                EventInfo[nInfo].BoundingBox.Bottom := y_min + PanelHeight + SPACE;

                Canvas.Pen.Style := psSolid;
              end;
{ ------------------------------------------------------------------------------------------------
              Draw rates (in/hr)
  ------------------------------------------------------------------------------------------------ }
              with TimeSeries[1] do
                if Rate = Average then
                begin
                  Canvas.Pen.Color := clBlue;
                  x_pixel := x_offset + (Round( Time + Points[1].Time ) * PanelWidth) div 1440;
                  y_pixel := Height - 1 - BASELINE; { start at 0 }
                  Canvas.MoveTo( x_pixel, y_pixel );
                  for k := 2 to Points.nPoints do
                  begin
                    try
                      y_pixel := Height - Round( Points[k].Rate * Height / (ScaleUnits[1] * MaxScales[1]) ) - 1 - BASELINE;
                    except
                      y_pixel := 0;
                    end;
                    Canvas.LineTo( x_pixel, y_pixel );
                    x_pixel := x_offset + (Round( Time + Points[k].Time ) * PanelWidth) div 1440;
                    Canvas.LineTo( x_pixel, y_pixel );
                  end;
                  y_pixel := Height - 1 - BASELINE; { end at 0 }
                  Canvas.LineTo( x_pixel, y_pixel );
                end
                else { instantaneous }
                begin
                  Canvas.Pen.Color := clBlue;
                  x_pixel := x_offset + (Round( Time + Points[1].Time ) * PanelWidth) div 1440;
                  try
                    y_pixel := Height - Round( Points[1].Rate * Height / (ScaleUnits[1] * MaxScales[1]) ) - 1 - BASELINE;
                  except
                    y_pixel := 0;
                  end;
                  Canvas.MoveTo( x_pixel, y_pixel );
                  for k := 2 to Points.nPoints do
                  begin
                    try
                      y_pixel := Height - Round( Points[k].Rate * Height / (ScaleUnits[1] * MaxScales[1]) ) - 1 - BASELINE;
                    except
                      y_pixel := 0;
                    end;
                    x_pixel := x_offset + (Round( Time + Points[k].Time ) * PanelWidth) div 1440;
                    Canvas.LineTo( x_pixel, y_pixel );
                  end;
                end;
            end
          else if DOY > End_DOY then
{ ------------------------------------------------------------------------------------------------
            Since events are sorted by date, save some time by skipping the rest
  ------------------------------------------------------------------------------------------------ }
            Break;
        end;
      end;
    end;
{ ------------------------------------------------------------------------------------------------
    Draw time series bitmaps onto MainBox
  ------------------------------------------------------------------------------------------------ }
    for i := 0 to 1 do
      MainBox.Canvas.Draw( -PanelWidth, PanelHeight + SPACE + i * (PanelHeight + SPACE), TimeSeries[i] );
  end;
end;

procedure TMainForm.TimeScrollBarChange(Sender: TObject);
begin
{ ------------------------------------------------------------------------------------------------
  Update map and timeline panels continuously 
  ------------------------------------------------------------------------------------------------ }
  DOY := TimeScrollBar.Position;
  MainBoxPaint(Self);
end;

procedure TMainForm.MainBoxMouseMove( Sender: TObject; Shift: TShiftState; X, Y: Integer );
var
  i:    integer;
  Xrel: integer;
begin
  with DisplayInfo[Ord( DataType )] do
  begin
    EventOver := -1;
    GageOver := -1;
    StatusBar.Panels.Items[4].Text := '';
    if (Y > MapYOffset) and (Y < MapPanelHeight + MapYOffset) then
    begin
      for i := 0 to 2 do
      begin
        Xrel := X - MapXOffset - i * PanelWidth;
        if (Xrel > 0) and (Xrel < MapPanelWidth) then
        begin
{ ------------------------------------------------------------------------------------------------
          Cursor is over a map panel - allow gage list popup menu to appear
  ------------------------------------------------------------------------------------------------ }
          MainBox.PopupMenu := MapPopup;
          GageOver := LocatorMap.Canvas.Pixels[Xrel, Y-MapYOffset];
          if (GageOver > -1) and (GageOver < 255) then
            StatusBar.Panels.Items[4].Text := IntToStr(GageNumbers[GageOver]);
        end;
      end;
    end
    else
    begin
{ ------------------------------------------------------------------------------------------------
      Cursor is over a time series panel - allow vertical scale popup menu to appear
  ------------------------------------------------------------------------------------------------ }
      MainBox.PopupMenu := ScalePopup;
{ ------------------------------------------------------------------------------------------------
      See if cursor is over an event
  ------------------------------------------------------------------------------------------------ }
      for i := 1 to nInfo do
        with EventInfo[i] do
          if (X > BoundingBox.Left - SELECTMARGIN) and (X < BoundingBox.Right + SELECTMARGIN) and
             (Y < BoundingBox.Bottom + SELECTMARGIN) and (Y > BoundingBox.Top - SELECTMARGIN) then
          begin
            EventOver := i;
            StatusBar.Panels.Items[4].Text := Format(' Start = %d:%.2d    Max. Depth = %.2f    Duration = %d min.',
                                                   [Hour,Minute,Depth,Duration]);
            MainBox.PopupMenu := EventPopup;
            Break;
          end;
    end;
  end;
end;

procedure TMainForm.MainBoxClick( Sender: TObject );
begin
{ ------------------------------------------------------------------------------------------------
  If user clicked on a map polygon, update display
  ------------------------------------------------------------------------------------------------ }
  with DisplayInfo[Ord( DataType )] do
    if (GageOver >= 0) and (GageOver < 255) then
    begin
      GageIndex := GageOver;
      StatusBar.Panels.Items[3].Text := IntToStr( GageNumbers[GageIndex] );
      MainBoxPaint(Self);
    end;
end;

procedure TMainForm.MainBoxDblClick( Sender: TObject );
var
  StatusCode: word;
  NewCode:    word;
  EventIndex: integer;
  Sensor:     THydroSensor;
  j:          integer;
{ ------------------------------------------------------------------------------------------------
  For temporary file write
  ------------------------------------------------------------------------------------------------ }
{
  OutFile:    TextFile;
  mmhr:       single;
  cms:        single;
}
begin
  if EventOver >= 1 then
    with DisplayInfo[Ord( DataType )] do
    begin
{ ------------------------------------------------------------------------------------------------
      Redraw event with a dotted line
  ------------------------------------------------------------------------------------------------ }
      Dotted := True;
      DrawTimeSeries;
      case DataType of
        Precip: Sensor := Raingages[GageIndex];
        Runoff: Sensor := Runoffgages[GageIndex];
      end;
      EventIndex := EventInfo[EventOver].EventIndex;
      StatusCode := Sensor.Events[EventIndex].Status;
      NewCode := EventDialog.ShowModalEx( StatusCode );
      Sensor.Events[EventIndex].Status := NewCode;
      Dotted := False;
{ ------------------------------------------------------------------------------------------------
      Recompute polygon colors (event contribution to daily total will be removed if it was rejected)
  ------------------------------------------------------------------------------------------------ }
      for j := StartDOY to EndDOY do
        Colors[GageIndex,j-1] := DepthToColor( Ord( DataType ), Sensor.DailyValue[j] );

      MainBoxPaint(Self);

{ ------------------------------------------------------------------------------------------------
      Temporary file write
  ------------------------------------------------------------------------------------------------ }
{
      AssignFile(OutFile, 'out.txt');
      Rewrite(OutFile);

      with EventInfo[EventOver] do
        Writeln( OutFile, Format( 'Start time = %d:%.2d', [Hour,Minute] ) );

      Writeln( OutFile, 'Elapsed time(min), mm/hr, cu.m/s' );

      with Sensor.Events[EventIndex] do
        for j := 1 to Points.nPoints do
        begin
          mmhr := Points[j].Rate * 25.4;
          cms := Points[j].Rate * 36900 * 43560 * Power( 0.3048, 3 ) / 12 / 3600; // wg flume 1
          Writeln( OutFile, Format( '%10.1f,%6.2f,%12.4f', [Points[j].Time, mmhr, cms] ) );
        end;

      CloseFile( OutFile );
}
    end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  i,j:    integer;
  code:   word;
  Sensor: THydroSensor;
label
  PrevGage, NextGage;
begin
  with DisplayInfo[Ord( DataType )] do
  begin
    if Marching then
      if Key = VK_HOME then
{ ------------------------------------------------------------------------------------------------
      Home key - highlight current gage in marching sequence
  ------------------------------------------------------------------------------------------------ }
      begin
        GageOver := MarchIndex;
        MainBoxClick(Self);
      end

      else if (Key = VK_NEXT) and (MarchIndex > 0)then
{ ------------------------------------------------------------------------------------------------
      Pagedown key - march backward to previous gage with rain
  ------------------------------------------------------------------------------------------------ }
      begin
        for i := MarchIndex - 1 downto 0 do
          for j := DOY - 1 to DOY + 1 do
            if Colors[i, j] <> clWhite then goto PrevGage;
        PrevGage:
          if i >= 0 then
          begin
            MarchIndex := i;
            GageOver   := i;
            MainBoxClick(Self);
          end;
      end

      else if Key = VK_PRIOR then
{ ------------------------------------------------------------------------------------------------
      Pageup key - march forward to next gage with rain
  ------------------------------------------------------------------------------------------------ }
      begin
        if MarchIndex = nGages - 1 then
{ ------------------------------------------------------------------------------------------------
        We're done marching
  ------------------------------------------------------------------------------------------------ }
        begin
          MessageDlg('Finished march',mtInformation,[mbOk],0);
          Marching := False;
          StartStop.Caption := 'Start';
        end
        else
        begin
          for i := MarchIndex + 1 to nGages - 1 do
            for j := DOY - 1 to DOY + 1 do
              if Colors[i, j] <> clWhite then goto NextGage;
          NextGage:
            if i = nGages then
{ ------------------------------------------------------------------------------------------------
            Oops - loop continued past the final gage because it had no data
  ------------------------------------------------------------------------------------------------ }
            begin
              MessageDlg('Finished march',mtInformation,[mbOk],0);
              Marching := False;
              StartStop.Caption := 'Start';
            end
            else
            begin
              MarchIndex := i;
              GageOver   := i;
              MainBoxClick(Self);
            end;
        end;
      end;

    if (Key = VK_F8) or (Key = VK_F9) then
{ ------------------------------------------------------------------------------------------------
    Give all events currently displayed a code indicating approval or not checked
  ------------------------------------------------------------------------------------------------ }
    begin
      case Key of
        VK_F8: code := 1; { approved }
        VK_F9: code := 0; { not checked }
      end;
      for i := 1 to nInfo do
      begin
        j := EventInfo[i].EventIndex;
        if DataType = Precip then
        begin
          with Raingages[GageIndex].Events[j] do
{ ------------------------------------------------------------------------------------------------
            Don't include events outside the current 3-day view
            Don't undo codes > 1 (disapproved events)
  ------------------------------------------------------------------------------------------------ }
            if (DOY >= Main.DOY) and (DOY <= Main.DOY + 2) and (Status < 2) then Status := code;
        end
        else
          with Runoffgages[GageIndex].Events[j] do
            if (DOY >= Main.DOY) and (DOY <= Main.DOY + 2) and (Status < 2) then Status := code;
      end;
      DrawTimeSeries;
    end;
  end;
end;

procedure TMainForm.StartStopClick(Sender: TObject);
var
 i: integer;
begin
  with DisplayInfo[Ord( DataType )] do
    if Marching then
    begin
      Marching := False;
      StartStop.Caption := 'Start';
    end
    else
    begin
      Marching := True;
      StartStop.Caption := 'Stop';
{ ------------------------------------------------------------------------------------------------
      Skip gages without data
  ------------------------------------------------------------------------------------------------ }
      for i := 0 to nGages - 1 do
        if Colors[i, DOY] <> clWhite then Break;
{ ------------------------------------------------------------------------------------------------ }
      MarchIndex := i;
      GageOver   := i;
      MainBoxClick(Self);
    end;
end;

function TMainForm.DepthToColor( index: integer; Depth: single ): TColor;
const
  TRACE_COLOR = $00F0F0F0; { light gray }
type
{ ------------------------------------------------------------------------------------------------
  Typecast to TColor type
  ------------------------------------------------------------------------------------------------ }
  TRGB = record
    red:      byte;
    green:    byte;
    blue:     byte;
    not_used: byte;
  end;
{ ------------------------------------------------------------------------------------------------
  Typecast to integer type
  ------------------------------------------------------------------------------------------------ }
  TByteRec = record
    byte1: byte;
    byte2: byte;
    byte3: byte;
    byte4: byte;
  end;

var
{ ------------------------------------------------------------------------------------------------
  Typecasting variables
  ------------------------------------------------------------------------------------------------ }
  RGB:    TRGB;
  dColor: integer;
begin
  RGB.not_used := 0;

  with DisplayInfo[index] do
    if Depth = 0 then
      Result := clWhite
    else if Depth < TraceDepth then
      Result := TRACE_COLOR
    else if Depth <= MidDepth then
    begin
      dColor := Round((Trunc(10 * Depth / MidDepth) + 1) * 255 / 10);
      RGB.blue := 255;
      RGB.red := TByteRec(Max(0, 255 - dColor)).byte1;
      RGB.green := RGB.red;
      Result := TColor(RGB);
    end
    else
    begin
      dColor := Round((Trunc(9 * (Depth - MidDepth) / (MaxDepth - MidDepth))  + 1) * 255 / 9);
      RGB.red := TByteRec(Min(255, dColor)).byte1;
      RGB.blue := TByteRec(Max(0, 255 - dColor)).byte1;
      RGB.green := 0;
      Result := TColor(RGB);
    end;
end;

procedure TMainForm.MainBoxContextPopup( Sender: TObject; MousePos: TPoint;  var Handled: Boolean );
var
  i: integer;
begin
  with DisplayInfo[Ord( DataType )] do
  begin
    if MousePos.Y > PanelHeight + SPACE then
      if MousePos.Y < 2 * PanelHeight + SPACE then
        SeriesIndex := 0
      else if MousePos.Y > 2 * (PanelHeight + SPACE) then
        SeriesIndex := 1;

    for i := 0 to ScaleMaxMenu.Count - 1 do ScaleMaxMenu.Items[i].Checked := False;
    ScaleMaxMenu.Items[10 - MaxScales[SeriesIndex]].Checked := True;
  end;
end;

procedure TMainForm.SetScaleMax( Sender: TObject );
begin
  DisplayInfo[Ord( DataType )].MaxScales[SeriesIndex] := 10 - TMenuItem(Sender).MenuIndex;
  DrawTimeSeries;
end;

procedure TMainForm.SetScaleUnit( Sender: TObject );
begin
  DisplayInfo[Ord( DataType )].ScaleUnits[SeriesIndex] := Power( 10, -TMenuItem(Sender).MenuIndex );
  DrawTimeSeries;
end;

procedure TMainForm.SetGage( Sender: TObject );
begin
  GageOver := TMenuItem(Sender).MenuIndex;
  MainBoxClick(Self);
end;

procedure TMainForm.SetDataType( Sender: TObject );
var
  i:       integer;
  NewItem: TMenuItem;
begin
  DataType := TDataType(TMenuItem(Sender).MenuIndex + 1);
  MapPopup.Items.Clear;
  with DisplayInfo[Ord( DataType )] do
  begin
    for i := 0 to nGages - 1 do
    begin
      NewItem := TMenuItem.Create(Self);
      NewItem.Caption := IntToStr( GageNumbers[i] );
      NewItem.OnClick := SetGage;
      if i mod 20 = 0 then NewItem.Break := mbBreak;
      MapPopup.Items.Add( NewItem );
    end;
    if GageIndex >= 0 then
      StatusBar.Panels.Items[3].Text := IntToStr( GageNumbers[GageIndex] )
    else
       StatusBar.Panels.Items[3].Text := '';
  end;
  if DataType = Precip then
    RevertEvent.Enabled := False
  else
    RevertEvent.Enabled := True;
  FormResize(Self);
  Repaint;
end;

procedure TMainForm.ApproveClick( Sender: TObject );
begin
  MainBoxDblClick( Self );
end;

procedure TMainForm.EventWindowClick(Sender: TObject);
begin
  with DisplayInfo[Ord( DataType )] do
    EventForm.ShowModalEx( GageIndex, EventInfo[EventOver].EventIndex, DataType );
end;

procedure TMainForm.ScalePopupPopup(Sender: TObject);
var
  i: integer;
begin
  for i := 0 to ScaleUnitMenu.Count - 1 do ScaleUnitMenu.Items[i].Checked := False;
  ScaleUnitMenu.Items[Round( -Log10( DisplayInfo[Ord( DataType )].ScaleUnits[SeriesIndex] ) )].Checked := True;
end;

procedure TMainForm.RevertEventClick(Sender: TObject);
begin
  if MessageDlg( 'Revert to original event?', mtConfirmation, [mbYes, mbNo], 0 ) = mrYes then
  begin
    Screen.Cursor := crHourGlass;
    with DisplayInfo[Ord( DataType )] do
      Runoffgages[GageIndex].Revert( EventInfo[EventOver].EventIndex );
    Screen.Cursor := crDefault;
    MainBoxPaint(Self);
  end;
end;

procedure TMainForm.ListUncheckedClick(Sender: TObject);
const
  WATERSHED:    array [1..2] of string = ('Walnut Gulch', 'Santa Rita');
  SENSOR_TYPE:  array [1..3] of string = ('Precip', 'Flume', 'Weir');
  SITE_NUM_POS: array [1..2,1..3] of integer = ((6, 8, 8),(6, 9, 9)); { position of first number in site.name }
  SITE_NUM_LEN: array [1..2] of integer = (3, 2); { length of numeric string in site.name }
  EVENT_TABLE:  array [1..3] of string = ('precipEvents', 'runoffEvents', 'runoffEvents');
var
  i,j,n:      integer;
  OutFile:    TextFile;
begin
  if FileDialog.Execute then
  try
    Screen.Cursor := crHourGlass;
    AssignFile( OutFile, FileDialog.FileName );
    Rewrite( OutFile );
    try
      for i := 1 to 2 do   // 1 = Walnut Gulch, 2 = Santa Rita
      begin
        Writeln( OutFile, ' ' );
        Writeln( OutFile, WATERSHED[i] );
        for j := 1 to 3 do //10 = precip, 20 = flume, 30 = weir
        begin
          Writeln( OutFile, ' ' );
          Writeln( OutFile, '  ', SENSOR_TYPE[j] );
          Writeln( OutFile, ' ' );
          GageQuery.SQL.Clear;
          GageQuery.SQL.Add( ' select site.name,sensor.id from site,sensor where'
                           + ' sensor.siteID=site.id and site.watershed='
                           +   IntToStr( i )
                           + ' and sensor.sensorType='
                           +   IntToStr( j * 10 )
                           + ' order by site.id' );
          GageQuery.Open;
          GageQuery.First;
          n := 0;
          while not GageQuery.Eof do
          begin
            EventQuery.SQL.Clear;
            EventQuery.SQL.Add( ' select * from '
                              +   EVENT_TABLE[j]
                              + ' where sensorID='
                              +   IntToStr( GageQuery['id'] )
                              + ' and code=0 order by startTime' );
            EventQuery.Open;
            EventQuery.First;
            if EventQuery.RecordCount > 0 then
            begin
              Writeln( OutFile, '    ', Copy( GageQuery['name'], SITE_NUM_POS[i,j], SITE_NUM_LEN[i] ) );
              while not EventQuery.Eof do
              begin
                Writeln( OutFile, '      ', DateTimeToStr( EventQuery['startTime'] ) );
                EventQuery.Next;
                Inc( n );
              end;
            end;
            GageQuery.Next;
          end;
          if n = 0 then
          begin
            Writeln( OutFile, ' ' );
            Writeln( OutFile, '  No unchecked events' );
          end;
        end;
      end;
    except
      MessageDlg( 'Database error', mtError, [mbOk], 0 );
    end;
  finally
    CloseFile( OutFile );
    Screen.Cursor := crDefault;
  end;
end;

end.

