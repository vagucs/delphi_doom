unit Doom.Tables;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Tabelas de seno, tangente e arco, iguais a doom/tables.py.
}

interface

procedure InitTables;
function FineSin(Angle: Cardinal): Integer;
function FineCos(Angle: Cardinal): Integer;
function FineTangentAt(Index: Integer): Integer;
function TanToAngle(Index: Integer): Cardinal;
function SlopeDiv(Num, Den: Integer): Integer;

implementation

uses
  System.Math, Doom.Compat;

const
  FINEANGLES = 8192;
  FINEMASK = 8191;
  FRACUNIT = 65536;
  SLOPERANGE = 2048;
  ANG90 = $40000000;

var
  GInited: Boolean;
  GSin: array of Integer;
  GTan: array of Integer;
  GAtan: array of Integer;

procedure InitTables;
var
  I: Integer;
  A: Double;
  V: Int64;
begin
  if GInited then
    Exit;
  SetLength(GSin, FINEANGLES div 4 * 5);
  for I := 0 to High(GSin) do
  begin
    A := (I + 0.5) * Pi * 2 / FINEANGLES;
    GSin[I] := Trunc(FRACUNIT * Sin(A));
  end;
  SetLength(GTan, FINEANGLES div 2);
  for I := 0 to High(GTan) do
  begin
    A := (I - FINEANGLES div 4 + 0.5) * Pi * 2 / FINEANGLES;
    if Abs(Cos(A)) < 1.0E-8 then
    begin
      if A > 0 then
        V := $7FFFFFFF
      else
        V := -$7FFFFFFF;
    end
    else
      V := Trunc(FRACUNIT * Tan(A));
    if V > $7FFFFFFF then
      V := $7FFFFFFF
    else if V < -$7FFFFFFF then
      V := -$7FFFFFFF;
    GTan[I] := Integer(V);
  end;
  SetLength(GAtan, SLOPERANGE + 1);
  for I := 0 to SLOPERANGE do
    GAtan[I] := Integer(AsU32(Trunc(ArcTan(I / SLOPERANGE) / (Pi * 2) * 4294967296.0)));
  GInited := True;
end;

function FineIndex(Angle: Cardinal): Integer;
begin
  Result := (Angle shr 19) and FINEMASK;
end;

function FineSin(Angle: Cardinal): Integer;
begin
  InitTables;
  Result := GSin[FineIndex(Angle)];
end;

function FineCos(Angle: Cardinal): Integer;
begin
  InitTables;
  Result := GSin[(FineIndex(Angle) + FINEANGLES div 4) and FINEMASK];
end;

function FineTangentAt(Index: Integer): Integer;
begin
  InitTables;
  if Index < 0 then
    Index := 0;
  if Index > High(GTan) then
    Index := High(GTan);
  Result := GTan[Index];
end;

function TanToAngle(Index: Integer): Cardinal;
begin
  InitTables;
  if Index < 0 then
    Index := 0;
  if Index > SLOPERANGE then
    Index := SLOPERANGE;
  Result := Cardinal(GAtan[Index]);
end;

function SlopeDiv(Num, Den: Integer): Integer;
var
  Ans: Int64;
begin
  if Den < 512 then
    Exit(SLOPERANGE);
  Ans := (Int64(Num) shl 3) div (Den shr 8);
  if Ans > SLOPERANGE then
    Ans := SLOPERANGE;
  if Ans < 0 then
    Ans := 0;
  Result := Integer(Ans);
end;

end.
