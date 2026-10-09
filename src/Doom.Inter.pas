unit Doom.Inter;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Estatistica entre mapas, igual a doom/wi_stuff.py.
}

interface

uses
  System.SysUtils, Doom.Wad;

type
  TIntermission = class
  public
    Done: Boolean;
    constructor Create(AWad: TWad; Episode, MapN, NextMap, MaxKills, MaxItems, MaxSecrets,
      Kills, Items, Secrets, Tics: Integer; SecretExit, Commercial: Boolean);
    procedure Tick(Accelerate: Boolean);
    procedure Draw(var Fb: TBytes);
  private
    FWad: TWad;
    FEpsd: Integer;
    FLast: Integer;
    FNext: Integer;
    FMaxKills: Integer;
    FMaxItems: Integer;
    FMaxSecrets: Integer;
    FKills: Integer;
    FItems: Integer;
    FSecrets: Integer;
    FTime: Integer;
    FPar: Integer;
    FDidSecret: Boolean;
    FCommercial: Boolean;
    FState: Integer;
    FSpState: Integer;
    FCntKills: Integer;
    FCntItems: Integer;
    FCntSecret: Integer;
    FCntTime: Integer;
    FCntPar: Integer;
    FCntPause: Integer;
    FCnt: Integer;
    FBcnt: Integer;
    FPointer: Boolean;
    FAccelerate: Boolean;
    FRnd: Cardinal;
    FBg: TBytes;
    FNum: array[0..9] of TBytes;
    FNames: array[0..31] of TBytes;
    FFinished: TBytes;
    FEntering: TBytes;
    FKillsP: TBytes;
    FItemsP: TBytes;
    FSecretP: TBytes;
    FPercent: TBytes;
    FColon: TBytes;
    FTimeP: TBytes;
    FParP: TBytes;
    FSucks: TBytes;
    FYah: array[0..1] of TBytes;
    FSplat: TBytes;
    FAnims: array[0..15] of record
      Kind, Period, NAnims, X, Y, Data1, Ctr, NextTic: Integer;
      Patches: array[0..2] of TBytes;
    end;
    FAnimCount: Integer;
    function Lump(const Name: string): TBytes;
    function Rnd(N: Integer): Integer;
    function Pw(const Patch: TBytes): Integer;
    function Ph(const Patch: TBytes): Integer;
    procedure AddAnim(Kind, Period, NAnims, X, Y, Data1: Integer);
    procedure InitAnims;
    procedure UpdateAnims;
    procedure DrawNum(var Fb: TBytes; var X: Integer; Y, N, Digits: Integer);
    procedure DrawPercent(var Fb: TBytes; X, Y, Value: Integer);
    procedure DrawTime(var Fb: TBytes; X, Y, T: Integer);
    procedure DrawBg(var Fb: TBytes);
    procedure DrawOnNode(var Fb: TBytes; N: Integer; const A, B: TBytes);
  end;

implementation

uses
  Doom.VVideo, Doom.Sound;

const
  TICRATE = 35;
  STAT_COUNT = 0;
  SHOW_NEXT = 1;
  NO_STATE = -1;
  ANIM_ALWAYS = 0;
  ANIM_LEVEL = 2;
  PARS: array[1..3, 1..9] of Integer = (
    (30, 75, 120, 90, 165, 180, 180, 30, 165),
    (90, 90, 90, 120, 90, 360, 240, 30, 170),
    (90, 45, 90, 150, 90, 90, 165, 30, 135));
  CPARS: array[0..31] of Integer = (
    30, 90, 120, 120, 90, 150, 120, 120, 270, 90,
    210, 150, 150, 150, 210, 150, 420, 150, 210, 150,
    240, 150, 180, 150, 150, 300, 330, 420, 300, 180,
    120, 30);
  NODES: array[0..2, 0..8, 0..1] of Integer = (
    ((185, 164), (148, 143), (69, 122), (209, 102), (116, 89), (166, 55), (71, 56), (135, 29), (71, 24)),
    ((254, 25), (97, 50), (188, 64), (128, 78), (214, 92), (133, 130), (208, 136), (148, 140), (235, 158)),
    ((156, 168), (48, 154), (174, 95), (265, 75), (130, 48), (279, 23), (198, 48), (140, 25), (281, 136)));

