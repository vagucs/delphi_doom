unit Doom.VVideo;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Desenho de patch no framebuffer, igual a doom/v_video.py.
}

interface

uses
  System.SysUtils;

const
  SCREENWIDTH = 320;
  SCREENHEIGHT = 200;
  SCREENPIXELS = SCREENWIDTH * SCREENHEIGHT;

procedure FillFb(var Fb: TBytes; Color: Byte = 0);
procedure DrawPatch(var Fb: TBytes; X, Y: Integer; const Patch: TBytes);
function PatchWidth(const Patch: TBytes): Integer;

implementation

function U16(const Data: TBytes; Off: Integer): Integer;
begin
  Result := Data[Off] or (Data[Off + 1] shl 8);
end;

function I16(const Data: TBytes; Off: Integer): Integer;
begin
  Result := U16(Data, Off);
  if Result >= 32768 then
    Dec(Result, 65536);
end;

function U32(const Data: TBytes; Off: Integer): Cardinal;
begin
  Result := Cardinal(Data[Off]) or (Cardinal(Data[Off + 1]) shl 8) or
    (Cardinal(Data[Off + 2]) shl 16) or (Cardinal(Data[Off + 3]) shl 24);
end;

function PatchWidth(const Patch: TBytes): Integer;
begin
  if Length(Patch) < 2 then
    Exit(0);
  Result := Patch[0] or (Patch[1] shl 8);
  if Result >= 32768 then
    Dec(Result, 65536);
end;

procedure FillFb(var Fb: TBytes; Color: Byte);
var
  I: Integer;
begin
  SetLength(Fb, SCREENPIXELS);
  for I := 0 to SCREENPIXELS - 1 do
    Fb[I] := Color;
end;

procedure DrawPatch(var Fb: TBytes; X, Y: Integer; const Patch: TBytes);
var
  W, Col, SrcCol, TopDelta, Len, Source, Dest, DestTop: Integer;
  Column: Cardinal;
begin
  if Length(Fb) < SCREENPIXELS then
    FillFb(Fb, 0);
  if Length(Patch) < 8 then
    Exit;
  W := I16(Patch, 0);
  X := X - I16(Patch, 4);
  Y := Y - I16(Patch, 6);
  DestTop := Y * SCREENWIDTH + X;
  for Col := 0 to W - 1 do
  begin
    SrcCol := Col;
    if 8 + (SrcCol + 1) * 4 > Length(Patch) then
      Break;
    Column := U32(Patch, 8 + SrcCol * 4);
    while Column < Cardinal(Length(Patch)) do
    begin
      TopDelta := Patch[Column];
      if TopDelta = $FF then
        Break;
      if Integer(Column) + 1 >= Length(Patch) then
        Break;
      Len := Patch[Column + 1];
      Source := Integer(Column) + 3;
      Dest := DestTop + TopDelta * SCREENWIDTH;
      while Len > 0 do
      begin
        if (Dest >= 0) and (Dest < SCREENPIXELS) and (Source >= 0) and (Source < Length(Patch)) then
          Fb[Dest] := Patch[Source];
        Inc(Source);
        Inc(Dest, SCREENWIDTH);
        Dec(Len);
      end;
      Column := Column + Cardinal(Patch[Column + 1]) + 4;
    end;
    Inc(DestTop);
  end;
end;

end.
