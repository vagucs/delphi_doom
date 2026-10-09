# delphi_doom

DOOM generic ported from **[python_doom](https://github.com/vagucs/python_doom)** to **Delphi FireMonkey**.

By **Wagner Nunes da Silva**

- vagucs@bol.com.br
- vagucs@vagucs.com.br
- vagucs@gmail.com
- [www.vagucs.com.br](https://www.vagucs.com.br)
- [LinkedIn](https://www.linkedin.com/in/wagner-nunes-da-silva-b0a15360)

The game stays in Pascal. The FireMonkey form is the window. There is no SDL2 and no Allegro. The same project targets Windows, Android, and iOS. On Windows the arrows move. On Android the same actions are buttons on the screen.

Versão em português: [README.pt.md](README.pt.md)

---

## How to run

RAD Studio 13 (Studio 37.0). This installation compiles only from the IDE. Leave Delphi open and press F9 at the end of each stage. `run.bat` only opens the project.

The Android SDK already installed in the IDE is the Android target. iOS is in the project for a later build on a Mac.

The window is 640×480. The picture is 320×200, stretched. Esc opens the menu. Arrows change the item, Enter confirms, Backspace goes back. F1 opens the help screen. On Android, Use opens and goes back, Fire confirms in the menu and shoots in the level. New Game, or any key on the title, opens the first-person view of E1M1. Up and down walk, left and right turn. Shift runs, Alt strafes, Ctrl fires the pistol. Space or E opens doors and switches. The exit switch loads the next map. Keys on the floor can be picked up. The shot hits monsters and barrels. Monsters chase and shoot back. The pistol, doors, cries, and deaths come out of the speaker. On Windows the level music loops. Android and iOS stay silent for music. The bottom bar shows health, bullets, keys, and the face. The exit opens the stats screen, and the picture melts into the next map. Tab opens the map. F2 saves the game and F3 loads it. The end of the episode shows the closing text. The caption shows health and bullets. The bottom rows stay black for the status bar that comes later. End Game returns to the title.

---

## Phases

The reference is `python_doom/doom/`. Each phase depends on the one before it.

1. **Types.** Done. `src/Doom.Compat.pas` follows `compat.py`. `AsI32` / `AsU32` wrap at 32 bits. `FixedMul` and `FixedDiv` use floor division, like Python `//`.
2. **WAD.** Done. `src/Doom.Wad.pas` follows `wad.py`. Lump numbers stay 0-based. The shareware IWAD has 1264 lumps.
3. **Form.** Done. `uMain.pas` paints the 320×200 bitmap on the FireMonkey form. Windows uses the arrows. Android shows the on-screen pad.
4. **Title.** Done. `src/Doom.VVideo.pas` draws `TITLEPIC` with the first `PLAYPAL`, like `v_video.py`.
5. **Loop and menu.** Done. `src/Doom.Menu.pas` follows `menu.py`. The tick stays near 35 Hz. Demos wait until the map exists.
6. **Map.** Done. `src/Doom.World.pas` follows `world.py`. E1M1 is shown from above. One-sided walls are red, two-sided walls are gray, and the green arrow sits on the player start.
7. **Textures.** Done. `src/Doom.RData.pas` takes the most common color of each flat and each texture, from the palette used by `r_data.py`. The overhead map paints floors with that color and walls with the texture color.
8. **View.** Done. `src/Doom.Tables.pas` builds the sine and tangent tables from `tables.py`. `src/Doom.Render.pas` walks the BSP, draws textured walls, floor and ceiling planes, and the sprites already placed on the map.
9. **Player.** Done. `src/Doom.Player.pas` follows `player.py`. Arrows walk and turn, Shift runs, Alt strafes, and Ctrl fires the pistol. The shot is a hitscan, like `line_attack` in `collision.py`. Monsters and barrels lose health. The pistol sprite sits on the view.
10. **Sectors.** Done. `src/Doom.Specials.pas` follows `specials.py`. Space or E opens doors, lifts, and switches. Lights and scrolling walls run. The exit switch loads the next map. Keys on the floor can be picked up.
11. **Enemies.** Done. `src/Doom.Enemy.pas` follows `enemy.py`. Monsters look, chase, and attack. Troopers use hitscan, imps and barons throw fireballs, and demons bite. A shot wakes the ones that can hear it.
12. **Sound.** Done. `src/Doom.Sound.pas` follows `sound.py` and `mus2mid.py`. `DS*` lumps become 11025 Hz PCM. On Windows, MUS becomes MIDI and plays through MCI. Android and iOS stay silent for music.
13. **Status bar, intermission, and melt.** Done. `src/Doom.Status.pas` draws `STBAR`. `src/Doom.Inter.pas` counts kills, items, secrets, and time. `src/Doom.Wipe.pas` melts the picture when the screen changes.
14. **The rest.** Done. Tab opens the automap. The episode end shows the closing text. F2 saves and F3 loads. `iddqd`, `idkfa`, `idfa`, `idclip`, `idclev` and `idmus` work from the keyboard. `-warp`, `-skill` and `-fps` come from the command line.

Left out: network, joystick, CD audio.

---

## Donate

### GitHub Sponsors

[github.com/sponsors/vagucs](https://github.com/sponsors/vagucs)

### Ethereum

`0x1b64038A2b1DB73ABd0068d8B9B0d1dC5a90C5F1`

![Ethereum QR Code](docs/qr-ethereum.png)

### PIX

Key: `vagucs@bol.com.br`

![PIX QR Code](docs/qr-pix.png)
