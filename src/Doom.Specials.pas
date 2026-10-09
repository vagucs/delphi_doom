unit Doom.Specials;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Portas, elevadores, luzes e saida, igual a doom/specials.py.
}

interface

uses
  System.Classes, System.Contnrs, Doom.World, Doom.Player, Doom.RData;

type
  TSpecials = class
  public
    ExitRequested: Boolean;
    SecretExit: Boolean;
    constructor Create(AWorld: TWorld; APlayer: TPlayer; ARes: TResources);
    destructor Destroy; override;
    procedure Tick;
    procedure Use;
    procedure Cross(OldX, OldY: Integer);
    procedure Shoot(Ln: TLine);
    procedure MonsterUse(Ln: TLine);
  private
    FWorld: TWorld;
    FPlayer: TPlayer;
    FRes: TResources;
    FThinkers: TObjectList;
    FLights: TObjectList;
    FButtons: TObjectList;
    FScrolls: TObjectList;
    FRnd: Cardinal;
    function Rnd: Integer;
    function LowestCeiling(Sec: TSector): Integer;
    function LowestFloor(Sec: TSector): Integer;
    function HighestFloor(Sec: TSector): Integer;
    function NextHighest(Sec: TSector; Current: Integer): Integer;
    function HighestCeiling(Sec: TSector): Integer;
    function RaiseDest(Sec: TSector): Integer;
    function MinLight(Sec: TSector; MaxLight: Integer): Integer;
    function MaxLight(Sec: TSector): Integer;
    function Settle(Sec: TSector; Crush: Boolean): Boolean;
    function MovePlane(Sec: TSector; Speed, Dest, FloorOrCeil, Direction: Integer; Crush: Boolean): Integer;
    function SpawnDoor(Sec: TSector; Kind: Integer; Reverse: Boolean): Boolean;
    function DoDoor(Ln: TLine; Kind: Integer; Reverse: Boolean): Boolean;
    procedure ManualDoor(Ln: TLine);
    function DoPlatDown(Ln: TLine; Blaze: Boolean): Boolean;
    function DoPlatUp(Ln: TLine; Amount: Integer): Boolean;
    function DoPlatAlways(Ln: TLine): Boolean;
    function StopPlat(Ln: TLine): Boolean;
    function FloorDest(Sec: TSector; Kind: Integer): Integer;
    function DoFloor(Ln: TLine; Kind, Direction, Speed: Integer; Crush: Boolean): Boolean;
    function DoStairs(Ln: TLine; Step, Speed: Integer): Boolean;
    function DoCrusher(Ln: TLine; Kind: Integer): Boolean;
    function DoDonut(Ln: TLine): Boolean;
    function RaiseTexture(Ln: TLine): Boolean;
    function LowerChange(Ln: TLine): Boolean;
    function LightOn(Ln: TLine; Bright: Integer): Boolean;
    function LightsOff(Ln: TLine): Boolean;
    function StartStrobe(Ln: TLine): Boolean;
    procedure SpawnMap;
    procedure TickOne(Mv: TObject);
    procedure TickLights;
    procedure ChangeSwitch(Ln: TLine; Again: Boolean);
    procedure UseSpecial(Ln: TLine; Side: Integer);
    procedure CrossSpecial(Ln: TLine; Side: Integer);
    procedure Teleport(Ln: TLine; Side: Integer);
    procedure TouchKeys;
    procedure TouchItems;
    function HitLine(X1, Y1, X2, Y2: Integer; Ln: TLine; out Along: Integer): Boolean;
    function SideOf(Px, Py: Integer; Ln: TLine): Integer;
    function Passage(Ln: TLine): Integer;
    function Swapped(const Name: string): string;
  end;

implementation

uses
  System.SysUtils, Doom.Compat, Doom.Tables, Doom.Sound;

const
  VDOORSPEED = 2 * 65536;
  VDOORWAIT = 150;
  PLATSPEED = 65536;
  PLATWAIT = 3 * 35;
  FLOORSPEED = 65536;
  CEILSPEED = 65536;
  GLOWSPEED = 8;
  STROBEBRIGHT = 5;
  FASTDARK = 15;
  SLOWDARK = 35;
  BUTTONTIME = 35;
  USERANGE = 64 * 65536;
  VLD_NORMAL = 0;
  VLD_CLOSE30 = 1;
  VLD_CLOSE = 2;
  VLD_OPEN = 3;
  VLD_RAISEIN5 = 4;
  VLD_BLAZERAISE = 5;
  VLD_BLAZEOPEN = 6;
  VLD_BLAZECLOSE = 7;
  PLAT_DOWN = 0;
  PLAT_UP = 1;
  PLAT_WAITING = 2;
  CEIL_LOWERTOFLOOR = 0;
  CEIL_RAISETOHIGHEST = 1;
  CEIL_LOWERANDCRUSH = 2;
  CEIL_CRUSHANDRAISE = 3;
  CEIL_FASTCRUSH = 4;
  CEIL_SILENTCRUSH = 5;
  DEST_LOWEST = 0;
  DEST_HIGHEST = 1;
  DEST_NEXT = 2;
  DEST_CEIL = 3;
  DEST_CRUSH = 4;
  DEST_DOWN8 = 5;
  DEST_UP24 = 6;
  DEST_UP32 = 7;
  DEST_UP512 = 8;
  LIGHT_FLASH = 0;
  LIGHT_STROBE = 1;
  LIGHT_GLOW = 2;
  LIGHT_FIRE = 3;

type
  TMover = class
  public
    Sector: TSector;
    Dead: Boolean;
  end;

  TVerticalDoor = class(TMover)
  public
    Kind: Integer;
    Direction: Integer;
    TopHeight: Integer;
    Speed: Integer;
    TopWait: Integer;
    TopCount: Integer;
  end;

  TPlat = class(TMover)
  public
    Kind: Integer;
    Status: Integer;
    Speed: Integer;
    Low: Integer;
    High: Integer;
    Wait: Integer;
    Count: Integer;
  end;

  TFloorMove = class(TMover)
  public
    Direction: Integer;
    Dest: Integer;
    Speed: Integer;
    Crush: Boolean;
    HasPic: Boolean;
    NewPic: string;
  end;

  TCeilMove = class(TMover)
  public
    Direction: Integer;
    Dest: Integer;
    Speed: Integer;
    Crush: Boolean;
    Kind: Integer;
    TopHeight: Integer;
    BottomHeight: Integer;
  end;

  TLightFx = class
  public
    Sector: TSector;
    Kind: Integer;
    Count: Integer;
    MinLight: Integer;
    MaxLight: Integer;
    DarkTime: Integer;
    BrightTime: Integer;
    MaxTime: Integer;
    MinTime: Integer;
    Direction: Integer;
  end;

  TSwitchBtn = class
  public
    Line: TLine;
    Slot: Integer;
    OldName: string;
    Timer: Integer;
  end;

constructor TSpecials.Create(AWorld: TWorld; APlayer: TPlayer; ARes: TResources);
begin
  inherited Create;
  FWorld := AWorld;
  FPlayer := APlayer;
  FRes := ARes;
  FRnd := 1;
  FThinkers := TObjectList.Create(True);
  FLights := TObjectList.Create(True);
  FButtons := TObjectList.Create(True);
  FScrolls := TObjectList.Create(False);
  SpawnMap;
end;

destructor TSpecials.Destroy;
var
  I: Integer;
  Mv: TMover;
begin
  if FThinkers <> nil then
    for I := 0 to FThinkers.Count - 1 do
    begin
      Mv := TMover(FThinkers[I]);
      if (Mv <> nil) and (Mv.Sector <> nil) then
        Mv.Sector.SpecialData := nil;
    end;
  FThinkers.Free;
  FLights.Free;
  FButtons.Free;
  FScrolls.Free;
  inherited Destroy;
end;

function TSpecials.Rnd: Integer;
begin
  FRnd := FRnd * 1664525 + 1013904223;
  Result := (FRnd shr 24) and 255;
end;

function TSpecials.Swapped(const Name: string): string;
const
  A: array[0..39] of string = (
    'SW1BRCOM', 'SW1BRN1', 'SW1BRN2', 'SW1BRNGN', 'SW1BROWN', 'SW1COMM', 'SW1COMP', 'SW1DIRT',
    'SW1EXIT', 'SW1GRAY', 'SW1GRAY1', 'SW1METAL', 'SW1PIPE', 'SW1SLAD', 'SW1STARG', 'SW1STON1',
    'SW1STON2', 'SW1STONE', 'SW1STRTN', 'SW1BLUE', 'SW1CMT', 'SW1GARG', 'SW1GSTON', 'SW1HOT',
    'SW1LION', 'SW1SATYR', 'SW1SKIN', 'SW1VINE', 'SW1WOOD', 'SW1PANEL', 'SW1ROCK', 'SW1MET2',
    'SW1WDMET', 'SW1BRIK', 'SW1MOD1', 'SW1ZIM', 'SW1STON6', 'SW1TEK', 'SW1MARB', 'SW1SKULL');
  B: array[0..39] of string = (
    'SW2BRCOM', 'SW2BRN1', 'SW2BRN2', 'SW2BRNGN', 'SW2BROWN', 'SW2COMM', 'SW2COMP', 'SW2DIRT',
    'SW2EXIT', 'SW2GRAY', 'SW2GRAY1', 'SW2METAL', 'SW2PIPE', 'SW2SLAD', 'SW2STARG', 'SW2STON1',
    'SW2STON2', 'SW2STONE', 'SW2STRTN', 'SW2BLUE', 'SW2CMT', 'SW2GARG', 'SW2GSTON', 'SW2HOT',
    'SW2LION', 'SW2SATYR', 'SW2SKIN', 'SW2VINE', 'SW2WOOD', 'SW2PANEL', 'SW2ROCK', 'SW2MET2',
    'SW2WDMET', 'SW2BRIK', 'SW2MOD1', 'SW2ZIM', 'SW2STON6', 'SW2TEK', 'SW2MARB', 'SW2SKULL');
