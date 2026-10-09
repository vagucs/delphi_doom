unit Doom.World;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Carga do mapa, igual a doom/world.py.
  A vista de cima cabe no quadro de 320x200, com a seta do jogador.
}

interface

uses
  System.SysUtils, System.Generics.Collections, Doom.Wad, Doom.RData;

const
  ML_TWOSIDED = 4;

type
  TVertex = class
  public
    X: Integer;
    Y: Integer;
  end;

  TLine = class;

  TSector = class
  public
    FloorHeight: Integer;
    CeilingHeight: Integer;
    FloorPic: string;
    CeilingPic: string;
    LightLevel: Integer;
    Special: Integer;
    Tag: Integer;
    Index: Integer;
    SpecialData: TObject;
    Lines: TList<TLine>;
    constructor Create;
    destructor Destroy; override;
  end;

  TSide = class
  public
    TextureOffset: Integer;
    RowOffset: Integer;
    TopTexture: string;
    BottomTexture: string;
    MidTexture: string;
    Sector: TSector;
  end;

  TLine = class
  public
    V1: TVertex;
    V2: TVertex;
    Dx: Integer;
    Dy: Integer;
    Flags: Integer;
    Special: Integer;
    Tag: Integer;
    SideNum: array[0..1] of Integer;
    Side0: TSide;
    Side1: TSide;
    FrontSector: TSector;
    BackSector: TSector;
    BBox: array[0..3] of Integer;
    Index: Integer;
  end;

  TSeg = class
  public
    V1: TVertex;
    V2: TVertex;
    Offset: Integer;
    Angle: Cardinal;
    SideDef: TSide;
    LineDef: TLine;
    FrontSector: TSector;
    BackSector: TSector;
  end;

  TSubsector = class
  public
    Index: Integer;
    NumLines: Integer;
    FirstLine: Integer;
    Sector: TSector;
  end;

  TNode = class
  public
    X: Integer;
    Y: Integer;
    Dx: Integer;
    Dy: Integer;
    BBox: array[0..1, 0..3] of Integer;
    Children: array[0..1] of Integer;
  end;

  TMapThing = class
  public
    X: Integer;
    Y: Integer;
    Angle: Integer;
    ThingType: Integer;
    Options: Integer;
    Radius: Integer;
    BodyHeight: Integer;
    Health: Integer;
    ActorFlags: Integer;
    Dead: Boolean;
    FrameUse: Integer;
    Ai: Integer;
    MoveDir: Integer;
    MoveCount: Integer;
    Speed: Integer;
    Kind: Integer;
    Tics: Integer;
    DidFire: Boolean;
    HasZ: Boolean;
    Z: Integer;
    MomX: Integer;
    MomY: Integer;
    MomZ: Integer;
    SprName: string;
    SprFrame: Integer;
    Floats: Boolean;
    Ambush: Boolean;
    FromPlayer: Boolean;
    MissileDmg: Integer;
  end;

  TMapPoint = record
    X: Integer;
    Y: Integer;
  end;

  TWorld = class
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetupLevel(Wad: TWad; Episode, MapN: Integer);
    procedure DrawOverhead(var Fb: TBytes; Res: TResources);
    function MapName: string;
    function LineCount: Integer;
    function LineAt(Index: Integer): TLine;
    function SectorCount: Integer;
    function SectorAt(Index: Integer): TSector;
    function HasPlayerStart: Boolean;
    function NumNodes: Integer;
    function NodeAt(Index: Integer): TNode;
    function SegAt(Index: Integer): TSeg;
    function SubsectorCount: Integer;
    function SubsectorAt(Index: Integer): TSubsector;
    function ThingCount: Integer;
    function ThingAt(Index: Integer): TMapThing;
    procedure AddThing(Th: TMapThing);
    function PlayerViewX: Integer;
    function PlayerViewY: Integer;
    function PlayerViewAngle: Cardinal;
    function PointInSubsector(X, Y: Integer): TSubsector;
  private
    FVertexes: TObjectList<TVertex>;
    FSectors: TObjectList<TSector>;
    FSides: TObjectList<TSide>;
    FLines: TObjectList<TLine>;
    FSegs: TObjectList<TSeg>;
    FSubsectors: TObjectList<TSubsector>;
    FNodes: TObjectList<TNode>;
    FThings: TObjectList<TMapThing>;
    FBlockMapLump: TArray<Integer>;
    FBlockMap: TArray<Integer>;
    FReject: TBytes;
    FBmapOrgX: Integer;
    FBmapOrgY: Integer;
    FBmapWidth: Integer;
    FBmapHeight: Integer;
    FMapName: string;
    FPlayerFound: Boolean;
    FPlayerX: Integer;
    FPlayerY: Integer;
    FPlayerAngle: Integer;
    FMinX: Integer;
    FMinY: Integer;
    FMaxX: Integer;
    FMaxY: Integer;
    FScaleNum: Integer;
    FScaleDen: Integer;
    FUsedW: Integer;
    FUsedH: Integer;
    FOffX: Integer;
    FOffY: Integer;
    procedure ClearMap;
    procedure LoadVertexes(const Data: TBytes);
    procedure LoadSectors(const Data: TBytes);
    procedure LoadSides(const Data: TBytes);
    procedure LoadLines(const Data: TBytes);
    procedure LoadSegs(const Data: TBytes);
    procedure LoadSubsectors(const Data: TBytes);
    procedure LoadNodes(const Data: TBytes);
    procedure LoadThings(const Data: TBytes);
    procedure LoadBlockmap(const Data: TBytes);
    procedure LoadReject(const Data: TBytes);
    procedure FinishView;
    function ScreenX(MapX: Integer): Integer;
    function ScreenY(MapY: Integer): Integer;
    procedure Plot(var Fb: TBytes; X, Y: Integer; Color: Byte);
    procedure Stroke(var Fb: TBytes; X0, Y0, X1, Y1: Integer; Color: Byte);
    procedure FillConvex(var Fb: TBytes; const Pts: TArray<TMapPoint>; Color: Byte);
    procedure FillSubsector(var Fb: TBytes; Ss: TSubsector; Res: TResources);
    function WallTexture(Ln: TLine): string;
    function LineColor(Ln: TLine; Res: TResources): Integer;
    procedure DrawArrow(var Fb: TBytes);
  end;

