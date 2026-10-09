unit Doom.RData;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Flats, texturas e sprites, a partir de doom/r_data.py.
  A cor mais comum continua servindo ao mapa de cima.
  A vista usa a coluna da textura e o pixel do flat.
}

interface

uses
  System.SysUtils, System.Generics.Collections, Doom.Wad;

type
  TTexPatch = record
    OriginX: Integer;
    OriginY: Integer;
    Patch: Integer;
  end;

  TDoomTex = class
  public
    Name: string;
    Width: Integer;
    Height: Integer;
    WidthMask: Integer;
    Patches: TArray<TTexPatch>;
    ColLump: TArray<Integer>;
    ColOfs: TArray<Integer>;
    Composite: TBytes;
    HasComposite: Boolean;
  end;

  TSpriteFrame = record
    Rotate: Integer;
    Lump: array[0..7] of Integer;
    Flip: array[0..7] of Integer;
  end;

  TResources = class
  public
    constructor Create;
    destructor Destroy; override;
    procedure Init(Wad: TWad);
    function ColorForFlat(const Name: string): Integer;
    function ColorForTexture(const Name: string): Integer;
    function FlatNumForName(const Name: string): Integer;
    function TextureNumForName(const Name: string): Integer;
    function TextureHeight(TexNum: Integer): Integer;
    function SkyFlat: Integer;
    function SkyTex: Integer;
    function MapColor(Level, Pix: Integer): Byte;
    procedure GetColumn(TexNum, Col: Integer; const Dest: TBytes);
    function ReadMaskPosts(TexNum, Col: Integer; var Tops, Lens: array of Integer;
      var Pix: array of TBytes): Integer;
    function FlatPixel(FlatNum, Spot: Integer): Byte;
    function LookupSprite(const Name: string; AngToThing, MoAngle: Cardinal; Frame: Integer;
      out Lump, Flip: Integer): Boolean;
    function WadData: TWad;
  private
    FWad: TWad;
    FFlats: TDictionary<string, Byte>;
    FTextures: TDictionary<string, Byte>;
    FTexList: TObjectList<TDoomTex>;
    FTexIndex: TDictionary<string, Integer>;
    FFlatCache: TArray<TBytes>;
    FColorMap: TBytes;
    FSprites: TDictionary<string, TArray<TSpriteFrame>>;
    FFlatsFirst: Integer;
    FFlatsLast: Integer;
    FSkyFlat: Integer;
    FSkyTex: Integer;
    procedure IndexFlats;
    procedure IndexTextures(const MapTex: TBytes; const PatchLookup: TArray<Integer>);
    procedure BuildTextures(const MapTex: TBytes; const PatchLookup: TArray<Integer>);
    procedure BuildColumns(Tex: TDoomTex);
    procedure BuildComposite(Tex: TDoomTex);
    procedure DrawColumnInCache(const Patch: TBytes; Column, X, OriginY: Integer; Tex: TDoomTex);
    procedure BuildSprites;
    function Dominant(const Hist: array of Integer; SkipZero: Boolean): Integer;
    procedure AccumulatePatch(const Patch: TBytes; var Hist: array of Integer);
    procedure AccumulateRaw(const Data: TBytes; var Hist: array of Integer);
    function InstallSprite(var Frames: TArray<TSpriteFrame>; Lump, Frame, Rotation: Integer;
      Flipped: Boolean): Boolean;
  end;

implementation

uses
  Doom.Compat;

function I16(const Data: TBytes; Off: Integer): Integer;
begin
  Result := Data[Off] or (Data[Off + 1] shl 8);
  if Result >= 32768 then
    Dec(Result, 65536);
end;

function I32(const Data: TBytes; Off: Integer): Integer;
begin
  Result := Integer(Cardinal(Data[Off]) or (Cardinal(Data[Off + 1]) shl 8) or
    (Cardinal(Data[Off + 2]) shl 16) or (Cardinal(Data[Off + 3]) shl 24));
end;

function U32(const Data: TBytes; Off: Integer): Cardinal;
begin
  Result := Cardinal(Data[Off]) or (Cardinal(Data[Off + 1]) shl 8) or
    (Cardinal(Data[Off + 2]) shl 16) or (Cardinal(Data[Off + 3]) shl 24);
end;

function Name8(const Data: TBytes; Off: Integer): string;
var
  I: Integer;
