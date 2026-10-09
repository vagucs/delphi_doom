unit Doom.Wad;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Leitor de WAD, igual a doom/wad.py. O numero do lump continua 0-based.
}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TLump = class
    Name: string;
    Position: Int64;
    Size: Integer;
    WadPath: string;
    Cache: TBytes;
    Cached: Boolean;
  end;

  TWad = class
  private
    FLumps: TObjectList<TLump>;
    FIndex: TDictionary<string, Integer>;
    function KeyOf(const Name: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFile(const Path: string);
    function NumLumps: Integer;
    function CheckNumForName(const Name: string): Integer;
    function GetNumForName(const Name: string): Integer;
    function CacheLumpNum(Num: Integer): TBytes;
    function CacheLumpName(const Name: string): TBytes;
    function LumpName(Num: Integer): string;
  end;

function FindIwad: string;

implementation

function Name8(const Raw: TBytes; Off, Count: Integer): string;
var
  N, I: Integer;
begin
  N := Count;
  if N > 8 then
    N := 8;
  I := 0;
  while (I < N) and (Raw[Off + I] <> 0) do
    Inc(I);
  Result := UpperCase(Trim(TEncoding.ANSI.GetString(Raw, Off, I)));
end;

function FindIwad: string;
const
  Names: array[0..5] of string = (
    'DOOM1.WAD', 'doom1.wad', 'DOOM.WAD', 'doom.wad', 'DOOM2.WAD', 'doom2.wad');
var
  Dirs: TArray<string>;
  Dir, Name, Candidate: string;
begin
  Dirs := TArray<string>.Create(
    GetCurrentDir,
    ExtractFilePath(ParamStr(0)),
    ExpandFileName(IncludeTrailingPathDelimiter(GetCurrentDir) + '..'),
    ExpandFileName(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + '..'),
    ExpandFileName(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + '..\..'),
    ExpandFileName(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + '..\..\..'));
  for Dir in Dirs do
    for Name in Names do
    begin
      Candidate := IncludeTrailingPathDelimiter(Dir) + Name;
      if FileExists(Candidate) then
        Exit(Candidate);
    end;
  Result := '';
end;

constructor TWad.Create;
begin
  inherited Create;
  FLumps := TObjectList<TLump>.Create(True);
  FIndex := TDictionary<string, Integer>.Create;
end;

destructor TWad.Destroy;
begin
  FIndex.Free;
  FLumps.Free;
  inherited;
end;

function TWad.KeyOf(const Name: string): string;
var
  S: string;
  ZeroAt: Integer;
begin
  S := Name;
  ZeroAt := Pos(#0, S);
  if ZeroAt > 0 then
    S := Copy(S, 1, ZeroAt - 1);
  S := Trim(S);
  if Length(S) > 8 then
    S := Copy(S, 1, 8);
  Result := UpperCase(S);
end;

procedure TWad.AddFile(const Path: string);
var
  Full, Ident: string;
  Fs: TFileStream;
  Header, Directory: TBytes;
  NumLumps, I, Off, Start: Integer;
  InfoOfs: Cardinal;
  Lump: TLump;
begin
  Full := ExpandFileName(Path);
  Fs := TFileStream.Create(Full, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Header, 12);
    if Fs.Read(Header[0], 12) <> 12 then
      raise Exception.Create('WAD curto: ' + Full);
    Ident := TEncoding.ANSI.GetString(Header, 0, 4);
    if (Ident <> 'IWAD') and (Ident <> 'PWAD') then
      raise Exception.Create('nao e WAD: ' + Full);
    NumLumps := Integer(Cardinal(Header[4]) or (Cardinal(Header[5]) shl 8) or
      (Cardinal(Header[6]) shl 16) or (Cardinal(Header[7]) shl 24));
    InfoOfs := Cardinal(Header[8]) or (Cardinal(Header[9]) shl 8) or
      (Cardinal(Header[10]) shl 16) or (Cardinal(Header[11]) shl 24);
    Fs.Position := InfoOfs;
    SetLength(Directory, NumLumps * 16);
    if NumLumps > 0 then
      Fs.ReadBuffer(Directory[0], Length(Directory));
  finally
    Fs.Free;
  end;
  Start := FLumps.Count;
  for I := 0 to NumLumps - 1 do
  begin
    Off := I * 16;
    Lump := TLump.Create;
    Lump.Position := Cardinal(Directory[Off]) or (Cardinal(Directory[Off + 1]) shl 8) or
      (Cardinal(Directory[Off + 2]) shl 16) or (Cardinal(Directory[Off + 3]) shl 24);
    Lump.Size := Integer(Cardinal(Directory[Off + 4]) or (Cardinal(Directory[Off + 5]) shl 8) or
      (Cardinal(Directory[Off + 6]) shl 16) or (Cardinal(Directory[Off + 7]) shl 24));
    Lump.Name := Name8(Directory, Off + 8, 8);
    Lump.WadPath := Full;
    FLumps.Add(Lump);
  end;
  for I := Start to FLumps.Count - 1 do
    FIndex.AddOrSetValue(FLumps[I].Name, I);
end;

function TWad.NumLumps: Integer;
begin
  Result := FLumps.Count;
end;

function TWad.CheckNumForName(const Name: string): Integer;
begin
  if not FIndex.TryGetValue(KeyOf(Name), Result) then
    Result := -1;
end;

function TWad.GetNumForName(const Name: string): Integer;
begin
  Result := CheckNumForName(Name);
  if Result < 0 then
    raise Exception.Create('lump nao encontrado: ' + Name);
end;

function TWad.CacheLumpNum(Num: Integer): TBytes;
var
  Lump: TLump;
  Fs: TFileStream;
begin
  Lump := FLumps[Num];
  if not Lump.Cached then
  begin
    SetLength(Lump.Cache, Lump.Size);
    if Lump.Size > 0 then
    begin
      Fs := TFileStream.Create(Lump.WadPath, fmOpenRead or fmShareDenyNone);
      try
        Fs.Position := Lump.Position;
        Fs.ReadBuffer(Lump.Cache[0], Lump.Size);
      finally
        Fs.Free;
      end;
    end;
    Lump.Cached := True;
  end;
  Result := Lump.Cache;
end;

function TWad.CacheLumpName(const Name: string): TBytes;
begin
  Result := CacheLumpNum(GetNumForName(Name));
end;

function TWad.LumpName(Num: Integer): string;
begin
  Result := FLumps[Num].Name;
end;

end.
