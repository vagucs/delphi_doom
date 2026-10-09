unit Doom.Render;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Vista: BSP, paredes, chao, teto e sprites parados.
  Segue doom/render.py e o desenho de sprite de doom/sprites.py.
}

interface

uses
  System.SysUtils, System.Generics.Collections, Doom.RData, Doom.World;

type
  TRenderer = class
  public
    constructor Create(Res: TResources);
    destructor Destroy; override;
    procedure SetViewSize(Blocks, Detail: Integer);
    procedure SetupFrame(X, Y, Z: Integer; Angle: Cardinal);
    procedure Render(World: TWorld; var Fb: TBytes);
    procedure DrawMapThings(World: TWorld; Skill: Integer);
    procedure DrawPSprite(const Patch: TBytes; Sx, Sy: Integer);
    procedure SetLightBoost(Amount: Integer);
  private
    FRes: TResources;
    FFb: TBytes;
    FBlocks: Integer;
    FWinX: Integer;
    FWinY: Integer;
    FViewWidth: Integer;
    FViewHeight: Integer;
    FCenterX: Integer;
    FCenterY: Integer;
    FCenterXFrac: Integer;
    FCenterYFrac: Integer;
    FProjection: Integer;
    FDetail: Integer;
    FViewX: Integer;
    FViewY: Integer;
    FViewZ: Integer;
    FViewAngle: Cardinal;
    FViewSin: Integer;
    FViewCos: Integer;
    FExtra: Integer;
    FFixedMap: Integer;
    FClipAngle: Cardinal;
    FViewAngleToX: array[0..4095] of Integer;
    FXtoViewAngle: array[0..320] of Cardinal;
    FYSlope: array[0..199] of Integer;
    FDistScale: array[0..319] of Integer;
    FScaleLight: array[0..15, 0..47] of Integer;
    FZLight: array[0..15, 0..127] of Integer;
    FLightRow: Integer;
    FYLookup: array[0..199] of Integer;
    FColumnOfs: array[0..319] of Integer;
    FCeilingClip: array[0..319] of Integer;
    FFloorClip: array[0..319] of Integer;
    FSolidFirst: array[0..127] of Integer;
    FSolidLast: array[0..127] of Integer;
    FNewEnd: Integer;
    FBaseXScale: Integer;
    FBaseYScale: Integer;
    FCurSeg: TSeg;
    FFront: TSector;
    FBack: TSector;
    FRwX: Integer;
    FRwStopX: Integer;
    FRwStart: Integer;
    FRwScale: Integer;
    FRwScaleStep: Integer;
    FRwDistance: Integer;
    FRwOffset: Integer;
    FRwNormal: Cardinal;
    FRwAngle1: Cardinal;
    FRwCenter: Cardinal;
    FRwMid: Integer;
    FRwTop: Integer;
    FRwBot: Integer;
    FMidTex: Integer;
    FTopTex: Integer;
    FBotTex: Integer;
    FMaskTex: Integer;
    FMaskMid: Integer;
    FColMask: array[0..319] of Integer;
    FScaleMask: array[0..319] of Integer;
    FLightMask: array[0..319] of Integer;
    FWorldTop: Integer;
    FWorldBot: Integer;
    FWorldHigh: Integer;
    FWorldLow: Integer;
    FMarkFloor: Boolean;
    FMarkCeiling: Boolean;
    FSegTextured: Boolean;
    FTopStep: Integer;
    FTopFrac: Integer;
    FBotStep: Integer;
    FBotFrac: Integer;
    FPixHigh: Integer;
    FPixLow: Integer;
    FPixHighStep: Integer;
    FPixLowStep: Integer;
    FDcX: Integer;
    FDcYl: Integer;
    FDcYh: Integer;
    FDcIScale: Integer;
    FDcMid: Integer;
    FDcSource: TBytes;
    FDcLight: Integer;
    FPlanes: TObjectList<TObject>;
    FFloorPlane: TObject;
    FCeilPlane: TObject;
    FSegs: TObjectList<TObject>;
    FSeen: TBytes;
    procedure InitMapping;
    procedure InitLights;
    procedure InitSlopes;
    procedure ClearClip;
    procedure RenderNode(World: TWorld; BspNum: Integer);
    procedure RenderSubsector(World: TWorld; Num: Integer);
    procedure AddLine(Seg: TSeg);
    procedure ClipSolid(First, Last: Integer);
    procedure CrunchSolid(Start, NextI: Integer);
    procedure ClipPass(First, Last: Integer);
    procedure StoreWall(Start, Stop: Integer);
    procedure SegLoop;
    procedure DrawColumn;
    procedure RenderMaskedRange(SegObj: TObject; X1, X2: Integer);
    procedure DrawMaskedSegs;
    procedure DrawPlanes;
    function FindPlane(Height, Pic, Light: Integer): TObject;
    function CheckPlane(Plane: TObject; Start, Stop: Integer): TObject;
    function PointToAngle(X, Y: Integer): Cardinal;
    function PointOnSide(X, Y: Integer; Node: TNode): Integer;
    function ScaleFromAngle(Vis: Cardinal): Integer;
    function PointToDist(X, Y: Integer): Integer;
    procedure PushSeg(Start, Stop, Scale1: Integer);
  end;

function ThingInfo(DoomEd: Integer; out Spr: string; out Frame, Height, Flags, Radius, Health: Integer): Boolean;

implementation

uses
  Doom.Compat, Doom.Tables, Doom.VVideo;

const
  ANG90 = Cardinal($40000000);
  ANG180 = Cardinal($80000000);
  HEIGHTBITS = 12;
  HEIGHTUNIT = 4096;
  LIGHTZSHIFT = 20;
  LIGHTSCALESHIFT = 12;
  NF_SUBSECTOR = $8000;
  ML_DONTPEGTOP = 8;
  ML_DONTPEGBOTTOM = 16;
  ML_MAPPED = 256;
  SIL_TOP = 1;
  SIL_BOTTOM = 2;
  SIL_BOTH = 3;
  MINZ = 4 * 65536;
  VIEWHEIGHT = 41 * 65536;

type
  TPlane = class
  public
    Height: Integer;
    Pic: Integer;
    Light: Integer;
    MinX: Integer;
    MaxX: Integer;
    Top: array[0..319] of Integer;
    Bottom: array[0..319] of Integer;
  end;

  TDrawSeg = class
  public
    X1: Integer;
    X2: Integer;
    Scale1: Integer;
    Scale2: Integer;
    ScaleStep: Integer;
    Silhouette: Integer;
    BSil: Integer;
    TSil: Integer;
    SprTop: TArray<Integer>;
    SprBot: TArray<Integer>;
    MaskTex: Integer;
    MaskMid: Integer;
    MaskCol: TArray<Integer>;
    MaskScale: TArray<Integer>;
    MaskLight: TArray<Integer>;
    Line: TSeg;
  end;

function AbsFixed(N: Integer): Integer;
begin
  N := AsI32(N);
  if N < 0 then
  begin
    if N = Integer($80000000) then
      Result := $7FFFFFFF
    else
      Result := -N;
  end
  else
    Result := N;
end;

function FloorDiv(A, B: Integer): Integer;
begin
  if B = 0 then
    Exit(0);
  if B < 0 then
    Exit(-FloorDiv(A, -B));
  if A >= 0 then
    Result := A div B
  else
    Result := Integer(-(((-Int64(A)) + B - 1) div B));
end;

