unit Doom.Menu;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Menu do jogo, igual a doom/menu.py. O som sai pelos lumps DS*.
  Novo jogo guarda episodio e habilidade. O mapa entra na fase seguinte.
}

interface

uses
  System.SysUtils, System.Generics.Collections, Doom.Wad, Doom.Sound;

const
  GS_TITLE = 0;
  GS_LEVEL = 1;
  GS_INTERMISSION = 2;
  GS_FINALE = 3;

type
  THostSave = function(Slot: Integer; const Desc: string): Boolean of object;
  THostLoad = function(Slot: Integer): Boolean of object;
  THostRead = function(Slot: Integer; out Desc: string): Boolean of object;

const
  KEY_NONE = 0;
  KEY_ESCAPE = 1;
  KEY_UP = 2;
  KEY_DOWN = 3;
  KEY_LEFT = 4;
  KEY_RIGHT = 5;
  KEY_ENTER = 6;
  KEY_BACK = 7;
  KEY_F1 = 8;
  KEY_F2 = 9;
  KEY_F3 = 10;
  KEY_Y = 11;
  KEY_N = 12;
  TICRATE = 35;
  HU_FONTSTART = 33;
  HU_FONTSIZE = 63;
  SAVESTRINGSIZE = 24;
  LOADSAVEEMPTY = 'empty slot';

type
  TDoomSound = class
  public
    SfxVolume: Integer;
    MusicVolume: Integer;
    procedure Open(AWad: TWad);
    procedure Play(const Name: string);
    procedure PlayTitle;
    procedure PlayLevel(Episode, MapN: Integer);
    procedure Update;
    procedure SetSfxVolume(Vol: Integer);
    procedure SetMusicVolume(Vol: Integer);
    destructor Destroy; override;
  private
    FAudio: TGameSound;
  end;

  TDoomHost = class
  public
    Wad: TWad;
    Sound: TDoomSound;
    Gamestate: Integer;
    ShowMessages: Boolean;
    DetailLevel: Integer;
    ScreenSize: Integer;
    MouseSensitivity: Integer;
    Running: Boolean;
    Episode: Integer;
    MapN: Integer;
    Skill: Integer;
    HasPlayer: Boolean;
    PendingLevel: Boolean;
    Notice: string;
    OnSave: THostSave;
    OnLoad: THostLoad;
    OnRead: THostRead;
    constructor Create(AWad: TWad);
    destructor Destroy; override;
    procedure StartNewGame(ASkill, AEpi, AMap: Integer);
    function LoadGame(Slot: Integer): Boolean;
    function SaveGame(Slot: Integer; const Desc: string): Boolean;
    procedure ReturnToTitle;
    procedure ApplyViewSize;
  end;

  TDoomMenu = class
  public
    Active: Boolean;
    constructor Create(AWad: TWad; AHost: TDoomHost);
    destructor Destroy; override;
    procedure Ticker;
    procedure Start;
    procedure Clear;
    function Responder(Key: Integer; const Ch: string): Boolean;
    procedure Draw(var Fb: TBytes);
  private
    FWad: TWad;
    FHost: TDoomHost;
    FMenus: TObjectDictionary<string, TObject>;
    FScreen: string;
    FItemOn: Integer;
    FWhichSkull: Integer;
    FSkullTics: Integer;
    FEpi: Integer;
    FMessage: string;
    FMessageOn: Boolean;
    FMessageConfirm: Boolean;
    FMessageAction: string;
    FSaveStrings: array[0..5] of string;
    FSaveSlotOk: array[0..5] of Boolean;
    FSaveStringEnter: Boolean;
    FSaveSlot: Integer;
    FSaveOldString: string;
    FSaveCharIndex: Integer;
    function HasEpisodes: Boolean;
    function HasLump(const Name: string): Boolean;
    function PatchOf(const Name: string): TBytes;
    procedure GotoScreen(const Name: string);
    procedure DoAction(const Action: string; Choice: Integer);
    procedure OpenHelp;
    procedure ReadSaveStrings;
    procedure OpenLoad;
    procedure OpenSave;
    procedure BeginSaveName(Slot: Integer);
    function SaveStringKey(Key: Integer; const Ch: string): Boolean;
    procedure DoSave(Slot: Integer);
    function StringWidth(const Text: string): Integer;
    function WriteText(var Fb: TBytes; X, Y: Integer; const Text: string): Integer;
    procedure DrawSaveLoadBorder(var Fb: TBytes; X, Y: Integer);
    procedure DrawSaveSlots(var Fb: TBytes; Menu: TObject);
    procedure DrawThermo(var Fb: TBytes; X, Y, Width, Dot: Integer);
    procedure DrawMessage(var Fb: TBytes);
  end;

  TMenuItem = record
    Status: Integer;
    Name: string;
    Action: string;
    Alpha: Integer;
  end;

  TMenuDef = class
  public
    Items: TArray<TMenuItem>;
    Routine: string;
    X: Integer;
    Y: Integer;
    LastOn: Integer;
    Prev: string;
  end;

