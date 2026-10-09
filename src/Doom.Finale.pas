unit Doom.Finale;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br

  Texto de fim de episodio, a partir de doom/finale.py.
  O quadro seguinte e a tela de credito. O mapa 30 volta ao titulo.
}

interface

uses
  System.SysUtils, Doom.Wad;

type
  TFinale = class
  public
    ToTitle: Boolean;
    constructor Create(AWad: TWad; Episode, FinishedMap: Integer; Commercial, ContinueAfter: Boolean);
    function Tick(Skip: Boolean): Boolean;
    procedure Draw(var Fb: TBytes);
  private
    FWad: TWad;
    FText: string;
    FFlat: string;
    FArt: string;
    FCount: Integer;
    FStage: Integer;
    FDone: Boolean;
    procedure Glyph(var Fb: TBytes; var X, Y: Integer; Ch: Char);
  end;

implementation

uses
  Doom.VVideo, Doom.Sound;

const
  TEXTSPEED = 3;
  TEXTWAIT = 250;
  E1TEXT =
    'Once you beat the big badasses and'#10 +
    'clean out the moon base you''re supposed'#10 +
    'to win, aren''t you? Aren''t you? Where''s'#10 +
    'your fat reward and ticket home? What'#10 +
    'the hell is this? It''s not supposed to'#10 +
    'end this way!'#10 +
    #10 +
    'It stinks like rotten meat, but looks'#10 +
    'like the lost Deimos base.  Looks like'#10 +
    'you''re stuck on The Shores of Hell.'#10 +
    'The only way out is through.'#10 +
    #10 +
    'To continue the DOOM experience, play'#10 +
    'The Shores of Hell and its amazing'#10 +
    'sequel, Inferno!'#10;
  E2TEXT =
    'You''ve done it! The hideous cyber-'#10 +
    'demon lord that ruled the lost Deimos'#10 +
    'moon base has been slain and you'#10 +
    'are triumphant! But ... where are'#10 +
    'you? You clamber to the edge of the'#10 +
    'moon and look down to see the awful'#10 +
    'truth.'#10 +
    #10 +
    'Deimos floats above Hell itself!'#10 +
    'You''ve never heard of anyone escaping'#10 +
    'from Hell, but you''ll make the bastards'#10 +
    'sorry they ever heard of you! Quickly,'#10 +
    'you rappel down to  the surface of'#10 +
    'Hell.'#10 +
    #10 +
    'Now, it''s on to the final chapter of'#10 +
    'DOOM! -- Inferno.'#10;
  E3TEXT =
    'The loathsome spiderdemon that'#10 +
    'masterminded the invasion of the moon'#10 +
    'bases and caused so much death has had'#10 +
    'its ass kicked for all time.'#10 +
    #10 +
    'A hidden doorway opens and you enter.'#10 +
    'You''ve proven too tough for Hell to'#10 +
    'contain, and now Hell at last plays'#10 +
    'fair -- for you emerge from the door'#10 +
    'to see the green fields of Earth!'#10 +
    'Home at last.'#10 +
    #10 +
    'You wonder what''s been happening on'#10 +
    'Earth while you were battling evil'#10 +
    'unleashed. It''s good that no Hell-'#10 +
    'spawn could have come through that'#10 +
    'door with you ...'#10;
  E4TEXT =
    'the spider mastermind must have sent forth'#10 +
    'its legions of hellspawn before your'#10 +
    'final confrontation with that terrible'#10 +
    'beast from hell.  but you stepped forward'#10 +
    'and brought forth eternal damnation and'#10 +
    'suffering upon the horde as a true hero'#10 +
    'would in the face of something so evil.'#10 +
    #10 +
    'besides, someone was gonna pay for what'#10 +
    'happened to daisy, your pet rabbit.'#10 +
    #10 +
    'but now, you see spread before you more'#10 +
    'potential pain and gibbitude as a nation'#10 +
    'of demons run amok among our cities.'#10 +
    #10 +
    'next stop, hell on earth!';
  C1TEXT =
    'YOU HAVE ENTERED DEEPLY INTO THE INFESTED'#10 +
    'STARPORT. BUT SOMETHING IS WRONG. THE'#10 +
    'MONSTERS HAVE BROUGHT THEIR OWN REALITY'#10 +
    'WITH THEM, AND THE STARPORT''S TECHNOLOGY'#10 +
    'IS BEING SUBVERTED BY THEIR PRESENCE.'#10 +
    #10 +
    'AHEAD, YOU SEE AN OUTPOST OF HELL, A'#10 +
    'FORTIFIED ZONE. IF YOU CAN GET PAST IT,'#10 +
    'YOU CAN PENETRATE INTO THE HAUNTED HEART'#10 +
    'OF THE STARBASE AND FIND THE CONTROLLING'#10 +
    'SWITCH WHICH HOLDS EARTH''S POPULATION'#10 +
    'HOSTAGE.';
  C2TEXT =
    'YOU HAVE WON! YOUR VICTORY HAS ENABLED'#10 +
    'HUMANKIND TO EVACUATE EARTH AND ESCAPE'#10 +
    'THE NIGHTMARE.  NOW YOU ARE THE ONLY'#10 +
    'HUMAN LEFT ON THE FACE OF THE PLANET.'#10 +
    'CANNIBAL MUTATIONS, CARNIVOROUS ALIENS,'#10 +
    'AND EVIL SPIRITS ARE YOUR ONLY NEIGHBORS.'#10 +
    'YOU SIT BACK AND WAIT FOR DEATH, CONTENT'#10 +
    'THAT YOU HAVE SAVED YOUR SPECIES.'#10 +
    #10 +
    'BUT THEN, EARTH CONTROL BEAMS DOWN A'#10 +
    'MESSAGE FROM SPACE: "SENSORS HAVE LOCATED'#10 +
    'THE SOURCE OF THE ALIEN INVASION. IF YOU'#10 +
    'GO THERE, YOU MAY BE ABLE TO BLOCK THEIR'#10 +
    'ENTRY.  THE ALIEN BASE IS IN THE HEART OF'#10 +
    'YOUR OWN HOME CITY, NOT FAR FROM THE'#10 +
    'STARPORT." SLOWLY AND PAINFULLY YOU GET'#10 +
    'UP AND RETURN TO THE FRAY.';
  C3TEXT =
    'YOU ARE AT THE CORRUPT HEART OF THE CITY,'#10 +
    'SURROUNDED BY THE CORPSES OF YOUR ENEMIES.'#10 +
    'YOU SEE NO WAY TO DESTROY THE CREATURES'''#10 +
    'ENTRYWAY ON THIS SIDE, SO YOU CLENCH YOUR'#10 +
    'TEETH AND PLUNGE THROUGH IT.'#10 +
    #10 +
    'THERE MUST BE A WAY TO CLOSE IT ON THE'#10 +
    'OTHER SIDE. WHAT DO YOU CARE IF YOU''VE'#10 +
    'GOT TO GO THROUGH HELL TO GET TO IT?';
  C4TEXT =
    'THE HORRENDOUS VISAGE OF THE BIGGEST'#10 +
    'DEMON YOU''VE EVER SEEN CRUMBLES BEFORE'#10 +
    'YOU, AFTER YOU PUMP YOUR ROCKETS INTO'#10 +
    'HIS EXPOSED BRAIN. THE MONSTER SHRIVELS'#10 +
    'UP AND DIES, ITS THRASHING LIMBS'#10 +
    'DEVASTATING UNTOLD MILES OF HELL''S'#10 +
    'SURFACE.'#10 +
    #10 +
    'YOU''VE DONE IT. THE INVASION IS OVER.'#10 +
    'EARTH IS SAVED. HELL IS A WRECK. YOU'#10 +
    'WONDER WHERE BAD FOLKS WILL GO WHEN THEY'#10 +
    'DIE, NOW. WIPING THE SWEAT FROM YOUR'#10 +
    'FOREHEAD YOU BEGIN THE LONG TREK BACK'#10 +
    'HOME. REBUILDING EARTH OUGHT TO BE A'#10 +
    'LOT MORE FUN THAN RUINING IT WAS.'#10;
  C5TEXT =
    'CONGRATULATIONS, YOU''VE FOUND THE SECRET'#10 +
    'LEVEL! LOOKS LIKE IT''S BEEN BUILT BY'#10 +
    'HUMANS, RATHER THAN DEMONS. YOU WONDER'#10 +
    'WHO THE INMATES OF THIS CORNER OF HELL'#10 +
    'WILL BE.';
  C6TEXT =
    'CONGRATULATIONS, YOU''VE FOUND THE'#10 +
    'SUPER SECRET LEVEL!  YOU''D BETTER'#10 +
    'BLAZE THROUGH THIS ONE!'#10;