var
  I: Integer;
  U: string;
begin
  Result := '';
  U := UpperCase(Trim(Name));
  for I := 0 to 39 do
    if U = A[I] then
      Exit(B[I])
    else if U = B[I] then
      Exit(A[I]);
end;

function OtherSector(Sec: TSector; Ln: TLine): TSector;
begin
  Result := nil;
  if (Sec = nil) or (Ln = nil) then
    Exit;
  if Ln.FrontSector = Sec then
    Result := Ln.BackSector
  else
    Result := Ln.FrontSector;
end;

function TSpecials.LowestCeiling(Sec: TSector): Integer;
var
  I: Integer;
  Other: TSector;
begin
  Result := $7FFFFFFF;
  if Sec = nil then
    Exit(0);
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if (Other <> nil) and (Other <> Sec) and (Other.CeilingHeight < Result) then
      Result := Other.CeilingHeight;
  end;
  if Result = $7FFFFFFF then
    Result := Sec.CeilingHeight;
end;

function TSpecials.LowestFloor(Sec: TSector): Integer;
var
  I: Integer;
  Other: TSector;
begin
  Result := Sec.FloorHeight;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if (Other <> nil) and (Other <> Sec) and (Other.FloorHeight < Result) then
      Result := Other.FloorHeight;
  end;
end;

function TSpecials.HighestFloor(Sec: TSector): Integer;
var
  I: Integer;
  Other: TSector;
begin
  Result := -500 * 65536;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if (Other <> nil) and (Other <> Sec) and (Other.FloorHeight > Result) then
      Result := Other.FloorHeight;
  end;
end;

function TSpecials.NextHighest(Sec: TSector; Current: Integer): Integer;
var
  I, H: Integer;
  Other: TSector;
  Found: Boolean;
begin
  Result := $7FFFFFFF;
  Found := False;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if Other = nil then
      Continue;
    H := Other.FloorHeight;
    if (H > Current) and (H < Result) then
    begin
      Result := H;
      Found := True;
    end;
  end;
  if not Found then
    Result := Current;
end;

function TSpecials.HighestCeiling(Sec: TSector): Integer;
var
  I: Integer;
  Other: TSector;
begin
  Result := Sec.CeilingHeight;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if (Other <> nil) and (Other <> Sec) and (Other.CeilingHeight > Result) then
      Result := Other.CeilingHeight;
  end;
end;

function TSpecials.RaiseDest(Sec: TSector): Integer;
begin
  Result := LowestCeiling(Sec);
  if Result > Sec.CeilingHeight then
    Result := Sec.CeilingHeight;
end;

function TSpecials.MinLight(Sec: TSector; MaxLight: Integer): Integer;
var
  I: Integer;
  Other: TSector;
begin
  Result := MaxLight;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if (Other <> nil) and (Other <> Sec) and (Other.LightLevel < Result) then
      Result := Other.LightLevel;
  end;
end;

function TSpecials.MaxLight(Sec: TSector): Integer;
var
  I: Integer;
  Other: TSector;
begin
  Result := Sec.LightLevel;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Other := OtherSector(Sec, Sec.Lines[I]);
    if (Other <> nil) and (Other <> Sec) and (Other.LightLevel > Result) then
      Result := Other.LightLevel;
  end;
end;

function TSpecials.Settle(Sec: TSector; Crush: Boolean): Boolean;
var
  Sub: TSubsector;
begin
  Result := True;
  if (FPlayer = nil) or (Sec = nil) then
    Exit;
  Sub := FWorld.PointInSubsector(FPlayer.X, FPlayer.Y);
  if (Sub = nil) or (Sub.Sector <> Sec) then
    Exit;
  Result := FPlayer.ClipSector(FWorld, Sec.FloorHeight, Sec.CeilingHeight);
  if Result or not Crush then
    Exit;
  Dec(FPlayer.Health, 10);
end;

function TSpecials.MovePlane(Sec: TSector; Speed, Dest, FloorOrCeil, Direction: Integer; Crush: Boolean): Integer;
var
  Last, NextH: Integer;
  Past: Boolean;
begin
  if FloorOrCeil = 0 then
    Last := Sec.FloorHeight
  else
    Last := Sec.CeilingHeight;
  Past := False;
  if Direction = -1 then
  begin
    if AsI32(Int64(Last) - Speed) < Dest then
    begin
      NextH := Dest;
      Past := True;
    end
    else
      NextH := AsI32(Int64(Last) - Speed);
  end
  else if AsI32(Int64(Last) + Speed) > Dest then
  begin
    NextH := Dest;
    Past := True;
  end
  else
    NextH := AsI32(Int64(Last) + Speed);
  if FloorOrCeil = 0 then
    Sec.FloorHeight := NextH
  else
    Sec.CeilingHeight := NextH;
  if not Settle(Sec, Crush) then
  begin
    if (not Crush) or Past then
    begin
      if FloorOrCeil = 0 then
        Sec.FloorHeight := Last
      else
        Sec.CeilingHeight := Last;
      Settle(Sec, False);
    end;
    if Past then
      Exit(2);
    Exit(1);
  end;
  if Past then
    Result := 2
  else
    Result := 0;
end;

function TSpecials.SpawnDoor(Sec: TSector; Kind: Integer; Reverse: Boolean): Boolean;
var
  Door: TVerticalDoor;
begin
  Result := False;
  if Sec = nil then
    Exit;
  if Sec.SpecialData is TVerticalDoor then
  begin
    Door := TVerticalDoor(Sec.SpecialData);
    if (Kind = VLD_NORMAL) or (Kind = VLD_BLAZERAISE) then
    begin
      if Door.Direction = -1 then
        Door.Direction := 1
      else
        Door.Direction := -1;
      Result := True;
    end;
    Exit;
  end;
  if Sec.SpecialData <> nil then
    Exit;
  Door := TVerticalDoor.Create;
  Door.Sector := Sec;
  Door.Kind := Kind;
  Door.Direction := 1;
  if Reverse or (Kind = VLD_CLOSE) or (Kind = VLD_BLAZECLOSE) or (Kind = VLD_CLOSE30) then
    Door.Direction := -1;
  Door.TopHeight := AsI32(Int64(LowestCeiling(Sec)) - 4 * 65536);
  if Kind = VLD_CLOSE30 then
    Door.TopHeight := Sec.CeilingHeight;
  Door.Speed := VDOORSPEED;
  if Kind >= VLD_BLAZERAISE then
    Door.Speed := VDOORSPEED * 4;
  Door.TopWait := VDOORWAIT;
  Sec.SpecialData := Door;
  FThinkers.Add(Door);
  if Door.Direction > 0 then
  begin
    if Kind >= VLD_BLAZERAISE then
      PlaySfx('bdopn')
    else
      PlaySfx('doropn');
  end
  else if Kind >= VLD_BLAZERAISE then
    PlaySfx('bdcls')
  else
    PlaySfx('dorcls');
  Result := True;
end;

function TSpecials.DoDoor(Ln: TLine; Kind: Integer; Reverse: Boolean): Boolean;
var
  I: Integer;
  Sec: TSector;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag = Ln.Tag) and SpawnDoor(Sec, Kind, Reverse) then
      Result := True;
  end;
end;

procedure TSpecials.ManualDoor(Ln: TLine);
var
  Spec, Kind: Integer;
  Sec: TSector;
begin
  if (Ln = nil) or (Ln.Side1 = nil) then
    Exit;
  Sec := Ln.Side1.Sector;
  if Sec = nil then
    Exit;
  Spec := Ln.Special;
  if (Spec = 26) or (Spec = 32) then
  begin
    if not (FPlayer.Cards[0] or FPlayer.Cards[3]) then
    begin
      FPlayer.Say('precisa da chave azul');
      PlaySfx('oof');
      Exit;
    end;
  end;
  if (Spec = 27) or (Spec = 34) then
  begin
    if not (FPlayer.Cards[1] or FPlayer.Cards[4]) then
    begin
      FPlayer.Say('precisa da chave amarela');
      PlaySfx('oof');
      Exit;
    end;
  end;
  if (Spec = 28) or (Spec = 33) then
  begin
    if not (FPlayer.Cards[2] or FPlayer.Cards[5]) then
    begin
      FPlayer.Say('precisa da chave vermelha');
      PlaySfx('oof');
      Exit;
    end;
  end;
  Kind := VLD_NORMAL;
  if (Spec = 31) or (Spec = 32) or (Spec = 33) or (Spec = 34) then
  begin
    Kind := VLD_OPEN;
    Ln.Special := 0;
  end
  else if Spec = 117 then
    Kind := VLD_BLAZERAISE
  else if Spec = 118 then
  begin
    Kind := VLD_BLAZEOPEN;
    Ln.Special := 0;
  end;
  SpawnDoor(Sec, Kind, False);