implementation

uses
  Doom.VVideo;

const
  LINEHEIGHT = 16;
  SKULLXOFF = -32;

function Item(Status: Integer; const Name, Action: string; Alpha: Integer): TMenuItem;
begin
  Result.Status := Status;
  Result.Name := Name;
  Result.Action := Action;
  Result.Alpha := Alpha;
end;

destructor TDoomSound.Destroy;
begin
  FAudio.Free;
  inherited;
end;

procedure TDoomSound.Open(AWad: TWad);
begin
  if FAudio = nil then
    FAudio := TGameSound.Create;
  FAudio.SetSfxVolume(SfxVolume);
  FAudio.SetMusicVolume(MusicVolume);
  FAudio.Open(AWad);
end;

procedure TDoomSound.Play(const Name: string);
begin
  if FAudio <> nil then
    FAudio.Play(Name);
end;

procedure TDoomSound.PlayTitle;
begin
  if FAudio <> nil then
    FAudio.PlayTitle;
end;

procedure TDoomSound.PlayLevel(Episode, MapN: Integer);
begin
  if FAudio <> nil then
    FAudio.PlayLevel(Episode, MapN);
end;

procedure TDoomSound.Update;
begin
  if FAudio <> nil then
    FAudio.Update;
end;

procedure TDoomSound.SetSfxVolume(Vol: Integer);
begin
  if Vol < 0 then
    Vol := 0;
  if Vol > 15 then
    Vol := 15;
  SfxVolume := Vol;
  if FAudio <> nil then
    FAudio.SetSfxVolume(Vol);
end;

procedure TDoomSound.SetMusicVolume(Vol: Integer);
begin
  if Vol < 0 then
    Vol := 0;
  if Vol > 15 then
    Vol := 15;
  MusicVolume := Vol;
  if FAudio <> nil then
    FAudio.SetMusicVolume(Vol);
end;

constructor TDoomHost.Create(AWad: TWad);
begin
  inherited Create;
  Wad := AWad;
  Sound := TDoomSound.Create;
  Sound.SfxVolume := 8;
  Sound.MusicVolume := 8;
  Sound.Open(AWad);
  Sound.PlayTitle;
  Gamestate := GS_TITLE;
  ShowMessages := True;
  DetailLevel := 0;
  ScreenSize := 7;
  MouseSensitivity := 5;
  Running := True;
  Episode := 1;
  MapN := 1;
  Skill := 2;
end;

destructor TDoomHost.Destroy;
begin
  Sound.Free;
  inherited;
end;

procedure TDoomHost.StartNewGame(ASkill, AEpi, AMap: Integer);
begin
  Skill := ASkill;
  Episode := AEpi;
  MapN := AMap;
  PendingLevel := True;
  Notice := Format('E%dM%d skill %d', [Episode, MapN, Skill]);
end;

function TDoomHost.LoadGame(Slot: Integer): Boolean;
begin
  Result := Assigned(OnLoad) and OnLoad(Slot);
end;

function TDoomHost.SaveGame(Slot: Integer; const Desc: string): Boolean;
begin
  Result := Assigned(OnSave) and OnSave(Slot, Desc);
end;

procedure TDoomHost.ReturnToTitle;
begin
  HasPlayer := False;
  PendingLevel := False;
  Gamestate := GS_TITLE;
  Notice := '';
end;

procedure TDoomHost.ApplyViewSize;
begin
end;

constructor TDoomMenu.Create(AWad: TWad; AHost: TDoomHost);
var
  Main, Episode, Skill, Options, Sound, Load, Save, Read1, Read2: TMenuDef;
  I: Integer;
