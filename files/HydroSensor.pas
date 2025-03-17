unit HydroSensor;

interface

uses
  DBTables, Types;

type
  TFloatFuncPtr = function: single of object;
  TWordFuncPtr  = function: word of object;
  TIntFuncPtr   = function: integer of object;
  TFloatProcPtr = procedure(Arg: single) of object;
  TWordProcPtr  = procedure(Arg: word) of object;

  TDataPoint = class

{ This class is not intended to be used outside of TPoints, as its property values are
  obtained from methods defined in TPoints }

  private

  { These point back to methods in the TPoints object that created it }

    GetTimePtr:  TFloatFuncPtr;
    GetDepthPtr: TFloatFuncPtr;
    GetRatePtr:  TFloatFuncPtr;
    GetNotePtr:  TWordFuncPtr;
    GetIDPtr:     TIntFuncPtr;
    SetTimePtr:  TFloatProcPtr;
    SetDepthPtr: TFloatProcPtr;
    SetRatePtr:  TFloatProcPtr;
    SetNotePtr:  TWordProcPtr;

  { The property access methods simply redirect using the above pointers }

    function     GetTime: single;
    procedure    SetTime(NewTime: single);
    function     GetDepth: single;
    procedure    SetDepth(NewDepth: single);
    function     GetRate: single;
    procedure    SetRate(NewRate: single);
    function     GetNote: word;
    procedure    SetNote(NewNote: word);
    function     GetID: integer;
  public
    property     Time:  single  read GetTime  write SetTime;  { elapsed time }
    property     Depth: single  read GetDepth write SetDepth; { depth }
    property     Rate:  single  read GetRate  write SetRate;  { rate }
    property     Note:  word    read GetNote  write SetNote;  { quality code }
    property     ID:    integer read GetID;
  end;

  TPoints = class
  private
    Point:           TDataPoint;                       { a portal to access PointData records as TDataPoint properties }
    PointData:       TQuery;                           { the actual data }
    RecNo:           integer;                          { currently active record in PointData }
    Rates:           array of single;                  { rates associated with datapoints }

  { The following three fields are necessary to allow TPoints to recompute rates, daily depths and event volume
    when data are changed (e.g. see SetDepth implementation) }

    CompRates:       procedure(i: integer) of object;  { computes rates associated with depths for event i }
    CompDailyValues: procedure of object;              { computes a daily value for each day in the interval }
    CompVolume:      procedure(i: integer) of object;  { computes a volume associated with event i }

    Event:           integer;                          { event index: Events.Event[Points.Event].Points }
    EventID:         integer;
    function         GetPoint(i: integer): TDataPoint; { move to record i in PointData (if not already there) }
    function         GetNumberofPoints: integer;       { return the number of records in PointData }

  { These are the actual property access methods used in TDataPoint }

    function         GetTime:  single;
    function         GetDepth: single;
    function         GetRate:  single;
    function         GetNote:  word;
    function         GetID:    integer;
    procedure        SetTime(  NewTime:  single);
    procedure        SetDepth( NewDepth: single );
    procedure        SetRate(  NewRate:  single );
    procedure        SetNote(  NewNote:  word);
  public
    property         Points[i: integer]: TDataPoint read GetPoint; default;
    property         nPoints: integer read GetNumberofPoints;
    procedure        Delete(FirstPt, LastPt: integer); { delete one or more contiguous records in PointData }
    procedure        Append(Time, Depth: single; Note: word); { add a record to the end of PointData }
    procedure        Insert(BeforePt: integer; Time, Depth: single; Note: word); { Insert a record into PointData before record BeforePt }
    constructor      Create;
    destructor       Destroy; override;
  end;

  TEvent = class