function ThingInfo(DoomEd: Integer; out Spr: string; out Frame, Height, Flags, Radius, Health: Integer): Boolean;
const
  N = 117;
  Eds: array[0..N] of Integer = (
    3004, 9, 64, 66, 67, 65, 3001, 3002, 58, 3005, 3003, 69, 3006, 7, 68, 16, 71, 84, 72, 88, 89, 87,
    2035, 14, 2018, 2019, 2014, 2015, 5, 13, 6, 39, 38, 40, 2011, 2012, 2013, 2022, 2023, 2024, 2025,
    2026, 2045, 83, 2007, 2048, 2010, 2046, 2047, 17, 2008, 2049, 8, 2006, 2002, 2005, 2003, 2004, 2001,
    82, 85, 86, 2028, 30, 31, 32, 33, 37, 36, 41, 42, 43, 44, 45, 46, 55, 56, 57, 47, 48, 34, 35, 49,
    50, 51, 52, 53, 59, 60, 61, 62, 63, 22, 15, 18, 21, 23, 20, 19, 10, 12, 28, 24, 27, 29, 25, 26, 54,
    70, 73, 74, 75, 76, 77, 78, 79, 80, 81);
  Names: array[0..N] of string = (
    'POSS', 'SPOS', 'VILE', 'SKEL', 'FATT', 'CPOS', 'TROO', 'SARG', 'SARG', 'HEAD', 'BOSS', 'BOS2',
    'SKUL', 'SPID', 'BSPI', 'CYBR', 'PAIN', 'SSWV', 'KEEN', 'BBRN', 'SSWV', 'TROO', 'BAR1', 'TROO',
    'ARM1', 'ARM2', 'BON1', 'BON2', 'BKEY', 'RKEY', 'YKEY', 'YSKU', 'RSKU', 'BSKU', 'STIM', 'MEDI',
    'SOUL', 'PINV', 'PSTR', 'PINS', 'SUIT', 'PMAP', 'PVIS', 'MEGA', 'CLIP', 'AMMO', 'ROCK', 'BROK',
    'CELL', 'CELP', 'SHEL', 'SBOX', 'BPAK', 'BFUG', 'MGUN', 'CSAW', 'LAUN', 'PLAS', 'SHOT', 'SGN2',
    'TLMP', 'TLP2', 'COLU', 'COL1', 'COL2', 'COL3', 'COL4', 'COL6', 'COL5', 'CEYE', 'FSKU', 'TRE1',
    'TBLU', 'TGRN', 'TRED', 'SMBT', 'SMGT', 'SMRT', 'SMIT', 'ELEC', 'CAND', 'CBRA', 'GOR1', 'GOR2',
    'GOR3', 'GOR4', 'GOR5', 'GOR2', 'GOR4', 'GOR3', 'GOR5', 'GOR1', 'HEAD', 'PLAY', 'POSS', 'SARG',
    'SKUL', 'TROO', 'SPOS', 'PLAY', 'PLAY', 'POL2', 'POL5', 'POL4', 'POL3', 'POL1', 'POL6', 'TRE2',
    'FCAN', 'HDB1', 'HDB2', 'HDB3', 'HDB4', 'HDB5', 'HDB6', 'POB1', 'POB2', 'BRS1');
  Frames: array[0..N] of Byte = (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 11, 13, 0,
    0, 0, 22, 22, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  Heights: array[0..N] of Integer = (
    3670016, 3670016, 3670016, 3670016, 4194304, 3670016, 3670016, 3670016, 3670016, 3670016, 4194304,
    4194304, 3670016, 6553600, 4194304, 7208960, 3670016, 3670016, 4718592, 1048576, 2097152, 2097152,
    2752512, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576,
    1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576,
    1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576,
    1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576,
    1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576,
    1048576, 1048576, 1048576, 1048576, 1048576, 4456448, 5505024, 5505024, 4456448, 3407872, 5505024,
    4456448, 3407872, 3407872, 4456448, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576,
    1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 1048576, 5767168,
    5767168, 4194304, 4194304, 4194304, 4194304, 1048576, 1048576, 1048576);
  Flgs: array[0..N] of Integer = (
    4194310, 4194310, 4194310, 4194310, 4194310, 4194310, 4194310, 4194310, 4456454, 4211206, 4194310,
    4194310, 16902, 4194310, 4194310, 4194310, 4211206, 4194310, 4195078, 6, 24, 24, 524294, 24, 1, 1,
    8388609, 8388609, 33554433, 33554433, 33554433, 33554433, 33554433, 33554433, 1, 1, 8388609, 8388609,
    8388609, 8388609, 1, 8388609, 8388609, 8388609, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 770, 770, 770, 770, 770,
    770, 768, 768, 768, 768, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 2, 2, 2, 2, 2, 770, 770, 770, 770, 770,
    770, 16, 16, 16);
var
  I: Integer;
begin
  Result := False;
  for I := 0 to N do
    if Eds[I] = DoomEd then
    begin
      Spr := Names[I];
      Frame := Frames[I];
      Height := Heights[I];
      Flags := Flgs[I];
      Radius := 16 * 65536;
      Health := 0;
      case DoomEd of
        3004: begin Radius := 20 * 65536; Health := 20; end;
        9: begin Radius := 20 * 65536; Health := 30; end;
        84: begin Radius := 20 * 65536; Health := 50; end;
        65: begin Radius := 20 * 65536; Health := 70; end;
        64: begin Radius := 20 * 65536; Health := 700; end;
        66: begin Radius := 20 * 65536; Health := 300; end;
        67: begin Radius := 48 * 65536; Health := 600; end;
        3001: begin Radius := 20 * 65536; Health := 60; end;
        3002, 58: begin Radius := 30 * 65536; Health := 150; end;
        3005, 71: begin Radius := 31 * 65536; Health := 400; end;
        3003: begin Radius := 24 * 65536; Health := 1000; end;
        69: begin Radius := 24 * 65536; Health := 500; end;
        3006: begin Radius := 16 * 65536; Health := 100; end;
        7: begin Radius := 128 * 65536; Health := 3000; end;
        68: begin Radius := 64 * 65536; Health := 500; end;
        16: begin Radius := 40 * 65536; Health := 4000; end;
        72: begin Radius := 16 * 65536; Health := 100; end;
        2035, 88: begin Radius := 10 * 65536; Health := 20; end;
      end;
      if ((Flags and 4) <> 0) and (Health = 0) then
        Health := 20;
      Exit(True);
    end;
end;

function SkillBit(Skill: Integer): Integer;
begin
  if Skill <= 1 then
    Result := 1
  else if Skill >= 3 then
    Result := 4
  else
    Result := 2;
end;

constructor TRenderer.Create(Res: TResources);
begin
  inherited Create;
  FRes := Res;
  SetLength(FDcSource, 128);
  FPlanes := TObjectList<TObject>.Create(True);
  FSegs := TObjectList<TObject>.Create(True);
  InitTables;
  SetViewSize(10, 0);
end;

destructor TRenderer.Destroy;
begin
  FSegs.Free;
  FPlanes.Free;
  inherited;
end;

procedure TRenderer.SetViewSize(Blocks, Detail: Integer);
var
  Scaled, VH, I: Integer;
begin
  if Blocks < 3 then
    Blocks := 3;
  if Blocks > 11 then
    Blocks := 11;
  if Detail <> 0 then
    Detail := 1;
  if (Blocks = FBlocks) and (Detail = FDetail) and (FViewWidth > 0) then
    Exit;
  FBlocks := Blocks;
  FDetail := Detail;
  if Blocks = 11 then
  begin
    Scaled := SCREENWIDTH;
    VH := SCREENHEIGHT;
  end
  else
  begin
    Scaled := Blocks * 32;
    VH := (Blocks * 168 div 10) and not 7;
  end;
  FViewWidth := Scaled shr Detail;
  FViewHeight := VH;
  FWinX := (SCREENWIDTH - Scaled) shr 1;
  if Scaled = SCREENWIDTH then
    FWinY := 0
  else
    FWinY := (SCREENHEIGHT - 32 - VH) shr 1;
  FCenterX := FViewWidth div 2;
  FCenterY := FViewHeight div 2;
  FCenterXFrac := FCenterX shl 16;
  FCenterYFrac := FCenterY shl 16;
  FProjection := FCenterXFrac;
  for I := 0 to SCREENHEIGHT - 1 do
    FYLookup[I] := (I + FWinY) * SCREENWIDTH;
  for I := 0 to SCREENWIDTH - 1 do
    FColumnOfs[I] := FWinX + I;
  InitMapping;
  InitSlopes;
  InitLights;
end;

procedure TRenderer.InitMapping;
var
  Focal, I, T, Half, X: Integer;
  Ft: Integer;
begin
  Half := 4096;
  Focal := FixedDiv(FCenterXFrac, FineTangentAt(2048 + 1024));
  for I := 0 to Half - 1 do
  begin
    Ft := FineTangentAt(I);
    if Ft > 65536 * 2 then
      T := -1
    else if Ft < -65536 * 2 then
      T := FViewWidth + 1
    else
    begin
      T := SHar32(AsI32(Int64(FCenterXFrac) - FixedMul(Ft, Focal) + 65535), 16);
      if T < -1 then
        T := -1;
      if T > FViewWidth + 1 then
        T := FViewWidth + 1;
    end;
    FViewAngleToX[I] := T;
  end;
  for X := 0 to FViewWidth do
  begin
    I := 0;
    while (I < Half) and (FViewAngleToX[I] > X) do
      Inc(I);
    FXtoViewAngle[X] := AsU32((Int64(I) shl 19) - ANG90);
  end;
  for I := 0 to Half - 1 do
  begin
    if FViewAngleToX[I] = -1 then
      FViewAngleToX[I] := 0
    else if FViewAngleToX[I] = FViewWidth + 1 then
      FViewAngleToX[I] := FViewWidth;
  end;
  FClipAngle := FXtoViewAngle[0];
end;

procedure TRenderer.InitLights;
var
  I, J, StartMap, Level, Scale, Vw: Integer;
begin
  for I := 0 to 15 do
  begin
    StartMap := ((15 - I) * 2) * 32 div 16;
    for J := 0 to 127 do
    begin
      Scale := SHar32(FixedDiv((SCREENWIDTH div 2) * 65536, (J + 1) shl LIGHTZSHIFT), LIGHTSCALESHIFT);
      Level := StartMap - Scale div 2;
      if Level < 0 then
        Level := 0;
      if Level > 31 then
        Level := 31;
      FZLight[I, J] := Level;
    end;
    Vw := FViewWidth shl FDetail;
    if Vw < 1 then
      Vw := 1;
    for J := 0 to 47 do
    begin
      Level := StartMap - (J * SCREENWIDTH div Vw) div 2;
      if Level < 0 then
        Level := 0;
      if Level > 31 then
        Level := 31;
      FScaleLight[I, J] := Level;
    end;
  end;
end;

procedure TRenderer.InitSlopes;
var
  I, Dy, CosAdj: Integer;
begin
  for I := 0 to FViewHeight - 1 do
  begin
    Dy := Abs(((I - FCenterY) shl 16) + 32768);
    if Dy < 1 then
      Dy := 1;
    FYSlope[I] := FixedDiv(((FViewWidth shl FDetail) div 2) * 65536, Dy);
  end;
  for I := 0 to FViewWidth - 1 do
  begin
    CosAdj := AbsFixed(FineCos(FXtoViewAngle[I]));
    if CosAdj < 1 then
      CosAdj := 1;
    FDistScale[I] := FixedDiv(65536, CosAdj);
  end;
end;

procedure TRenderer.SetupFrame(X, Y, Z: Integer; Angle: Cardinal);
var
  Ang: Cardinal;
begin
  FViewX := X;
  FViewY := Y;
  FViewZ := Z;
  FViewAngle := Angle;
  FViewSin := FineSin(Angle);
  FViewCos := FineCos(Angle);
  FExtra := 0;
  FFixedMap := -1;
  Ang := UShr32(AsU32(Int64(Angle) - ANG90), 19) and 8191;
  if FCenterXFrac = 0 then
  begin
    FBaseXScale := 0;
    FBaseYScale := 0;
  end
  else
  begin
    FBaseXScale := FixedDiv(FineSin(Cardinal((Ang + 2048) and 8191) shl 19), FCenterXFrac);
    FBaseYScale := -FixedDiv(FineSin(Ang shl 19), FCenterXFrac);
  end;
end;

function TRenderer.PointToAngle(X, Y: Integer): Cardinal;
begin
  X := AsI32(Int64(X) - FViewX);
  Y := AsI32(Int64(Y) - FViewY);
  if (X = 0) and (Y = 0) then
    Exit(0);
  if X >= 0 then
  begin
    if Y >= 0 then
    begin
      if X > Y then
        Exit(TanToAngle(SlopeDiv(Y, X)));
      Exit(AsU32(Int64(ANG90) - 1 - TanToAngle(SlopeDiv(X, Y))));
    end;
    Y := -Y;
    if X > Y then
      Exit(AsU32(-Int64(TanToAngle(SlopeDiv(Y, X)))));
    Exit(AsU32($C0000000 + Int64(TanToAngle(SlopeDiv(X, Y)))));
  end;
  X := -X;
  if Y >= 0 then
  begin
    if X > Y then
      Exit(AsU32(Int64(ANG180) - 1 - TanToAngle(SlopeDiv(Y, X))));
    Exit(AsU32(Int64(ANG90) + TanToAngle(SlopeDiv(X, Y))));
  end;
  Y := -Y;
  if X > Y then
    Exit(AsU32(Int64(ANG180) + TanToAngle(SlopeDiv(Y, X))));
  Result := AsU32($C0000000 - 1 - Int64(TanToAngle(SlopeDiv(X, Y))));
end;

function TRenderer.PointOnSide(X, Y: Integer; Node: TNode): Integer;
var
  Dx, Dy: Integer;
  Left, Right: Int64;
begin
  Dx := AsI32(Int64(X) - Node.X);
  Dy := AsI32(Int64(Y) - Node.Y);
  Left := Int64(SHar32(Node.Dy, 16)) * Dx;
  Right := Int64(Dy) * SHar32(Node.Dx, 16);
  if Right >= Left then
    Result := 1
  else
    Result := 0;
end;

function TRenderer.ScaleFromAngle(Vis: Cardinal): Integer;
var
  AngleA, AngleB: Cardinal;
  SineA, SineB, Num, Den: Integer;
begin
  AngleA := AsU32(Int64(ANG90) + AsU32(Int64(Vis) - FViewAngle));
  AngleB := AsU32(Int64(ANG90) + AsU32(Int64(Vis) - FRwNormal));
  SineA := FineSin(AngleA);
  SineB := FineSin(AngleB);
  Num := FixedMul(FProjection, SineB) shl FDetail;
  Den := FixedMul(FRwDistance, SineA);
  if (Den <> 0) and (Den > SHar32(Num, 16)) then
  begin
    Result := FixedDiv(Num, Den);
    if Result > 64 * 65536 then
      Result := 64 * 65536
    else if Result < 256 then
      Result := 256;
  end
  else
    Result := 64 * 65536;
end;

function TRenderer.PointToDist(X, Y: Integer): Integer;
var
  Dx, Dy, Frac: Integer;
  Ang: Cardinal;
begin
  Dx := AbsFixed(AsI32(Int64(X) - FViewX));
  Dy := AbsFixed(AsI32(Int64(Y) - FViewY));
  if Dy > Dx then
  begin
    Frac := Dx;
    Dx := Dy;
    Dy := Frac;
  end;
  if Dx = 0 then
    Exit(0);
  Frac := FixedDiv(Dy, Dx);
  Frac := SHar32(Frac, 5);
  if Frac > 2048 then
    Frac := 2048;
  if Frac < 0 then
    Frac := 0;
  Ang := (TanToAngle(Frac) + ANG90) shr 19;
  Result := FixedDiv(Dx, FineSin(Ang shl 19));
end;

function TRenderer.FindPlane(Height, Pic, Light: Integer): TObject;
var
  I, X: Integer;
  P: TPlane;
begin
  if Pic = FRes.SkyFlat then
  begin
    Height := 0;
    Light := 0;
  end;
  for I := 0 to FPlanes.Count - 1 do
  begin
    P := TPlane(FPlanes[I]);
    if (P.Height = Height) and (P.Pic = Pic) and (P.Light = Light) then
      Exit(P);
  end;
  P := TPlane.Create;
  P.Height := Height;
  P.Pic := Pic;
  P.Light := Light;
  P.MinX := FViewWidth;
  P.MaxX := -1;
  for X := 0 to 319 do
  begin
    P.Top[X] := $FF;
    P.Bottom[X] := 0;
  end;
  FPlanes.Add(P);
  Result := P;
end;

function TRenderer.CheckPlane(Plane: TObject; Start, Stop: Integer): TObject;
var
  P, Dup: TPlane;
  Intrl, Intrh, UnionL, UnionH, X: Integer;
begin
  if Plane = nil then
    Exit(FindPlane(0, 0, 0));
  P := TPlane(Plane);
  if Start < P.MinX then
  begin
    Intrl := P.MinX;
    UnionL := Start;
  end
  else
  begin
    UnionL := P.MinX;
    Intrl := Start;
  end;
  if Stop > P.MaxX then
  begin
    Intrh := P.MaxX;
    UnionH := Stop;
  end
  else
  begin
    UnionH := P.MaxX;
    Intrh := Stop;
  end;
  if Intrl < 0 then
    Intrl := 0;
  if Intrh >= SCREENWIDTH then
    Intrh := SCREENWIDTH - 1;
  X := Intrl;
  while (X <= Intrh) and (X < SCREENWIDTH) do
  begin
    if (X >= 0) and (P.Top[X] <> $FF) then
      Break;
    Inc(X);
  end;
  if X > Intrh then
  begin
    P.MinX := UnionL;
    P.MaxX := UnionH;
    Exit(P);
  end;
  Dup := TPlane.Create;
  Dup.Height := P.Height;
  Dup.Pic := P.Pic;
  Dup.Light := P.Light;
  Dup.MinX := Start;
  Dup.MaxX := Stop;
  for X := 0 to 319 do
  begin
    Dup.Top[X] := $FF;
    Dup.Bottom[X] := 0;
  end;
  FPlanes.Add(Dup);
  Result := Dup;
end;

procedure TRenderer.ClearClip;
var
  I: Integer;
begin
  FSolidFirst[0] := -MaxInt;
  FSolidLast[0] := -1;
  FSolidFirst[1] := FViewWidth;
  FSolidLast[1] := MaxInt;
  FNewEnd := 2;
  for I := 0 to FViewWidth - 1 do
  begin
    FFloorClip[I] := FViewHeight;
    FCeilingClip[I] := -1;
  end;
end;

procedure TRenderer.Render(World: TWorld; var Fb: TBytes);
var
  I, N: Integer;
begin
  FFb := Fb;
  FPlanes.Clear;
  FSegs.Clear;
  FFloorPlane := nil;
  FCeilPlane := nil;
  N := World.SubsectorCount;
  if Length(FSeen) <> N then
    SetLength(FSeen, N);
  for I := 0 to N - 1 do
    FSeen[I] := 0;
  ClearClip;
  if World.NumNodes > 0 then
    RenderNode(World, World.NumNodes - 1)
  else if World.SubsectorAt(0) <> nil then
    RenderSubsector(World, 0);
  DrawPlanes;
end;

procedure TRenderer.RenderNode(World: TWorld; BspNum: Integer);
var
  Node: TNode;
  Side: Integer;
begin
  if (BspNum and NF_SUBSECTOR) <> 0 then
  begin
    RenderSubsector(World, BspNum and not NF_SUBSECTOR);
    Exit;
  end;
  if (BspNum < 0) or (BspNum >= World.NumNodes) then
  begin
    RenderSubsector(World, 0);
    Exit;
  end;
  Node := World.NodeAt(BspNum);
  Side := PointOnSide(FViewX, FViewY, Node);
  RenderNode(World, Node.Children[Side]);
  RenderNode(World, Node.Children[Side xor 1]);
end;

procedure TRenderer.RenderSubsector(World: TWorld; Num: Integer);
var
  Sub: TSubsector;
  Light, I: Integer;
begin
  if (Num < 0) then
    Exit;
  if Num < Length(FSeen) then
    FSeen[Num] := 1;
  Sub := World.SubsectorAt(Num);
  if (Sub = nil) or (Sub.Sector = nil) then
    Exit;
  FFront := Sub.Sector;
  Light := (FFront.LightLevel shr 4) + FExtra;
  if Light < 0 then
    Light := 0;
  if Light > 15 then
    Light := 15;
  FLightRow := Light;
  FFloorPlane := FindPlane(FFront.FloorHeight, FRes.FlatNumForName(FFront.FloorPic), FFront.LightLevel);
  FCeilPlane := FindPlane(FFront.CeilingHeight, FRes.FlatNumForName(FFront.CeilingPic), FFront.LightLevel);
  for I := 0 to Sub.NumLines - 1 do
  begin
    if Sub.FirstLine + I >= 0 then
      AddLine(World.SegAt(Sub.FirstLine + I));
  end;
end;

procedure TRenderer.AddLine(Seg: TSeg);
var
  Angle1, Angle2, Span, TSpan: Cardinal;
  X1, X2: Integer;
begin
  if (Seg = nil) or (Seg.V1 = nil) or (Seg.V2 = nil) then
    Exit;
  FCurSeg := Seg;
  Angle1 := PointToAngle(Seg.V1.X, Seg.V1.Y);
  Angle2 := PointToAngle(Seg.V2.X, Seg.V2.Y);
  Span := AsU32(Int64(Angle1) - Angle2);
  if Span >= ANG180 then
    Exit;
  FRwAngle1 := Angle1;
  Angle1 := AsU32(Int64(Angle1) - FViewAngle);
  Angle2 := AsU32(Int64(Angle2) - FViewAngle);
  TSpan := AsU32(Int64(Angle1) + FClipAngle);
  if TSpan > AsU32(Int64(FClipAngle) * 2) then
  begin
    TSpan := AsU32(Int64(TSpan) - Int64(FClipAngle) * 2);
    if TSpan >= Span then
      Exit;
    Angle1 := FClipAngle;
  end;
  TSpan := AsU32(Int64(FClipAngle) - Angle2);
  if TSpan > AsU32(Int64(FClipAngle) * 2) then
  begin
    TSpan := AsU32(Int64(TSpan) - Int64(FClipAngle) * 2);
    if TSpan >= Span then
      Exit;
    Angle2 := AsU32(-Int64(FClipAngle));
  end;
  X1 := FViewAngleToX[UShr32(AsU32(Int64(Angle1) + ANG90), 19) and 4095];
  X2 := FViewAngleToX[UShr32(AsU32(Int64(Angle2) + ANG90), 19) and 4095];
  if X1 = X2 then
    Exit;
  FBack := Seg.BackSector;
  if (FBack = nil) or (FBack.CeilingHeight <= FFront.FloorHeight) or
    (FBack.FloorHeight >= FFront.CeilingHeight) then
    ClipSolid(X1, X2 - 1)
  else
    ClipPass(X1, X2 - 1);
end;

procedure TRenderer.CrunchSolid(Start, NextI: Integer);
var
  I, Tail: Integer;
begin
  if NextI = Start then
    Exit;
  Tail := FNewEnd - (NextI + 1);
  for I := 0 to Tail - 1 do
  begin
    FSolidFirst[Start + 1 + I] := FSolidFirst[NextI + 1 + I];
    FSolidLast[Start + 1 + I] := FSolidLast[NextI + 1 + I];
  end;
  FNewEnd := Start + 1 + Tail;
end;

procedure TRenderer.ClipSolid(First, Last: Integer);
var
  Start, NextI: Integer;
begin
  if First > Last then
    Exit;
  Start := 0;
  while (Start < FNewEnd) and (FSolidLast[Start] < First - 1) do
    Inc(Start);
  if Start >= FNewEnd then
  begin
    StoreWall(First, Last);
    Exit;
  end;
  if First < FSolidFirst[Start] then
  begin
    if Last < FSolidFirst[Start] - 1 then
    begin
      StoreWall(First, Last);
      if FNewEnd < 127 then
      begin
        for NextI := FNewEnd downto Start + 1 do
        begin
          FSolidFirst[NextI] := FSolidFirst[NextI - 1];
          FSolidLast[NextI] := FSolidLast[NextI - 1];
        end;
        FSolidFirst[Start] := First;
        FSolidLast[Start] := Last;
        Inc(FNewEnd);
      end;
      Exit;
    end;
    StoreWall(First, FSolidFirst[Start] - 1);
    FSolidFirst[Start] := First;
  end;
  if Last <= FSolidLast[Start] then
    Exit;
  NextI := Start;
  while (NextI + 1 < FNewEnd) and (Last >= FSolidFirst[NextI + 1] - 1) do
  begin
    StoreWall(FSolidLast[NextI] + 1, FSolidFirst[NextI + 1] - 1);
    Inc(NextI);
    if Last <= FSolidLast[NextI] then
    begin
      FSolidLast[Start] := FSolidLast[NextI];
      CrunchSolid(Start, NextI);
      Exit;
    end;
  end;
  StoreWall(FSolidLast[NextI] + 1, Last);
  FSolidLast[Start] := Last;
  CrunchSolid(Start, NextI);
end;

procedure TRenderer.ClipPass(First, Last: Integer);
var
  Start, NextI: Integer;
begin
  if First > Last then
    Exit;
  Start := 0;
  while (Start < FNewEnd) and (FSolidLast[Start] < First - 1) do
    Inc(Start);
  if Start >= FNewEnd then
  begin
    StoreWall(First, Last);
    Exit;
  end;
  if First < FSolidFirst[Start] then
  begin
    if Last < FSolidFirst[Start] - 1 then
    begin
      StoreWall(First, Last);
      Exit;
    end;
    StoreWall(First, FSolidFirst[Start] - 1);
  end;
  if Last <= FSolidLast[Start] then
    Exit;
  NextI := Start;
  while (NextI + 1 < FNewEnd) and (Last >= FSolidFirst[NextI + 1] - 1) do
  begin
    StoreWall(FSolidLast[NextI] + 1, FSolidFirst[NextI + 1] - 1);
    Inc(NextI);
    if Last <= FSolidLast[NextI] then
      Exit;
  end;
  StoreWall(FSolidLast[NextI] + 1, Last);
end;

procedure TRenderer.PushSeg(Start, Stop, Scale1: Integer);
var
  Ds: TDrawSeg;
  Width, I: Integer;
begin
  Ds := TDrawSeg.Create;
  Ds.X1 := Start;
  Ds.X2 := Stop;
  Ds.Scale1 := Scale1;
  Ds.ScaleStep := FRwScaleStep;
  Ds.Scale2 := Scale1 + FRwScaleStep * (Stop - Start);
  if Stop < Start then
    Ds.Scale2 := Scale1;
  Ds.Line := FCurSeg;
  Ds.MaskTex := FMaskTex;
  Ds.MaskMid := FMaskMid;
  Width := Stop - Start + 1;
  if Width < 1 then
    Width := 1;
  SetLength(Ds.SprTop, Width);
  SetLength(Ds.SprBot, Width);
  if FBack = nil then
  begin
    Ds.Silhouette := SIL_BOTH;
    Ds.BSil := MaxInt;
    Ds.TSil := -MaxInt;
    for I := 0 to Width - 1 do
    begin
      Ds.SprTop[I] := FViewHeight;
      Ds.SprBot[I] := -1;
    end;
  end
  else
  begin
    Ds.Silhouette := 0;
    if FFront.FloorHeight > FBack.FloorHeight then
    begin
      Ds.Silhouette := SIL_BOTTOM;
      Ds.BSil := FFront.FloorHeight;
    end
    else if FBack.FloorHeight > FViewZ then
    begin
      Ds.Silhouette := SIL_BOTTOM;
      Ds.BSil := MaxInt;
    end;
    if FFront.CeilingHeight < FBack.CeilingHeight then
    begin
      Ds.Silhouette := Ds.Silhouette or SIL_TOP;
      Ds.TSil := FFront.CeilingHeight;
    end
    else if FBack.CeilingHeight < FViewZ then
    begin
      Ds.Silhouette := Ds.Silhouette or SIL_TOP;
      Ds.TSil := -MaxInt;
    end;
    for I := 0 to Width - 1 do
    begin
      if (Start + I >= 0) and (Start + I < FViewWidth) then
      begin
        Ds.SprTop[I] := FCeilingClip[Start + I];
        Ds.SprBot[I] := FFloorClip[Start + I];
      end
      else
      begin
        Ds.SprTop[I] := -1;
        Ds.SprBot[I] := FViewHeight;
      end;
    end;
  end;
  if FMaskTex >= 0 then
  begin
    SetLength(Ds.MaskCol, Width);
    SetLength(Ds.MaskScale, Width);
    SetLength(Ds.MaskLight, Width);
    for I := 0 to Width - 1 do
      if (Start + I >= 0) and (Start + I < FViewWidth) then
      begin
        Ds.MaskCol[I] := FColMask[Start + I];
        Ds.MaskScale[I] := FScaleMask[Start + I];
        Ds.MaskLight[I] := FLightMask[Start + I];
      end
      else
        Ds.MaskCol[I] := 0;
  end;
  FSegs.Add(Ds);
end;

procedure TRenderer.StoreWall(Start, Stop: Integer);
var
  Side: TSide;
  Line: TLine;
  OffsetAng, DistAng: Cardinal;
  Hyp, Scale2, VTop: Integer;
begin
  if (Start > Stop) or (FCurSeg = nil) or (FCurSeg.SideDef = nil) or (FFront = nil) then
    Exit;
  if (Start < 0) or (Stop >= FViewWidth) then
  begin
    if Start < 0 then
      Start := 0;
    if Stop >= FViewWidth then
      Stop := FViewWidth - 1;
    if Start > Stop then
      Exit;
  end;
  Side := FCurSeg.SideDef;
  Line := FCurSeg.LineDef;
  if Line <> nil then
    Line.Flags := Line.Flags or ML_MAPPED;
  FRwNormal := AsU32(Int64(FCurSeg.Angle) + ANG90);
  OffsetAng := AsU32(Int64(FRwNormal) - FRwAngle1);
  if OffsetAng > ANG180 then
    OffsetAng := AsU32(-Int64(OffsetAng));
  if OffsetAng > ANG90 then
    OffsetAng := ANG90;
  DistAng := AsU32(Int64(ANG90) - OffsetAng);
  Hyp := PointToDist(FCurSeg.V1.X, FCurSeg.V1.Y);
  FRwDistance := FixedMul(Hyp, FineSin(DistAng));
  FRwX := Start;
  FRwStart := Start;
  FRwStopX := Stop + 1;
  FRwScale := ScaleFromAngle(AsU32(Int64(FViewAngle) + FXtoViewAngle[Start]));
  if Stop > Start then
  begin
    Scale2 := ScaleFromAngle(AsU32(Int64(FViewAngle) + FXtoViewAngle[Stop]));
    FRwScaleStep := FloorDiv(Scale2 - FRwScale, Stop - Start);
  end
  else
    FRwScaleStep := 0;
  FWorldTop := AsI32(Int64(FFront.CeilingHeight) - FViewZ);
  FWorldBot := AsI32(Int64(FFront.FloorHeight) - FViewZ);
  FMidTex := -1;
  FTopTex := -1;
  FBotTex := -1;
  FMaskTex := -1;
  FSegTextured := False;
  if FBack = nil then
  begin
    FMidTex := FRes.TextureNumForName(Side.MidTexture);
    FMarkFloor := True;
    FMarkCeiling := True;
    if (Line <> nil) and ((Line.Flags and ML_DONTPEGBOTTOM) <> 0) then
    begin
      VTop := FFront.FloorHeight + FRes.TextureHeight(FMidTex);
      FRwMid := AsI32(Int64(VTop) - FViewZ);
    end
    else
      FRwMid := FWorldTop;
    FRwMid := AsI32(Int64(FRwMid) + Side.RowOffset);
  end
  else
  begin
    FWorldHigh := AsI32(Int64(FBack.CeilingHeight) - FViewZ);
    FWorldLow := AsI32(Int64(FBack.FloorHeight) - FViewZ);
    if (FRes.FlatNumForName(FFront.CeilingPic) = FRes.SkyFlat) and
      (FRes.FlatNumForName(FBack.CeilingPic) = FRes.SkyFlat) then
      FWorldTop := FWorldHigh;
    FMarkFloor := (FWorldLow <> FWorldBot) or (FBack.FloorPic <> FFront.FloorPic) or
      (FBack.LightLevel <> FFront.LightLevel);
    FMarkCeiling := (FWorldHigh <> FWorldTop) or (FBack.CeilingPic <> FFront.CeilingPic) or
      (FBack.LightLevel <> FFront.LightLevel);
    if (FBack.CeilingHeight <= FFront.FloorHeight) or (FBack.FloorHeight >= FFront.CeilingHeight) then
    begin
      FMarkFloor := True;
      FMarkCeiling := True;
    end;
    if FWorldHigh < FWorldTop then
    begin
      FTopTex := FRes.TextureNumForName(Side.TopTexture);
      if (Line <> nil) and ((Line.Flags and ML_DONTPEGTOP) <> 0) then
        FRwTop := FWorldTop
      else
      begin
        VTop := FBack.CeilingHeight + FRes.TextureHeight(FTopTex);
        FRwTop := AsI32(Int64(VTop) - FViewZ);
      end;
    end;
    if FWorldLow > FWorldBot then
    begin
      FBotTex := FRes.TextureNumForName(Side.BottomTexture);
      if (Line <> nil) and ((Line.Flags and ML_DONTPEGBOTTOM) <> 0) then
        FRwBot := FWorldTop
      else
        FRwBot := FWorldLow;
    end;
    FMaskTex := FRes.TextureNumForName(Side.MidTexture);
    if FMaskTex >= 0 then
    begin
      if (Line <> nil) and ((Line.Flags and ML_DONTPEGBOTTOM) <> 0) then
      begin
        if FFront.FloorHeight > FBack.FloorHeight then
          VTop := FFront.FloorHeight
        else
          VTop := FBack.FloorHeight;
        VTop := VTop + FRes.TextureHeight(FMaskTex);
      end
      else if FFront.CeilingHeight < FBack.CeilingHeight then
        VTop := FFront.CeilingHeight
      else
        VTop := FBack.CeilingHeight;
      FMaskMid := AsI32(Int64(VTop) - FViewZ + Side.RowOffset);
    end;
    FRwTop := AsI32(Int64(FRwTop) + Side.RowOffset);
    FRwBot := AsI32(Int64(FRwBot) + Side.RowOffset);
  end;
  FSegTextured := (FMidTex >= 0) or (FTopTex >= 0) or (FBotTex >= 0) or (FMaskTex >= 0);
  if FSegTextured then
  begin
    OffsetAng := AsU32(Int64(FRwNormal) - FRwAngle1);
    if OffsetAng > ANG180 then
      OffsetAng := AsU32(-Int64(OffsetAng));
    FRwOffset := FixedMul(Hyp, FineSin(OffsetAng));
    if AsU32(Int64(FRwNormal) - FRwAngle1) < ANG180 then
      FRwOffset := -FRwOffset;
    FRwOffset := AsI32(Int64(FRwOffset) + Side.TextureOffset + FCurSeg.Offset);
    FRwCenter := AsU32(Int64(ANG90) + FViewAngle - FRwNormal);
  end;
  if FFront.FloorHeight >= FViewZ then
    FMarkFloor := False;
  if (FFront.CeilingHeight <= FViewZ) and (FRes.FlatNumForName(FFront.CeilingPic) <> FRes.SkyFlat) then
    FMarkCeiling := False;
  if FMarkCeiling then
    FCeilPlane := CheckPlane(FCeilPlane, Start, Stop);
  if FMarkFloor then
    FFloorPlane := CheckPlane(FFloorPlane, Start, Stop);
  FWorldTop := SHar32(FWorldTop, 4);
  FWorldBot := SHar32(FWorldBot, 4);
  FTopStep := -FixedMul(FRwScaleStep, FWorldTop);
  FTopFrac := AsI32((Int64(FCenterYFrac) shr 4) - FixedMul(FWorldTop, FRwScale));
  FBotStep := -FixedMul(FRwScaleStep, FWorldBot);
  FBotFrac := AsI32((Int64(FCenterYFrac) shr 4) - FixedMul(FWorldBot, FRwScale));
  if FBack <> nil then
  begin
    FWorldHigh := SHar32(FWorldHigh, 4);
    FWorldLow := SHar32(FWorldLow, 4);
    if FWorldHigh < FWorldTop then
    begin
      FPixHigh := AsI32((Int64(FCenterYFrac) shr 4) - FixedMul(FWorldHigh, FRwScale));
      FPixHighStep := -FixedMul(FRwScaleStep, FWorldHigh);
    end;
    if FWorldLow > FWorldBot then
    begin
      FPixLow := AsI32((Int64(FCenterYFrac) shr 4) - FixedMul(FWorldLow, FRwScale));
      FPixLowStep := -FixedMul(FRwScaleStep, FWorldLow);
    end;
  end;
  Scale2 := FRwScale;
  SegLoop;
  PushSeg(Start, Stop, Scale2);
end;

procedure TRenderer.SegLoop;
var
  Yl, Yh, Mid, Index, TexCol: Integer;
  Angle: Cardinal;
  Plane: TPlane;
begin
  TexCol := 0;
  if FRwX < 0 then
    FRwX := 0;
  if FRwStopX > FViewWidth then
    FRwStopX := FViewWidth;
  while FRwX < FRwStopX do
  begin
    if (FRwX < 0) or (FRwX >= FViewWidth) then
      Break;
    Yl := SHar32(AsI32(Int64(FTopFrac) + HEIGHTUNIT - 1), HEIGHTBITS);
    if Yl < FCeilingClip[FRwX] + 1 then
      Yl := FCeilingClip[FRwX] + 1;
    if FMarkCeiling and (FCeilPlane <> nil) then
    begin
      Plane := TPlane(FCeilPlane);
      Mid := Yl - 1;
      if Mid >= FFloorClip[FRwX] then
        Mid := FFloorClip[FRwX] - 1;
      if FCeilingClip[FRwX] + 1 <= Mid then
      begin
        Plane.Top[FRwX] := FCeilingClip[FRwX] + 1;
        Plane.Bottom[FRwX] := Mid;
      end;
    end;
    Yh := SHar32(FBotFrac, HEIGHTBITS);
    if Yh >= FFloorClip[FRwX] then
      Yh := FFloorClip[FRwX] - 1;
    if FMarkFloor and (FFloorPlane <> nil) then
    begin
      Plane := TPlane(FFloorPlane);
      Mid := Yh + 1;
      Index := FFloorClip[FRwX] - 1;
      if Mid <= FCeilingClip[FRwX] then
        Mid := FCeilingClip[FRwX] + 1;
      if Mid <= Index then
      begin
        Plane.Top[FRwX] := Mid;
        Plane.Bottom[FRwX] := Index;
      end;
    end;
    if FSegTextured then
    begin
      Angle := UShr32(AsU32(Int64(FRwCenter) + FXtoViewAngle[FRwX]), 19);
      TexCol := SHar32(AsI32(Int64(FRwOffset) - FixedMul(FineTangentAt(Integer(Angle) and 4095), FRwDistance)), 16);
      Index := UShr32(FRwScale, LIGHTSCALESHIFT);
      if Index >= 48 then
        Index := 47;
      if Index < 0 then
        Index := 0;
      FDcLight := FScaleLight[FLightRow, Index];
      FDcX := FRwX;
      if FRwScale > 0 then
        FDcIScale := AsI32(Int64(4294967295) div Int64(FRwScale))
      else
        FDcIScale := 0;
    end;
    if FMidTex >= 0 then
    begin
      FDcYl := Yl;
      FDcYh := Yh;
      FDcMid := FRwMid;
      FRes.GetColumn(FMidTex, TexCol, FDcSource);
      DrawColumn;
      FCeilingClip[FRwX] := FViewHeight;
      FFloorClip[FRwX] := -1;
    end
    else
    begin
      if FTopTex >= 0 then
      begin
        Mid := SHar32(FPixHigh, HEIGHTBITS);
        FPixHigh := AsI32(Int64(FPixHigh) + FPixHighStep);
        if Mid >= FFloorClip[FRwX] then
          Mid := FFloorClip[FRwX] - 1;
        if Mid >= Yl then
        begin
          FDcYl := Yl;
          FDcYh := Mid;
          FDcMid := FRwTop;
          FRes.GetColumn(FTopTex, TexCol, FDcSource);
          DrawColumn;
          FCeilingClip[FRwX] := Mid;
        end
        else
          FCeilingClip[FRwX] := Yl - 1;
      end
      else if FMarkCeiling then
        FCeilingClip[FRwX] := Yl - 1;
      if FBotTex >= 0 then
      begin
        Mid := SHar32(AsI32(Int64(FPixLow) + HEIGHTUNIT - 1), HEIGHTBITS);
        FPixLow := AsI32(Int64(FPixLow) + FPixLowStep);
        if Mid <= FCeilingClip[FRwX] then
          Mid := FCeilingClip[FRwX] + 1;
        if Mid <= Yh then
        begin
          FDcYl := Mid;
          FDcYh := Yh;
          FDcMid := FRwBot;
          FRes.GetColumn(FBotTex, TexCol, FDcSource);
          DrawColumn;
          FFloorClip[FRwX] := Mid;
        end
        else
          FFloorClip[FRwX] := Yh + 1;
      end
      else if FMarkFloor then
        FFloorClip[FRwX] := Yh + 1;
      if (FMaskTex >= 0) and (FRwX >= 0) and (FRwX <= 319) then
      begin
        FColMask[FRwX] := TexCol;
        FScaleMask[FRwX] := FRwScale;
        FLightMask[FRwX] := FDcLight;
      end;
    end;
    FRwScale := AsI32(Int64(FRwScale) + FRwScaleStep);
    FTopFrac := AsI32(Int64(FTopFrac) + FTopStep);
    FBotFrac := AsI32(Int64(FBotFrac) + FBotStep);
    Inc(FRwX);
  end;
end;

procedure TRenderer.RenderMaskedRange(SegObj: TObject; X1, X2: Integer);
var
  X, Sx, P, N, Y, Scale, Mid, SprScreen, TopScreen, BotScreen, Yl, Yh: Integer;
  Ds: TDrawSeg;
  Tops, Lens: array[0..31] of Integer;
  Pix: array[0..31] of TBytes;
begin
  Ds := TDrawSeg(SegObj);
  if (Ds = nil) or (Ds.MaskTex < 0) or (Length(Ds.MaskCol) = 0) then
    Exit;
  if X1 < Ds.X1 then
    X1 := Ds.X1;
  if X2 > Ds.X2 then
    X2 := Ds.X2;
  for X := X1 to X2 do
  begin
    Sx := X - Ds.X1;
    if (Sx < 0) or (Sx >= Length(Ds.MaskCol)) or (Sx >= Length(Ds.SprTop)) then
      Continue;
    if Ds.MaskCol[Sx] = 32767 then
      Continue;
    Scale := Ds.MaskScale[Sx];
    if (X < 0) or (X >= FViewWidth) or (Scale <= 0) then
      Continue;
    N := FRes.ReadMaskPosts(Ds.MaskTex, Ds.MaskCol[Sx], Tops, Lens, Pix);
    Ds.MaskCol[Sx] := 32767;
    if N <= 0 then
      Continue;
    Mid := Ds.MaskMid;
    SprScreen := AsI32(Int64(FCenterYFrac) - FixedMul(Mid, Scale));
    FDcX := X;
    FDcLight := Ds.MaskLight[Sx];
    FDcIScale := AsI32(Int64(4294967295) div Int64(Scale));
    for P := 0 to N - 1 do
    begin
      if Lens[P] <= 0 then
        Continue;
      TopScreen := AsI32(Int64(SprScreen) + Int64(Scale) * Tops[P]);
      BotScreen := AsI32(Int64(TopScreen) + Int64(Scale) * Lens[P]);
      Yl := SHar32(AsI32(Int64(TopScreen) + 65535), 16);
      Yh := SHar32(AsI32(Int64(BotScreen) - 1), 16);
      if Yh >= Ds.SprBot[Sx] then
        Yh := Ds.SprBot[Sx] - 1;
      if Yl <= Ds.SprTop[Sx] then
        Yl := Ds.SprTop[Sx] + 1;
      if Yl < 0 then
        Yl := 0;
      if Yh >= FViewHeight then
        Yh := FViewHeight - 1;
      if Yl > Yh then
        Continue;
      for Y := 0 to 127 do
        FDcSource[Y] := 0;
      for Y := 0 to Lens[P] - 1 do
        if Y < 128 then
          FDcSource[Y] := Pix[P][Y];
      FDcYl := Yl;
      FDcYh := Yh;
      FDcMid := AsI32(Int64(Mid) - (Int64(Tops[P]) shl 16));
      DrawColumn;
    end;
  end;
end;

procedure TRenderer.DrawMaskedSegs;
var
  I: Integer;
  Ds: TDrawSeg;
begin
  for I := FSegs.Count - 1 downto 0 do
  begin
    Ds := TDrawSeg(FSegs[I]);
    if (Ds.MaskTex < 0) or (Length(Ds.MaskCol) = 0) then
      Continue;
    RenderMaskedRange(Ds, Ds.X1, Ds.X2);
  end;
end;

procedure TRenderer.DrawColumn;
var
  Count, Yl, Dest, Frac, Idx, Sx: Integer;
  Pix: Byte;
begin
  Count := FDcYh - FDcYl;
  if (Count < 0) or (FDcX < 0) or (FDcX >= FViewWidth) then
    Exit;
  Yl := FDcYl;
  if Yl < 0 then
  begin
    Frac := AsI32(Int64(FDcMid) + Int64(0 - FCenterY) * FDcIScale);
    Count := Count + Yl;
    Yl := 0;
  end
  else
    Frac := AsI32(Int64(FDcMid) + Int64(FDcYl - FCenterY) * FDcIScale);
  if (Yl < 0) or (Yl >= FViewHeight) then
    Exit;
  Sx := FDcX shl FDetail;
  if (Sx < 0) or (Sx >= SCREENWIDTH) then
    Exit;
  Dest := FYLookup[Yl] + FColumnOfs[Sx];
  while (Count >= 0) and (Yl < FViewHeight) and (Yl + FWinY < SCREENHEIGHT) do
  begin
    Idx := (UShr32(Frac, 16)) and 127;
    Pix := FRes.MapColor(FDcLight, FDcSource[Idx]);
    if (Dest >= 0) and (Dest < SCREENPIXELS) then
      FFb[Dest] := Pix;
    if (FDetail <> 0) and (Dest + 1 >= 0) and (Dest + 1 < SCREENPIXELS) then
      FFb[Dest + 1] := Pix;
    Inc(Dest, SCREENWIDTH);
    Frac := AsI32(Int64(Frac) + FDcIScale);
    Dec(Count);
    Inc(Yl);
  end;
end;

procedure TRenderer.DrawPlanes;
var
  I, X, Y, T1, B1, Light, Index, Spot, Dest: Integer;
  Distance, Length, XFrac, YFrac, PlaneZ: Integer;
  P: TPlane;
  CachedY: Integer;
  Pix: Byte;
begin
  for I := 0 to FPlanes.Count - 1 do
  begin
    P := TPlane(FPlanes[I]);
    if P.MinX < 0 then
      P.MinX := 0;
    if P.MaxX >= FViewWidth then
      P.MaxX := FViewWidth - 1;
    if P.MinX > P.MaxX then
      Continue;
    if P.Pic = FRes.SkyFlat then
    begin
      FDcIScale := 9 * 65536 div 10;
      FDcLight := 0;
      FDcMid := 100 * 65536;
      for X := P.MinX to P.MaxX do
      begin
        if (X < 0) or (X >= FViewWidth) then
          Continue;
        T1 := P.Top[X];
        B1 := P.Bottom[X];
        if (T1 <= B1) and (T1 < $FF) then
        begin
          FDcX := X;
          FDcYl := T1;
          FDcYh := B1;
          FRes.GetColumn(FRes.SkyTex, Integer(UShr32(AsU32(Int64(FViewAngle) + FXtoViewAngle[X]), 22)), FDcSource);
          DrawColumn;
        end;
      end;
      Continue;
    end;
    Light := (P.Light shr 4) + FExtra;
    if Light < 0 then
      Light := 0;
    if Light > 15 then
      Light := 15;
    PlaneZ := AbsFixed(AsI32(Int64(P.Height) - FViewZ));
    if PlaneZ = 0 then
      Continue;
    CachedY := -1;
    Distance := 0;
    for X := P.MinX to P.MaxX do
    begin
      if (X < 0) or (X >= FViewWidth) then
        Continue;
      T1 := P.Top[X];
      B1 := P.Bottom[X];
      if (T1 > B1) or (T1 = $FF) then
        Continue;
      if T1 < 0 then
        T1 := 0;
      if B1 >= FViewHeight then
        B1 := FViewHeight - 1;
      for Y := T1 to B1 do
      begin
        if (Y < 0) or (Y >= FViewHeight) then
          Continue;
        if Y <> CachedY then
        begin
          CachedY := Y;
          Distance := FixedMul(PlaneZ, FYSlope[Y]);
        end;
        Length := FixedMul(Distance, FDistScale[X]);
        Index := Integer(UShr32(AsU32(Int64(FViewAngle) + FXtoViewAngle[X]), 19) and 8191);
        XFrac := AsI32(Int64(FViewX) + FixedMul(FineSin(Cardinal((Index + 2048) and 8191) shl 19), Length));
        YFrac := AsI32(-Int64(FViewY) - FixedMul(FineSin(Cardinal(Index) shl 19), Length));
        Index := UShr32(Distance, LIGHTZSHIFT);
        if Index > 127 then
          Index := 127;
        if Index < 0 then
          Index := 0;
        Spot := (SHar32(XFrac, 16) and 63) or (SHar32(YFrac, 10) and $FC0);
        Pix := FRes.MapColor(FZLight[Light, Index], FRes.FlatPixel(P.Pic, Spot));
        Dest := FYLookup[Y] + FColumnOfs[X shl FDetail];
        if (Dest >= 0) and (Dest < SCREENPIXELS) then
          FFb[Dest] := Pix;
        if (FDetail <> 0) and (Dest + 1 >= 0) and (Dest + 1 < SCREENPIXELS) then
          FFb[Dest + 1] := Pix;
      end;
    end;
  end;
end;

procedure TRenderer.DrawMapThings(World: TWorld; Skill: Integer);
var
  I, Bit, Lump, Flip, W, Left, Top, X1, X2, Tz, Tx, Gx, Gy, Gz, Gzt, XScale, SprScale, SprLight, Radius, ThingHp, LightNum: Integer;
  RelX, RelY, Gxt, Gyt, IScale, StartFrac, XiScale, TexMid: Integer;
  Th: TMapThing;
  Spr: string;
  Frame, Height, Flags: Integer;
  Sub: TSubsector;
  Patch: TBytes;
  VisX1, VisX2, X, Col, Column, Y, Yl, Yh, Source, Len, TopDelta: Integer;
  SprTop, YIScale, Frac, Idx, Dest, ClipTop, ClipBot, Off: Integer;
  Ang: Cardinal;
  Ds: TDrawSeg;
  R1, R2, Si, Scale, LowScale, N, J, Tmp: Integer;
  ClipT, ClipB: array[0..319] of Integer;
  Order: TArray<Integer>;
  Best: Int64;
  Far: TArray<Int64>;
begin
  Bit := SkillBit(Skill);
  N := World.ThingCount;
  SetLength(Order, N);
  SetLength(Far, N);
  for I := 0 to N - 1 do
  begin
    Order[I] := I;
    Th := World.ThingAt(I);
    if Th = nil then
      Far[I] := 0
    else
      Far[I] := Sqr(Int64(Th.X) - SHar32(FViewX, 16)) + Sqr(Int64(Th.Y) - SHar32(FViewY, 16));
  end;
  for I := 1 to N - 1 do
  begin
    Tmp := Order[I];
    Best := Far[Tmp];
    J := I;
    while (J > 0) and (Far[Order[J - 1]] < Best) do
    begin
      Order[J] := Order[J - 1];
      Dec(J);
    end;
    Order[J] := Tmp;
  end;
  for I := 0 to N - 1 do
  begin
    Th := World.ThingAt(Order[I]);
    if (Th = nil) or (Th.FrameUse = -2) then
      Continue;
    if Th.SprName <> '' then
    begin
      Spr := Th.SprName;
      Frame := Th.SprFrame;
      Height := Th.BodyHeight;
      if Height <= 0 then
        Height := 8 * 65536;
      Flags := Th.ActorFlags;
      Radius := Th.Radius;
      ThingHp := 0;
    end
    else
    begin
      if (Th.ThingType <= 4) or (Th.ThingType = 11) then
        Continue;
      if (Th.Options and Bit) = 0 then
        Continue;
      if (Th.Options and 16) <> 0 then
        Continue;
      if not ThingInfo(Th.ThingType, Spr, Frame, Height, Flags, Radius, ThingHp) then
        Continue;
      if Th.FrameUse >= 0 then
        Frame := Th.FrameUse;
    end;
    if (Flags and 8) <> 0 then
      Continue;
    if (Th.Radius = 0) and (Radius > 0) then
      Th.Radius := Radius;
    if (Th.ActorFlags = 0) and (Flags <> 0) then
    begin
      Th.ActorFlags := Flags;
      Th.BodyHeight := Height;
      Th.Health := ThingHp;
    end;
    Gx := AsI32(Int64(Th.X) * 65536);
    Gy := AsI32(Int64(Th.Y) * 65536);
    Sub := World.PointInSubsector(Gx, Gy);
    if (Sub = nil) or (Sub.Sector = nil) then
      Continue;
    if (Sub.Index < 0) or (Sub.Index >= Length(FSeen)) or (FSeen[Sub.Index] = 0) then
      Continue;
    if Th.HasZ then
      Gz := Th.Z
    else if (Flags and 256) <> 0 then
      Gz := AsI32(Int64(Sub.Sector.CeilingHeight) - Height)
    else
      Gz := Sub.Sector.FloorHeight;
    Ang := AsU32(Int64(Th.Angle) * $40000000 div 90);
    if not FRes.LookupSprite(Spr, PointToAngle(Gx, Gy), Ang, Frame, Lump, Flip) then
      Continue;
    Patch := FRes.WadData.CacheLumpNum(Lump);
    if Length(Patch) < 8 then
      Continue;
    W := Patch[0] or (Patch[1] shl 8);
    if W >= 32768 then
      W := W - 65536;
    Left := Patch[4] or (Patch[5] shl 8);
    if Left >= 32768 then
      Left := Left - 65536;
    Top := Patch[6] or (Patch[7] shl 8);
    if Top >= 32768 then
      Top := Top - 65536;
    RelX := AsI32(Int64(Gx) - FViewX);
    RelY := AsI32(Int64(Gy) - FViewY);
    Gxt := FixedMul(RelX, FViewCos);
    Gyt := -FixedMul(RelY, FViewSin);
    Tz := AsI32(Int64(Gxt) - Gyt);
    if Tz < MINZ then
      Continue;
    XScale := FixedDiv(FProjection, Tz);
    if XScale <= 0 then
      Continue;
    if XScale > 64 * 65536 then
      XScale := 64 * 65536;
    SprScale := XScale shl FDetail;
    if SprScale > 64 * 65536 then
      SprScale := 64 * 65536;
    if Th.SprName <> '' then
      SprLight := 0
    else
    begin
      LightNum := (Sub.Sector.LightLevel shr 4) + FExtra;
      if LightNum < 0 then
        LightNum := 0;
      if LightNum > 15 then
        LightNum := 15;
      SprLight := UShr32(SprScale, LIGHTSCALESHIFT);
      if SprLight > 47 then
        SprLight := 47;
      SprLight := FScaleLight[LightNum, SprLight];
    end;
    Gxt := -FixedMul(RelX, FViewSin);
    Gyt := FixedMul(RelY, FViewCos);
    Tx := AsI32(-(Int64(Gyt) + Gxt));
    if Abs(Int64(Tx)) > Abs(Int64(Tz)) * 4 then
      Continue;
    Tx := AsI32(Int64(Tx) - Int64(Left) * 65536);
    X1 := SHar32(AsI32(Int64(FCenterXFrac) + FixedMul(Tx, XScale)), 16);
    if X1 > FViewWidth then
      Continue;
    Tx := AsI32(Int64(Tx) + Int64(W) * 65536);
    X2 := SHar32(AsI32(Int64(FCenterXFrac) + FixedMul(Tx, XScale)), 16) - 1;
    if X2 < 0 then
      Continue;
    if XScale = 0 then
      IScale := 65536
    else
      IScale := FixedDiv(65536, XScale);
    if Flip <> 0 then
      XiScale := -IScale
    else
      XiScale := IScale;
    if Flip <> 0 then
      StartFrac := (W shl 16) - 1
    else
      StartFrac := 0;
    VisX1 := X1;
    if VisX1 < 0 then
      VisX1 := 0;
    VisX2 := X2;
    if VisX2 > FViewWidth - 1 then
      VisX2 := FViewWidth - 1;
    if VisX1 > X1 then
      StartFrac := AsI32(Int64(StartFrac) + Int64(XiScale) * (VisX1 - X1));
    Gzt := AsI32(Int64(Gz) + Int64(Top) * 65536);
    TexMid := AsI32(Int64(Gzt) - FViewZ);
    for X := 0 to 319 do
    begin
      ClipT[X] := -2;
      ClipB[X] := -2;
    end;
    for Si := FSegs.Count - 1 downto 0 do
    begin
      Ds := TDrawSeg(FSegs[Si]);
      if (Ds.X1 > VisX2) or (Ds.X2 < VisX1) then
        Continue;
      if (Ds.Silhouette = 0) and (Ds.MaskTex < 0) then
        Continue;
      R1 := Ds.X1;
      if R1 < VisX1 then
        R1 := VisX1;
      R2 := Ds.X2;
      if R2 > VisX2 then
        R2 := VisX2;
      if Ds.X2 <= Ds.X1 then
      begin
        Scale := Ds.Scale1;
        LowScale := Ds.Scale1;
      end
      else
      begin
        Scale := Ds.Scale1 + Integer((Int64(Ds.Scale2 - Ds.Scale1) * (R1 - Ds.X1)) div (Ds.X2 - Ds.X1));
        LowScale := Ds.Scale1 + Integer((Int64(Ds.Scale2 - Ds.Scale1) * (R2 - Ds.X1)) div (Ds.X2 - Ds.X1));
      end;
      if LowScale > Scale then
        Scale := LowScale;
      if Scale < SprScale then
      begin
        if Ds.MaskTex >= 0 then
          RenderMaskedRange(Ds, R1, R2);
        Continue;
      end;
      for X := R1 to R2 do
      begin
        Column := X - Ds.X1;
        if (Column < 0) or (Column > High(Ds.SprTop)) then
          Continue;
        if ((Ds.Silhouette and SIL_BOTTOM) <> 0) and (Gz < Ds.BSil) and (ClipB[X] = -2) then
          ClipB[X] := Ds.SprBot[Column];
        if ((Ds.Silhouette and SIL_TOP) <> 0) and (Gzt > Ds.TSil) and (ClipT[X] = -2) then
          ClipT[X] := Ds.SprTop[Column];
      end;
    end;
    SprTop := AsI32(Int64(FCenterYFrac) - FixedMul(TexMid, SprScale));
    YIScale := Abs(XiScale) shr FDetail;
    if YIScale < 1 then
      YIScale := 1;
    Frac := StartFrac;
    for X := VisX1 to VisX2 do
    begin
      Col := SHar32(Frac, 16);
      Frac := AsI32(Int64(Frac) + XiScale);
      if (Col < 0) or (Col >= W) then
        Continue;
      if 8 + (Col + 1) * 4 > Length(Patch) then
        Continue;
      Column := Integer(Cardinal(Patch[8 + Col * 4]) or (Cardinal(Patch[9 + Col * 4]) shl 8) or
        (Cardinal(Patch[10 + Col * 4]) shl 16) or (Cardinal(Patch[11 + Col * 4]) shl 24));
      ClipTop := ClipT[X];
      if ClipTop = -2 then
        ClipTop := -1;
      ClipBot := ClipB[X];
      if ClipBot = -2 then
        ClipBot := FViewHeight;
      while (Column >= 0) and (Column < Length(Patch)) do
      begin
        TopDelta := Patch[Column];
        if TopDelta = $FF then
          Break;
        if Column + 1 >= Length(Patch) then
          Break;
        Len := Patch[Column + 1];
        Source := Column + 3;
        Yl := SHar32(AsI32(Int64(SprTop) + Int64(SprScale) * TopDelta + 65535), 16);
        Yh := SHar32(AsI32(Int64(SprTop) + Int64(SprScale) * (TopDelta + Len) - 1), 16);
        if Yl <= ClipTop then
          Yl := ClipTop + 1;
        if Yh >= ClipBot then
          Yh := ClipBot - 1;
        if Yl < 0 then
          Yl := 0;
        if Yh >= FViewHeight then
          Yh := FViewHeight - 1;
        if Yh >= SCREENHEIGHT then
          Yh := SCREENHEIGHT - 1;
        if Yl <= Yh then
        begin
          Idx := FixedMul(AsI32((Int64(Yl) shl 16) - (Int64(SprTop) + Int64(SprScale) * TopDelta)), YIScale);
          if Idx < 0 then
            Idx := 0;
          Y := Yl;
          while Y <= Yh do
          begin
            Dest := Idx shr 16;
            if Dest < 0 then
              Dest := 0;
            if Dest >= Len then
              Dest := Len - 1;
            if (Dest >= 0) and (Source + Dest < Length(Patch)) and (Y >= 0) and (Y < SCREENHEIGHT) then
            begin
              Off := FYLookup[Y] + FColumnOfs[X shl FDetail];
              if (Off >= 0) and (Off < SCREENPIXELS) then
                FFb[Off] := FRes.MapColor(SprLight, Patch[Source + Dest]);
              if (FDetail <> 0) and (Off + 1 >= 0) and (Off + 1 < SCREENPIXELS) then
                FFb[Off + 1] := FRes.MapColor(SprLight, Patch[Source + Dest]);
            end;
            Idx := AsI32(Int64(Idx) + YIScale);
            Inc(Y);
          end;
        end;
        Column := Column + Len + 4;
      end;
    end;
  end;
  DrawMaskedSegs;
end;

procedure TRenderer.SetLightBoost(Amount: Integer);
begin
  if Amount < 0 then
    Amount := 0;
  if Amount > 4 then
    Amount := 4;
  FExtra := Amount;
end;

procedure TRenderer.DrawPSprite(const Patch: TBytes; Sx, Sy: Integer);
var
  W, Left, Top, PScale, PIScale, VisScale, YStep, Tx, X1, X2, VisX1, VisX2: Integer;
  TexMid, SprTop, StartFrac, Frac, Col, Column, Y, Yl, Yh, Source, Len, TopDelta: Integer;
  Idx, Dest, Off: Integer;
begin
  if (Length(Patch) < 8) or (FViewWidth < 2) then
    Exit;
  W := Patch[0] or (Patch[1] shl 8);
  if W >= 32768 then
    W := W - 65536;
  Left := Patch[4] or (Patch[5] shl 8);
  if Left >= 32768 then
    Left := Left - 65536;
  Top := Patch[6] or (Patch[7] shl 8);
  if Top >= 32768 then
    Top := Top - 65536;
  PScale := (65536 * FViewWidth) div SCREENWIDTH;
  if PScale < 1 then
    PScale := 1;
  PIScale := (65536 * SCREENWIDTH) div FViewWidth;
  VisScale := PScale shl FDetail;
  YStep := PIScale;
  if FDetail <> 0 then
    YStep := PIScale shr FDetail;
  if YStep < 1 then
    YStep := 1;
  Tx := AsI32(Int64(Sx) - 160 * 65536 - Int64(Left) * 65536);
  X1 := SHar32(AsI32(Int64(FCenterXFrac) + FixedMul(Tx, PScale)), 16);
  if X1 > FViewWidth then
    Exit;
  Tx := AsI32(Int64(Tx) + Int64(W) * 65536);
  X2 := SHar32(AsI32(Int64(FCenterXFrac) + FixedMul(Tx, PScale)), 16) - 1;
  if X2 < 0 then
    Exit;
  VisX1 := X1;
  if VisX1 < 0 then
    VisX1 := 0;
  VisX2 := X2;
  if VisX2 > FViewWidth - 1 then
    VisX2 := FViewWidth - 1;
  StartFrac := 0;
  if VisX1 > X1 then
    StartFrac := AsI32(Int64(PIScale) * (VisX1 - X1));
  TexMid := AsI32(100 * 65536 + 32768 - (Int64(Sy) - Int64(Top) * 65536));
  SprTop := AsI32(Int64(FCenterYFrac) - FixedMul(TexMid, VisScale));
  Frac := StartFrac;
  for Col := VisX1 to VisX2 do
  begin
    Column := SHar32(Frac, 16);
    Frac := AsI32(Int64(Frac) + PIScale);
    if (Column < 0) or (Column >= W) then
      Continue;
    if 8 + (Column + 1) * 4 > Length(Patch) then
      Continue;
    Off := Integer(Cardinal(Patch[8 + Column * 4]) or (Cardinal(Patch[9 + Column * 4]) shl 8) or
      (Cardinal(Patch[10 + Column * 4]) shl 16) or (Cardinal(Patch[11 + Column * 4]) shl 24));
    while (Off >= 0) and (Off < Length(Patch)) do
    begin
      TopDelta := Patch[Off];
      if TopDelta = $FF then
        Break;
      if Off + 1 >= Length(Patch) then
        Break;
      Len := Patch[Off + 1];
      Source := Off + 3;
      Yl := SHar32(AsI32(Int64(SprTop) + Int64(VisScale) * TopDelta + 65535), 16);
      Yh := SHar32(AsI32(Int64(SprTop) + Int64(VisScale) * (TopDelta + Len) - 1), 16);
      if Yl < 0 then
        Yl := 0;
      if Yh >= FViewHeight then
        Yh := FViewHeight - 1;
      if Yl <= Yh then
      begin
        Idx := FixedMul(AsI32((Int64(Yl) shl 16) - (Int64(SprTop) + Int64(VisScale) * TopDelta)), YStep);
        if Idx < 0 then
          Idx := 0;
        for Y := Yl to Yh do
        begin
          Dest := Idx shr 16;
          if (Dest >= 0) and (Dest < Len) and (Source + Dest < Length(Patch)) then
          begin
            Column := FYLookup[Y] + FColumnOfs[Col shl FDetail];
            if (Column >= 0) and (Column < SCREENPIXELS) then
              FFb[Column] := FRes.MapColor(0, Patch[Source + Dest]);
            if (FDetail <> 0) and (Column + 1 >= 0) and (Column + 1 < SCREENPIXELS) then
              FFb[Column + 1] := FRes.MapColor(0, Patch[Source + Dest]);
          end;
          Idx := AsI32(Int64(Idx) + YStep);
        end;
      end;
      Off := Off + Len + 4;
    end;
  end;
end;

end.