begin
  inherited Create;
  FWad := AWad;
  FHost := AHost;
  FSkullTics := 8;
  FScreen := 'main';
  FMenus := TObjectDictionary<string, TObject>.Create([doOwnsValues]);
  for I := 0 to 5 do
  begin
    FSaveStrings[I] := LOADSAVEEMPTY;
    FSaveSlotOk[I] := False;
  end;

  Main := TMenuDef.Create;
  Main.Routine := 'main';
  Main.X := 97;
  Main.Y := 64;
  Main.Items := TArray<TMenuItem>.Create(
    Item(1, 'M_NGAME', 'newgame', 110),
    Item(1, 'M_OPTION', 'options', 111),
    Item(1, 'M_LOADG', 'loadgame', 108),
    Item(1, 'M_SAVEG', 'savegame', 115),
    Item(1, 'M_RDTHIS', 'readthis', 114),
    Item(1, 'M_QUITG', 'quit', 113)
  );

  Episode := TMenuDef.Create;
  Episode.Routine := 'episode';
  Episode.X := 48;
  Episode.Y := 63;
  Episode.Prev := 'main';
  Episode.Items := TArray<TMenuItem>.Create(
    Item(1, 'M_EPI1', 'episode', 107),
    Item(1, 'M_EPI2', 'episode', 116),
    Item(1, 'M_EPI3', 'episode', 105),
    Item(1, 'M_EPI4', 'episode', 116)
  );

  Skill := TMenuDef.Create;
  Skill.Routine := 'skill';
  Skill.X := 48;
  Skill.Y := 63;
  Skill.LastOn := 2;
  Skill.Prev := 'episode';
  Skill.Items := TArray<TMenuItem>.Create(
    Item(1, 'M_JKILL', 'skill', 105),
    Item(1, 'M_ROUGH', 'skill', 104),
    Item(1, 'M_HURT', 'skill', 104),
    Item(1, 'M_ULTRA', 'skill', 117),
    Item(1, 'M_NMARE', 'skill', 110)
  );

  Options := TMenuDef.Create;
  Options.Routine := 'options';
  Options.X := 60;
  Options.Y := 37;
  Options.Prev := 'main';
  Options.Items := TArray<TMenuItem>.Create(
    Item(1, 'M_ENDGAM', 'endgame', 101),
    Item(1, 'M_MESSG', 'messages', 109),
    Item(1, 'M_DETAIL', 'detail', 103),
    Item(2, 'M_SCRNSZ', 'scrnsize', 115),
    Item(-1, '', '', 0),
    Item(2, 'M_MSENS', 'mousesens', 109),
    Item(-1, '', '', 0),
    Item(1, 'M_SVOL', 'sound', 115)
  );

  Sound := TMenuDef.Create;
  Sound.Routine := 'sound';
  Sound.X := 80;
  Sound.Y := 64;
  Sound.Prev := 'options';
  Sound.Items := TArray<TMenuItem>.Create(
    Item(2, 'M_SFXVOL', 'sfxvol', 115),
    Item(-1, '', '', 0),
    Item(2, 'M_MUSVOL', 'musvol', 109),
    Item(-1, '', '', 0)
  );

  Load := TMenuDef.Create;
  Load.Routine := 'load';
  Load.X := 80;
  Load.Y := 54;
  Load.Prev := 'main';
  SetLength(Load.Items, 6);
  for I := 0 to 5 do
    Load.Items[I] := Item(1, '', 'loadslot', 0);

  Save := TMenuDef.Create;
  Save.Routine := 'save';
  Save.X := 80;
  Save.Y := 54;
  Save.Prev := 'main';
  SetLength(Save.Items, 6);
  for I := 0 to 5 do
    Save.Items[I] := Item(1, '', 'saveslot', 0);

  Read1 := TMenuDef.Create;
  Read1.Routine := 'read1';
  Read1.X := 280;
  Read1.Y := 185;
  Read1.Prev := 'main';
  Read1.Items := TArray<TMenuItem>.Create(Item(1, '', 'read2', 0));

  Read2 := TMenuDef.Create;
  Read2.Routine := 'read2';
  Read2.X := 330;
  Read2.Y := 175;
  Read2.Prev := 'read1';
  Read2.Items := TArray<TMenuItem>.Create(Item(1, '', 'finishread', 0));

  if not HasEpisodes then
    Skill.Prev := 'main';

  FMenus.Add('main', Main);
  FMenus.Add('episode', Episode);
  FMenus.Add('skill', Skill);
  FMenus.Add('options', Options);
  FMenus.Add('sound', Sound);
  FMenus.Add('load', Load);
  FMenus.Add('save', Save);
  FMenus.Add('read1', Read1);
  FMenus.Add('read2', Read2);
end;

destructor TDoomMenu.Destroy;
begin
  FMenus.Free;
  inherited;
end;

function TDoomMenu.HasEpisodes: Boolean;
begin
  if FWad.CheckNumForName('MAP01') >= 0 then
    Exit(False);
  Result := FWad.CheckNumForName('E2M1') >= 0;
end;

function TDoomMenu.HasLump(const Name: string): Boolean;
begin
  Result := FWad.CheckNumForName(Name) >= 0;
