unit Doom.Status;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Barra de status, igual a doom/status.py.
}

interface

uses
  System.SysUtils, Doom.Wad, Doom.Player;

type
  TStatusBar = class
  public
    constructor Create(AWad: TWad);
    procedure Ticker(Player: TPlayer; AttackDown: Boolean);
    procedure Draw(var Fb: TBytes; Player: TPlayer);
    procedure Reset;
  private
    FWad: TWad;
    FSbar: TBytes;
    FTall: array[0..9] of TBytes;
    FShort: array[0..9] of TBytes;
    FPercent: TBytes;
    FKeys: array[0..5] of TBytes;
    FArmsBg: TBytes;
    FArmsOff: array[0..5] of TBytes;
    FFaces: array[0..41] of TBytes;
    FFallback: TBytes;
    FFont: array[0..62] of TBytes;
    FFaceIndex: Integer;
    FFaceCount: Integer;
    FFacePriority: Integer;
    FOldHealth: Integer;
    FPainHealth: Integer;
    FLastCalc: Integer;
    FLastAttack: Integer;
    FRnd: Cardinal;
    function Lump(const Name: string): TBytes;
    function PainOffset(Health: Integer): Integer;
    procedure DrawNum(var Fb: TBytes; X, Y, Value, Digits: Integer; const Font: array of TBytes);
    procedure DrawText(var Fb: TBytes; X, Y: Integer; const Text: string);
  end;

implementation

uses
  Doom.VVideo;

const
  ST_FACESTRIDE = 8;
  ST_TURNOFFSET = 3;
  ST_OUCHOFFSET = 5;
  ST_EVILGRINOFFSET = 6;
  ST_RAMPAGEOFFSET = 7;
  ST_GODFACE = 40;
  ST_DEADFACE = 41;
  ST_EVILGRINCOUNT = 70;
  ST_STRAIGHTFACECOUNT = 17;
  ST_TURNCOUNT = 35;
  ST_RAMPAGEDELAY = 70;
  ST_MUCHPAIN = 20;

constructor TStatusBar.Create(AWad: TWad);
var
  I, Pain, Look: Integer;
begin
  inherited Create;
  FWad := AWad;
  FOldHealth := -1;
  FPainHealth := -1;
  FLastAttack := -1;
  FRnd := 1;
  if FWad = nil then
    Exit;
  FSbar := Lump('STBAR');
  for I := 0 to 9 do
  begin
    FTall[I] := Lump('STTNUM' + IntToStr(I));
    FShort[I] := Lump('STYSNUM' + IntToStr(I));
  end;
  FPercent := Lump('STTPRCNT');
  for I := 0 to 5 do
    FKeys[I] := Lump('STKEYS' + IntToStr(I));
  FArmsBg := Lump('STARMS');
  for I := 0 to 5 do
    FArmsOff[I] := Lump('STGNUM' + IntToStr(I + 2));
  FFallback := Lump('STFST00');
  I := 0;
  for Pain := 0 to 4 do
  begin
    for Look := 0 to 2 do
    begin
      FFaces[I] := Lump('STFST' + IntToStr(Pain) + IntToStr(Look));
      Inc(I);
    end;
    FFaces[I] := Lump('STFTR' + IntToStr(Pain) + '0');
    Inc(I);
    FFaces[I] := Lump('STFTL' + IntToStr(Pain) + '0');
    Inc(I);
    FFaces[I] := Lump('STFOUCH' + IntToStr(Pain));
    Inc(I);
    FFaces[I] := Lump('STFEVL' + IntToStr(Pain));
    Inc(I);
    FFaces[I] := Lump('STFKILL' + IntToStr(Pain));
    Inc(I);
  end;
  FFaces[ST_GODFACE] := Lump('STFGOD0');
  FFaces[ST_DEADFACE] := Lump('STFDEAD0');
  for I := 0 to 62 do
    FFont[I] := Lump('STCFN' + Format('%.3d', [I + 33]));
end;

function TStatusBar.Lump(const Name: string): TBytes;
var
  N: Integer;
begin
  SetLength(Result, 0);
  if FWad = nil then
    Exit;
  N := FWad.CheckNumForName(Name);
  if N >= 0 then
    Result := FWad.CacheLumpNum(N);
end;

function TStatusBar.PainOffset(Health: Integer): Integer;
begin
  if Health < 0 then
    Health := 0;
  if Health > 100 then
    Health := 100;
  if Health <> FPainHealth then
  begin
    FLastCalc := ST_FACESTRIDE * ((100 - Health) * 5) div 101;
    FPainHealth := Health;
  end;
  Result := FLastCalc;
end;

procedure TStatusBar.Reset;
begin
  FFaceIndex := 0;
  FFaceCount := 0;
  FFacePriority := 0;
  FOldHealth := -1;
  FPainHealth := -1;
  FLastCalc := 0;
  FLastAttack := -1;
end;

procedure TStatusBar.Ticker(Player: TPlayer; AttackDown: Boolean);
var
  Rnd, Pain: Integer;
