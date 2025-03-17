unit RainData;

interface

uses HydroSensor;

type

  TRaingage = class(THydroSensor)
  protected
    procedure CompRates(i: integer); override;
    procedure CompDailyValues; override;
    procedure CompVolume(i: integer); override;
  public
    constructor Create(DatabaseName: string; SensorID: integer);
  end;

var
  Raingages: array of TRaingage;

const
{ ------------------------------------------------------------------------------------------------
  Database tables
  ------------------------------------------------------------------------------------------------ }
  PRECIP_EVENT_TABLE = 'precipEvents';
  PRECIP_POINT_TABLE = 'precipPoints';

implementation

uses
  DateUtils;

procedure TRaingage.CompRates(i: integer);
var
  j: integer;
  dh,dt: single;
begin
  Events[i].Points[1].Rate := 0;
  for j := 2 to Events[i].Points.nPoints do
  begin
    dh := Events[i].Points[j].Depth - Events[i].Points[j-1].Depth;
    dt := Events[i].Points[j].Time  - Events[i].Points[j-1].Time;
    Events[i].Points[j].Rate := 60 * dh / dt; { in/hr }
  end;
end;

procedure TRaingage.CompDailyValues;
{ ------------------------------------------------------------------------------------------------
  Compute daily rainfall totals for each day in the interval - note that the interval
  is truncated by the end of the year if it crosses midnight of Dec 31st
  ------------------------------------------------------------------------------------------------ }
var
  j,k,n:   integer;
  Midnite: single;
begin
  for k := 1 to 366 do DailyValues[k] := 0.0;
{ ------------------------------------------------------------------------------------------------
  The interval is truncated at the end of the year if it continues into the next year
  ------------------------------------------------------------------------------------------------ }
  if EndYear = StartYear then
    n := EndDOY
  else
    n := DaysInAYear( StartYear );
{ ------------------------------------------------------------------------------------------------
  Add contribution to daily total rainfall depth from each event
  ------------------------------------------------------------------------------------------------ }
  for j := 1 to Events.nEvents do
    with Events[j] do
    if Status < 2 then { don't count events that were rejected }
    begin
      if DOY <= n then
      begin
        if Time + Points[Points.nPoints].Time <= 1440 then
{ ------------------------------------------------------------------------------------------------
        Event does not cross midnight
  ------------------------------------------------------------------------------------------------ }
          DailyValues[DOY] := DailyValues[DOY] + Points[Points.nPoints].Depth
        else
        begin
{ ------------------------------------------------------------------------------------------------
          Find the breakpoints that bracket midnight (k, k+1) - assume the event will not cross
          midnight more than once
  ------------------------------------------------------------------------------------------------ }
          for k := 1 to Points.nPoints - 1 do
            if (Time + Points[k].Time <= 1440) and (Time + Points[k+1].Time > 1440) then Break;

          Midnite := Points[k].Depth + (Points[k+1].Depth - Points[k].Depth) *
                       (1440 - Time - Points[k].Time) / (Points[k+1].Time - Points[k].Time);
          DailyValues[DOY] := DailyValues[DOY] + Midnite - Points[1].Depth;
          if DOY < n then
            DailyValues[DOY+1] := DailyValues[DOY+1] + Points[Points.nPoints].Depth - Midnite;
        end;
      end;
    end;
end;

procedure TRaingage.CompVolume(i: integer);
begin
  Events[i].Volume := Events[i].Points[Events[i].Points.nPoints].Depth;
end;

constructor TRaingage.Create( DatabaseName: string; SensorID: integer );
begin
  inherited Create( DatabaseName, PRECIP_EVENT_TABLE, PRECIP_POINT_TABLE, SensorID );
end;

end.