begin
  I := 0;
  while (I < 8) and (Off + I < Length(Data)) and (Data[Off + I] <> 0) do
    Inc(I);
  Result := UpperCase(Trim(TEncoding.ANSI.GetString(Data, Off, I)));
end;

constructor TResources.Create;
begin
  inherited Create;
  FFlats := TDictionary<string, Byte>.Create;
  FTextures := TDictionary<string, Byte>.Create;
  FTexList := TObjectList<TDoomTex>.Create(True);
  FTexIndex := TDictionary<string, Integer>.Create;
  FSprites := TDictionary<string, TArray<TSpriteFrame>>.Create;
end;

destructor TResources.Destroy;
begin
  FSprites.Free;
  FTexIndex.Free;
  FTexList.Free;
  FTextures.Free;
  FFlats.Free;
  inherited;
end;

function TResources.Dominant(const Hist: array of Integer; SkipZero: Boolean): Integer;
var
  I, Best, BestN, First: Integer;
begin
  Result := -1;
  Best := 0;
  BestN := 0;
  if SkipZero then
    First := 1
  else
    First := 0;
  for I := First to High(Hist) do
    if Hist[I] > BestN then
    begin
      BestN := Hist[I];
      Best := I;
    end;
  if BestN > 0 then
    Result := Best;
end;

procedure TResources.AccumulateRaw(const Data: TBytes; var Hist: array of Integer);
var
  I: Integer;
begin
  for I := 0 to Length(Data) - 1 do
    Inc(Hist[Data[I]]);
end;

procedure TResources.AccumulatePatch(const Patch: TBytes; var Hist: array of Integer);
var
  W, Col, TopDelta, Len, Source: Integer;
  Column: Cardinal;
begin
  if Length(Patch) < 8 then
    Exit;
  W := I16(Patch, 0);
  if W < 0 then
    Exit;
  for Col := 0 to W - 1 do
  begin
    if 8 + (Col + 1) * 4 > Length(Patch) then
      Break;
    Column := U32(Patch, 8 + Col * 4);
    while Column < Cardinal(Length(Patch)) do
    begin
      TopDelta := Patch[Column];
      if TopDelta = $FF then
        Break;
      if Integer(Column) + 1 >= Length(Patch) then
        Break;
      Len := Patch[Column + 1];
      Source := Integer(Column) + 3;
      while Len > 0 do
      begin
        if (Source >= 0) and (Source < Length(Patch)) then
          Inc(Hist[Patch[Source]]);
        Inc(Source);
        Dec(Len);
      end;
      Column := Column + Cardinal(Patch[Column + 1]) + 4;
    end;
  end;
end;

procedure TResources.IndexFlats;
var
  First, Last, I, Color: Integer;
  Hist: array[0..255] of Integer;
  Data: TBytes;
  Name: string;
begin
  if FWad = nil then
    Exit;
  First := FWad.CheckNumForName('F_START');
  Last := FWad.CheckNumForName('F_END');
  if (First < 0) or (Last <= First) then
    Exit;
  FFlatsFirst := First + 1;
  FFlatsLast := Last - 1;
  for I := First + 1 to Last - 1 do
  begin
    Name := FWad.LumpName(I);
    if (Name = '') or (Name = '-') or (Name = 'F1_START') or (Name = 'F1_END') or
      (Name = 'F2_START') or (Name = 'F2_END') or (Name = 'FF_START') or (Name = 'FF_END') then
      Continue;
    Data := FWad.CacheLumpNum(I);
    if Length(Data) = 0 then
      Continue;
    FillChar(Hist, SizeOf(Hist), 0);
    AccumulateRaw(Data, Hist);
    Color := Dominant(Hist, False);
    if Color >= 0 then
      FFlats.AddOrSetValue(Name, Byte(Color));
  end;
end;

procedure TResources.IndexTextures(const MapTex: TBytes; const PatchLookup: TArray<Integer>);
var
  Count, I, Offset, PatchCount, P, PIdx, Lump, Color: Integer;
  Hist: array[0..255] of Integer;
  Name: string;
  Patch: TBytes;
  Poff: Integer;