end;

function TDoomMenu.PatchOf(const Name: string): TBytes;
var
  N: Integer;
begin
  N := FWad.CheckNumForName(Name);
  if N < 0 then
    Exit(nil);
  Result := FWad.CacheLumpNum(N);
end;

procedure TDoomMenu.Ticker;
begin
  if not Active then
    Exit;
  Dec(FSkullTics);
  if FSkullTics <= 0 then
  begin
    FWhichSkull := FWhichSkull xor 1;
    FSkullTics := 8;
  end;
end;

procedure TDoomMenu.Start;
begin
  if Active then
    Exit;
  Active := True;
  FScreen := 'main';
  FItemOn := TMenuDef(FMenus['main']).LastOn;
  FMessageOn := False;
  FSaveStringEnter := False;
  FHost.Sound.Play('swtchn');
end;

procedure TDoomMenu.Clear;
begin
  Active := False;
  FMessageOn := False;
  FSaveStringEnter := False;
end;

procedure TDoomMenu.GotoScreen(const Name: string);
begin
  TMenuDef(FMenus[FScreen]).LastOn := FItemOn;
  FScreen := Name;
  FItemOn := TMenuDef(FMenus[Name]).LastOn;
end;

procedure TDoomMenu.OpenHelp;
begin
  Active := True;
  FMessageOn := False;
  FSaveStringEnter := False;
  TMenuDef(FMenus['read1']).LastOn := 0;
  FScreen := 'read1';
  FItemOn := 0;
  FHost.Sound.Play('swtchn');
end;

procedure TDoomMenu.ReadSaveStrings;
var
  Load, Save: TMenuDef;
  I: Integer;
  Row: TMenuItem;
begin
  Load := TMenuDef(FMenus['load']);
  Save := TMenuDef(FMenus['save']);
  for I := 0 to 5 do
  begin
    if not Assigned(FHost.OnRead) or not FHost.OnRead(I, FSaveStrings[I]) then
    begin
      FSaveStrings[I] := LOADSAVEEMPTY;
      FSaveSlotOk[I] := False;
    end
    else
      FSaveSlotOk[I] := True;
    Row := Load.Items[I];
    Row.Status := 0;
    Load.Items[I] := Row;
    Row := Save.Items[I];
    Row.Status := 1;
    Save.Items[I] := Row;
  end;
end;

procedure TDoomMenu.OpenLoad;
begin
  ReadSaveStrings;
  FSaveStringEnter := False;
  FMessageOn := False;
  if not Active then
  begin
    Active := True;
    FScreen := 'load';
    FItemOn := TMenuDef(FMenus['load']).LastOn;
  end
  else
    GotoScreen('load');
  FHost.Sound.Play('swtchn');
end;

procedure TDoomMenu.OpenSave;
begin
  ReadSaveStrings;
  FSaveStringEnter := False;
  FMessageOn := False;
  if not Active then
  begin
    Active := True;
    FScreen := 'save';
    FItemOn := TMenuDef(FMenus['save']).LastOn;
  end
  else
    GotoScreen('save');
  FHost.Sound.Play('swtchn');
end;

procedure TDoomMenu.BeginSaveName(Slot: Integer);
begin
  FSaveStringEnter := True;
  FSaveSlot := Slot;
  FSaveOldString := FSaveStrings[Slot];
  if FSaveStrings[Slot] = LOADSAVEEMPTY then
    FSaveStrings[Slot] := '';
  FSaveCharIndex := Length(FSaveStrings[Slot]);
end;

function TDoomMenu.StringWidth(const Text: string): Integer;
var
  Ch: Char;
  C, W: Integer;
  P: TBytes;
  Upper: string;
begin
  Result := 0;
  Upper := UpperCase(Text);
  for Ch in Upper do
  begin
    C := Ord(Ch) - HU_FONTSTART;
    if (C < 0) or (C >= HU_FONTSIZE) then
    begin
      Inc(Result, 4);
      Continue;
    end;
    P := PatchOf(Format('STCFN%.3d', [Ord(Ch)]));
    if Length(P) > 0 then
    begin
      W := PatchWidth(P);
      if W < 4 then
        W := 4;
      Inc(Result, W);
    end
    else
      Inc(Result, 8);
  end;
end;

function TDoomMenu.SaveStringKey(Key: Integer; const Ch: string): Boolean;
var
  Slot, Code: Integer;
  One, Name: string;