{ This class is not intended to be used outside of TEvents, as its property values are
  obtained from methods defined in TEvents }

  private

  { These point back to methods in the TEvents object that created it }

    GetYearPtr:   TWordFuncPtr;
    GetDOYPtr:    TWordFuncPtr;
    GetTimePtr:   TFloatFuncPtr;
    GetStatusPtr: TWordFuncPtr;
    GetIDPtr:     TIntFuncPtr;
    SetYearPtr:   TWordProcPtr;
    SetDOYPtr:    TWordProcPtr;
    SetTimePtr:   TFloatProcPtr;
    SetStatusPtr: TWordProcPtr;

    CompDailyValues: procedure of object; { updated in SetStatus }

    procedure     SetVolume(Vol: single);

  { These property access methods simply redirect using the above pointers }

    function      GetYear: word;
    procedure     SetYear(NewYear: word);
    function      GetDOY: word;
    procedure     SetDOY(NewDOY: word);
    function      GetTime: single;
    procedure     SetTime(NewTime: single);
    function      GetStatus: word;
    procedure     SetStatus(NewStatus: word);
    function      GetID: integer;
  protected
    FVolume:      single;
  public
    Points:       TPoints;
    property      Year:   word    read GetYear   write SetYear;   { starting year }
    property      DOY:    word    read GetDOY    write SetDOY;    { starting day of year }
    property      Time:   single  read GetTime   write SetTime;   { starting time, minutes from beginning of day }
    property      Volume: single  read FVolume   write SetVolume;
    property      Status: word    read GetStatus write SetStatus; { status code }
    property      ID:     integer read GetID;
    constructor   Create;
    destructor    Destroy; override;
  end;

  TEvents = class
  private
    Event:        array of TEvent;                { portals to access EventData records as TEvent properties }
    EventData:    TQuery;                         { the actual event data }
    RecNo:        integer;                        { currently active record in EventData }
    function      GetEvent(i: integer): TEvent;   { move to record i in EventData (if not already there) }
    function      GetNumberofEvents: integer;     { return the number of records in EventData }

  { These are the actual property access methods used in TEvent }

    function      GetYear:   word;
    function      GetDOY:    word;
    function      GetTime:   single;
    function      GetStatus: word;
    function      GetID:     integer;
    procedure     SetYear(NewYear: word);
    procedure     SetDOY(NewDOY: word);
    procedure     SetTime(NewTime: single);
    procedure     SetStatus(NewStatus: word);
    procedure     SetPointers(i: integer);
  public
    property      Events[i: integer]: TEvent read GetEvent; default;
    property      nEvents: integer read GetNumberofEvents;
    procedure     Delete(i: integer);
    destructor    Destroy; override;
  end;

  TArrayOne = class

{ This class is not intended to be used outside of TArrayOnes, as its property values are
  obtained from methods defined in TArrayOnes }

  private

  { These point back to methods in the TArrayOnes object that created it }

    GetYearPtr: TWordFuncPtr;
    GetDOYPtr:  TWordFuncPtr;
    GetTimePtr: TFloatFuncPtr;

  { The property access methods simply redirect using the above pointers }

    function    GetYear: word;
    function    GetDOY: word;
    function    GetTime: single;
  public
    property    Year: word   read GetYear; { year }
    property    DOY:  word   read GetDOY;  { day of year }
    property    Time: single read GetTime; { time, minutes from beginning of day }
  end;

  TArrayOnes = class
  private
    ArrayOne:     TArrayOne;                          { portal to access ArrayOneData records as TArrayOne properties }
    ArrayOneData: TQuery;                             { the actual array 1 data }
    RecNo:        integer;                            { currently active record in ArrayOneData }
    function      GetArrayOne(i: integer): TArrayOne; { move to record i in ArrayOneData (if not already there) }
    function      GetNumberofArrayOnes: integer;      { return the number of records in ArrayOneData }

  { These are the actual property  access methods used in TArrayOne }

    function      GetYear:   word;
    function      GetDOY:    word;
    function      GetTime:   single;
  public
    property    ArrayOnes[i: integer]: TArrayOne read GetArrayOne; default;
    property    nArrayOnes:            integer   read GetNumberofArrayOnes;
    destructor  Destroy; override;
  end;

  THydroSensor = class

