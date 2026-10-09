unit Doom.Sound;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Efeitos DS* em PCM e musica MUS convertida para MIDI.
  A musica toca no Windows pela MCI. Android e iOS ficam sem musica.
}

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections, Doom.Wad
  {$IFDEF MSWINDOWS}, Winapi.MMSystem{$ENDIF};

const
  MIXRATE = 11025;
  VOICES = 8;
  MIXSLOTS = 3;
  CHUNK = 315;

{$IFDEF MSWINDOWS}
type
  TWaveSlot = record
    Hdr: TWaveHdr;
    Data: TBytes;
    Ready: Boolean;
  end;

  TVoice = record
    Data: TBytes;
    Name: string;
    Pos: Integer;
    Gain: Integer;
    Active: Boolean;
  end;
{$ENDIF}

type
  TGameSound = class
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open(AWad: TWad);
    procedure Play(const Name: string);
    procedure PlayAt(const Name: string; SX, SY, LX, LY: Integer);
    procedure PlayTitle;
    procedure PlayLevel(Episode, MapN: Integer);
    procedure StopSfx;
    procedure PlayMusic(const Name: string; Looping: Boolean);
    procedure SetSfxVolume(Vol: Integer);
    procedure SetMusicVolume(Vol: Integer);
    procedure Update;
    procedure StopMusic;
  private
    FWad: TWad;
    FSfxVol: Integer;
    FMusicVol: Integer;
    FMusicName: string;
    FMusicLoop: Boolean;
    FCache: TDictionary<string, TBytes>;
    {$IFDEF MSWINDOWS}
    FWave: HWAVEOUT;
    FWaveOn: Boolean;
    FMix: array[0..MIXSLOTS - 1] of TWaveSlot;
    FVoices: array[0..VOICES - 1] of TVoice;
    FMusicOn: Boolean;
    FMusicPath: string;
    procedure OpenWave;
    procedure CloseWave;
    procedure MixVoices;
    function Mci(const Cmd: string): Cardinal;
    function MciText(const Cmd: string): string;
    {$ENDIF}
    procedure ChangeMusic(const Name: string; Looping: Boolean);
    function LoadSfx(const Name: string): TBytes;
    procedure Start(const Name: string; Gain: Integer);
  end;

procedure PlaySfx(const Name: string);
procedure PlaySfxAt(const Name: string; SX, SY, LX, LY: Integer);
procedure StartMusic(const Name: string; Looping: Boolean);
procedure SetAudioGates(AllowSfx, AllowMusic: Boolean);

implementation

{$IFDEF MSWINDOWS}
uses
  System.Classes, Winapi.Windows;
{$ENDIF}

const
  DOOM2MUSIC: array[0..31] of string = (
    'runnin', 'stalks', 'countd', 'betwee', 'doom', 'the_da', 'shawn', 'ddtblu',
    'in_cit', 'dead', 'stlks2', 'theda2', 'doom2', 'ddtbl2', 'runni2', 'dead2',
    'stlks3', 'romero', 'shawn2', 'messag', 'count2', 'ddtbl3', 'ampie', 'theda3',
    'adrian', 'messg2', 'romer2', 'tense', 'shawn3', 'openin', 'evil', 'ultima');

var
  GSound: TGameSound;

procedure PlaySfx(const Name: string);
begin
  if GSound <> nil then
    GSound.Play(Name);
end;

procedure PlaySfxAt(const Name: string; SX, SY, LX, LY: Integer);
begin
  if GSound <> nil then
    GSound.PlayAt(Name, SX, SY, LX, LY);
end;

procedure StartMusic(const Name: string; Looping: Boolean);
begin
  if GSound <> nil then
    GSound.PlayMusic(Name, Looping);
end;

var
  GAllowSfx: Boolean = True;
  GAllowMusic: Boolean = True;

procedure SetAudioGates(AllowSfx, AllowMusic: Boolean);
begin
  GAllowSfx := AllowSfx;
  GAllowMusic := AllowMusic;
  if (not AllowMusic) and (GSound <> nil) then
    GSound.StopMusic;
end;

function ClampVol(Vol: Integer): Integer;
begin
  Result := Vol;
  if Result < 0 then
    Result := 0;
  if Result > 15 then
    Result := 15;
end;

