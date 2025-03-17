unit RunoffData;

interface

uses HydroSensor, DBTables;

type

  TStructure = (Flume = 1, Weir = 2, Tank = 3);

  TRunoffgage = class(THydroSensor)
  protected
    procedure   CompRates(i: integer); override;
    procedure   CompDailyValues; override;
    procedure   CompVolume(i: integer); override;
  private
    Query:      TQuery;
    RatingD:    array of single; { depth, feet }
    RatingQ:    array of single; { discharge, cfs }
    RatingE:    array of single; { pre-computation for log-log interpolation }
    RatingN:    integer;         { number of D,Q pairs in rating table }
    PondingD:   array of single; { depth, feet }
    PondingV:   array of single; { volume, cu.ft }
    PondingE:   array of single; { pre-computation for log-log interpolation }
    PondingN:   integer;         { number of D,V pairs in ponding table }
    Area:       single; {sq. ft }
    dt:         integer; {seconds}
    FStructure: TStructure;
    NotchLevel: single;
    procedure   Undo( i, action: integer );
  public
    property    TimeStep: integer read dt;
    property    Structure: TStructure read FStructure;
    procedure   SetInterval(StartYear, StartDOY, EndYear, EndDOY: word); override;
    function    Q2D(Rate: single): single;
    function    D2Q(Depth: single): single;
    procedure   Backup( i: integer );
    procedure   Revert( i: integer );
    constructor Create(DatabaseName: string; SensorID: integer);
  end;

var
  Runoffgages: array of TRunoffgage;

implementation

uses
  Controls, SysUtils, DateUtils, Math;

const
  conv = 12 * 3600; { ft/s -> in/hr }

procedure TRunoffgage.CompRates(i: integer);
var
  j:           integer;
  index:       integer;
  depth:       single;
  outflow:     array of single;
  storage:     array of single;
  volume:      array [1..2] of single;
  NotchVolume: single;
  volume0:     single;
  infilt:      single;
  dSdt:        array [1..2] of single;
  avg_t:       array [1..2] of single;
