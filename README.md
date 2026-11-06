# Carreira FC — protótipo 1 (partida jogável)

Partida completa de 90 minutos (6 min reais) em que você controla **só o seu jogador** (camisa 9, atacante);
os outros 21 jogadores são IA. Feito em **Godot 4.3+** (GDScript), pensado para Android.

## Como abrir e testar no PC
1. Abra o Godot 4.3 ou mais novo → **Import** → selecione `project.godot`.
2. Aperte **F5**.
3. Controles de teclado: `WASD`/setas mover · `Espaço` ou `J` chute (segure p/ força) · `K` passe (e desarme sem a bola) ·
   `L` cruzamento · `Shift` correr · `E` pedir a bola · `Q` carrinho.
   O mouse também funciona nos botões de tela (o projeto emula toque com o mouse).

## Como gerar o APK
1. Godot → **Editor → Manage Export Templates** → instale os templates da sua versão.
2. Instale o **Android SDK / JDK 17** e aponte para eles em **Editor Settings → Export → Android**.
3. **Project → Install Android Build Template** (opcional para APK simples) e **Project → Export → Add… → Android**.
4. Marque **Export as APK** (para instalar direto) e clique **Export Project**. Ou, com o celular em modo
   desenvolvedor e USB ligado, use o botão **Run on device** (ícone de Android no topo).

## Controles no celular
Joystick flutuante na metade esquerda; botões à direita: **CHUTE** (segure para força), **PASSE** (sem a bola vira desarme),
**CRUZ.**, **CORRER**, **PEDIR** (os companheiros passam mais para você enquanto segura) e **CARR.** (carrinho).

## Arquivos
- `scripts/match.gd` — a partida: regras, IA, chutes/passes, goleiro, gols, bola fora, relógio, nota.
- `scripts/touch_controls.gd` — joystick + botões (e teclado).
- `scripts/match_hud.gd` — placar, fôlego, barra de força, mensagens, tela de fim.
- `scripts/footballer.gd`, `soccer_ball.gd`, `pitch_view.gd` — jogador, bola e campo.
- Ao fim do jogo é salvo `user://last_match.json` (placar, nota, estatísticas): é esse resumo que vai alimentar a IA das entrevistas.

## Ainda não tem (próximos passos)
Faltas/cartões, impedimento, substituições, troca de lados no 2º tempo, atributos/progressão estilo EAFC,
ciclo da semana (treino), entrevista com IA e mundo aberto.