implementation

uses
  System.Math, Doom.Compat, Doom.VVideo;

const
  WALL_COLOR = 176;
  TWO_COLOR = 96;
  ARROW_COLOR = 112;

function I16(const Data: TBytes; Off: Integer): Integer;
begin
  Result := Data[Off] or (Data[Off + 1] shl 8);
  if Result >= 32768 then
    Dec(Result, 65536);
end;

function U16(const Data: TBytes; Off: Integer): Integer;
begin
  Result := Data[Off] or (Data[Off + 1] shl 8);
end;

function Name8(const Data: TBytes; Off: Integer): string;
var
  I: Integer;
begin
  I := 0;
  while (I < 8) and (Off + I < Length(Data)) and (Data[Off + I] <> 0) do
    Inc(I);
  Result := UpperCase(Trim(TEncoding.ANSI.GetString(Data, Off, I)));
end;

function MapFixed(V: Integer): Integer;
begin
  Result := AsI32(Int64(V) * FRACUNIT);
end;

constructor TSector.Create;
begin
  inherited Create;
  Lines := TList<TLine>.Create;
end;

destructor TSector.Destroy;
begin
  Lines.Free;
  inherited;
end;

constructor TWorld.Create;
begin
  inherited Create;
  FVertexes := TObjectList<TVertex>.Create(True);
  FSectors := TObjectList<TSector>.Create(True);
  FSides := TObjectList<TSide>.Create(True);
  FLines := TObjectList<TLine>.Create(True);
  FSegs := TObjectList<TSeg>.Create(True);
  FSubsectors := TObjectList<TSubsector>.Create(True);
  FNodes := TObjectList<TNode>.Create(True);
  FThings := TObjectList<TMapThing>.Create(True);
end;

destructor TWorld.Destroy;
begin
  FThings.Free;
  FNodes.Free;
  FSubsectors.Free;
  FSegs.Free;
  FLines.Free;
  FSides.Free;
  FSectors.Free;
  FVertexes.Free;
  inherited;
end;

function TWorld.MapName: string;
begin
  Result := FMapName;
end;

function TWorld.LineCount: Integer;
begin
  Result := FLines.Count;
end;

function TWorld.LineAt(Index: Integer): TLine;
begin
  Result := FLines[Index];
end;

function TWorld.SectorCount: Integer;
begin
  Result := FSectors.Count;
end;

