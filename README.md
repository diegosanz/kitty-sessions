# kitty-agents

Guarda las conversaciones abiertas con agentes de código (Claude Code, opencode) y las
shells que tengas en kitty, y las restaura después reanudando la misma sesión. Todo en
bash, sin servidor, sin hooks ni plugins en los agentes.

Un único proceso `kitty-agents watch` por instancia de kitty recorre cada segundo las
ventanas con `kitten @ ls`, detecta los agentes por el proceso en primer plano y guarda un
snapshot cada vez que cambia lo que hay abierto.

## Requisitos

- bash 4+
- kitty 0.48 o superior con `allow_remote_control yes`
- `jq`
- Agentes opcionales en el `PATH`: `claude`, `opencode`
- Para los tests: `bats` (`pacman -S bats` en Arch)

## Instalación

```sh
git clone https://github.com/diegosanz/kitty-agents ~/.local/share/kitty-agents-src
```

Y añade `bin` al `PATH` (ver la sección de `.zshrc`).

### `~/.config/kitty/kitty.conf`

Obligatorio:

```
allow_remote_control yes
```

Opcional, un atajo para restaurar las sesiones guardadas:

```
map ctrl+shift+u launch --type=background kitty-agents restore
```

Y otro para guardar lo abierto bajo un nombre que te pida kitty:

```
map ctrl+shift+s launch --type=background sh -c 'name=$(kitten ask --type=line --prompt "Nombre de la sesión: ") && kitty-agents save "$name"'
```

### `~/.zshrc`

```zsh
export PATH="$HOME/.local/share/kitty-agents-src/bin:$PATH"

if [[ -n "$KITTY_PID" ]] && command -v kitty-agents >/dev/null; then
  kitty-agents watch >/dev/null 2>&1 &!
fi
```

El watcher usa un lock por `KITTY_PID`, así que cada shell nueva intenta arrancarlo y
solo sobrevive el primero. Muere solo cuando se cierra kitty.

## Uso

| Comando                         | Acción                                                        |
| ------------------------------- | ------------------------------------------------------------- |
| `kitty-agents watch`            | Observa las ventanas y guarda cuando cambia lo abierto        |
| `kitty-agents save [nombre]`    | Guarda las sesiones de agente y las shells abiertas           |
| `kitty-agents restore [nombre]` | Reabre en tabs nuevas lo guardado                             |
| `kitty-agents list`             | Lista `_auto` y las sesiones con nombre                       |
| `kitty-agents delete <nombre>`  | Borra una sesión con nombre                                   |

Sin nombre, `save` y `restore` trabajan sobre `_auto`, la sesión que mantiene el watcher.
Con nombre (`[A-Za-z0-9_-]`), `save` escribe una foto fija que solo cambia si vuelves a
guardar con ese nombre: el watcher no la toca, la poda no la borra y `restore <nombre>` la
reabre igual que `_auto`. `_auto` está reservado y no se puede borrar.

Restore es aditivo: abre una tab por sesión guardada, en su directorio, con
`claude -r <id>` u `opencode -s <id>`. Se salta las sesiones ya abiertas, los directorios
que ya no existen y los agentes no instalados.

Las ventanas sin agente se guardan como shells: solo su directorio y, si había algo
corriendo en primer plano, su comando. Restore abre una tab con tu shell en ese directorio
y deja el comando escrito en el prompt sin ejecutarlo. Se salta los directorios en los que
ya hay una shell abierta.

El watcher guarda automáticamente cada vez que cambia lo que hay abierto (sesiones,
shells, sus directorios o sus comandos) respecto a lo que encontró al arrancar, y nunca
escribe un snapshot vacío. Así, abrir un kitty nuevo no pisa el último estado hasta que
abres, cierras o mueves algo; restaura antes de ponerte a trabajar.
Cada guardado crea un fichero nuevo y solo se conservan los últimos `KITTY_AGENTS_HISTORY`;
los locks de watchers que ya no existen se borran al arrancar el siguiente.

## Cómo se descubre la sesión

- **Claude Code**: `--session-id`, `--resume` o `-r` en la línea de comandos; si no, el
  `.jsonl` más reciente de `~/.claude/projects/<directorio>/`. El nombre guardado es el
  `customTitle` de la sesión (`/rename`) o el título de la ventana.
- **opencode**: `-s`/`--session` en la línea de comandos; si no, la sesión más reciente
  de ese directorio en `opencode db`.

Sin `--session-id`, el descubrimiento es heurístico: si tienes dos ventanas de Claude en
el mismo directorio se guardará la misma sesión para ambas.

## Variables de entorno

| Variable                        | Valor por defecto                        |
| ------------------------------- | ---------------------------------------- |
| `KITTY_AGENTS_INTERVAL`         | `1` (segundos entre sondeos)             |
| `KITTY_AGENTS_HISTORY`          | `20` (snapshots que se conservan)        |
| `KITTY_AGENTS_DATA_DIR`         | `$XDG_DATA_HOME/kitty-agents`            |

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