begin
  if Length(MapTex) < 4 then
    Exit;
  Count := I32(MapTex, 0);
  for I := 0 to Count - 1 do
  begin
    if 4 + (I + 1) * 4 > Length(MapTex) then
      Break;
    Offset := I32(MapTex, 4 + I * 4);
    if (Offset < 0) or (Offset + 22 > Length(MapTex)) then
      Continue;
    Name := Name8(MapTex, Offset);
    if (Name = '') or (Name = '-') then
      Continue;
    PatchCount := I16(MapTex, Offset + 20);
    if PatchCount < 0 then
      Continue;
    FillChar(Hist, SizeOf(Hist), 0);
    Poff := Offset + 22;
    for P := 0 to PatchCount - 1 do
    begin
      if Poff + 6 > Length(MapTex) then
        Break;
      PIdx := I16(MapTex, Poff + 4);
      Inc(Poff, 10);
      if (PIdx < 0) or (PIdx >= Length(PatchLookup)) then
        Continue;
      Lump := PatchLookup[PIdx];
      if Lump < 0 then
        Continue;
      Patch := FWad.CacheLumpNum(Lump);
      AccumulatePatch(Patch, Hist);
    end;
    Color := Dominant(Hist, True);
    if Color >= 0 then
      FTextures.AddOrSetValue(Name, Byte(Color));
  end;
end;

procedure TResources.Init(Wad: TWad);
var
  Pnames, MapTex: TBytes;
  NumPatches, I: Integer;
  PatchLookup: TArray<Integer>;
begin
  FWad := Wad;
  FFlats.Clear;
  FTextures.Clear;
  FTexList.Clear;
  FTexIndex.Clear;
  FSprites.Clear;
  SetLength(FFlatCache, 0);
  SetLength(FColorMap, 0);
  FFlatsFirst := 0;
  FFlatsLast := -1;
  FSkyFlat := 0;
  FSkyTex := -1;
  if Wad = nil then
    Exit;
  IndexFlats;
  if Wad.CheckNumForName('COLORMAP') >= 0 then
    FColorMap := Wad.CacheLumpName('COLORMAP');
  BuildSprites;
  if Wad.CheckNumForName('PNAMES') < 0 then
    Exit;
  if Wad.CheckNumForName('TEXTURE1') < 0 then
    Exit;
  Pnames := Wad.CacheLumpName('PNAMES');
  if Length(Pnames) < 4 then
    Exit;
  NumPatches := I32(Pnames, 0);
  if NumPatches < 0 then
    Exit;
  SetLength(PatchLookup, NumPatches);
  for I := 0 to NumPatches - 1 do
  begin
    if 4 + (I + 1) * 8 > Length(Pnames) then
    begin
      PatchLookup[I] := -1;
      Continue;
    end;
    PatchLookup[I] := Wad.CheckNumForName(Name8(Pnames, 4 + I * 8));
  end;
  MapTex := Wad.CacheLumpName('TEXTURE1');
  IndexTextures(MapTex, PatchLookup);
  BuildTextures(MapTex, PatchLookup);
  if Wad.CheckNumForName('TEXTURE2') >= 0 then
  begin
    MapTex := Wad.CacheLumpName('TEXTURE2');
    IndexTextures(MapTex, PatchLookup);
    BuildTextures(MapTex, PatchLookup);
  end;
  FSkyFlat := FlatNumForName('F_SKY1');
  FSkyTex := TextureNumForName('SKY1');
end;

function TResources.ColorForFlat(const Name: string): Integer;
var
  Key: string;
  Color: Byte;
begin
  Key := UpperCase(Trim(Name));
  if (Key = '') or (Key = '-') then
    Exit(-1);
  if FFlats.TryGetValue(Key, Color) then
    Exit(Color);
  Result := -1;
end;

function TResources.ColorForTexture(const Name: string): Integer;
var
  Key: string;
  Color: Byte;
begin
  Key := UpperCase(Trim(Name));
  if (Key = '') or (Key = '-') then
    Exit(-1);
  if FTextures.TryGetValue(Key, Color) then
    Exit(Color);
  Result := -1;
end;

function TResources.WadData: TWad;
begin
  Result := FWad;
end;

function TResources.SkyFlat: Integer;
begin
  Result := FSkyFlat;
end;

function TResources.SkyTex: Integer;
begin
  Result := FSkyTex;
end;

function TResources.FlatNumForName(const Name: string): Integer;
var
  Key: string;
  N: Integer;
begin
  Result := 0;
  if (FWad = nil) or (FFlatsLast < FFlatsFirst) then
    Exit;
  Key := UpperCase(Trim(Name));
  if (Key = '') or (Key = '-') then
    Exit;
  N := FWad.CheckNumForName(Key);
  if N < 0 then
    Exit;
  Result := N - FFlatsFirst;