{ Descendent classes override the CompRate method to provide meaningful rates for with each time, depth data pair }
{ Descendent classes override the CompDailyValues method to provide a meaningful daily value for each day in the interval }
{ Descendent classes override the CompVolume method to provide a meaningful event volume for each event in the interval }

  private
    EventTable:   string;
    PointTable:   string;
    VertexData:   TQuery;
    function      GetNumberofVertices:       integer;
    function      GetVertex(i: integer):     TPoint;
    function      GetDailyValue(i: integer): single;
  protected
    DatabaseName: string;
    SensorID:     integer;
    FStartYear:   word;
    FStartDOY:    word;
    FEndYear:     word;
    FEndDOY:      word;
    DailyValues:  array [1..366] of single;
    procedure     CompRates(i: integer); virtual;
    procedure     CompVolume(i: integer); virtual;
    procedure     CompDailyValues; virtual;
  public
    Events:       TEvents;
    ArrayOnes:    TArrayOnes;
    property      StartYear:              word    read FStartYear;
    property      StartDOY:               word    read FStartDOY;
    property      EndYear:                word    read FEndYear;
    property      EndDOY:                 word    read FEndDOY;
    property      nVertices:              integer read GetNumberofVertices;
    property      Vertices[i: integer]:   TPoint  read GetVertex;
    property      DailyValue[i: integer]: single  read GetDailyValue;
    procedure     SetInterval(StartYear, StartDOY, EndYear, EndDOY: word); virtual;
    procedure     Split(i, StartPt: integer);
    constructor   Create(DatabaseName, EventTable, PointTable: string; SensorID: integer); virtual;
  end;

const
{ Event status codes }

  UNCHECKED = 0;
  APPROVED = 1;

{ Data point note codes }

  NO_ESTIMATE = 0;

implementation

uses
  SysUtils, DateUtils;

{ TDataPoint methods ---------------------------------------------- }

function TDataPoint.GetTime: single;
begin
  Result := GetTimePtr;
end;

procedure TDataPoint.SetTime(NewTime: single);
begin
  SetTimePtr(NewTime);
end;

function TDataPoint.GetDepth: single;
begin
  Result := GetDepthPtr;
end;

procedure TDataPoint.SetDepth(NewDepth: single);
begin
  SetDepthPtr(NewDepth);
end;

function TDataPoint.GetRate: single;
begin
  Result := GetRatePtr;
end;

procedure TDataPoint.SetRate(NewRate: single);
begin
  SetRatePtr(NewRate);
end;

function TDataPoint.GetNote: word;
begin
  Result := GetNotePtr;
end;

procedure TDataPoint.SetNote(NewNote: word);
begin
  SetNotePtr(NewNote);
end;

function TDataPoint.GetID: integer;
begin
  Result := GetIDPtr;
end;

{ TPoints methods ------------------------------------------------- }

function TPoints.GetPoint(i: integer): TDataPoint;
begin
{ Move to record i in PointData if not already there }
  if i <> RecNo then
  begin
    PointData.MoveBy(i - RecNo);
    RecNo := i;
  end;
  Result := Point;
end;

function TPoints.GetTime: single;
begin
  Result := PointData['elapsedTime'];
end;

procedure TPoints.SetTime(NewTime: single);
begin
  PointData.Edit;
  PointData['elapsedTime'] := NewTime;
  PointData.Post;
  CompRates(Event);
  CompVolume(Event);
  CompDailyValues;
end;

function  TPoints.GetDepth: single;
begin
  Result := PointData['depth'];
end;

procedure TPoints.SetDepth(NewDepth: single);
begin
  PointData.Edit;
  PointData['depth'] := NewDepth;
  PointData.Post;
  CompRates(Event);
  CompVolume(Event);
  CompDailyValues;
end;

function  TPoints.GetRate: single;
begin
  if Rates <> nil then
    Result := Rates[RecNo-1]
  else
    Result := 0;
end;

procedure TPoints.SetRate(NewRate: single);
begin
  if Rates <> nil then
    Rates[RecNo-1] := NewRate;
end;

function  TPoints.GetNote: word;
begin
  Result := PointData['code'];
end;

procedure TPoints.SetNote(NewNote: word);
begin
  PointData.Edit;
  PointData['code'] := NewNote;
  PointData.Post;
end;

function  TPoints.GetID: integer;
begin
  Result := PointData['id'];
end;

function TPoints.GetNumberofPoints: integer;
begin
  Result := PointData.RecordCount;
end;

procedure TPoints.Delete(FirstPt, LastPt: integer);
{ Delete one or more contiguous records in PointData }
var
  j: integer;
begin
  if (LastPt >= FirstPt) and (LastPt <= PointData.RecordCount)then
  begin
  { Navigate to the record in PointData indicated by FirstPt }
    PointData.MoveBy(FirstPt - RecNo);
  { Successively delete records through LastPt }
    for j := 1 to LastPt - FirstPt + 1 do
    begin