begin
  Result := True;
  Slot := FSaveSlot;
  if Key = KEY_BACK then
  begin
    if FSaveCharIndex > 0 then
    begin
      Dec(FSaveCharIndex);
      FSaveStrings[Slot] := Copy(FSaveStrings[Slot], 1, FSaveCharIndex);
    end;
    Exit;
  end;
  if Key = KEY_ESCAPE then
  begin
    FSaveStringEnter := False;
    FSaveStrings[Slot] := FSaveOldString;
    Exit;
  end;
  if Key = KEY_ENTER then
  begin
    FSaveStringEnter := False;
    if FSaveStrings[Slot] <> '' then
      DoSave(Slot)
    else
      FSaveStrings[Slot] := FSaveOldString;
    Exit;
  end;
  One := UpperCase(Ch);
  if Length(One) <> 1 then
    Exit;
  Code := Ord(One[1]);
  if One <> ' ' then
  begin
    if (Code - HU_FONTSTART < 0) or (Code - HU_FONTSTART >= HU_FONTSIZE) then
      Exit;
  end;
  Name := FSaveStrings[Slot];
  if (Code >= 32) and (Code <= 127) and (FSaveCharIndex < SAVESTRINGSIZE - 1) and
    (StringWidth(Name) < (SAVESTRINGSIZE - 2) * 8) then
  begin
    FSaveStrings[Slot] := Name + One;
    Inc(FSaveCharIndex);
  end;
end;

procedure TDoomMenu.DoSave(Slot: Integer);
begin
  if FHost.SaveGame(Slot, FSaveStrings[Slot]) then
    Clear
  else
    FHost.Sound.Play('oof');
end;

procedure TDoomMenu.DoAction(const Action: string; Choice: Integer);
var
  Vol: Integer;
begin
  if Action = 'newgame' then
  begin
    if (FWad.CheckNumForName('MAP01') >= 0) or not HasEpisodes then
    begin
      FEpi := 0;
      GotoScreen('skill');
    end
    else
      GotoScreen('episode');
  end
  else if Action = 'options' then
    GotoScreen('options')
  else if Action = 'loadgame' then
    OpenLoad
  else if Action = 'savegame' then
  begin
    if (FHost.Gamestate <> GS_LEVEL) or not FHost.HasPlayer then
    begin
      FHost.Sound.Play('oof');
      Exit;
    end;
    OpenSave;
  end
  else if Action = 'loadslot' then
  begin
    if not FSaveSlotOk[Choice] then
    begin
      FHost.Sound.Play('oof');
      Exit;
    end;
    if FHost.LoadGame(Choice) then
      Clear
    else
      FHost.Sound.Play('oof');
  end
  else if Action = 'saveslot' then
    BeginSaveName(Choice)
  else if Action = 'readthis' then
    GotoScreen('read1')
  else if Action = 'read2' then
  begin
    if HasLump('HELP1') and (FScreen = 'read1') then
      GotoScreen('read2')
    else
      GotoScreen('main');
  end
  else if Action = 'finishread' then
    GotoScreen('main')
  else if Action = 'quit' then
  begin
    FMessage := 'ARE YOU SURE YOU WANT TO QUIT?';
    FMessageOn := True;
    FMessageConfirm := True;
    FMessageAction := 'quit';
  end
  else if Action = 'endgame' then
  begin
    if FHost.Gamestate <> GS_LEVEL then
    begin
      FHost.Sound.Play('oof');
      Exit;
    end;
    FMessage := 'END GAME?';
    FMessageOn := True;
    FMessageConfirm := True;
    FMessageAction := 'endgame';
  end
  else if Action = 'sound' then
    GotoScreen('sound')
  else if Action = 'messages' then
  begin
    FHost.ShowMessages := not FHost.ShowMessages;
    if FHost.ShowMessages then
      FHost.Notice := 'Messages On'
    else
      FHost.Notice := 'Messages Off';
  end
  else if Action = 'detail' then
  begin
    if FHost.DetailLevel = 0 then
      FHost.DetailLevel := 1
    else
      FHost.DetailLevel := 0;
    FHost.ApplyViewSize;
    if FHost.DetailLevel = 0 then
      FHost.Notice := 'High detail'
    else
      FHost.Notice := 'Low detail';
  end
  else if Action = 'scrnsize' then
  begin
    if Choice <> 0 then
    begin
      if FHost.ScreenSize < 8 then
        Inc(FHost.ScreenSize);
    end
    else if FHost.ScreenSize > 0 then
      Dec(FHost.ScreenSize);
    FHost.ApplyViewSize;
  end
  else if Action = 'mousesens' then
  begin
    if Choice <> 0 then
    begin
      if FHost.MouseSensitivity < 9 then
        Inc(FHost.MouseSensitivity);
    end
    else if FHost.MouseSensitivity > 0 then
      Dec(FHost.MouseSensitivity);
  end
  else if Action = 'sfxvol' then
  begin
    Vol := FHost.Sound.SfxVolume;
    if Choice <> 0 then
      Inc(Vol)
    else
      Dec(Vol);
    FHost.Sound.SetSfxVolume(Vol);
  end
  else if Action = 'musvol' then
  begin
    Vol := FHost.Sound.MusicVolume;
    if Choice <> 0 then
      Inc(Vol)
    else
      Dec(Vol);
    FHost.Sound.SetMusicVolume(Vol);
  end
  else if Action = 'episode' then
  begin
    if not HasLump('E2M1') and (Choice <> 0) then
    begin
      FMessage := 'ONLY AVAILABLE IN THE REGISTERED VERSION.';
      FMessageOn := True;
      FMessageConfirm := False;
      FMessageAction := '';
      GotoScreen('read1');
      Exit;
    end;
    FEpi := Choice;
    GotoScreen('skill');
  end
  else if Action = 'skill' then
  begin
    FHost.StartNewGame(Choice, FEpi + 1, 1);
    Clear;
  end;