end;

function TResources.TextureNumForName(const Name: string): Integer;
var
  Key: string;
begin
  Key := UpperCase(Trim(Name));
  if (Key = '') or (Key = '-') then
    Exit(-1);
  if not FTexIndex.TryGetValue(Key, Result) then
    Result := -1;
end;

function TResources.TextureHeight(TexNum: Integer): Integer;
begin
  if (TexNum < 0) or (TexNum >= FTexList.Count) or (FTexList[TexNum].Height <= 0) then
    Exit(65536);
  Result := FTexList[TexNum].Height * 65536;
end;

function TResources.MapColor(Level, Pix: Integer): Byte;
var
  Off: Integer;
begin
  if Level < 0 then
    Level := 0;
  if Level > 31 then
    Level := 31;
  if (Pix < 0) or (Pix > 255) then
    Exit(0);
  Off := Level * 256 + Pix;
  if Off < Length(FColorMap) then
    Result := FColorMap[Off]
  else
    Result := Byte(Pix);
end;

function TResources.FlatPixel(FlatNum, Spot: Integer): Byte;
var
  Lump, N: Integer;
  Data: TBytes;
begin
  Result := 0;
  if (FWad = nil) or (FFlatsLast < FFlatsFirst) then
    Exit;
  N := FFlatsLast - FFlatsFirst + 1;
  if N <= 0 then
    Exit;
  if FlatNum < 0 then
    FlatNum := 0;
  if FlatNum >= N then
    FlatNum := 0;
  if Length(FFlatCache) <> N then
    SetLength(FFlatCache, N);
  if Length(FFlatCache[FlatNum]) < 4096 then
  begin
    Lump := FFlatsFirst + FlatNum;
    if (Lump >= 0) and (Lump < FWad.NumLumps) then
      Data := FWad.CacheLumpNum(Lump);
    SetLength(FFlatCache[FlatNum], 4096);
    if Length(Data) > 0 then
    begin
      if Length(Data) > 4096 then
        Move(Data[0], FFlatCache[FlatNum][0], 4096)
      else
        Move(Data[0], FFlatCache[FlatNum][0], Length(Data));
    end;
  end;
  if (Spot >= 0) and (Spot < 4096) then
    Result := FFlatCache[FlatNum][Spot];
end;

procedure TResources.BuildTextures(const MapTex: TBytes; const PatchLookup: TArray<Integer>);
var
  Count, I, Offset, PatchCount, P, PIdx, J: Integer;
  Name: string;
  Tex: TDoomTex;
  Tp: TTexPatch;
  Poff: Integer;
begin
  if Length(MapTex) < 4 then
    Exit;
  Count := I32(MapTex, 0);
  for I := 0 to Count - 1 do
  begin
    if 4 + (I + 1) * 4 > Length(MapTex) then
      Break;
    Offset := I32(MapTex, 4 + I * 4);
    if (Offset < 0) or (Offset + 22 > Length(MapTex)) then
      Continue;
    Name := Name8(MapTex, Offset);
    Tex := TDoomTex.Create;
    Tex.Name := Name;
    Tex.Width := I16(MapTex, Offset + 12);
    Tex.Height := I16(MapTex, Offset + 14);
    if Tex.Width < 1 then
      Tex.Width := 1;
    if Tex.Height < 1 then
      Tex.Height := 1;
    J := 1;
    while J * 2 <= Tex.Width do
      J := J * 2;
    Tex.WidthMask := J - 1;
    PatchCount := I16(MapTex, Offset + 20);
    if PatchCount < 0 then
      PatchCount := 0;
    SetLength(Tex.Patches, PatchCount);
    Poff := Offset + 22;
    for P := 0 to PatchCount - 1 do
    begin
      if Poff + 6 > Length(MapTex) then
        Break;
      Tp.OriginX := I16(MapTex, Poff);
      Tp.OriginY := I16(MapTex, Poff + 2);
      PIdx := I16(MapTex, Poff + 4);
      Inc(Poff, 10);
      if (PIdx >= 0) and (PIdx < Length(PatchLookup)) then
        Tp.Patch := PatchLookup[PIdx]
      else
        Tp.Patch := -1;
      Tex.Patches[P] := Tp;
    end;
    SetLength(Tex.ColLump, Tex.Width);
    SetLength(Tex.ColOfs, Tex.Width);
    for J := 0 to Tex.Width - 1 do
    begin
      Tex.ColLump[J] := -1;
      Tex.ColOfs[J] := 0;
    end;
    BuildColumns(Tex);
    FTexIndex.AddOrSetValue(Name, FTexList.Count);
    FTexList.Add(Tex);
  end;