//      PointData.Edit;
      PointData.Delete;
//      PointData.Post;
    end;
    RecNo := FirstPt;
    SetLength( Rates, PointData.RecordCount );
    CompRates(Event);
    CompVolume(Event);
    CompDailyValues;
  end;
end;

procedure TPoints.Append(Time, Depth: single; Note: word);
{ Add a record to the end of PointData }
begin
  PointData.Append;
//  PointData.Edit;
  PointData['elapsedTime'] := Time;
  PointData['depth']       := Depth;
  PointData['code']        := Note;
  PointData['eventID']     := EventID;
  PointData.Post;
  PointData.Close;
  PointData.Open;
  SetLength( Rates, PointData.RecordCount );
  CompRates(Event);
  CompVolume(Event);
  CompDailyValues;
end;

procedure TPoints.Insert(BeforePt: integer; Time, Depth: single; Note: word);
{ Insert a record into PointData before record BeforePt }
begin
  if (BeforePt >= 1) and (BeforePt <= PointData.RecordCount)then
  { Navigate to the record in PointData indicated by FirstPt }
    PointData.MoveBy(BeforePt - RecNo);
  PointData.Insert;
//  PointData.Edit;
  PointData['elapsedTime'] := Time;
  PointData['depth']       := Depth;
  PointData['code']        := Note;
  PointData['eventID']     := EventID;
  PointData.Post;
  PointData.Close;
  PointData.Open;
  SetLength( Rates, PointData.RecordCount );
  CompRates(Event);
  CompVolume(Event);
  CompDailyValues;
end;

constructor TPoints.Create;
begin
  inherited Create;
  Point := TDataPoint.Create;
{ Redirect property accesss in Point back to TPoints }
  Point.GetTimePtr  := GetTime;
  Point.GetDepthPtr := GetDepth;
  Point.GetRatePtr  := GetRate;
  Point.GetNotePtr  := GetNote;
  Point.SetTimePtr  := SetTime;
  Point.SetDepthPtr := SetDepth;
  Point.SetRatePtr  := SetRate;
  Point.SetNotePtr  := SetNote;
  Point.GetIDPtr    := GetID;
end;

destructor TPoints.Destroy;
begin
  PointData.Close;
  PointData.Free;
  Point.Free;
  inherited;
end;

{ TEvent methods -------------------------------------------------- }

function TEvent.GetYear: word;
begin
  Result := GetYearPtr;
end;

procedure TEvent.SetYear(NewYear: word);
begin
  SetYearPtr(NewYear);
end;

function TEvent.GetDOY: word;
begin
  Result := GetDOYPtr;
end;

procedure TEvent.SetDOY(NewDOY: word);
begin
  SetDOYPtr(NewDOY);
end;

function TEvent.GetTime: single;
begin
  Result := GetTimePtr;
end;

procedure TEvent.SetTime(NewTime: single);
begin
  SetTimePtr(NewTime);
end;

function TEvent.GetStatus: word;
begin
  Result := GetStatusPtr;
end;

procedure TEvent.SetStatus(NewStatus: word);
begin
  SetStatusPtr(NewStatus);
  CompDailyValues;
end;

procedure TEvent.SetVolume(Vol: single);
begin
  FVolume := Vol;
end;

function TEvent.GetID: integer;
begin
  Result := GetIDPtr;
end;

constructor TEvent.Create;
begin
  inherited Create;
  Points := TPoints.Create;
end;

destructor  TEvent.Destroy;
begin
  Points.Free;
  inherited;
end;

{ TEvents ------------------------------------------------- }

function  TEvents.GetEvent(i: integer): TEvent;
begin
{ Move to record i in EventData if not already there }
  if i <> RecNo then
  begin
    EventData.MoveBy(i - RecNo);
    RecNo := i;
  end;
  Result := Event[i-1]; { zero-based }
end;

function  TEvents.GetYear: word;
var
  Year,DOY: Word;
begin
  DecodeDateDay(EventData['startTime'], Year, DOY);
  Result := Year;
end;

procedure TEvents.SetYear(NewYear: word);
var
  Year,DOY: Word;
  StartTime: TDateTime;
begin
  StartTime := EventData['startTime'];
  DecodeDateDay(startTime, Year, DOY);
  EventData.Edit;
  EventData['startTime'] := IncYear(StartTime, NewYear - Year);
  EventData.Post;