end;

function TDoomMenu.Responder(Key: Integer; const Ch: string): Boolean;
var
  Menu: TMenuDef;
  N: Integer;
  Row: TMenuItem;
  Action: string;
begin
  if FSaveStringEnter then
    Exit(SaveStringKey(Key, Ch));

  if FMessageOn then
  begin
    Result := True;
    if FMessageConfirm then
    begin
      if (Key = KEY_Y) or (Key = KEY_ENTER) then
      begin
        Action := FMessageAction;
        FMessageOn := False;
        if Action = 'quit' then
          FHost.Running := False
        else if Action = 'endgame' then
        begin
          FHost.ReturnToTitle;
          Clear;
        end;
      end
      else if (Key = KEY_N) or (Key = KEY_ESCAPE) then
        FMessageOn := False;
      Exit;
    end;
    if Key <> KEY_NONE then
      FMessageOn := False;
    Exit;
  end;

  if Key = KEY_F2 then
  begin
    DoAction('savegame', 0);
    Exit(True);
  end;
  if Key = KEY_F3 then
  begin
    DoAction('loadgame', 0);
    Exit(True);
  end;
  if Key = KEY_F1 then
  begin
    OpenHelp;
    Exit(True);
  end;

  if not Active then
  begin
    if Key = KEY_ESCAPE then
    begin
      Start;
      Exit(True);
    end;
    Exit(False);
  end;

  Result := True;
  Menu := TMenuDef(FMenus[FScreen]);
  if Key = KEY_ESCAPE then
  begin
    Menu.LastOn := FItemOn;
    Clear;
    FHost.Sound.Play('swtchx');
    Exit;
  end;
  if Key = KEY_BACK then
  begin
    Menu.LastOn := FItemOn;
    if Menu.Prev <> '' then
    begin
      FScreen := Menu.Prev;
      FItemOn := TMenuDef(FMenus[FScreen]).LastOn;
      FHost.Sound.Play('swtchx');
    end
    else
    begin
      Clear;
      FHost.Sound.Play('swtchx');
    end;
    Exit;
  end;
  if Key = KEY_DOWN then
  begin
    N := Length(Menu.Items);
    repeat
      FItemOn := (FItemOn + 1) mod N;
      FHost.Sound.Play('pstop');
    until Menu.Items[FItemOn].Status <> -1;
    Exit;
  end;
  if Key = KEY_UP then
  begin
    N := Length(Menu.Items);
    repeat
      Dec(FItemOn);
      if FItemOn < 0 then
        FItemOn := N - 1;
      FHost.Sound.Play('pstop');
    until Menu.Items[FItemOn].Status <> -1;
    Exit;
  end;
  if (Key = KEY_LEFT) or (Key = KEY_RIGHT) then
  begin
    Row := Menu.Items[FItemOn];
    if (Row.Status = 2) and (Row.Action <> '') then
    begin
      FHost.Sound.Play('stnmov');
      if Key = KEY_LEFT then
        DoAction(Row.Action, 0)
      else
        DoAction(Row.Action, 1);
    end;
    Exit;
  end;
  if Key = KEY_ENTER then
  begin
    Row := Menu.Items[FItemOn];
    if Row.Status <> 0 then
    begin
      Menu.LastOn := FItemOn;
      FHost.Sound.Play('pistol');
      if Row.Status = 2 then
        DoAction(Row.Action, 1)
      else
        DoAction(Row.Action, FItemOn);
    end;
  end;