end;

procedure TResources.BuildColumns(Tex: TDoomTex);
var
  Counts: TArray<Integer>;
  P, X, X1, X2, Pw: Integer;
  Data: TBytes;
  Tp: TTexPatch;
begin
  SetLength(Counts, Tex.Width);
  for P := 0 to High(Tex.Patches) do
  begin
    Tp := Tex.Patches[P];
    if Tp.Patch < 0 then
      Continue;
    Data := FWad.CacheLumpNum(Tp.Patch);
    if Length(Data) < 4 then
      Continue;
    Pw := I16(Data, 0);
    X1 := Tp.OriginX;
    X2 := X1 + Pw;
    X := X1;
    if X < 0 then
      X := 0;
    if X2 > Tex.Width then
      X2 := Tex.Width;
    while X < X2 do
    begin
      Inc(Counts[X]);
      Tex.ColLump[X] := Tp.Patch;
      if 8 + (X - Tp.OriginX + 1) * 4 <= Length(Data) then
        Tex.ColOfs[X] := Integer(U32(Data, 8 + (X - Tp.OriginX) * 4));
      Inc(X);
    end;
  end;
  for X := 0 to Tex.Width - 1 do
    if Counts[X] > 1 then
      Tex.ColLump[X] := -1;
end;

procedure TResources.DrawColumnInCache(const Patch: TBytes; Column, X, OriginY: Integer; Tex: TDoomTex);
var
  TopDelta, Len, Source, Pos, Count, Dest, I: Integer;
begin
  while Column < Length(Patch) do
  begin
    TopDelta := Patch[Column];
    if TopDelta = $FF then
      Break;
    if Column + 1 >= Length(Patch) then
      Break;
    Len := Patch[Column + 1];
    Source := Column + 3;
    Pos := OriginY + TopDelta;
    Count := Len;
    if Pos < 0 then
    begin
      Count := Count + Pos;
      Source := Source - Pos;
      Pos := 0;
    end;
    if Pos + Count > Tex.Height then
      Count := Tex.Height - Pos;
    if Count > 0 then
    begin
      Dest := X * Tex.Height + Pos;
      for I := 0 to Count - 1 do
        if (Source + I >= 0) and (Source + I < Length(Patch)) and
          (Dest + I >= 0) and (Dest + I < Length(Tex.Composite)) then
          Tex.Composite[Dest + I] := Patch[Source + I];
    end;
    Column := Column + Len + 4;
  end;
end;

procedure TResources.BuildComposite(Tex: TDoomTex);
var
  P, X, X1, X2, Pw: Integer;
  Data: TBytes;
  Tp: TTexPatch;
begin
  if Tex.HasComposite then
    Exit;
  SetLength(Tex.Composite, Tex.Width * Tex.Height);
  for P := 0 to High(Tex.Patches) do
  begin
    Tp := Tex.Patches[P];
    if Tp.Patch < 0 then
      Continue;
    Data := FWad.CacheLumpNum(Tp.Patch);
    if Length(Data) < 4 then
      Continue;
    Pw := I16(Data, 0);
    X1 := Tp.OriginX;
    X2 := X1 + Pw;
    if X2 > Tex.Width then
      X2 := Tex.Width;
    X := X1;
    if X < 0 then
      X := 0;
    while X < X2 do
    begin
      if 8 + (X - Tp.OriginX + 1) * 4 <= Length(Data) then
        DrawColumnInCache(Data, Integer(U32(Data, 8 + (X - Tp.OriginX) * 4)), X, Tp.OriginY, Tex);
      Inc(X);
    end;
  end;
  Tex.HasComposite := True;
  for X := 0 to Tex.Width - 1 do
    if Tex.ColLump[X] < 0 then
      Tex.ColOfs[X] := X * Tex.Height;
end;

function TResources.ReadMaskPosts(TexNum, Col: Integer; var Tops, Lens: array of Integer;
  var Pix: array of TBytes): Integer;
var
  Tex: TDoomTex;
  Data: TBytes;
  Lump, Ofs, Y, TopDelta, Len, RawLen, Source, Limit: Integer;
  Column: Cardinal;
