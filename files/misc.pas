unit misc;

interface

uses
  SysUtils;

  procedure split(line, delim: string; var list: array of string; var n: integer);
  procedure DOY2Date(DOY, Year: word; var Day, Month: word);

implementation

const
  Days: array [0..12] of integer = (0,31,59,90,120,151,181,212,243,273,304,334,365);

procedure split(line, delim: string; var list: array of string; var n: integer);
{ Split a line of text into an array of strings }
var
  i,j,k: integer;
begin
  j := 1;
  for i := 0 to High(list) do
  begin
    k := Pos(delim, line); { position of next delimiter }
    if k = 0 then
    begin
      list[i] := Copy(line, j, Length(line)-j+1);
      break;
    end;
    list[i] := Copy(line, j, k-j);
    line[k] := ' ';
    j := k + 1;
  end;
  n := i + 1;
end;

procedure DOY2Date(DOY, Year: word; var Day, Month: word);
var
  extraday: integer;
begin
  if (Year mod 4 = 0) and (DOY >= 60) then
    extraday := 1
  else
    extraday := 0;
  Month := 1;
  While Days[Month] + extraday < DOY do Inc(Month);
  Day := DOY - Days[Month-1] - extraday;
end;

end.