end;

function TSpecials.DoPlatDown(Ln: TLine; Blaze: Boolean): Boolean;
var
  I: Integer;
  Sec: TSector;
  Plat: TPlat;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    Plat := TPlat.Create;
    Plat.Sector := Sec;
    Plat.Status := PLAT_DOWN;
    Plat.High := Sec.FloorHeight;
    Plat.Low := LowestFloor(Sec);
    if Plat.Low = Plat.High then
      Plat.Low := AsI32(Int64(Plat.High) - 8 * 65536);
    Plat.Speed := PLATSPEED;
    if Blaze then
      Plat.Speed := PLATSPEED * 8;
    Plat.Wait := PLATWAIT;
    Sec.SpecialData := Plat;
    FThinkers.Add(Plat);
    Result := True;
  end;
end;

function TSpecials.DoPlatUp(Ln: TLine; Amount: Integer): Boolean;
var
  I, High: Integer;
  Sec: TSector;
  Plat: TPlat;
  Pic: string;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  Pic := '';
  if (Ln.Side0 <> nil) and (Ln.Side0.Sector <> nil) then
    Pic := Ln.Side0.Sector.FloorPic;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    if Amount <> 0 then
      High := AsI32(Int64(Sec.FloorHeight) + Amount)
    else
      High := NextHighest(Sec, Sec.FloorHeight);
    if Pic <> '' then
      Sec.FloorPic := Pic;
    Plat := TPlat.Create;
    Plat.Sector := Sec;
    Plat.Status := PLAT_UP;
    Plat.Low := Sec.FloorHeight;
    Plat.High := High;
    Plat.Speed := PLATSPEED div 2;
    Plat.Wait := 0;
    Sec.SpecialData := Plat;
    FThinkers.Add(Plat);
    Result := True;
  end;
end;

function TSpecials.DoPlatAlways(Ln: TLine): Boolean;
var
  I, Low, High: Integer;
  Sec: TSector;
  Plat: TPlat;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    Low := LowestFloor(Sec);
    High := HighestFloor(Sec);
    if Low > Sec.FloorHeight then
      Low := Sec.FloorHeight;
    if High < Sec.FloorHeight then
      High := Sec.FloorHeight;
    Plat := TPlat.Create;
    Plat.Sector := Sec;
    Plat.Kind := 1;
    Plat.Status := Rnd and 1;
    Plat.Speed := PLATSPEED;
    Plat.Low := Low;
    Plat.High := High;
    Plat.Wait := PLATWAIT;
    Sec.SpecialData := Plat;
    FThinkers.Add(Plat);
    Result := True;
  end;
end;

function TSpecials.StopPlat(Ln: TLine): Boolean;
var
  I: Integer;
  Plat: TPlat;
begin
  Result := False;
  if Ln = nil then
    Exit;
  for I := 0 to FThinkers.Count - 1 do
    if FThinkers[I] is TPlat then
    begin
      Plat := TPlat(FThinkers[I]);
      if (not Plat.Dead) and (Plat.Sector <> nil) and (Plat.Sector.Tag = Ln.Tag) then
      begin
        Plat.Status := PLAT_WAITING;
        Plat.Count := $7FFFFFFF;
        Result := True;
      end;
    end;
end;

function TSpecials.FloorDest(Sec: TSector; Kind: Integer): Integer;
begin
  case Kind of
    DEST_HIGHEST: Result := HighestFloor(Sec);
    DEST_NEXT: Result := NextHighest(Sec, Sec.FloorHeight);
    DEST_CEIL: Result := RaiseDest(Sec);
    DEST_CRUSH: Result := AsI32(Int64(RaiseDest(Sec)) - 8 * 65536);
    DEST_DOWN8: Result := AsI32(Int64(Sec.FloorHeight) - 8 * 65536);
    DEST_UP24: Result := AsI32(Int64(Sec.FloorHeight) + 24 * 65536);
    DEST_UP32: Result := AsI32(Int64(Sec.FloorHeight) + 32 * 65536);
    DEST_UP512: Result := AsI32(Int64(Sec.FloorHeight) + 512 * 65536);
  else
    Result := LowestFloor(Sec);
  end;
end;

function TSpecials.DoFloor(Ln: TLine; Kind, Direction, Speed: Integer; Crush: Boolean): Boolean;
var
  I: Integer;
  Sec: TSector;
  Floor: TFloorMove;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  if Speed = 0 then
    Speed := FLOORSPEED;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    Floor := TFloorMove.Create;
    Floor.Sector := Sec;
    Floor.Direction := Direction;
    Floor.Dest := FloorDest(Sec, Kind);
    Floor.Speed := Speed;
    Floor.Crush := Crush;
    Sec.SpecialData := Floor;
    FThinkers.Add(Floor);
    Result := True;
  end;
end;

function TSpecials.DoStairs(Ln: TLine; Step, Speed: Integer): Boolean;
var
  I, Height: Integer;
  Sec, Cur, Nxt, Other: TSector;
  Floor: TFloorMove;
  Texture: string;
  J: Integer;
  Wall: TLine;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    Height := AsI32(Int64(Sec.FloorHeight) + Step);
    Floor := TFloorMove.Create;
    Floor.Sector := Sec;
    Floor.Direction := 1;
    Floor.Dest := Height;
    Floor.Speed := Speed;
    Sec.SpecialData := Floor;
    FThinkers.Add(Floor);
    Result := True;
    Texture := Sec.FloorPic;
    Cur := Sec;
    while True do
    begin
      Nxt := nil;
      for J := 0 to Cur.Lines.Count - 1 do
      begin
        Wall := Cur.Lines[J];
        if (Wall.Flags and ML_TWOSIDED) = 0 then
          Continue;
        Other := OtherSector(Cur, Wall);
        if (Other = nil) or (Other = Cur) or (Other.SpecialData <> nil) then
          Continue;
        if Other.FloorPic <> Texture then
          Continue;
        Nxt := Other;
        Break;
      end;
      if Nxt = nil then
        Break;
      Height := AsI32(Int64(Height) + Step);
      Floor := TFloorMove.Create;
      Floor.Sector := Nxt;
      Floor.Direction := 1;
      Floor.Dest := Height;
      Floor.Speed := Speed;
      Nxt.SpecialData := Floor;
      FThinkers.Add(Floor);
      Cur := Nxt;
    end;
  end;
end;

function StartFloor(Thinkers: TObjectList; Sec: TSector; Dest, Direction, Speed: Integer; const Pic: string; HasPic: Boolean): Boolean;
var
  Floor: TFloorMove;
begin
  Result := False;
  if (Sec = nil) or (Sec.SpecialData <> nil) then
    Exit;
  Floor := TFloorMove.Create;
  Floor.Sector := Sec;
  Floor.Direction := Direction;
  Floor.Dest := Dest;
  Floor.Speed := Speed;
  Floor.HasPic := HasPic;
  Floor.NewPic := Pic;
  Sec.SpecialData := Floor;
  Thinkers.Add(Floor);
  Result := True;
end;

function TSpecials.DoCrusher(Ln: TLine; Kind: Integer): Boolean;
var
  I, Top, Bottom, Speed, Direction, Dest: Integer;
  Sec: TSector;
  Ceil: TCeilMove;
  Crush: Boolean;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    Top := Sec.CeilingHeight;
    Bottom := Sec.FloorHeight;
    Crush := Kind <> CEIL_RAISETOHIGHEST;
    Speed := CEILSPEED;
    if Kind = CEIL_FASTCRUSH then
      Speed := CEILSPEED * 2;
    Direction := -1;
    Dest := Bottom;
    if Kind = CEIL_RAISETOHIGHEST then
    begin
      Dest := HighestCeiling(Sec);
      Direction := 1;
      Crush := False;
    end
    else if Kind <> CEIL_LOWERTOFLOOR then
    begin
      Bottom := AsI32(Int64(Bottom) + 8 * 65536);
      Dest := Bottom;
    end;
    Ceil := TCeilMove.Create;
    Ceil.Sector := Sec;
    Ceil.Direction := Direction;
    Ceil.Dest := Dest;
    Ceil.Speed := Speed;
    Ceil.Crush := Crush;
    Ceil.Kind := Kind;
    Ceil.TopHeight := Top;
    Ceil.BottomHeight := Bottom;
    Sec.SpecialData := Ceil;
    FThinkers.Add(Ceil);
    Result := True;
  end;
