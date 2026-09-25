# kitty-agents

Muestra el estado de los agentes de código (Claude Code, opencode) en el título de la tab
de kitty, guarda las conversaciones abiertas y las restaura después reanudando la misma
sesión. Todo en bash, sin servidor, sin hooks ni plugins en los agentes.

Un único proceso `kitty-agents watch` por instancia de kitty recorre cada segundo las
ventanas con `kitten @ ls`, detecta los agentes por el proceso en primer plano, lee su
pantalla para deducir el estado y actualiza el título de la tab con un icono:

| Icono | Estado                                            |
| ----- | ------------------------------------------------- |
| ⚙     | trabajando                                        |
| 🔔    | esperando una decisión tuya (permiso, pregunta)   |
| ✅    | terminado, esperando el siguiente prompt          |

Cuando el agente termina, la tab vuelve a seguir el título de la ventana.

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

### `~/.zshrc`

```zsh
export PATH="$HOME/.local/share/kitty-agents-src/bin:$PATH"

export KITTY_AGENTS_ICON_WORKING='⚙'
export KITTY_AGENTS_ICON_ATTENTION='🔔'
export KITTY_AGENTS_ICON_DONE='✅'

if [[ -n "$KITTY_PID" ]] && command -v kitty-agents >/dev/null; then
  kitty-agents watch >/dev/null 2>&1 &!
fi
```

El watcher usa un lock por `KITTY_PID`, así que cada shell nueva intenta arrancarlo y
solo sobrevive el primero. Muere solo cuando se cierra kitty.

## Uso

| Comando                       | Acción                                                        |
| ----------------------------- | ------------------------------------------------------------- |
| `kitty-agents watch`          | Observa las ventanas y refleja el estado en la tab           |
| `kitty-agents save`           | Guarda las sesiones de agente abiertas                        |
| `kitty-agents restore`        | Reabre en tabs nuevas las sesiones del último snapshot        |
| `kitty-agents status <id>`    | Imprime agente y estado de la ventana `<id>`                  |

Restore es aditivo: abre una tab por sesión guardada, en su directorio, con
`claude -r <id>` u `opencode -s <id>`. Se salta las sesiones ya abiertas, los directorios
que ya no existen y los agentes no instalados.

El watcher guarda automáticamente cada vez que cambia el conjunto de sesiones abiertas y
nunca escribe un snapshot vacío, así que cerrar todas las tabs no borra el último estado.

## Cómo se descubre la sesión

- **Claude Code**: `--session-id`, `--resume` o `-r` en la línea de comandos; si no, el
  `.jsonl` más reciente de `~/.claude/projects/<directorio>/`. El nombre guardado es el
  `customTitle` de la sesión (`/rename`) o el título de la ventana.
- **opencode**: `-s`/`--session` en la línea de comandos; si no, la sesión más reciente
  de ese directorio en `opencode db`.

Sin `--session-id`, el descubrimiento es heurístico: si tienes dos ventanas de Claude en
el mismo directorio se guardará la misma sesión para ambas.

## Estados por pantalla

Los patrones viven en `scripts/agents/<agente>.sh`, función `agent_status_from_screen`,
y dependen de la UI de cada versión del agente. Si un estado deja de detectarse, ajusta
ahí la expresión regular.

## Variables de entorno

| Variable                        | Valor por defecto                        |
| ------------------------------- | ---------------------------------------- |
| `KITTY_AGENTS_ICON_WORKING`     | `⚙`                                      |
| `KITTY_AGENTS_ICON_ATTENTION`   | `🔔`                                     |
| `KITTY_AGENTS_ICON_DONE`        | `✅`                                     |
| `KITTY_AGENTS_INTERVAL`         | `1` (segundos entre sondeos)             |
| `KITTY_AGENTS_DATA_DIR`         | `$XDG_DATA_HOME/kitty-agents`            |

Los snapshots son TSV (`agente, sesión, directorio, nombre, fecha`) en el directorio de
datos, con un enlace `last` al más reciente.

## Tests

```sh
bats tests/
```

Los tests usan fakes de `kitten`, `claude` y `opencode` en `tests/fakes`, sin necesidad de
kitty en ejecución.