function TWorld.SectorAt(Index: Integer): TSector;
begin
  Result := FSectors[Index];
end;

function TWorld.HasPlayerStart: Boolean;
begin
  Result := FPlayerFound;
end;

function TWorld.NumNodes: Integer;
begin
  Result := FNodes.Count;
end;

function TWorld.NodeAt(Index: Integer): TNode;
begin
  Result := FNodes[Index];
end;

function TWorld.SegAt(Index: Integer): TSeg;
begin
  Result := FSegs[Index];
end;

function TWorld.SubsectorCount: Integer;
begin
  Result := FSubsectors.Count;
end;

function TWorld.SubsectorAt(Index: Integer): TSubsector;
begin
  Result := FSubsectors[Index];
end;

function TWorld.ThingCount: Integer;
begin
  Result := FThings.Count;
end;

function TWorld.ThingAt(Index: Integer): TMapThing;
begin
  Result := FThings[Index];
end;

procedure TWorld.AddThing(Th: TMapThing);
begin
  if Th <> nil then
    FThings.Add(Th);
end;

function TWorld.PlayerViewX: Integer;
begin
  Result := AsI32(Int64(FPlayerX) * FRACUNIT);
end;

function TWorld.PlayerViewY: Integer;
begin
  Result := AsI32(Int64(FPlayerY) * FRACUNIT);
end;

function TWorld.PlayerViewAngle: Cardinal;
begin
  Result := AsU32(Int64(FPlayerAngle) * $40000000 div 90);
end;

function TWorld.PointInSubsector(X, Y: Integer): TSubsector;
var
  NodeNum, Side, Dx, Dy, Hops: Integer;
  Nd: TNode;
  Left, Right: Int64;
begin
  Result := nil;
  if FSubsectors.Count = 0 then
    Exit;
  if FNodes.Count = 0 then
    Exit(FSubsectors[0]);
  NodeNum := FNodes.Count - 1;
  Hops := 0;
  while (NodeNum and $8000) = 0 do
  begin
    Inc(Hops);
    if Hops > 128 then
      Exit(FSubsectors[0]);
    if (NodeNum < 0) or (NodeNum >= FNodes.Count) then
      Exit(FSubsectors[0]);
    Nd := FNodes[NodeNum];
    Dx := AsI32(Int64(X) - Nd.X);
    Dy := AsI32(Int64(Y) - Nd.Y);
    Left := Int64(SHar32(Nd.Dy, 16)) * Dx;
    Right := Int64(Dy) * SHar32(Nd.Dx, 16);
    if Right >= Left then
      Side := 1
    else
      Side := 0;
    NodeNum := Nd.Children[Side];
  end;
  NodeNum := NodeNum and $7FFF;
  if (NodeNum >= 0) and (NodeNum < FSubsectors.Count) then
    Result := FSubsectors[NodeNum]
  else
    Result := FSubsectors[0];
end;

procedure TWorld.ClearMap;
begin
  FVertexes.Clear;
  FSectors.Clear;
  FSides.Clear;
  FLines.Clear;
  FSegs.Clear;
  FSubsectors.Clear;
  FNodes.Clear;
  FThings.Clear;
  SetLength(FBlockMapLump, 0);
  SetLength(FBlockMap, 0);
  SetLength(FReject, 0);
  FBmapWidth := 0;
  FBmapHeight := 0;
  FPlayerFound := False;
end;

procedure TWorld.SetupLevel(Wad: TWad; Episode, MapN: Integer);
var
  LumpNum, I: Integer;
  Name: string;
begin
  Name := Format('MAP%.2d', [MapN]);
  if Wad.CheckNumForName(Name) < 0 then
    Name := Format('E%dM%d', [Episode, MapN]);
  LumpNum := Wad.GetNumForName(Name);
  ClearMap;
  FMapName := Name;
  LoadVertexes(Wad.CacheLumpNum(LumpNum + 4));
  LoadSectors(Wad.CacheLumpNum(LumpNum + 8));
  LoadSides(Wad.CacheLumpNum(LumpNum + 3));
  LoadLines(Wad.CacheLumpNum(LumpNum + 2));
  LoadSegs(Wad.CacheLumpNum(LumpNum + 5));
  LoadSubsectors(Wad.CacheLumpNum(LumpNum + 6));
  LoadNodes(Wad.CacheLumpNum(LumpNum + 7));
  LoadThings(Wad.CacheLumpNum(LumpNum + 1));
  LoadBlockmap(Wad.CacheLumpNum(LumpNum + 10));
  LoadReject(Wad.CacheLumpNum(LumpNum + 9));
  for I := 0 to FSubsectors.Count - 1 do
    if (FSubsectors[I].FirstLine >= 0) and (FSubsectors[I].FirstLine < FSegs.Count) then
      FSubsectors[I].Sector := FSegs[FSubsectors[I].FirstLine].FrontSector;
  FinishView;
