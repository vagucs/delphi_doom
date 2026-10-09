unit Doom.AutoMap;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Mapa do jogo, a partir de doom/am_map.py. Tab abre e fecha.
  So as paredes ja vistas entram, ate o truque iddt.
}

interface

uses
  System.SysUtils, Doom.World, Doom.Player;

type
  TAutomap = class
  public
    Active: Boolean;
    Cheat: Integer;
    constructor Create;
    procedure ResetLevel;
    procedure Toggle;
    procedure Zoom(Inward: Boolean);
    procedure Fit(World: TWorld);
    procedure Pan(World: TWorld; DX, DY: Integer);
    procedure ToggleFollow(Player: TPlayer);
    procedure ToggleGrid(Player: TPlayer);
    function Eat(Key: Word; const Ch: string; World: TWorld; Player: TPlayer): Boolean;
    procedure Draw(var Fb: TBytes; World: TWorld; Player: TPlayer; ViewH: Integer);
  private
    FFollow: Boolean;
    FGrid: Boolean;
    FZoom: Integer;
    FFocusX: Integer;
    FFocusY: Integer;
    FMinX: Integer;
    FMinY: Integer;
    FMaxX: Integer;
    FMaxY: Integer;
    FHaveBox: Boolean;
    procedure Box(World: TWorld);
    function ProjX(V: Integer): Integer;
    function ProjY(V, H: Integer): Integer;
    procedure Plot(var Fb: TBytes; X, Y, Color, H: Integer);
    procedure Line(var Fb: TBytes; X0, Y0, X1, Y1, Color, H: Integer);
  end;

implementation

uses
  System.UITypes, Doom.Tables, Doom.VVideo;

const
  RED = 176;
  GRAY = 96;
  BROWN = 64;
  YELLOW = 231;
  GREEN = 112;
  WHITE = 209;
  GRID = 104;

constructor TAutomap.Create;
begin
  inherited Create;
  FFollow := True;
  FZoom := 4096;
end;

procedure TAutomap.ResetLevel;
begin
  Active := False;
  Cheat := 0;
  FFollow := True;
  FHaveBox := False;
end;

procedure TAutomap.Box(World: TWorld);
var
  I: Integer;
  Ln: TLine;
begin
  if (World = nil) or (World.LineCount <= 0) then
    Exit;
  FMinX := MaxInt;
  FMinY := MaxInt;
  FMaxX := -MaxInt;
  FMaxY := -MaxInt;
  for I := 0 to World.LineCount - 1 do
  begin
    Ln := World.LineAt(I);
    if (Ln = nil) or (Ln.V1 = nil) or (Ln.V2 = nil) then
      Continue;
    if Ln.V1.X < FMinX then
      FMinX := Ln.V1.X;
    if Ln.V2.X < FMinX then
      FMinX := Ln.V2.X;
    if Ln.V1.Y < FMinY then
      FMinY := Ln.V1.Y;
    if Ln.V2.Y < FMinY then
      FMinY := Ln.V2.Y;
    if Ln.V1.X > FMaxX then
      FMaxX := Ln.V1.X;
    if Ln.V2.X > FMaxX then
      FMaxX := Ln.V2.X;
    if Ln.V1.Y > FMaxY then
      FMaxY := Ln.V1.Y;
    if Ln.V2.Y > FMaxY then
      FMaxY := Ln.V2.Y;
  end;
  FHaveBox := FMaxX > FMinX;
end;

procedure TAutomap.Fit(World: TWorld);
var
  W, H, Zx, Zy: Integer;
begin
  Box(World);
  if not FHaveBox then
    Exit;
  W := FMaxX - FMinX;
  H := FMaxY - FMinY;
  if W < 1 then
    W := 1;
  if H < 1 then
    H := 1;
  Zx := Integer((Int64(280) * 65536) div W);
  Zy := Integer((Int64(140) * 65536) div H);
  if Zx < Zy then
    FZoom := Zx
  else
    FZoom := Zy;
  if FZoom < 256 then
    FZoom := 256;
  FFocusX := (FMinX + FMaxX) div 2;
  FFocusY := (FMinY + FMaxY) div 2;
  FFollow := True;
end;

procedure TAutomap.Toggle;
begin
  Active := not Active;
