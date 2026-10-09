# delphi_doom

DOOM generic portado de **[python_doom](https://github.com/vagucs/python_doom)** para **Delphi FireMonkey**.

Por **Wagner Nunes da Silva**

- vagucs@bol.com.br
- vagucs@vagucs.com.br
- vagucs@gmail.com
- [www.vagucs.com.br](https://www.vagucs.com.br)
- [LinkedIn](https://www.linkedin.com/in/wagner-nunes-da-silva-b0a15360)

O jogo fica em Pascal. O formulário FireMonkey é a janela. Não há SDL2 nem Allegro. O mesmo projeto aponta para Windows, Android e iOS. No Windows as setas movem. No Android as mesmas ações são botões na tela.

English version: [README.md](README.md)

---

## Como rodar

RAD Studio 13 (Studio 37.0). Esta instalação só compila pelo IDE. Deixe o Delphi aberto e aperte F9 ao fim de cada etapa. O `run.bat` só abre o projeto.

O SDK de Android já instalado no IDE é o alvo Android. O iOS está no projeto para uma compilação depois, no Mac.

A janela é 640×480. O quadro é 320×200, esticado. Esc abre o menu. As setas trocam o item, Enter confirma, Backspace volta. F1 abre a ajuda. No Android, Use abre e volta, Fire confirma no menu e atira na fase. Novo Jogo, ou qualquer tecla no título, abre a vista em primeira pessoa de E1M1. Cima e baixo andam, esquerda e direita viram. Shift corre, Alt anda de lado, Ctrl atira com a pistola. Espaço ou E abre portas e interruptores. O interruptor de saída carrega o mapa seguinte. As chaves no chão podem ser pegadas. O tiro acerta monstros e barris. Os monstros perseguem e atiram de volta. A pistola, as portas, o grito e a morte saem no alto-falante. No Windows a música do mapa fica em loop. Android e iOS ficam sem música. A barra embaixo mostra vida, balas, chaves e o rosto. A saída abre a estatística e o quadro escorre para o mapa seguinte. Tab abre o mapa. F2 grava a partida e F3 carrega. No fim do episódio entra o texto de encerramento. A legenda mostra vida e balas. As linhas de baixo ficam pretas para a barra que vem depois. Fim de jogo volta ao título.

---

## Fases

A referência é `python_doom/doom/`. Cada fase depende da anterior.

1. **Tipos.** Feito. `src/Doom.Compat.pas` segue `compat.py`. `AsI32` / `AsU32` estouram em 32 bits. `FixedMul` e `FixedDiv` usam divisão para baixo, como o `//` do Python.
2. **WAD.** Feito. `src/Doom.Wad.pas` segue `wad.py`. O número do lump continua 0-based. O shareware sai com 1264 lumps.
3. **Form.** Feito. `uMain.pas` pinta o bitmap de 320×200 no form FireMonkey. O Windows usa as setas. O Android mostra os botões na tela.
4. **Título.** Feito. `src/Doom.VVideo.pas` desenha o `TITLEPIC` com a primeira `PLAYPAL`, como `v_video.py`.
5. **Laço e menu.** Feito. `src/Doom.Menu.pas` segue `menu.py`. O pulso fica perto de 35 Hz. As demos ficam para quando o mapa existir.
6. **Mapa.** Feito. `src/Doom.World.pas` segue `world.py`. E1M1 aparece visto de cima. Paredes de um lado em vermelho, as de dois lados em cinza, a seta verde no ponto do jogador.
7. **Texturas.** Feito. `src/Doom.RData.pas` tira a cor mais comum de cada flat e de cada textura, como a paleta de `r_data.py`. O mapa de cima pinta o piso com essa cor e a parede com a da textura.
8. **Vista.** Feito. `src/Doom.Tables.pas` monta as tabelas de seno e tangente de `tables.py`. `src/Doom.Render.pas` percorre o BSP, desenha paredes com textura, planos de chão e teto, e os sprites que já estão no mapa.
9. **Jogador.** Feito. `src/Doom.Player.pas` segue `player.py`. As setas andam e viram, Shift corre, Alt anda de lado, Ctrl atira com a pistola. O tiro é hitscan, como o `line_attack` de `collision.py`. Monstros e barris perdem vida. O sprite da pistola fica na vista.
10. **Setores.** Feito. `src/Doom.Specials.pas` segue `specials.py`. Espaço ou E abre portas, elevadores e interruptores. Luzes e paredes que deslizam andam. O interruptor de saída carrega o mapa seguinte. As chaves no chão podem ser pegadas.
11. **Inimigos.** Feito. `src/Doom.Enemy.pas` segue `enemy.py`. Os monstros olham, perseguem e atacam. Soldados usam hitscan, imps e barões lançam bolas de fogo, e demônios mordem. Um tiro acorda os que podem ouvir.
12. **Som.** Feito. `src/Doom.Sound.pas` segue `sound.py` e `mus2mid.py`. Os lumps `DS*` viram PCM em 11025 Hz. No Windows a música MUS vira MIDI e toca pela MCI. Android e iOS ficam sem música.
13. **Barra, intermissão e melt.** Feito. `src/Doom.Status.pas` desenha a `STBAR`. `src/Doom.Inter.pas` conta mortes, itens, segredos e tempo. `src/Doom.Wipe.pas` faz o quadro escorrer na troca de tela.
14. **Resto.** Feito. Tab abre o automapa. O fim do episódio mostra o texto. F2 grava e F3 carrega. `iddqd`, `idkfa`, `idfa`, `idclip`, `idclev` e `idmus` valem no teclado. `-warp`, `-skill` e `-fps` entram pela linha de comando.

Fora: rede, joystick, CD de áudio.

---

## Doe

### Patrocínio no GitHub

[github.com/sponsors/vagucs](https://github.com/sponsors/vagucs)

### Ethereum

`0x1b64038A2b1DB73ABd0068d8B9B0d1dC5a90C5F1`

![QR Code Ethereum](docs/qr-ethereum.png)

### PIX

Chave: `vagucs@bol.com.br`

![QR Code PIX](docs/qr-pix.png)