function MusToMidi(const Mus: TBytes): TBytes;
const
  Header: array[0..21] of Byte = (
    $4D, $54, $68, $64, $00, $00, $00, $06, $00, $00, $00, $01, $00, $46,
    $4D, $54, $72, $6B, $00, $00, $00, $00);
  Map: array[0..14] of Byte = (
    $00, $20, $01, $07, $0A, $0B, $5B, $5D, $40, $43, $78, $7B, $7E, $7F, $79);
var
  Pos, Score, Channel, Event, Key, Vel, Ctrl, Val, Delay, Wheel, I, Track: Integer;
  Queued: Integer;
  Body: TBytes;
  ChanMap: array[0..15] of Integer;
  Speed: array[0..15] of Integer;
  Desc: Byte;

  function ReadByte: Integer;
  begin
    if Pos >= Length(Mus) then
      Exit(-1);
    Result := Mus[Pos];
    Inc(Pos);
  end;

  procedure Add(B: Byte);
  begin
    SetLength(Body, Length(Body) + 1);
    Body[High(Body)] := B;
    Inc(Track);
  end;

  procedure WriteTime(Time: Integer);
  var
    Buf: Int64;
    T: Integer;
    B: Byte;
  begin
    Buf := Time and $7F;
    T := Time shr 7;
    while T <> 0 do
    begin
      Buf := Buf shl 8;
      Buf := Buf or ((T and $7F) or $80);
      T := T shr 7;
    end;
    repeat
      B := Byte(Buf and $FF);
      Add(B);
      if (Buf and $80) <> 0 then
        Buf := Buf shr 8
      else
        Break;
    until False;
    Queued := 0;
  end;

  procedure Put(const Bytes: array of Byte);
  var
    N: Integer;
  begin
    WriteTime(Queued);
    for N := 0 to High(Bytes) do
      Add(Bytes[N]);
  end;

  function AllocChan: Integer;
  var
    N, Hi: Integer;
  begin
    Hi := -1;
    for N := 0 to 15 do
      if ChanMap[N] > Hi then
        Hi := ChanMap[N];
    Result := Hi + 1;
    if Result = 9 then
      Inc(Result);
  end;

  function MidiChan(MusChan: Integer): Integer;
  begin
    if MusChan = 15 then
      Exit(9);
    if ChanMap[MusChan] < 0 then
    begin
      ChanMap[MusChan] := AllocChan;
      Put([$B0 or ChanMap[MusChan], $7B, 0]);
    end;
    Result := ChanMap[MusChan];
  end;

begin
  SetLength(Result, 0);
  if Length(Mus) >= 4 then
  begin
    if (Mus[0] = Ord('M')) and (Mus[1] = Ord('T')) and (Mus[2] = Ord('h')) and (Mus[3] = Ord('d')) then
      Exit(Mus);
  end;
  if (Length(Mus) < 16) or (Mus[0] <> Ord('M')) or (Mus[1] <> Ord('U')) or (Mus[2] <> Ord('S')) or
    (Mus[3] <> $1A) then
    Exit;
  Score := Mus[6] or (Mus[7] shl 8);
  Pos := Score;
  Track := 0;
  Queued := 0;
  SetLength(Body, 0);
  for I := 0 to 15 do
  begin
    ChanMap[I] := -1;
    Speed[I] := 127;
  end;
  while True do
  begin
    while True do
    begin
      Event := ReadByte;
      if Event < 0 then
        Exit;
      Desc := Byte(Event);
      Channel := MidiChan(Desc and $0F);
      Event := Desc and $70;
      if Event = $00 then
      begin
        Key := ReadByte;
        if Key < 0 then
          Exit;
        Put([$80 or Channel, Key and $7F, 0]);
      end
      else if Event = $10 then
      begin
        Key := ReadByte;
        if Key < 0 then
          Exit;
        if (Key and $80) <> 0 then
        begin
          Vel := ReadByte;
          if Vel < 0 then
            Exit;
          Speed[Channel] := Vel and $7F;
        end;
        Put([$90 or Channel, Key and $7F, Speed[Channel]]);
      end
      else if Event = $20 then
      begin
        Key := ReadByte;
        if Key < 0 then
          Exit;
        Wheel := Key * 64;
        Put([$E0 or Channel, Wheel and $7F, (Wheel shr 7) and $7F]);
      end
      else if Event = $30 then
      begin
        Ctrl := ReadByte;
        if (Ctrl < 10) or (Ctrl > 14) then
          Exit;
        Put([$B0 or Channel, Map[Ctrl], 0]);
      end
      else if Event = $40 then
      begin
        Ctrl := ReadByte;
        Val := ReadByte;
        if (Ctrl < 0) or (Val < 0) then
          Exit;
        if Ctrl = 0 then
          Put([$C0 or Channel, Val and $7F])
        else
        begin
          if (Ctrl < 1) or (Ctrl > 9) then
            Exit;
          if (Val and $80) <> 0 then
            Wheel := $7F
          else
            Wheel := Val;
          Put([$B0 or Channel, Map[Ctrl], Wheel]);
        end;
      end
      else if Event = $60 then
      begin
        WriteTime(Queued);
        Add($FF);
        Add($2F);
        Add(0);
        SetLength(Result, 22 + Length(Body));
        for I := 0 to 21 do
          Result[I] := Header[I];
        Result[18] := Byte((Track shr 24) and $FF);
        Result[19] := Byte((Track shr 16) and $FF);
        Result[20] := Byte((Track shr 8) and $FF);
        Result[21] := Byte(Track and $FF);
        if Length(Body) > 0 then
          Move(Body[0], Result[22], Length(Body));
        Exit;
      end
      else
        Exit;
      if (Desc and $80) <> 0 then
        Break;
    end;
    Delay := 0;
    while True do
    begin
      Val := ReadByte;
      if Val < 0 then
        Exit;
      Delay := Delay * 128 + (Val and $7F);
      if (Val and $80) = 0 then
        Break;
    end;
    Inc(Queued, Delay);
  end;
