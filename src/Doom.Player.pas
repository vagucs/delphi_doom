unit Doom.Player;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Andar, virar e pistola. Segue doom/player.py e o choque de doom/collision.py.
  As portas ficam para a fase dos setores.
}

interface

uses
  Doom.World;

type
  TPlayer = class
  public
    X: Integer;
    Y: Integer;
    Z: Integer;
    Angle: Cardinal;
    ViewZ: Integer;
    LightBoost: Integer;
    Health: Integer;
    Ammo: Integer;
    GodMode: Boolean;
    NoClip: Boolean;
    WeaponBody: string;
    WeaponFlash: string;
    WeaponSx: Integer;
    WeaponSy: Integer;
    Cards: array[0..5] of Boolean;
    ShotLine: TLine;
    Fired: Boolean;
    Kills: Integer;
    Secrets: Integer;
    DamageCount: Integer;
    BonusCount: Integer;
    Armor: Integer;
    ArmorType: Integer;
    Shells: Integer;
    Rockets: Integer;
    Cells: Integer;
    MaxClip: Integer;
    MaxShell: Integer;
    MaxRocket: Integer;
    MaxCell: Integer;
    Weapon: Integer;
    Owned: array[0..6] of Boolean;
    function LevelTics: Integer;
    function Message: string;
    function ShownAmmo: Integer;
    constructor Create;
    procedure Spawn(World: TWorld; Skill: Integer);
    procedure Tick(World: TWorld; Up, Down, Left, Right, Fire, Run, Strafe, SideL, SideR: Boolean);
    function StatusLine(const MapName: string): string;
    procedure Say(const Text: string);
    function ClipSector(World: TWorld; FloorH, CeilH: Integer): Boolean;
    procedure Place(NX, NY, FloorH, CeilH: Integer; NewAngle: Cardinal);
    function Accepts(Options: Integer): Boolean;
    procedure SelectWeapon(Index: Integer);
    procedure Strike(Th: TMapThing; Amount: Integer);
    procedure Damage(Amount: Integer); overload;
    procedure Damage(Amount, SrcX, SrcY: Integer); overload;
  private
    FMomX: Integer;
    FMomY: Integer;
    FMomZ: Integer;
    FFloorZ: Integer;
    FCeilZ: Integer;
    FViewHeight: Integer;
    FDeltaView: Integer;
    FBob: Integer;
    FSkill: Integer;
    FSkillBit: Integer;
    FLevelTime: Integer;
    FTurnHeld: Integer;
    FRefire: Integer;
    FShotNow: Boolean;
    FWeaponState: Integer;
    FWeaponStep: Integer;
    FWeaponTics: Integer;
    FFlashTics: Integer;
    FMelee: Boolean;
    FRnd: Cardinal;
    FMsg: string;
    FMsgTic: Integer;
    procedure ArmThings(World: TWorld);
    procedure Thrust(Ang: Cardinal; Move: Integer);
    function CanOccupy(World: TWorld; NX, NY: Integer): Boolean;
    function LineSide(Px, Py: Integer; Ln: TLine): Integer;
    function BoxSide(L, R, B, T: Integer; Ln: TLine): Integer;
    function SegHit(X1, Y1, X2, Y2: Integer; Ln: TLine; out Along: Integer): Boolean;
    function WallStops(Ln: TLine; AtZ, Slope, Dist: Integer): Boolean;
    procedure Slide(World: TWorld; StepX, StepY: Integer);
    procedure MoveXY(World: TWorld);
    procedure FollowFloor(World: TWorld);
    procedure ApplyZ;
    procedure SectorFit(World: TWorld; PX, PY: Integer; out FloorZ, CeilZ: Integer);
    procedure Shoot(World: TWorld; Accurate: Boolean);
    procedure HurtThing(Th: TMapThing);
    procedure WeaponTick(Fire: Boolean);
    procedure EnterGunStep(Held: Boolean);
    procedure CheckSecret(World: TWorld);
    procedure Launch(World: TWorld; const Sprite: string; Speed, Dmg: Integer);
    function HasAmmo: Boolean;
    function GunName(Kind: Integer): string;
    procedure ApplyHit(Amount, SrcX, SrcY: Integer; HasSrc: Boolean);
    function RandByte: Integer;
    function AimAngle(X1, Y1, X2, Y2: Integer): Cardinal;
  end;

implementation

uses
  System.SysUtils, Doom.Compat, Doom.Tables, Doom.Render, Doom.Sound;

const
  ANG90 = Cardinal($40000000);
  ANG180 = Cardinal($80000000);
  PLAYER_RADIUS = 16 * 65536;
  PLAYER_HEIGHT = 56 * 65536;
  VIEW_H = 41 * 65536;
  MAXMOVE = 30 * 65536;
  MAXSTEP = 24 * 65536;
  STOPSPEED = $1000;
  FRICTION = $E800;
  GRAVITY = 65536;
  MAXBOB = $100000;
  MISSILERANGE = 32 * 64 * 65536;
  MF_SOLID = 2;
  MF_SHOOTABLE = 4;
  ML_BLOCKING = 1;
  WS_UP = 0;
  WS_READY = 1;
  WS_ATK = 2;
  WEAPON_TOP = 32 * 65536;
  WEAPON_BOTTOM = 128 * 65536;
  FORWARDMOVE: array[0..1] of Integer = ($19, $32);
  SIDEMOVE: array[0..1] of Integer = ($18, $28);
  ANGLETURN: array[0..2] of Integer = (640, 1280, 320);

type
  TGunStep = record
    Body: string;
    Tics: Integer;
    DoFire: Boolean;
    Flash: string;
    FlashTics: Integer;
    Light: Integer;
  end;