function ParSeconds(Episode, MapN: Integer; Commercial: Boolean): Integer;
begin
  if Commercial then
  begin
    if MapN < 1 then
      MapN := 1;
    if MapN > 32 then
      MapN := 32;
    Exit(CPARS[MapN - 1]);
  end;
  if (Episode >= 1) and (Episode <= 3) and (MapN >= 1) and (MapN <= 9) then
    Exit(PARS[Episode, MapN]);
  Result := 30;
end;

constructor TIntermission.Create(AWad: TWad; Episode, MapN, NextMap, MaxKills, MaxItems, MaxSecrets,
  Kills, Items, Secrets, Tics: Integer; SecretExit, Commercial: Boolean);
var
  I, NMaps: Integer;
  Name: string;
begin
  inherited Create;
  FWad := AWad;
  FRnd := 1;
  if Episode < 1 then
    Episode := 1;
  FEpsd := Episode - 1;
  FLast := MapN - 1;
  FNext := NextMap - 1;
  FMaxKills := MaxKills;
  FMaxItems := MaxItems;
  FMaxSecrets := MaxSecrets;
  FKills := Kills;
  FItems := Items;
  FSecrets := Secrets;
  FTime := Tics;
  FPar := ParSeconds(Episode, MapN, Commercial) * TICRATE;
  FDidSecret := SecretExit;
  FCommercial := Commercial;
  FState := STAT_COUNT;
  FSpState := 1;
  FCntKills := -1;
  FCntItems := -1;
  FCntSecret := -1;
  FCntTime := -1;
  FCntPar := -1;
  FCntPause := TICRATE;
  FFinished := Lump('WIF');
  FEntering := Lump('WIENTER');
  FKillsP := Lump('WIOSTK');
  FItemsP := Lump('WIOSTI');
  FSecretP := Lump('WISCRT2');
  FPercent := Lump('WIPCNT');
  FColon := Lump('WICOLON');
  FTimeP := Lump('WITIME');
  FParP := Lump('WIPAR');
  FSucks := Lump('WISUCKS');
  FYah[0] := Lump('WIURH0');
  FYah[1] := Lump('WIURH1');
  FSplat := Lump('WISPLAT');
  for I := 0 to 9 do
    FNum[I] := Lump('WINUM' + IntToStr(I));
  if Commercial or (FEpsd = 3) then
    FBg := Lump('INTERPIC')
  else
    FBg := Lump('WIMAP' + IntToStr(FEpsd));
  if Length(FBg) < 8 then
    FBg := Lump('INTERPIC');
  if Commercial then
    NMaps := 32
  else
    NMaps := 9;
  for I := 0 to NMaps - 1 do
  begin
    if Commercial then
      Name := Format('CWILV%.2d', [I])
    else
      Name := 'WILV' + IntToStr(FEpsd) + IntToStr(I);
    FNames[I] := Lump(Name);
  end;
  InitAnims;
end;

function TIntermission.Lump(const Name: string): TBytes;
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

function TIntermission.Rnd(N: Integer): Integer;
begin
  FRnd := FRnd * 1664525 + 1013904223;
  if N <= 1 then
    Exit(0);
  Result := Integer((FRnd shr 16) mod Cardinal(N));
end;

function TIntermission.Pw(const Patch: TBytes): Integer;
begin
  if Length(Patch) < 2 then
    Exit(8);
  Result := PatchWidth(Patch);
  if Result < 1 then
    Result := 8;
end;

function TIntermission.Ph(const Patch: TBytes): Integer;
begin
  if Length(Patch) < 4 then
    Exit(16);
  Result := Patch[2] or (Patch[3] shl 8);
  if Result >= 32768 then
    Dec(Result, 65536);
  if Result < 1 then
    Result := 16;
end;

procedure TIntermission.AddAnim(Kind, Period, NAnims, X, Y, Data1: Integer);
var
  I: Integer;
begin
  if FAnimCount > 15 then
    Exit;
  FAnims[FAnimCount].Kind := Kind;
  FAnims[FAnimCount].Period := Period;
  FAnims[FAnimCount].NAnims := NAnims;
  FAnims[FAnimCount].X := X;
  FAnims[FAnimCount].Y := Y;
  FAnims[FAnimCount].Data1 := Data1;
  FAnims[FAnimCount].Ctr := -1;
  for I := 0 to 2 do
    SetLength(FAnims[FAnimCount].Patches[I], 0);
  Inc(FAnimCount);
end;

procedure TIntermission.InitAnims;
var
  I, J: Integer;