end;

procedure TWorld.LoadVertexes(const Data: TBytes);
var
  N, I, O: Integer;
  V: TVertex;
begin
  N := Length(Data) div 4;
  for I := 0 to N - 1 do
  begin
    O := I * 4;
    V := TVertex.Create;
    V.X := MapFixed(I16(Data, O));
    V.Y := MapFixed(I16(Data, O + 2));
    FVertexes.Add(V);
  end;
end;

procedure TWorld.LoadSectors(const Data: TBytes);
var
  N, I, O: Integer;
  S: TSector;
begin
  N := Length(Data) div 26;
  for I := 0 to N - 1 do
  begin
    O := I * 26;
    S := TSector.Create;
    S.FloorHeight := MapFixed(I16(Data, O));
    S.CeilingHeight := MapFixed(I16(Data, O + 2));
    S.FloorPic := Name8(Data, O + 4);
    S.CeilingPic := Name8(Data, O + 12);
    S.LightLevel := I16(Data, O + 20);
    S.Special := I16(Data, O + 22);
    S.Tag := I16(Data, O + 24);
    S.Index := I;
    FSectors.Add(S);
  end;
end;

procedure TWorld.LoadSides(const Data: TBytes);
var
  N, I, O, Sec: Integer;
  Sd: TSide;
begin
  N := Length(Data) div 30;
  for I := 0 to N - 1 do
  begin
    O := I * 30;
    Sd := TSide.Create;
    Sd.TextureOffset := MapFixed(I16(Data, O));
    Sd.RowOffset := MapFixed(I16(Data, O + 2));
    Sd.TopTexture := Name8(Data, O + 4);
    Sd.BottomTexture := Name8(Data, O + 12);
    Sd.MidTexture := Name8(Data, O + 20);
    Sec := I16(Data, O + 28);
    if (Sec >= 0) and (Sec < FSectors.Count) then
      Sd.Sector := FSectors[Sec]
    else if FSectors.Count > 0 then
      Sd.Sector := FSectors[0];
    FSides.Add(Sd);
  end;
end;

procedure TWorld.LoadLines(const Data: TBytes);
var
  N, I, O, V1, V2, S0, S1: Integer;
  Ln: TLine;
begin
  N := Length(Data) div 14;
  for I := 0 to N - 1 do
  begin
    O := I * 14;
    V1 := I16(Data, O);
    V2 := I16(Data, O + 2);
    if (V1 < 0) or (V1 >= FVertexes.Count) or (V2 < 0) or (V2 >= FVertexes.Count) then
      raise Exception.Create('vertice fora do mapa');
    Ln := TLine.Create;
    Ln.V1 := FVertexes[V1];
    Ln.V2 := FVertexes[V2];
    Ln.Dx := AsI32(Int64(Ln.V2.X) - Ln.V1.X);
    Ln.Dy := AsI32(Int64(Ln.V2.Y) - Ln.V1.Y);
    Ln.Flags := I16(Data, O + 4);
    Ln.Special := I16(Data, O + 6);
    Ln.Tag := I16(Data, O + 8);
    S0 := I16(Data, O + 10);
    S1 := I16(Data, O + 12);
    Ln.SideNum[0] := S0;
    Ln.SideNum[1] := S1;
    if (S0 >= 0) and (S0 < FSides.Count) then
    begin
      Ln.Side0 := FSides[S0];
      Ln.FrontSector := Ln.Side0.Sector;
    end;
    if (S1 >= 0) and (S1 < FSides.Count) then
    begin
      Ln.Side1 := FSides[S1];
      Ln.BackSector := Ln.Side1.Sector;
    end;
    if Ln.V1.X < Ln.V2.X then
    begin
      Ln.BBox[0] := Ln.V1.X;
      Ln.BBox[1] := Ln.V2.X;
    end
    else
    begin
      Ln.BBox[0] := Ln.V2.X;
      Ln.BBox[1] := Ln.V1.X;
    end;
    if Ln.V1.Y < Ln.V2.Y then
    begin
      Ln.BBox[2] := Ln.V1.Y;
      Ln.BBox[3] := Ln.V2.Y;
    end
    else
    begin
      Ln.BBox[2] := Ln.V2.Y;
      Ln.BBox[3] := Ln.V1.Y;
    end;
    Ln.Index := I;
    if Ln.FrontSector <> nil then
      Ln.FrontSector.Lines.Add(Ln);
    if (Ln.BackSector <> nil) and (Ln.BackSector <> Ln.FrontSector) then
      Ln.BackSector.Lines.Add(Ln);
    FLines.Add(Ln);
  end;