end;

function TSpecials.DoDonut(Ln: TLine): Boolean;
var
  I, J: Integer;
  S1, S2, S3, Other: TSector;
  Wall: TLine;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    S1 := FWorld.SectorAt(I);
    if (S1.Tag <> Ln.Tag) or (S1.SpecialData <> nil) or (S1.Lines.Count = 0) then
      Continue;
    S2 := OtherSector(S1, S1.Lines[0]);
    if S2 = nil then
      Continue;
    S3 := nil;
    for J := 0 to S2.Lines.Count - 1 do
    begin
      Wall := S2.Lines[J];
      Other := Wall.BackSector;
      if (Other = nil) or (Other = S1) then
        Continue;
      S3 := Other;
      Break;
    end;
    if S3 = nil then
      Continue;
    if StartFloor(FThinkers, S2, S3.FloorHeight, 1, FLOORSPEED div 2, S3.FloorPic, True) then
      Result := True;
    if StartFloor(FThinkers, S1, S3.FloorHeight, -1, FLOORSPEED div 2, '', False) then
      Result := True;
  end;
end;

function TSpecials.RaiseTexture(Ln: TLine): Boolean;
var
  I, J, MinSize, H: Integer;
  Sec: TSector;
  Wall: TLine;
  Side: TSide;
  Tex: Integer;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) or (FRes = nil) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    MinSize := $7FFFFFFF;
    for J := 0 to Sec.Lines.Count - 1 do
    begin
      Wall := Sec.Lines[J];
      if (Wall.Flags and ML_TWOSIDED) = 0 then
        Continue;
      Side := Wall.Side0;
      if (Side <> nil) and (Side.BottomTexture <> '') and (Side.BottomTexture <> '-') then
      begin
        Tex := FRes.TextureNumForName(Side.BottomTexture);
        H := FRes.TextureHeight(Tex);
        if (H > 0) and (H < MinSize) then
          MinSize := H;
      end;
      Side := Wall.Side1;
      if (Side <> nil) and (Side.BottomTexture <> '') and (Side.BottomTexture <> '-') then
      begin
        Tex := FRes.TextureNumForName(Side.BottomTexture);
        H := FRes.TextureHeight(Tex);
        if (H > 0) and (H < MinSize) then
          MinSize := H;
      end;
    end;
    if MinSize = $7FFFFFFF then
      MinSize := 64 * 65536;
    if StartFloor(FThinkers, Sec, AsI32(Int64(Sec.FloorHeight) + MinSize), 1, FLOORSPEED, '', False) then
      Result := True;
  end;
end;

function TSpecials.LowerChange(Ln: TLine): Boolean;
var
  I, Dest: Integer;
  Sec, Other: TSector;
  Pic: string;
  J: Integer;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    Dest := LowestFloor(Sec);
    Pic := Sec.FloorPic;
    for J := 0 to Sec.Lines.Count - 1 do
    begin
      Other := OtherSector(Sec, Sec.Lines[J]);
      if (Other <> nil) and (Other.FloorHeight = Dest) then
      begin
        Pic := Other.FloorPic;
        Break;
      end;
    end;
    if StartFloor(FThinkers, Sec, Dest, -1, FLOORSPEED, Pic, True) then
      Result := True;
  end;
end;

function TSpecials.LightOn(Ln: TLine; Bright: Integer): Boolean;
var
  I: Integer;
  Sec: TSector;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if Sec.Tag <> Ln.Tag then
      Continue;
    if Bright <> 0 then
      Sec.LightLevel := Bright
    else
      Sec.LightLevel := MaxLight(Sec);
    Result := True;
  end;
end;

function TSpecials.LightsOff(Ln: TLine): Boolean;
var
  I: Integer;
  Sec: TSector;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if Sec.Tag <> Ln.Tag then
      Continue;
    Sec.LightLevel := MinLight(Sec, Sec.LightLevel);
    Result := True;
  end;
end;

procedure AddStrobe(Lights: TObjectList; Sec: TSector; DarkTime: Integer; Synced: Boolean; RndValue: Integer);
var
  Fx: TLightFx;
  MinL: Integer;
begin
  Sec.Special := 0;
  MinL := 0;
  Fx := TLightFx.Create;
  Fx.Sector := Sec;
  Fx.Kind := LIGHT_STROBE;
  Fx.MaxLight := Sec.LightLevel;
  Fx.MinLight := MinL;
  Fx.DarkTime := DarkTime;
  Fx.BrightTime := STROBEBRIGHT;
  if Synced then
    Fx.Count := 1
  else
    Fx.Count := (RndValue and 7) + 1;
  Lights.Add(Fx);
end;

function TSpecials.StartStrobe(Ln: TLine): Boolean;
var
  I: Integer;
  Sec: TSector;
begin
  Result := False;
  if (Ln = nil) or (Ln.Tag = 0) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec.Tag <> Ln.Tag) or (Sec.SpecialData <> nil) then
      Continue;
    AddStrobe(FLights, Sec, SLOWDARK, False, Rnd);
    TLightFx(FLights[FLights.Count - 1]).MinLight := MinLight(Sec, TLightFx(FLights[FLights.Count - 1]).MaxLight);
    if TLightFx(FLights[FLights.Count - 1]).MinLight = TLightFx(FLights[FLights.Count - 1]).MaxLight then
      TLightFx(FLights[FLights.Count - 1]).MinLight := 0;
    Result := True;
  end;
end;

procedure TSpecials.SpawnMap;
var
  I, Spec, MinL: Integer;
  Sec: TSector;
  Fx: TLightFx;
  Door: TVerticalDoor;
  Ln: TLine;
begin
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    Spec := Sec.Special;
    if (Spec = 1) or (Spec = 2) or (Spec = 3) or (Spec = 4) or (Spec = 8) or (Spec = 12) or
      (Spec = 13) or (Spec = 17) then
    begin
      MinL := MinLight(Sec, Sec.LightLevel);
      Fx := TLightFx.Create;
      Fx.Sector := Sec;
      Fx.MaxLight := Sec.LightLevel;
      Fx.MinLight := MinL;
      if Spec = 1 then
      begin
        Fx.Kind := LIGHT_FLASH;
        Fx.MaxTime := 64;
        Fx.MinTime := 7;
        Fx.Count := (Rnd and 64) + 1;
      end
      else if Spec = 8 then
      begin
        Fx.Kind := LIGHT_GLOW;
        Fx.Direction := -1;
      end
      else if Spec = 17 then
      begin
        Fx.Kind := LIGHT_FIRE;
        Fx.MinLight := MinL + 16;
        Fx.Count := 4;
      end
      else
      begin
        Fx.Kind := LIGHT_STROBE;
        Fx.BrightTime := STROBEBRIGHT;
        if (Spec = 2) or (Spec = 4) or (Spec = 13) then
          Fx.DarkTime := FASTDARK
        else
          Fx.DarkTime := SLOWDARK;
        if Fx.MinLight = Fx.MaxLight then
          Fx.MinLight := 0;
        if (Spec = 12) or (Spec = 13) then
          Fx.Count := 1
        else
          Fx.Count := (Rnd and 7) + 1;
      end;
      Sec.Special := 0;
      if Spec = 4 then
        Sec.Special := 4;
      FLights.Add(Fx);
    end
    else if (Spec = 10) or (Spec = 14) then
    begin
      if Sec.SpecialData = nil then
      begin
        Door := TVerticalDoor.Create;
        Door.Sector := Sec;
        Door.Direction := 0;
        Door.Speed := VDOORSPEED;
        Door.TopWait := VDOORWAIT;
        if Spec = 10 then
        begin
          Door.Kind := VLD_CLOSE;
          Door.TopHeight := Sec.CeilingHeight;
          Door.TopCount := 30 * 35;
        end
        else
        begin
          Door.Kind := VLD_RAISEIN5;
          Door.TopHeight := AsI32(Int64(LowestCeiling(Sec)) - 4 * 65536);
          Door.TopCount := 5 * 60 * 35;
        end;
        Sec.Special := 0;
        Sec.SpecialData := Door;
        FThinkers.Add(Door);
      end;
    end;
  end;
  for I := 0 to FWorld.LineCount - 1 do
  begin
    Ln := FWorld.LineAt(I);
    if (Ln <> nil) and (Ln.Special = 48) then
      FScrolls.Add(Ln);
  end;
end;

procedure TSpecials.TickOne(Mv: TObject);
var
  Door: TVerticalDoor;
  Plat: TPlat;
  Floor: TFloorMove;
  Ceil: TCeilMove;
  Dest, Dir, Res: Integer;
  Bounce: Boolean;