end;

function DecodeDs(const Data: TBytes; Vol: Integer): TBytes;
var
  Rate, Count, OutN, I, SrcI, Sample: Integer;
begin
  SetLength(Result, 0);
  if (Length(Data) < 8) or (Data[0] <> 3) or (Data[1] <> 0) or (Vol <= 0) then
    Exit;
  Rate := Data[2] or (Data[3] shl 8);
  Count := Integer(Cardinal(Data[4]) or (Cardinal(Data[5]) shl 8) or (Cardinal(Data[6]) shl 16) or
    (Cardinal(Data[7]) shl 24));
  if (Rate <= 0) or (Count <= 48) or (Count > Length(Data) - 8) then
    Exit;
  Dec(Count, 32);
  if (Count <= 0) or (16 + Count > Length(Data)) then
    Exit;
  OutN := Count;
  if Rate <> MIXRATE then
    OutN := Max(1, (Int64(Count) * MIXRATE) div Rate);
  SetLength(Result, OutN * 2);
  for I := 0 to OutN - 1 do
  begin
    SrcI := 16;
    if OutN > 1 then
      SrcI := 16 + (Int64(I) * Count) div OutN;
    if SrcI >= 16 + Count then
      SrcI := 16 + Count - 1;
    Sample := (Integer(Data[SrcI]) - 128) shl 8;
    Sample := Sample * Vol div 15;
    if Sample > 32767 then
      Sample := 32767;
    if Sample < -32768 then
      Sample := -32768;
    Result[I * 2] := Byte(Word(SmallInt(Sample)) and $FF);
    Result[I * 2 + 1] := Byte(Word(SmallInt(Sample)) shr 8);
  end;
end;

constructor TGameSound.Create;
begin
  inherited Create;
  FSfxVol := 8;
  FMusicVol := 8;
  FCache := TDictionary<string, TBytes>.Create;
  GSound := Self;
  {$IFDEF MSWINDOWS}
  OpenWave;
  {$ENDIF}
end;

destructor TGameSound.Destroy;
begin
  StopMusic;
  {$IFDEF MSWINDOWS}
  CloseWave;
  if FMusicPath <> '' then
    System.SysUtils.DeleteFile(FMusicPath);
  {$ENDIF}
  if GSound = Self then
    GSound := nil;
  FCache.Free;
  inherited;
end;

procedure TGameSound.Open(AWad: TWad);
begin
  FWad := AWad;
  FCache.Clear;
end;

procedure TGameSound.SetSfxVolume(Vol: Integer);
begin
  FSfxVol := ClampVol(Vol);
  FCache.Clear;
end;