constructor TFinale.Create(AWad: TWad; Episode, FinishedMap: Integer; Commercial, ContinueAfter: Boolean);
begin
  inherited Create;
  FWad := AWad;
  FStage := 0;
  ToTitle := not ContinueAfter;
  if Commercial then
  begin
    case FinishedMap of
      11: begin FFlat := 'RROCK14'; FText := C2TEXT; end;
      20: begin FFlat := 'RROCK07'; FText := C3TEXT; end;
      30: begin FFlat := 'RROCK17'; FText := C4TEXT; ToTitle := True; end;
      15: begin FFlat := 'RROCK13'; FText := C5TEXT; end;
      31: begin FFlat := 'RROCK19'; FText := C6TEXT; end;
    else
      begin FFlat := 'SLIME16'; FText := C1TEXT; end;
    end;
    StartMusic('read_m', True);
  end
  else
  begin
    case Episode of
      2: begin FFlat := 'SFLR6_1'; FText := E2TEXT; FArt := 'VICTORY2'; end;
      3: begin FFlat := 'MFLR8_4'; FText := E3TEXT; FArt := 'PFUB2'; end;
      4: begin FFlat := 'MFLR8_3'; FText := E4TEXT; FArt := 'ENDPIC'; end;
    else
      begin FFlat := 'FLOOR4_8'; FText := E1TEXT; FArt := 'CREDIT'; end;
    end;
    ToTitle := True;
    StartMusic('victor', True);
  end;