begin
  Result := 0;
  Limit := Length(Tops);
  if (Limit > Length(Lens)) or (Limit > Length(Pix)) then
  begin
    if Length(Lens) < Limit then
      Limit := Length(Lens);
    if Length(Pix) < Limit then
      Limit := Length(Pix);
  end;
  if (Limit <= 0) or (TexNum < 0) or (TexNum >= FTexList.Count) then
    Exit;
  Tex := FTexList[TexNum];
  Col := Col and Tex.WidthMask;
  if (Col < 0) or (Col >= Tex.Width) then
    Exit;
  Lump := Tex.ColLump[Col];
  if Lump >= 0 then
  begin
    Data := FWad.CacheLumpNum(Lump);
    Column := Cardinal(Tex.ColOfs[Col]);
    while (Column < Cardinal(Length(Data))) and (Result < Limit) do
    begin
      TopDelta := Data[Column];
      if TopDelta = $FF then
        Break;
      if Integer(Column) + 1 >= Length(Data) then
        Break;
      RawLen := Data[Column + 1];
      if RawLen <= 0 then
        Break;
      Len := RawLen;
      Source := Integer(Column) + 3;
      if Len > 128 then
        Len := 128;
      SetLength(Pix[Result], Len);
      for Y := 0 to Len - 1 do
        if (Source + Y >= 0) and (Source + Y < Length(Data)) then
          Pix[Result][Y] := Data[Source + Y]
        else
          Pix[Result][Y] := 0;
      Tops[Result] := TopDelta;
      Lens[Result] := Len;
      Inc(Result);
      Column := Column + Cardinal(RawLen) + 4;
    end;
    Exit;
  end;
  BuildComposite(Tex);
  if (Tex.Height <= 0) or (Limit < 1) then
    Exit;
  Ofs := Tex.ColOfs[Col];
  Len := Tex.Height;
  if Len > 128 then
    Len := 128;
  SetLength(Pix[0], Len);
  for Y := 0 to Len - 1 do
    if Ofs + Y < Length(Tex.Composite) then
      Pix[0][Y] := Tex.Composite[Ofs + Y]
    else
      Pix[0][Y] := 0;
  Tops[0] := 0;
  Lens[0] := Len;
  Result := 1;
end;

procedure TResources.GetColumn(TexNum, Col: Integer; const Dest: TBytes);
var
  Tex: TDoomTex;
  Lump, Ofs, Y, TopDelta, Len, Source: Integer;
  Data: TBytes;
  Column: Cardinal;
begin
  if Length(Dest) < 128 then
    Exit;
  for Y := 0 to 127 do
    Dest[Y] := 0;
  if (TexNum < 0) or (TexNum >= FTexList.Count) then
    Exit;
  Tex := FTexList[TexNum];
  Col := Col and Tex.WidthMask;
  if (Col < 0) or (Col >= Tex.Width) then
    Exit;
  Lump := Tex.ColLump[Col];
  if Lump >= 0 then
  begin
    Data := FWad.CacheLumpNum(Lump);
    Column := Cardinal(Tex.ColOfs[Col]);
    while Column < Cardinal(Length(Data)) do
    begin
      TopDelta := Data[Column];
      if TopDelta = $FF then
        Break;
      if Integer(Column) + 1 >= Length(Data) then
        Break;
      Len := Data[Column + 1];
      Source := Integer(Column) + 3;
      for Y := 0 to Len - 1 do
        if (TopDelta + Y < 128) and (Source + Y >= 0) and (Source + Y < Length(Data)) then
          Dest[TopDelta + Y] := Data[Source + Y];
      Column := Column + Cardinal(Len) + 4;
    end;
    Exit;
  end;
  BuildComposite(Tex);
  Ofs := Tex.ColOfs[Col];
  if Tex.Height <= 0 then
    Exit;
  for Y := 0 to 127 do
    if Ofs + (Y mod Tex.Height) < Length(Tex.Composite) then
      Dest[Y] := Tex.Composite[Ofs + (Y mod Tex.Height)];
end;

function TResources.InstallSprite(var Frames: TArray<TSpriteFrame>; Lump, Frame, Rotation: Integer;
  Flipped: Boolean): Boolean;
var
  R: Integer;
  Slot: TSpriteFrame;