end;

procedure TAutomap.Zoom(Inward: Boolean);
begin
  if Inward then
    FZoom := Integer((Int64(FZoom) * 66846) div 65536)
  else
    FZoom := Integer((Int64(FZoom) * 64250) div 65536);
  if FZoom < 256 then
    FZoom := 256;
  if FZoom > 262144 then
    FZoom := 262144;
end;

procedure TAutomap.Pan(World: TWorld; DX, DY: Integer);
var
  Step: Integer;
begin
  FFollow := False;
  if FZoom < 1 then
    FZoom := 1;
  Step := Integer((Int64(24) * 65536) div FZoom);
  FFocusX := FFocusX + DX * Step;
  FFocusY := FFocusY + DY * Step;
  if World <> nil then
    Box(World);
end;

procedure TAutomap.ToggleFollow(Player: TPlayer);
begin
  FFollow := not FFollow;
  if Player <> nil then
  begin
    if FFollow then
      Player.Say('Follow Mode ON')
    else
      Player.Say('Follow Mode OFF');
  end;
end;

procedure TAutomap.ToggleGrid(Player: TPlayer);
begin
  FGrid := not FGrid;
  if Player <> nil then
  begin
    if FGrid then
      Player.Say('Grid ON')
    else
      Player.Say('Grid OFF');
  end;
end;

function TAutomap.Eat(Key: Word; const Ch: string; World: TWorld; Player: TPlayer): Boolean;
begin
  Result := False;
  if not Active then
  begin
    if Key = vkTab then
    begin
      if not FHaveBox then
        Fit(World);
      Active := True;
      Result := True;
    end;
    Exit;
  end;
  if Key = vkTab then
  begin
    Active := False;
    Exit(True);
  end;
  if (Ch = '+') or (Ch = '=') then
  begin
    Zoom(True);
    Exit(True);
  end;
  if (Ch = '-') or (Ch = '_') then
  begin
    Zoom(False);
    Exit(True);
  end;
  if Ch = '0' then
  begin
    Fit(World);
    Exit(True);
  end;
  if (Ch = 'f') or (Ch = 'F') then
  begin
    ToggleFollow(Player);
    Exit(True);
  end;
  if (Ch = 'g') or (Ch = 'G') then
  begin
    ToggleGrid(Player);
    Exit(True);
  end;
  if not FFollow then
  begin
    if Key = vkLeft then
    begin
      Pan(World, -1, 0);
      Exit(True);
    end;
    if Key = vkRight then
    begin
      Pan(World, 1, 0);
      Exit(True);
    end;
    if Key = vkUp then
    begin
      Pan(World, 0, 1);
      Exit(True);
    end;
    if Key = vkDown then
    begin
      Pan(World, 0, -1);
      Exit(True);
    end;
  end;
end;

function TAutomap.ProjX(V: Integer): Integer;
begin
  Result := 160 + Integer((Int64(V - FFocusX) * FZoom) div 65536);
end;

function TAutomap.ProjY(V, H: Integer): Integer;
begin
  Result := (H div 2) - Integer((Int64(V - FFocusY) * FZoom) div 65536);
end;

procedure TAutomap.Plot(var Fb: TBytes; X, Y, Color, H: Integer);
var
  Dest: Integer;
begin
  if (X < 0) or (X >= SCREENWIDTH) or (Y < 0) or (Y >= H) then
    Exit;
  Dest := Y * SCREENWIDTH + X;
  if (Dest >= 0) and (Dest < Length(Fb)) then
    Fb[Dest] := Byte(Color);
end;

procedure TAutomap.Line(var Fb: TBytes; X0, Y0, X1, Y1, Color, H: Integer);
var
  DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X1 - X0);
  DY := Abs(Y1 - Y0);
  if X0 < X1 then
    SX := 1
  else
    SX := -1;
  if Y0 < Y1 then
    SY := 1
  else
    SY := -1;
  Err := DX - DY;
  while True do
  begin
    Plot(Fb, X0, Y0, Color, H);
    if (X0 = X1) and (Y0 = Y1) then
      Break;
    E2 := 2 * Err;
    if E2 > -DY then
    begin
      Err := Err - DY;
      X0 := X0 + SX;
    end;
    if E2 < DX then
    begin
      Err := Err + DX;
      Y0 := Y0 + SY;
    end;
  end;