end;

function  TEvents.GetDOY: word;
var
  Year,DOY: Word;
begin
  DecodeDateDay(EventData['startTime'], Year, DOY);
  Result := DOY;
end;

procedure TEvents.SetDOY(NewDOY: word);
var
  Year,DOY: Word;
  StartTime: TDateTime;
begin
  StartTime := EventData['startTime'];
  DecodeDateDay(startTime, Year, DOY);
  EventData.Edit;
  EventData['startTime'] := IncDay(StartTime, NewDOY - DOY);
  EventData.Post;
end;

function  TEvents.GetTime: single; { minutes from beg of day }
var
  Hour,Min,Sec,MSec: word;
begin
  DecodeTime(EventData['startTime'], Hour, Min, Sec, MSec);
  Result := Hour * 60 + Min + Sec / 60;
end;

procedure TEvents.SetTime(NewTime: single);
var
  Hour,Min,Sec: word;
  WholeMinutes: integer;
begin
  WholeMinutes := Trunc(NewTime);
  Hour := WholeMinutes div 60;
  Min := WholeMinutes mod 60;
  Sec := Trunc(Frac(NewTime) * 60.0);
  EventData.Edit;
  EventData['startTime'] := Int(EventData['startTime']) + EncodeTime(Hour, Min, Sec, 0);
  EventData.Post;
end;

function  TEvents.GetStatus: word;
begin
  Result := EventData['code'];
end;

procedure TEvents.SetStatus(NewStatus: word);
begin
  EventData.Edit;
  EventData['code'] := NewStatus;
  EventData.Post;
end;

function  TEvents.GetID: integer;
begin
  Result := EventData['id'];
end;

procedure TEvents.SetPointers(i: integer);
{ Redirect property accesss in Event[i] back to Events }
begin
  Event[i].GetYearPtr   := GetYear;
  Event[i].GetDOYPtr    := GetDOY;
  Event[i].GetTimePtr   := GetTime;
  Event[i].GetStatusPtr := GetStatus;
  Event[i].SetYearPtr   := SetYear;
  Event[i].SetDOYPtr    := SetDOY;
  Event[i].SetTimePtr   := SetTime;
  Event[i].SetStatusPtr := SetStatus;
  Event[i].GetIDPtr     := GetID;
end;

function  TEvents.GetNumberofEvents: integer;
begin
  Result := EventData.RecordCount;
end;

procedure TEvents.Delete(i: integer);
var
  j: integer;
begin
{ Delete the point records associated with this event }
  Event[i-1].Points.Delete(1, Event[i-1].Points.nPoints);
{ Destroy the TEvent object }
  Event[i-1].Free;
{ Move Event array elements up to fill the gap, and reduce the array size by one element }
  for j := i - 1 to High(Event) - 1 do
    Event[j] := Event[j+1];
  SetLength(Event, Length(Event) - 1);
{ Move to record i in EventData if not already there }
  if i <> RecNo then
  begin
    EventData.MoveBy(i - RecNo);
    RecNo := i;
  end;
  if RecNo = EventData.RecordCount then Dec(RecNo); { we deleted the last record }
{ Delete the database record }
  EventData.Delete;
end;

destructor TEvents.Destroy;
var
  i: integer;
begin
  for i := 0 to High( Event ) do Event[i].Free;
  EventData.Close;
  EventData.Free;
  inherited;
end;

{ TArrayOne methods ----------------------------------------------- }

function TArrayOne.GetYear: word;
begin
  Result := GetYearPtr;
end;

function TArrayOne.GetDOY: word;
begin
  Result := GetDOYPtr;
end;

function TArrayOne.GetTime: single;
begin
  Result := GetTimePtr;
end;

{ TArrayOnes methods ---------------------------------------------- }

function  TArrayOnes.GetArrayOne(i: integer): TArrayOne;
begin
{ Move to record i in ArrayOneData if not already there }
  if i <> RecNo then
  begin
    ArrayOneData.MoveBy(i - RecNo);
    RecNo := i;
  end;
  Result := ArrayOne;
end;

function  TArrayOnes.GetYear: word;
var
  Year,DOY: Word;
begin
  DecodeDateDay(ArrayOneData['repDate'], Year, DOY);
  Result := Year;
