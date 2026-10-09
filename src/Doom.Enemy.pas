unit Doom.Enemy;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Monstros olham, perseguem, atacam e soltam misseis, como doom/enemy.py.
}

interface

uses
  Doom.World, Doom.Player, Doom.Specials;

type
  TEnemies = class
  public
    constructor Create(AWorld: TWorld; APlayer: TPlayer; ASpecials: TSpecials; NoMonsters: Boolean = False);
    destructor Destroy; override;
    procedure Tick(Heard: Boolean);
  private
    FWorld: TWorld;
    FNoMonsters: Boolean;
    FPlayer: TPlayer;
    FSpecials: TSpecials;
    FRnd: Cardinal;
    FTime: Integer;
    FGen: Integer;
    FUsed: Boolean;
    FVisit: array of Integer;
    FBlocks: array of Integer;
    function Rnd: Integer;
    procedure Hear(Th: TMapThing; const Name: string);
    function Profile(Ed: Integer; out Speed, Kind: Integer; out Floats: Boolean): Boolean;
    procedure Arm;
    function PlayerX: Integer;
    function PlayerY: Integer;
    function Degrees(X1, Y1, X2, Y2: Integer): Integer;
    function BamOf(Deg: Integer): Cardinal;
    function Dist(X1, Y1, X2, Y2: Integer): Integer;
    function Behind(Face, Target: Integer): Boolean;
    function Sight(X1, Y1, X2, Y2: Integer): Boolean;
    function Sees(Th: TMapThing): Boolean;
    function HitLine(X1, Y1, X2, Y2: Integer; Ln: TLine; out Along: Integer): Boolean;
    function Blocked(Th: TMapThing; NX, NY: Integer; out Hit: TLine): Boolean;
    function TryStep(Th: TMapThing; NX, NY: Integer): Boolean;
    procedure Wake(Th: TMapThing);
    procedure Look(Th: TMapThing; Heard: Boolean);
    procedure Idle(Th: TMapThing);
    procedure Chase(Th: TMapThing);
    procedure Attack(Th: TMapThing);
    procedure FlySkull(Th: TMapThing);
    procedure NewDir(Th: TMapThing);
    procedure Hitscan(Th: TMapThing; Pellets: Integer);
    procedure SpawnBall(Th: TMapThing; const Sprite: string; Speed, Dmg, Spread: Integer);
    procedure TickMissile(Th: TMapThing);
    procedure AdvanceDeath(Th: TMapThing);
    procedure Alert;
    procedure Flood(Sec: TSector; Blocks: Integer);
  end;

implementation

uses
  System.Math, Doom.Compat, Doom.Tables, Doom.Sound;

const
  XS: array[0..7] of Integer = (65536, 47000, 0, -47000, -65536, -47000, 0, 47000);
  YS: array[0..7] of Integer = (0, 47000, 65536, 47000, 0, -47000, -65536, -47000);
  OPP: array[0..8] of Integer = (4, 5, 6, 7, 0, 1, 2, 3, 8);
  FACE: array[0..7] of Integer = (0, 45, 90, 135, 180, 225, 270, 315);
  NODIR = 8;

constructor TEnemies.Create(AWorld: TWorld; APlayer: TPlayer; ASpecials: TSpecials; NoMonsters: Boolean);
begin
  inherited Create;
  FWorld := AWorld;
  FPlayer := APlayer;
  FSpecials := ASpecials;
  FNoMonsters := NoMonsters;
  FRnd := 1;
  Arm;
end;

destructor TEnemies.Destroy;
begin
  inherited Destroy;
end;

function TEnemies.Rnd: Integer;
begin
  FRnd := FRnd * 1664525 + 1013904223;
  Result := (FRnd shr 24) and 255;
end;

procedure TEnemies.Hear(Th: TMapThing; const Name: string);
begin
  if (Th = nil) or (FPlayer = nil) or (Name = '') then
    Exit;
  PlaySfxAt(Name, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), FPlayer.X, FPlayer.Y);
end;

function TEnemies.Profile(Ed: Integer; out Speed, Kind: Integer; out Floats: Boolean): Boolean;
begin
  Result := True;
  Floats := False;
  Speed := 8;
  Kind := 0;
  case Ed of
    3004, 84: Kind := 0;
    9: Kind := 1;
    65: Kind := 2;
    3001: Kind := 3;
    3002: begin Kind := 4; Speed := 10; end;
    58: begin Kind := 4; Speed := 10; Floats := False; end;
    3003, 69: Kind := 5;
    3005: begin Kind := 6; Floats := True; end;
    3006: begin Kind := 7; Floats := True; end;
    16: begin Kind := 8; Speed := 16; end;
    7: begin Kind := 9; Speed := 12; end;
    68: Kind := 2;
    66: Kind := 5;
    67: Kind := 10;
    64: begin Kind := 0; Speed := 15; end;
    71: begin Kind := 6; Floats := True; end;
  else
    Result := False;
  end;
end;

procedure TEnemies.Arm;
var
  I, Speed, Kind: Integer;
  Th: TMapThing;
  Floats: Boolean;
begin
  if FWorld = nil then
    Exit;
  for I := 0 to FWorld.ThingCount - 1 do
  begin
    Th := FWorld.ThingAt(I);
    if (Th = nil) or Th.Dead or (Th.Health <= 0) then
      Continue;
    if (FPlayer <> nil) and not FPlayer.Accepts(Th.Options) then
      Continue;
    if not Profile(Th.ThingType, Speed, Kind, Floats) then
      Continue;
    if FNoMonsters then
    begin
      Th.FrameUse := -2;
      Th.Dead := True;
      Th.Health := 0;
      Th.Ai := 0;
      Continue;
    end;
    Th.Ai := 1;
    Th.Speed := Speed;
    Th.Kind := Kind;
    Th.Floats := Floats;
    Th.MoveDir := NODIR;
    Th.Ambush := (Th.Options and 8) <> 0;
    Th.FrameUse := 0;
    if Th.ThingType = 67 then
      Th.Tics := 15
    else
      Th.Tics := 10;
    Th.Tics := 1 + (Rnd mod Th.Tics);
  end;