begin
  FAnimCount := 0;
  if FCommercial or (FEpsd > 2) then
    Exit;
  if FEpsd = 0 then
  begin
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 224, 104, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 184, 160, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 112, 136, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 72, 112, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 88, 96, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 64, 48, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 192, 40, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 136, 16, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 80, 16, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 64, 24, 0);
  end
  else if FEpsd = 1 then
  begin
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 1);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 2);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 3);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 4);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 5);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 6);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 7);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 192, 144, 8);
    AddAnim(ANIM_LEVEL, TICRATE div 3, 1, 128, 136, 8);
  end
  else
  begin
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 104, 168, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 40, 136, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 160, 96, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 104, 80, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 3, 3, 120, 32, 0);
    AddAnim(ANIM_ALWAYS, TICRATE div 4, 3, 40, 0, 0);
  end;
  for J := 0 to FAnimCount - 1 do
  begin
    FAnims[J].Ctr := -1;
    if FAnims[J].Kind = ANIM_ALWAYS then
      FAnims[J].NextTic := FBcnt + 1 + Rnd(FAnims[J].Period)
    else
      FAnims[J].NextTic := FBcnt + 1;
    for I := 0 to FAnims[J].NAnims - 1 do
    begin
      if (FEpsd = 1) and (J = 8) and (FAnimCount > 4) then
        FAnims[J].Patches[I] := FAnims[4].Patches[I]
      else if I <= 2 then
        FAnims[J].Patches[I] := Lump(Format('WIA%d%.2d%.2d', [FEpsd, J, I]));
    end;
  end;
end;

procedure TIntermission.UpdateAnims;
var
  I: Integer;
begin
  if FCommercial or (FEpsd > 2) then
    Exit;
  for I := 0 to FAnimCount - 1 do
  begin
    if FBcnt <> FAnims[I].NextTic then
      Continue;
    if FAnims[I].Kind = ANIM_ALWAYS then
    begin
      Inc(FAnims[I].Ctr);
      if FAnims[I].Ctr >= FAnims[I].NAnims then
        FAnims[I].Ctr := 0;
      FAnims[I].NextTic := FBcnt + FAnims[I].Period;
    end
    else if (not ((FState = STAT_COUNT) and (I = 7))) and (FNext = FAnims[I].Data1) then
    begin
      Inc(FAnims[I].Ctr);
      if FAnims[I].Ctr = FAnims[I].NAnims then
        Dec(FAnims[I].Ctr);
      FAnims[I].NextTic := FBcnt + FAnims[I].Period;
    end;
  end;
end;

function Pct(Value, Maximum: Integer): Integer;
begin
  if Maximum < 1 then
    Maximum := 1;
  Result := (Value * 100) div Maximum;
end;

procedure TIntermission.Tick(Accelerate: Boolean);
var
  Target, TTime, PTime: Integer;