procedure TGameSound.SetMusicVolume(Vol: Integer);
begin
  FMusicVol := ClampVol(Vol);
  {$IFDEF MSWINDOWS}
  if FMusicOn then
    Mci('setaudio doommus volume to ' + IntToStr(FMusicVol * 1000 div 15));
  {$ENDIF}
end;

function TGameSound.LoadSfx(const Name: string): TBytes;
var
  Key, Lump: string;
  N: Integer;
  Raw: TBytes;
begin
  SetLength(Result, 0);
  Key := LowerCase(Trim(Name));
  if Key = '' then
    Exit;
  if FCache.TryGetValue(Key, Result) then
    Exit;
  if FWad = nil then
    Exit;
  Lump := 'DS' + UpperCase(Copy(Key, 1, 6));
  N := FWad.CheckNumForName(Lump);
  if N < 0 then
  begin
    FCache.Add(Key, Result);
    Exit;
  end;
  Raw := FWad.CacheLumpNum(N);
  Result := DecodeDs(Raw, FSfxVol);
  FCache.AddOrSetValue(Key, Result);
end;

function ScaledPcm(const Pcm: TBytes; Gain: Integer): TBytes;
var
  I, S: Integer;
  W: Word;
begin
  Result := Copy(Pcm);
  if (Gain >= 15) or (Length(Result) < 2) then
    Exit;
  I := 0;
  while I + 1 < Length(Result) do
  begin
    S := Result[I] or (Result[I + 1] shl 8);
    if S >= 32768 then
      Dec(S, 65536);
    S := S * Gain div 15;
    W := Word(SmallInt(S));
    Result[I] := Byte(W and $FF);
    Result[I + 1] := Byte(W shr 8);
    Inc(I, 2);
  end;
end;

procedure TGameSound.Start(const Name: string; Gain: Integer);
{$IFDEF MSWINDOWS}
var
  Pcm: TBytes;
  Key: string;
  Slot, FreeSlot, I: Integer;
{$ENDIF}
begin
  if not GAllowSfx then
    Exit;
  {$IFDEF MSWINDOWS}
  if (not FWaveOn) or (FSfxVol <= 0) or (Gain <= 0) or (Name = '') then
    Exit;
  Key := LowerCase(Trim(Name));
  Pcm := LoadSfx(Key);
  if Length(Pcm) < 2 then
    Exit;
  Slot := -1;
  FreeSlot := -1;
  for I := 0 to VOICES - 1 do
  begin
    if FVoices[I].Active and SameText(FVoices[I].Name, Key) then
    begin
      if Gain < FVoices[I].Gain then
        Exit;
      Slot := I;
      Break;
    end;
    if (FreeSlot < 0) and not FVoices[I].Active then
      FreeSlot := I;
  end;
  if Slot < 0 then
    Slot := FreeSlot;
  if Slot < 0 then
    Exit;
  FVoices[Slot].Data := ScaledPcm(Pcm, Gain);
  FVoices[Slot].Name := Key;
  FVoices[Slot].Gain := Gain;
  FVoices[Slot].Pos := 0;
  FVoices[Slot].Active := True;
  {$ELSE}
  if (Name = '') or (Gain < 0) then
    Exit;
  {$ENDIF}
end;

procedure TGameSound.Play(const Name: string);
begin
  Start(Name, 15);
end;

procedure TGameSound.PlayAt(const Name: string; SX, SY, LX, LY: Integer);
var
  Dx, Dy, Dist, Gain: Integer;
begin
  Dx := Abs(Integer((Int64(SX) - LX) div 65536));
  Dy := Abs(Integer((Int64(SY) - LY) div 65536));
  if Dx < Dy then
    Dist := Dx + Dy - (Dx div 2)
  else
    Dist := Dx + Dy - (Dy div 2);
  if Dist <= 200 then
    Gain := 15
  else if Dist >= 1200 then
    Exit
  else
  begin
    Gain := ((1200 - Dist) * 15) div 1000;
    if Gain < 1 then
      Gain := 1;
  end;
  Start(Name, Gain);
end;

procedure TGameSound.PlayTitle;
begin
  if FWad = nil then
    Exit;
  if FWad.CheckNumForName('MAP01') >= 0 then
    ChangeMusic('dm2ttl', False)
  else if FWad.CheckNumForName('D_INTROA') >= 0 then
    ChangeMusic('introa', False)
  else
    ChangeMusic('intro', False);