begin
  Result := False;
  if (Frame < 0) or (Frame >= 29) or (Rotation < 0) or (Rotation > 8) then
    Exit;
  Slot := Frames[Frame];
  if Rotation = 0 then
  begin
    if Slot.Rotate = 1 then
      Exit(True);
    Slot.Rotate := 0;
    for R := 0 to 7 do
    begin
      Slot.Lump[R] := Lump;
      if Flipped then
        Slot.Flip[R] := 1
      else
        Slot.Flip[R] := 0;
    end;
    Frames[Frame] := Slot;
    Exit(True);
  end;
  if Slot.Rotate = 0 then
    Exit(True);
  Slot.Rotate := 1;
  R := Rotation - 1;
  if Slot.Lump[R] < 0 then
  begin
    Slot.Lump[R] := Lump;
    if Flipped then
      Slot.Flip[R] := 1
    else
      Slot.Flip[R] := 0;
  end;
  Frames[Frame] := Slot;
  Result := True;
end;

procedure TResources.BuildSprites;
var
  Start, Last, First, Lump, Frame, Rotation, MaxFrame, I: Integer;
  Name, Key: string;
  Frames: TArray<TSpriteFrame>;
  Slot: TSpriteFrame;
  Names: TArray<string>;
begin
  if FWad = nil then
    Exit;
  Start := FWad.CheckNumForName('S_START');
  Last := FWad.CheckNumForName('S_END');
  if Start < 0 then
    Start := FWad.CheckNumForName('SS_START');
  if Last < 0 then
    Last := FWad.CheckNumForName('SS_END');
  if (Start >= 0) and (Last > Start) then
  begin
    First := Start + 1;
    Last := Last - 1;
  end
  else
  begin
    First := 0;
    Last := FWad.NumLumps - 1;
  end;
  for Lump := First to Last do
  begin
    Name := FWad.LumpName(Lump);
    if Length(Name) < 6 then
      Continue;
    Key := Copy(Name, 1, 4);
    if not FSprites.TryGetValue(Key, Frames) then
    begin
      SetLength(Frames, 29);
      for I := 0 to 28 do
      begin
        Frames[I].Rotate := -1;
        for Frame := 0 to 7 do
        begin
          Frames[I].Lump[Frame] := -1;
          Frames[I].Flip[Frame] := 0;
        end;
      end;
    end;
    Frame := Ord(Name[5]) - Ord('A');
    Rotation := Ord(Name[6]) - Ord('0');
    InstallSprite(Frames, Lump, Frame, Rotation, False);
    if (Length(Name) >= 8) and (Name[7] >= 'A') and (Name[7] <= ']') then
      InstallSprite(Frames, Lump, Ord(Name[7]) - Ord('A'), Ord(Name[8]) - Ord('0'), True);
    FSprites.AddOrSetValue(Key, Frames);
  end;
  Names := FSprites.Keys.ToArray;
  for Key in Names do
  begin
    Frames := FSprites[Key];
    MaxFrame := -1;
    for I := 0 to High(Frames) do
      if Frames[I].Rotate >= 0 then
        MaxFrame := I;
    for I := 0 to MaxFrame do
      if Frames[I].Rotate < 0 then
      begin
        Slot := Frames[I];
        Slot.Rotate := 0;
        Frames[I] := Slot;
      end;
    FSprites.AddOrSetValue(Key, Frames);
  end;
end;

function TResources.LookupSprite(const Name: string; AngToThing, MoAngle: Cardinal; Frame: Integer;
  out Lump, Flip: Integer): Boolean;
var
  Key: string;
  Frames: TArray<TSpriteFrame>;
  Slot: TSpriteFrame;
  Rot, Fi: Integer;
begin
  Result := False;
  Lump := -1;
  Flip := 0;
  Key := UpperCase(Copy(Trim(Name), 1, 4));
  if not FSprites.TryGetValue(Key, Frames) then
    Exit;
  Fi := Frame and $7FFF;
  if (Fi < 0) or (Fi > High(Frames)) then
    Exit;
  Slot := Frames[Fi];
  if Slot.Rotate <> 0 then
  begin
    Rot := Integer((AsU32(Int64(AngToThing) - MoAngle + $90000000) shr 29) and 7);
    Lump := Slot.Lump[Rot];
    Flip := Slot.Flip[Rot];
  end
  else
  begin
    Lump := Slot.Lump[0];
    Flip := Slot.Flip[0];
  end;
  Result := Lump >= 0;
end;

end.