const
  GUN_LEN: array[0..6] of Integer = (5, 4, 9, 2, 2, 2, 4);
  GUN_ATK: array[0..6, 0..8] of TGunStep = (
    (
      (Body: 'PUNGB0'; Tics: 4; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'PUNGC0'; Tics: 4; DoFire: True; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'PUNGD0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'PUNGC0'; Tics: 4; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'PUNGB0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    ),
    (
      (Body: 'PISGA0'; Tics: 4; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'PISGB0'; Tics: 6; DoFire: True; Flash: 'PISFA0'; FlashTics: 7; Light: 1),
      (Body: 'PISGC0'; Tics: 4; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'PISGB0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    ),
    (
      (Body: 'SHTGA0'; Tics: 3; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGA0'; Tics: 7; DoFire: True; Flash: 'SHTFA0'; FlashTics: 7; Light: 1),
      (Body: 'SHTGB0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGC0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGD0'; Tics: 4; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGC0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGB0'; Tics: 5; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGA0'; Tics: 3; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'SHTGA0'; Tics: 7; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    ),
    (
      (Body: 'CHGGA0'; Tics: 4; DoFire: True; Flash: 'CHGFA0'; FlashTics: 5; Light: 1),
      (Body: 'CHGGB0'; Tics: 4; DoFire: True; Flash: 'CHGFB0'; FlashTics: 5; Light: 2),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    ),
    (
      (Body: 'MISGB0'; Tics: 8; DoFire: False; Flash: 'MISFA0'; FlashTics: 15; Light: 1),
      (Body: 'MISGB0'; Tics: 12; DoFire: True; Flash: ''; FlashTics: 0; Light: 2),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    ),
    (
      (Body: 'PLSGA0'; Tics: 3; DoFire: True; Flash: 'PLSFA0'; FlashTics: 4; Light: 1),
      (Body: 'PLSGB0'; Tics: 20; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    ),
    (
      (Body: 'BFGGA0'; Tics: 20; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: 'BFGGB0'; Tics: 10; DoFire: False; Flash: 'BFGFA0'; FlashTics: 17; Light: 1),
      (Body: 'BFGGB0'; Tics: 10; DoFire: True; Flash: ''; FlashTics: 0; Light: 2),
      (Body: 'BFGGB0'; Tics: 20; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0),
      (Body: ''; Tics: 0; DoFire: False; Flash: ''; FlashTics: 0; Light: 0)
    )
  );

function SkillBitOf(Skill: Integer): Integer;
begin
  if Skill <= 1 then
    Result := 1
  else if Skill >= 3 then
    Result := 4
  else
    Result := 2;
end;

function ApproxLen(Dx, Dy: Integer): Integer;
begin
  Dx := Abs(Dx);
  Dy := Abs(Dy);
  if Dx < Dy then
    Result := Dy + Dx div 2
  else
    Result := Dx + Dy div 2;
end;

constructor TPlayer.Create;
begin
  inherited Create;
  FRnd := 1;
  WeaponBody := 'PISGA0';
  WeaponFlash := '';
  Health := 100;
  Ammo := 50;
end;

function TPlayer.RandByte: Integer;
begin
  FRnd := FRnd * 1664525 + 1013904223;
  Result := Integer((FRnd shr 16) and 255);
end;

function TPlayer.LevelTics: Integer;
begin
  Result := FLevelTime;
end;

function TPlayer.Message: string;
begin
  if FMsgTic > 0 then
    Result := FMsg
  else
    Result := '';
end;

function TPlayer.StatusLine(const MapName: string): string;
begin
  if Health <= 0 then
    Result := MapName + '  morto'
  else
    Result := Format('%s  vida %d  balas %d', [MapName, Health, Ammo]);
  if FMsgTic > 0 then
  begin
    Dec(FMsgTic);
    Result := Result + '  ' + FMsg;
  end;
end;

procedure TPlayer.Say(const Text: string);
begin
  FMsg := Text;
  FMsgTic := 35 * 3;
end;

procedure TPlayer.SectorFit(World: TWorld; PX, PY: Integer; out FloorZ, CeilZ: Integer);
var
  Sub: TSubsector;
  L, R, B, T, I, OpenTop, OpenBot: Integer;
  Ln: TLine;
begin
  FloorZ := 0;
  CeilZ := 128 * 65536;
  if World = nil then
    Exit;
  Sub := World.PointInSubsector(PX, PY);
  if (Sub = nil) or (Sub.Sector = nil) then
    Exit;
  FloorZ := Sub.Sector.FloorHeight;
  CeilZ := Sub.Sector.CeilingHeight;
  L := AsI32(Int64(PX) - PLAYER_RADIUS);
  R := AsI32(Int64(PX) + PLAYER_RADIUS);
  B := AsI32(Int64(PY) - PLAYER_RADIUS);
  T := AsI32(Int64(PY) + PLAYER_RADIUS);
  for I := 0 to World.LineCount - 1 do
  begin
    Ln := World.LineAt(I);
    if (Ln = nil) or (Ln.V1 = nil) or (Ln.FrontSector = nil) or (Ln.BackSector = nil) then
      Continue;
    if (R <= Ln.BBox[0]) or (L >= Ln.BBox[1]) or (T <= Ln.BBox[2]) or (B >= Ln.BBox[3]) then
      Continue;
    if BoxSide(L, R, B, T, Ln) <> -1 then
      Continue;
    if Ln.FrontSector.CeilingHeight < Ln.BackSector.CeilingHeight then
      OpenTop := Ln.FrontSector.CeilingHeight
    else
      OpenTop := Ln.BackSector.CeilingHeight;
    if Ln.FrontSector.FloorHeight > Ln.BackSector.FloorHeight then
      OpenBot := Ln.FrontSector.FloorHeight
    else
      OpenBot := Ln.BackSector.FloorHeight;
    if OpenBot > FloorZ then
      FloorZ := OpenBot;
    if OpenTop < CeilZ then
      CeilZ := OpenTop;
  end;
end;

function TPlayer.ClipSector(World: TWorld; FloorH, CeilH: Integer): Boolean;
var
  OldZ, FloorZ, CeilZ, Support: Integer;
  WasOn: Boolean;
begin
  WasOn := Z <= FFloorZ;
  SectorFit(World, X, Y, FloorZ, CeilZ);
  if World = nil then
  begin
    FloorZ := FloorH;
    CeilZ := CeilH;
  end;
  Support := FloorH;
  if (FloorZ > Support) and (FloorZ - Z <= MAXSTEP) then
    Support := FloorZ;
  OldZ := Z;
  FFloorZ := Support;
  FCeilZ := CeilZ;
  if WasOn then
  begin
    Z := FFloorZ;
    FMomZ := 0;
  end
  else if Z < FFloorZ then
  begin
    Z := FFloorZ;
    if FMomZ < 0 then
      FMomZ := 0;
  end;
  if AsI32(Int64(Z) + PLAYER_HEIGHT) > FCeilZ then
  begin
    Z := AsI32(Int64(FCeilZ) - PLAYER_HEIGHT);
    if Z < FFloorZ then
      Z := FFloorZ;
    if FMomZ > 0 then
      FMomZ := 0;
  end;
  ViewZ := AsI32(Int64(ViewZ) + (Int64(Z) - OldZ));
  Result := (AsI32(Int64(FCeilZ) - FFloorZ) >= PLAYER_HEIGHT) and (Z >= FFloorZ) and
    (AsI32(Int64(Z) + PLAYER_HEIGHT) <= FCeilZ);
end;

procedure TPlayer.Place(NX, NY, FloorH, CeilH: Integer; NewAngle: Cardinal);
begin
  X := NX;
  Y := NY;
  Z := FloorH;
  FFloorZ := FloorH;
  FCeilZ := CeilH;
  FMomX := 0;
  FMomY := 0;
  FMomZ := 0;
  Angle := NewAngle;
  ViewZ := AsI32(Int64(Z) + FViewHeight);
end;

function TPlayer.Accepts(Options: Integer): Boolean;
begin
  Result := ((Options and FSkillBit) <> 0) and ((Options and 16) = 0);
end;

procedure TPlayer.Damage(Amount: Integer);
begin
  ApplyHit(Amount, 0, 0, False);
end;

procedure TPlayer.Damage(Amount, SrcX, SrcY: Integer);
begin
  ApplyHit(Amount, SrcX, SrcY, True);
end;

procedure TPlayer.ApplyHit(Amount, SrcX, SrcY: Integer; HasSrc: Boolean);
var
  Push, Saved: Integer;
  Ang: Cardinal;
begin
  if (Health <= 0) or (Amount <= 0) then
    Exit;
  if HasSrc and not NoClip then
  begin
    Ang := AimAngle(SrcX, SrcY, X, Y);
    if Amount > 80 then
      Push := 80 * (65536 div 4)
    else
      Push := Amount * (65536 div 4);
    FMomX := AsI32(Int64(FMomX) + FixedMul(Push, FineCos(Ang)));
    FMomY := AsI32(Int64(FMomY) + FixedMul(Push, FineSin(Ang)));
  end;
  if GodMode and (Amount < 1000) then
    Exit;
  Saved := 0;
  if ArmorType = 1 then
    Saved := Amount div 3
  else if ArmorType >= 2 then
    Saved := Amount div 2;
  if Saved > Armor then
  begin
    Saved := Armor;
    ArmorType := 0;
  end;
  Dec(Armor, Saved);
  Dec(Amount, Saved);
  if Amount < 0 then
    Amount := 0;
  Dec(Health, Amount);
  if Health < 0 then
    Health := 0;
  if Health <= 0 then
  begin
    PlaySfx('pldeth');
    if FViewHeight > 20 * 65536 then
      FViewHeight := 20 * 65536;
    ViewZ := AsI32(Int64(Z) + FViewHeight);
  end
  else
    PlaySfx('plpain');
  DamageCount := DamageCount + Amount;
  if (Amount > 0) and (DamageCount < 24) then
    DamageCount := 24;
  if DamageCount > 100 then
    DamageCount := 100;
end;

procedure TPlayer.SelectWeapon(Index: Integer);
begin
  if (Health <= 0) or (Index < 0) or (Index > 6) or (not Owned[Index]) or (Index = Weapon) then
    Exit;
  Weapon := Index;
  FRefire := 0;
  if FWeaponState <> WS_ATK then
  begin
    WeaponBody := GunName(0);
    FWeaponState := WS_READY;
  end;
end;

function TPlayer.ShownAmmo: Integer;
begin
  case Weapon of
    0: Result := 0;
    2: Result := Shells;
    4: Result := Rockets;
    5, 6: Result := Cells;
  else
    Result := Ammo;
  end;
end;

function TPlayer.HasAmmo: Boolean;
begin
  case Weapon of
    0: Result := True;
    2: Result := Shells > 0;
    4: Result := Rockets > 0;
    5, 6: Result := Cells > 0;
  else
    Result := Ammo > 0;
  end;
end;

function TPlayer.GunName(Kind: Integer): string;
begin
  case Weapon of
    0:
      case Kind of
        1: Result := 'PUNGB0';
        2: Result := 'PUNGC0';
        3: Result := '';
      else
        Result := 'PUNGA0';
      end;
    2:
      case Kind of
        1: Result := 'SHTGB0';
        2: Result := 'SHTGC0';
        3: Result := 'SHTFA0';
      else
        Result := 'SHTGA0';
      end;
    3:
      case Kind of
        1, 2: Result := 'CHGGB0';
        3: Result := 'CHGFA0';
      else
        Result := 'CHGGA0';
      end;
    4:
      case Kind of
        1, 2: Result := 'MISGB0';
        3: Result := 'MISFA0';
      else
        Result := 'MISGA0';
      end;
    5:
      case Kind of
        1, 2: Result := 'PLSGB0';
        3: Result := 'PLSFA0';
      else
        Result := 'PLSGA0';
      end;
    6:
      case Kind of
        1, 2: Result := 'BFGGB0';
        3: Result := 'BFGFA0';
      else
        Result := 'BFGGA0';
      end;
  else
    case Kind of
      1: Result := 'PISGB0';
      2: Result := 'PISGC0';
      3: Result := 'PISFA0';
    else
      Result := 'PISGA0';
    end;
  end;
end;

function TPlayer.AimAngle(X1, Y1, X2, Y2: Integer): Cardinal;
var
  Dx, Dy: Integer;
begin
  Dx := AsI32(Int64(X2) - X1);
  Dy := AsI32(Int64(Y2) - Y1);
  if (Dx = 0) and (Dy = 0) then
    Exit(0);
  if Dx >= 0 then
  begin
    if Dy >= 0 then
    begin
      if Dx > Dy then
        Exit(TanToAngle(SlopeDiv(Dy, Dx)));
      Exit(AsU32(Int64(ANG90) - 1 - TanToAngle(SlopeDiv(Dx, Dy))));
    end;
    Dy := -Dy;
    if Dx > Dy then
      Exit(AsU32(-Int64(TanToAngle(SlopeDiv(Dy, Dx)))));
    Exit(AsU32($C0000000 + Int64(TanToAngle(SlopeDiv(Dx, Dy)))));
  end;
  Dx := -Dx;
  if Dy >= 0 then
  begin
    if Dx > Dy then
      Exit(AsU32(Int64(ANG180) - 1 - TanToAngle(SlopeDiv(Dy, Dx))));
    Exit(AsU32(Int64(ANG90) + TanToAngle(SlopeDiv(Dx, Dy))));
  end;
  Dy := -Dy;
  if Dx > Dy then
    Exit(AsU32(Int64(ANG180) + TanToAngle(SlopeDiv(Dy, Dx))));
  Result := AsU32($C0000000 - 1 - Int64(TanToAngle(SlopeDiv(Dx, Dy))));
end;

procedure TPlayer.ArmThings(World: TWorld);
var
  I, Frame, Height, Flags, Radius, Hp: Integer;
  Spr: string;
  Th: TMapThing;
begin
  for I := 0 to World.ThingCount - 1 do
  begin
    Th := World.ThingAt(I);
    Th.Dead := False;
    Th.FrameUse := -1;
    if not ThingInfo(Th.ThingType, Spr, Frame, Height, Flags, Radius, Hp) then
    begin
      Th.Radius := 0;
      Th.ActorFlags := 0;
      Th.Health := 0;
      Continue;
    end;
    Th.Radius := Radius;
    Th.BodyHeight := Height;
    Th.ActorFlags := Flags;
    Th.Health := Hp;
  end;
end;

procedure TPlayer.Spawn(World: TWorld; Skill: Integer);
var
  Sub: TSubsector;
  I: Integer;
begin
  FSkill := Skill;
  FSkillBit := SkillBitOf(Skill);
  X := World.PlayerViewX;
  Y := World.PlayerViewY;
  Angle := World.PlayerViewAngle;
  FMomX := 0;
  FMomY := 0;
  FMomZ := 0;
  FViewHeight := VIEW_H;
  FDeltaView := 0;
  FBob := 0;
  FLevelTime := 0;
  FTurnHeld := 0;
  FRefire := 0;
  FShotNow := False;
  FWeaponState := WS_UP;
  FWeaponStep := 0;
  FWeaponTics := 0;
  FFlashTics := 0;
  Health := 100;
  Ammo := 50;
  Shells := 0;
  Rockets := 0;
  Cells := 0;
  Armor := 0;
  ArmorType := 0;
  MaxClip := 200;
  MaxShell := 50;
  MaxRocket := 50;
  MaxCell := 300;
  BonusCount := 0;
  Weapon := 1;
  for I := 0 to 6 do
    Owned[I] := False;
  Owned[0] := True;
  Owned[1] := True;
  FMelee := False;
  Cards[0] := False;
  Cards[1] := False;
  Cards[2] := False;
  Cards[3] := False;
  Cards[4] := False;
  Cards[5] := False;
  FMsg := '';
  FMsgTic := 0;
  Kills := 0;
  Secrets := 0;
  DamageCount := 0;
  LightBoost := 0;
  WeaponBody := 'PISGA0';
  WeaponFlash := '';
  WeaponSx := 65536;
  WeaponSy := WEAPON_BOTTOM;
  Sub := World.PointInSubsector(X, Y);
  if (Sub <> nil) and (Sub.Sector <> nil) then
  begin
    FFloorZ := Sub.Sector.FloorHeight;
    FCeilZ := Sub.Sector.CeilingHeight;
  end
  else
  begin
    FFloorZ := 0;
    FCeilZ := 128 * 65536;
  end;
  Z := FFloorZ;
  ViewZ := AsI32(Int64(Z) + VIEW_H);
  ArmThings(World);
end;

procedure TPlayer.Thrust(Ang: Cardinal; Move: Integer);
begin
  FMomX := AsI32(Int64(FMomX) + FixedMul(Move, FineCos(Ang)));
  FMomY := AsI32(Int64(FMomY) + FixedMul(Move, FineSin(Ang)));
end;

function TPlayer.LineSide(Px, Py: Integer; Ln: TLine): Integer;
var
  Dx, Dy: Integer;
begin
  if (Ln = nil) or (Ln.V1 = nil) then
    Exit(0);
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

function TPlayer.BoxSide(L, R, B, T: Integer; Ln: TLine): Integer;
var
  P1, P2: Integer;
begin
  if Ln.Dx = 0 then
  begin
    if R < Ln.V1.X then
      P1 := 0
    else
      P1 := 1;
    if L < Ln.V1.X then
      P2 := 0
    else
      P2 := 1;
    if Ln.Dy > 0 then
    begin
      P1 := P1 xor 1;
      P2 := P2 xor 1;
    end;
  end
  else if Ln.Dy = 0 then
  begin
    if T > Ln.V1.Y then
      P1 := 0
    else
      P1 := 1;
    if B > Ln.V1.Y then
      P2 := 0
    else
      P2 := 1;
    if Ln.Dx < 0 then
    begin
      P1 := P1 xor 1;
      P2 := P2 xor 1;
    end;
  end
  else if ((Ln.Dy > 0) = (Ln.Dx > 0)) then
  begin
    P1 := LineSide(L, T, Ln);
    P2 := LineSide(R, B, Ln);
  end
  else
  begin
    P1 := LineSide(R, T, Ln);
    P2 := LineSide(L, B, Ln);
  end;
  if P1 = P2 then
    Result := P1
  else
    Result := -1;
end;

function TPlayer.WallStops(Ln: TLine; AtZ, Slope, Dist: Integer): Boolean;
var
  OpenTop, OpenBot, ZAt: Integer;
  Front, Back: TSector;
begin
  Result := True;
  if (Ln = nil) or (Ln.BackSector = nil) or (Ln.FrontSector = nil) then
    Exit;
  Front := Ln.FrontSector;
  Back := Ln.BackSector;
  if Front.CeilingHeight < Back.CeilingHeight then
    OpenTop := Front.CeilingHeight
  else
    OpenTop := Back.CeilingHeight;
  if Front.FloorHeight > Back.FloorHeight then
    OpenBot := Front.FloorHeight
  else
    OpenBot := Back.FloorHeight;
  ZAt := AsI32(Int64(AtZ) + FixedMul(Slope, Dist));
  if (Ln.Flags and ML_BLOCKING) <> 0 then
    Exit;
  if OpenTop - OpenBot < PLAYER_HEIGHT then
    Exit;
  if ZAt >= OpenTop then
    Exit;
  if ZAt <= OpenBot then
    Exit;
  Result := False;
end;

function TPlayer.CanOccupy(World: TWorld; NX, NY: Integer): Boolean;
var
  Sub: TSubsector;
  L, R, B, T, I, OpenTop, OpenBot,   FloorZ, CeilZ: Integer;
  Ln: TLine;
  Th: TMapThing;
  Tx, Ty, Reach, Dx1, Dy1, Dx2, Dy2, OldD, NewD: Int64;
begin
  if NoClip then
    Exit(True);
  Result := False;
  Sub := World.PointInSubsector(NX, NY);
  if (Sub = nil) or (Sub.Sector = nil) then
    Exit;
  FloorZ := Sub.Sector.FloorHeight;
  CeilZ := Sub.Sector.CeilingHeight;
  L := AsI32(Int64(NX) - PLAYER_RADIUS);
  R := AsI32(Int64(NX) + PLAYER_RADIUS);
  B := AsI32(Int64(NY) - PLAYER_RADIUS);
  T := AsI32(Int64(NY) + PLAYER_RADIUS);
  for I := 0 to World.LineCount - 1 do
  begin
    Ln := World.LineAt(I);
    if (Ln = nil) or (Ln.V1 = nil) then
      Continue;
    if (R <= Ln.BBox[0]) or (L >= Ln.BBox[1]) or (T <= Ln.BBox[2]) or (B >= Ln.BBox[3]) then
      Continue;
    if BoxSide(L, R, B, T, Ln) <> -1 then
      Continue;
    if (Ln.BackSector = nil) or (Ln.FrontSector = nil) then
      Exit;
    if (Ln.Flags and ML_BLOCKING) <> 0 then
      Exit;
    if Ln.FrontSector.CeilingHeight < Ln.BackSector.CeilingHeight then
      OpenTop := Ln.FrontSector.CeilingHeight
    else
      OpenTop := Ln.BackSector.CeilingHeight;
    if Ln.FrontSector.FloorHeight > Ln.BackSector.FloorHeight then
      OpenBot := Ln.FrontSector.FloorHeight
    else
      OpenBot := Ln.BackSector.FloorHeight;
    if OpenTop - OpenBot < PLAYER_HEIGHT then
      Exit;
    if OpenBot > FloorZ then
      FloorZ := OpenBot;
    if OpenTop < CeilZ then
      CeilZ := OpenTop;
  end;
  if CeilZ - FloorZ < PLAYER_HEIGHT then
    Exit;
  if FloorZ - Z > MAXSTEP then
    Exit;
  if CeilZ - Z < PLAYER_HEIGHT then
    Exit;
  for I := 0 to World.ThingCount - 1 do
  begin
    Th := World.ThingAt(I);
    if Th.Dead or ((Th.ActorFlags and MF_SOLID) = 0) then
      Continue;
    if (Th.ThingType <= 4) or (Th.ThingType = 11) then
      Continue;
    if (Th.Options and FSkillBit) = 0 then
      Continue;
    if (Th.Options and 16) <> 0 then
      Continue;
    Tx := Int64(Th.X) * 65536;
    Ty := Int64(Th.Y) * 65536;
    Reach := Int64(Th.Radius) + PLAYER_RADIUS;
    if (Abs(Tx - NX) >= Reach) or (Abs(Ty - NY) >= Reach) then
      Continue;
    Dx1 := Tx - X;
    Dy1 := Ty - Y;
    Dx2 := Tx - NX;
    Dy2 := Ty - NY;
    OldD := Dx1 * Dx1 + Dy1 * Dy1;
    NewD := Dx2 * Dx2 + Dy2 * Dy2;
    if (OldD < Reach * Reach) and (NewD > OldD) then
      Continue;
    Exit;
  end;
  FFloorZ := FloorZ;
  FCeilZ := CeilZ;
  Result := True;
end;

function TPlayer.SegHit(X1, Y1, X2, Y2: Integer; Ln: TLine; out Along: Integer): Boolean;
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

procedure TPlayer.Slide(World: TWorld; StepX, StepY: Integer);
var
  HitCount, Along, Best, Side, Mx, My, Frac, Remain, NX, NY: Integer;
  LeadX, LeadY, TrailX, TrailY, OpenTop, OpenBot: Integer;
  Ln, Hit: TLine;
  LineAng, MoveAng, Delta: Cardinal;
  NewLen: Integer;

  function SlideBlocks(Line: TLine): Boolean;
  begin
    Result := False;
    if (Line = nil) or (Line.V1 = nil) or (Line.V2 = nil) then
      Exit;
    if (Line.BackSector = nil) or (Line.FrontSector = nil) then
    begin
      Result := LineSide(X, Y, Line) = 0;
      Exit;
    end;
    if Line.FrontSector.CeilingHeight < Line.BackSector.CeilingHeight then
      OpenTop := Line.FrontSector.CeilingHeight
    else
      OpenTop := Line.BackSector.CeilingHeight;
    if Line.FrontSector.FloorHeight > Line.BackSector.FloorHeight then
      OpenBot := Line.FrontSector.FloorHeight
    else
      OpenBot := Line.BackSector.FloorHeight;
    if OpenTop - OpenBot < PLAYER_HEIGHT then
      Result := True
    else if OpenTop - Z < PLAYER_HEIGHT then
      Result := True
    else if OpenBot - Z > MAXSTEP then
      Result := True
    else if (Line.Flags and ML_BLOCKING) <> 0 then
      Result := True;
  end;

  procedure TraceCorner(X1, Y1: Integer);
  var
    N: Integer;
  begin
    for N := 0 to World.LineCount - 1 do
    begin
      Ln := World.LineAt(N);
      if not SegHit(X1, Y1, AsI32(Int64(X1) + Mx), AsI32(Int64(Y1) + My), Ln, Along) then
        Continue;
      if (Along < 0) or (Along > 65536) or not SlideBlocks(Ln) then
        Continue;
      if Along < Best then
      begin
        Best := Along;
        Hit := Ln;
      end;
    end;
  end;

  procedure StairStep;
  begin
    if CanOccupy(World, X, AsI32(Int64(Y) + FMomY)) then
      Y := AsI32(Int64(Y) + FMomY)
    else if CanOccupy(World, AsI32(Int64(X) + FMomX), Y) then
      X := AsI32(Int64(X) + FMomX);
  end;

begin
  FMomX := StepX;
  FMomY := StepY;
  HitCount := 0;
  while True do
  begin
    Inc(HitCount);
    if HitCount = 3 then
    begin
      StairStep;
      Exit;
    end;
    Mx := FMomX;
    My := FMomY;
    if Mx > 0 then
    begin
      LeadX := AsI32(Int64(X) + PLAYER_RADIUS);
      TrailX := AsI32(Int64(X) - PLAYER_RADIUS);
    end
    else
    begin
      LeadX := AsI32(Int64(X) - PLAYER_RADIUS);
      TrailX := AsI32(Int64(X) + PLAYER_RADIUS);
    end;
    if My > 0 then
    begin
      LeadY := AsI32(Int64(Y) + PLAYER_RADIUS);
      TrailY := AsI32(Int64(Y) - PLAYER_RADIUS);
    end
    else
    begin
      LeadY := AsI32(Int64(Y) - PLAYER_RADIUS);
      TrailY := AsI32(Int64(Y) + PLAYER_RADIUS);
    end;
    Best := 65536 + 1;
    Hit := nil;
    TraceCorner(LeadX, LeadY);
    TraceCorner(TrailX, LeadY);
    TraceCorner(LeadX, TrailY);
    if Hit = nil then
    begin
      StairStep;
      Exit;
    end;
    Frac := Best - $800;
    if Frac > 0 then
    begin
      NX := AsI32(Int64(X) + FixedMul(Mx, Frac));
      NY := AsI32(Int64(Y) + FixedMul(My, Frac));
      if not CanOccupy(World, NX, NY) then
      begin
        StairStep;
        Exit;
      end;
      X := NX;
      Y := NY;
    end;
    Remain := 65536 - Best;
    if Remain > 65536 then
      Remain := 65536;
    if Remain <= 0 then
      Exit;
    Mx := FixedMul(FMomX, Remain);
    My := FixedMul(FMomY, Remain);
    if Hit.Dy = 0 then
      My := 0
    else if Hit.Dx = 0 then
      Mx := 0
    else
    begin
      Side := LineSide(X, Y, Hit);
      LineAng := AimAngle(0, 0, Hit.Dx, Hit.Dy);
      if Side = 1 then
        LineAng := AsU32(Int64(LineAng) + ANG180);
      MoveAng := AimAngle(0, 0, Mx, My);
      Delta := AsU32(Int64(MoveAng) - LineAng);
      if Delta > ANG180 then
        Delta := AsU32(Int64(Delta) + ANG180);
      NewLen := FixedMul(ApproxLen(Mx, My), FineCos(Delta));
      Mx := FixedMul(NewLen, FineCos(LineAng));
      My := FixedMul(NewLen, FineSin(LineAng));
    end;
    FMomX := Mx;
    FMomY := My;
    NX := AsI32(Int64(X) + Mx);
    NY := AsI32(Int64(Y) + My);
    if CanOccupy(World, NX, NY) then
    begin
      X := NX;
      Y := NY;
      Exit;
    end;
  end;
end;

procedure TPlayer.MoveXY(World: TWorld);
var
  LeftX, LeftY, StepX, StepY, Half, NX, NY: Integer;
begin
  if FMomX > MAXMOVE then
    FMomX := MAXMOVE
  else if FMomX < -MAXMOVE then
    FMomX := -MAXMOVE;
  if FMomY > MAXMOVE then
    FMomY := MAXMOVE
  else if FMomY < -MAXMOVE then
    FMomY := -MAXMOVE;
  LeftX := FMomX;
  LeftY := FMomY;
  Half := MAXMOVE div 2;
  while (LeftX <> 0) or (LeftY <> 0) do
  begin
    if LeftX > Half then
      StepX := Half
    else if LeftX < -Half then
      StepX := -Half
    else
      StepX := LeftX;
    if LeftY > Half then
      StepY := Half
    else if LeftY < -Half then
      StepY := -Half
    else
      StepY := LeftY;
    LeftX := LeftX - StepX;
    LeftY := LeftY - StepY;
    NX := AsI32(Int64(X) + StepX);
    NY := AsI32(Int64(Y) + StepY);
    if CanOccupy(World, NX, NY) then
    begin
      X := NX;
      Y := NY;
    end
    else
    begin
      Slide(World, StepX, StepY);
      Break;
    end;
  end;
  if Z > FFloorZ then
    Exit;
  if (Abs(FMomX) < STOPSPEED) and (Abs(FMomY) < STOPSPEED) then
  begin
    FMomX := 0;
    FMomY := 0;
  end
  else
  begin
    FMomX := FixedMul(FMomX, FRICTION);
    FMomY := FixedMul(FMomY, FRICTION);
  end;
end;

procedure TPlayer.FollowFloor(World: TWorld);
var
  Sub: TSubsector;
begin
  if (World = nil) or not NoClip then
    Exit;
  Sub := World.PointInSubsector(X, Y);
  if (Sub = nil) or (Sub.Sector = nil) then
    Exit;
  FFloorZ := Sub.Sector.FloorHeight;
  FCeilZ := Sub.Sector.CeilingHeight;
  Z := FFloorZ;
  FMomZ := 0;
end;

procedure TPlayer.ApplyZ;
begin
  if Z < FFloorZ then
  begin
    FViewHeight := AsI32(Int64(FViewHeight) - (Int64(FFloorZ) - Z));
    FDeltaView := SHar32(AsI32(Int64(VIEW_H) - FViewHeight), 3);
  end;
  Z := AsI32(Int64(Z) + FMomZ);
  if Z <= FFloorZ then
  begin
    if FMomZ < -GRAVITY * 8 then
      FDeltaView := SHar32(FMomZ, 3);
    if FMomZ < 0 then
      FMomZ := 0;
    Z := FFloorZ;
  end
  else
  begin
    if FMomZ = 0 then
      FMomZ := -GRAVITY * 2
    else
      FMomZ := AsI32(Int64(FMomZ) - GRAVITY);
  end;
  if AsI32(Int64(Z) + PLAYER_HEIGHT) > FCeilZ then
  begin
    if FMomZ > 0 then
      FMomZ := 0;
    Z := AsI32(Int64(FCeilZ) - PLAYER_HEIGHT);
  end;
end;

procedure TPlayer.HurtThing(Th: TMapThing);
begin
  Strike(Th, 5 * (RandByte mod 3 + 1));
end;

procedure TPlayer.Strike(Th: TMapThing; Amount: Integer);
var
  SprName: string;
  SprFrame, SprH, SprFlags, SprRad, SprHp: Integer;
begin
  if (Th = nil) or (Amount <= 0) then
    Exit;
  if Th.Health > 0 then
    Dec(Th.Health, Amount);
  if Th.Health > 0 then
  begin
    case Th.ThingType of
      3004, 9, 84, 3001: PlaySfxAt('popain', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
      3002, 58, 3003: PlaySfxAt('dmpain', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
    end;
    if Th.Ai = 1 then
    begin
      Th.Ai := 2;
      Th.MoveDir := 8;
      Th.MoveCount := 0;
      Th.FrameUse := 0;
    end;
    Exit;
  end;
  if not Th.Dead then
  begin
    if (Th.ActorFlags and $400000) <> 0 then
      Inc(Kills)
    else if ThingInfo(Th.ThingType, SprName, SprFrame, SprH, SprFlags, SprRad, SprHp) and
      ((SprFlags and $400000) <> 0) then
      Inc(Kills);
  end;
  if Th.Dead then
    Exit;
  Th.Health := 0;
  Th.Dead := True;
  Th.ActorFlags := Th.ActorFlags and not MF_SOLID;
  Th.Ai := 6;
  case Th.ThingType of
    3004, 9, 84:
      begin
        Th.FrameUse := 7;
        Th.Tics := 5;
      end;
    3001:
      begin
        Th.FrameUse := 8;
        Th.Tics := 8;
      end;
    3002, 58:
      begin
        Th.FrameUse := 8;
        Th.Tics := 8;
      end;
    3003, 69:
      begin
        Th.FrameUse := 8;
        Th.Tics := 8;
      end;
    2035:
      begin
        Th.SprName := 'BEXP';
        Th.SprFrame := 0;
        Th.FrameUse := 0;
        Th.Tics := 5;
        Th.Ai := 7;
        PlaySfxAt('barexp', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
      end;
  else
    begin
      Th.Ai := 0;
      if Th.FrameUse < 0 then
        Th.FrameUse := 0;
    end;
  end;
  case Th.ThingType of
    3004, 84:
      case RandByte mod 3 of
        0: PlaySfxAt('podth1', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
        1: PlaySfxAt('podth2', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
      else
        PlaySfxAt('podth3', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
      end;
    9: PlaySfxAt('podth2', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
    3001:
      if RandByte mod 2 = 0 then
        PlaySfxAt('bgdth1', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y)
      else
        PlaySfxAt('bgdth2', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
    3002, 58: PlaySfxAt('sgtdth', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
    3003: PlaySfxAt('brsdth', AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536), X, Y);
  end;
end;

procedure TPlayer.Shoot(World: TWorld; Accurate: Boolean);
var
  Ang: Cardinal;
  ShotX, ShotY, ShootZ, I, Along, BestWall, BestThing, Dist, Slope, Window, ThingZ: Integer;
  Dx, Dy: Int64;
  Ln, HitLn: TLine;
  Th, HitTh: TMapThing;
  Tx, Ty, Reach, Closest, Side: Int64;
  Sub: TSubsector;
begin
  Ang := Angle;
  if not Accurate then
    Ang := AsU32(Int64(Angle) + Int64(RandByte - RandByte) * 262144);
  ShotX := AsI32(Int64(X) + Int64(SHar32(MISSILERANGE, 16)) * FineCos(Ang));
  ShotY := AsI32(Int64(Y) + Int64(SHar32(MISSILERANGE, 16)) * FineSin(Ang));
  ShootZ := AsI32(Int64(Z) + (PLAYER_HEIGHT div 2) + 8 * 65536);
  Window := (100 * 65536) div 160;
  BestWall := 65536 + 1;
  HitLn := nil;
  for I := 0 to World.LineCount - 1 do
  begin
    Ln := World.LineAt(I);
    if not SegHit(X, Y, ShotX, ShotY, Ln, Along) then
      Continue;
    if (Along < 0) or (Along >= BestWall) then
      Continue;
    Dist := FixedMul(MISSILERANGE, Along);
    if not WallStops(Ln, ShootZ, 0, Dist) then
      Continue;
    BestWall := Along;
    HitLn := Ln;
  end;
  BestThing := 65536 + 1;
  HitTh := nil;
  Dx := Int64(SHar32(ShotX, 16) - SHar32(X, 16));
  Dy := Int64(SHar32(ShotY, 16) - SHar32(Y, 16));
  if Dx * Dx + Dy * Dy = 0 then
    Exit;
  for I := 0 to World.ThingCount - 1 do
  begin
    Th := World.ThingAt(I);
    if Th.Dead or ((Th.ActorFlags and MF_SHOOTABLE) = 0) or (Th.Health <= 0) then
      Continue;
    if (Th.ThingType <= 4) or (Th.ThingType = 11) then
      Continue;
    if (Th.Options and FSkillBit) = 0 then
      Continue;
    Closest := ((Int64(Th.X - SHar32(X, 16)) * Dx + Int64(Th.Y - SHar32(Y, 16)) * Dy) * 65536) div
      (Dx * Dx + Dy * Dy);
    if (Closest <= 0) or (Closest >= 65536) or (Closest >= BestThing) then
      Continue;
    Side := Th.X - (SHar32(X, 16) + (Closest * Dx) div 65536);
    Reach := Th.Y - (SHar32(Y, 16) + (Closest * Dy) div 65536);
    if Side * Side + Reach * Reach > Int64(SHar32(Th.Radius, 16)) * SHar32(Th.Radius, 16) then
      Continue;
    Dist := FixedMul(MISSILERANGE, Integer(Closest));
    if Dist < 65536 then
      Dist := 65536;
    if FMelee and (Dist > 64 * 65536) then
      Continue;
    Tx := Int64(Th.X) * 65536;
    Ty := Int64(Th.Y) * 65536;
    Sub := World.PointInSubsector(AsI32(Tx), AsI32(Ty));
    if (Sub = nil) or (Sub.Sector = nil) then
      Continue;
    if (Th.ActorFlags and 256) <> 0 then
      ThingZ := AsI32(Int64(Sub.Sector.CeilingHeight) - Th.BodyHeight)
    else
      ThingZ := Sub.Sector.FloorHeight;
    Slope := FixedDiv(AsI32(Int64(ThingZ) + (Th.BodyHeight div 2) - ShootZ), Dist);
    if (Slope > Window) or (Slope < -Window) then
    begin
      if (ShootZ < ThingZ) or (ShootZ > ThingZ + Th.BodyHeight) then
        Continue;
      Slope := 0;
    end;
    if (Closest >= BestWall) and (HitLn <> nil) and
      WallStops(HitLn, ShootZ, Slope, FixedMul(MISSILERANGE, BestWall)) then
      Continue;
    BestThing := Integer(Closest);
    HitTh := Th;
  end;
  if HitTh <> nil then
    HurtThing(HitTh)
  else
    ShotLine := HitLn;
end;

procedure TPlayer.EnterGunStep(Held: Boolean);
var
  N, W: Integer;
  St: TGunStep;
begin
  W := Weapon;
  if (W < 0) or (W > 6) then
    W := 1;
  N := GUN_LEN[W];
  while True do
  begin
    if FWeaponStep >= N then
    begin
      if Held and HasAmmo then
      begin
        FWeaponStep := 0;
        Continue;
      end;
      FWeaponState := WS_READY;
      WeaponBody := GunName(0);
      WeaponSy := WEAPON_TOP;
      if not Held then
        FRefire := 0;
      Exit;
    end;
    St := GUN_ATK[W, FWeaponStep];
    if Held and (W = 5) and (FWeaponStep = 1) then
    begin
      FWeaponStep := 0;
      Continue;
    end;
    WeaponBody := St.Body;
    WeaponSy := WEAPON_TOP;
    FWeaponTics := St.Tics;
    if St.FlashTics > 0 then
    begin
      WeaponFlash := St.Flash;
      FFlashTics := St.FlashTics;
    end;
    if St.Light > 0 then
      LightBoost := St.Light;
    if St.DoFire and HasAmmo then
      FShotNow := True;
    if (W = 5) and St.DoFire then
    begin
      if (RandByte and 1) <> 0 then
        WeaponFlash := 'PLSFB0'
      else
        WeaponFlash := 'PLSFA0';
      FFlashTics := 4;
    end;
    Exit;
  end;
end;

procedure TPlayer.WeaponTick(Fire: Boolean);
var
  WantFire: Boolean;
begin
  if Health <= 0 then
  begin
    WeaponSy := AsI32(Int64(WeaponSy) + 4 * 65536);
    if WeaponSy > WEAPON_BOTTOM then
      WeaponSy := WEAPON_BOTTOM;
    if FFlashTics > 0 then
    begin
      Dec(FFlashTics);
      if FFlashTics <= 0 then
      begin
        WeaponFlash := '';
        LightBoost := 0;
      end;
    end;
    Exit;
  end;
  if FFlashTics > 0 then
  begin
    Dec(FFlashTics);
    if FFlashTics <= 0 then
    begin
      WeaponFlash := '';
      LightBoost := 0;
    end;
  end;
  WantFire := Fire and (Health > 0) and HasAmmo;
  if FWeaponState = WS_UP then
  begin
    WeaponBody := GunName(0);
    WeaponSy := AsI32(Int64(WeaponSy) - 6 * 65536);
    if WeaponSy <= WEAPON_TOP then
    begin
      WeaponSy := WEAPON_TOP;
      FWeaponState := WS_READY;
    end;
    Exit;
  end;
  if FWeaponState = WS_ATK then
  begin
    if FWeaponTics > 0 then
      Dec(FWeaponTics);
    if FWeaponTics > 0 then
      Exit;
    Inc(FWeaponStep);
    EnterGunStep(WantFire);
    Exit;
  end;
  WeaponBody := GunName(0);
  WeaponSy := WEAPON_TOP;
  if WantFire and (((Weapon <> 4) and (Weapon <> 6)) or (FRefire = 0)) then
  begin
    FWeaponState := WS_ATK;
    FWeaponStep := 0;
    EnterGunStep(True);
  end
  else if not Fire then
    FRefire := 0;
end;

procedure TPlayer.Tick(World: TWorld; Up, Down, Left, Right, Fire, Run, Strafe, SideL, SideR: Boolean);
var
  Speed, TurnSpeed, BobAng, N, Pellets: Integer;
  Forward, Side, Turn: Integer;
  OnGround: Boolean;
  BobAdd: Integer;
begin
  Inc(FLevelTime);
  if DamageCount > 0 then
    Dec(DamageCount);
  if BonusCount > 0 then
    Dec(BonusCount);
  ShotLine := nil;
  Fired := False;
  if Health <= 0 then
  begin
    if FViewHeight > 6 * 65536 then
      FViewHeight := AsI32(Int64(FViewHeight) - 4 * 65536);
    if FViewHeight < 6 * 65536 then
      FViewHeight := 6 * 65536;
    FDeltaView := 0;
    if (FMomX <> 0) or (FMomY <> 0) then
      MoveXY(World);
    FollowFloor(World);
    ApplyZ;
    ViewZ := AsI32(Int64(Z) + FViewHeight);
    if (FCeilZ > Z + 8 * 65536) and (ViewZ > FCeilZ - 4 * 65536) then
      ViewZ := AsI32(Int64(FCeilZ) - 4 * 65536);
    WeaponTick(False);
    Exit;
  end;
  if Run then
    Speed := 1
  else
    Speed := 0;
  if Left or Right then
    Inc(FTurnHeld)
  else
    FTurnHeld := 0;
  if FTurnHeld < 6 then
    TurnSpeed := 2
  else
    TurnSpeed := Speed;
  Forward := 0;
  Side := 0;
  Turn := 0;
  if Strafe then
  begin
    if Right then
      Inc(Side, SIDEMOVE[Speed]);
    if Left then
      Dec(Side, SIDEMOVE[Speed]);
  end
  else
  begin
    if Right then
      Dec(Turn, ANGLETURN[TurnSpeed]);
    if Left then
      Inc(Turn, ANGLETURN[TurnSpeed]);
  end;
  if Up then
    Inc(Forward, FORWARDMOVE[Speed]);
  if Down then
    Dec(Forward, FORWARDMOVE[Speed]);
  if SideL then
    Dec(Side, SIDEMOVE[Speed]);
  if SideR then
    Inc(Side, SIDEMOVE[Speed]);
  Angle := AsU32(Int64(Angle) + Int64(Turn) shl 16);
  OnGround := Z <= FFloorZ;
  if OnGround and (Forward <> 0) then
    Thrust(Angle, Forward * 2048);
  if OnGround and (Side <> 0) then
    Thrust(AsU32(Int64(Angle) - ANG90), Side * 2048);
  if (FMomX <> 0) or (FMomY <> 0) then
    MoveXY(World);
  FollowFloor(World);
  ApplyZ;
  FViewHeight := AsI32(Int64(FViewHeight) + FDeltaView);
  if FViewHeight > VIEW_H then
  begin
    FViewHeight := VIEW_H;
    FDeltaView := 0;
  end;
  if FViewHeight < VIEW_H div 2 then
  begin
    FViewHeight := VIEW_H div 2;
    if FDeltaView <= 0 then
      FDeltaView := 1;
  end;
  if FDeltaView <> 0 then
  begin
    FDeltaView := AsI32(Int64(FDeltaView) + 65536 div 4);
    if FDeltaView = 0 then
      FDeltaView := 1;
  end;
  FBob := (FixedMul(FMomX, FMomX) + FixedMul(FMomY, FMomY)) div 4;
  if FBob > MAXBOB then
    FBob := MAXBOB;
  BobAng := ((8192 div 20) * FLevelTime) and 8191;
  BobAdd := FixedMul(FBob div 2, FineSin(Cardinal(BobAng) shl 19));
  ViewZ := AsI32(Int64(Z) + FViewHeight + BobAdd);
  if ViewZ > FCeilZ - 4 * 65536 then
    ViewZ := AsI32(Int64(FCeilZ) - 4 * 65536);
  BobAng := (128 * FLevelTime) and 8191;
  WeaponSx := AsI32(65536 + FixedMul(FBob, FineSin(Cardinal((BobAng + 2048) and 8191) shl 19)));
  WeaponTick(Fire);
  if FShotNow then
  begin
    FShotNow := False;
    if HasAmmo then
    begin
      case Weapon of
        2: Dec(Shells);
        4: Dec(Rockets);
        5, 6: Dec(Cells);
        0: ;
      else
        Dec(Ammo);
      end;
      if Weapon = 4 then
        Launch(World, 'MISL', 20, 20)
      else if Weapon = 5 then
        Launch(World, 'PLSS', 25, 5)
      else
      begin
        Pellets := 1;
        if Weapon = 2 then
          Pellets := 7;
        FMelee := Weapon = 0;
        for N := 1 to Pellets do
          Shoot(World, (FRefire = 0) and (Weapon <> 0) and (Weapon <> 2));
        FMelee := False;
      end;
      Fired := True;
      case Weapon of
        0: PlaySfx('punch');
        2: PlaySfx('shotgn');
        3: PlaySfx('pistol');
        4: PlaySfx('rlaunc');
        5: PlaySfx('plasma');
        6: PlaySfx('bfg');
      else
        PlaySfx('pistol');
      end;
      Inc(FRefire);
    end;
  end;
  if FWeaponState = WS_READY then
    WeaponSy := AsI32(Int64(WEAPON_TOP) + FixedMul(FBob, FineSin(Cardinal((BobAng and 4095)) shl 19)))
  else if FWeaponState = WS_ATK then
    WeaponSy := WEAPON_TOP;
  CheckSecret(World);
end;

procedure TPlayer.CheckSecret(World: TWorld);
var
  Sub: TSubsector;
begin
  if (World = nil) or (Health <= 0) then
    Exit;
  Sub := World.PointInSubsector(X, Y);
  if (Sub = nil) or (Sub.Sector = nil) or (Z <> Sub.Sector.FloorHeight) then
    Exit;
  if Sub.Sector.Special = 9 then
  begin
    Inc(Secrets);
    Sub.Sector.Special := 0;
    Exit;
  end;
  if (FLevelTime and 31) <> 0 then
    Exit;
  case Sub.Sector.Special of
    7: Damage(5);
    5: Damage(10);
    4, 16, 11: Damage(20);
  end;
end;

procedure TPlayer.Launch(World: TWorld; const Sprite: string; Speed, Dmg: Integer);
var
  Ball, Th: TMapThing;
  Sub: TSubsector;
  Ang: Cardinal;
  I, Fx, Fy, Best, Fwd, Side, Rad, Slope, Sl, ShootZ, ThingZ, Window: Integer;
begin
  if World = nil then
    Exit;
  Ang := Angle;
  Fx := FineCos(Ang);
  Fy := FineSin(Ang);
  ShootZ := AsI32(Int64(Z) + 32 * 65536);
  Window := (100 * 65536) div 160;
  Best := 1024;
  Slope := 0;
  for I := 0 to World.ThingCount - 1 do
  begin
    Th := World.ThingAt(I);
    if (Th = nil) or Th.Dead or (Th.Health <= 0) or ((Th.ActorFlags and MF_SHOOTABLE) = 0) then
      Continue;
    if (Th.ThingType <= 4) or (Th.ThingType = 11) or (Th.Ai = 4) then
      Continue;
    if (Th.Options and FSkillBit) = 0 then
      Continue;
    Fwd := Integer((Int64(Th.X - SHar32(X, 16)) * Fx + Int64(Th.Y - SHar32(Y, 16)) * Fy) div 65536);
    if (Fwd < 32) or (Fwd >= Best) then
      Continue;
    Side := Integer((Int64(Th.Y - SHar32(Y, 16)) * Fx - Int64(Th.X - SHar32(X, 16)) * Fy) div 65536);
    Rad := Th.Radius shr 16;
    if Rad < 16 then
      Rad := 20;
    if Abs(Side) > Rad then
      Continue;
    Sub := World.PointInSubsector(AsI32(Int64(Th.X) * 65536), AsI32(Int64(Th.Y) * 65536));
    if (Sub = nil) or (Sub.Sector = nil) then
      Continue;
    if (Th.ActorFlags and 256) <> 0 then
      ThingZ := AsI32(Int64(Sub.Sector.CeilingHeight) - Th.BodyHeight)
    else
      ThingZ := Sub.Sector.FloorHeight;
    if Th.BodyHeight > 65536 then
      ThingZ := AsI32(Int64(ThingZ) + Th.BodyHeight div 2);
    Sl := FixedDiv(AsI32(Int64(ThingZ) - ShootZ), Fwd * 65536);
    if (Sl > Window) or (Sl < -Window) then
      Continue;
    Best := Fwd;
    Slope := Sl;
  end;
  Ball := TMapThing.Create;
  Ball.Angle := Integer((Int64(Ang) * 360) shr 32);
  Ball.X := SHar32(X, 16) + Integer((Int64(Speed) * Fx) div 65536);
  Ball.Y := SHar32(Y, 16) + Integer((Int64(Speed) * Fy) div 65536);
  Ball.ThingType := 0;
  Ball.Options := 7;
  Ball.SprName := Sprite;
  Ball.SprFrame := 0;
  Ball.FrameUse := 0;
  Ball.Ai := 4;
  Ball.HasZ := True;
  Ball.FromPlayer := True;
  Ball.MissileDmg := Dmg;
  Ball.MomX := Integer((Int64(Speed) * Fx) div 65536);
  Ball.MomY := Integer((Int64(Speed) * Fy) div 65536);
  Ball.MomZ := Integer(Int64(Speed) * Slope);
  Ball.Z := AsI32(Int64(ShootZ) + Ball.MomZ div 2);
  Ball.Radius := 8 * 65536;
  World.AddThing(Ball);
end;

end.
