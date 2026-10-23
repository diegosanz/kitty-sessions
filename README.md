# kitty-sessions

Guarda las tabs abiertas. Las tabs con Claude Code las restaura después reanudando la misma sesión. Todo en
bash, sin servidor, sin hooks ni plugins en los agentes.

Un único proceso `kitty-sessions watch` por instancia de kitty recorre cada segundo las
ventanas con `kitten @ ls`, detecta los agentes por el proceso en primer plano, guarda un
snapshot cada vez que cambia lo que hay abierto y pone una campana en la tab cuando un
agente termina sin que lo estés mirando.

## Requisitos

- bash 4+
- kitty 0.48 o superior con `allow_remote_control yes`
- `jq`
- Agentes opcionales en el `PATH`: `claude`, `opencode`
- Para los tests: `bats` (`pacman -S bats` en Arch)

## Instalación

```sh
git clone https://github.com/diegosanz/kitty-sessions ~/.local/share/kitty-sessions-src
```

Y añade `bin` al `PATH` (ver la sección de `.zshrc`).

### `~/.config/kitty/kitty.conf`

Obligatorio:

```
allow_remote_control yes
```

Opcional, un atajo para restaurar las sesiones guardadas:

```
map ctrl+shift+u launch --type=background kitty-sessions restore
```

Y otro para guardar lo abierto bajo un nombre que te pida kitty:

```
map ctrl+shift+s launch --type=background sh -c 'name=$(kitten ask --type=line --prompt "Nombre de la sesión: ") && kitty-sessions save "$name"'
```

### `~/.zshrc`

```zsh
export PATH="$HOME/.local/share/kitty-sessions-src/bin:$PATH"

if [[ -n "$KITTY_PID" ]] && command -v kitty-sessions >/dev/null; then
  kitty-sessions watch >/dev/null 2>&1 &!
fi
```

El watcher usa un lock por `KITTY_PID`, así que cada shell nueva intenta arrancarlo y
solo sobrevive el primero. Muere solo cuando se cierra kitty.

## Uso

| Comando                           | Acción                                                        |
| --------------------------------- | ------------------------------------------------------------- |
| `kitty-sessions watch`            | Observa las ventanas, guarda cuando cambia lo abierto y avisa |
| `kitty-sessions save [nombre]`    | Guarda las sesiones de agente y las shells abiertas           |
| `kitty-sessions restore [nombre]` | Reabre en tabs nuevas lo guardado                             |
| `kitty-sessions list`             | Lista `_auto` y las sesiones con nombre                       |
| `kitty-sessions delete <nombre>`  | Borra una sesión con nombre                                   |

Sin nombre, `save` y `restore` trabajan sobre `_auto`, la sesión que mantiene el watcher.
Con nombre (`[A-Za-z0-9_-]`), `save` escribe una foto fija que solo cambia si vuelves a
guardar con ese nombre: el watcher no la toca, la poda no la borra y `restore <nombre>` la
reabre igual que `_auto`. `_auto` está reservado y no se puede borrar.

Restore es aditivo: abre una tab por sesión guardada, en su directorio, con
`claude -r <id>`, o con un `opencode` nuevo para las tabs de opencode. Se salta las
sesiones de Claude ya abiertas, los directorios que ya no existen y los agentes no
instalados; las tabs de opencode se reabren siempre.

Las ventanas sin agente se guardan como shells: solo su directorio y, si había algo
corriendo en primer plano, su comando. Restore abre una tab con tu shell en ese directorio
y deja el comando escrito en el prompt sin ejecutarlo. Se salta los directorios en los que
ya hay una shell abierta.

El watcher guarda automáticamente cada vez que cambia lo que hay abierto (sesiones,
shells, sus directorios o sus comandos) respecto a lo que encontró al arrancar, y nunca
escribe un snapshot vacío. Así, abrir un kitty nuevo no pisa el último estado hasta que
abres, cierras o mueves algo; restaura antes de ponerte a trabajar.
Cada guardado crea un fichero nuevo y solo se conservan los últimos `KITTY_SESSIONS_HISTORY`;
los locks de watchers que ya no existen se borran al arrancar el siguiente.

## Campana al terminar

Claude Code escribe su estado en el título de la ventana: `◐`/`◑` mientras trabaja y `✳`
cuando espera el siguiente prompt. El watcher vigila ese título y, cuando ve pasar de
trabajando a terminado en una tab que no es la activa, cambia el título de la tab a
`🔔 ✳ <título>`. Al cambiar a esa tab la campana desaparece y la tab vuelve a seguir el
título de la ventana. Si el agente se pone a trabajar de nuevo antes de que la veas, la
campana se quita y volverá a sonar cuando termine.

No hay campana para lo que ya estaba terminado al arrancar el watcher, ni si la tab
estaba a la vista cuando terminó. opencode no publica su estado en el título, así que de
momento queda fuera.

## Cómo se descubre la sesión

- **Claude Code**: `--session-id`, `--resume` o `-r` en la línea de comandos; si no, el
  `.jsonl` más reciente de `~/.claude/projects/<directorio>/`. El nombre guardado es el
  `customTitle` de la sesión (`/rename`) o el título de la ventana.
- **opencode**: no se busca sesión. Se guarda solo el directorio (con `-` como sesión) y
  restore lanza `opencode` a secas.

Sin `--session-id`, el descubrimiento es heurístico: si tienes dos ventanas de Claude en
el mismo directorio se guardará la misma sesión para ambas.

## Variables de entorno

| Variable                   | Valor por defecto                 |
| -------------------------- | --------------------------------- |
| `KITTY_SESSIONS_ICON_BELL` | `🔔`                              |
| `KITTY_SESSIONS_INTERVAL`  | `1` (segundos entre sondeos)      |
| `KITTY_SESSIONS_HISTORY`   | `20` (snapshots que se conservan) |
| `KITTY_SESSIONS_DATA_DIR`  | `$XDG_DATA_HOME/kitty-sessions`   |

Los snapshots son TSV (`agente, sesión, directorio, nombre, fecha`) en el directorio de
datos, con un enlace `last` al más reciente. Las sesiones con nombre viven en
`sessions/<nombre>.tsv` con el mismo formato. Las shells llevan `shell` como agente, `-` como
sesión y el comando en primer plano como nombre (`-` si no había ninguno).

## Tests

```sh
bats tests/
```

Los tests usan fakes de `kitten`, `claude` y `opencode` en `tests/fakes`, sin necesidad de
kitty en ejecución.