begin
  if Player = nil then
    Exit;
  if Player.GodMode and (Player.Health > 0) then
  begin
    FFacePriority := 10;
    FFaceIndex := ST_GODFACE;
    FFaceCount := 2;
  end
  else if FFaceIndex = ST_GODFACE then
  begin
    FFacePriority := 0;
    FFaceCount := 0;
    FFaceIndex := 0;
  end;
  FRnd := FRnd * 1103515245 + 12345;
  Rnd := (FRnd shr 16) and 255;
  if (FFacePriority < 10) and (Player.Health <= 0) then
  begin
    FFacePriority := 9;
    FFaceIndex := ST_DEADFACE;
    FFaceCount := 1;
  end;
  if (FFacePriority < 7) and (Player.DamageCount > 0) then
  begin
    Pain := PainOffset(Player.Health);
    if Player.Health - FOldHealth > ST_MUCHPAIN then
    begin
      FFacePriority := 7;
      FFaceCount := ST_TURNCOUNT;
      FFaceIndex := Pain + ST_OUCHOFFSET;
    end
    else
    begin
      FFacePriority := 6;
      FFaceCount := ST_TURNCOUNT;
      FFaceIndex := Pain + ST_RAMPAGEOFFSET;
    end;
  end;
  if FFacePriority < 6 then
  begin
    if AttackDown then
    begin
      if FLastAttack = -1 then
        FLastAttack := ST_RAMPAGEDELAY
      else
      begin
        Dec(FLastAttack);
        if FLastAttack = 0 then
        begin
          FFacePriority := 5;
          FFaceIndex := PainOffset(Player.Health) + ST_RAMPAGEOFFSET;
          FFaceCount := 1;
          FLastAttack := 1;
        end;
      end;
    end
    else
      FLastAttack := -1;
  end;
  if FFaceCount = 0 then
  begin
    FFaceIndex := PainOffset(Player.Health) + (Rnd mod 3);
    FFaceCount := ST_STRAIGHTFACECOUNT;
    FFacePriority := 0;
  end;
  Dec(FFaceCount);
  FOldHealth := Player.Health;
end;

procedure TStatusBar.DrawNum(var Fb: TBytes; X, Y, Value, Digits: Integer; const Font: array of TBytes);
var
  W, I: Integer;
begin
  if Length(Font[0]) < 4 then
    Exit;
  W := PatchWidth(Font[0]);
  if W < 1 then
    W := 4;
  Dec(X, W);
  if Value < 0 then
    Value := -Value;
  for I := 1 to Digits do
  begin
    DrawPatch(Fb, X, Y, Font[Value mod 10]);
    Dec(X, W);
    Value := Value div 10;
    if Value = 0 then
      Break;
  end;
end;

procedure TStatusBar.DrawText(var Fb: TBytes; X, Y: Integer; const Text: string);
var
  I, Idx, W: Integer;
  Ch: Char;
begin
  for I := 1 to Length(Text) do
  begin
    Ch := UpCase(Text[I]);
    Idx := Ord(Ch) - 33;
    if (Idx >= 0) and (Idx <= 62) and (Length(FFont[Idx]) >= 8) then
    begin
      DrawPatch(Fb, X, Y, FFont[Idx]);
      W := PatchWidth(FFont[Idx]);
      if W < 1 then
        W := 4;
      Inc(X, W);
    end
    else
      Inc(X, 4);
  end;
end;

procedure TStatusBar.Draw(var Fb: TBytes; Player: TPlayer);
var
  I, X, Y, Card: Integer;
  Face: TBytes;
begin
  if (Player = nil) or (Length(FSbar) < 8) then
    Exit;
  DrawPatch(Fb, 0, 168, FSbar);
  if Length(FArmsBg) >= 8 then
    DrawPatch(Fb, 104, 168, FArmsBg);
  DrawNum(Fb, 44, 171, Player.ShownAmmo, 3, FTall);
  DrawNum(Fb, 90, 171, Player.Health, 3, FTall);
  if Length(FPercent) >= 8 then
    DrawPatch(Fb, 90, 171, FPercent);
  DrawNum(Fb, 221, 171, Player.Armor, 3, FTall);
  if Length(FPercent) >= 8 then
    DrawPatch(Fb, 221, 171, FPercent);
  for I := 0 to 5 do
  begin
    X := 111 + (I mod 3) * 12;
    Y := 172 + (I div 3) * 10;
    if Player.Owned[I + 1] then
    begin
      if Length(FShort[0]) >= 4 then
        DrawNum(Fb, X + PatchWidth(FShort[0]), Y, I + 2, 1, FShort)
      else
        DrawNum(Fb, X + 4, Y, I + 2, 1, FShort);
    end
    else if Length(FArmsOff[I]) >= 8 then
      DrawPatch(Fb, X, Y, FArmsOff[I]);
  end;
  if (FFaceIndex >= 0) and (FFaceIndex <= 41) and (Length(FFaces[FFaceIndex]) >= 8) then
    Face := FFaces[FFaceIndex]
  else
    Face := FFallback;
  if Length(Face) >= 8 then
    DrawPatch(Fb, 143, 168, Face);
  for I := 0 to 2 do
  begin
    Card := I;
    if Player.Cards[I + 3] then
      Card := I + 3;
    if Player.Cards[I] or Player.Cards[I + 3] then
      if Length(FKeys[Card]) >= 8 then
        DrawPatch(Fb, 239, 171 + I * 10, FKeys[Card]);
  end;
  DrawNum(Fb, 288, 173, Player.Ammo, 3, FShort);
  DrawNum(Fb, 314, 173, Player.MaxClip, 3, FShort);
  DrawNum(Fb, 288, 179, Player.Shells, 3, FShort);
  DrawNum(Fb, 314, 179, Player.MaxShell, 3, FShort);
  DrawNum(Fb, 288, 191, Player.Cells, 3, FShort);
  DrawNum(Fb, 314, 191, Player.MaxCell, 3, FShort);
  DrawNum(Fb, 288, 185, Player.Rockets, 3, FShort);
  DrawNum(Fb, 314, 185, Player.MaxRocket, 3, FShort);
  if Player.Message <> '' then
    DrawText(Fb, 0, 0, Player.Message);
end;

end.
