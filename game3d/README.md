# TowerDefense 3D

Proyecto Godot 4.7 independiente — el subconjunto 3D de `/game/` (repo
hermano), depurado para funcionar solo, sin depender de ningún archivo
fuera de esta carpeta. Por qué existe un proyecto separado en vez de seguir
sobre `/game/`: ver `docs/towerdefense_3d_manifiesto.md`. Decisiones y
dificultades ya sobrellevadas que siguen siendo relevantes acá: ver
`docs/versionado.md`.

## Requisitos

- **Godot 4.7** (Forward+). Este repo trae el binario en `.tools/godot/`
  (`Godot_v4.7-stable_win64_console.exe`) un nivel arriba de esta carpeta;
  si `game3d/` se movió a otro lado, usar cualquier instalación de Godot
  4.7 propia.
- **Rust** (`stable-msvc`, el default en Windows) vía
  [rustup](https://rustup.rs/), solo si se va a compilar el hot path nativo
  (opcional — ver abajo).
- **Visual Studio Build Tools** (workload "Desktop development with C++"),
  necesario para que `stable-msvc` pueda enlazar. En Windows con Smart App
  Control activo, esta es la ruta que funciona — MinGW queda bloqueado.

```powershell
winget install --id Rustlang.Rustup -e --accept-package-agreements --accept-source-agreements --silent
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --silent --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

## Build del hot path nativo (opcional, pero recomendado)

`SimHotPath` (`rust/`) acelera la colisión de proyectiles. Sin compilarlo,
el juego sigue andando — cada call site chequea
`ClassDB.class_exists("SimHotPath")` antes de usarlo y cae a un camino
GDScript puro más lento si no está.

```powershell
cd rust
cargo build --release
Copy-Item target\release\sim_hotpath.dll ..\bin\sim_hotpath.dll -Force
```

Primera vez: ~2-3 minutos (compila `godot-rust`/`gdext` entero). El `.dll`
ya compilado de esta migración está en `bin/sim_hotpath.dll` — si no se
tocó `rust/src/lib.rs`, no hace falta recompilar.

## Primer arranque / rescan

Cada vez que se agrega o renombra un script con `class_name`, o se deja
caer un `.dll` nuevo, Godot necesita un rescan antes de reconocer la clase
— si no, tira `Parse Error: Could not find type "X"` en headless. Forzar
el rescan (una vez, después de clonar/copiar este proyecto):

```powershell
<ruta-a-godot>\Godot_v4.7-stable_win64_console.exe --path . --headless --editor --quit-after 60
```

Confirmar que `SimHotPath` cargó: la primera línea de cualquier corrida
debería ser `Initialize godot-rust (API v4.3.stable.official, ...)`.

## Mapa de autoloads

| Autoload | Archivo | Qué guarda |
|---|---|---|
| `SaveManager` | `sim/save_manager.gd` | Progreso de partida — `user://savegame.json` |
| `Settings` | `sim/settings.gd` | Preferencias de UI (`show_fps`) — `user://settings.json`, separado de SaveManager a propósito (ver versionado.md §8) |
| `StressLaunchConfig` | `sim/stress_launch_config.gd` | Preset de stress-test pasado de StressMenu a Level.tscn |
| `FpsOverlay` | `scenes/FpsOverlay.tscn` | Autoload-escena — overlay global de FPS |

Corridas con cualquier argumento de línea de comandos usan
`user://savegame_test.json`/`user://settings_test.json` en vez de los
archivos reales — no ensucian el progreso/preferencias de quien juega el
build exportado sin argumentos.

**`config/name` = `"TowerDefense3D"`** — a propósito distinto de
`"TowerDefense"` (el `config/name` de `/game/`). Godot deriva la carpeta
`user://` del `config/name`; si coincidiera, este proyecto leería/
escribiría el mismo guardado que `/game/`.

## Mapa de escenas / flujo

`run/main_scene` = `MainMenu.tscn`.

- **Start** → `Level.tscn` — la pantalla de juego real.
- **Talentos** → `TalentTree.tscn`.
- **Prueba de Estrés** → `StressMenu.tscn` → `Level.tscn` (vía
  `StressLaunchConfig`, con un preset de población).
- **Configuración** → `ConfigMenu.tscn` — checkbox "Mostrar FPS".
- **Exit** / **Tabula Rasa** — quit / borra `SaveManager.state` (sin
  confirmación, a propósito).

## Flags de CLI (`-- flag` / `-- flag=valor`, heredados de `/game/`)

- `tabula-rasa` — equivalente headless del botón.
- `set-level=<n>` — fuerza `player_level` (prueba de persistencia).
- `show-fps=0`/`show-fps=1` — fuerza el overlay sin pasar por Configuración.
- `screenshot-quit` — captura la pantalla actual y cierra.
- `auto-start` / `auto-talents` / `auto-stress` / `auto-config` — navega
  automáticamente desde `MainMenu.tscn` (verificación sin mouse).
- `stage=<n>` — fuerza el nivel a cargar (0-4), sin persistir.
- `real-stats` — usa rango/cadencia reales de cada torre (sin esto, las
  torres alcanzan cualquier punto del nivel — útil solo para "¿dispara o
  no?").
- `stress-test stress-towers=<n> stress-enemies=<n>` — población forzada,
  mismo camino de render real que jugar.
- `place-all-towers` / `place-types=<csv>` / `start-round` /
  `force-finish-round` — coloca torres y avanza la ronda sin mouse.
- `quit-after=<segundos>` / `no-screenshot=1` — control de duración/captura
  para verificación automatizada.

## Deuda conocida

Resumen de una línea, detalle completo en `docs/versionado.md`: sin
rotación por instancia (torres/enemigos/proyectiles no se orientan), sin
VFX reales todavía, presupuesto de performance por encima del budget en el
escenario oficial ×1,2 (aceptado con gatillo, no bloqueante hoy), talentos
sin efecto en combate, calibración de combate sin hacer.
