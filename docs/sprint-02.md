# Sprint 2 — Spike técnico del núcleo de simulación

**Rol:** desarrollador único (PM + Dirección de Desarrollo), con apoyo de Claude
Code para la ruta GDExtension.
**Estado:** Ruta A completa y medida (no alcanza el objetivo — ver Paso 3).
Ruta B aprobada por el director, lenguaje resuelto (Rust). Listo para arrancar
Paso 4 — sin fecha asignada, se retoma a discreción.
**Input congelado:** `docs/definicion-escala-v1.md` (todos los campos cerrados),
`docs/combat-design-v1.md` (T3), `docs/projectile-variety-v1.md` (T5),
`docs/directorsuggestions.md` (arquitectura propuesta).
**Ubicación del código:** `game/sim/`, `game/render/`, `game/data/` (ya creadas
en T8, vacías). El POC en `POC/` no se toca.

---

## Objetivo

Validar — o corregir — con datos medidos, no intuición, si la arquitectura de
`directorsuggestions.md` (SoA + hash espacial propio + buffer único de render)
sostiene el objetivo de escala fijado en T2, en GDScript puro y/o con el hot
path en GDExtension.

## Qué NO es este sprint

- No es el rediseño final del núcleo con contenido real (eso es Fase 2 /
  "Sprint 4+", condicional al resultado de acá).
- No incluye lógica de juego real — armas, oleadas, XP, UI. Caso de prueba
  sintético únicamente.
- No incluye multijugador (T6 ya cerrado: No).
- No incluye `WorkerThreadPool` desde el arranque — solo si las rutas A y B se
  quedan cortas (ver Paso 5).

## Criterios de salida (ya definidos, se repiten acá para no tener que releer 3 documentos)

- **Corte duro: 10 días de trabajo efectivo acumulado**, no de calendario. Si a
  esa altura no hay señal clara, se corta igual y se decide con los datos que
  haya — el spike no se convierte en el proyecto.
- **Objetivo a medir:** ~6.000-8.000 proyectiles simultáneos (pico
  10.000-12.000), ~1.500-2.000 enemigos simultáneos (pico 3.000), a 60fps, en
  el hardware mínimo definido (CPU 4 núcleos, GPU eq. GTX 1660/RX 580, 8GB
  RAM) — no en la máquina de desarrollo si es más potente que eso.
- **Hipótesis a confirmar o corregir:** el director estimó ~15.000 proyectiles
  simples sostenibles en GDScript puro antes de necesitar GDExtension. Es un
  punto de partida a falsear, no un resultado adquirido.
- **Si GDScript puro ya alcanza el objetivo, no se construye GDExtension "por
  las dudas".** Es una apuesta más cara que hay que ganarse con datos.
- **Condición de reapertura de la decisión de motor** (ver
  `definicion-escala-v1.md`): si ni GDExtension de un hilo ni GDExtension +
  `WorkerThreadPool` llegan a ~60% del objetivo, se reabre formalmente la
  pregunta de si Godot sigue siendo el motor correcto.

---

## Pasos, en orden de dependencia

### Paso 0 — Herramienta de medición

Definir cómo se mide fps/frame time de forma reproducible **antes** de escribir
código de simulación — quedó marcado como riesgo abierto en
`auditoria-sprint1.md` sección 04 y no conviene improvisarlo a mitad del spike.
Propuesta: un logger simple que registre, cada N frames, el frame time
(`Performance.get_monitor(Performance.TIME_PROCESS)` o equivalente) junto con
el conteo de entidades activas en ese momento, a archivo o consola — para
poder graficar "entidades vs. frame time" al final y ubicar con precisión
dónde cae de 60fps, no a ojo.

### Paso 1 — Inicializar el proyecto Godot en `game/`

`project.godot` (Godot 4.7, Forward+), sin escenas de gameplay reales — una
escena de benchmark vacía como main scene. Este es el primer trabajo real de
Sprint 2, no de T8 (a propósito — ver nota en `sprint-01.md`, T8).

### Paso 2 — Caso de prueba sintético

Spawner que genera N proyectiles y M enemigos con movimiento simple (sin IA
real, sin lógica de armas/oleadas) para aislar el costo de
simulación+colisión+render del resto del juego. N y M ajustables sin
recompilar, para poder barrer desde 0 hasta el pico objetivo.

