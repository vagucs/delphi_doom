program delphi_doom;

{
  DOOM generic portado do python_doom para Delphi FireMonkey.

  Por Wagner Nunes da Silva

  vagucs@bol.com.br
  vagucs@vagucs.com.br
  vagucs@gmail.com

  www.vagucs.com.br
}

uses
  System.StartUpCopy,
  FMX.Forms,
  Doom.Compat in 'src\Doom.Compat.pas',
  Doom.Wad in 'src\Doom.Wad.pas',
  Doom.VVideo in 'src\Doom.VVideo.pas',
  Doom.Tables in 'src\Doom.Tables.pas',
  Doom.RData in 'src\Doom.RData.pas',
  Doom.World in 'src\Doom.World.pas',
  Doom.Render in 'src\Doom.Render.pas',
  Doom.Player in 'src\Doom.Player.pas',
  Doom.Specials in 'src\Doom.Specials.pas',
  Doom.Enemy in 'src\Doom.Enemy.pas',
  Doom.Sound in 'src\Doom.Sound.pas',
  Doom.Status in 'src\Doom.Status.pas',
  Doom.Wipe in 'src\Doom.Wipe.pas',
  Doom.Inter in 'src\Doom.Inter.pas',
  Doom.AutoMap in 'src\Doom.AutoMap.pas',
  Doom.Finale in 'src\Doom.Finale.pas',
  Doom.Menu in 'src\Doom.Menu.pas',
  uMain in 'uMain.pas' {FormMain};

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