end;

procedure TGameSound.StopSfx;
{$IFDEF MSWINDOWS}
var
  I: Integer;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  for I := 0 to VOICES - 1 do
    FVoices[I].Active := False;
  if FWaveOn then
  begin
    waveOutReset(FWave);
    for I := 0 to MIXSLOTS - 1 do
      if FMix[I].Ready then
      begin
        waveOutUnprepareHeader(FWave, @FMix[I].Hdr, SizeOf(TWaveHdr));
        FMix[I].Ready := False;
      end;
  end;
  {$ENDIF}
end;

procedure TGameSound.PlayLevel(Episode, MapN: Integer);
var
  Name: string;
begin
  if FWad = nil then
    Exit;
  if MapN < 1 then
    MapN := 1;
  if FWad.CheckNumForName('MAP01') >= 0 then
    Name := DOOM2MUSIC[(MapN - 1) mod Length(DOOM2MUSIC)]
  else
    Name := Format('e%dm%d', [Episode, MapN]);
  ChangeMusic(Name, True);
end;

procedure TGameSound.PlayMusic(const Name: string; Looping: Boolean);
begin
  ChangeMusic(Name, Looping);
end;

procedure TGameSound.ChangeMusic(const Name: string; Looping: Boolean);
{$IFDEF MSWINDOWS}
var
  Lump, Path: string;
  N: Integer;
  Midi: TBytes;
  Fs: TFileStream;
  Buf: array[0..MAX_PATH] of Char;
{$ENDIF}
begin
  if not GAllowMusic then
    Exit;
  {$IFDEF MSWINDOWS}
  if (FWad = nil) or (Name = '') then
    Exit;
  if SameText(Name, FMusicName) then
    Exit;
  Lump := 'D_' + UpperCase(Copy(Name, 1, 6));
  N := FWad.CheckNumForName(Lump);
  if N < 0 then
    Exit;
  Midi := MusToMidi(FWad.CacheLumpNum(N));
  if Length(Midi) < 22 then
    Exit;
  if GetTempPath(MAX_PATH, Buf) = 0 then
    Exit;
  StopMusic;
  Path := IncludeTrailingPathDelimiter(Buf) + 'doommus.mid';
  try
    Fs := TFileStream.Create(Path, fmCreate);
    try
      if Length(Midi) > 0 then
        Fs.WriteBuffer(Midi[0], Length(Midi));
    finally
      Fs.Free;
    end;
  except
    Exit;
  end;
  FMusicPath := Path;
  FMusicName := LowerCase(Name);
  FMusicLoop := Looping;
  Mci('close doommus');
  if Mci('open "' + Path + '" type sequencer alias doommus') <> 0 then
    if Mci('open "' + Path + '" alias doommus') <> 0 then
    begin
      FMusicName := '';
      Exit;
    end;
  if Mci('play doommus from 0') <> 0 then
  begin
    Mci('close doommus');
    FMusicName := '';
    Exit;
  end;
  FMusicOn := True;
  Mci('setaudio doommus volume to ' + IntToStr(FMusicVol * 1000 div 15));
  {$ELSE}
  FMusicName := '';
  FMusicLoop := Looping;
  if Name = '' then
    Exit;
  {$ENDIF}
end;

procedure TGameSound.StopMusic;
begin
  {$IFDEF MSWINDOWS}
  if FMusicOn then
    Mci('close doommus');
  FMusicOn := False;
  {$ENDIF}
  FMusicName := '';
  FMusicLoop := False;
end;

procedure TGameSound.Update;
{$IFDEF MSWINDOWS}
var
  Mode: string;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  MixVoices;
  if (not FMusicOn) or (not FMusicLoop) then
    Exit;
  Mode := Trim(MciText('status doommus mode'));
  if (Mode <> '') and not SameText(Mode, 'playing') then
    Mci('play doommus from 0');
  {$ENDIF}
end;

{$IFDEF MSWINDOWS}
procedure TGameSound.OpenWave;
var
  Fmt: TWaveFormatEx;