end;

function TDoomMenu.WriteText(var Fb: TBytes; X, Y: Integer; const Text: string): Integer;
var
  Ch: Char;
  W: Integer;
  P: TBytes;
  Upper: string;
begin
  Result := X;
  Upper := UpperCase(Text);
  for Ch in Upper do
  begin
    if Ch = ' ' then
    begin
      Inc(Result, 4);
      Continue;
    end;
    P := PatchOf(Format('STCFN%.3d', [Ord(Ch)]));
    if Length(P) > 0 then
    begin
      DrawPatch(Fb, Result, Y, P);
      W := PatchWidth(P);
      if W < 4 then
        W := 4;
      Inc(Result, W);
    end
    else
      Inc(Result, 8);
  end;
end;

procedure TDoomMenu.DrawSaveLoadBorder(var Fb: TBytes; X, Y: Integer);
var
  Left, Mid, Right: TBytes;
  XX, I: Integer;
begin
  Left := PatchOf('M_LSLEFT');
  Mid := PatchOf('M_LSCNTR');
  Right := PatchOf('M_LSRGHT');
  if Length(Left) > 0 then
    DrawPatch(Fb, X - 8, Y + 7, Left);
  XX := X;
  for I := 1 to SAVESTRINGSIZE do
  begin
    if Length(Mid) > 0 then
      DrawPatch(Fb, XX, Y + 7, Mid);
    Inc(XX, 8);
  end;
  if Length(Right) > 0 then
    DrawPatch(Fb, XX, Y + 7, Right);
end;

procedure TDoomMenu.DrawSaveSlots(var Fb: TBytes; Menu: TObject);
var
  Def: TMenuDef;
  I, Y, XX: Integer;
begin
  Def := TMenuDef(Menu);
  for I := 0 to 5 do
  begin
    Y := Def.Y + LINEHEIGHT * I;
    DrawSaveLoadBorder(Fb, Def.X, Y);
    XX := WriteText(Fb, Def.X, Y, FSaveStrings[I]);
    if FSaveStringEnter and (I = FSaveSlot) then
      WriteText(Fb, XX, Y, '_');
  end;
end;

procedure TDoomMenu.DrawThermo(var Fb: TBytes; X, Y, Width, Dot: Integer);
var
  Left, Mid, Right, Knob: TBytes;
  XX, I, KnobAt: Integer;
begin
  Left := PatchOf('M_THERML');
  Mid := PatchOf('M_THERMM');
  Right := PatchOf('M_THERMR');
  Knob := PatchOf('M_THERMO');
  XX := X;
  if Length(Left) > 0 then
    DrawPatch(Fb, XX, Y, Left);
  Inc(XX, 8);
  for I := 1 to Width do
  begin
    if Length(Mid) > 0 then
      DrawPatch(Fb, XX, Y, Mid);
    Inc(XX, 8);
  end;
  if Length(Right) > 0 then
    DrawPatch(Fb, XX, Y, Right);
  if Length(Knob) > 0 then
  begin
    KnobAt := Dot;
    if KnobAt < 0 then
      KnobAt := 0;
    if KnobAt > Width - 1 then
      KnobAt := Width - 1;
    DrawPatch(Fb, X + 8 + KnobAt * 8, Y, Knob);
  end;
end;

procedure TDoomMenu.DrawMessage(var Fb: TBytes);
var
  Text, Lump: string;
  X, Y, W, I: Integer;
  Ch: Char;
  P: TBytes;
begin
  Text := FMessage;
  if FMessageConfirm then
    Text := Text + '  (Y/N)';
  X := 10;
  Y := 80;
  for I := 1 to Length(Text) do
  begin
    Ch := Text[I];
    if Ch = ' ' then
    begin
      Inc(X, 8);
      Continue;
    end;
    Lump := Format('STCFN%.3d', [Ord(Ch)]);
    P := PatchOf(Lump);
    if Length(P) > 0 then
    begin
      DrawPatch(Fb, X, Y, P);
      W := PatchWidth(P);
      if W < 4 then
        W := 4;
      Inc(X, W);
    end
    else
      Inc(X, 8);
    if X > 300 then
    begin
      X := 10;
      Inc(Y, 10);
    end;
  end;
end;

procedure TDoomMenu.Draw(var Fb: TBytes);
var
  Menu: TMenuDef;
  P: TBytes;
  Y, I: Integer;
  Lump, Skull: string;