end;

function TEnemies.PlayerX: Integer;
begin
  if FPlayer = nil then
    Result := 0
  else
    Result := SHar32(FPlayer.X, 16);
end;

function TEnemies.PlayerY: Integer;
begin
  if FPlayer = nil then
    Result := 0
  else
    Result := SHar32(FPlayer.Y, 16);
end;

function TEnemies.Degrees(X1, Y1, X2, Y2: Integer): Integer;
begin
  Result := Round(ArcTan2(Y2 - Y1, X2 - X1) * (180 / Pi));
  if Result < 0 then
    Inc(Result, 360);
end;

function TEnemies.BamOf(Deg: Integer): Cardinal;
begin
  Result := AsU32(Int64(Deg) * $40000000 div 90);
end;

function TEnemies.Dist(X1, Y1, X2, Y2: Integer): Integer;
var
  Dx, Dy: Integer;
begin
  Dx := Abs(X2 - X1);
  Dy := Abs(Y2 - Y1);
  if Dx < Dy then
    Result := Dy + Dx div 2
  else
    Result := Dx + Dy div 2;
end;

function TEnemies.Behind(Face, Target: Integer): Boolean;
var
  D: Integer;
begin
  D := (Target - Face) mod 360;
  if D < 0 then
    Inc(D, 360);
  Result := (D > 90) and (D < 270);
end;

function TEnemies.HitLine(X1, Y1, X2, Y2: Integer; Ln: TLine; out Along: Integer): Boolean;
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

function MissileBlocked(Ln: TLine; AtZ: Integer): Boolean;
var
  Top, Bot: Integer;
begin
  Result := True;
  if (Ln = nil) or (Ln.FrontSector = nil) or (Ln.BackSector = nil) then
    Exit;
  if Ln.FrontSector.CeilingHeight < Ln.BackSector.CeilingHeight then
    Top := Ln.FrontSector.CeilingHeight
  else
    Top := Ln.BackSector.CeilingHeight;
  if Ln.FrontSector.FloorHeight > Ln.BackSector.FloorHeight then
    Bot := Ln.FrontSector.FloorHeight
  else
    Bot := Ln.BackSector.FloorHeight;
  Result := (AtZ <= Bot) or (AtZ + 8 * 65536 >= Top);
end;

function OpenHeight(Ln: TLine): Integer;
var
  Top, Bot: Integer;
begin
  Result := 0;
  if (Ln = nil) or (Ln.FrontSector = nil) or (Ln.BackSector = nil) then
    Exit;
  if Ln.FrontSector.CeilingHeight < Ln.BackSector.CeilingHeight then
    Top := Ln.FrontSector.CeilingHeight
  else
    Top := Ln.BackSector.CeilingHeight;
  if Ln.FrontSector.FloorHeight > Ln.BackSector.FloorHeight then
    Bot := Ln.FrontSector.FloorHeight
  else
    Bot := Ln.BackSector.FloorHeight;
  Result := AsI32(Int64(Top) - Bot);
end;

function TEnemies.Sight(X1, Y1, X2, Y2: Integer): Boolean;
var
  I, Along: Integer;
  Ln: TLine;
  A, B, C, D: Integer;
begin
  Result := True;
  if FWorld = nil then
    Exit;
  A := AsI32(Int64(X1) * 65536);
  B := AsI32(Int64(Y1) * 65536);
  C := AsI32(Int64(X2) * 65536);
  D := AsI32(Int64(Y2) * 65536);
  for I := 0 to FWorld.LineCount - 1 do
  begin
    Ln := FWorld.LineAt(I);
    if OpenHeight(Ln) > 0 then
      Continue;
    if not HitLine(A, B, C, D, Ln, Along) then
      Continue;
    if (Along > 1024) and (Along < 65536 - 1024) then
      Exit(False);
  end;
end;

function TEnemies.Sees(Th: TMapThing): Boolean;
var
  Px, Py, Far: Integer;
begin
  Result := False;
  if (Th = nil) or (FPlayer = nil) or (FPlayer.Health <= 0) then
    Exit;
  Px := PlayerX;
  Py := PlayerY;
  if not Sight(Th.X, Th.Y, Px, Py) then
    Exit;
  Far := Dist(Th.X, Th.Y, Px, Py);
  if Behind(Th.Angle, Degrees(Th.X, Th.Y, Px, Py)) and (Far > 64) then
    Exit;
  Result := True;
end;

function BodyHits(NX, NY, Rad: Integer; Ln: TLine): Boolean;
var
  Ax, Ay, Bx, By, Vx, Vy, Wx, Wy, Den, Tee: Int64;
begin
  Result := False;
  if (Ln = nil) or (Ln.V1 = nil) or (Ln.V2 = nil) or (Rad <= 0) then
    Exit;
  Ax := SHar32(Ln.V1.X, 16);
  Ay := SHar32(Ln.V1.Y, 16);
  Bx := SHar32(Ln.V2.X, 16);
  By := SHar32(Ln.V2.Y, 16);
  if (Int64(NX) + Rad < Ax) and (Int64(NX) + Rad < Bx) then
    Exit;
  if (Int64(NX) - Rad > Ax) and (Int64(NX) - Rad > Bx) then
    Exit;
  if (Int64(NY) + Rad < Ay) and (Int64(NY) + Rad < By) then
    Exit;
  if (Int64(NY) - Rad > Ay) and (Int64(NY) - Rad > By) then
    Exit;
  Vx := Bx - Ax;
  Vy := By - Ay;
  Den := Vx * Vx + Vy * Vy;
  if Den <= 0 then
    Exit;
  Tee := (Int64(NX) - Ax) * Vx + (Int64(NY) - Ay) * Vy;
  if Tee <= 0 then
  begin
    Wx := Ax;
    Wy := Ay;
  end
  else if Tee >= Den then
  begin
    Wx := Bx;
    Wy := By;
  end
  else
  begin
    Wx := Ax + (Tee * Vx) div Den;
    Wy := Ay + (Tee * Vy) div Den;
  end;
  Wx := Wx - NX;
  Wy := Wy - NY;
  Result := Wx * Wx + Wy * Wy < Int64(Rad) * Rad;