end;

procedure TWorld.LoadSegs(const Data: TBytes);
var
  N, I, O, Side, LineNum: Integer;
  Sg: TSeg;
  Ln: TLine;
begin
  N := Length(Data) div 12;
  for I := 0 to N - 1 do
  begin
    O := I * 12;
    Sg := TSeg.Create;
    Sg.V1 := FVertexes[I16(Data, O)];
    Sg.V2 := FVertexes[I16(Data, O + 2)];
    Sg.Angle := Cardinal(I16(Data, O + 4)) shl 16;
    LineNum := I16(Data, O + 6);
    Ln := FLines[LineNum];
    Sg.LineDef := Ln;
    Side := I16(Data, O + 8);
    Sg.Offset := MapFixed(I16(Data, O + 10));
    if Side = 0 then
      Sg.SideDef := Ln.Side0
    else
      Sg.SideDef := Ln.Side1;
    if Sg.SideDef = nil then
      Sg.SideDef := Ln.Side0;
    if Sg.SideDef <> nil then
      Sg.FrontSector := Sg.SideDef.Sector;
    if (Ln.Flags and ML_TWOSIDED) <> 0 then
    begin
      if (Side xor 1) = 0 then
      begin
        if Ln.Side0 <> nil then
          Sg.BackSector := Ln.Side0.Sector;
      end
      else if Ln.Side1 <> nil then
        Sg.BackSector := Ln.Side1.Sector;
    end;
    FSegs.Add(Sg);
  end;
end;

procedure TWorld.LoadSubsectors(const Data: TBytes);
var
  N, I, O: Integer;
  Ss: TSubsector;
begin
  N := Length(Data) div 4;
  for I := 0 to N - 1 do
  begin
    O := I * 4;
    Ss := TSubsector.Create;
    Ss.Index := I;
    Ss.NumLines := U16(Data, O);
    Ss.FirstLine := U16(Data, O + 2);
    FSubsectors.Add(Ss);
  end;
end;

procedure TWorld.LoadNodes(const Data: TBytes);
var
  N, I, O, Child, P: Integer;
  Nd: TNode;
begin
  N := Length(Data) div 28;
  for I := 0 to N - 1 do
  begin
    O := I * 28;
    Nd := TNode.Create;
    Nd.X := MapFixed(I16(Data, O));
    Nd.Y := MapFixed(I16(Data, O + 2));
    Nd.Dx := MapFixed(I16(Data, O + 4));
    Nd.Dy := MapFixed(I16(Data, O + 6));
    P := O + 8;
    for Child := 0 to 1 do
    begin
      Nd.BBox[Child, 0] := MapFixed(I16(Data, P));
      Nd.BBox[Child, 1] := MapFixed(I16(Data, P + 2));
      Nd.BBox[Child, 2] := MapFixed(I16(Data, P + 4));
      Nd.BBox[Child, 3] := MapFixed(I16(Data, P + 6));
      Inc(P, 8);
    end;
    Nd.Children[0] := U16(Data, P);
    Nd.Children[1] := U16(Data, P + 2);
    FNodes.Add(Nd);
  end;
end;

procedure TWorld.LoadThings(const Data: TBytes);
var
  N, I, O: Integer;
  Th: TMapThing;