begin
  if not Active then
    Exit;
  if FMessageOn then
  begin
    DrawMessage(Fb);
    Exit;
  end;
  Menu := TMenuDef(FMenus[FScreen]);
  if Menu.Routine = 'main' then
  begin
    P := PatchOf('M_DOOM');
    if Length(P) > 0 then
      DrawPatch(Fb, 94, 2, P);
  end
  else if Menu.Routine = 'skill' then
  begin
    P := PatchOf('M_NEWG');
    if Length(P) > 0 then
      DrawPatch(Fb, 96, 14, P);
    P := PatchOf('M_SKILL');
    if Length(P) > 0 then
      DrawPatch(Fb, 54, 38, P);
  end
  else if Menu.Routine = 'episode' then
  begin
    P := PatchOf('M_EPISOD');
    if Length(P) > 0 then
      DrawPatch(Fb, 54, 38, P);
  end
  else if Menu.Routine = 'options' then
  begin
    P := PatchOf('M_OPTTTL');
    if Length(P) > 0 then
      DrawPatch(Fb, 108, 15, P);
    if FHost.ShowMessages then
      Lump := 'M_MSGON'
    else
      Lump := 'M_MSGOFF';
    P := PatchOf(Lump);
    if Length(P) > 0 then
      DrawPatch(Fb, Menu.X + 120, Menu.Y + LINEHEIGHT, P);
    if FHost.DetailLevel = 0 then
      Lump := 'M_GDHIGH'
    else
      Lump := 'M_GDLOW';
    P := PatchOf(Lump);
    if Length(P) > 0 then
      DrawPatch(Fb, Menu.X + 175, Menu.Y + LINEHEIGHT * 2, P);
  end
  else if Menu.Routine = 'sound' then
  begin
    P := PatchOf('M_SVOL');
    if Length(P) > 0 then
      DrawPatch(Fb, 60, 38, P);
  end
  else if Menu.Routine = 'read1' then
  begin
    if HasLump('HELP2') then
      Lump := 'HELP2'
    else if HasLump('HELP1') then
      Lump := 'HELP1'
    else if HasLump('HELP') then
      Lump := 'HELP'
    else
      Lump := 'CREDIT';
    P := PatchOf(Lump);
    if Length(P) > 0 then
      DrawPatch(Fb, 0, 0, P);
  end
  else if Menu.Routine = 'read2' then
  begin
    P := PatchOf('HELP1');
    if Length(P) = 0 then
      P := PatchOf('CREDIT');
    if Length(P) > 0 then
      DrawPatch(Fb, 0, 0, P);
  end
  else if Menu.Routine = 'load' then
  begin
    P := PatchOf('M_LOADG');
    if Length(P) > 0 then
      DrawPatch(Fb, 72, 28, P);
    DrawSaveSlots(Fb, Menu);
  end
  else if Menu.Routine = 'save' then
  begin
    P := PatchOf('M_SAVEG');
    if Length(P) > 0 then
      DrawPatch(Fb, 72, 28, P);
    DrawSaveSlots(Fb, Menu);
  end;

  if (Menu.Routine <> 'read1') and (Menu.Routine <> 'read2') and
    (Menu.Routine <> 'load') and (Menu.Routine <> 'save') then
  begin
    Y := Menu.Y;
    for I := 0 to High(Menu.Items) do
    begin
      if Menu.Items[I].Name <> '' then
      begin
        P := PatchOf(Menu.Items[I].Name);
        if Length(P) > 0 then
          DrawPatch(Fb, Menu.X, Y, P);
      end;
      Inc(Y, LINEHEIGHT);
    end;
  end;

  if Menu.Routine = 'options' then
  begin
    DrawThermo(Fb, Menu.X, Menu.Y + LINEHEIGHT * 4, 9, FHost.ScreenSize);
    DrawThermo(Fb, Menu.X, Menu.Y + LINEHEIGHT * 6, 10, FHost.MouseSensitivity);
  end
  else if Menu.Routine = 'sound' then
  begin
    DrawThermo(Fb, Menu.X, Menu.Y + LINEHEIGHT, 16, FHost.Sound.SfxVolume);
    DrawThermo(Fb, Menu.X, Menu.Y + LINEHEIGHT * 3, 16, FHost.Sound.MusicVolume);
  end;

  if FWhichSkull <> 0 then
    Skull := 'M_SKULL2'
  else
    Skull := 'M_SKULL1';
  P := PatchOf(Skull);
  if (Length(P) > 0) and (Menu.Routine <> 'read1') and (Menu.Routine <> 'read2') then
    DrawPatch(Fb, Menu.X + SKULLXOFF, Menu.Y - 5 + FItemOn * LINEHEIGHT, P);
end;

end.
