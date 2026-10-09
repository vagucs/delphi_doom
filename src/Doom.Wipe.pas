unit Doom.Wipe;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  O quadro antigo escorre e o novo aparece por cima, igual a doom/wipe.py.
}

interface

uses
  System.SysUtils;

type
  TWipe = class
  public
    constructor Create;
    procedure CaptureStart(const Fb: TBytes);
    procedure CaptureEnd(const Fb: TBytes);
    procedure BeginMelt(var Fb: TBytes);
    function Tick(var Fb: TBytes): Boolean;
  private
    FStart: TBytes;
    FEnd: TBytes;
    FY: array[0..159] of Integer;
    FRnd: Cardinal;
    function NextRnd(N: Integer): Integer;
    procedure Column(var Fb: TBytes; const Src: TBytes; X, SrcY, DestY, H: Integer);
  end;

implementation

uses
  Doom.VVideo;

constructor TWipe.Create;
begin
  inherited Create;
  FRnd := 1;
end;

function TWipe.NextRnd(N: Integer): Integer;
begin
  FRnd := FRnd * 1664525 + 1013904223;
  if N <= 1 then
    Exit(0);
  Result := Integer((FRnd shr 16) mod Cardinal(N));
end;

procedure TWipe.CaptureStart(const Fb: TBytes);
begin
  FStart := Copy(Fb);
  if Length(FStart) <> SCREENPIXELS then
    FillFb(FStart, 0);
end;

procedure TWipe.CaptureEnd(const Fb: TBytes);
begin
  FEnd := Copy(Fb);
  if Length(FEnd) <> SCREENPIXELS then
    FillFb(FEnd, 0);
end;

procedure TWipe.BeginMelt(var Fb: TBytes);
var
  I, Ny, R: Integer;
begin
  Fb := Copy(FStart);
  FY[0] := -NextRnd(16);
  for I := 1 to 159 do
  begin
    R := NextRnd(3) - 1;
    Ny := FY[I - 1] + R;
    if Ny > 0 then
      Ny := 0
    else if Ny = -16 then
      Ny := -15;
    FY[I] := Ny;
  end;
end;

procedure TWipe.Column(var Fb: TBytes; const Src: TBytes; X, SrcY, DestY, H: Integer);
var
  Y, S, D: Integer;
begin
  for Y := 0 to H - 1 do
  begin
    S := (SrcY + Y) * SCREENWIDTH + X;
    D := (DestY + Y) * SCREENWIDTH + X;
    if (S >= 0) and (S + 1 < Length(Src)) and (D >= 0) and (D + 1 < Length(Fb)) then
    begin
      Fb[D] := Src[S];
      Fb[D + 1] := Src[S + 1];
    end;
  end;
end;

function TWipe.Tick(var Fb: TBytes): Boolean;
var
  I, Yi, Dy, Rem: Integer;
  Done: Boolean;
begin
  if Length(Fb) <> SCREENPIXELS then
    FillFb(Fb, 0);
  Done := True;
  for I := 0 to 159 do
  begin
    Yi := FY[I];
    if Yi < 0 then
    begin
      Column(Fb, FStart, I * 2, 0, 0, SCREENHEIGHT);
      FY[I] := Yi + 1;
      Done := False;
    end
    else if Yi < SCREENHEIGHT then
    begin
      if Yi < 16 then
        Dy := Yi + 1
      else
        Dy := 8;
      if Yi + Dy > SCREENHEIGHT then
        Dy := SCREENHEIGHT - Yi;
      Column(Fb, FEnd, I * 2, Yi, Yi, Dy);
      Inc(Yi, Dy);
      FY[I] := Yi;
      Rem := SCREENHEIGHT - Yi;
      if Rem > 0 then
        Column(Fb, FStart, I * 2, 0, Yi, Rem);
      Done := False;
    end;
  end;
  if Done then
    Fb := Copy(FEnd);
  Result := Done;
end;

end.