begin
  N := Length(Data) div 10;
  for I := 0 to N - 1 do
  begin
    O := I * 10;
    Th := TMapThing.Create;
    Th.X := I16(Data, O);
    Th.Y := I16(Data, O + 2);
    Th.Angle := I16(Data, O + 4);
    Th.ThingType := I16(Data, O + 6);
    Th.Options := I16(Data, O + 8);
    Th.Radius := 0;
    Th.BodyHeight := 0;
    Th.Health := 0;
    Th.ActorFlags := 0;
    Th.Dead := False;
    Th.FrameUse := -1;
    Th.Ai := 0;
    Th.MoveDir := 8;
    Th.MoveCount := 0;
    Th.Speed := 0;
    Th.Kind := 0;
    Th.Tics := 0;
    Th.DidFire := False;
    Th.HasZ := False;
    Th.Z := 0;
    Th.MomX := 0;
    Th.MomY := 0;
    Th.MomZ := 0;
    Th.SprName := '';
    Th.SprFrame := 0;
    Th.Floats := False;
    Th.Ambush := False;
    Th.FromPlayer := False;
    Th.MissileDmg := 0;
    FThings.Add(Th);
    if (not FPlayerFound) and (Th.ThingType = 1) then
    begin
      FPlayerFound := True;
      FPlayerX := Th.X;
      FPlayerY := Th.Y;
      FPlayerAngle := Th.Angle;
    end;
  end;
end;

procedure TWorld.LoadBlockmap(const Data: TBytes);
var
  N, I, Count: Integer;
begin
  N := Length(Data) div 2;
  SetLength(FBlockMapLump, N);
  for I := 0 to N - 1 do
    FBlockMapLump[I] := U16(Data, I * 2);
  if N < 4 then
    Exit;
  FBmapOrgX := MapFixed(I16(Data, 0));
  FBmapOrgY := MapFixed(I16(Data, 2));
  FBmapWidth := I16(Data, 4);
  FBmapHeight := I16(Data, 6);
  if (FBmapWidth <= 0) or (FBmapHeight <= 0) then
    Exit;
  Count := FBmapWidth * FBmapHeight;
  if (Count <= 0) or (Count > N - 4) then
    Exit;
  SetLength(FBlockMap, Count);
  for I := 0 to Count - 1 do
    FBlockMap[I] := FBlockMapLump[4 + I];
end;

procedure TWorld.LoadReject(const Data: TBytes);
begin
  FReject := Copy(Data);
end;

procedure TWorld.FinishView;
var
  I, X, Y, SpanX, SpanY, AvailW, AvailH: Integer;
begin
  if FVertexes.Count = 0 then
    Exit;
  FMinX := FVertexes[0].X div FRACUNIT;
  FMaxX := FMinX;
  FMinY := FVertexes[0].Y div FRACUNIT;
  FMaxY := FMinY;
  for I := 1 to FVertexes.Count - 1 do
  begin
    X := FVertexes[I].X div FRACUNIT;
    Y := FVertexes[I].Y div FRACUNIT;
    if X < FMinX then
      FMinX := X;
    if X > FMaxX then
      FMaxX := X;
    if Y < FMinY then
      FMinY := Y;
    if Y > FMaxY then
      FMaxY := Y;
  end;
  SpanX := FMaxX - FMinX;
  if SpanX < 1 then
    SpanX := 1;
  SpanY := FMaxY - FMinY;
  if SpanY < 1 then
    SpanY := 1;
  AvailW := SCREENWIDTH - 8;
  AvailH := SCREENHEIGHT - 8;
  if Int64(AvailH) * SpanX < Int64(AvailW) * SpanY then
  begin
    FScaleNum := AvailH;
    FScaleDen := SpanY;
  end
  else
  begin
    FScaleNum := AvailW;
    FScaleDen := SpanX;
  end;
  if FScaleDen < 1 then
    FScaleDen := 1;
  FUsedW := SpanX * FScaleNum div FScaleDen;
  FUsedH := SpanY * FScaleNum div FScaleDen;
  FOffX := (SCREENWIDTH - FUsedW) div 2;
  FOffY := (SCREENHEIGHT - FUsedH) div 2;
end;

function TWorld.ScreenX(MapX: Integer): Integer;
begin
  if FScaleDen = 0 then
    Exit(0);
  Result := FOffX + (MapX - FMinX) * FScaleNum div FScaleDen;
end;

function TWorld.ScreenY(MapY: Integer): Integer;
begin
  if FScaleDen = 0 then
    Exit(0);
  Result := FOffY + FUsedH - (MapY - FMinY) * FScaleNum div FScaleDen;
end;