end;

procedure TAutomap.Draw(var Fb: TBytes; World: TWorld; Player: TPlayer; ViewH: Integer);
var
  I, X, Y, Color, AX, AY, BX, BY, H, Step, N: Integer;
  Ln: TLine;
  Th: TMapThing;
  Seen: Boolean;
  C, S: Integer;
begin
  if not Active or (World = nil) or (Length(Fb) < SCREENPIXELS) then
    Exit;
  if not FHaveBox then
    Fit(World);
  H := ViewH;
  if H > SCREENHEIGHT then
    H := SCREENHEIGHT;
  if H < 8 then
    H := SCREENHEIGHT;
  if (Player <> nil) and FFollow then
  begin
    FFocusX := Player.X;
    FFocusY := Player.Y;
  end;
  for Y := 0 to H - 1 do
    for X := 0 to SCREENWIDTH - 1 do
      Fb[Y * SCREENWIDTH + X] := 0;
  if FGrid and FHaveBox and (FZoom > 0) then
  begin
    Step := 128 * 65536;
    X := FMinX;
    N := 0;
    while (X <= FMaxX) and (N < 80) do
    begin
      Line(Fb, ProjX(X), 0, ProjX(X), H - 1, GRID, H);
      X := X + Step;
      Inc(N);
    end;
    Y := FMinY;
    N := 0;
    while (Y <= FMaxY) and (N < 80) do
    begin
      Line(Fb, 0, ProjY(Y, H), SCREENWIDTH - 1, ProjY(Y, H), GRID, H);
      Y := Y + Step;
      Inc(N);
    end;
  end;
  for I := 0 to World.LineCount - 1 do
  begin
    Ln := World.LineAt(I);
    if (Ln = nil) or (Ln.V1 = nil) or (Ln.V2 = nil) then
      Continue;
    Seen := (Ln.Flags and 256) <> 0;
    if (not Seen) and (Cheat = 0) then
      Continue;
    if ((Ln.Flags and 128) <> 0) and (Cheat = 0) then
      Continue;
    if Ln.BackSector = nil then
      Color := RED
    else if Ln.FrontSector = nil then
      Continue
    else if (Ln.Flags and 32) <> 0 then
      Color := RED
    else if Ln.BackSector.FloorHeight <> Ln.FrontSector.FloorHeight then
      Color := BROWN
    else if Ln.BackSector.CeilingHeight <> Ln.FrontSector.CeilingHeight then
      Color := YELLOW
    else if Cheat <> 0 then
      Color := GRAY
    else
      Continue;
    Line(Fb, ProjX(Ln.V1.X), ProjY(Ln.V1.Y, H), ProjX(Ln.V2.X), ProjY(Ln.V2.Y, H), Color, H);
  end;
  if Cheat >= 2 then
    for I := 0 to World.ThingCount - 1 do
    begin
      Th := World.ThingAt(I);
      if (Th = nil) or (Th.ThingType = 1) then
        Continue;
      AX := ProjX(Th.X * 65536);
      AY := ProjY(Th.Y * 65536, H);
      Plot(Fb, AX, AY, GREEN, H);
      Plot(Fb, AX - 1, AY, GREEN, H);
      Plot(Fb, AX + 1, AY, GREEN, H);
    end;
  if Player <> nil then
  begin
    AX := ProjX(Player.X);
    AY := ProjY(Player.Y, H);
    C := FineCos(Player.Angle);
    S := FineSin(Player.Angle);
    BX := AX + (C * 10) div 65536;
    BY := AY - (S * 10) div 65536;
    Line(Fb, AX, AY, BX, BY, WHITE, H);
    Line(Fb, BX, BY, BX - (C * 6) div 65536 + (S * 4) div 65536,
      BY + (S * 6) div 65536 + (C * 4) div 65536, WHITE, H);
    Line(Fb, BX, BY, BX - (C * 6) div 65536 - (S * 4) div 65536,
      BY + (S * 6) div 65536 - (C * 4) div 65536, WHITE, H);
  end;
  Plot(Fb, 160, H div 2, GRAY, H);
end;

end.