### Paso 3 — Ruta A: GDScript puro

- `entity_store.gd` — arrays paralelos (SoA) + free-list con swap-remove, para
  proyectiles y enemigos por separado.
- `spatial_hash.gd` — grilla uniforme reconstruida cada tick sobre posiciones
  de enemigos.
- Batch único de movimiento + colisión (contra la grilla) + aplicación de
  daño, sin señales.
- `entity_render_sync.gd` — un solo `multimesh_set_buffer()` por grupo visual
  y por frame.
- Barrer con el spawner sintético desde 0 hasta el pico objetivo, registrando
  frame time con la herramienta del Paso 0.
- **Resultado esperado:** número concreto — a cuántas entidades cae de 60fps
  en GDScript puro, en el hardware definido.

**Checkpoint intermedio** (interno del spike, no el checkpoint final): si Ruta
A ya sostiene el objetivo completo a 60fps en el hardware definido, el spike
puede cerrarse acá — no se sigue a Ruta B "por las dudas".

#### Resultado — Ruta A (07-ago-2026)

**Medido en la máquina de desarrollo** (i5-9400, 6 núcleos @2.9GHz, AMD Radeon
RX Vega, Vulkan Forward+) — igual o por encima del hardware mínimo definido en
T4, no el hardware mínimo real. Trato estos números como **cota optimista**,
no como el resultado final. Reporte visual completo (curva, capturas,
metodología): ver artifact publicado en esta sesión de trabajo.

- **Movimiento + render, sin colisión:** sostiene el pico completo del
  objetivo — **12.000 proyectiles + 3.000 enemigos simultáneos a ~80 fps**.
  Valida la mitad no-colisión de la arquitectura de `directorsuggestions.md`
  (SoA + free-list + un solo `multimesh_set_buffer()` por frame).
- **Con colisión (hash espacial), Ruta A completa:** cae de 60fps ya en
  **~3.600-3.900 proyectiles / ~1.000 enemigos simultáneos** — muy por debajo
  del objetivo de T2 (~6.000-8.000 proyectiles / ~1.500-2.000 enemigos, pico
  10-12k/3k). Se estabiliza en un plateau de ~42-46fps con la población en
  equilibrio dinámico (~2.800-4.000 proyectiles) cuando los enemigos llegan a
  su pico de 3.000 — no llega a sostener el pico de spawn de proyectiles.
- **El costo dominante es la consulta de colisión al hash espacial, no el
  conteo de entidades en sí** — confirmado desactivando la colisión (arriba)
  y comparando contra la misma corrida con colisión activa a igualdad de
  población. Esto es exactamente el hot path que `directorsuggestions.md`
  proponía mover a GDExtension si Ruta A no alcanzaba.
- Se probaron dos ajustes dentro de Ruta A antes de declarar el techo: reducir
  `cell_size` del hash de 96→24px (alineado a ~2× el radio de impacto de
  10px) y eliminar la asignación de un array nuevo por proyectil por frame
  (consulta inline de 9 celdas en una sola llamada). Ambos ayudaron
  (~15-30% de mejora), pero no cerraron la brecha — rendimientos
  decrecientes, coherente con no perseguir GDScript indefinidamente dentro
  del corte del spike.
- Bug real encontrado y corregido en el caso sintético: los enemigos
  convergían todos al mismo punto exacto donde spawnean los proyectiles (sin
  distancia de "stand-off"), matándolos casi al instante y invalidando la
  medición a poblaciones altas. Se corrigió dándoles un radio de parada
  aleatorio (60-240px) alrededor del ancla — además de arreglar la medición,
  es más representativo del gameplay real (enemigos rodeando al jugador en
  rango de melee, no apilados en un punto).

**Conclusión del checkpoint intermedio: Ruta A (GDScript puro) no alcanza el
objetivo de T2.** Corresponde pasar a Ruta B (Paso 4) — GDExtension acotado
al hot path de colisión + aplicación de daño, tal como preveía el checkpoint
del spike.

**Pendiente de decisión del PM antes de arrancar Ruta B:** C++ (`godot-cpp`)
vs. Rust (`godot-rust`/`gdext`). El Paso 4 pide "repasar lo mínimo
indispensable de bindings antes de comprometerse a uno" — todavía no se
eligió ninguno.

#### Prototipo de toolchain — C++ vs. Rust (07-ago-2026)