begin
  if Mv is TVerticalDoor then
  begin
    Door := TVerticalDoor(Mv);
    if Door.Direction = 0 then
    begin
      Dec(Door.TopCount);
      if Door.TopCount <= 0 then
      begin
        if (Door.Kind = VLD_NORMAL) or (Door.Kind = VLD_BLAZERAISE) or (Door.Kind = VLD_CLOSE) then
        begin
          Door.Direction := -1;
          if Door.Kind >= VLD_BLAZERAISE then
            PlaySfx('bdcls')
          else
            PlaySfx('dorcls');
        end
        else if (Door.Kind = VLD_CLOSE30) or (Door.Kind = VLD_RAISEIN5) then
        begin
          Door.Direction := 1;
          if Door.Kind >= VLD_BLAZERAISE then
            PlaySfx('bdopn')
          else
            PlaySfx('doropn');
        end;
      end;
      Exit;
    end;
    if Door.Direction = 1 then
      Dest := Door.TopHeight
    else
      Dest := Door.Sector.FloorHeight;
    if MovePlane(Door.Sector, Door.Speed, Dest, 1, Door.Direction, False) <> 2 then
      Exit;
    if Door.Direction = 1 then
    begin
      if (Door.Kind = VLD_NORMAL) or (Door.Kind = VLD_BLAZERAISE) then
      begin
        Door.Direction := 0;
        Door.TopCount := Door.TopWait;
      end
      else
        Door.Dead := True;
    end
    else if Door.Kind = VLD_CLOSE30 then
    begin
      Door.Direction := 0;
      Door.TopCount := 35 * 30;
    end
    else
      Door.Dead := True;
    Exit;
  end;
  if Mv is TPlat then
  begin
    Plat := TPlat(Mv);
    if Plat.Status = PLAT_WAITING then
    begin
      Dec(Plat.Count);
      if Plat.Count <= 0 then
      begin
        PlaySfx('pstart');
        if Plat.Sector.FloorHeight <= Plat.Low then
          Plat.Status := PLAT_UP
        else
          Plat.Status := PLAT_DOWN;
      end;
      Exit;
    end;
    if Plat.Status = PLAT_UP then
    begin
      Dest := Plat.High;
      Dir := 1;
    end
    else
    begin
      Dest := Plat.Low;
      Dir := -1;
    end;
    if MovePlane(Plat.Sector, Plat.Speed, Dest, 0, Dir, False) = 2 then
    begin
      PlaySfx('pstop');
      if (Plat.Status = PLAT_DOWN) or (Plat.Kind = 1) then
      begin
        Plat.Status := PLAT_WAITING;
        Plat.Count := Plat.Wait;
      end
      else
        Plat.Dead := True;
    end;
    Exit;
  end;
  if Mv is TFloorMove then
  begin
    Floor := TFloorMove(Mv);
    if MovePlane(Floor.Sector, Floor.Speed, Floor.Dest, 0, Floor.Direction, Floor.Crush) = 2 then
    begin
      if Floor.HasPic then
        Floor.Sector.FloorPic := Floor.NewPic;
      Floor.Dead := True;
    end;
    Exit;
  end;
  if Mv is TCeilMove then
  begin
    Ceil := TCeilMove(Mv);
    Dest := Ceil.Dest;
    if Ceil.Kind <> 0 then
    begin
      if Ceil.Direction = 1 then
        Dest := Ceil.TopHeight
      else
        Dest := Ceil.BottomHeight;
    end;
    Res := MovePlane(Ceil.Sector, Ceil.Speed, Dest, 1, Ceil.Direction, Ceil.Crush);
    Bounce := (Ceil.Kind = CEIL_CRUSHANDRAISE) or (Ceil.Kind = CEIL_FASTCRUSH) or (Ceil.Kind = CEIL_SILENTCRUSH);
    if Res = 2 then
    begin
      if Bounce then
      begin
        if Ceil.Direction = -1 then
        begin
          Ceil.Direction := 1;
          Ceil.Speed := CEILSPEED;
          if Ceil.Kind = CEIL_FASTCRUSH then
            Ceil.Speed := CEILSPEED * 2;
        end
        else
          Ceil.Direction := -1;
      end
      else
        Ceil.Dead := True;
    end
    else if (Res = 1) and Bounce then
      Ceil.Speed := CEILSPEED div 8;
  end;
end;

procedure TSpecials.TickLights;
var
  I, Amount: Integer;
  Fx: TLightFx;
begin
  for I := 0 to FLights.Count - 1 do
  begin
    Fx := TLightFx(FLights[I]);
    if Fx.Kind = LIGHT_GLOW then
    begin
      if Fx.Direction = -1 then
      begin
        Dec(Fx.Sector.LightLevel, GLOWSPEED);
        if Fx.Sector.LightLevel <= Fx.MinLight then
        begin
          Inc(Fx.Sector.LightLevel, GLOWSPEED);
          Fx.Direction := 1;
        end;
      end
      else
      begin
        Inc(Fx.Sector.LightLevel, GLOWSPEED);
        if Fx.Sector.LightLevel >= Fx.MaxLight then
        begin
          Dec(Fx.Sector.LightLevel, GLOWSPEED);
          Fx.Direction := -1;
        end;
      end;
      Continue;
    end;
    Dec(Fx.Count);
    if Fx.Count <> 0 then
      Continue;
    if Fx.Kind = LIGHT_FLASH then
    begin
      if Fx.Sector.LightLevel = Fx.MaxLight then
      begin
        Fx.Sector.LightLevel := Fx.MinLight;
        Fx.Count := (Rnd and Fx.MinTime) + 1;
      end
      else
      begin
        Fx.Sector.LightLevel := Fx.MaxLight;
        Fx.Count := (Rnd and Fx.MaxTime) + 1;
      end;
    end
    else if Fx.Kind = LIGHT_STROBE then
    begin
      if Fx.Sector.LightLevel = Fx.MinLight then
      begin
        Fx.Sector.LightLevel := Fx.MaxLight;
        Fx.Count := Fx.BrightTime;
      end
      else
      begin
        Fx.Sector.LightLevel := Fx.MinLight;
        Fx.Count := Fx.DarkTime;
      end;
    end
    else if Fx.Kind = LIGHT_FIRE then
    begin
      Amount := (Rnd and 3) * 16;
      if Fx.Sector.LightLevel - Amount < Fx.MinLight then
        Fx.Sector.LightLevel := Fx.MinLight
      else
        Fx.Sector.LightLevel := Fx.MaxLight - Amount;
      Fx.Count := 4;
    end;
  end;
end;

procedure TSpecials.ChangeSwitch(Ln: TLine; Again: Boolean);
var
  Side: TSide;
  Swap, Old: string;
  Slot: Integer;
  Btn: TSwitchBtn;
begin
  if Ln = nil then
    Exit;
  if not Again then
    Ln.Special := 0;
  Side := Ln.Side0;
  if Side = nil then
    Exit;
  Slot := -1;
  Old := '';
  Swap := Swapped(Side.TopTexture);
  if Swap <> '' then
  begin
    Slot := 0;
    Old := Side.TopTexture;
    Side.TopTexture := Swap;
  end
  else
  begin
    Swap := Swapped(Side.MidTexture);
    if Swap <> '' then
    begin
      Slot := 1;
      Old := Side.MidTexture;
      Side.MidTexture := Swap;
    end
    else
    begin
      Swap := Swapped(Side.BottomTexture);
      if Swap <> '' then
      begin
        Slot := 2;
        Old := Side.BottomTexture;
        Side.BottomTexture := Swap;
      end;
    end;
  end;
  if (Slot >= 0) and Again then
  begin
    Btn := TSwitchBtn.Create;
    Btn.Line := Ln;
    Btn.Slot := Slot;
    Btn.OldName := Old;
    Btn.Timer := BUTTONTIME;
    FButtons.Add(Btn);
  end;
  if (Ln.Special = 11) and Again then
    PlaySfx('swtchx')
  else
    PlaySfx('swtchn');
end;

procedure TSpecials.UseSpecial(Ln: TLine; Side: Integer);
var
  Spec: Integer;
  Ok, Again: Boolean;