end;

function TEnemies.Blocked(Th: TMapThing; NX, NY: Integer; out Hit: TLine): Boolean;
var
  I, Along, Rad, H, Px, Py: Integer;
  Ln: TLine;
  Sub, Old: TSubsector;
  Other: TMapThing;
  A, B, C, D: Integer;
begin
  Result := True;
  Hit := nil;
  if (Th = nil) or (FWorld = nil) then
    Exit;
  Rad := Th.Radius shr 16;
  if Rad < 8 then
    Rad := 16;
  H := Th.BodyHeight;
  if H <= 0 then
    H := 56 * 65536;
  Px := PlayerX;
  Py := PlayerY;
  if (Abs(NX - Px) < Rad + 16) and (Abs(NY - Py) < Rad + 16) then
    Exit;
  A := AsI32(Int64(Th.X) * 65536);
  B := AsI32(Int64(Th.Y) * 65536);
  C := AsI32(Int64(NX) * 65536);
  D := AsI32(Int64(NY) * 65536);
  for I := 0 to FWorld.LineCount - 1 do
  begin
    Ln := FWorld.LineAt(I);
    if not (HitLine(A, B, C, D, Ln, Along) and (Along > 0) and (Along < 65536)) and
      not BodyHits(NX, NY, Rad, Ln) then
      Continue;
    if (Ln.BackSector = nil) or (Ln.FrontSector = nil) or ((Ln.Flags and 3) <> 0) or (OpenHeight(Ln) < H) then
    begin
      Hit := Ln;
      Exit;
    end;
    if not Th.Floats then
    begin
      if Ln.FrontSector.FloorHeight > Ln.BackSector.FloorHeight then
      begin
        if Ln.FrontSector.FloorHeight - Ln.BackSector.FloorHeight > 24 * 65536 then
        begin
          Hit := Ln;
          Exit;
        end;
      end
      else if Ln.BackSector.FloorHeight - Ln.FrontSector.FloorHeight > 24 * 65536 then
      begin
        Hit := Ln;
        Exit;
      end;
    end;
  end;
  Old := FWorld.PointInSubsector(A, B);
  Sub := FWorld.PointInSubsector(C, D);
  if (Sub = nil) or (Sub.Sector = nil) then
    Exit;
  if (Old <> nil) and (Old.Sector <> nil) and not Th.Floats then
    if Abs(Sub.Sector.FloorHeight - Old.Sector.FloorHeight) > 24 * 65536 then
      Exit;
  if Sub.Sector.CeilingHeight - Sub.Sector.FloorHeight < H then
    Exit;
  for I := 0 to FWorld.ThingCount - 1 do
  begin
    Other := FWorld.ThingAt(I);
    if (Other = nil) or (Other = Th) or Other.Dead then
      Continue;
    if (Other.ActorFlags and 2) = 0 then
      Continue;
    if (Abs(NX - Other.X) < Rad + (Other.Radius shr 16)) and
      (Abs(NY - Other.Y) < Rad + (Other.Radius shr 16)) then
      Exit;
  end;
  Result := False;
end;

function TEnemies.TryStep(Th: TMapThing; NX, NY: Integer): Boolean;
var
  Hit: TLine;
begin
  if Blocked(Th, NX, NY, Hit) then
  begin
    Result := False;
    if (not FUsed) and (Hit <> nil) and (Hit.Special <> 0) and (FSpecials <> nil) then
    begin
      FUsed := True;
      FSpecials.MonsterUse(Hit);
    end;
  end
  else
  begin
    Th.X := NX;
    Th.Y := NY;
    Result := True;
  end;
end;

procedure TEnemies.Wake(Th: TMapThing);
begin
  if (Th = nil) or (Th.Ai <> 1) then
    Exit;
  Th.Ai := 2;
  Th.MoveDir := NODIR;
  Th.MoveCount := 0;
  Th.FrameUse := 0;
  case Th.ThingType of
    3004, 84:
      case Rnd mod 3 of
        0: Hear(Th, 'posit1');
        1: Hear(Th, 'posit2');
      else
        Hear(Th, 'posit3');
      end;
    9: Hear(Th, 'posit2');
    3001:
      if Rnd mod 2 = 0 then
        Hear(Th, 'bgsit1')
      else
        Hear(Th, 'bgsit2');
    3002, 58: Hear(Th, 'sgtsit');
    3003: Hear(Th, 'brssit');
  end;
end;

procedure TEnemies.Look(Th: TMapThing; Heard: Boolean);
var
  Sub: TSubsector;
  Noisy: Boolean;