end;

function  TArrayOnes.GetDOY: word;
var
  Year,DOY: Word;
begin
  DecodeDateDay(ArrayOneData['repDate'], Year, DOY);
  Result := DOY;
end;

function  TArrayOnes.GetTime: single; { minutes from beg of day }
var
  Hour,Min,Sec,MSec: word;
begin
  DecodeTime(ArrayOneData['repDate'], Hour, Min, Sec, MSec);
  Result := Hour * 60 + Min + Sec / 60;
end;

function  TArrayOnes.GetNumberofArrayOnes: integer;
begin
  Result := ArrayOneData.RecordCount;
end;

destructor TArrayOnes.Destroy;
begin
  ArrayOne.Free;
  ArrayOneData.Free;
  inherited;
end;

{ THydroSensor methods -------------------------------------------- }

function THydroSensor.GetNumberofVertices:    integer;
begin
  Result := VertexData.RecordCount;
end;

function THydroSensor.GetVertex(i: integer):  TPoint;
begin
{ Navigate to the record in VertexData indicated by Index }
  VertexData.First;
  VertexData.MoveBy(i - 1);
{ Copy/convert fields from the current record into TPoint fields }
  Result.X := VertexData['x'];
  Result.Y := VertexData['y'];
end;

procedure THydroSensor.CompRates(i: integer);
{ Compute rates for event i}
var
  j: integer;
begin
  for j := 1 to Events.Event[i].Points.nPoints do
    Events.Event[i].Points.Rates[j-1] := 0;
end;

procedure THydroSensor.CompVolume(i: integer);
{ Compute volume for event i}
begin
  Events[i].Volume := 0;
end;

procedure THydroSensor.CompDailyValues;
{ Compute some kind of daily value for each day in the interval - note that the interval
  is truncated at the end of the year if it continues into the next year }
var
  j,n: integer;
begin
  if EndYear = StartYear then
    n := EndDOY
  else
    n := DaysInAYear( StartYear );
  for j := StartDOY to n do
    DailyValues[j] := 0;
end;

function THydroSensor.GetDailyValue(i: integer): single;
begin
  Result := DailyValues[i];
end;

procedure THydroSensor.SetInterval( StartYear, StartDOY, EndYear, EndDOY: word );
var
  i: integer;