begin
  Inc(FBcnt);
  if FBcnt = 1 then
  begin
    if FCommercial then
      StartMusic('dm2int', True)
    else
      StartMusic('inter', True);
  end;
  if Accelerate then
    FAccelerate := True;
  if FState = SHOW_NEXT then
  begin
    UpdateAnims;
    Dec(FCnt);
    if (FCnt = 0) or FAccelerate then
    begin
      FState := NO_STATE;
      FAccelerate := False;
      FCnt := 10;
    end
    else
      FPointer := (FCnt and 31) < 20;
    Exit;
  end;
  if FState = NO_STATE then
  begin
    UpdateAnims;
    Dec(FCnt);
    if FCnt = 0 then
      Done := True;
    Exit;
  end;
  UpdateAnims;
  if FAccelerate and (FSpState <> 10) then
  begin
    FAccelerate := False;
    FCntKills := Pct(FKills, FMaxKills);
    FCntItems := Pct(FItems, FMaxItems);
    FCntSecret := Pct(FSecrets, FMaxSecrets);
    FCntTime := FTime div TICRATE;
    FCntPar := FPar div TICRATE;
    PlaySfx('barexp');
    FSpState := 10;
  end;
  if FSpState = 2 then
  begin
    Inc(FCntKills, 2);
    if (FBcnt and 3) = 0 then
      PlaySfx('pistol');
    Target := Pct(FKills, FMaxKills);
    if FCntKills >= Target then
    begin
      FCntKills := Target;
      PlaySfx('barexp');
      Inc(FSpState);
    end;
  end
  else if FSpState = 4 then
  begin
    Inc(FCntItems, 2);
    if (FBcnt and 3) = 0 then
      PlaySfx('pistol');
    Target := Pct(FItems, FMaxItems);
    if FCntItems >= Target then
    begin
      FCntItems := Target;
      PlaySfx('barexp');
      Inc(FSpState);
    end;
  end
  else if FSpState = 6 then
  begin
    Inc(FCntSecret, 2);
    if (FBcnt and 3) = 0 then
      PlaySfx('pistol');
    Target := Pct(FSecrets, FMaxSecrets);
    if FCntSecret >= Target then
    begin
      FCntSecret := Target;
      PlaySfx('barexp');
      Inc(FSpState);
    end;
  end
  else if FSpState = 8 then
  begin
    if (FBcnt and 3) = 0 then
      PlaySfx('pistol');
    Inc(FCntTime, 3);
    TTime := FTime div TICRATE;
    if FCntTime >= TTime then
      FCntTime := TTime;
    Inc(FCntPar, 3);
    PTime := FPar div TICRATE;
    if FCntPar >= PTime then
    begin
      FCntPar := PTime;
      if FCntTime >= TTime then
      begin
        PlaySfx('barexp');
        Inc(FSpState);
      end;
    end;
  end
  else if FSpState = 10 then
  begin
    if FAccelerate then
    begin
      PlaySfx('wpnup');
      FAccelerate := False;
      if FCommercial then
      begin
        FState := NO_STATE;
        FCnt := 10;
      end
      else
      begin
        FState := SHOW_NEXT;
        FCnt := 4 * TICRATE;
        InitAnims;
      end;
    end;
  end
  else if (FSpState and 1) <> 0 then
  begin
    Dec(FCntPause);
    if FCntPause = 0 then
    begin
      Inc(FSpState);
      FCntPause := TICRATE;
      if FSpState = 2 then
        FCntKills := 0
      else if FSpState = 4 then
        FCntItems := 0
      else if FSpState = 6 then
        FCntSecret := 0
      else if FSpState = 8 then
      begin
        FCntTime := 0;
        FCntPar := 0;
      end;
    end;
  end;
end;

procedure TIntermission.DrawNum(var Fb: TBytes; var X: Integer; Y, N, Digits: Integer);
var
  FontW, D: Integer;
  Neg: Boolean;
begin
  FontW := Pw(FNum[0]);
  if Digits < 0 then
  begin
    if N = 0 then
      Digits := 1
    else
    begin
      Digits := 0;
      D := Abs(N);
      while D > 0 do
      begin
        D := D div 10;
        Inc(Digits);
      end;
    end;
  end;
  Neg := N < 0;
  if Neg then
    N := -N;
  while Digits > 0 do
  begin
    Dec(Digits);
    Dec(X, FontW);
    D := N mod 10;
    if Length(FNum[D]) >= 8 then
      DrawPatch(Fb, X, Y, FNum[D]);
    N := N div 10;
  end;
end;

procedure TIntermission.DrawPercent(var Fb: TBytes; X, Y, Value: Integer);
begin
  if Value < 0 then
    Exit;
  if Length(FPercent) >= 8 then
    DrawPatch(Fb, X, Y, FPercent);
  DrawNum(Fb, X, Y, Value, -1);
end;

procedure TIntermission.DrawTime(var Fb: TBytes; X, Y, T: Integer);
var
  DivN, N: Integer;
begin
  if T < 0 then
    Exit;
  if T > 61 * 59 then
  begin
    if Length(FSucks) >= 8 then
      DrawPatch(Fb, X - Pw(FSucks), Y, FSucks);
    Exit;
  end;
  DivN := 1;
  while True do
  begin
    N := (T div DivN) mod 60;
    DrawNum(Fb, X, Y, N, 2);
    Dec(X, Pw(FColon));
    DivN := DivN * 60;
    if (DivN = 60) or (T div DivN > 0) then
      if Length(FColon) >= 8 then
        DrawPatch(Fb, X, Y, FColon);
    if T div DivN = 0 then
      Break;
  end;
end;

procedure TIntermission.DrawBg(var Fb: TBytes);
var
  I: Integer;
begin
  if Length(FBg) >= 8 then
    DrawPatch(Fb, 0, 0, FBg)
  else
    FillFb(Fb, 0);
  if FCommercial or (FEpsd > 2) then
    Exit;
  for I := 0 to FAnimCount - 1 do
    if (FAnims[I].Ctr >= 0) and (FAnims[I].Ctr <= 2) and (Length(FAnims[I].Patches[FAnims[I].Ctr]) >= 8) then
      DrawPatch(Fb, FAnims[I].X, FAnims[I].Y, FAnims[I].Patches[FAnims[I].Ctr]);