procedure TWorld.Plot(var Fb: TBytes; X, Y: Integer; Color: Byte);
begin
  if (X < 0) or (Y < 0) or (X >= SCREENWIDTH) or (Y >= SCREENHEIGHT) then
    Exit;
  if Length(Fb) < SCREENPIXELS then
    Exit;
  Fb[Y * SCREENWIDTH + X] := Color;
end;

procedure TWorld.Stroke(var Fb: TBytes; X0, Y0, X1, Y1: Integer; Color: Byte);
var
  Dx, Dy, Sx, Sy, Err, E2: Integer;
begin
  Dx := Abs(X1 - X0);
  Dy := -Abs(Y1 - Y0);
  if X0 < X1 then
    Sx := 1
  else
    Sx := -1;
  if Y0 < Y1 then
    Sy := 1
  else
    Sy := -1;
  Err := Dx + Dy;
  while True do
  begin
    Plot(Fb, X0, Y0, Color);
    if (X0 = X1) and (Y0 = Y1) then
      Break;
    E2 := Err * 2;
    if E2 >= Dy then
    begin
      Inc(Err, Dy);
      Inc(X0, Sx);
    end;
    if E2 <= Dx then
    begin
      Inc(Err, Dx);
      Inc(Y0, Sy);
    end;
  end;
end;

procedure TWorld.FillConvex(var Fb: TBytes; const Pts: TArray<TMapPoint>; Color: Byte);
var
  Left, Right: array[0..SCREENHEIGHT - 1] of Integer;
  I, Y, X, X0, Y0, X1, Y1: Integer;

  procedure AddSpan(SpanY, SpanX: Integer);
  begin
    if (SpanY < 0) or (SpanY >= SCREENHEIGHT) then
      Exit;
    if SpanX < Left[SpanY] then
      Left[SpanY] := SpanX;
    if SpanX > Right[SpanY] then
      Right[SpanY] := SpanX;
  end;

  procedure Cover(Ax, Ay, Bx, By: Integer);
  var
    Swap, Dy, YStart, YEnd, StepY: Integer;
  begin
    if Ay > By then
    begin
      Swap := Ax;
      Ax := Bx;
      Bx := Swap;
      Swap := Ay;
      Ay := By;
      By := Swap;
    end;
    if (By < 0) or (Ay >= SCREENHEIGHT) then
      Exit;
    Dy := By - Ay;
    if Dy = 0 then
    begin
      AddSpan(Ay, Ax);
      AddSpan(Ay, Bx);
      Exit;
    end;
    YStart := Ay;
    if YStart < 0 then
      YStart := 0;
    YEnd := By;
    if YEnd >= SCREENHEIGHT then
      YEnd := SCREENHEIGHT - 1;
    for StepY := YStart to YEnd do
      AddSpan(StepY, Ax + Integer((Int64(Bx - Ax) * (StepY - Ay)) div Dy));
  end;

begin
  if Length(Pts) < 3 then
    Exit;
  for Y := 0 to SCREENHEIGHT - 1 do
  begin
    Left[Y] := 32767;
    Right[Y] := -32767;
  end;
  for I := 0 to High(Pts) do
  begin
    X0 := Pts[I].X;
    Y0 := Pts[I].Y;
    X1 := Pts[(I + 1) mod Length(Pts)].X;
    Y1 := Pts[(I + 1) mod Length(Pts)].Y;
    Cover(X0, Y0, X1, Y1);
  end;
  for Y := 0 to SCREENHEIGHT - 1 do
  begin
    if Right[Y] < Left[Y] then
      Continue;
    X0 := Left[Y];
    if X0 < 0 then
      X0 := 0;
    X1 := Right[Y];
    if X1 >= SCREENWIDTH then
      X1 := SCREENWIDTH - 1;
    for X := X0 to X1 do
      Plot(Fb, X, Y, Color);
  end;
end;

procedure TWorld.FillSubsector(var Fb: TBytes; Ss: TSubsector; Res: TResources);
var
  Pts: TArray<TMapPoint>;
  I, Color: Integer;
  Sg: TSeg;