begin
  Events.Free;
  Events := TEvents.Create;
  Events.EventData := TQuery.Create(nil);
  Events.EventData.DatabaseName := DatabaseName;
  FStartYear := StartYear;
  FStartDOY  := StartDOY;
  FEndYear   := EndYear;
  FEndDOY    := EndDOY;
{ For now we won't expand the interval to include events which cross an endpoint }
  with Events do
  begin
    EventData.SQL.Clear;
    EventData.SQL.Add('select * from '      + EventTable                                      +
                     ' where sensorID = '   + IntToStr( SensorID )                            +
                     ' and startTime >= ''' + DateToStr(EncodeDateDay( StartYear, StartDOY )) +
                   ''' and startTime <  ''' + DateToStr(EncodeDateDay( EndYear, EndDOY ) + 1) +
                   ''' order by startTime');
    EventData.RequestLive := True;
    EventData.Open;
    EventData.First;
  { For each record in EventData, create an Event object }
    SetLength( Event, EventData.RecordCount );
    i := 0;
    RecNo := 1;
    while not EventData.Eof do
    begin
      Event[i] := TEvent.Create;
      SetPointers(i);
      Event[i].CompDailyValues := Self.CompDailyValues;
      with Event[i].Points do
      begin
        CompRates := Self.CompRates;
        CompDailyValues := Self.CompDailyValues;
        CompVolume := Self.CompVolume;
      { Configure and open query }
        PointData := TQuery.Create(nil);
        PointData.DatabaseName := DatabaseName;
        PointData.SQL.Add('select * from '  + PointTable                +
                         ' where eventID= ' + IntToStr(EventData['id']) +
                         ' order by elapsedTime');
        PointData.RequestLive := True;
        PointData.Open;
        PointData.First;
        RecNo := 1;
        SetLength( Rates, PointData.RecordCount );
        Event   := Self.Events.RecNo;
        EventID := EventData['id'];
        CompRates( Event );
      end;
      CompVolume(RecNo);
      EventData.Next;
      Inc(i);
      Inc(RecNo);
    end;
    EventData.First;
    RecNo := 1;
  end;

  CompDailyValues;
  
  ArrayOnes.Free;
  ArrayOnes := TArrayOnes.Create;
  with ArrayOnes do
  begin
    ArrayOne := TArrayOne.Create;
    ArrayOneData := TQuery.Create(nil);
    { Redirect property accesss in ArrayOne back to ArrayOnes }
    ArrayOne.GetYearPtr := GetYear;
    ArrayOne.GetDOYPtr  := GetDOY;
    ArrayOne.GetTimePtr := GetTime;
  { Configure and open query }
    ArrayOneData.DatabaseName := DatabaseName;
    ArrayOneData.SQL.Clear;
    ArrayOneData.SQL.Add('select array1.repDate from array1, sensor'                            +
                        ' where sensor.id = ' + IntToStr( SensorID )                            +
                        ' and array1.siteID = sensor.siteID'                                    +
                        ' and repDate >= '''  + DateToStr(EncodeDateDay( StartYear, StartDOY )) +
                      ''' and repDate <  '''  + DateToStr(EncodeDateDay( EndYear, EndDOY ))     +
                      ''' order by repDate');
    ArrayOneData.Open;
    ArrayOneData.First;
    RecNo := 1;
  end;
end;

procedure THydroSensor.Split(i, StartPt: integer);
{ Split Events[i] into two events starting at StartPt }
var
  NewEventID:   integer;
  SensorID:     integer;
  StartTime:    TDateTime;
  NewStartTime: TDateTime;
  Minutes:      single;
  code:         word;
  t0:           single;
begin
  with Events do
  if StartPt < Event[i-1].Points.PointData.RecordCount then
  begin
{   Move to record i in EventData if not already there }
    if i <> RecNo then
    begin
      EventData.MoveBy(i - RecNo);
      RecNo := i;
    end;
{   Get startTime and status code for original event }
    StartTime := EventData['startTime'];
    code := EventData['code'];
    SensorID := EventData['sensorID'];
{   Construct the new startTime by adding the elapsed minutes and seconds for
    StartPt to the original startTime }
    Minutes := Event[i-1].Points[StartPt].Time;
    NewStartTime := IncMinute(StartTime, Trunc(Minutes));
    NewStartTime := IncSecond(NewStartTime, Trunc(Frac(Minutes) * 60.0));
{   Append a new record to EventData, populate the fields and post the changes }
    EventData.Append;
    EventData['startTime'] := NewStartTime;
    EventData['code'] := code;
    EventData['sensorID'] := SensorID;
    EventData.Post;
{   Close and reopen query to generate an id for the new event record }
    EventData.Close;
    EventData.Open;
{   Find new event record in result set }
    EventData.First;
    while not EventData.Eof do
    begin
//      if EventData['startTime'] = NewStartTime then Break;
      if SecondSpan( EventData['startTime'], NewStartTime ) < 1.0 then Break;
      EventData.Next;
    end;
    NewEventID := EventData['id'];
{   Associate the data point records after StartPt with the new event id and
    shift the elapsed times to be relative to the new event start time }
    with Event[i-1].Points do
    begin
      PointData.First;
      PointData.MoveBy(StartPt-1);
      t0 := PointData['elapsedTime'];
      while not PointData.Eof do
      begin
        PointData.Edit;
        PointData['eventID'] := NewEventID;
        PointData.Post;
        PointData.Edit;
        PointData['elapsedTime'] := PointData['elapsedTime'] - t0;
        PointData.Post;
        PointData.Next;
      end;
    end;
  end;
  SetInterval( FStartYear, FStartDOY, FEndYear, FEndDOY );
end;

constructor THydroSensor.Create(DatabaseName, EventTable, PointTable: string; SensorID: integer);
begin
  inherited Create;
  VertexData := TQuery.Create(nil);
  VertexData.DatabaseName := DatabaseName;
  VertexData.SQL.Add( 'select * from vertices where sensorID = ' + IntToStr(SensorID) +
                     ' order by orderNum' );
  VertexData.Open;
  Self.DatabaseName := DatabaseName;
  Self.EventTable   := EventTable;
  Self.PointTable   := PointTable;
  Self.SensorID     := SensorID;
end;

end.