Antes de comprometerse a un lenguaje, se armó un binding mínimo de cada uno
(una función que procesa arrays completos entre llamadas, la misma forma de
operación que el hot path real) y se midió la fricción real de cada
toolchain en esta máquina — no en el papel. Código descartable en
`.tools/proto_cpp_ext/` y `.tools/proto_rust/` (no versionado — el resultado
es lo que importa, no el prototipo en sí).

**Hallazgo bloqueante primero:** esta máquina tiene **Smart App Control**
activo (Windows 11), que bloqueó la ejecución del compilador MinGW recién
instalado por no estar firmado/reconocido. Smart App Control, una vez
activo, **no se puede apagar sin reinstalar Windows** — no es una decisión
de proyecto, es una restricción del entorno. Esto descarta MinGW como opción
de C++ en esta máquina y obliga a usar **MSVC** (Visual Studio Build Tools,
firmado por Microsoft) tanto para C++ como para el linker que necesita el
toolchain por default de Rust en Windows. Si el spike se termina corriendo
en otra máquina, vale re-chequear esto — no asumir que aplica igual.

| | C++ (`godot-cpp`) | Rust (`godot-rust`/`gdext`) |
|---|---|---|
| Setup previo necesario | MSVC (Build Tools) + **Python 3** (genera los bindings desde `extension_api.json`, requisito estándar de godot-cpp, no un workaround) | MSVC (Build Tools, solo como linker) + `rustup` |
| Build limpia (primer intento) | **Falló** — generador multi-config de CMake (Visual Studio) hizo que godot-cpp compilara en Debug pese a pedir `--config Release`, y el link final tiró error de runtime library mismatch (Debug vs. Release CRT) tras **18m51s** de compilación | **OK al primer intento** — `cargo build --release`, sin configuración extra más allá de tener el linker de MSVC disponible |
| Build limpia (config corregida) | **4m03s** una vez cambiado a generador Ninja + `CMAKE_BUILD_TYPE=Release` explícito, activando el entorno de MSVC a mano (`vcvars64.bat`) | **3m02s** (sin cambios — la primera corrida ya fue la buena) |
| Tamaño del binario | 164 KB | 3 MB (godot-rust trae más dependencias propias — `glam`, `regex`, etc.) |
| Superficie de la API disponible | Completa — genera bindings para toda la API de Godot desde `extension_api.json` (930 archivos compilados) | Completa — la crate `godot` ya trae los bindings generados, no hace falta generarlos por proyecto |

**Lectura del resultado:** Rust tuvo menos fricción de setup en esta corrida
concreta — compiló bien a la primera, sin que hiciera falta entender el
sistema de build de godot-cpp para diagnosticar un error de configuración.
C++ funciona igual de bien una vez resuelta la configuración correcta, pero
esa configuración correcta no es obvia sin haber tocado CMake +
generadores multi-config antes — es exactamente el tipo de fricción de
integración que `directorsuggestions.md` (sección 2.5, nota del auditor)
pedía medir explícitamente, para no confundir "la técnica no escala" con
"todavía no afinamos el flujo de trabajo con la herramienta". Ninguno de los
dos resultó inviable; la diferencia es de fricción de aprendizaje para un
desarrollador sin experiencia previa en ninguno de los dos, apoyado en
Claude Code — Rust dejó menos margen para un error silencioso de
configuración gracias a su build system más uniforme (`cargo` no tiene el
concepto de generador multi-config que causó el problema en C++).

**Recomendación:** Rust (`godot-rust`/`gdext`), pero es una decisión del PM,
no una que corresponda cerrar en ingeniería sola — ver Paso 4.

> **Director — [RESUELTO 07-ago]: Rust (`godot-rust`/`gdext`).** Con los datos
> de la tabla arriba, no hace falta más deliberación: build limpia al primer
> intento sin tocar generadores de CMake, sin la trampa de Debug/Release CRT
> que se comió 15 de los 19 minutos del primer intento en C++, y superficie de
> API completa igual que `godot-cpp`. El tamaño del binario (3MB vs 164KB) es
> irrelevante a esta escala. El argumento que inclina la balanza, más allá de
> la fricción medida: el hot path que se va a mover a GDExtension procesa
> arrays crudos cruzando el borde FFI — exactamente la clase de código donde
> un error de punteros/lifetimes en C++ es más fácil de introducir sin darse
> cuenta, en especial escribiéndolo con apoyo de Claude Code y sin experiencia
> previa propia en ninguno de los dos lenguajes para revisar con criterio
> curtido. Rust no hace inmune al error, pero el borrow checker recorta esa
> categoría específica de bug justo donde más se necesita acá. Cierra el
> pendiente — Paso 4 arranca en Rust.

