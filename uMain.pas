unit uMain;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  O form pinta o quadro de 320x200. Esc abre o menu.
  Novo jogo mostra a vista. As setas andam e viram, Ctrl atira.
  Espaco e E usam portas e interruptores. A saida carrega o mapa seguinte.
  No Android a tela fica deitada. Os botoes transparentes ficam sobre o jogo.
  Use age na fase e abre o menu no titulo. Fire atira.
  Menos e mais mudam o tamanho da janela. Alt+Enter alterna a tela cheia.
}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Objects,
  FMX.Layouts, FMX.ListBox, FMX.Edit, Doom.Wad, Doom.Menu, Doom.World, Doom.RData, Doom.Render,   Doom.Player,
  Doom.Specials, Doom.Enemy, Doom.Status, Doom.Wipe, Doom.Inter, Doom.AutoMap, Doom.Finale;

type
  TFormMain = class(TForm)
    ImageView: TImage;
    LayPad: TLayout;
    BtnUp: TButton;
    BtnDown: TButton;
    BtnLeft: TButton;
    BtnRight: TButton;
    BtnFire: TButton;
    BtnUse: TButton;
    BtnWeapon: TButton;
    BtnRun: TButton;
    BtnSide: TButton;
    BtnEsc: TButton;
    GameTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShown(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure PadDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure PadUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure GameTimerTimer(Sender: TObject);
  private
    FBmp: TBitmap;
    FWad: TWad;
    FHost: TDoomHost;
    FMenu: TDoomMenu;
    FWorld: TWorld;
    FRes: TResources;
    FRender: TRenderer;
    FPlayer: TPlayer;
    FSpecials: TSpecials;
    FEnemies: TEnemies;
    FUseEdge: Boolean;
    FUseDown: Boolean;
    FCarry: Boolean;
    FCarryHealth: Integer;
    FCarryAmmo: Integer;
    FCarryShells: Integer;
    FCarryRockets: Integer;
    FCarryCells: Integer;
    FCarryArmor: Integer;
    FCarryArmorType: Integer;
    FCarryWeapon: Integer;
    FCarryMaxClip: Integer;
    FCarryMaxShell: Integer;
    FCarryMaxRocket: Integer;
    FCarryMaxCell: Integer;
    FCarryOwned: array[0..6] of Boolean;
    FPadUp: Boolean;
    FPadDown: Boolean;
    FPadLeft: Boolean;
    FPadRight: Boolean;
    FPadFire: Boolean;
    FRunLock: Boolean;
    FSideLock: Boolean;
    FPick: TLayout;
    FPickList: TListBox;
    FPickUrl: TEdit;
    FPickUrlBack: TRectangle;
    FPickStatus: TLabel;
    FPickGet: TButton;
    FPickPlay: TButton;
    FPickTrack: TRectangle;
    FPickFill: TRectangle;
    FPicked: string;
    FGetting: Boolean;
    FDlTick: Cardinal;
    FDlTotal: Int64;
    FHoldUp: Boolean;
    FHoldDown: Boolean;
    FHoldLeft: Boolean;
    FHoldRight: Boolean;
    FHoldFire: Boolean;
    FHoldRun: Boolean;
    FHoldStrafe: Boolean;
    FHoldSideL: Boolean;
    FHoldSideR: Boolean;
    FFb: TBytes;
    FPage: TBytes;
    FPal: array[0..255] of TAlphaColor;
    FPlaypal: TBytes;
    FPalIndex: Integer;
    FSequence: Integer;
    FPageTic: Integer;
    FAdvance: Boolean;
    FHoldPage: Boolean;
    FWasLevel: Boolean;
    FStatus: TStatusBar;
    FWipe: TWipe;
    FInter: TIntermission;
    FWiping: Boolean;
    FWipeState: Integer;
    FMaxKills: Integer;
    FMaxItems: Integer;
    FMaxSecrets: Integer;
    FNextMap: Integer;
    FWasFire: Boolean;
    FWasUse: Boolean;
    FAuto: TAutomap;
    FFinale: TFinale;
    FWantFinale: Boolean;
    FFinaleMap: Integer;
    FCheat: string;
    FLoadName: string;
    FShowFps: Boolean;
    FFpsStamp: Cardinal;
    FFpsCount: Integer;
    FFpsShown: Integer;
    FFpsLabel: TLabel;
    FScale: Integer;
    FCrt: Boolean;
    FWantFull: Boolean;
    FNoMonsters: Boolean;
    FNoSound: Boolean;
    FNoMusic: Boolean;
    FIwad: string;
    FFiles: TArray<string>;
    FCrtMap: TArray<Word>;
    FCrtGain: TBytes;
    FCrtMask: array[0..2, 0..2] of Integer;
    FCrtW: Integer;
    FCrtH: Integer;
    FRgb: TBytes;
    FBlur: TBytes;
    FView: TBitmap;
    FWarpOn: Boolean;
    FWarpEpi: Integer;
    FWarpMap: Integer;
    FSkillOn: Boolean;
    FSkillArg: Integer;
    procedure LoadTitle;
    procedure ShowPage(const Name: string);
    procedure AdvanceDemo;
    procedure EnterLevel;
    procedure FinishLevel;
    procedure CountLevel;
    procedure Compose;
    procedure FeedKey(Key: Integer; const Ch: string);
    procedure PaintFrame;
    procedure ApplyPalette;
    procedure SyncHolds;
    procedure RememberCarry;
    procedure ReadArgs;
    procedure ApplyWindow;
    procedure LockLandscape;
    procedure StylePad(Btn: TButton);
    procedure PlacePad;
    procedure NextWeapon;
    procedure ShowToggle(Btn: TButton; On: Boolean);
    procedure StartGame;
    procedure BuildPicker;
    procedure PlacePick;
    procedure StyleUrlEdit(Sender: TObject);
    procedure RefreshWadList;
    procedure PickChanged(Sender: TObject);
    procedure PickPlay(Sender: TObject);
    procedure PickDownload(Sender: TObject);
    procedure SetPickStatus(const S: string);
    procedure ShowDl(ReadN, TotalN: Int64);
    procedure QueueDl(ReadN, TotalN: Int64);
    function DlPulse(ReadN, TotalN: Int64): Boolean;
    procedure DlReceive(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
    procedure ToggleFull;
    procedure ChangeScale(Delta: Integer);
    procedure BuildCrt(Dw, Dh: Integer);
    procedure PresentCrt;
    procedure PlaceFps;
    function LocateWad(const Spec: string): string;
    procedure StartFinale(FinishedMap: Integer; ContinueAfter: Boolean);
    procedure FeedCheat(const Ch: string);
    function DoSave(Slot: Integer; const Desc: string): Boolean;
    function DoLoad(Slot: Integer): Boolean;
    function DoRead(Slot: Integer; out Desc: string): Boolean;
    procedure ApplySave(const Path: string);
    function SavePath(Slot: Integer): string;
  end;

var
  FormMain: TFormMain;

implementation

uses
  System.Math, System.StrUtils, System.IOUtils, System.Net.HttpClient, Doom.Compat, Doom.VVideo, Doom.Sound
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF}
  {$IFDEF ANDROID}, Androidapi.Helpers, Androidapi.JNI.App, Androidapi.JNI.GraphicsContentViewText{$ENDIF};

const
  VK_COMMA = 188;
  VK_PERIOD = 190;
  VK_SPACE = 32;
  VK_E = 69;

function ScreenColor(const Data: TBitmapData; Color: TAlphaColor): TAlphaColor; forward;

type
  TWadStream = class(TFileStream)
  public
    Form: TFormMain;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

{$R *.fmx}

procedure TFormMain.RememberCarry;
var
  I: Integer;
begin
  if FPlayer = nil then
    Exit;
  FCarry := True;
  FCarryHealth := FPlayer.Health;
  FCarryAmmo := FPlayer.Ammo;
  FCarryShells := FPlayer.Shells;
  FCarryRockets := FPlayer.Rockets;
  FCarryCells := FPlayer.Cells;
  FCarryArmor := FPlayer.Armor;
  FCarryArmorType := FPlayer.ArmorType;
  FCarryWeapon := FPlayer.Weapon;
  FCarryMaxClip := FPlayer.MaxClip;
  FCarryMaxShell := FPlayer.MaxShell;
  FCarryMaxRocket := FPlayer.MaxRocket;
  FCarryMaxCell := FPlayer.MaxCell;
  for I := 0 to 6 do
    FCarryOwned[I] := FPlayer.Owned[I];
end;

procedure TFormMain.SyncHolds;
{$IFDEF MSWINDOWS}
  function Down(Code: Integer): Boolean;
  begin
    Result := (GetAsyncKeyState(Code) and $8000) <> 0;
  end;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  if (FAuto = nil) or not FAuto.Active then
  begin
    FHoldUp := FPadUp or Down(VK_UP);
    FHoldDown := FPadDown or Down(VK_DOWN);
    FHoldLeft := FPadLeft or Down(VK_LEFT);
    FHoldRight := FPadRight or Down(VK_RIGHT);
    FHoldSideL := Down(VK_COMMA);
    FHoldSideR := Down(VK_PERIOD);
  end;
  FHoldStrafe := Down(VK_MENU) or Down(VK_LMENU) or Down(VK_RMENU);
  FHoldRun := Down(VK_SHIFT) or Down(VK_LSHIFT) or Down(VK_RSHIFT);
  FHoldFire := FPadFire or Down(VK_CONTROL) or Down(VK_LCONTROL) or Down(VK_RCONTROL);
  {$ENDIF}
end;

procedure TFormMain.ApplyPalette;
var
  I, Cnt, R, G, B, Add, Gold: Integer;
begin
  if Length(FPlaypal) < 768 then
    Exit;
  Cnt := 0;
  Gold := 0;
  if (FPlayer <> nil) and (FHost <> nil) and (FHost.Gamestate = GS_LEVEL) then
  begin
    Cnt := FPlayer.DamageCount;
    if Cnt = 0 then
      Gold := FPlayer.BonusCount;
  end;
  Add := Cnt * 3;
  if Add > 180 then
    Add := 180;
  if Gold > 16 then
    Gold := 16;
  for I := 0 to 255 do
  begin
    R := FPlaypal[I * 3];
    G := FPlaypal[I * 3 + 1];
    B := FPlaypal[I * 3 + 2];
    if Add > 0 then
    begin
      Inc(R, Add);
      if R > 255 then
        R := 255;
      Dec(G, Add div 2);
      if G < 0 then
        G := 0;
      Dec(B, Add div 2);
      if B < 0 then
        B := 0;
    end
    else if Gold > 0 then
    begin
      Inc(R, Gold * 4);
      if R > 255 then
        R := 255;
      Inc(G, Gold * 3);
      if G > 255 then
        G := 255;
      Dec(B, Gold * 2);
      if B < 0 then
        B := 0;
    end;
    FPal[I] := $FF000000 or (Cardinal(R) shl 16) or (Cardinal(G) shl 8) or Cardinal(B);
  end;
end;

function EndsWith(const S, Tail: string): Boolean;
begin
  Result := (Length(S) >= Length(Tail)) and (Copy(S, Length(S) - Length(Tail) + 1, Length(Tail)) = Tail);
end;

function SavePathOf(Slot: Integer): string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'doomsav' + IntToStr(Slot) + '.sav';
end;

function NextInt(const S: string; var At: Integer): Integer;
var
  P: Integer;
begin
  while (At <= Length(S)) and (S[At] = ' ') do
    Inc(At);
  P := At;
  while (At <= Length(S)) and (S[At] <> ' ') do
    Inc(At);
  Result := StrToIntDef(Copy(S, P, At - P), 0);
end;

function TFormMain.SavePath(Slot: Integer): string;
begin
  Result := SavePathOf(Slot);
end;

function TFormMain.DoRead(Slot: Integer; out Desc: string): Boolean;
var
  L: TStringList;
begin
  Result := False;
  Desc := '';
  if (Slot < 0) or (Slot > 5) or not FileExists(SavePath(Slot)) then
    Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(SavePath(Slot));
    if (L.Count < 2) or (L[0] <> 'DSAVE1') then
      Exit;
    Desc := L[1];
    Result := True;
  finally
    L.Free;
  end;
end;

function TFormMain.DoSave(Slot: Integer; const Desc: string): Boolean;
var
  L: TStringList;
  I, G, C: Integer;
  Th: TMapThing;
  Sec: TSector;
  Ln: TLine;
  Text: string;
begin
  Result := False;
  if (Slot < 0) or (Slot > 5) or (FPlayer = nil) or (FWorld = nil) or (FHost = nil) then
    Exit;
  if FHost.Gamestate <> GS_LEVEL then
    Exit;
  Text := Trim(Desc);
  if Text = '' then
    Text := 'save ' + IntToStr(Slot);
  if Length(Text) > 24 then
    Text := Copy(Text, 1, 24);
  L := TStringList.Create;
  try
    L.Add('DSAVE1');
    L.Add(Text);
    L.Add(Format('%d %d %d', [FHost.Episode, FHost.MapN, FHost.Skill]));
    if FPlayer.GodMode then
      G := 1
    else
      G := 0;
    if FPlayer.NoClip then
      C := 1
    else
      C := 0;
    L.Add(Format('%d %d %d %d %d %d %d %d %d %d', [FPlayer.Health, FPlayer.Ammo, FPlayer.X, FPlayer.Y,
      FPlayer.Z, Integer(FPlayer.Angle), FPlayer.Kills, FPlayer.Secrets, G, C]));
    L.Add(Format('%d %d %d %d %d %d', [Ord(FPlayer.Cards[0]), Ord(FPlayer.Cards[1]), Ord(FPlayer.Cards[2]),
      Ord(FPlayer.Cards[3]), Ord(FPlayer.Cards[4]), Ord(FPlayer.Cards[5])]));
    L.Add(IntToStr(FWorld.ThingCount));
    for I := 0 to FWorld.ThingCount - 1 do
    begin
      Th := FWorld.ThingAt(I);
      if Th = nil then
        L.Add('0 0 0 1 0 0 0 8 0 0')
      else
        L.Add(Format('%d %d %d %d %d %d %d %d %d %d', [Th.X, Th.Y, Th.Health, Ord(Th.Dead), Th.Ai,
          Th.FrameUse, Th.Angle, Th.MoveDir, Th.MoveCount, Th.Tics]));
    end;
    L.Add(IntToStr(FWorld.SectorCount));
    for I := 0 to FWorld.SectorCount - 1 do
    begin
      Sec := FWorld.SectorAt(I);
      if Sec = nil then
        L.Add('0 0 0 0')
      else
        L.Add(Format('%d %d %d %d', [Sec.FloorHeight, Sec.CeilingHeight, Sec.LightLevel, Sec.Special]));
    end;
    L.Add(IntToStr(FWorld.LineCount));
    for I := 0 to FWorld.LineCount - 1 do
    begin
      Ln := FWorld.LineAt(I);
      if Ln = nil then
        L.Add('0')
      else
        L.Add(IntToStr(Ln.Flags));
    end;
    L.SaveToFile(SavePath(Slot));
    Result := True;
    FPlayer.Say('Game Saved.');
  finally
    L.Free;
  end;
end;

function TFormMain.DoLoad(Slot: Integer): Boolean;
var
  L: TStringList;
  At, Ep, MapN, Skill: Integer;
  Desc: string;
begin
  Result := False;
  if not DoRead(Slot, Desc) then
    Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(SavePath(Slot));
    if L.Count < 3 then
      Exit;
    At := 1;
    Ep := NextInt(L[2], At);
    MapN := NextInt(L[2], At);
    Skill := NextInt(L[2], At);
  finally
    L.Free;
  end;
  if (Ep < 1) or (MapN < 1) then
    Exit;
  FLoadName := SavePath(Slot);
  FCarry := False;
  FHost.StartNewGame(Skill, Ep, MapN);
  Result := True;
end;

procedure TFormMain.ApplySave(const Path: string);
var
  L: TStringList;
  At, I, N, Row, Health, Ammo, PX, PY, PZ, Ang, Kills, Secrets, G, C: Integer;
  Th: TMapThing;
  Sec: TSector;
  Ln: TLine;
begin
  if (FPlayer = nil) or (FWorld = nil) or not FileExists(Path) then
    Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(Path);
    if (L.Count < 6) or (L[0] <> 'DSAVE1') then
      Exit;
    At := 1;
    Health := NextInt(L[3], At);
    Ammo := NextInt(L[3], At);
    PX := NextInt(L[3], At);
    PY := NextInt(L[3], At);
    PZ := NextInt(L[3], At);
    Ang := NextInt(L[3], At);
    Kills := NextInt(L[3], At);
    Secrets := NextInt(L[3], At);
    G := NextInt(L[3], At);
    C := NextInt(L[3], At);
    FPlayer.Health := Health;
    FPlayer.Ammo := Ammo;
    FPlayer.X := PX;
    FPlayer.Y := PY;
    FPlayer.Z := PZ;
    FPlayer.Angle := Cardinal(Ang);
    FPlayer.ViewZ := PZ + 41 * 65536;
    FPlayer.Kills := Kills;
    FPlayer.Secrets := Secrets;
    FPlayer.GodMode := G <> 0;
    FPlayer.NoClip := C <> 0;
    At := 1;
    for I := 0 to 5 do
      FPlayer.Cards[I] := NextInt(L[4], At) <> 0;
    Row := 6;
    N := StrToIntDef(L[5], 0);
    for I := 0 to N - 1 do
    begin
      if Row >= L.Count then
        Break;
      if I < FWorld.ThingCount then
      begin
        Th := FWorld.ThingAt(I);
        if Th <> nil then
        begin
          At := 1;
          Th.X := NextInt(L[Row], At);
          Th.Y := NextInt(L[Row], At);
          Th.Health := NextInt(L[Row], At);
          Th.Dead := NextInt(L[Row], At) <> 0;
          Th.Ai := NextInt(L[Row], At);
          Th.FrameUse := NextInt(L[Row], At);
          Th.Angle := NextInt(L[Row], At);
          Th.MoveDir := NextInt(L[Row], At);
          Th.MoveCount := NextInt(L[Row], At);
          Th.Tics := NextInt(L[Row], At);
          if Th.Dead then
            Th.ActorFlags := Th.ActorFlags and not 2;
        end;
      end;
      Inc(Row);
    end;
    if Row >= L.Count then
      Exit;
    N := StrToIntDef(L[Row], 0);
    Inc(Row);
    for I := 0 to N - 1 do
    begin
      if Row >= L.Count then
        Break;
      if I < FWorld.SectorCount then
      begin
        Sec := FWorld.SectorAt(I);
        if Sec <> nil then
        begin
          At := 1;
          Sec.FloorHeight := NextInt(L[Row], At);
          Sec.CeilingHeight := NextInt(L[Row], At);
          Sec.LightLevel := NextInt(L[Row], At);
          Sec.Special := NextInt(L[Row], At);
        end;
      end;
      Inc(Row);
    end;
    if Row >= L.Count then
      Exit;
    N := StrToIntDef(L[Row], 0);
    Inc(Row);
    for I := 0 to N - 1 do
    begin
      if Row >= L.Count then
        Break;
      if I < FWorld.LineCount then
      begin
        Ln := FWorld.LineAt(I);
        if Ln <> nil then
          Ln.Flags := StrToIntDef(L[Row], Ln.Flags);
      end;
      Inc(Row);
    end;
  finally
    L.Free;
  end;
end;

procedure TFormMain.StartFinale(FinishedMap: Integer; ContinueAfter: Boolean);
var
  Commercial: Boolean;
begin
  if FAuto <> nil then
    FAuto.ResetLevel;
  Commercial := (FWad <> nil) and (FWad.CheckNumForName('MAP01') >= 0);
  FFinale.Free;
  FFinale := TFinale.Create(FWad, FHost.Episode, FinishedMap, Commercial, ContinueAfter);
  FHost.Gamestate := GS_FINALE;
  FHost.PendingLevel := False;
  FHost.Notice := '';
end;

procedure TFormMain.FeedCheat(const Ch: string);
var
  C, Lump, Tail: string;
  A, B, Ep, MapN: Integer;
  I: Integer;
begin
  if (Length(Ch) <> 1) or (FPlayer = nil) or (FHost = nil) or (FWad = nil) then
    Exit;
  C := LowerCase(Ch);
  if not CharInSet(C[1], ['a'..'z', '0'..'9']) then
    Exit;
  FCheat := FCheat + C;
  if Length(FCheat) > 32 then
    FCheat := Copy(FCheat, Length(FCheat) - 31, 32);
  if EndsWith(FCheat, 'iddqd') then
  begin
    FPlayer.GodMode := not FPlayer.GodMode;
    if FPlayer.GodMode then
    begin
      if FPlayer.Health < 100 then
        FPlayer.Health := 100;
      FPlayer.Say('God mode ON');
    end
    else
      FPlayer.Say('God mode OFF');
    FCheat := '';
  end
  else if EndsWith(FCheat, 'idkfa') then
  begin
    FPlayer.Ammo := FPlayer.MaxClip;
    FPlayer.Shells := FPlayer.MaxShell;
    FPlayer.Rockets := FPlayer.MaxRocket;
    FPlayer.Cells := FPlayer.MaxCell;
    FPlayer.Armor := 200;
    FPlayer.ArmorType := 2;
    for I := 0 to 6 do
      FPlayer.Owned[I] := True;
    for I := 0 to 5 do
      FPlayer.Cards[I] := True;
    FPlayer.Say('Very Happy Ammo Added');
    FCheat := '';
  end
  else if EndsWith(FCheat, 'idfa') then
  begin
    FPlayer.Ammo := FPlayer.MaxClip;
    FPlayer.Shells := FPlayer.MaxShell;
    FPlayer.Rockets := FPlayer.MaxRocket;
    FPlayer.Cells := FPlayer.MaxCell;
    FPlayer.Say('Ammo (no keys) Added');
    FCheat := '';
  end
  else if EndsWith(FCheat, 'idclip') or EndsWith(FCheat, 'idspispopd') then
  begin
    FPlayer.NoClip := not FPlayer.NoClip;
    if FPlayer.NoClip then
      FPlayer.Say('No Clipping Mode ON')
    else
      FPlayer.Say('No Clipping Mode OFF');
    FCheat := '';
  end
  else if EndsWith(FCheat, 'iddt') then
  begin
    if (FAuto <> nil) and FAuto.Active then
      FAuto.Cheat := (FAuto.Cheat + 1) mod 3;
    FCheat := '';
  end
  else if (Length(FCheat) >= 8) and (Copy(FCheat, Length(FCheat) - 7, 6) = 'idclev') then
  begin
    Tail := Copy(FCheat, Length(FCheat) - 1, 2);
    A := StrToIntDef(Copy(Tail, 1, 1), -1);
    B := StrToIntDef(Copy(Tail, 2, 1), -1);
    if FWad.CheckNumForName('MAP01') >= 0 then
    begin
      Ep := 1;
      MapN := A * 10 + B;
      Lump := Format('MAP%.2d', [MapN]);
    end
    else
    begin
      Ep := A;
      MapN := B;
      Lump := Format('E%dM%d', [Ep, MapN]);
    end;
    if (A >= 0) and (MapN >= 1) and (FWad.CheckNumForName(Lump) >= 0) then
    begin
      RememberCarry;
      FPlayer.Say('Changing Level...');
      FHost.StartNewGame(FHost.Skill, Ep, MapN);
    end;
    FCheat := '';
  end
  else if (Length(FCheat) >= 7) and (Copy(FCheat, Length(FCheat) - 6, 5) = 'idmus') then
  begin
    Tail := Copy(FCheat, Length(FCheat) - 1, 2);
    A := StrToIntDef(Copy(Tail, 1, 1), -1);
    B := StrToIntDef(Copy(Tail, 2, 1), -1);
    if (FHost.Sound <> nil) and (A >= 0) and (B >= 0) then
    begin
      if FWad.CheckNumForName('MAP01') >= 0 then
        FHost.Sound.PlayLevel(1, A * 10 + B)
      else
        FHost.Sound.PlayLevel(A, B);
      FPlayer.Say('Music changed');
    end;
    FCheat := '';
  end;
end;

function TFormMain.LocateWad(const Spec: string): string;
var
  Dirs: TArray<string>;
  Dir, Name, Candidate: string;
begin
  Result := '';
  if Spec = '' then
    Exit;
  if FileExists(Spec) then
    Exit(ExpandFileName(Spec));
  Name := ExtractFileName(Spec);
  Dirs := WadSearchDirs;
  for Dir in Dirs do
  begin
    if Dir = '' then
      Continue;
    Candidate := IncludeTrailingPathDelimiter(Dir) + Name;
    if FileExists(Candidate) then
      Exit(Candidate);
  end;
end;

procedure TFormMain.ReadArgs;
var
  I, N: Integer;
  A, Path: string;
begin
  FShowFps := False;
  FCrt := False;
  FWantFull := False;
  FNoMonsters := False;
  FNoSound := False;
  FNoMusic := False;
  FIwad := '';
  SetLength(FFiles, 0);
  FWarpOn := False;
  FSkillOn := False;
  FWarpEpi := 1;
  FWarpMap := 1;
  FSkillArg := 2;
  I := 1;
  while I <= ParamCount do
  begin
    A := LowerCase(ParamStr(I));
    if A = '-fps' then
      FShowFps := True
    else if A = '-crt' then
      FCrt := True
    else if A = '-fullscreen' then
      FWantFull := True
    else if A = '-nomonsters' then
      FNoMonsters := True
    else if A = '-nosound' then
    begin
      FNoSound := True;
      FNoMusic := True;
    end
    else if A = '-nomusic' then
      FNoMusic := True
    else if (A = '-iwad') and (I < ParamCount) then
    begin
      Inc(I);
      Path := LocateWad(ParamStr(I));
      if Path = '' then
        Path := ParamStr(I);
      FIwad := Path;
    end
    else if A = '-file' then
    begin
      Inc(I);
      while (I <= ParamCount) and (ParamStr(I) <> '') and (ParamStr(I)[1] <> '-') do
      begin
        Path := LocateWad(ParamStr(I));
        if Path = '' then
          Path := ParamStr(I);
        FFiles := FFiles + [Path];
        Inc(I);
      end;
      Dec(I);
    end
    else if (A = '-skill') and (I < ParamCount) then
    begin
      N := StrToIntDef(ParamStr(I + 1), 3);
      if (N >= 1) and (N <= 5) then
        Dec(N);
      if N < 0 then
        N := 0;
      if N > 4 then
        N := 4;
      FSkillOn := True;
      FSkillArg := N;
      Inc(I);
    end
    else if (A = '-warp') and (I < ParamCount) then
    begin
      FWarpOn := True;
      FWarpEpi := StrToIntDef(ParamStr(I + 1), 1);
      if (I + 2 <= ParamCount) and (ParamStr(I + 2) <> '') and (ParamStr(I + 2)[1] <> '-') then
      begin
        FWarpMap := StrToIntDef(ParamStr(I + 2), 1);
        Inc(I, 2);
      end
      else
      begin
        FWarpMap := FWarpEpi;
        FWarpEpi := 1;
        Inc(I);
      end;
    end
    else if EndsStr('.wad', A) then
    begin
      Path := LocateWad(ParamStr(I));
      if Path = '' then
        Path := ParamStr(I);
      FIwad := Path;
    end;
    Inc(I);
  end;
end;

procedure TFormMain.LockLandscape;
{$IFDEF ANDROID}
var
  Window: JWindow;
  Decor: JView;
{$ENDIF}
begin
  {$IFDEF ANDROID}
  FullScreen := True;
  if TAndroidHelper.Activity = nil then
    Exit;
  TAndroidHelper.Activity.setRequestedOrientation(
    TJActivityInfo.JavaClass.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
  Window := TAndroidHelper.Activity.getWindow;
  if Window = nil then
    Exit;
  Window.setFlags(TJWindowManager_LayoutParams.JavaClass.FLAG_FULLSCREEN,
    TJWindowManager_LayoutParams.JavaClass.FLAG_FULLSCREEN);
  Decor := Window.getDecorView;
  if Decor <> nil then
    Decor.setSystemUiVisibility(
      TJView.JavaClass.SYSTEM_UI_FLAG_FULLSCREEN or
      TJView.JavaClass.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
      TJView.JavaClass.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
      TJView.JavaClass.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
      TJView.JavaClass.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
      TJView.JavaClass.SYSTEM_UI_FLAG_LAYOUT_STABLE);
  {$ENDIF}
end;

procedure TFormMain.StylePad(Btn: TButton);
var
  Back: TFmxObject;
begin
  if Btn = nil then
    Exit;
  Btn.CanFocus := False;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  Btn.TextSettings.FontColor := TAlphaColor($FFFFFFFF);
  Btn.TextSettings.Font.Size := 16;
  Btn.ApplyStyleLookup;
  Back := Btn.FindStyleResource('background');
  if Back is TShape then
  begin
    TShape(Back).Fill.Kind := TBrushKind.Solid;
    TShape(Back).Fill.Color := TAlphaColor($40FFFFFF);
    TShape(Back).Stroke.Kind := TBrushKind.Solid;
    TShape(Back).Stroke.Color := TAlphaColor($C0FFFFFF);
    if Back is TRectangle then
    begin
      TRectangle(Back).XRadius := 10;
      TRectangle(Back).YRadius := 10;
    end;
    Btn.Opacity := 1;
  end
  else
    Btn.Opacity := 0.4;
end;

procedure TFormMain.ShowToggle(Btn: TButton; On: Boolean);
begin
  if Btn = nil then
    Exit;
  if On then
    Btn.Opacity := 1
  else
    Btn.Opacity := 0.45;
end;

procedure TFormMain.NextWeapon;
var
  I, N: Integer;
begin
  if (FPlayer = nil) or (FPlayer.Health <= 0) then
    Exit;
  for I := 1 to 7 do
  begin
    N := (FPlayer.Weapon + I) mod 7;
    if FPlayer.Owned[N] then
    begin
      FPlayer.SelectWeapon(N);
      Exit;
    end;
  end;
end;

procedure TFormMain.PlacePad;
var
  S, G, M, Bot, Wide, Row, Third: Single;
begin
  if not LayPad.Visible then
    Exit;
  LayPad.Align := TAlignLayout.Contents;
  LayPad.HitTest := False;
  LayPad.BringToFront;
  S := 58;
  if ClientHeight < 340 then
    S := 48;
  G := 4;
  M := 10;
  Bot := ClientHeight - S - 8;
  BtnLeft.SetBounds(M, Bot, S, S);
  BtnDown.SetBounds(M + S + G, Bot, S, S);
  BtnRight.SetBounds(M + (S + G) * 2, Bot, S, S);
  BtnUp.SetBounds(M + S + G, Bot - S - G, S, S);
  Wide := S * 1.45;
  Row := Wide * 2 + G;
  Third := (Row - G * 2) / 3;
  BtnFire.SetBounds(ClientWidth - M - Row, Bot, Wide, S);
  BtnUse.SetBounds(ClientWidth - M - Wide, Bot, Wide, S);
  BtnWeapon.SetBounds(ClientWidth - M - Row, Bot - S - G, Third, S);
  BtnRun.SetBounds(ClientWidth - M - Row + Third + G, Bot - S - G, Third, S);
  BtnSide.SetBounds(ClientWidth - M - Third, Bot - S - G, Third, S);
  BtnEsc.SetBounds((ClientWidth - S * 1.6) / 2, 8, S * 1.6, S * 0.75);
  ShowToggle(BtnRun, FRunLock);
  ShowToggle(BtnSide, FSideLock);
end;

procedure TFormMain.FormResize(Sender: TObject);
begin
  PlacePad;
  PlacePick;
end;

procedure TFormMain.ApplyWindow;
begin
  if TOSVersion.Platform = pfAndroid then
    Exit;
  if FullScreen then
    Exit;
  ClientWidth := SCREENWIDTH * FScale;
  ClientHeight := SCREENHEIGHT * FScale;
end;

procedure TFormMain.ToggleFull;
begin
  if TOSVersion.Platform = pfAndroid then
    Exit;
  FullScreen := not FullScreen;
  if not FullScreen then
    ApplyWindow;
end;

procedure TFormMain.ChangeScale(Delta: Integer);
var
  N: Integer;
begin
  if FullScreen or (TOSVersion.Platform = pfAndroid) then
    Exit;
  N := FScale + Delta;
  if N < 1 then
    N := 1;
  if N > 6 then
    N := 6;
  if N = FScale then
    Exit;
  FScale := N;
  ApplyWindow;
  PlaySfx('stnmov');
end;

procedure TFormMain.LoadTitle;
var
  WadPath: string;
  Pal: TBytes;
  I: Integer;
begin
  FPalIndex := -1;
  SetLength(FPlaypal, 0);
  for I := 0 to 255 do
    FPal[I] := $FF000000 or (Cardinal(I) shl 16) or (Cardinal(I) shl 8) or Cardinal(I);
  FWad := TWad.Create;
  try
    if FIwad <> '' then
      WadPath := FIwad
    else
      WadPath := FindIwad;
    if WadPath = '' then
    begin
      Caption := 'DOOM sem WAD';
      Exit;
    end;
    FWad.AddFile(WadPath);
    for WadPath in FFiles do
      FWad.AddFile(WadPath);
    Caption := 'DOOM ' + IntToStr(FWad.NumLumps);
    if FWad.CheckNumForName('PLAYPAL') >= 0 then
    begin
      Pal := FWad.CacheLumpName('PLAYPAL');
      if Length(Pal) >= 768 then
      begin
        FPlaypal := Pal;
        FPalIndex := 0;
        for I := 0 to 255 do
          FPal[I] := $FF000000 or (Cardinal(Pal[I * 3]) shl 16) or
            (Cardinal(Pal[I * 3 + 1]) shl 8) or Cardinal(Pal[I * 3 + 2]);
      end;
    end;
  except
    on E: Exception do
      Caption := 'DOOM ' + E.Message;
  end;
end;

procedure TFormMain.ShowPage(const Name: string);
var
  UseName: string;
  Lump: TBytes;
begin
  FillFb(FPage, 0);
  if FWad = nil then
    Exit;
  UseName := Name;
  if FWad.CheckNumForName(UseName) < 0 then
  begin
    if FWad.CheckNumForName('TITLEPIC') >= 0 then
      UseName := 'TITLEPIC'
    else
      Exit;
  end;
  Lump := FWad.CacheLumpName(UseName);
  DrawPatch(FPage, 0, 0, Lump);
end;

procedure TFormMain.AdvanceDemo;
var
  Tic: Integer;
  Commercial: Boolean;
begin
  if FWad = nil then
    Exit;
  Commercial := FWad.CheckNumForName('MAP01') >= 0;
  repeat
    FAdvance := False;
    FSequence := (FSequence + 1) mod 6;
    case FSequence of
      0:
        begin
          if Commercial then
            Tic := TICRATE * 11
          else
            Tic := 170;
          FPageTic := Tic;
          FHost.Gamestate := GS_TITLE;
          ShowPage('TITLEPIC');
        end;
      2:
        begin
          FPageTic := 200;
          FHost.Gamestate := GS_TITLE;
          if FWad.CheckNumForName('CREDIT') >= 0 then
            ShowPage('CREDIT')
          else
            ShowPage('TITLEPIC');
        end;
      4:
        begin
          if Commercial then
            Tic := TICRATE * 11
          else
            Tic := 200;
          FPageTic := Tic;
          FHost.Gamestate := GS_TITLE;
          ShowPage('TITLEPIC');
        end;
    else
      FAdvance := True;
    end;
  until not FAdvance;
end;

procedure TFormMain.EnterLevel;
var
  I: Integer;
begin
  if (FWad = nil) or (FHost = nil) then
    Exit;
  if FWorld = nil then
    FWorld := TWorld.Create;
  FSpecials.Free;
  FSpecials := nil;
  FEnemies.Free;
  FEnemies := nil;
  try
    FWorld.SetupLevel(FWad, FHost.Episode, FHost.MapN);
    if FPlayer = nil then
      FPlayer := TPlayer.Create;
    FPlayer.Spawn(FWorld, FHost.Skill);
    if FCarry then
    begin
      FPlayer.Health := FCarryHealth;
      FPlayer.Ammo := FCarryAmmo;
      FPlayer.Shells := FCarryShells;
      FPlayer.Rockets := FCarryRockets;
      FPlayer.Cells := FCarryCells;
      FPlayer.Armor := FCarryArmor;
      FPlayer.ArmorType := FCarryArmorType;
      FPlayer.Weapon := FCarryWeapon;
      FPlayer.MaxClip := FCarryMaxClip;
      FPlayer.MaxShell := FCarryMaxShell;
      FPlayer.MaxRocket := FCarryMaxRocket;
      FPlayer.MaxCell := FCarryMaxCell;
      for I := 0 to 6 do
        FPlayer.Owned[I] := FCarryOwned[I];
      FCarry := False;
    end;
    FSpecials := TSpecials.Create(FWorld, FPlayer, FRes);
    FEnemies := TEnemies.Create(FWorld, FPlayer, FSpecials, FNoMonsters);
    CountLevel;
    if FStatus <> nil then
      FStatus.Reset;
    if FHost.Sound <> nil then
    begin
      FHost.Sound.StopSfx;
      FHost.Sound.PlayLevel(FHost.Episode, FHost.MapN);
    end;
    FHost.Gamestate := GS_LEVEL;
    FHost.HasPlayer := FWorld.HasPlayerStart;
    FHost.PendingLevel := False;
    if FAuto <> nil then
      FAuto.ResetLevel;
    if FLoadName <> '' then
    begin
      ApplySave(FLoadName);
      FLoadName := '';
    end;
    FHost.Notice := Format('%s skill %d  %d linhas', [FWorld.MapName, FHost.Skill, FWorld.LineCount]);
    FWasLevel := True;
    FHoldPage := False;
  except
    on E: Exception do
    begin
      FHost.PendingLevel := False;
      FHost.Gamestate := GS_TITLE;
      FHost.Notice := E.Message;
      if FHost.Sound <> nil then
        FHost.Sound.PlayTitle;
    end;
  end;
end;

procedure TFormMain.FinishLevel;
var
  Secret, Commercial: Boolean;
  Cur, Nxt: Integer;
  Lump: string;
begin
  if (FHost = nil) or (FWad = nil) or (FPlayer = nil) then
    Exit;
  Secret := (FSpecials <> nil) and FSpecials.SecretExit;
  Commercial := FWad.CheckNumForName('MAP01') >= 0;
  Cur := FHost.MapN;
  if not Commercial and (Cur = 8) and not Secret then
  begin
    StartFinale(Cur, False);
    Exit;
  end;
  if Commercial then
  begin
    if Secret and (Cur = 15) then
      Nxt := 31
    else if Secret and (Cur = 31) then
      Nxt := 32
    else if (Cur = 31) or (Cur = 32) then
      Nxt := 16
    else
      Nxt := Cur + 1;
  end
  else if Secret then
    Nxt := 9
  else if Cur = 9 then
    case FHost.Episode of
      2: Nxt := 6;
      3: Nxt := 7;
      4: Nxt := 3;
    else
      Nxt := 4;
    end
  else
    Nxt := Cur + 1;
  if Commercial then
    Lump := Format('MAP%.2d', [Nxt])
  else
    Lump := Format('E%dM%d', [FHost.Episode, Nxt]);
  if FWad.CheckNumForName(Lump) < 0 then
  begin
    FHost.Gamestate := GS_TITLE;
    FHost.PendingLevel := False;
    FHost.Notice := 'fim';
    Exit;
  end;
  FWantFinale := Commercial and ((Cur = 6) or (Cur = 11) or (Cur = 20) or (Cur = 30) or
    (Secret and ((Cur = 15) or (Cur = 31))));
  FFinaleMap := Cur;
  RememberCarry;
  FNextMap := Nxt;
  FInter.Free;
  FInter := TIntermission.Create(FWad, FHost.Episode, Cur, Nxt, FMaxKills, FMaxItems, FMaxSecrets,
    FPlayer.Kills, 0, FPlayer.Secrets, FPlayer.LevelTics, Secret, Commercial);
  FHost.Gamestate := GS_INTERMISSION;
  FHost.PendingLevel := False;
  FHost.Notice := '';
end;

procedure TFormMain.CountLevel;
var
  I, Flags, Frame, Height, Radius, Health: Integer;
  Spr: string;
  Th: TMapThing;
  Sec: TSector;
begin
  FMaxKills := 0;
  FMaxItems := 0;
  FMaxSecrets := 0;
  if (FWorld = nil) or (FPlayer = nil) then
    Exit;
  for I := 0 to FWorld.ThingCount - 1 do
  begin
    Th := FWorld.ThingAt(I);
    if not FPlayer.Accepts(Th.Options) then
      Continue;
    if Th.FrameUse = -2 then
      Continue;
    if not ThingInfo(Th.ThingType, Spr, Frame, Height, Flags, Radius, Health) then
      Continue;
    if (Flags and $400000) <> 0 then
      Inc(FMaxKills);
    if (Flags and $800000) <> 0 then
      Inc(FMaxItems);
  end;
  for I := 0 to FWorld.SectorCount - 1 do
  begin
    Sec := FWorld.SectorAt(I);
    if (Sec <> nil) and (Sec.Special = 9) then
      Inc(FMaxSecrets);
  end;
end;

procedure TFormMain.Compose;
var
  Sub: TSubsector;
  Z: Integer;
begin
  if (FHost <> nil) and (FHost.Notice <> '') then
    Caption := 'DOOM ' + FHost.Notice
  else if FWad <> nil then
    Caption := 'DOOM ' + IntToStr(FWad.NumLumps);
  if (FHost <> nil) and (FHost.Gamestate = GS_LEVEL) and (FWorld <> nil) and (FRender <> nil) then
  begin
    FillFb(FFb, 0);
    FRender.SetViewSize(FHost.ScreenSize + 3, FHost.DetailLevel);
    if FPlayer <> nil then
    begin
      FRender.SetupFrame(FPlayer.X, FPlayer.Y, FPlayer.ViewZ, FPlayer.Angle);
      FRender.SetLightBoost(FPlayer.LightBoost);
    end
    else
    begin
      Sub := FWorld.PointInSubsector(FWorld.PlayerViewX, FWorld.PlayerViewY);
      Z := 41 * 65536;
      if (Sub <> nil) and (Sub.Sector <> nil) then
        Z := AsI32(Int64(Sub.Sector.FloorHeight) + Z);
      FRender.SetupFrame(FWorld.PlayerViewX, FWorld.PlayerViewY, Z, FWorld.PlayerViewAngle);
      FRender.SetLightBoost(0);
    end;
    FRender.Render(FWorld, FFb);
    FRender.DrawMapThings(FWorld, FHost.Skill);
    if (FPlayer <> nil) and (FWad <> nil) and (FPlayer.WeaponBody <> '') and
      (FWad.CheckNumForName(FPlayer.WeaponBody) >= 0) then
      FRender.DrawPSprite(FWad.CacheLumpName(FPlayer.WeaponBody), FPlayer.WeaponSx, FPlayer.WeaponSy);
    if (FPlayer <> nil) and (FWad <> nil) and (FPlayer.WeaponFlash <> '') and
      (FWad.CheckNumForName(FPlayer.WeaponFlash) >= 0) then
      FRender.DrawPSprite(FWad.CacheLumpName(FPlayer.WeaponFlash), FPlayer.WeaponSx, FPlayer.WeaponSy);
    if (FAuto <> nil) and FAuto.Active then
    begin
      if FHost.ScreenSize < 8 then
        FAuto.Draw(FFb, FWorld, FPlayer, 168)
      else
        FAuto.Draw(FFb, FWorld, FPlayer, 200);
    end;
    if (FStatus <> nil) and (FHost.ScreenSize < 8) then
      FStatus.Draw(FFb, FPlayer);
  end
  else if (FHost <> nil) and (FHost.Gamestate = GS_FINALE) and (FFinale <> nil) then
    FFinale.Draw(FFb)
  else if (FHost <> nil) and (FHost.Gamestate = GS_INTERMISSION) and (FInter <> nil) then
    FInter.Draw(FFb)
  else if Length(FPage) = SCREENPIXELS then
    FFb := Copy(FPage)
  else
    FillFb(FFb, 0);
end;

procedure TFormMain.FeedKey(Key: Integer; const Ch: string);
begin
  if FMenu = nil then
    Exit;
  if FMenu.Responder(Key, Ch) then
  begin
    if not FHost.Running then
      Close;
    Exit;
  end;
  if FHost.Gamestate = GS_TITLE then
  begin
    FHost.StartNewGame(FHost.Skill, FHost.Episode, FHost.MapN);
    FHoldPage := True;
    FAdvance := False;
  end;
end;

procedure TFormMain.StyleUrlEdit(Sender: TObject);
var
  Obj: TFmxObject;
begin
  if FPickUrl = nil then
    Exit;
  FPickUrl.StyledSettings := FPickUrl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  FPickUrl.TextSettings.Font.Size := 18;
  FPickUrl.TextSettings.FontColor := TAlphaColor($FF111111);
  Obj := FPickUrl.FindStyleResource('text');
  if Obj is TText then
    TText(Obj).TextSettings.FontColor := TAlphaColor($FF111111);
  Obj := FPickUrl.FindStyleResource('prompt');
  if Obj is TText then
    TText(Obj).TextSettings.FontColor := TAlphaColor($FF666666);
  Obj := FPickUrl.FindStyleResource('background');
  if Obj is TRectangle then
  begin
    TRectangle(Obj).Fill.Kind := TBrushKind.Solid;
    TRectangle(Obj).Fill.Color := TAlphaColorRec.White;
  end;
end;

procedure TFormMain.PlacePick;
var
  TopY, ListTop, ListH, BtnW: Single;
begin
  if (FPick = nil) or not FPick.Visible then
    Exit;
  FPick.BringToFront;
  TopY := 10;
  BtnW := 120;
  if FPickStatus <> nil then
    FPickStatus.SetBounds(16, TopY, ClientWidth - 32, 26);
  if FPickUrl <> nil then
    FPickUrl.SetBounds(16, TopY + 28, ClientWidth - 32 - BtnW - 8, 44);
  if (FPickUrlBack <> nil) and (FPickUrl <> nil) then
    FPickUrlBack.SetBounds(FPickUrl.Position.X - 2, FPickUrl.Position.Y - 2,
      FPickUrl.Width + 4, FPickUrl.Height + 4);
  if (FPickGet <> nil) and (FPickUrl <> nil) then
    FPickGet.SetBounds(FPickUrl.Position.X + FPickUrl.Width + 8, TopY + 28, BtnW, 44);
  if FPickTrack <> nil then
    FPickTrack.SetBounds(16, TopY + 78, ClientWidth - 32, 14);
  if (FPickFill <> nil) and (FPickTrack <> nil) then
    FPickFill.SetBounds(FPickTrack.Position.X, FPickTrack.Position.Y, FPickFill.Width, FPickTrack.Height);
  ListTop := TopY + 100;
  ListH := ClientHeight - ListTop - 58;
  if ListH < 72 then
    ListH := 72;
  if FPickList <> nil then
    FPickList.SetBounds(16, ListTop, ClientWidth - 32, ListH);
  if FPickPlay <> nil then
    FPickPlay.SetBounds(16, ListTop + ListH + 8, 160, 44);
  if FPickStatus <> nil then
    FPickStatus.BringToFront;
  if FPickTrack <> nil then
    FPickTrack.BringToFront;
  if FPickFill <> nil then
    FPickFill.BringToFront;
  if FPickUrl <> nil then
    FPickUrl.BringToFront;
  if FPickGet <> nil then
    FPickGet.BringToFront;
  if FPickPlay <> nil then
    FPickPlay.BringToFront;
end;

procedure TFormMain.SetPickStatus(const S: string);
begin
  if FPickStatus = nil then
    Exit;
  FPickStatus.StyledSettings := FPickStatus.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  FPickStatus.TextSettings.FontColor := TAlphaColor($FFFFFF50);
  FPickStatus.TextSettings.Font.Size := 16;
  FPickStatus.Text := S;
  FPickStatus.BringToFront;
end;

function TFormMain.DlPulse(ReadN, TotalN: Int64): Boolean;
var
  NowTick: Cardinal;
begin
  if TotalN > 0 then
    FDlTotal := TotalN;
  NowTick := TThread.GetTickCount;
  if NowTick = 0 then
    NowTick := 1;
  Result := (FDlTick = 0) or (NowTick - FDlTick >= 150) or ((FDlTotal > 0) and (ReadN >= FDlTotal));
  if Result then
    FDlTick := NowTick;
end;

procedure TFormMain.QueueDl(ReadN, TotalN: Int64);
begin
  TThread.Queue(nil,
    procedure
    begin
      ShowDl(ReadN, TotalN);
    end);
end;

procedure TFormMain.DlReceive(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
begin
  if AContentLength > 0 then
    FDlTotal := AContentLength;
  if DlPulse(AReadCount, FDlTotal) then
    QueueDl(AReadCount, FDlTotal);
end;

procedure TFormMain.ShowDl(ReadN, TotalN: Int64);
  function FmtDl(N: Int64): string;
  begin
    if N >= 1048576 then
      Result := Format('%.1f MB', [N / 1048576])
    else if N >= 1024 then
      Result := Format('%.0f KB', [N / 1024])
    else
      Result := IntToStr(N) + ' B';
  end;
var
  Frac: Double;
  Pct: Integer;
begin
  if not FGetting then
    Exit;
  if TotalN > 0 then
  begin
    Frac := ReadN / TotalN;
    Pct := Round(Frac * 100);
    if Pct > 100 then
      Pct := 100;
    if Pct < 0 then
      Pct := 0;
    SetPickStatus('baixando ' + IntToStr(Pct) + '%  ' + FmtDl(ReadN) + ' / ' + FmtDl(TotalN));
    if FPickGet <> nil then
      FPickGet.Text := IntToStr(Pct) + '%';
  end
  else
  begin
    if ReadN <= 0 then
      Frac := 0.04
    else
      Frac := ReadN / (ReadN + 512 * 1024);
    SetPickStatus('baixando ' + FmtDl(ReadN));
    if FPickGet <> nil then
      FPickGet.Text := FmtDl(ReadN);
  end;
  if Frac < 0.04 then
    Frac := 0.04;
  if Frac > 1 then
    Frac := 1;
  if (FPickTrack <> nil) and (FPickFill <> nil) then
    FPickFill.SetBounds(FPickTrack.Position.X, FPickTrack.Position.Y, FPickTrack.Width * Frac, FPickTrack.Height);
end;

procedure TFormMain.RefreshWadList;
var
  Docs, Path: string;
  Item: TListBoxItem;
begin
  if FPickList = nil then
    Exit;
  FPickList.Clear;
  FPicked := '';
  Docs := '';
  try
    Docs := TPath.GetDocumentsPath;
  except
    Docs := '';
  end;
  if (Docs = '') or not TDirectory.Exists(Docs) then
  begin
    SetPickStatus('pasta de documentos indisponivel');
    Exit;
  end;
  for Path in TDirectory.GetFiles(Docs) do
  begin
    if not SameText(ExtractFileExt(Path), '.wad') then
      Continue;
    Item := TListBoxItem.Create(FPickList);
    Item.Text := ExtractFileName(Path);
    Item.TagString := Path;
    Item.StyledSettings := Item.StyledSettings - [TStyledSetting.FontColor];
    Item.TextSettings.FontColor := TAlphaColorRec.White;
    FPickList.AddObject(Item);
  end;
  if FPickList.Count = 0 then
  begin
    SetPickStatus('nenhum WAD na pasta. Cole um endereco e baixe.');
  end
  else
  begin
    FPickList.ItemIndex := 0;
    FPicked := FPickList.ListItems[0].TagString;
    SetPickStatus(IntToStr(FPickList.Count) + ' WAD');
  end;
end;

procedure TFormMain.PickChanged(Sender: TObject);
begin
  if (FPickList <> nil) and (FPickList.Selected <> nil) then
    FPicked := FPickList.Selected.TagString;
end;

procedure TFormMain.PickPlay(Sender: TObject);
begin
  if FGetting then
    Exit;
  if FPicked = '' then
  begin
    SetPickStatus('escolha um WAD da lista');
    Exit;
  end;
  FIwad := FPicked;
  StartGame;
end;

function TWadStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := inherited Write(Buffer, Count);
  if (Form <> nil) and (Result > 0) and Form.DlPulse(Position, Form.FDlTotal) then
    Form.QueueDl(Position, Form.FDlTotal);
end;

procedure TFormMain.PickDownload(Sender: TObject);
var
  Url, Name, Dest, Docs: string;
begin
  if FGetting or (FPickUrl = nil) then
    Exit;
  Url := Trim(FPickUrl.Text);
  Name := Url;
  if Pos('?', Name) > 0 then
    Name := Copy(Name, 1, Pos('?', Name) - 1);
  Name := ExtractFileName(StringReplace(Name, '/', '\', [rfReplaceAll]));
  if (Url = '') or not SameText(ExtractFileExt(Name), '.wad') then
  begin
    SetPickStatus('o endereco precisa terminar em .wad');
    Exit;
  end;
  try
    Docs := TPath.GetDocumentsPath;
  except
    Docs := '';
  end;
  if Docs = '' then
  begin
    SetPickStatus('pasta de documentos indisponivel');
    Exit;
  end;
  Dest := TPath.Combine(Docs, Name);
  FGetting := True;
  FDlTick := 0;
  FDlTotal := 0;
  if FPickGet <> nil then
    FPickGet.Text := '0%';
  if FPickFill <> nil then
    FPickFill.Width := 0;
  SetPickStatus('conectando...');
  TThread.CreateAnonymousThread(
    procedure
    var
      Http: THTTPClient;
      Resp: IHTTPResponse;
      Down: TWadStream;
      Check: TFileStream;
      Mark: AnsiString;
      Msg: string;
      Ok: Boolean;
    begin
      Ok := False;
      Msg := '';
      Http := THTTPClient.Create;
      try
        try
          Http.UserAgent := 'delphi_doom';
          Http.ConnectionTimeout := 20000;
          Http.ResponseTimeout := 180000;
          Http.OnReceiveData := DlReceive;
          Down := TWadStream.Create(Dest, fmCreate);
          Down.Form := Self;
          try
            Resp := Http.Get(Url, Down);
            if Resp.StatusCode <> 200 then
              Msg := 'HTTP ' + IntToStr(Resp.StatusCode);
          finally
            Down.Free;
          end;
          if Msg = '' then
          begin
            Check := TFileStream.Create(Dest, fmOpenRead or fmShareDenyNone);
            try
              SetLength(Mark, 4);
              if Check.Read(Mark[1], 4) <> 4 then
                Mark := '';
            finally
              Check.Free;
            end;
            if (Mark <> 'IWAD') and (Mark <> 'PWAD') then
            begin
              System.SysUtils.DeleteFile(Dest);
              Msg := 'o arquivo nao e um WAD';
            end
            else
              Ok := True;
          end
          else
            System.SysUtils.DeleteFile(Dest);
        except
          on E: Exception do
          begin
            Msg := E.Message;
            System.SysUtils.DeleteFile(Dest);
          end;
        end;
      finally
        Http.Free;
      end;
      TThread.Synchronize(nil,
        procedure
        var
          I: Integer;
        begin
          FGetting := False;
          if FPickGet <> nil then
            FPickGet.Text := 'Baixar';
          if FPickFill <> nil then
            FPickFill.Width := 0;
          if Ok then
          begin
            RefreshWadList;
            if FPickList <> nil then
              for I := 0 to FPickList.Count - 1 do
                if SameText(FPickList.ListItems[I].Text, Name) then
                begin
                  FPickList.ItemIndex := I;
                  FPicked := FPickList.ListItems[I].TagString;
                  Break;
                end;
            SetPickStatus('baixado ' + Name);
          end
          else
          begin
            if Msg = '' then
              Msg := 'falha no download';
            SetPickStatus(Msg);
          end;
        end);
    end).Start;
end;

procedure TFormMain.BuildPicker;
var
  Back: TRectangle;
  Play: TButton;
  Cap: TLabel;
begin
  FPick := TLayout.Create(Self);
  FPick.Parent := Self;
  FPick.Align := TAlignLayout.Contents;
  FPick.Visible := True;
  Back := TRectangle.Create(FPick);
  Back.Parent := FPick;
  Back.Align := TAlignLayout.Contents;
  Back.HitTest := True;
  Back.Fill.Color := TAlphaColor($F0101010);
  Back.Stroke.Kind := TBrushKind.None;
  Cap := TLabel.Create(FPick);
  Cap.Parent := FPick;
  Cap.Text := 'Escolha o WAD';
  Cap.StyledSettings := Cap.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  Cap.TextSettings.FontColor := TAlphaColorRec.White;
  Cap.TextSettings.Font.Size := 20;
  FPickStatus := Cap;
  FPickList := TListBox.Create(FPick);
  FPickList.Parent := FPick;
  FPickList.OnChange := PickChanged;
  FPickUrlBack := TRectangle.Create(FPick);
  FPickUrlBack.Parent := FPick;
  FPickUrlBack.HitTest := False;
  FPickUrlBack.Fill.Color := TAlphaColorRec.White;
  FPickUrlBack.Stroke.Color := TAlphaColor($FF888888);
  FPickUrl := TEdit.Create(FPick);
  FPickUrl.Parent := FPick;
  FPickUrl.ControlType := TControlType.Styled;
  FPickUrl.TextPrompt := 'https://.../arquivo.wad';
  FPickUrl.StyledSettings := FPickUrl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  FPickUrl.TextSettings.Font.Size := 18;
  FPickUrl.TextSettings.FontColor := TAlphaColor($FF111111);
  FPickUrl.OnApplyStyleLookup := StyleUrlEdit;
  FPickGet := TButton.Create(FPick);
  FPickGet.Parent := FPick;
  FPickGet.Text := 'Baixar';
  FPickGet.OnClick := PickDownload;
  FPickTrack := TRectangle.Create(FPick);
  FPickTrack.Parent := FPick;
  FPickTrack.HitTest := False;
  FPickTrack.Fill.Color := TAlphaColor($FF333333);
  FPickTrack.Stroke.Kind := TBrushKind.None;
  FPickFill := TRectangle.Create(FPick);
  FPickFill.Parent := FPick;
  FPickFill.HitTest := False;
  FPickFill.Fill.Color := TAlphaColor($FF3DDC84);
  FPickFill.Stroke.Kind := TBrushKind.None;
  FPickFill.Width := 0;
  Play := TButton.Create(FPick);
  Play.Parent := FPick;
  Play.Text := 'Jogar';
  Play.OnClick := PickPlay;
  FPickPlay := Play;
  RefreshWadList;
  PlacePick;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FScale := 2;
  FFpsStamp := TThread.GetTickCount;
  ReadArgs;
  SetAudioGates(not FNoSound, not FNoMusic);
  FBmp := FMX.Graphics.TBitmap.Create(SCREENWIDTH, SCREENHEIGHT);
  FSequence := -1;
  if TOSVersion.Platform = pfAndroid then
  begin
    LayPad.Visible := False;
    LockLandscape;
    BuildPicker;
    Exit;
  end;
  StartGame;
end;

procedure TFormMain.StartGame;
begin
  if FHost <> nil then
    Exit;
  if FPick <> nil then
    FPick.Visible := False;
  LoadTitle;
  FRes := TResources.Create;
  if FWad <> nil then
    FRes.Init(FWad);
  FRender := TRenderer.Create(FRes);
  FHost := TDoomHost.Create(FWad);
  FHost.OnSave := DoSave;
  FHost.OnLoad := DoLoad;
  FHost.OnRead := DoRead;
  FAuto := TAutomap.Create;
  if FSkillOn then
    FHost.Skill := FSkillArg;
  if FWarpOn then
    FHost.StartNewGame(FHost.Skill, FWarpEpi, FWarpMap);
  FStatus := TStatusBar.Create(FWad);
  FWipe := TWipe.Create;
  FWipeState := GS_TITLE;
  FMenu := TDoomMenu.Create(FWad, FHost);
  AdvanceDemo;
  LayPad.Visible := TOSVersion.Platform = pfAndroid;
  if LayPad.Visible then
  begin
    LockLandscape;
    StylePad(BtnUp);
    StylePad(BtnDown);
    StylePad(BtnLeft);
    StylePad(BtnRight);
    StylePad(BtnFire);
    StylePad(BtnUse);
    StylePad(BtnWeapon);
    StylePad(BtnRun);
    StylePad(BtnSide);
    StylePad(BtnEsc);
    ShowToggle(BtnRun, FRunLock);
    ShowToggle(BtnSide, FSideLock);
    PlacePad;
  end;
  OnShow := FormShown;
  if not FWantFull then
    ApplyWindow;
  FFpsLabel := TLabel.Create(Self);
  FFpsLabel.Parent := Self;
  FFpsLabel.HitTest := False;
  FFpsLabel.StyledSettings := FFpsLabel.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size, TStyledSetting.Family];
  FFpsLabel.TextSettings.Font.Family := 'Consolas';
  FFpsLabel.TextSettings.Font.Size := 16;
  FFpsLabel.TextSettings.FontColor := TAlphaColor($FFFFFF50);
  FFpsLabel.TextSettings.HorzAlign := TTextAlign.Trailing;
  FFpsLabel.Text := '0 FPS';
  FFpsLabel.Width := 160;
  FFpsLabel.Height := 28;
  FFpsLabel.Visible := FShowFps;
  GameTimer.Interval := 28;
  GameTimer.Enabled := True;
  Compose;
  if FMenu <> nil then
    FMenu.Draw(FFb);
  PaintFrame;
end;

procedure TFormMain.FormShown(Sender: TObject);
begin
  if LayPad.Visible then
  begin
    LockLandscape;
    StylePad(BtnUp);
    StylePad(BtnDown);
    StylePad(BtnLeft);
    StylePad(BtnRight);
    StylePad(BtnFire);
    StylePad(BtnUse);
    StylePad(BtnWeapon);
    StylePad(BtnRun);
    StylePad(BtnSide);
    StylePad(BtnEsc);
    ShowToggle(BtnRun, FRunLock);
    ShowToggle(BtnSide, FSideLock);
    PlacePad;
  end;
  if FWantFull then
    FullScreen := True
  else if not FullScreen then
    ApplyWindow;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FInter.Free;
  FFinale.Free;
  FAuto.Free;
  FWipe.Free;
  FStatus.Free;
  FMenu.Free;
  FSpecials.Free;
  FEnemies.Free;
  FPlayer.Free;
  FRender.Free;
  FWorld.Free;
  FRes.Free;
  FHost.Free;
  FView.Free;
  FBmp.Free;
  FWad.Free;
end;

procedure TFormMain.PadDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Sender = BtnUp then
  begin
    FPadUp := True;
    FHoldUp := True;
    FeedKey(KEY_UP, '');
  end
  else if Sender = BtnDown then
  begin
    FPadDown := True;
    FHoldDown := True;
    FeedKey(KEY_DOWN, '');
  end
  else if Sender = BtnLeft then
  begin
    FPadLeft := True;
    FHoldLeft := True;
    FeedKey(KEY_LEFT, '');
  end
  else if Sender = BtnRight then
  begin
    FPadRight := True;
    FHoldRight := True;
    FeedKey(KEY_RIGHT, '');
  end
  else if Sender = BtnFire then
  begin
    FPadFire := True;
    FHoldFire := True;
    FeedKey(KEY_ENTER, '');
  end
  else if Sender = BtnUse then
  begin
    if (FMenu <> nil) and FMenu.Active then
      FeedKey(KEY_BACK, '')
    else if (FHost <> nil) and (FHost.Gamestate = GS_LEVEL) then
      FUseEdge := True
    else
      FeedKey(KEY_ESCAPE, '');
  end
  else if Sender = BtnWeapon then
    NextWeapon
  else if Sender = BtnRun then
  begin
    FRunLock := not FRunLock;
    FHoldRun := FRunLock;
    ShowToggle(BtnRun, FRunLock);
  end
  else if Sender = BtnSide then
  begin
    FSideLock := not FSideLock;
    FHoldStrafe := FSideLock;
    ShowToggle(BtnSide, FSideLock);
  end
  else if Sender = BtnEsc then
    FeedKey(KEY_ESCAPE, '');
end;

procedure TFormMain.PadUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Sender = BtnUp then
  begin
    FPadUp := False;
    FHoldUp := False;
  end
  else if Sender = BtnDown then
  begin
    FPadDown := False;
    FHoldDown := False;
  end
  else if Sender = BtnLeft then
  begin
    FPadLeft := False;
    FHoldLeft := False;
  end
  else if Sender = BtnRight then
  begin
    FPadRight := False;
    FHoldRight := False;
  end
  else if Sender = BtnFire then
  begin
    FPadFire := False;
    FHoldFire := False;
  end;
end;

procedure TFormMain.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  K, Delta: Integer;
  Ch: string;
  MenuUp: Boolean;
begin
  if (Key = vkReturn) and (ssAlt in Shift) then
  begin
    ToggleFull;
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  MenuUp := (FMenu = nil) or not FMenu.Active;
  Delta := 0;
  if (Key = vkAdd) or (KeyChar = '+') or (KeyChar = '=') then
    Delta := 1
  else if (Key = vkSubtract) or (KeyChar = '-') or (KeyChar = '_') then
    Delta := -1;
  if MenuUp and (Delta <> 0) then
  begin
    ChangeScale(Delta);
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  if MenuUp and (Key = vkF11) then
  begin
    FShowFps := not FShowFps;
    if FFpsLabel <> nil then
      FFpsLabel.Visible := FShowFps;
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  Ch := '';
  if KeyChar <> #0 then
    Ch := KeyChar;
  if (FAuto <> nil) and (FHost <> nil) and (FHost.Gamestate = GS_LEVEL) and
    ((FMenu = nil) or not FMenu.Active) and FAuto.Eat(Key, Ch, FWorld, FPlayer) then
  begin
    Key := 0;
    KeyChar := #0;
    Exit;
  end;
  K := KEY_NONE;
  case Key of
    vkEscape: K := KEY_ESCAPE;
    vkUp: K := KEY_UP;
    vkDown: K := KEY_DOWN;
    vkLeft: K := KEY_LEFT;
    vkRight: K := KEY_RIGHT;
    vkReturn: K := KEY_ENTER;
    vkBack: K := KEY_BACK;
    vkF1: K := KEY_F1;
    vkF2: K := KEY_F2;
    vkF3: K := KEY_F3;
  end;
  if (K = KEY_NONE) and (Length(Ch) = 1) then
  begin
    if (Ch[1] = 'y') or (Ch[1] = 'Y') then
      K := KEY_Y
    else if (Ch[1] = 'n') or (Ch[1] = 'N') then
      K := KEY_N
    else if (Ch[1] = ',') or (Ch[1] = '<') then
      FHoldSideL := True
    else if (Ch[1] = '.') or (Ch[1] = '>') then
      FHoldSideR := True;
  end;
  if ssShift in Shift then
    FHoldRun := True;
  if ssAlt in Shift then
    FHoldStrafe := True;
  if ssCtrl in Shift then
    FHoldFire := True;
  if ((FMenu = nil) or not FMenu.Active) and
    ((Key = VK_SPACE) or (Key = VK_E) or (KeyChar = ' ') or (KeyChar = 'e') or (KeyChar = 'E')) and
    not FUseDown then
  begin
    FUseDown := True;
    FUseEdge := True;
  end;
  case Key of
    vkUp: FHoldUp := True;
    vkDown: FHoldDown := True;
    vkLeft: FHoldLeft := True;
    vkRight: FHoldRight := True;
    vkShift, vkLShift, vkRShift: FHoldRun := True;
    vkMenu, vkLMenu, vkRMenu: FHoldStrafe := True;
    vkControl, vkLControl, vkRControl: FHoldFire := True;
    VK_COMMA: FHoldSideL := True;
    VK_PERIOD: FHoldSideR := True;
    vkReturn:
      if (FHost <> nil) and ((FHost.Gamestate = GS_FINALE) or (FHost.Gamestate = GS_INTERMISSION)) and
        not FUseDown then
      begin
        FUseDown := True;
        FUseEdge := True;
      end;
  end;
  if (FPlayer <> nil) and (FHost <> nil) and (FHost.Gamestate = GS_LEVEL) and
    ((FMenu = nil) or not FMenu.Active) and (Length(Ch) = 1) and (Ch[1] >= '1') and (Ch[1] <= '7') then
    FPlayer.SelectWeapon(Ord(Ch[1]) - Ord('1'));
  if (FHost <> nil) and (FHost.Gamestate = GS_LEVEL) and ((FMenu = nil) or not FMenu.Active) then
    FeedCheat(Ch);
  if (K <> KEY_NONE) or (Ch <> '') then
    FeedKey(K, Ch);
  Key := 0;
  KeyChar := #0;
end;

procedure TFormMain.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  case Key of
    vkUp: FHoldUp := False;
    vkDown: FHoldDown := False;
    vkLeft: FHoldLeft := False;
    vkRight: FHoldRight := False;
    vkShift, vkLShift, vkRShift: FHoldRun := False;
    vkMenu, vkLMenu, vkRMenu: FHoldStrafe := False;
    vkControl, vkLControl, vkRControl: FHoldFire := False;
    VK_COMMA: FHoldSideL := False;
    VK_PERIOD: FHoldSideR := False;
    VK_SPACE, VK_E, vkReturn: FUseDown := False;
  end;
  if (KeyChar = ' ') or (KeyChar = 'e') or (KeyChar = 'E') then
    FUseDown := False;
  if (KeyChar = ',') or (KeyChar = '<') then
    FHoldSideL := False
  else if (KeyChar = '.') or (KeyChar = '>') then
    FHoldSideR := False;
  Key := 0;
  KeyChar := #0;
end;

procedure TFormMain.GameTimerTimer(Sender: TObject);
var
  OldX, OldY: Integer;
  NeedWipe, Go: Boolean;
begin
  if FWiping and (FWipe <> nil) then
  begin
    FWiping := not FWipe.Tick(FFb);
    if FMenu <> nil then
      FMenu.Draw(FFb);
    PaintFrame;
    Exit;
  end;
  if FHost <> nil then
  begin
    FHoldPage := FHost.PendingLevel;
    if FHost.PendingLevel then
      EnterLevel;
    if (FHost.Gamestate = GS_LEVEL) and (FPlayer <> nil) and (FWorld <> nil) and
      ((FMenu = nil) or not FMenu.Active) then
    begin
      OldX := FPlayer.X;
      OldY := FPlayer.Y;
      SyncHolds;
      if LayPad.Visible then
      begin
        FHoldRun := FRunLock;
        FHoldStrafe := FSideLock;
      end;
      FPlayer.Tick(FWorld, FHoldUp, FHoldDown, FHoldLeft, FHoldRight, FHoldFire, FHoldRun,
        FHoldStrafe, FHoldSideL, FHoldSideR);
      if FStatus <> nil then
        FStatus.Ticker(FPlayer, FHoldFire);
      if FSpecials <> nil then
      begin
        if FUseEdge then
          FSpecials.Use;
        FSpecials.Cross(OldX, OldY);
        FSpecials.Shoot(FPlayer.ShotLine);
        FSpecials.Tick;
        if FSpecials.ExitRequested then
          FinishLevel;
      end;
      if (FEnemies <> nil) and (FHost.Gamestate = GS_LEVEL) then
        FEnemies.Tick(FPlayer.Fired);
      FUseEdge := False;
      if FHost.Gamestate = GS_LEVEL then
        FHost.Notice := FPlayer.StatusLine(FWorld.MapName);
    end;
    if (FHost.Gamestate = GS_INTERMISSION) and (FInter <> nil) then
    begin
      Go := False;
      if (FMenu = nil) or not FMenu.Active then
      begin
        if FHoldFire and not FWasFire then
          Go := True;
        if FUseDown and not FWasUse then
          Go := True;
      end;
      FInter.Tick(Go);
      if FInter.Done then
      begin
        FInter.Free;
        FInter := nil;
        if FWantFinale then
        begin
          FWantFinale := False;
          StartFinale(FFinaleMap, True);
        end
        else
        begin
          FHost.MapN := FNextMap;
          FCarry := True;
          FHost.PendingLevel := True;
          FHost.Gamestate := GS_LEVEL;
          EnterLevel;
        end;
      end;
    end;
    if (FHost.Gamestate = GS_FINALE) and (FFinale <> nil) then
    begin
      Go := False;
      if (FMenu = nil) or not FMenu.Active then
      begin
        if FHoldFire and not FWasFire then
          Go := True;
        if FUseDown and not FWasUse then
          Go := True;
      end;
      if FFinale.Tick(Go) then
      begin
        if FFinale.ToTitle then
        begin
          FFinale.Free;
          FFinale := nil;
          FHost.ReturnToTitle;
          if FHost.Sound <> nil then
            FHost.Sound.PlayTitle;
        end
        else
        begin
          FFinale.Free;
          FFinale := nil;
          FHost.MapN := FNextMap;
          FCarry := True;
          FHost.PendingLevel := True;
          FHost.Gamestate := GS_LEVEL;
          EnterLevel;
        end;
      end;
    end;
    FWasFire := FHoldFire;
    FWasUse := FUseDown;
  end;
  if FMenu <> nil then
    FMenu.Ticker;
  if (FHost <> nil) and (FHost.Gamestate = GS_TITLE) then
  begin
    if FWasLevel then
    begin
      FWasLevel := False;
      if FHost.Sound <> nil then
        FHost.Sound.PlayTitle;
      FSequence := -1;
      FAdvance := False;
      FHoldPage := False;
      AdvanceDemo;
    end
    else
    begin
      if FAdvance and not FHoldPage then
        AdvanceDemo;
      if not FHoldPage then
      begin
        Dec(FPageTic);
        if FPageTic < 0 then
          FAdvance := True;
      end;
    end;
  end;
  if (FHost <> nil) and (FHost.Sound <> nil) then
    FHost.Sound.Update;
  NeedWipe := (FHost <> nil) and (FWipe <> nil) and (FHost.Gamestate <> FWipeState);
  if NeedWipe then
    FWipe.CaptureStart(FFb);
  Compose;
  if NeedWipe then
  begin
    FWipe.CaptureEnd(FFb);
    FWipe.BeginMelt(FFb);
    FWipeState := FHost.Gamestate;
    FWiping := True;
  end;
  if FMenu <> nil then
    FMenu.Draw(FFb);
  Inc(FFpsCount);
  if TThread.GetTickCount - FFpsStamp >= 1000 then
  begin
    FFpsShown := FFpsCount;
    FFpsStamp := TThread.GetTickCount;
    FFpsCount := 0;
  end;
  PaintFrame;
end;

procedure TFormMain.BuildCrt(Dw, Dh: Integer);
var
  X, Y, Ix, Iy, Pix, M, C: Integer;
  Ny, Nx, U, V, Sx, Sy, Uu, Vv, Vig, Dist, Gain, Sl, Off, Boost: Double;
begin
  if (Dw < 2) or (Dh < 2) then
    Exit;
  if (FCrtW = Dw) and (FCrtH = Dh) and (Length(FCrtMap) = Dw * Dh) then
    Exit;
  FCrtW := Dw;
  FCrtH := Dh;
  SetLength(FCrtMap, Dw * Dh);
  SetLength(FCrtGain, Dw * Dh);
  Sl := Dh / SCREENHEIGHT - 1.0;
  if Sl < 0 then
    Sl := 0;
  if Sl > 1 then
    Sl := 1;
  Sl := Sl * 0.45;
  for Y := 0 to Dh - 1 do
  begin
    Ny := 2.0 * Y / Dh - 1.0;
    for X := 0 to Dw - 1 do
    begin
      Nx := 2.0 * (X + 0.5) / Dw - 1.0;
      U := Nx * (1.0 + (Ny * Ny) / 32.0);
      V := Ny * (1.0 + (Nx * Nx) / 24.0);
      Pix := Y * Dw + X;
      if (U <= -1.0) or (U >= 1.0) or (V <= -1.0) or (V >= 1.0) then
      begin
        FCrtMap[Pix] := $FFFF;
        FCrtGain[Pix] := 0;
        Continue;
      end;
      Sx := (U + 1.0) * 0.5 * SCREENWIDTH;
      Sy := (V + 1.0) * 0.5 * SCREENHEIGHT;
      Ix := Trunc(Sx);
      Iy := Trunc(Sy);
      if Ix < 0 then
        Ix := 0;
      if Ix > SCREENWIDTH - 1 then
        Ix := SCREENWIDTH - 1;
      if Iy < 0 then
        Iy := 0;
      if Iy > SCREENHEIGHT - 1 then
        Iy := SCREENHEIGHT - 1;
      Dist := (Sy - Iy) - 0.5;
      Uu := (U + 1.0) * 0.5;
      Vv := (V + 1.0) * 0.5;
      Vig := 16.0 * Uu * Vv * (1.0 - Uu) * (1.0 - Vv);
      if Vig < 1E-20 then
        Vig := 1E-20;
      Gain := (1.0 - Sl * 4.0 * Dist * Dist) * Power(Vig, 0.12) * 255.0;
      if Gain < 0 then
        Gain := 0;
      if Gain > 255 then
        Gain := 255;
      FCrtMap[Pix] := Word(Iy * SCREENWIDTH + Ix);
      FCrtGain[Pix] := Byte(Round(Gain));
    end;
  end;
  if Dw >= 2 * SCREENWIDTH then
  begin
    Off := 0.70;
    Boost := 1.40;
  end
  else
  begin
    Off := 1.0;
    Boost := 1.15;
  end;
  for M := 0 to 2 do
    for C := 0 to 2 do
      if M = C then
        FCrtMask[M, C] := Round(256.0 * Boost)
      else
        FCrtMask[M, C] := Round(256.0 * Boost * Off);
end;

procedure TFormMain.PresentCrt;
var
  Data: TBitmapData;
  Dw, Dh, X, Y, SrcI, LeftI, RightI, Pix, Idx, Gain, R, G, B, M: Integer;
  Row: PByte;
  Color: TAlphaColor;
begin
  Dw := Round(ImageView.Width);
  Dh := Round(ImageView.Height);
  if (Dw < 2) or (Dh < 2) then
  begin
    ImageView.Bitmap.Assign(FBmp);
    Exit;
  end;
  BuildCrt(Dw, Dh);
  if Length(FRgb) <> SCREENPIXELS * 3 then
    SetLength(FRgb, SCREENPIXELS * 3);
  if Length(FBlur) <> SCREENPIXELS * 3 then
    SetLength(FBlur, SCREENPIXELS * 3);
  for Y := 0 to SCREENHEIGHT - 1 do
    for X := 0 to SCREENWIDTH - 1 do
    begin
      if Length(FFb) = SCREENPIXELS then
        Color := FPal[FFb[Y * SCREENWIDTH + X]]
      else
        Color := $FF181818;
      Pix := (Y * SCREENWIDTH + X) * 3;
      FRgb[Pix] := Byte((Color shr 16) and $FF);
      FRgb[Pix + 1] := Byte((Color shr 8) and $FF);
      FRgb[Pix + 2] := Byte(Color and $FF);
    end;
  for Y := 0 to SCREENHEIGHT - 1 do
    for X := 0 to SCREENWIDTH - 1 do
    begin
      SrcI := (Y * SCREENWIDTH + X) * 3;
      if X = 0 then
        LeftI := SrcI
      else
        LeftI := SrcI - 3;
      if X = SCREENWIDTH - 1 then
        RightI := SrcI
      else
        RightI := SrcI + 3;
      FBlur[SrcI] := Byte((FRgb[LeftI] + FRgb[SrcI] * 2 + FRgb[RightI]) shr 2);
      FBlur[SrcI + 1] := Byte((FRgb[LeftI + 1] + FRgb[SrcI + 1] * 2 + FRgb[RightI + 1]) shr 2);
      FBlur[SrcI + 2] := Byte((FRgb[LeftI + 2] + FRgb[SrcI + 2] * 2 + FRgb[RightI + 2]) shr 2);
    end;
  if (FView = nil) or (FView.Width <> Dw) or (FView.Height <> Dh) then
  begin
    FView.Free;
    FView := FMX.Graphics.TBitmap.Create(Dw, Dh);
  end;
  if not FView.Map(TMapAccess.Write, Data) then
    Exit;
  try
    for Y := 0 to Dh - 1 do
    begin
      Row := PByte(Data.GetScanline(Y));
      for X := 0 to Dw - 1 do
      begin
        Pix := Y * Dw + X;
        Idx := FCrtMap[Pix];
        if Idx = $FFFF then
          Color := $FF000000
        else
        begin
          Idx := Idx * 3;
          Gain := FCrtGain[Pix];
          M := X mod 3;
          R := (FBlur[Idx] * Gain * FCrtMask[M, 0]) shr 16;
          G := (FBlur[Idx + 1] * Gain * FCrtMask[M, 1]) shr 16;
          B := (FBlur[Idx + 2] * Gain * FCrtMask[M, 2]) shr 16;
          if R > 255 then
            R := 255;
          if G > 255 then
            G := 255;
          if B > 255 then
            B := 255;
          Color := TAlphaColor($FF000000 or Cardinal(R shl 16) or Cardinal(G shl 8) or Cardinal(B));
        end;
        PAlphaColor(Row)^ := ScreenColor(Data, Color);
        Inc(Row, 4);
      end;
    end;
  finally
    FView.Unmap(Data);
  end;
  ImageView.Bitmap.Assign(FView);
end;

procedure TFormMain.PlaceFps;
begin
  if FFpsLabel = nil then
    Exit;
  FFpsLabel.Visible := FShowFps;
  if not FShowFps then
    Exit;
  FFpsLabel.Text := IntToStr(FFpsShown) + ' FPS';
  FFpsLabel.Position.X := ClientWidth - FFpsLabel.Width - 8;
  FFpsLabel.Position.Y := 4;
  FFpsLabel.BringToFront;
end;

function ScreenColor(const Data: TBitmapData; Color: TAlphaColor): TAlphaColor;
var
  R, G, B: Cardinal;
begin
  if Data.PixelFormat = TPixelFormat.RGBA then
  begin
    R := (Color shr 16) and $FF;
    G := (Color shr 8) and $FF;
    B := Color and $FF;
    Result := TAlphaColor($FF000000 or (B shl 16) or (G shl 8) or R);
  end
  else
    Result := Color;
end;

procedure TFormMain.PaintFrame;
var
  Data: TBitmapData;
  X, Y: Integer;
  Row: PByte;
  Color: TAlphaColor;
begin
  ApplyPalette;
  if FCrt then
  begin
    PresentCrt;
    PlaceFps;
    Exit;
  end;
  if not FBmp.Map(TMapAccess.Write, Data) then
    Exit;
  try
    for Y := 0 to SCREENHEIGHT - 1 do
    begin
      Row := PByte(Data.GetScanline(Y));
      for X := 0 to SCREENWIDTH - 1 do
      begin
        if Length(FFb) = SCREENPIXELS then
          Color := FPal[FFb[Y * SCREENWIDTH + X]]
        else
          Color := $FF181818;
        PAlphaColor(Row)^ := ScreenColor(Data, Color);
        Inc(Row, 4);
      end;
    end;
  finally
    FBmp.Unmap(Data);
  end;
  ImageView.Bitmap.Assign(FBmp);
  PlaceFps;
end;

end.