end;

procedure TIntermission.DrawOnNode(var Fb: TBytes; N: Integer; const A, B: TBytes);
var
  Left, Top, W, H: Integer;
  Patch: TBytes;
begin
  if (FEpsd < 0) or (FEpsd > 2) or (N < 0) or (N > 8) then
    Exit;
  if Length(A) >= 8 then
    Patch := A
  else
    Patch := B;
  if Length(Patch) < 8 then
    Exit;
  W := Pw(Patch);
  H := Ph(Patch);
  Left := NODES[FEpsd, N, 0];
  Top := NODES[FEpsd, N, 1];
  if Length(Patch) >= 8 then
  begin
    Left := Left - (SmallInt(Patch[4] or (Patch[5] shl 8)));
    Top := Top - (SmallInt(Patch[6] or (Patch[7] shl 8)));
  end;
  if (Left >= 0) and (Left + W < SCREENWIDTH) and (Top >= 0) and (Top + H < SCREENHEIGHT) then
    DrawPatch(Fb, NODES[FEpsd, N, 0], NODES[FEpsd, N, 1], Patch);
end;

procedure TIntermission.Draw(var Fb: TBytes);
var
  Y, Lh, I, Last, X: Integer;
begin
  DrawBg(Fb);
  if FState = STAT_COUNT then
  begin
    Y := 2;
    if (FLast >= 0) and (FLast <= 31) and (Length(FNames[FLast]) >= 8) then
    begin
      DrawPatch(Fb, (SCREENWIDTH - Pw(FNames[FLast])) div 2, Y, FNames[FLast]);
      Inc(Y, (5 * Ph(FNames[FLast])) div 4);
    end;
    if Length(FFinished) >= 8 then
      DrawPatch(Fb, (SCREENWIDTH - Pw(FFinished)) div 2, Y, FFinished);
    Lh := 24;
    if Length(FNum[0]) >= 8 then
      Lh := (3 * Ph(FNum[0])) div 2;
    if Length(FKillsP) >= 8 then
      DrawPatch(Fb, 50, 50, FKillsP);
    DrawPercent(Fb, SCREENWIDTH - 50, 50, FCntKills);
    if Length(FItemsP) >= 8 then
      DrawPatch(Fb, 50, 50 + Lh, FItemsP);
    DrawPercent(Fb, SCREENWIDTH - 50, 50 + Lh, FCntItems);
    if Length(FSecretP) >= 8 then
      DrawPatch(Fb, 50, 50 + 2 * Lh, FSecretP);
    DrawPercent(Fb, SCREENWIDTH - 50, 50 + 2 * Lh, FCntSecret);
    if Length(FTimeP) >= 8 then
      DrawPatch(Fb, 16, SCREENHEIGHT - 32, FTimeP);
    DrawTime(Fb, SCREENWIDTH div 2 - 16, SCREENHEIGHT - 32, FCntTime);
    if FEpsd < 3 then
    begin
      if Length(FParP) >= 8 then
        DrawPatch(Fb, SCREENWIDTH div 2 + 16, SCREENHEIGHT - 32, FParP);
      DrawTime(Fb, SCREENWIDTH - 16, SCREENHEIGHT - 32, FCntPar);
    end;
    Exit;
  end;
  if FState = NO_STATE then
    FPointer := True;
  if not FCommercial then
  begin
    if FEpsd <= 2 then
    begin
      if FLast = 8 then
        Last := FNext - 1
      else
        Last := FLast;
      for I := 0 to Last do
        DrawOnNode(Fb, I, FSplat, FSplat);
      if FDidSecret then
        DrawOnNode(Fb, 8, FSplat, FSplat);
      if FPointer then
        DrawOnNode(Fb, FNext, FYah[0], FYah[1]);
    end;
  end;
  if (not FCommercial) or (FNext <> 30) then
  begin
    Y := 2;
    if Length(FEntering) >= 8 then
    begin
      DrawPatch(Fb, (SCREENWIDTH - Pw(FEntering)) div 2, Y, FEntering);
      Inc(Y, (5 * Ph(FEntering)) div 4);
    end;
    if (FNext >= 0) and (FNext <= 31) and (Length(FNames[FNext]) >= 8) then
    begin
      X := (SCREENWIDTH - Pw(FNames[FNext])) div 2;
      DrawPatch(Fb, X, Y, FNames[FNext]);
    end;
  end;
end;

end.