begin
{ ------------------------------------------------------------------------------------------------
  For convenience, allocate an extra element so we can use arrays as 1-based instead of 0-based
  ------------------------------------------------------------------------------------------------ }
  SetLength( outflow, Events[i].Points.nPoints + 1 );
{ ------------------------------------------------------------------------------------------------
  Compute outflow rates from structure
  ------------------------------------------------------------------------------------------------ }
  index := 0;
  for j := 1 to Events[i].Points.nPoints do
  begin
    depth := Events[i].Points[j].Depth - NotchLevel;
    if depth < 0.0001 then
      outflow[j] := 0
    else if depth <= RatingD[0] then
{ ------------------------------------------------------------------------------------------------
      Linear interpolation between zero and RatingD[0]
  ------------------------------------------------------------------------------------------------ }
      outflow[j] := depth * RatingQ[0] / RatingD[0]
    else
    begin
{ ------------------------------------------------------------------------------------------------
      Starting with the previous index value, increment/decrement the index until the interval
      RatingD[index0-1], RatingD[index] brackets the current depth
  ------------------------------------------------------------------------------------------------ }
      while depth > RatingD[index] do
      begin
        Inc(index);
        if index > RatingN - 1 then
        begin
{ ------------------------------------------------------------------------------------------------
          Current depth is beyond final entry in the rating table - extrapolate from the last
          two entries using log-log interpolation
  ------------------------------------------------------------------------------------------------ }
          index := RatingN - 1;
          Break;
        end;
      end;
      while depth < RatingD[index-1] do Dec(index);
{ ------------------------------------------------------------------------------------------------
      Log-log interpolation
  ------------------------------------------------------------------------------------------------ }
      outflow[j] := RatingQ[index-1] * Power(depth / RatingD[index-1], RatingE[index]);
    end;
  end;

  if FStructure = Flume then
    for j := 1 to Events[i].Points.nPoints do Events[i].Points[j].Rate := outflow[j] * conv / Area

  else if FStructure = Weir then
  begin
{ ------------------------------------------------------------------------------------------------
    Compute volume held behind weir at the notch level
  ------------------------------------------------------------------------------------------------ }
    index := 0;
    if Notchlevel <= PondingD[0] then
{ ------------------------------------------------------------------------------------------------
      Linear interpolation between zero and PondingD[0]
  ------------------------------------------------------------------------------------------------ }
      NotchVolume := Notchlevel * PondingV[0] / PondingD[0]
    else
    begin
{ ------------------------------------------------------------------------------------------------
      Starting with the previous index value, increment/decrement the index until the interval
      PondingD[index0-1], PondingD[index] brackets the notch level
  ------------------------------------------------------------------------------------------------ }
      while Notchlevel > PondingD[index] do
      begin
        Inc(index);
        if index > PondingN - 1 then
        begin
{ ------------------------------------------------------------------------------------------------
          Notch level is beyond final entry in the ponding table - extrapolate from the last
          two entries using log-log interpolation
  ------------------------------------------------------------------------------------------------ }
          index := PondingN - 1;
          Break;
        end;
      end;
      while Notchlevel < PondingD[index-1] do Dec(index);
{ ------------------------------------------------------------------------------------------------
      Log-log interpolation
  ------------------------------------------------------------------------------------------------ }
      NotchVolume := PondingV[index-1] * Power(Notchlevel / PondingD[index-1], PondingE[index]);
    end;
{ ------------------------------------------------------------------------------------------------
    Compute volumes stored behind weir
  ------------------------------------------------------------------------------------------------ }
    SetLength( storage,  Events[i].Points.nPoints + 1 );
    volume[1] := -1;
    infilt    :=  0;
    index     :=  0;
    for j := 1 to Events[i].Points.nPoints do
    begin
      depth := Events[i].Points[j].Depth;
      if depth < 0.0001 then
        volume[2] := 0
      else if depth <= PondingD[0] then
{ ------------------------------------------------------------------------------------------------
        Linear interpolation between zero and PondingD[0]
  ------------------------------------------------------------------------------------------------ }
        volume[2] := depth * PondingV[0] / PondingD[0]
      else
      begin
{ ------------------------------------------------------------------------------------------------
        Starting with the previous index value, increment/decrement the index until the interval
        PondingD[index0-1], PondingD[index] brackets the current depth
  ------------------------------------------------------------------------------------------------ }
        while depth > PondingD[index] do
        begin
          Inc(index);
          if index > PondingN - 1 then
          begin
{ ------------------------------------------------------------------------------------------------
            Current depth is beyond final entry in the ponding table - extrapolate from the last
            two entries using log-log interpolation
  ------------------------------------------------------------------------------------------------ }
            index := PondingN - 1;
            Break;
          end;
        end;
        while depth < PondingD[index-1] do Dec(index);
{ ------------------------------------------------------------------------------------------------
        Log-log interpolation
  ------------------------------------------------------------------------------------------------ }
        volume[2] := PondingV[index-1] * Power(depth / PondingD[index-1], PondingE[index]);
      end;
{ ------------------------------------------------------------------------------------------------
      Save initial pond volume
  ------------------------------------------------------------------------------------------------ }
      if j = 1 then volume0 := volume[2];
{ ------------------------------------------------------------------------------------------------
      Decreasing depth below the notch level is due to infiltration - infiltrated volume is part
      of the storage behind the weir
  ------------------------------------------------------------------------------------------------ }
      if depth < NotchLevel then
        if volume[1] > volume[2] then
          if Events[i].Points[j-1].Depth  < NotchLevel then
            infilt := infilt + volume[1] - volume[2]
          else
            infilt := infilt + NotchVolume - volume[2];

      storage[j] := volume[2] - volume0 + infilt;
      volume[1]  := volume[2];
    end;
{ ------------------------------------------------------------------------------------------------
    Compute watershed discharge rates - beginning and ending rates are zero
  ------------------------------------------------------------------------------------------------ }
    Events[i].Points[1].Rate := 0;
    Events[i].Points[Events[i].Points.nPoints].Rate := 0;
    if Events[i].Points.nPoints > 0 then
    begin
      dSdt[1]  := (storage[2] - storage[1]) / (Events[i].Points[2].Time - Events[i].Points[1].Time);
      avg_t[1] := (Events[i].Points[1].Time + Events[i].Points[2].Time) / 2;
      for j := 2 to Events[i].Points.nPoints - 1 do
      begin
        dSdt[2]  := (storage[j+1] - storage[j]) / (Events[i].Points[j+1].Time - Events[i].Points[j].Time);
        avg_t[2] := (Events[i].Points[j].Time + Events[i].Points[j+1].Time) / 2;
        if (Events[i].Points[j].Depth <= NotchLevel) and ((dSdt[1] = 0) or (dSdt[2] = 0)) then
          Events[i].Points[j].Rate := outflow[j] * conv / Area
        else
          Events[i].Points[j].Rate := ((Events[i].Points[j].Time - avg_t[1]) * (dSdt[2] - dSdt[1]) /
                                      (avg_t[2] - avg_t[1]) + dSdt[1] + outflow[j]) * conv / Area;
      dSdt[1]  := dSdt[2];
      avg_t[1] := avg_t[2];
      end;
    end;
  end;