begin
  FillChar(Fmt, SizeOf(Fmt), 0);
  Fmt.wFormatTag := WAVE_FORMAT_PCM;
  Fmt.nChannels := 1;
  Fmt.nSamplesPerSec := MIXRATE;
  Fmt.wBitsPerSample := 16;
  Fmt.nBlockAlign := 2;
  Fmt.nAvgBytesPerSec := MIXRATE * 2;
  FWaveOn := waveOutOpen(@FWave, WAVE_MAPPER, @Fmt, 0, 0, CALLBACK_NULL) = MMSYSERR_NOERROR;
end;

procedure TGameSound.MixVoices;
var
  Mix: array[0..CHUNK - 1] of Integer;
  Slot, I, V, S, B: Integer;
  W: Word;
  Busy: Boolean;
begin
  if not FWaveOn then
    Exit;
  Slot := -1;
  for I := 0 to MIXSLOTS - 1 do
  begin
    Busy := FMix[I].Ready and ((FMix[I].Hdr.dwFlags and WHDR_DONE) = 0);
    if not Busy then
    begin
      Slot := I;
      Break;
    end;
  end;
  if Slot < 0 then
    Exit;
  Busy := False;
  for V := 0 to VOICES - 1 do
    if FVoices[V].Active then
      Busy := True;
  if not Busy then
    Exit;
  for I := 0 to CHUNK - 1 do
    Mix[I] := 0;
  for V := 0 to VOICES - 1 do
  begin
    if not FVoices[V].Active then
      Continue;
    for I := 0 to CHUNK - 1 do
    begin
      B := FVoices[V].Pos;
      if B + 1 >= Length(FVoices[V].Data) then
      begin
        FVoices[V].Active := False;
        Break;
      end;
      S := FVoices[V].Data[B] or (FVoices[V].Data[B + 1] shl 8);
      if S >= 32768 then
        Dec(S, 65536);
      Inc(Mix[I], S);
      Inc(FVoices[V].Pos, 2);
    end;
  end;
  if FMix[Slot].Ready then
  begin
    waveOutUnprepareHeader(FWave, @FMix[Slot].Hdr, SizeOf(TWaveHdr));
    FMix[Slot].Ready := False;
  end;
  SetLength(FMix[Slot].Data, CHUNK * 2);
  for I := 0 to CHUNK - 1 do
  begin
    S := Mix[I];
    if S > 32767 then
      S := 32767;
    if S < -32768 then
      S := -32768;
    W := Word(SmallInt(S));
    FMix[Slot].Data[I * 2] := Byte(W and $FF);
    FMix[Slot].Data[I * 2 + 1] := Byte(W shr 8);
  end;
  FillChar(FMix[Slot].Hdr, SizeOf(TWaveHdr), 0);
  FMix[Slot].Hdr.lpData := @FMix[Slot].Data[0];
  FMix[Slot].Hdr.dwBufferLength := CHUNK * 2;
  FMix[Slot].Hdr.dwLoops := 0;
  if waveOutPrepareHeader(FWave, @FMix[Slot].Hdr, SizeOf(TWaveHdr)) <> MMSYSERR_NOERROR then
    Exit;
  FMix[Slot].Ready := True;
  if waveOutWrite(FWave, @FMix[Slot].Hdr, SizeOf(TWaveHdr)) <> MMSYSERR_NOERROR then
  begin
    waveOutUnprepareHeader(FWave, @FMix[Slot].Hdr, SizeOf(TWaveHdr));
    FMix[Slot].Ready := False;
  end;
end;

procedure TGameSound.CloseWave;
var
  I: Integer;
begin
  if not FWaveOn then
    Exit;
  waveOutReset(FWave);
  for I := 0 to MIXSLOTS - 1 do
    if FMix[I].Ready then
    begin
      waveOutUnprepareHeader(FWave, @FMix[I].Hdr, SizeOf(TWaveHdr));
      FMix[I].Ready := False;
    end;
  for I := 0 to VOICES - 1 do
    FVoices[I].Active := False;
  waveOutClose(FWave);
  FWaveOn := False;
end;

function TGameSound.Mci(const Cmd: string): Cardinal;
begin
  Result := mciSendString(PChar(Cmd), nil, 0, 0);
end;

function TGameSound.MciText(const Cmd: string): string;
var
  Buf: array[0..63] of Char;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  if mciSendString(PChar(Cmd), Buf, 64, 0) <> 0 then
    Exit('');
  Result := Buf;
end;
{$ENDIF}

end.
