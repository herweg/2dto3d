# Fase 3 — sistema de guardado

**Rol:** Mesa de Developers (Motor).
**Fecha:** 10-ago-2026.
**Origen:** pedido directo del usuario. Corresponde a la tercera pieza de
motor identificada en `fase3-alcance-v1.md` sección 6 ("sistema de
guardado/carga"), pausada por Dirección hasta que el árbol de mejoras
tuviera "aunque sea una forma preliminar" (`plan-fases.md`) — condición ya
cumplida por el frame de talentos (`fase3-talentos-motor.md`).

---

## 1. Alcance — qué pidió el usuario, tal cual

- Guardar el estado de la partida: monstruos eliminados, nivel del
  jugador, estado del árbol de talentos, oro (única moneda por ahora).
- Oro se gana al finalizar rondas — placeholder de 10 por ronda, pedido
  explícito ("si lo haces ponele un arbitrario 10 por ronda").
- Botón "Tabula Rasa" — borra todos los datos de juego, **sin
  explicación en la UI, a propósito**.

## 2. `SaveManager` — autoload, JSON en `user://`

`game/sim/save_manager.gd`, registrado en `project.godot` (`[autoload]`).
Autoload porque `change_scene_to_file()` no pasa datos entre escenas —
MainMenu, Level1 y TalentTree necesitan leer/escribir el mismo estado sin
acoplarse a mano entre sí.

**JSON, no Resource/`.tres`** — a diferencia de `LevelDef`/`TalentTreeDef`
(autoría de diseño, se cargan con `preload`), esto es data generada en
tiempo de ejecución. JSON es el camino estándar de Godot para partidas
guardadas y evita el problema de registro de `class_name` que ya mordió al
árbol de talentos (`fase3-talentos-motor.md` sección 5.1) — un autoload
plano (`extends Node`, sin `class_name`) no lo tiene, confirmado en la
verificación (sección 5 de este documento).

**Estado guardado** (`SaveManager.state`, con default si no hay archivo o
está corrupto):
```json
{"player_level": 1, "gold": 0, "total_kills": 0, "unlocked_talent_ids": []}
```

**Separación save real / save de prueba** — cualquier invocación con
argumentos de línea de comandos (todo lo que corre Motor para verificar)
escribe en `user://savegame_test.json`, no en `user://savegame.json`. Nada
de lo que este juego exporta hoy usa argumentos para jugar de verdad, así
que esta separación evita que una corrida de regresión deje oro o
talentos falsos en la partida real de quien lo juegue sin argumentos.

## 3. Dónde se lee/escribe cada stat

| Stat | Se escribe en | Se lee en |
|---|---|---|
| `gold` | `level_controller.gd::_complete_round()` (+10 por ronda, incluye el atajo de test) y `talent_tree_controller.gd::_try_unlock()` (gasto) | `talent_tree_controller.gd` (gating de costo), `main_menu_controller.gd` (status) |
| `total_kills` | `level_controller.gd::_complete_round()` (+`_lane_system.killed_count` de esa ronda) | `main_menu_controller.gd` (status) |
| `unlocked_talent_ids` | `talent_tree_controller.gd::_try_unlock()` | `talent_tree_controller.gd::_ready()` (repuebla `_unlocked` al cargar la pantalla) |
| `player_level` | Nada todavía — no existe mecánica de subir de nivel (`fase3-alcance-v1.md` sección 2, sin calibrar). Campo persistido, listo para cuando exista. | `main_menu_controller.gd` (status) |

**El oro del árbol de talentos pasó a ser real, no un contador en memoria**
— `talent_tree_controller.gd` ya no tiene su propio `_points_available`;
lee y gasta `SaveManager.state["gold"]` directamente. Esto significa que
una partida nueva (0 oro) no puede desbloquear nada hasta jugar una ronda
— correcto por diseño (hay que ganar oro antes de poder gastarlo), no un
bug, y se verificó así (sección 5).

## 4. "Tabula Rasa"

`SaveManager.wipe_all_data()` — vuelve al estado default y lo persiste
(no alcanza con resetear en memoria). Botón en `MainMenu.tscn`, sin
`tooltip_text` ni texto adicional más allá de "Tabula Rasa" — pedido
explícito del usuario. Separado del resto de los botones con espacio de
sobra (no estilo, solo layout) para que no se confunda con "un botón más"
sin necesitar explicarlo con palabras. Sin confirmación — mismo pedido.

## 5. Verificación

Flags CLI nuevos, mismo criterio que el resto del proyecto: `gold=<n>`
(override para test, reemplaza a `points=<n>` de la tarjeta anterior),
`tabula-rasa`, `set-level=<n>` (sin mecánica real detrás, solo prueba que
persiste).

| Caso | Resultado |
|---|---|
| `TalentTree.tscn -- gold=50 unlock=root` | `oro: 49` (50-1), guardado en `savegame_test.json` |
| `Level1.tscn -- ... force-finish-round quit-after=1` (ronda forzada, sin bajas reales) | `oro ganado: 10`, `total_kills` sin cambios (0 bajas reales todavía) |
| `Level1.tscn -- ... start-round quit-after=32` (ronda real completa, sin forzar) | `muertes: 10`, guardado confirma `"total_kills":10` |
| `TalentTree.tscn -- unlock=root unlock=ctrl_trunk_1` y recarga sin `unlock=` | Las dos veces `2/31 desbloqueados, oro: 8` — persiste entre procesos, no solo en memoria |
| `MainMenu.tscn -- tabula-rasa` y recarga de `TalentTree.tscn` | `0/31, oro: 0` — Tabula Rasa borra de verdad, confirmado desde otra pantalla |
| Captura de ventana de `MainMenu.tscn` | Status "Nivel: 1  Oro: 10  Bajas totales: 0" legible, botón "Tabula Rasa" separado y sin texto extra |
| Regresión estándar de `Level1.tscn`/`stress-test` | Sin cambios respecto al baseline — el guardado no interfiere con nada de lo ya construido |

Todo pasa. `save_path` de test se limpió entre corridas para no arrastrar
estado de una prueba a la siguiente.

## 6. Qué sigue sin resolver, a propósito

Ninguna mecánica sube `player_level` todavía — el campo persiste pero
nada lo mueve. Los efectos del árbol de talentos (`stat_id`/
`modifier_value`) siguen sin conectarse a `TowerStore`/`TowerSystem` —
esto guarda que un nodo esté desbloqueado, no aplica lo que ese nodo
hace. Los dos son la calibración/conexión real que sigue pendiente,
mismo criterio que ya dejó anotado `fase3-talentos-motor.md`.