end;

procedure TRunoffgage.CompDailyValues;
{ ------------------------------------------------------------------------------------------------
  Compute daily runoff totals for each day in the interval - note that the interval
  is truncated by the end of the year if it crosses midnight of Dec 31st
  ------------------------------------------------------------------------------------------------ }
var
  i:   integer;
  j:   integer;
  k:   integer;
  n:   integer;
  t:   single;
  dt:  single;
  dv:  single;
  dt_: single;
  dv_: single;
  qm:  single;
begin
  for i := 1 to 366 do DailyValues[i] := 0.0;
{ ------------------------------------------------------------------------------------------------
  The interval is truncated at the end of the year if it continues into the next year
  ------------------------------------------------------------------------------------------------ }
  if EndYear = StartYear then
    n := EndDOY
  else
    n := DaysInAYear( StartYear );
{ ------------------------------------------------------------------------------------------------
  Integrate each event and add volume to daily total runoff depth (inches)
  ------------------------------------------------------------------------------------------------ }
  for i := 1 to Events.nEvents do
    with Events[i] do
    if Status < 2 then { don't count events that were rejected }
      if DOY <= n then
      begin
        k := 0; { number of midnights crossed }
        for j := 2 to Points.nPoints do
        begin
          dt := (Points[j].Time - Points[j-1].Time) / 60; { min - > hrs }
          dv := dt * 0.5 * (Points[j].Rate + Points[j-1].Rate);
          t := Time + Points[j].Time;
          if t <= 1440 * (k + 1) then
            DailyValues[DOY+k] := DailyValues[DOY+k] + dv

          else { interval crosses midnight }

          begin
            dt_ := (1440 - t) / 60; { min - > hrs }
            qm := Points[j-1].Rate + (dt_ / (dt - dt_)) * (Points[j].Rate - Points[j-1].Rate);
            dv_ := dt_ * 0.5 * (Points[j-1].Rate + qm);
            DailyValues[DOY] := DailyValues[DOY] + dv_;
            Inc( k );
            if DOY + k <= n then
              DailyValues[DOY+k] := DailyValues[DOY+k] + dv - dv_
            else
              Break;
          end;
        end;
      end;
end;

procedure TRunoffgage.SetInterval( StartYear, StartDOY, EndYear, EndDOY: word );
var
  StartDate:      TDate;
  ratingTableID:  integer;
  pondingTableID: integer;
  i:              integer;
begin
  StartDate := EncodeDateDay( StartYear, StartDOY );
{ ------------------------------------------------------------------------------------------------
  Find the rating table which applies to this interval
  ------------------------------------------------------------------------------------------------ }
  Query.SQL.Clear;
  Query.SQL.Add( 'select * from ratingTables where sensorID = ' + IntToStr(  SensorID )  +
                ' and effectiveDate <= '''                      + DateToStr( StartDate ) +
              ''' order by effectiveDate' );
  Query.Open;
  Query.Last;
  ratingTableID := Query['id'];
{ ------------------------------------------------------------------------------------------------
  Copy the D,Q pairs into RatingD, RatingQ and compute RatingE's for each rating interval
  ------------------------------------------------------------------------------------------------ }
  Query.SQL.Clear;
  Query.SQL.Add( 'select * from ratingData where rtID = ' + IntToStr( ratingTableID ) +
                ' order by depth' );
  Query.Open;
  RatingN := Query.RecordCount;
  SetLength( RatingD, RatingN );
  SetLength( RatingQ, RatingN );
  SetLength( RatingE, RatingN );
  Query.First;
  RatingD[0] := Query['depth'];     { feet }
  RatingQ[0] := Query['discharge']; { cfs }
  Query.Next;
  i := 1;
  while not Query.Eof do
  begin
    RatingD[i] := Query['depth'];
    RatingQ[i] := Query['discharge'];
    RatingE[i] := Ln( RatingQ[i]/RatingQ[i-1] ) / Ln( RatingD[i]/RatingD[i-1] );
    Query.Next;
    Inc(i);
  end;
{ ------------------------------------------------------------------------------------------------
  Find the time step which applies to this interval
  ------------------------------------------------------------------------------------------------ }
  Query.SQL.Clear;
  Query.SQL.Add( 'select * from flumeHistory where sensorID = ' + IntToStr(  SensorID )  +
                ' and effectiveDate <= '''                      + DateToStr( StartDate ) +
              ''' order by effectiveDate' );
  Query.Open;
  Query.Last;
  if not Query.IsEmpty then
    dt := Query['timeStep']
  else
    dt := 60; { default to 1 minute }

  NotchLevel := 0;

  if FStructure = Weir then
  begin
{ ------------------------------------------------------------------------------------------------
    Find the ponding table which applies to this interval
  ------------------------------------------------------------------------------------------------ }
    Query.SQL.Clear;
    Query.SQL.Add( 'select * from pondingTables where sensorID = ' + IntToStr( SensorID ) +
                  ' and effectiveDate <= '''                       + DateToStr( StartDate ) +
                ''' order by effectiveDate' );
    Query.Open;
    Query.Last;
    pondingTableID := Query['id'];
{ ------------------------------------------------------------------------------------------------
    Copy the D,V pairs into PondingD, PondingV and compute RatingEs for each rating interval
  ------------------------------------------------------------------------------------------------ }
    Query.SQL.Clear;
    Query.SQL.Add( 'select * from pondingData where ptID = ' + IntToStr( pondingTableID ) +
                  ' order by depth' );
    Query.Open;
    PondingN := Query.RecordCount;
    SetLength( PondingD, PondingN );
    SetLength( PondingV, PondingN );
    SetLength( PondingE, PondingN );
    Query.First;
    PondingD[0] := Query['depth'];     { feet }
    PondingV[0] := Query['volume']; { cu.ft }
    Query.Next;
    i := 1;
    while not Query.Eof do
    begin
      PondingD[i] := Query['depth'];
      PondingV[i] := Query['volume'];
      PondingE[i] := Ln( PondingV[i]/PondingV[i-1] ) / Ln( PondingD[i]/PondingD[i-1] );
      Query.Next;
      Inc(i);
    end;
{ ------------------------------------------------------------------------------------------------
    Find the notch level which applies to this interval
  ------------------------------------------------------------------------------------------------ }
    Query.SQL.Clear;
    Query.SQL.Add( 'select * from weir where id = ' + IntToStr( SensorID ) );
    Query.Open;
    if Query['effectiveDate'] < StartDate then
      NotchLevel := (Query['weirLevel'] - Query['zeroVolt']) / Query['calibration']
    else
    begin
      Query.SQL.Clear;
      Query.SQL.Add( 'select * from weirHistory where sensorID = ' + IntToStr(  SensorID ) +
                    ' and effectiveDate <= '''                     + DateToStr( StartDate ) +
                  ''' order by effectiveDate' );
      Query.Open;
      Query.Last;
      NotchLevel := (Query['weirLevel'] - Query['zeroVolt']) / Query['calibration'];
    end;
  end;
  inherited SetInterval( StartYear, StartDOY, EndYear, EndDOY );
end;

procedure TRunoffgage.CompVolume(i: integer);
{ Maximum depth of flow }
var
  j:   integer;
begin
  with Events[i] do
  begin
    Volume := 0;
    for j := 1 to Points.nPoints do
      if Points[j].Depth > Volume then Volume := Points[j].Depth;
  end;
end;

function TRunoffgage.Q2D(Rate: single): single;
{ Return depth of flow given Rate }
var
  i: integer;
  q: single;
begin
  if (FStructure <> Flume) or (Rate = 0) then
    Result := 0
  else
  begin
    i := 1; // rating table index
    q := Area * Rate / conv;
    while q > RatingQ[i] do // Depth above interval [i-1,i]
    begin
      Inc(i);
      if i > RatingN then // depth beyond rating
      begin
        i := RatingN; // extrapolate log-log from last interval in table
        Break;
      end;
    end;

    if i = 1 then // Discharge interpolated linearly from zero:
      Result := q * RatingD[1] / RatingQ[1]
    else
      Result := RatingD[i-1] * Power(q / RatingQ[i-1], 1 / RatingE[i]);
  end;
end;

function TRunoffgage.D2Q(Depth: single): single;
{ Return discharge rate of flow given Depth }
var
  i: integer;
begin
  if (FStructure <> Flume) or (Depth = 0) then
    Result := 0
  else
  begin
    i := 1; // rating table index
    while Depth > RatingD[i] do // Depth above interval [i-1,i]
    begin
      Inc(i);
      if i > RatingN then // depth beyond rating
      begin
        i := RatingN; // extrapolate log-log from last interval in table
        Break;
      end;
    end;

    if i = 1 then // Discharge interpolated linearly from zero:
      Result := conv * Depth * RatingQ[1] / RatingD[1] / Area
    else
      Result := conv * RatingQ[i-1] * Power(Depth / RatingD[i-1], RatingE[i]) / Area;
  end;
end;

procedure TRunoffgage.Backup( i: integer );
begin
//  if FStructure = Flume then Undo( i, 1 );
  Undo( i, 1 );
end;

procedure TRunoffgage.Revert( i: integer );
begin
//  if FStructure = Flume then Undo( i, -1 );
  Undo( i, -1 );
end;

procedure TRunoffgage.Undo( i, action: integer );
{ ------------------------------------------------------------------------------------------------
  Depending on action, do one of two things:

  action = -1
    Replace event i with the original event in BkUpEventTable and BkUpPointTable.  Since the
    original event may have been split one or more times, delete all events which overlap the
    original.  Also delete the original event from the BkUp tables

  action = 1
    Save event i in BkUpEventTable and BkUpPointTable.  Since event i may be one of several
    events split from the original, first check to make sure the original event is not already
    in the BkUp tables
  ------------------------------------------------------------------------------------------------ }
var
  BkUpEventData: TQuery;
  BkUpPointData: TQuery;
  RevEventData:  TQuery;
  RevPointData:  TQuery;
  PtTable:       TTable;
  EvtTable:      TTable;
  EvtQuery:      TQuery;
  StartDate:     TDateTime;
  OrigStartDate: TDateTime;
  OrigEndDate:   TDateTime;
  OrigEventID:   integer;
  Minutes:       single;
  Found:         boolean;
  j:             integer;
begin
//  if FStructure <> Flume then Exit;

  BkUpEventData              := TQuery.Create( nil );
  BkUpEventData.DatabaseName := DatabaseName;
  BkUpPointData              := TQuery.Create( nil );
  BkUpPointData.DatabaseName := DatabaseName;
{ ------------------------------------------------------------------------------------------------
  Get all events in BkUpEventTable that start before or at the same date-time as the event to be
  reverted
  ------------------------------------------------------------------------------------------------ }
  StartDate := EncodeDateDay( FStartYear, Events[i].DOY );
  Minutes   := Events[i].Time;
  StartDate := IncMinute( StartDate, Trunc( Minutes ) );
  StartDate := IncSecond( StartDate, Trunc( Frac( Minutes ) * 60.0 ) );

  BkUpEventData.SQL.Add( 'select * from '      + 'runOffEventsBkUp'         +
                        ' where sensorID = '   + IntToStr( SensorID )       +
                        ' and startTime <= ''' + DateTimeToStr( StartDate ) +
                      ''' order by startTime' );

  BkUpEventData.RequestLive := True;
  BkUpEventData.Open;
  BkUpEventData.First;
{ ------------------------------------------------------------------------------------------------
  Find the original event that brackets the start time of the event to be reverted
  ------------------------------------------------------------------------------------------------ }
  Found := False;
  while not BkUpEventData.Eof do
  begin
    OrigStartDate := BkUpEventData['startTime'];
{ ------------------------------------------------------------------------------------------------
    Determine the end date-time of original event
  ------------------------------------------------------------------------------------------------ }
    OrigEventID := BkUpEventData['id'];
    BkUpPointData.SQL.Clear;
    BkUpPointData.SQL.Add( 'select * from '   + 'runOffPointsBkUp'      +
                          ' where eventID = ' + IntToStr( OrigEventID ) +
                          ' order by elapsedTime' );

    BkUpPointData.RequestLive := True;
    BkUpPointData.Open;

    BkUpPointData.Last;
    Minutes     := BkUpPointData['elapsedTime'];
//  Using the 'Last' method does not seem to work reliably, so iterate instead
//    BkUpPointData.First;
//    while not BkUpPointData.Eof do
//    begin
//      Minutes := BkUpPointData['elapsedTime'];
//      BkUpPointData.Next;
//    end;

    OrigEndDate := IncMinute( OrigStartDate, Trunc( Minutes ) );
    OrigEndDate := IncSecond( OrigEndDate, Trunc( Frac( Minutes ) * 60.0 ) );

    if StartDate < OrigEndDate then
    begin
      Found := True;
      Break;
    end;

    BkUpEventData.Next;
  end;

  if Found and (action = -1) then
  begin
{ ------------------------------------------------------------------------------------------------
    Find and delete all events which were derived from the original event - they may not be part
    of the current interval
  ------------------------------------------------------------------------------------------------ }
    RevEventData              := TQuery.Create(nil);
    RevEventData.DatabaseName := DatabaseName;
    RevPointData              := TQuery.Create(nil);
    RevPointData.DatabaseName := DatabaseName;

    RevEventData.SQL.Add( 'select * from '      + 'runOffEvents'             +
                         ' where sensorID = '   + IntToStr( SensorID )           +
                         ' and startTime >= ''' + DateTimeToStr( OrigStartDate ) +
                       ''' and startTime <  ''' + DateTimeToStr( OrigEndDate )   + '''' );

    RevEventData.RequestLive := True;
    RevEventData.Open;
    RevEventData.First;

    while not RevEventData.Eof do
    begin
      RevPointData.SQL.Clear;
      RevPointData.SQL.Add( 'select * from '   + 'runOffPoints'             +
                           ' where eventID = ' + IntToStr( RevEventData['id'] ) );
      RevPointData.RequestLive := True;
      RevPointData.Open;
      RevPointData.First;
      while not RevPointData.Eof do RevPointData.Delete;
      RevEventData.Delete;
    end;
    RevEventData.Close;
    RevEventData.Free;
    RevPointData.Close;
    RevPointData.Free;
{ ------------------------------------------------------------------------------------------------
    Append the original event to the events table, populate the fields and post the changes
  ------------------------------------------------------------------------------------------------ }
    EvtTable              := TTable.Create( nil );
    EvtTable.DatabaseName := DatabaseName;
    EvtTable.TableName    := 'runOffEvents';
    EvtTable.Open;
    EvtTable.Append;
    EvtTable['startTime'] := OrigStartDate;
    EvtTable['code']      := BkUpEventData['code'];
    EvtTable['sensorID']  := SensorID;
    EvtTable.Post;
{ ------------------------------------------------------------------------------------------------
    Close and reopen table to generate an id for the new event record
  ------------------------------------------------------------------------------------------------ }
    EvtTable.Close;
    EvtTable.Open;
{ ------------------------------------------------------------------------------------------------
    Find new event record 
  ------------------------------------------------------------------------------------------------ }
    EvtQuery              := TQuery.Create( nil );
    EvtQuery.DatabaseName := DatabaseName;
    EvtQuery.SQL.Clear;
    EvtQuery.SQL.Add( 'select * from '     + 'runOffEvents'             +
                     ' where sensorID = '  + IntToStr( SensorID )           +
                     ' and startTime = ''' + DateTimeToStr( OrigStartDate ) + '''' );
    EvtQuery.Open;
    OrigEventID := EvtQuery['id'];
    EvtQuery.Close;
    EvtQuery.Free;
{ ------------------------------------------------------------------------------------------------
    Append the original data points to the points table, populate the fields and post the changes
  ------------------------------------------------------------------------------------------------ }
    PtTable              := TTable.Create( nil );
    PtTable.DatabaseName := DatabaseName;
    PtTable.TableName    := 'runOffPoints';
    PtTable.Open;
    BkUpPointData.First;
    while not BkUpPointData.Eof do
    begin
      PtTable.Append;
      PtTable['eventID']     := OrigEventID;
      PtTable['elapsedTime'] := BkUpPointData['elapsedTime'];
      PtTable['depth']       := BkUpPointData['depth'];
      PtTable['code']        := BkUpPointData['code'];
      PtTable.Post;
      BkUpPointData.Next;
    end;
    PtTable.Close;
    PtTable.Free;
{ ------------------------------------------------------------------------------------------------
    Reload the data
  ------------------------------------------------------------------------------------------------ }
    SetInterval( FStartYear, FStartDOY, FEndYear, FEndDOY );
{ ------------------------------------------------------------------------------------------------
    Delete the original event and points from backup tables
  ------------------------------------------------------------------------------------------------ }
    BkUpPointData.First;
    while not BkUpPointData.Eof do BkUpPointData.Delete;
    BkUpEventData.Delete;
  end
  else if not Found and (action = 1) then
  begin
{ ------------------------------------------------------------------------------------------------
    Append a new record to the backup event table, populate the fields and post the changes
  ------------------------------------------------------------------------------------------------ }
    BkUpEventData.Append;
    BkUpEventData['id']        := Events[i].ID;
    BkUpEventData['startTime'] := StartDate;
    BkUpEventData['code']      := Events[i].Status;
    BkUpEventData['sensorID']  := SensorID;
    BkUpEventData.Post;
{ ------------------------------------------------------------------------------------------------
    Append the data points to the backup points table, populate the fields and post the changes
  ------------------------------------------------------------------------------------------------ }
    PtTable              := TTable.Create( nil );
    PtTable.DatabaseName := DatabaseName;
    PtTable.TableName    := 'runOffPointsBkUp';
    PtTable.Open;
    for j := 1 to Events[i].Points.nPoints do
    begin
      PtTable.Append;
      PtTable['id']          := Events[i].Points[j].ID;
      PtTable['eventID']     := Events[i].ID;
      PtTable['elapsedTime'] := Events[i].Points[j].Time;
      PtTable['depth']       := Events[i].Points[j].Depth;
      PtTable['code']        := Events[i].Points[j].Note;
      PtTable.Post;
    end;
    PtTable.Close;
    PtTable.Free;
  end;
  BkUpEventData.Close;
  BkUpEventData.Free;
  BkUpPointData.Close;
  BkUpPointData.Free;
end;

constructor TRunoffgage.Create( DatabaseName: string; SensorID: integer );
var
  table: string;
begin
  inherited Create( DatabaseName, 'runOffEvents', 'runOffPoints', SensorID );
  Query := TQuery.Create( nil );
  Query.DatabaseName := DatabaseName;
  Query.SQL.Add( 'select sensorType from sensor where id=' + IntToStr( SensorID ) );
  Query.Open;
  Query.First;
  case Query['sensorType'] of
    20: FStructure := Flume;
    30: FStructure := Weir;
  end;
  if FStructure = Flume then
    table := 'flume'
  else if FStructure = Weir then
    table := 'weir';
  Query.SQL.Clear;
  Query.SQL.Add( 'select area from ' + table + ' where id=' + IntToStr( SensorID ) );
  Query.Open;
  Query.First;
  Area := Query['area'] * 43560; { acres -> sq. ft }
end;

end.