begin
  if (Ln = nil) or (Side <> 0) then
    Exit;
  Spec := Ln.Special;
  if (Spec = 1) or (Spec = 26) or (Spec = 27) or (Spec = 28) or (Spec = 31) or (Spec = 32) or
    (Spec = 33) or (Spec = 34) or (Spec = 117) or (Spec = 118) then
  begin
    ManualDoor(Ln);
    Exit;
  end;
  if (Spec = 99) or (Spec = 133) or (Spec = 134) or (Spec = 135) or (Spec = 136) or (Spec = 137) then
  begin
    if (Spec = 99) or (Spec = 133) then
    begin
      if not (FPlayer.Cards[0] or FPlayer.Cards[3]) then
      begin
        FPlayer.Say('precisa da chave azul');
        PlaySfx('oof');
        Exit;
      end;
    end
    else if (Spec = 134) or (Spec = 135) then
    begin
      if not (FPlayer.Cards[2] or FPlayer.Cards[5]) then
      begin
        FPlayer.Say('precisa da chave vermelha');
        PlaySfx('oof');
        Exit;
      end;
    end
    else if not (FPlayer.Cards[1] or FPlayer.Cards[4]) then
    begin
      FPlayer.Say('precisa da chave amarela');
      PlaySfx('oof');
      Exit;
    end;
    if DoDoor(Ln, VLD_BLAZEOPEN, False) then
      ChangeSwitch(Ln, (Spec = 99) or (Spec = 134) or (Spec = 136));
    Exit;
  end;
  if Spec = 11 then
  begin
    ChangeSwitch(Ln, False);
    ExitRequested := True;
    Exit;
  end;
  if Spec = 51 then
  begin
    ChangeSwitch(Ln, False);
    ExitRequested := True;
    SecretExit := True;
    Exit;
  end;
  Ok := False;
  Again := False;
  case Spec of
    29: Ok := DoDoor(Ln, VLD_NORMAL, False);
    50: Ok := DoDoor(Ln, VLD_CLOSE, False);
    103: Ok := DoDoor(Ln, VLD_OPEN, False);
    111: Ok := DoDoor(Ln, VLD_BLAZERAISE, False);
    112: Ok := DoDoor(Ln, VLD_BLAZEOPEN, False);
    113: Ok := DoDoor(Ln, VLD_BLAZECLOSE, False);
    21: Ok := DoPlatDown(Ln, False);
    122: Ok := DoPlatDown(Ln, True);
    18, 131: Ok := DoFloor(Ln, DEST_NEXT, 1, FLOORSPEED * (1 + 3 * Ord(Spec = 131)), False);
    23: Ok := DoFloor(Ln, DEST_LOWEST, -1, 0, False);
    71: Ok := DoFloor(Ln, DEST_HIGHEST, -1, 0, False);
    101: Ok := DoFloor(Ln, DEST_CEIL, 1, 0, False);
    102: Ok := DoFloor(Ln, DEST_HIGHEST, -1, 0, False);
    7: Ok := DoStairs(Ln, 8 * 65536, FLOORSPEED div 4);
    127: Ok := DoStairs(Ln, 16 * 65536, FLOORSPEED * 4);
    41: Ok := DoCrusher(Ln, CEIL_LOWERTOFLOOR);
    49: Ok := DoCrusher(Ln, CEIL_CRUSHANDRAISE);
    9: Ok := DoDonut(Ln);
    14: Ok := DoPlatUp(Ln, 32 * 65536);
    15: Ok := DoPlatUp(Ln, 24 * 65536);
    20: Ok := DoPlatUp(Ln, 0);
    55: Ok := DoFloor(Ln, DEST_CRUSH, 1, 0, True);
    140: Ok := DoFloor(Ln, DEST_UP512, 1, 0, False);
    42: begin Ok := DoDoor(Ln, VLD_CLOSE, False); Again := True; end;
    61: begin Ok := DoDoor(Ln, VLD_OPEN, False); Again := True; end;
    63: begin Ok := DoDoor(Ln, VLD_NORMAL, False); Again := True; end;
    114: begin Ok := DoDoor(Ln, VLD_BLAZERAISE, False); Again := True; end;
    115: begin Ok := DoDoor(Ln, VLD_BLAZEOPEN, False); Again := True; end;
    116: begin Ok := DoDoor(Ln, VLD_BLAZECLOSE, False); Again := True; end;
    62: begin Ok := DoPlatDown(Ln, False); Again := True; end;
    120, 123: begin Ok := DoPlatDown(Ln, True); Again := True; end;
    45: begin Ok := DoFloor(Ln, DEST_HIGHEST, -1, 0, False); Again := True; end;
    60: begin Ok := DoFloor(Ln, DEST_LOWEST, -1, 0, False); Again := True; end;
    64: begin Ok := DoFloor(Ln, DEST_CEIL, 1, 0, False); Again := True; end;
    65: begin Ok := DoFloor(Ln, DEST_CRUSH, 1, 0, True); Again := True; end;
    66: begin Ok := DoPlatUp(Ln, 24 * 65536); Again := True; end;
    67: begin Ok := DoPlatUp(Ln, 32 * 65536); Again := True; end;
    68: begin Ok := DoPlatUp(Ln, 0); Again := True; end;
    69, 132: begin Ok := DoFloor(Ln, DEST_NEXT, 1, FLOORSPEED * (1 + 3 * Ord(Spec = 132)), False); Again := True; end;
    70: begin Ok := DoFloor(Ln, DEST_HIGHEST, -1, FLOORSPEED * 4, False); Again := True; end;
    43: begin Ok := DoCrusher(Ln, CEIL_LOWERTOFLOOR); Again := True; end;
    138: begin Ok := LightOn(Ln, 255); Again := True; end;
    139: begin Ok := LightOn(Ln, 35); Again := True; end;
  end;
  if Ok then
    ChangeSwitch(Ln, Again);
end;

procedure TSpecials.CrossSpecial(Ln: TLine; Side: Integer);
var
  Spec, Once: Integer;
begin
  if Ln = nil then
    Exit;
  Spec := Ln.Special;
  if Spec = 52 then
  begin
    ExitRequested := True;
    Exit;
  end;
  if Spec = 124 then
  begin
    ExitRequested := True;
    SecretExit := True;
    Exit;
  end;
  Once := 0;
  case Spec of
    2: begin DoDoor(Ln, VLD_OPEN, False); Once := 1; end;
    3: begin DoDoor(Ln, VLD_CLOSE, False); Once := 1; end;
    4: begin DoDoor(Ln, VLD_NORMAL, False); Once := 1; end;
    5: begin DoFloor(Ln, DEST_CEIL, 1, 0, False); Once := 1; end;
    6: begin DoCrusher(Ln, CEIL_FASTCRUSH); Once := 1; end;
    8: begin DoStairs(Ln, 8 * 65536, FLOORSPEED div 4); Once := 1; end;
    10: begin DoPlatDown(Ln, False); Once := 1; end;
    12: begin LightOn(Ln, 0); Once := 1; end;
    13: begin LightOn(Ln, 255); Once := 1; end;
    16: begin DoDoor(Ln, VLD_CLOSE30, True); Once := 1; end;
    17: begin StartStrobe(Ln); Once := 1; end;
    19: begin DoFloor(Ln, DEST_HIGHEST, -1, 0, False); Once := 1; end;
    22: begin DoPlatUp(Ln, 0); Once := 1; end;
    25: begin DoCrusher(Ln, CEIL_CRUSHANDRAISE); Once := 1; end;
    30: begin RaiseTexture(Ln); Once := 1; end;
    35: begin LightOn(Ln, 35); Once := 1; end;
    36: begin DoFloor(Ln, DEST_HIGHEST, -1, FLOORSPEED * 4, False); Once := 1; end;
    37: begin LowerChange(Ln); Once := 1; end;
    38: begin DoFloor(Ln, DEST_LOWEST, -1, 0, False); Once := 1; end;
    39: begin Teleport(Ln, Side); Once := 1; end;
    40:
      begin
        DoCrusher(Ln, CEIL_RAISETOHIGHEST);
        DoFloor(Ln, DEST_LOWEST, -1, 0, False);
        Once := 1;
      end;
    44: begin DoCrusher(Ln, CEIL_LOWERANDCRUSH); Once := 1; end;
    53: begin DoPlatAlways(Ln); Once := 1; end;
    54, 57: begin StopPlat(Ln); Once := 1; end;
    56: begin DoFloor(Ln, DEST_CRUSH, 1, 0, True); Once := 1; end;
    58, 59: begin DoFloor(Ln, DEST_UP24, 1, 0, False); Once := 1; end;
    100: begin DoStairs(Ln, 16 * 65536, FLOORSPEED * 4); Once := 1; end;
    104: begin LightsOff(Ln); Once := 1; end;
    108: begin DoDoor(Ln, VLD_BLAZERAISE, False); Once := 1; end;
    109: begin DoDoor(Ln, VLD_BLAZEOPEN, False); Once := 1; end;
    110: begin DoDoor(Ln, VLD_BLAZECLOSE, False); Once := 1; end;
    119, 130: begin DoFloor(Ln, DEST_NEXT, 1, FLOORSPEED * (1 + 3 * Ord(Spec = 130)), False); Once := 1; end;
    121: begin DoPlatDown(Ln, True); Once := 1; end;
    125: Once := 1;
    141: begin DoCrusher(Ln, CEIL_SILENTCRUSH); Once := 1; end;
    72: DoCrusher(Ln, CEIL_LOWERANDCRUSH);
    73: DoCrusher(Ln, CEIL_CRUSHANDRAISE);
    74, 89: StopPlat(Ln);
    75: DoDoor(Ln, VLD_CLOSE, False);
    76: DoDoor(Ln, VLD_CLOSE30, True);
    77: DoCrusher(Ln, CEIL_FASTCRUSH);
    79: LightOn(Ln, 35);
    80: LightOn(Ln, 0);
    81: LightOn(Ln, 255);
    82: DoFloor(Ln, DEST_LOWEST, -1, 0, False);
    83: DoFloor(Ln, DEST_HIGHEST, -1, 0, False);
    84: LowerChange(Ln);
    86: DoDoor(Ln, VLD_OPEN, False);
    87: DoPlatAlways(Ln);
    88: DoPlatDown(Ln, False);
    90: DoDoor(Ln, VLD_NORMAL, False);
    91: DoFloor(Ln, DEST_CEIL, 1, 0, False);
    92, 93: DoFloor(Ln, DEST_UP24, 1, 0, False);
    94: DoFloor(Ln, DEST_CRUSH, 1, 0, True);
    95: DoPlatUp(Ln, 0);
    96: RaiseTexture(Ln);
    97: Teleport(Ln, Side);
    98: DoFloor(Ln, DEST_HIGHEST, -1, FLOORSPEED * 4, False);
    105: DoDoor(Ln, VLD_BLAZERAISE, False);
    106: DoDoor(Ln, VLD_BLAZEOPEN, False);
    107: DoDoor(Ln, VLD_BLAZECLOSE, False);
    120: DoPlatDown(Ln, True);
    128, 129: DoFloor(Ln, DEST_NEXT, 1, FLOORSPEED * (1 + 3 * Ord(Spec = 129)), False);
  end;
  if Once = 1 then
    Ln.Special := 0;