end;

function TFinale.Tick(Skip: Boolean): Boolean;
begin
  Result := False;
  if FDone then
    Exit(True);
  if (FStage = 0) and Skip and (FCount > 50) and not ToTitle then
  begin
    FDone := True;
    Exit(True);
  end;
  Inc(FCount);
  if FStage = 0 then
  begin
    if FCount > Length(FText) * TEXTSPEED + TEXTWAIT then
    begin
      if ToTitle then
      begin
        FStage := 1;
        FCount := 0;
      end
      else
      begin
        FDone := True;
        Result := True;
      end;
    end;
  end
  else if Skip and (FCount > 10) then
  begin
    FDone := True;
    Result := True;
  end;
end;

procedure TFinale.Glyph(var Fb: TBytes; var X, Y: Integer; Ch: Char);
var
  Code, N: Integer;
  P: TBytes;
begin
  if Ch = #10 then
  begin
    X := 10;
    Inc(Y, 11);
    Exit;
  end;
  Code := Ord(UpCase(Ch));
  if (Ch = ' ') or (Code < 33) or (Code > 95) then
  begin
    Inc(X, 4);
    Exit;
  end;
  if FWad = nil then
    Exit;
  N := FWad.CheckNumForName(Format('STCFN%.3d', [Code]));
  if N < 0 then
  begin
    Inc(X, 4);
    Exit;
  end;
  P := FWad.CacheLumpNum(N);
  DrawPatch(Fb, X, Y, P);
  Inc(X, PatchWidth(P));
end;

procedure TFinale.Draw(var Fb: TBytes);
var
  Lump, I, X, Y, Show, N, DX, DY, Row: Integer;
  Flat, Art: TBytes;
  Pix: Byte;
begin
  if FStage = 1 then
  begin
    FillFb(Fb, 0);
    if (FWad <> nil) and (FArt <> '') then
    begin
      N := FWad.CheckNumForName(FArt);
      if N < 0 then
        N := FWad.CheckNumForName('HELP2');
      if N < 0 then
        N := FWad.CheckNumForName('CREDIT');
      if N >= 0 then
      begin
        Art := FWad.CacheLumpNum(N);
        DrawPatch(Fb, 0, 0, Art);
      end;
    end;
    Exit;
  end;
  FillFb(Fb, 0);
  if FWad <> nil then
  begin
    N := FWad.CheckNumForName(FFlat);
    if N >= 0 then
    begin
      Flat := FWad.CacheLumpNum(N);
      if Length(Flat) >= 4096 then
        for DY := 0 to SCREENHEIGHT - 1 do
        begin
          Row := (DY and 63) * 64;
          for DX := 0 to SCREENWIDTH - 1 do
          begin
            Pix := Flat[Row + (DX and 63)];
            Fb[DY * SCREENWIDTH + DX] := Pix;
          end;
        end;
    end;
  end;
  Show := FCount div TEXTSPEED;
  X := 10;
  Y := 10;
  Lump := 0;
  for I := 1 to Length(FText) do
  begin
    if Lump >= Show then
      Break;
    Glyph(Fb, X, Y, FText[I]);
    Inc(Lump);
  end;
end;

end.