### Paso 4 — Ruta B: GDExtension (condicional a que Ruta A no alcance)

- Setup de GDExtension en `game/` en **Rust** (`godot-rust`/`gdext`) — ver
  resolución del director arriba, cierra el pendiente de lenguaje.
- Mover el hot path (colisión + aplicación de daño) a GDExtension — el resto
  (movimiento, sync de render) se queda en GDScript, según el corte que ya
  propuso el director en `directorsuggestions.md`.
- **Cuidado explícito con marshaling** (riesgo ya anotado en
  `definicion-escala-v1.md`): procesar arrays completos entre llamadas al
  motor, no llamar a la API de Godot por entidad — un loop con llamadas
  chicas puede terminar más lento que GDScript.

  > **Director — nota de alcance, 07-ago:** esto implica más que portar
  > `SpatialHash.find_hit()` sola. Tal como está hoy en `spatial_hash.gd`, la
  > grilla vive del lado de GDScript (`Dictionary` de `PackedInt32Array`) y
  > `ProjectileSystem` la consulta una vez por proyectil. Si Ruta B sólo mueve
  > la función de consulta a Rust pero la grilla se sigue construyendo y
  > guardando en GDScript, cada consulta vuelve a cruzar el borde FFI por
  > proyectil — el mismo problema de marshaling que esto busca evitar, solo
  > que ahora también con el costo de conversión `Dictionary`↔Rust en el
  > medio. El corte correcto es: **build de la grilla + el batch completo de
  > colisión y daño, los tres, en una sola llamada nativa por frame**,
  > recibiendo los arrays crudos de posición/salud/daño de ambos stores y
  > devolviendo los índices de impacto (o aplicando el daño directamente del
  > lado de Rust). GDScript le entrega arrays al inicio del frame y recibe un
  > resultado al final — no dialoga con la grilla entidad por entidad. Lo
  > agrego explícito acá porque no estaba dicho en ningún lado todavía y es la
  > diferencia entre que Ruta B efectivamente resuelva el cuello de botella
  > medido en Ruta A o que lo reproduzca con otro nombre.

- Repetir el mismo barrido sintético del Paso 3, mismo objetivo, mismo
  hardware.

### Paso 5 — `WorkerThreadPool` (condicional a que Ruta B tampoco alcance)

Paralelizar el batch de colisión+daño en chunks sobre `WorkerThreadPool`. Es
la palanca que `directorsuggestions.md` marcó "fuera de alcance a propósito"
en su sección 4 — se activa acá porque las dos rutas anteriores no
alcanzaron, no como optimización prematura sin medir.

### Paso 6 — Checkpoint de decisión (cierre del spike)

- ¿Alcanzó el objetivo de T2? ¿En qué ruta (A, B, o B + `WorkerThreadPool`)?
- ¿Se reabre memo Q7 (motor)? — aplicar la condición del ~60% ya definida en
  `definicion-escala-v1.md`.
- Con esto se define el alcance real de Fase 2 (rediseño de núcleo con
  contenido real, congelado contra `combat-design-v1.md` y
  `projectile-variety-v1.md`) — no antes.

---

## Qué se porta de este spike y qué no

- El código de `game/sim/` y `game/render/` de este spike, si funciona, es
  candidato a sobrevivir a Fase 2 — no es descartable por diseño. Pero el
  objetivo acá es medir, no producir código de producción prolijo: está bien
  que tenga logging de debug y el caso sintético hardcodeado. Se limpia recién
  si se decide continuar sobre él.
- `game/data/` (`projectile_defs.tres`, `enemy_defs.tres`) probablemente no
  hace falta poblarlo en el spike — el caso sintético puede generar sus
  propios parámetros en código. Se define en Fase 2, contra
  `combat-design-v1.md` y `projectile-variety-v1.md`.

---

## Corte duro (recordatorio final)

**10 días de trabajo efectivo acumulado.** No calendario. Si a esa altura no
hay señal clara, se corta igual y se decide con los datos que haya.