end;

procedure TSpecials.MonsterUse(Ln: TLine);
begin
  UseSpecial(Ln, 0);
end;

procedure TSpecials.Shoot(Ln: TLine);
begin
  if Ln = nil then
    Exit;
  if Ln.Special = 24 then
  begin
    if DoFloor(Ln, DEST_CEIL, 1, 0, False) then
      ChangeSwitch(Ln, False);
  end
  else if Ln.Special = 46 then
  begin
    DoDoor(Ln, VLD_OPEN, False);
    ChangeSwitch(Ln, True);
  end
  else if Ln.Special = 47 then
  begin
    if DoPlatUp(Ln, 0) then
      ChangeSwitch(Ln, False);
  end;
end;

procedure TSpecials.Teleport(Ln: TLine; Side: Integer);
var
  I, J: Integer;
  Sec: TSector;
  Th: TMapThing;
  Sub: TSubsector;
begin
  if (Ln = nil) or (Side = 1) or (FPlayer = nil) then
    Exit;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if Sec.Tag <> Ln.Tag then
      Continue;
    for J := 0 to FWorld.ThingCount - 1 do
    begin
      Th := FWorld.ThingAt(J);
      if Th.ThingType <> 14 then
        Continue;
      Sub := FWorld.PointInSubsector(Th.X * 65536, Th.Y * 65536);
      if (Sub = nil) or (Sub.Sector <> Sec) then
        Continue;
      FPlayer.Place(Th.X * 65536, Th.Y * 65536, Sec.FloorHeight, Sec.CeilingHeight,
        AsU32(Int64(Th.Angle) * $40000000 div 90));
      PlaySfx('telept');
      Exit;
    end;
  end;
end;

procedure TSpecials.TouchKeys;
var
  I, Px, Py, Card: Integer;
  Th: TMapThing;
  Name: string;
begin
  if FPlayer = nil then
    Exit;
  Px := SHar32(FPlayer.X, 16);
  Py := SHar32(FPlayer.Y, 16);
  for I := 0 to FWorld.ThingCount - 1 do
  begin
    Th := FWorld.ThingAt(I);
    if not FPlayer.Accepts(Th.Options) then
      Continue;
    Card := -1;
    Name := '';
    case Th.ThingType of
      5: begin Card := 0; Name := 'chave azul'; end;
      6: begin Card := 1; Name := 'chave amarela'; end;
      13: begin Card := 2; Name := 'chave vermelha'; end;
      40: begin Card := 3; Name := 'caveira azul'; end;
      39: begin Card := 4; Name := 'caveira amarela'; end;
      38: begin Card := 5; Name := 'caveira vermelha'; end;
    end;
    if Card < 0 then
      Continue;
    if (Abs(Th.X - Px) >= 36) or (Abs(Th.Y - Py) >= 36) then
      Continue;
    FPlayer.Cards[Card] := True;
    Th.ThingType := 0;
    Th.FrameUse := -2;
    FPlayer.Say('pegou a ' + Name);
    PlaySfx('itemup');
  end;
end;

procedure TSpecials.TouchItems;
var
  I, Px, Py: Integer;
  Th: TMapThing;
  Take: Boolean;
  Snd, Msg: string;

  procedure Give(var Pool: Integer; Max, Amount: Integer);
  begin
    if Pool >= Max then
      Exit;
    Pool := Pool + Amount;
    if Pool > Max then
      Pool := Max;
  end;

begin
  if FPlayer = nil then
    Exit;
  Px := SHar32(FPlayer.X, 16);
  Py := SHar32(FPlayer.Y, 16);
  for I := 0 to FWorld.ThingCount - 1 do
  begin
    Th := FWorld.ThingAt(I);
    if (Th.FrameUse = -2) or not FPlayer.Accepts(Th.Options) then
      Continue;
    if (Abs(Th.X - Px) >= 36) or (Abs(Th.Y - Py) >= 36) then
      Continue;
    Take := True;
    Snd := 'itemup';
    Msg := '';
    case Th.ThingType of
      2011:
        if FPlayer.Health >= 100 then
          Take := False
        else
        begin
          FPlayer.Health := FPlayer.Health + 10;
          if FPlayer.Health > 100 then
            FPlayer.Health := 100;
          Msg := 'pegou um estimulante';
        end;
      2012:
        if FPlayer.Health >= 100 then
          Take := False
        else
        begin
          FPlayer.Health := FPlayer.Health + 25;
          if FPlayer.Health > 100 then
            FPlayer.Health := 100;
          Msg := 'pegou um kit medico';
        end;
      2014:
        if FPlayer.Health >= 200 then
          Take := False
        else
        begin
          Inc(FPlayer.Health);
          Msg := 'bonus de vida';
        end;
      2015:
        if FPlayer.Armor >= 200 then
          Take := False
        else
        begin
          Inc(FPlayer.Armor);
          if FPlayer.ArmorType = 0 then
            FPlayer.ArmorType := 1;
          Msg := 'bonus de armadura';
        end;
      2018:
        if FPlayer.Armor >= 100 then
          Take := False
        else
        begin
          FPlayer.Armor := 100;
          FPlayer.ArmorType := 1;
          Msg := 'pegou a armadura';
        end;
      2019:
        if FPlayer.Armor >= 200 then
          Take := False
        else
        begin
          FPlayer.Armor := 200;
          FPlayer.ArmorType := 2;
          Msg := 'pegou a mega armadura';
        end;
      2013:
        begin
          FPlayer.Health := FPlayer.Health + 100;
          if FPlayer.Health > 200 then
            FPlayer.Health := 200;
          Msg := 'Supercharge!';
        end;
      83:
        begin
          FPlayer.Health := 200;
          FPlayer.Armor := 200;
          FPlayer.ArmorType := 2;
          Msg := 'MegaSphere!';
        end;
      2007, 2048:
        if FPlayer.Ammo >= FPlayer.MaxClip then
          Take := False
        else
        begin
          if Th.ThingType = 2007 then
            Give(FPlayer.Ammo, FPlayer.MaxClip, 10)
          else
            Give(FPlayer.Ammo, FPlayer.MaxClip, 50);
          Msg := 'pegou municao';
        end;
      2008, 2049:
        if FPlayer.Shells >= FPlayer.MaxShell then
          Take := False
        else
        begin
          if Th.ThingType = 2008 then
            Give(FPlayer.Shells, FPlayer.MaxShell, 4)
          else
            Give(FPlayer.Shells, FPlayer.MaxShell, 20);
          Msg := 'pegou municao';
        end;
      2010, 2046:
        if FPlayer.Rockets >= FPlayer.MaxRocket then
          Take := False
        else
        begin
          if Th.ThingType = 2010 then
            Give(FPlayer.Rockets, FPlayer.MaxRocket, 1)
          else
            Give(FPlayer.Rockets, FPlayer.MaxRocket, 5);
          Msg := 'pegou municao';
        end;
      2047, 17:
        if FPlayer.Cells >= FPlayer.MaxCell then
          Take := False
        else
        begin
          if Th.ThingType = 2047 then
            Give(FPlayer.Cells, FPlayer.MaxCell, 20)
          else
            Give(FPlayer.Cells, FPlayer.MaxCell, 100);
          Msg := 'pegou municao';
        end;
      8:
        begin
          if FPlayer.MaxClip < 400 then
          begin
            FPlayer.MaxClip := FPlayer.MaxClip * 2;
            FPlayer.MaxShell := FPlayer.MaxShell * 2;
            FPlayer.MaxRocket := FPlayer.MaxRocket * 2;
            FPlayer.MaxCell := FPlayer.MaxCell * 2;
          end;
          Give(FPlayer.Ammo, FPlayer.MaxClip, 10);
          Give(FPlayer.Shells, FPlayer.MaxShell, 4);
          Give(FPlayer.Rockets, FPlayer.MaxRocket, 1);
          Give(FPlayer.Cells, FPlayer.MaxCell, 20);
          Msg := 'pegou a mochila';
        end;
      2001, 82:
        begin
          FPlayer.Owned[2] := True;
          Give(FPlayer.Shells, FPlayer.MaxShell, 4);
          FPlayer.SelectWeapon(2);
          Msg := 'pegou a escopeta';
          Snd := 'wpnup';
        end;
      2002:
        begin
          FPlayer.Owned[3] := True;
          Give(FPlayer.Ammo, FPlayer.MaxClip, 10);
          FPlayer.SelectWeapon(3);
          Msg := 'pegou a metralhadora';
          Snd := 'wpnup';
        end;
      2003:
        begin
          FPlayer.Owned[4] := True;
          Give(FPlayer.Rockets, FPlayer.MaxRocket, 1);
          FPlayer.SelectWeapon(4);
          Msg := 'pegou o lancador';
          Snd := 'wpnup';
        end;
      2004:
        begin
          FPlayer.Owned[5] := True;
          Give(FPlayer.Cells, FPlayer.MaxCell, 20);
          FPlayer.SelectWeapon(5);
          Msg := 'pegou o rifle de plasma';
          Snd := 'wpnup';
        end;
      2006:
        begin
          FPlayer.Owned[6] := True;
          Give(FPlayer.Cells, FPlayer.MaxCell, 40);
          FPlayer.SelectWeapon(6);
          Msg := 'pegou a BFG';
          Snd := 'wpnup';
        end;
      2005:
        begin
          FPlayer.Owned[0] := True;
          FPlayer.SelectWeapon(0);
          Msg := 'pegou a motosserra';
          Snd := 'wpnup';
        end;
      2023:
        begin
          if FPlayer.Health < 100 then
            FPlayer.Health := 100;
          FPlayer.SelectWeapon(0);
          Msg := 'Berserk!';
          Snd := 'getpow';
        end;
      2022, 2024, 2025, 2026, 2045:
        begin
          Msg := 'pegou um item';
          Snd := 'getpow';
        end;
    else
      Continue;
    end;
    if not Take then
      Continue;
    if Msg <> '' then
      FPlayer.Say(Msg);
    FPlayer.BonusCount := FPlayer.BonusCount + 6;
    if FPlayer.BonusCount > 32 then
      FPlayer.BonusCount := 32;
    Th.ThingType := 0;
    Th.FrameUse := -2;
    PlaySfx(Snd);
  end;