begin
  Noisy := False;
  if Heard then
  begin
    Sub := FWorld.PointInSubsector(AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
    if (Sub <> nil) and (Sub.Sector <> nil) and (Sub.Sector.Index >= 0) and
      (Sub.Sector.Index < Length(FVisit)) and (FVisit[Sub.Sector.Index] = FGen) then
      Noisy := True;
  end;
  if Noisy and (not Th.Ambush or Sees(Th)) then
    Wake(Th)
  else if Sees(Th) then
    Wake(Th);
end;

procedure TEnemies.Idle(Th: TMapThing);
var
  Dur: Integer;
begin
  if (Th.ThingType = 3005) or (Th.ThingType = 71) then
  begin
    Th.FrameUse := 0;
    Exit;
  end;
  if Th.ThingType = 67 then
    Dur := 15
  else
    Dur := 10;
  if Th.FrameUse < 0 then
    Th.FrameUse := 0;
  Dec(Th.Tics);
  if Th.Tics > 0 then
    Exit;
  if Th.FrameUse = 0 then
    Th.FrameUse := 1
  else
    Th.FrameUse := 0;
  Th.Tics := Dur;
end;

function StepOf(Th: TMapThing; Dir: Integer; out NX, NY: Integer): Boolean;
begin
  Result := (Dir >= 0) and (Dir < 8) and (Th <> nil);
  if not Result then
    Exit;
  NX := Th.X + (Th.Speed * XS[Dir]) div 65536;
  NY := Th.Y + (Th.Speed * YS[Dir]) div 65536;
end;

procedure TEnemies.NewDir(Th: TMapThing);
var
  Old, Turn, D2, D3, Nx, Ny, TDir, Start: Integer;
  Px, Py, Dx, Dy: Integer;
begin
  Px := PlayerX;
  Py := PlayerY;
  Old := Th.MoveDir;
  if (Old >= 0) and (Old < 8) then
    Turn := OPP[Old]
  else
    Turn := NODIR;
  Dx := Px - Th.X;
  Dy := Py - Th.Y;
  if Dx > 10 then
    D2 := 0
  else if Dx < -10 then
    D2 := 4
  else
    D2 := NODIR;
  if Dy < -10 then
    D3 := 6
  else if Dy > 10 then
    D3 := 2
  else
    D3 := NODIR;
  if (D2 <> NODIR) and (D3 <> NODIR) then
  begin
    if Dy < 0 then
    begin
      if Dx > 0 then
        Th.MoveDir := 7
      else
        Th.MoveDir := 5;
    end
    else if Dx > 0 then
      Th.MoveDir := 1
    else
      Th.MoveDir := 3;
    if (Th.MoveDir <> Turn) and StepOf(Th, Th.MoveDir, Nx, Ny) and TryStep(Th, Nx, Ny) then
    begin
      Th.MoveCount := Rnd and 15;
      Exit;
    end;
  end;
  if (Rnd > 200) or (Abs(Dy) > Abs(Dx)) then
  begin
    TDir := D2;
    D2 := D3;
    D3 := TDir;
  end;
  if D2 = Turn then
    D2 := NODIR;
  if D3 = Turn then
    D3 := NODIR;
  if (D2 <> NODIR) and StepOf(Th, D2, Nx, Ny) then
  begin
    Th.MoveDir := D2;
    if TryStep(Th, Nx, Ny) then
    begin
      Th.MoveCount := Rnd and 15;
      Exit;
    end;
  end;
  if (D3 <> NODIR) and StepOf(Th, D3, Nx, Ny) then
  begin
    Th.MoveDir := D3;
    if TryStep(Th, Nx, Ny) then
    begin
      Th.MoveCount := Rnd and 15;
      Exit;
    end;
  end;
  if (Old <> NODIR) and StepOf(Th, Old, Nx, Ny) then
  begin
    Th.MoveDir := Old;
    if TryStep(Th, Nx, Ny) then
    begin
      Th.MoveCount := Rnd and 15;
      Exit;
    end;
  end;
  Start := Rnd and 1;
  if Start = 0 then
  begin
    for TDir := 0 to 7 do
      if (TDir <> Turn) and StepOf(Th, TDir, Nx, Ny) then
      begin
        Th.MoveDir := TDir;
        if TryStep(Th, Nx, Ny) then
        begin
          Th.MoveCount := Rnd and 15;
          Exit;
        end;
      end;
  end
  else
    for TDir := 7 downto 0 do
      if (TDir <> Turn) and StepOf(Th, TDir, Nx, Ny) then
      begin
        Th.MoveDir := TDir;
        if TryStep(Th, Nx, Ny) then
        begin
          Th.MoveCount := Rnd and 15;
          Exit;
        end;
      end;
  if (Turn <> NODIR) and StepOf(Th, Turn, Nx, Ny) then
  begin
    Th.MoveDir := Turn;
    if TryStep(Th, Nx, Ny) then
    begin
      Th.MoveCount := Rnd and 15;
      Exit;
    end;
  end;
  Th.MoveDir := NODIR;
  Th.MoveCount := Rnd and 15;
end;

procedure TEnemies.Hitscan(Th: TMapThing; Pellets: Integer);
var
  N, Spread, Px, Py, Aim, Along, Best, I, Closest, HitDmg: Integer;
  Ang: Cardinal;
  X2, Y2: Integer;
  Dx, Dy, Side, Reach: Int64;
  Ln: TLine;
begin
  if (FPlayer = nil) or (FPlayer.Health <= 0) then
    Exit;
  Px := PlayerX;
  Py := PlayerY;
  Aim := Degrees(Th.X, Th.Y, Px, Py);
  HitDmg := 0;
  for N := 1 to Pellets do
  begin
    Spread := Rnd - Rnd;
    Ang := AsU32(Int64(BamOf(Aim)) + Int64(Spread) shl 20);
    X2 := Th.X + Integer((Int64(2048) * FineCos(Ang)) div 65536);
    Y2 := Th.Y + Integer((Int64(2048) * FineSin(Ang)) div 65536);
    Dx := X2 - Th.X;
    Dy := Y2 - Th.Y;
    if Dx * Dx + Dy * Dy = 0 then
      Continue;
    Closest := Integer(((Int64(Px - Th.X) * Dx + Int64(Py - Th.Y) * Dy) * 65536) div (Dx * Dx + Dy * Dy));
    if (Closest <= 0) or (Closest >= 65536) then
      Continue;
    Side := Px - (Th.X + (Closest * Dx) div 65536);
    Reach := Py - (Th.Y + (Closest * Dy) div 65536);
    if Side * Side + Reach * Reach > 24 * 24 then
      Continue;
    Best := 65536;
    for I := 0 to FWorld.LineCount - 1 do
    begin
      Ln := FWorld.LineAt(I);
      if OpenHeight(Ln) > 0 then
        Continue;
      if not HitLine(AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536),
        AsI32(Int64(X2) * 65536), AsI32(Int64(Y2) * 65536), Ln, Along) then
        Continue;
      if (Along > 0) and (Along < Best) then
        Best := Along;
    end;
    if Best < Closest then
      Continue;
    Inc(HitDmg, (Rnd mod 5 + 1) * 3);
  end;
  if HitDmg > 0 then
    FPlayer.Damage(HitDmg, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
end;

procedure TEnemies.SpawnBall(Th: TMapThing; const Sprite: string; Speed, Dmg, Spread: Integer);
var
  Ball: TMapThing;
  Sub: TSubsector;
  Px, Py, Aim, Far, Steps: Integer;
  Ang: Cardinal;
begin
  if (Th = nil) or (FWorld = nil) then
    Exit;
  Px := PlayerX;
  Py := PlayerY;
  Aim := Degrees(Th.X, Th.Y, Px, Py) + Spread;
  Ang := BamOf(Aim);
  Ball := TMapThing.Create;
  Ball.X := Th.X;
  Ball.Y := Th.Y;
  Ball.ThingType := 0;
  Ball.Options := 7;
  Ball.SprName := Sprite;
  Ball.SprFrame := 0;
  Ball.Ai := 4;
  Ball.Speed := Speed;
  Ball.MissileDmg := Dmg;
  Ball.HasZ := True;
  Ball.FrameUse := 0;
  Sub := FWorld.PointInSubsector(AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
  if (Sub <> nil) and (Sub.Sector <> nil) then
    Ball.Z := AsI32(Int64(Sub.Sector.FloorHeight) + 32 * 65536)
  else
    Ball.Z := 32 * 65536;
  Ball.MomX := Integer((Int64(Speed) * FineCos(Ang)) div 65536);
  Ball.MomY := Integer((Int64(Speed) * FineSin(Ang)) div 65536);
  Far := Dist(Th.X, Th.Y, Px, Py);
  Steps := 1;
  if Speed > 0 then
    Steps := Far div Speed;
  if Steps < 1 then
    Steps := 1;
  if FPlayer <> nil then
    Ball.MomZ := (AsI32(Int64(FPlayer.Z) + 28 * 65536) - Ball.Z) div Steps;
  Ball.X := Ball.X + Ball.MomX div 2;
  Ball.Y := Ball.Y + Ball.MomY div 2;
  Ball.Z := AsI32(Int64(Ball.Z) + Ball.MomZ div 2);
  FWorld.AddThing(Ball);
end;

procedure TEnemies.Attack(Th: TMapThing);
var
  Px, Py, Far, Rad: Integer;
begin
  if (FPlayer = nil) or (FPlayer.Health <= 0) then
  begin
    Th.Ai := 1;
    Th.FrameUse := 0;
    Th.Tics := 0;
    Exit;
  end;
  Px := PlayerX;
  Py := PlayerY;
  Th.Angle := Degrees(Th.X, Th.Y, Px, Py);
  Dec(Th.Tics);
  if (not Th.DidFire) and (Th.Tics <= 10) then
  begin
    Th.DidFire := True;
    Th.FrameUse := 5;
    Far := Dist(Th.X, Th.Y, Px, Py);
    Rad := Th.Radius shr 16;
    if Rad < 8 then
      Rad := 16;
    case Th.Kind of
      1, 9:
        begin
          Hear(Th, 'shotgn');
          Hitscan(Th, 3);
        end;
      3:
        if Far < 64 + Rad then
        begin
          Hear(Th, 'claw');
          FPlayer.Damage((Rnd mod 8 + 1) * 3, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
        end
        else
        begin
          Hear(Th, 'firsht');
          SpawnBall(Th, 'BAL1', 10, 3, 0);
        end;
      4:
        begin
          Hear(Th, 'claw');
          FPlayer.Damage((Rnd mod 8 + 1) * 3, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
        end;
      5, 6:
        if Far < 64 + Rad then
        begin
          Hear(Th, 'claw');
          FPlayer.Damage((Rnd mod 8 + 1) * 3, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
        end
        else if Th.Kind = 6 then
        begin
          Hear(Th, 'firsht');
          SpawnBall(Th, 'BAL2', 10, 5, 0);
        end
        else
        begin
          Hear(Th, 'firsht');
          SpawnBall(Th, 'BAL2', 15, 8, 0);
        end;
      8:
        begin
          Hear(Th, 'rlaunc');
          SpawnBall(Th, 'MISL', 20, 20, 0);
        end;
      10:
        begin
          Hear(Th, 'firsht');
          SpawnBall(Th, 'MANF', 20, 8, -20);
          SpawnBall(Th, 'MANF', 20, 8, 0);
          SpawnBall(Th, 'MANF', 20, 8, 20);
        end;
    else
      begin
        Hear(Th, 'pistol');
        Hitscan(Th, 1);
      end;
    end;
  end;
  if Th.Tics <= 0 then
  begin
    Th.Ai := 2;
    Th.DidFire := False;
    Th.MoveCount := 8 + (Rnd and 7);
    Th.FrameUse := 0;
  end;
end;

procedure TEnemies.FlySkull(Th: TMapThing);
var
  Px, Py, Nx, Ny: Integer;
  Hit: TLine;
begin
  if (FPlayer = nil) or (FPlayer.Health <= 0) then
  begin
    Th.Ai := 2;
    Exit;
  end;
  Px := PlayerX;
  Py := PlayerY;
  Th.Angle := Degrees(Th.X, Th.Y, Px, Py);
  Nx := Th.X + (20 * FineCos(BamOf(Th.Angle))) div 65536;
  Ny := Th.Y + (20 * FineSin(BamOf(Th.Angle))) div 65536;
  if (Abs(Nx - Px) < 30) and (Abs(Ny - Py) < 30) then
  begin
    FPlayer.Damage((Rnd mod 8 + 1) * 3, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
    Th.Ai := 2;
    Exit;
  end;
  if Blocked(Th, Nx, Ny, Hit) then
    Th.Ai := 2
  else
  begin
    Th.X := Nx;
    Th.Y := Ny;
  end;
end;

procedure TEnemies.Chase(Th: TMapThing);
var
  Px, Py, Far, Rad, Chance, Nx, Ny, Ox, Oy: Integer;
begin
  if (FPlayer = nil) or (FPlayer.Health <= 0) or not Sees(Th) then
  begin
    if (FPlayer = nil) or (FPlayer.Health <= 0) then
    begin
      Th.Ai := 1;
      Th.FrameUse := 0;
      Th.Tics := 0;
      Exit;
    end;
  end;
  Px := PlayerX;
  Py := PlayerY;
  Far := Dist(Th.X, Th.Y, Px, Py);
  Rad := Th.Radius shr 16;
  if Rad < 8 then
    Rad := 16;
  if (FTime and 3) <> 0 then
    Exit;
  if (Th.Kind = 7) and Sees(Th) and (Far < 512) then
  begin
    Th.Ai := 5;
    Exit;
  end;
  if ((Th.Kind = 3) or (Th.Kind = 4) or (Th.Kind = 5) or (Th.Kind = 6)) and
    (Far < 64 + Rad) and Sees(Th) then
  begin
    Th.Ai := 3;
    Th.Tics := 18;
    Th.DidFire := False;
    Th.FrameUse := 4;
    Exit;
  end;
  if (Th.Kind <> 4) and (Th.Kind <> 7) and (Th.MoveCount = 0) and Sees(Th) then
  begin
    Chance := Far - 64;
    if (Th.Kind <> 3) and (Th.Kind <> 5) and (Th.Kind <> 6) then
      Dec(Chance, 128);
    if Chance < 0 then
      Chance := 0;
    if Chance > 200 then
      Chance := 200;
    if Rnd >= Chance then
    begin
      Th.Ai := 3;
      Th.Tics := 18;
      Th.DidFire := False;
      Th.FrameUse := 4;
      Exit;
    end;
  end;
  if (Abs(Th.X - Px) < Rad + 16) and (Abs(Th.Y - Py) < Rad + 16) then
  begin
    Th.Angle := Degrees(Th.X, Th.Y, Px, Py);
    Th.FrameUse := 0;
    Dec(Th.MoveCount);
    if Th.MoveCount < 0 then
      Th.MoveCount := 0;
    Exit;
  end;
  Ox := Th.X;
  Oy := Th.Y;
  Dec(Th.MoveCount);
  if (Th.MoveCount < 0) or not StepOf(Th, Th.MoveDir, Nx, Ny) or not TryStep(Th, Nx, Ny) then
    NewDir(Th);
  if (Th.MoveDir >= 0) and (Th.MoveDir < 8) then
    Th.Angle := FACE[Th.MoveDir];
  if (Th.X <> Ox) or (Th.Y <> Oy) then
    Th.FrameUse := (FTime div 4) and 3
  else
    Th.FrameUse := 0;
end;

procedure TEnemies.AdvanceDeath(Th: TMapThing);
var
  Last, Dur: Integer;
begin
  if (Th = nil) or (Th.FrameUse < 0) then
  begin
    Th.Ai := 0;
    Exit;
  end;
  Dec(Th.Tics);
  if Th.Tics > 0 then
    Exit;
  case Th.ThingType of
    3004, 9, 84: Last := 11;
    3001: Last := 12;
    3002, 58: Last := 13;
    3003, 69: Last := 14;
  else
    begin
      Th.Ai := 0;
      Exit;
    end;
  end;
  if Th.FrameUse >= Last then
  begin
    Th.FrameUse := Last;
    Th.Ai := 0;
    Exit;
  end;
  Inc(Th.FrameUse);
  if Th.FrameUse >= Last then
  begin
    Th.FrameUse := Last;
    Th.Ai := 0;
    Exit;
  end;
  Dur := 5;
  case Th.ThingType of
    3001:
      if Th.FrameUse <= 9 then
        Dur := 8
      else
        Dur := 6;
    3002, 58:
      if Th.FrameUse <= 9 then
        Dur := 8
      else
        Dur := 4;
    3003, 69: Dur := 8;
  end;
  Th.Tics := Dur;
end;

procedure TEnemies.TickMissile(Th: TMapThing);
var
  Px, Py, OldX, OldY, I, Rad, NX, NY, Best, Ax, Ay, Bx, By, Along, ZAt, BaseZ, Tall, Slack: Integer;
  Sub: TSubsector;
  Other, Victim: TMapThing;
  Ln: TLine;
  Boom, Struck: Boolean;
begin
  if (Th = nil) or (Th.FrameUse = -2) then
    Exit;
  if Th.Ai = 7 then
  begin
    Dec(Th.Tics);
    if Th.Tics > 0 then
      Exit;
    Inc(Th.SprFrame);
    Th.FrameUse := Th.SprFrame;
    if (((Th.SprName = 'PLSE') or (Th.SprName = 'BEXP')) and (Th.SprFrame > 4)) or
      ((Th.SprName <> 'PLSE') and (Th.SprName <> 'BEXP') and (Th.SprFrame > 3)) then
    begin
      Th.FrameUse := -2;
      Th.Ai := 0;
    end
    else
      Th.Tics := 5;
    Exit;
  end;
  if Th.Ai <> 4 then
    Exit;
  OldX := Th.X;
  OldY := Th.Y;
  Boom := False;
  Struck := False;
  Slack := 64 * 65536;
  NX := Th.X + Th.MomX;
  NY := Th.Y + Th.MomY;
  Best := -1;
  Ax := AsI32(Int64(OldX) * 65536);
  Ay := AsI32(Int64(OldY) * 65536);
  Bx := AsI32(Int64(NX) * 65536);
  By := AsI32(Int64(NY) * 65536);
  for I := 0 to FWorld.LineCount - 1 do
  begin
    Ln := FWorld.LineAt(I);
    if not HitLine(Ax, Ay, Bx, By, Ln, Along) then
      Continue;
    if (Along <= 1024) or (Along >= 65536 - 1024) then
      Continue;
    ZAt := AsI32(Int64(Th.Z) + (Int64(Th.MomZ) * Along) div 65536);
    if not MissileBlocked(Ln, ZAt) then
      Continue;
    if (Best < 0) or (Along < Best) then
      Best := Along;
  end;
  if Best >= 0 then
  begin
    Th.X := OldX + Integer((Int64(Th.MomX) * Best) div 65536);
    Th.Y := OldY + Integer((Int64(Th.MomY) * Best) div 65536);
    Th.Z := AsI32(Int64(Th.Z) + (Int64(Th.MomZ) * Best) div 65536);
    Boom := True;
  end
  else
  begin
    Th.X := NX;
    Th.Y := NY;
    Th.Z := AsI32(Int64(Th.Z) + Th.MomZ);
  end;
  if Th.FromPlayer then
  begin
    if not Boom then
    for I := 0 to FWorld.ThingCount - 1 do
    begin
      Other := FWorld.ThingAt(I);
      if (Other = nil) or (Other = Th) or Other.Dead or (Other.Health <= 0) then
        Continue;
      if (Other.ActorFlags and 4) = 0 then
        Continue;
      Rad := Other.Radius shr 16;
      if Rad < 8 then
        Rad := 16;
      if (Abs(Th.X - Other.X) >= Rad + 8) or (Abs(Th.Y - Other.Y) >= Rad + 8) then
        Continue;
      Sub := FWorld.PointInSubsector(AsI32(Int64(Other.X) * 65536), AsI32(Int64(Other.Y) * 65536));
      if (Sub = nil) or (Sub.Sector = nil) then
        Continue;
      if (Other.ActorFlags and 256) <> 0 then
        BaseZ := AsI32(Int64(Sub.Sector.CeilingHeight) - Other.BodyHeight)
      else
        BaseZ := Sub.Sector.FloorHeight;
      Tall := Other.BodyHeight;
      if Tall < 32 * 65536 then
        Tall := 56 * 65536;
      if (Th.Z + 8 * 65536 + Slack < BaseZ) or (Th.Z - Slack > BaseZ + Tall) then
        Continue;
      Th.X := Other.X;
      Th.Y := Other.Y;
      if FPlayer <> nil then
        FPlayer.Strike(Other, Th.MissileDmg * (Rnd mod 8 + 1));
      Struck := True;
      Boom := True;
      Break;
    end;
  end
  else
  begin
    Px := PlayerX;
    Py := PlayerY;
    if (FPlayer <> nil) and (FPlayer.Health > 0) and (Abs(Th.X - Px) < 24) and (Abs(Th.Y - Py) < 24) and
      (Th.Z > FPlayer.Z) and (Th.Z < FPlayer.Z + 56 * 65536) then
    begin
      FPlayer.Damage(Th.MissileDmg * (Rnd mod 8 + 1), AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
      Boom := True;
    end;
  end;
  if not Boom then
  begin
    Sub := FWorld.PointInSubsector(AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
    if (Sub = nil) or (Sub.Sector = nil) or (Th.Z < Sub.Sector.FloorHeight) or
      (Th.Z > Sub.Sector.CeilingHeight) or not Sight(OldX, OldY, Th.X, Th.Y) then
      Boom := True;
  end;
  if Boom then
  begin
    Th.MomX := 0;
    Th.MomY := 0;
    Th.MomZ := 0;
    if Th.SprName = 'MISL' then
    begin
      for I := 0 to FWorld.ThingCount - 1 do
      begin
        Other := FWorld.ThingAt(I);
        if (Other = nil) or (Other = Th) or Other.Dead or (Other.Health <= 0) then
          Continue;
        if (Other.ActorFlags and 4) = 0 then
          Continue;
        if (Other.ThingType = 7) or (Other.ThingType = 16) then
          Continue;
        Px := Abs(Other.X - Th.X);
        Py := Abs(Other.Y - Th.Y);
        if Px > Py then
          Rad := Px
        else
          Rad := Py;
        Along := Other.Radius shr 16;
        if Along < 1 then
          Along := 16;
        Rad := Rad - Along;
        if Rad < 0 then
          Rad := 0;
        if (Rad < 128) and Sight(Other.X, Other.Y, Th.X, Th.Y) and (FPlayer <> nil) then
          FPlayer.Strike(Other, 128 - Rad);
      end;
      if FPlayer <> nil then
      begin
        Px := Abs(SHar32(FPlayer.X, 16) - Th.X);
        Py := Abs(SHar32(FPlayer.Y, 16) - Th.Y);
        if Px > Py then
          Rad := Px
        else
          Rad := Py;
        Rad := Rad - 16;
        if Rad < 0 then
          Rad := 0;
        if (Rad < 128) and ((Rad <= 64) or Sight(SHar32(FPlayer.X, 16), SHar32(FPlayer.Y, 16), Th.X, Th.Y)) then
          FPlayer.Damage(128 - Rad, AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
      end;
    end;
    if (Th.SprName = 'PLSS') and (not Struck) and (FPlayer <> nil) then
    begin
      Victim := nil;
      Best := 2147483647;
      for I := 0 to FWorld.ThingCount - 1 do
      begin
        Other := FWorld.ThingAt(I);
        if (Other = nil) or (Other = Th) or Other.Dead or (Other.Health <= 0) then
          Continue;
        if (Other.ActorFlags and 4) = 0 then
          Continue;
        Rad := Other.Radius shr 16;
        if Rad < 8 then
          Rad := 16;
        if ((Abs(Th.X - Other.X) >= Rad + 13) or (Abs(Th.Y - Other.Y) >= Rad + 13)) and
          ((Abs(OldX - Other.X) >= Rad + 13) or (Abs(OldY - Other.Y) >= Rad + 13)) then
          Continue;
        Sub := FWorld.PointInSubsector(AsI32(Int64(Other.X) * 65536), AsI32(Int64(Other.Y) * 65536));
        if (Sub = nil) or (Sub.Sector = nil) then
          Continue;
        if (Other.ActorFlags and 256) <> 0 then
          BaseZ := AsI32(Int64(Sub.Sector.CeilingHeight) - Other.BodyHeight)
        else
          BaseZ := Sub.Sector.FloorHeight;
        Tall := Other.BodyHeight;
        if Tall < 32 * 65536 then
          Tall := 56 * 65536;
        if (Th.Z + 8 * 65536 + Slack < BaseZ) or (Th.Z - Slack > BaseZ + Tall) then
          Continue;
        Along := Abs(Th.X - Other.X);
        if Abs(Th.Y - Other.Y) > Along then
          Along := Abs(Th.Y - Other.Y);
        if Along < Best then
        begin
          Best := Along;
          Victim := Other;
        end;
      end;
      if Victim <> nil then
        FPlayer.Strike(Victim, Th.MissileDmg * (Rnd mod 8 + 1));
    end;
    if (Th.SprName = 'MISL') or (Th.SprName = 'PLSS') then
    begin
      if Th.SprName = 'PLSS' then
      begin
        Th.SprName := 'PLSE';
        Th.SprFrame := 0;
      end
      else
        Th.SprFrame := 1;
      Th.FrameUse := Th.SprFrame;
      Th.Tics := 5;
      Th.Ai := 7;
      if Th.SprName = 'MISL' then
        PlaySfxAt('barexp', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536),
          AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
    end
    else
    begin
      Th.FrameUse := -2;
      Th.Ai := 0;
    end;
  end;
end;

procedure TEnemies.Flood(Sec: TSector; Blocks: Integer);
var
  I: Integer;
  Ln: TLine;
  Other: TSector;
begin
  if (Sec = nil) or (Sec.Index < 0) or (Sec.Index >= Length(FVisit)) then
    Exit;
  if (FVisit[Sec.Index] = FGen) and (FBlocks[Sec.Index] <= Blocks + 1) then
    Exit;
  FVisit[Sec.Index] := FGen;
  FBlocks[Sec.Index] := Blocks + 1;
  for I := 0 to Sec.Lines.Count - 1 do
  begin
    Ln := Sec.Lines[I];
    if (Ln = nil) or ((Ln.Flags and 4) = 0) then
      Continue;
    if OpenHeight(Ln) <= 0 then
      Continue;
    if Ln.FrontSector = Sec then
      Other := Ln.BackSector
    else
      Other := Ln.FrontSector;
    if (Ln.Flags and 64) <> 0 then
    begin
      if Blocks = 0 then
        Flood(Other, 1);
    end
    else
      Flood(Other, Blocks);
  end;
end;

procedure TEnemies.Alert;
var
  Sub: TSubsector;
begin
  if (FWorld = nil) or (FPlayer = nil) then
    Exit;
  if Length(FVisit) <> FWorld.SectorCount then
  begin
    SetLength(FVisit, FWorld.SectorCount);
    SetLength(FBlocks, FWorld.SectorCount);
  end;
  Inc(FGen);
  if FGen = 0 then
    Inc(FGen);
  Sub := FWorld.PointInSubsector(FPlayer.X, FPlayer.Y);
  if (Sub <> nil) and (Sub.Sector <> nil) then
    Flood(Sub.Sector, 0);
end;

procedure TEnemies.Tick(Heard: Boolean);
var
  I, N: Integer;
  Th: TMapThing;
begin
  if (FWorld = nil) or (FPlayer = nil) then
    Exit;
  Inc(FTime);
  if Heard then
    Alert;
  N := FWorld.ThingCount;
  for I := 0 to N - 1 do
  begin
    Th := FWorld.ThingAt(I);
    if (Th <> nil) and (Th.Ai = 6) then
    begin
      AdvanceDeath(Th);
      Continue;
    end;
    if (Th = nil) or Th.Dead or (Th.Health <= 0) or (Th.Ai = 0) or (Th.Ai = 4) then
      Continue;
    FUsed := False;
    if Th.Ai = 1 then
    begin
      Look(Th, Heard);
      if Th.Ai = 1 then
        Idle(Th);
    end
    else if Th.Ai = 3 then
      Attack(Th)
    else if Th.Ai = 5 then
      FlySkull(Th)
    else
      Chase(Th);
  end;
  N := FWorld.ThingCount;
  for I := 0 to N - 1 do
  begin
    Th := FWorld.ThingAt(I);
    if (Th <> nil) and ((Th.Ai = 4) or (Th.Ai = 7)) then
      TickMissile(Th);
  end;
end;

end.