begin
  if (Ss = nil) or (Ss.Sector = nil) or (Ss.NumLines < 3) then
    Exit;
  if (Res <> nil) then
    Color := Res.ColorForFlat(Ss.Sector.FloorPic)
  else
    Color := -1;
  if Color < 0 then
    Color := 80;
  SetLength(Pts, Ss.NumLines);
  for I := 0 to Ss.NumLines - 1 do
  begin
    if Ss.FirstLine + I >= FSegs.Count then
      Exit;
    Sg := FSegs[Ss.FirstLine + I];
    if Sg.V1 = nil then
      Exit;
    Pts[I].X := ScreenX(Sg.V1.X div FRACUNIT);
    Pts[I].Y := ScreenY(Sg.V1.Y div FRACUNIT);
  end;
  FillConvex(Fb, Pts, Byte(Color));
end;

function TWorld.WallTexture(Ln: TLine): string;
var
  Side: TSide;
begin
  Result := '';
  Side := Ln.Side0;
  if Side = nil then
    Exit;
  if (Ln.Flags and ML_TWOSIDED) = 0 then
  begin
    Result := Side.MidTexture;
    Exit;
  end;
  if (Side.MidTexture <> '') and (Side.MidTexture <> '-') then
    Result := Side.MidTexture
  else if (Ln.FrontSector <> nil) and (Ln.BackSector <> nil) and
    (Ln.FrontSector.FloorHeight <> Ln.BackSector.FloorHeight) and
    (Side.BottomTexture <> '') and (Side.BottomTexture <> '-') then
    Result := Side.BottomTexture
  else if (Ln.FrontSector <> nil) and (Ln.BackSector <> nil) and
    (Ln.FrontSector.CeilingHeight <> Ln.BackSector.CeilingHeight) and
    (Side.TopTexture <> '') and (Side.TopTexture <> '-') then
    Result := Side.TopTexture;
end;

function TWorld.LineColor(Ln: TLine; Res: TResources): Integer;
var
  Name: string;
begin
  Name := WallTexture(Ln);
  if (Res <> nil) and (Name <> '') then
  begin
    Result := Res.ColorForTexture(Name);
    if Result >= 0 then
      Exit;
  end;
  if (Ln.Flags and ML_TWOSIDED) <> 0 then
    Result := TWO_COLOR
  else
    Result := WALL_COLOR;
end;

procedure TWorld.DrawArrow(var Fb: TBytes);
var
  Rad: Double;
  TipX, TipY, LeftX, LeftY, RightX, RightY: Integer;
  X0, Y0, X1, Y1, X2, Y2, X3, Y3: Integer;
begin
  if not FPlayerFound then
    Exit;
  Rad := FPlayerAngle * Pi / 180;
  TipX := FPlayerX + Round(Cos(Rad) * 160);
  TipY := FPlayerY + Round(Sin(Rad) * 160);
  LeftX := TipX + Round(Cos(Rad + Pi * 0.75) * 56);
  LeftY := TipY + Round(Sin(Rad + Pi * 0.75) * 56);
  RightX := TipX + Round(Cos(Rad - Pi * 0.75) * 56);
  RightY := TipY + Round(Sin(Rad - Pi * 0.75) * 56);
  X0 := ScreenX(FPlayerX);
  Y0 := ScreenY(FPlayerY);
  X1 := ScreenX(TipX);
  Y1 := ScreenY(TipY);
  X2 := ScreenX(LeftX);
  Y2 := ScreenY(LeftY);
  X3 := ScreenX(RightX);
  Y3 := ScreenY(RightY);
  Stroke(Fb, X0, Y0, X1, Y1, ARROW_COLOR);
  Stroke(Fb, X1, Y1, X2, Y2, ARROW_COLOR);
  Stroke(Fb, X1, Y1, X3, Y3, ARROW_COLOR);
  Stroke(Fb, X0 + 1, Y0, X1 + 1, Y1, ARROW_COLOR);
end;

procedure TWorld.DrawOverhead(var Fb: TBytes; Res: TResources);
var
  I, Color: Integer;
  Ln: TLine;
begin
  FillFb(Fb, 0);
  for I := 0 to FSubsectors.Count - 1 do
    FillSubsector(Fb, FSubsectors[I], Res);
  for I := 0 to FLines.Count - 1 do
  begin
    Ln := FLines[I];
    Color := LineColor(Ln, Res);
    Stroke(Fb, ScreenX(Ln.V1.X div FRACUNIT), ScreenY(Ln.V1.Y div FRACUNIT),
      ScreenX(Ln.V2.X div FRACUNIT), ScreenY(Ln.V2.Y div FRACUNIT), Byte(Color));
  end;
  DrawArrow(Fb);
end;

end.