end;

function TSpecials.HitLine(X1, Y1, X2, Y2: Integer; Ln: TLine; out Along: Integer): Boolean;
var
  Ax, Ay, Bx, By, Cx, Cy, Dx, Dy, Den, Tee, Uu: Int64;
begin
  Result := False;
  Along := 0;
  if (Ln = nil) or (Ln.V1 = nil) or (Ln.V2 = nil) then
    Exit;
  Ax := SHar32(X1, 16);
  Ay := SHar32(Y1, 16);
  Bx := SHar32(X2, 16);
  By := SHar32(Y2, 16);
  Cx := SHar32(Ln.V1.X, 16);
  Cy := SHar32(Ln.V1.Y, 16);
  Dx := SHar32(Ln.V2.X, 16);
  Dy := SHar32(Ln.V2.Y, 16);
  Den := (Bx - Ax) * (Dy - Cy) - (By - Ay) * (Dx - Cx);
  if Den = 0 then
    Exit;
  Tee := (Cx - Ax) * (Dy - Cy) - (Cy - Ay) * (Dx - Cx);
  Uu := (Cx - Ax) * (By - Ay) - (Cy - Ay) * (Bx - Ax);
  if Den < 0 then
  begin
    Den := -Den;
    Tee := -Tee;
    Uu := -Uu;
  end;
  if (Tee < 0) or (Tee > Den) or (Uu < 0) or (Uu > Den) then
    Exit;
  Along := Integer((Tee * 65536) div Den);
  Result := True;
end;

function TSpecials.SideOf(Px, Py: Integer; Ln: TLine): Integer;
var
  Dx, Dy: Integer;
begin
  Result := 0;
  if (Ln = nil) or (Ln.V1 = nil) then
    Exit;
  if Ln.Dx = 0 then
  begin
    if Px <= Ln.V1.X then
      Result := 1
    else
      Result := 0;
    if Ln.Dy <= 0 then
      Result := 1 - Result;
    Exit;
  end;
  if Ln.Dy = 0 then
  begin
    if Py <= Ln.V1.Y then
      Result := 1
    else
      Result := 0;
    if Ln.Dx >= 0 then
      Result := 1 - Result;
    Exit;
  end;
  Dx := AsI32(Int64(Px) - Ln.V1.X);
  Dy := AsI32(Int64(Py) - Ln.V1.Y);
  if FixedMul(SHar32(Ln.Dy, 16), Dx) > FixedMul(Dy, SHar32(Ln.Dx, 16)) then
    Result := 0
  else
    Result := 1;
end;

function TSpecials.Passage(Ln: TLine): Integer;
var
  OpenTop, OpenBot: Integer;
begin
  Result := 0;
  if (Ln = nil) or (Ln.FrontSector = nil) or (Ln.BackSector = nil) then
    Exit;
  if Ln.FrontSector.CeilingHeight < Ln.BackSector.CeilingHeight then
    OpenTop := Ln.FrontSector.CeilingHeight
  else
    OpenTop := Ln.BackSector.CeilingHeight;
  if Ln.FrontSector.FloorHeight > Ln.BackSector.FloorHeight then
    OpenBot := Ln.FrontSector.FloorHeight
  else
    OpenBot := Ln.BackSector.FloorHeight;
  Result := AsI32(Int64(OpenTop) - OpenBot);
end;

procedure TSpecials.Use;
var
  X2, Y2, I, Along, Best, Last: Integer;
  Ln, Hit: TLine;
begin
  if (FPlayer = nil) or (FWorld = nil) then
    Exit;
  X2 := AsI32(Int64(FPlayer.X) + Int64(64) * FineCos(FPlayer.Angle));
  Y2 := AsI32(Int64(FPlayer.Y) + Int64(64) * FineSin(FPlayer.Angle));
  Last := -1;
  repeat
    Best := 65536 + 1;
    Hit := nil;
    for I := 0 to FWorld.LineCount - 1 do
    begin
      Ln := FWorld.LineAt(I);
      if not HitLine(FPlayer.X, FPlayer.Y, X2, Y2, Ln, Along) then
        Continue;
      if (Along <= Last) or (Along >= Best) then
        Continue;
      Best := Along;
      Hit := Ln;
    end;
    if Hit = nil then
      Break;
    Last := Best;
    if Hit.Special = 0 then
    begin
      if Passage(Hit) <= 0 then
        Break;
      Continue;
    end;
    UseSpecial(Hit, SideOf(FPlayer.X, FPlayer.Y, Hit));
    Break;
  until False;
end;

procedure TSpecials.Cross(OldX, OldY: Integer);
var
  I, Along, Side: Integer;
  Ln: TLine;
begin
  if (FPlayer = nil) or (FWorld = nil) then
    Exit;
  if (OldX = FPlayer.X) and (OldY = FPlayer.Y) then
    Exit;
  for I := 0 to FWorld.LineCount - 1 do
  begin
    Ln := FWorld.LineAt(I);
    if (Ln = nil) or (Ln.Special = 0) then
      Continue;
    if not HitLine(OldX, OldY, FPlayer.X, FPlayer.Y, Ln, Along) then
      Continue;
    if (Along <= 0) or (Along >= 65536) then
      Continue;
    Side := SideOf(OldX, OldY, Ln);
    if Side = SideOf(FPlayer.X, FPlayer.Y, Ln) then
      Continue;
    CrossSpecial(Ln, Side);
  end;
end;

procedure TSpecials.Tick;
var
  I: Integer;
  Mv: TMover;
  Btn: TSwitchBtn;
  Side: TSide;
  Ln: TLine;
begin
  TickLights;
  for I := 0 to FScrolls.Count - 1 do
  begin
    Ln := TLine(FScrolls[I]);
    if (Ln <> nil) and (Ln.Side0 <> nil) then
      Ln.Side0.TextureOffset := AsI32(Int64(Ln.Side0.TextureOffset) + 65536);
  end;
  for I := FThinkers.Count - 1 downto 0 do
  begin
    Mv := TMover(FThinkers[I]);
    if not Mv.Dead then
      TickOne(Mv);
    if Mv.Dead then
    begin
      if Mv.Sector <> nil then
        Mv.Sector.SpecialData := nil;
      FThinkers.Delete(I);
    end;
  end;
  for I := FButtons.Count - 1 downto 0 do
  begin
    Btn := TSwitchBtn(FButtons[I]);
    Dec(Btn.Timer);
    if Btn.Timer > 0 then
      Continue;
    if (Btn.Line <> nil) and (Btn.Line.Side0 <> nil) then
    begin
      Side := Btn.Line.Side0;
      if Btn.Slot = 0 then
        Side.TopTexture := Btn.OldName
      else if Btn.Slot = 1 then
        Side.MidTexture := Btn.OldName
      else
        Side.BottomTexture := Btn.OldName;
    end;
    FButtons.Delete(I);
  end;
  TouchKeys;
  TouchItems;
end;

end.
