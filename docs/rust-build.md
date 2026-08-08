# Build reproducible de `game/rust/` → `game/bin/sim_hotpath.dll`

**Estado:** documentado — 08-ago-2026 (sugerencia del auditor en
`fase2-motor-cristalizado.md`, aceptada por el director). Antes de esto,
`game/rust/target/` existía en el disco de quien lo compiló la primera vez
(Sprint 2) pero no había instrucciones escritas — solo esa persona sabía
reproducirlo.

## Requisitos (una sola vez por máquina)

En esta máquina de desarrollo, **Smart App Control** (Windows 11) está
activo y bloquea binarios sin firma reconocida — MinGW/GCC quedó
descartado por esto durante el spike de Sprint 2 (no es una preferencia,
es una restricción del entorno; en otra máquina sin Smart App Control,
MinGW es una alternativa más liviana). La ruta que sí funciona:

1. **Rust**, vía [rustup](https://rustup.rs/) — toolchain `stable-msvc`
   (el default en Windows). No hace falta nada especial.
2. **Visual Studio Build Tools** (workload "Desktop development with C++" /
   `Microsoft.VisualStudio.Workload.VCTools`) — firmado por Microsoft, pasa
   Smart App Control sin problema. Provee `cl.exe`/`link.exe`, que
   necesita tanto el propio Rust (`stable-msvc` enlaza con `link.exe`) como
   el CMake que trae la misma instalación de VS (no hace falta uno aparte).
3. **Python 3** (build de `godot-cpp` si en algún momento se evalúa la ruta
   C++ — no hace falta para compilar `game/rust/`, que es Rust puro).

Instalación vía `winget` (PowerShell):

```powershell
winget install --id Rustlang.Rustup -e --accept-package-agreements --accept-source-agreements --silent
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --silent --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Verificar después de instalar (con el `PATH` recién actualizado — puede
hacer falta abrir una terminal nueva):

```powershell
rustc --version
cargo --version
```

## Build

```powershell
cd game/rust
cargo build --release
```

Primera vez: ~2-3 minutos (compila `godot-rust`/`gdext` entero — es una
dependencia grande). Builds incrementales (solo cambió `src/lib.rs`): ~1-2
minutos, porque `gdext` sigue siendo la mayor parte del árbol de
dependencias aunque no haya cambiado.

Salida: `game/rust/target/release/sim_hotpath.dll`.

## Instalar el binario compilado

Godot lo busca donde apunta `game/sim_hotpath.gdextension` —
`res://bin/sim_hotpath.dll`. Copiar manualmente después de cada build:

```powershell
Copy-Item game\rust\target\release\sim_hotpath.dll game\bin\sim_hotpath.dll -Force
```

`game/rust/target/` y `game/bin/*.dll` están en `.gitignore` — son
artefactos de build, no se versionan.

## Verificar que Godot lo cargó

Correr cualquier escena headless y revisar la salida — si cargó bien, la
primera línea es del inicializador de `godot-rust`:

```
Initialize godot-rust (API v4.3.stable.official, runtime v4.7.stable.official)
```

Si `game/bin/sim_hotpath.dll` es nuevo (o el proyecto nunca se abrió con
este `.dll` presente), Godot puede necesitar un rescan del proyecto antes
de reconocer la clase `SimHotPath` en GDScript — mismo síntoma y mismo
arreglo que el registro de clases `class_name` nuevas (ver más abajo):

```powershell
.tools\godot\Godot_v4.7-stable_win64_console.exe --path game --headless --editor --quit-after 60
```

## Nota aparte: registro de clases GDScript nuevas

No es específico de Rust, pero aparece junto con este flujo seguido: cada
vez que se agrega un script nuevo con `class_name` (GDScript, no Rust) y se
corre el proyecto por primera vez sin haber pasado por el editor, Godot
tira `Parse Error: Could not find type "X" in la current scope` — el mismo
`--headless --editor --quit-after 60` de arriba fuerza el rescan que arma
`game/.godot/global_script_class_cache.cfg` y lo resuelve. Vale la pena
correrlo por rutina después de agregar cualquier script/clase nueva
(GDScript o `.gdextension`), no solo cuando falla.
