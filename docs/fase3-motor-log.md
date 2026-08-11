# Fase 3 — hallazgos e implementación de Mesa de Developers

**Rol:** Mesa de Developers (Motor).
**Empieza:** 09-ago-2026.
**Qué es este documento:** mismo criterio que `fase2-benchmark-conjunto.md`
en Fase 2 — el lugar donde Motor deja escritos hallazgos/implementación de
Fase 3 en detalle, en vez de acumularlos dentro de `plan-fases.md` (que
tiene alcance restringido, solo Dirección/PM cierran criterios ahí). Cada
tarjeta que Dirección asigna en `plan-fases.md`/`fase3-alcance-v1.md` recibe
acá su sección de implementación; `plan-fases.md` se queda con un puntero
corto.

---

## 0. Revisión de alcance — qué de Fase 3 es de Motor hoy

Pedido explícito: revisar `fase3-alcance-v1.md` + `plan-fases.md` (sección
Fase 3) y evaluar qué tarjetas caen del lado de Motor. `fase3-alcance-v1.md`
sección 6 identifica **tres piezas de motor**, pero no las tres están en el
mismo estado:

| Pieza | Estado | ¿Accionable hoy? |
|---|---|---|
| 1. Máquina de estados colocación/combate | Tarjeta completa escrita (`fase3-tarjeta-estado-ronda-v1.md`), Dirección la eligió como punto de partida explícito | **Sí — implementada y verificada (funcional + visual), sección 1.** |
| 2. Sistema de guardado/carga | Identificada, sin tarjeta | **No — Dirección la pausó explícitamente** ("guardado queda para después", `plan-fases.md`, razón: el árbol de mejoras — lo que más forma le va a dar a qué hay que persistir — todavía no tiene ni boceto). No se toca. |
| 3. 4 niveles de contenido nuevo | Identificada, sin tarjeta, marcada "puede arrancar ahora en paralelo" | **Sí, con un paso intermedio — ver sección 2.** Sin tarjeta que fije el enfoque, así que arranqué por uno solo (geometría es decisión de diseño real, no solo autoría de datos), lo verifiqué, y seguí con los 3 restantes ya con la técnica probada. Los 4 construidos y verificados. |

**Dos piezas más grandes, explícitamente fuera de esto:** el árbol de
mejoras (sección 3 de `fase3-alcance-v1.md`) y la calibración de
combate/progresión (sección 4, punto 4) — el propio documento de alcance
las trata como sub-alcances propios que todavía no se descompusieron en
tarjetas de motor ("lo va a moldear el mismo ciclo corto... no antes"). No
hay nada para Motor ahí todavía, más allá de la máquina de estados que esta
misma sección ya cubre (condición para que esos ciclos cortos tengan con
qué trabajar).

**Resumen de la evaluación pedida:** de las tres piezas identificadas, dos
quedan hechas de punta a punta hoy (máquina de estados y contenido de
niveles) y una está correctamente pausada por Dirección (no la toco) — no
era "la mayoría, si no todas" listas para ejecutar de una, pero terminaron
siéndolo salvo la que el propio proceso del proyecto ya había pausado por
una razón real y explícita.

---

## 1. Máquina de estados colocación/combate — implementado y verificado

Tarjeta: `fase3-tarjeta-estado-ronda-v1.md`, completa (secciones 1-6). Los 5
puntos, tal cual:

### 1.1 Estado `PLACEMENT`/`COMBAT`/`ROUND_COMPLETE`

`level_controller.gd`: `enum RoundState { PLACEMENT, COMBAT, ROUND_COMPLETE }`
(tres estados, no dos — la tarjeta pedía "marcar ronda completa de forma
verificable" como mínimo aceptable, sección 5; un tercer estado explícito es
más barato y más claro que un booleano aparte conviviendo con `COMBAT`).

- **`PLACEMENT`** (default): `_place_tower()` habilitado, spawner apagado.
- **`COMBAT`**: `_place_tower()` deshabilitado, spawner activo hasta agotar
  `LevelDef.wave_enemy_count`.
- **`ROUND_COMPLETE`**: spawner ya agotado y sin activos — estado terminal
  de esta tarjeta, la transición real (¿otra ronda? ¿fin de sesión?) queda
  como TODO explícito, tal como pide la sección 5 de la tarjeta ("pregunta
  abierta para la PM, no la resuelvo acá").

### 1.2 Objetivo de oleada — campo nuevo en `LevelDef`, no constante

La tarjeta dejaba elegir entre "constante o campo nuevo trivial en
`LevelDef`" (sección 2, punto 2). Elegí campo en `LevelDef`
(`wave_enemy_count: int = 10`) en vez de constante en
`level_controller.gd`: cada pantalla futura (4 niveles más, sección 2 de
este documento) va a necesitar su propio número eventualmente, y el costo
de ponerlo en `LevelDef` desde ahora es cero. **10 es un placeholder
funcional, no un número de balance** — explícito en el comentario del
campo, mismo criterio que `fase3-alcance-v1.md` sección 5 (calibración
fuera de alcance).

### 1.3 Botón "Comenzar"

`CanvasLayer` + `Button` construidos por código en `_ready()` (mismo patrón
que el resto de la pantalla — nada de esto tiene `.tscn` con nodos a mano,
todo se arma en `_ready()`), sin estilo, tal como pide la sección 4 de la
tarjeta. Un agregado chico más allá del mínimo: al completarse la ronda, el
mismo botón cambia texto a "Ronda completa" y se deshabilita — es el mismo
nodo, no una pantalla nueva, evita que un jugador real se quede sin ninguna
señal en pantalla (la tarjeta lo deja como no resuelto a propósito, esto no
es la resolución real, solo evita la nada absoluta mientras Fase 4 no
construye la pantalla de resultado real).

**No se crea en `stress-test`.** La tarjeta scopea la máquina de estados a
"modo normal, no stress-test" (sección 1) — `_setup_round_ui()` queda detrás
de `if not _stress_test`, y ese modo tampoco paga el costo de render de un
`CanvasLayer` extra. Coherente con cuánto esfuerzo este mismo proyecto le
puso a mantener `stress_main.gd`/`Level1.tscn` en modo estrés libres de
costo incidental (`fase2-benchmark-conjunto.md`, Causa 1 y 2).

### 1.4 `_find_nearest_enemy()`/hash — sin tocar

Punto 3 de la tarjeta revisada anterior (BEAM/RAIL) tampoco es parte de
esta tarjeta — no se tocó nada de `tower_system.gd` en este trabajo.

### 1.5 CLI/headless — flag `start-round`

Equivalente al click real, mismo criterio que ya usa el resto de esta
pantalla para poder probar sin mouse (`place-test-towers`,
`sprite-test=...`). Se procesa en la **segunda pasada** de
`_parse_cli_args()` (la de acciones en orden de línea de comandos, no la de
settings order-independent) — a propósito: colocar torres después de
`start-round` en la invocación debe rechazarse, igual que le pasaría a un
jugador real que ya apretó el botón. Verificado explícitamente, ver 1.6.

### 1.6 Verificación

Regresión estándar de siempre + los 4 casos que pide la sección 6 de la
tarjeta, todos headless (`--path game --headless -- <args>`):

| Caso | Args | Resultado |
|---|---|---|
| A — regresión estándar, sin `start-round` | `place-all-towers real-stats quit-after=8` | `torres:8, proyectiles:5, enemigos:0, muertes:0, leaks:0, estado:PLACEMENT` |
| B — regresión estándar, con `start-round` | `place-all-towers real-stats start-round quit-after=8` | `torres:8, proyectiles:3, enemigos:5, muertes:2, leaks:0, estado:COMBAT` |
| C — caso nuevo de la tarjeta: 0 torres | `real-stats start-round quit-after=35` | `[ronda completa — objetivo:10, muertes:0, leaks:10]` → `torres:0, proyectiles:0, enemigos:0, muertes:0, leaks:10, estado:ROUND_COMPLETE` |
| D — orden invertido (placement después de start-round, rechazado) | `start-round place-all-towers real-stats quit-after=3` | `torres:0` (las 8 colocaciones fueron rechazadas), `estado:COMBAT` |
| E — sanity de `stress-test` sin tocar | `stress-test stress-towers=8 stress-enemies=50 quit-after=3` | `torres:8, proyectiles:45, enemigos:50` — idéntico al comportamiento pre-tarjeta, la máquina de estados no interviene |

Caso C es exactamente la verificación que pide la sección 6 de la tarjeta
("colocar 0 torres, apretar Comenzar, confirmar que el spawner arranca y
que llegar al objetivo de oleada deja el estado marcado como completo, sin
errores") — pasa limpio.

**Nota sobre el baseline histórico de regresión.** Desde Fase 2,
`place-all-towers real-stats quit-after=8` (sin más flags) era el chequeo
estándar y daba `muertes:2, leaks:0` porque el spawner corría sin gate. Con
esta tarjeta, ese mismo comando ahora da `muertes:0` (caso A arriba) — **no
es una regresión, es el gate funcionando**: sin `start-round`, no hay
spawner, no hay enemigos, no hay muertes. El baseline equivalente de acá en
más es el caso B (con `start-round`), que sí reproduce los números
históricos dentro del margen esperado de jitter. Dejo los dos casos en la
tabla para que quien vuelva a correr esta regresión no lea el caso A como
un bug.

### 1.7 Lo que esta tarjeta no resuelve (a propósito, sección 5 de la tarjeta)

Transición post-`ROUND_COMPLETE`, condición de derrota, economía/gasto de
puntos — sin tocar, tal como la tarjeta pedía dejarlos. `ROUND_COMPLETE` es
un estado terminal real hoy: no hay forma de volver a `PLACEMENT` todavía.

### 1.8 Verificación visual — hecha, usuario libre

Postergada mientras el usuario jugaba (ver historial), retomada apenas
avisó que ya podía correr ventanas. Tres corridas cortas en ventana
(Vulkan real, `--path game -- ...`), una por estado, capturadas con el
mecanismo de screenshot existente (`_maybe_screenshot()`):

| Estado | Args | Captura |
|---|---|---|
| `PLACEMENT` | `place-all-towers real-stats quit-after=7` | `level1_screenshot_placement.png` — botón "Comenzar" visible arriba a la izquierda, 8 torres colocadas, un par de disparos de los tipos sin targeting ya en vuelo. |
| `COMBAT` | `place-all-towers real-stats start-round quit-after=7` | `level1_screenshot_combat.png` — botón oculto, enemigos (cuadrados rojos) ya spawneando en el carril. |
| `ROUND_COMPLETE` | `real-stats start-round quit-after=32` | `level1_screenshot_round_complete.png` — botón relabeleado "Ronda completa" y deshabilitado (texto atenuado), carril vacío (los 10 objetivo ya leakearon, 0 torres colocadas en esta corrida). |

Las tres coinciden exactamente con lo que predecía la verificación
funcional de 1.6 — sin sorpresas, ningún ajuste de código hizo falta
después de mirarlas. El botón no tapa ni la zona construible ni el carril
en ninguno de los tres estados. Con esto, la tarjeta
`fase3-tarjeta-estado-ronda-v1.md` queda verificada de punta a punta
(funcional + visual), no solo funcional.

---

## 2. Contenido de niveles — los 4 nuevos, construidos y verificados

`fase3-alcance-v1.md` sección 6, punto 3: 4 niveles nuevos
(`planeta rocoso/desértico`, `luna/jungla alienígena`, `gigante gaseoso`,
`estrella`), reusando `LevelDef` tal cual quedó de Fase 2. El formato
soporta esto sin cambios (`background_texture`/`background_color` ya
estaban, `wave_enemy_count` de la sección 1 cubre el objetivo de oleada —
los 4 usan el default de 10, ningún nivel pidió un número distinto todavía,
son placeholders, no calibración).

**Por qué esto es más una decisión de diseño que autoría mecánica de
datos**, y por qué en la primera pasada arranqué por uno solo antes de
seguir: a diferencia de `level_01.tres` (tuvo una captura de referencia
real que replicar), estos 4 solo tenían dirección de paleta/mood
(`diseno-grafico.md` sección 2) — la geometría del carril es invención
original en los cinco casos. Terminado el nivel 2 y verificado sin
sorpresas, seguí con los otros 3 en el mismo movimiento — el usuario pidió
continuar, y para entonces la técnica ya estaba probada.

**Un bug real encontrado y corregido en el camino, no solo en teoría.** El
primer intento de nivel 2 (5 rects finos: 3 bandas + 2 codos angostos)
tenía un hueco real sin cubrir — visible como una franja del color de fondo
cortando el carril verde en la primera captura. Causa: dos bandas no
consecutivas (banda 1 y banda 3) compartían el mismo rango de X, pero el
codo que las conecta solo cubría una ventana angosta de ese rango — fuera
de esa ventana, ninguna de las dos piezas llegaba a cubrir el salto en Y
entre ellas. La regla que terminé aplicando en los cinco niveles: cuando
dos tramos comparten rango de X, **el conector tiene que cubrir exactamente
esa zona de solape completa**, o los tramos deben quedar cada uno a un lado
distinto del conector (nunca los dos "compitiendo" por el mismo rango de X
sin nada que lo puentee). Verifiqué cada nivel a ojo (ventana + captura)
antes de seguir al siguiente — exactamente el mismo criterio de "medir, no
asumir" que el resto de este proyecto.

### 2.1 Los 5 niveles, resumen

| # | Tema | Forma | Rects | Obstáculos | `background_color` |
|---|---|---|---|---|---|
| 1 | Luna helada (Fase 2) | L simple | 2 | 13 | verde-gris oscuro (sin cambios) |
| 2 | Planeta rocoso/desértico | Z compacta (arriba-izq → abajo-der) | 3 | 13 | ocre-marrón |
| 3 | Luna/jungla alienígena | Z espejada, más angosta (arriba-der → abajo-izq) | 3 | 15 (más densa, "maleza") | violeta-índigo oscuro |
| 4 | Gigante gaseoso | banda ancha y abierta + caída corta | 2 | 9 (más dispersa, "plataforma abierta") | azul-gris tormentoso |
| 5 | Estrella (clímax) | gauntlet largo y angosto, casi directo | 2 | 11 | rojo ember oscuro |

Cada uno usa una forma estructuralmente distinta (no son el mismo molde
repintado) — nivel 4 y 5 se mantuvieron deliberadamente más simples (2
rects, menos giros) porque su tema pedía "abierto"/"directo" en vez de
"laberíntico", lo que además los hizo más baratos de verificar sin riesgo
de repetir el bug de arriba.

### 2.2 Verificación

Cada nivel: `LEVEL_DEF` de `level_controller.gd` apuntado temporalmente al
`.tres` nuevo, corrida en ventana (`--path game -- real-stats quit-after=7`,
sin torres, solo para mirar la geometría), captura revisada, revertido a
`level_01.tres` antes de pasar al siguiente. Capturas:
`level2_screenshot_layout.png` .. `level5_screenshot_layout.png` en
`game/benchmark_results/`. Las cinco confirman: carril continuo sin huecos,
zona construible sin superponerse al carril, spawn/meta dentro de sus
rects, paleta distinta de las otras cuatro a simple vista.

**Cobertura de torres — varía por nivel, a propósito no emparejada.** Igual
que nivel 1 (donde ya era sabido que no toda la base entra en rango, ver
`plan-fases.md`), los niveles 2-3 dejan la mitad del carril lejos de la
zona construible; el nivel 5 en cambio deja casi todo el tramo final bien
cubierto (zona construible pegada al último tramo) — no emparejé esto a
propósito, es geometría nueva sin calibrar, cada caso es una variación
razonable dentro de lo que Fase 2 ya estableció como aceptable, no algo que
necesite arreglarse ahora.

### 2.3 Qué falta para que esto sea jugable, no solo datos correctos

Ningún nivel nuevo está conectado a nada — no existe selector de pantallas
(`fase3-alcance-v1.md` lo deja explícito: eso no se descompuso en tarea de
motor todavía) — `level_01.tres` sigue siendo el único `LEVEL_DEF` que
`Level1.tscn`/`project.godot` cargan. Los 4 nuevos existen como recursos
verificados, listos para que un sistema de selección los use apenas se
construya. No inventé ese sistema acá — no era parte de esta pieza.

---

## 3. Guardado/carga — no evaluado en profundidad, confirmado pausado

Dirección ya lo pausó explícitamente en `plan-fases.md` ("guardado queda
para después... se retoma cuando el árbol [de mejoras] tenga aunque sea una
forma preliminar"). No hay tarjeta, no hay pieza de motor que evaluar
todavía — lo dejo anotado acá solo para que quede registrado como
"revisado, correctamente fuera de alcance hoy", no como un olvido.

**Actualización, 10-ago:** el árbol de mejoras (sección 3 de
`fase3-alcance-v1.md`) ya tiene un frame funcionando — ver sección 5.

**Actualización, 10-ago (más tarde):** el usuario pidió el sistema de
guardado directamente, sin esperar una reapertura formal en
`plan-fases.md` — implementado y verificado, ver sección 6
(`fase3-guardado-motor.md`). Ya no queda nada pausado de las 3 piezas de
motor originales de `fase3-alcance-v1.md` sección 6.

---

## 5. Árbol de talentos — frame implementado

Pedido directo del usuario (10-ago), no una tarjeta de `plan-fases.md`:
mecanismo de árbol de talentos estilo PoE funcionando de punta a punta
(datos, render, desbloqueo con gating por prerequisito/costo) —
deliberadamente sin conectar a combate ni a economía real todavía, eso
queda para la próxima interacción. Detalle completo, dos bugs reales
encontrados y corregidos (registro de `class_name` en corridas headless,
overlap de nodos a la densidad real de 31 nodos) y tabla de verificación en
`fase3-talentos-motor.md`.

---

## 4. Revisión del commit `f0cfa56` (pantalla de inicio + botones de test)

Tarjeta que debía llegar a Mesa de Developers llegó al Auditor por error, y
la ejecutó (`MainMenu.tscn`/`main_menu_controller.gd`, dos botones nuevos
en `Level1.tscn` — "TEST: Finalizar ronda" y "Salir al menú"). Pedido del
usuario: revisar el resultado, con voz final acá — corrijo lo que haga
falta.

**Veredicto: el diseño y la lógica están bien. Encontré y corregí un bug
visual real, y corregí un diagnóstico de la verificación original que
estaba mal — ninguno de los dos invalida el trabajo, los dos eran
verificables y no se habían verificado del todo.**

### 4.1 Lo que estaba bien

- `main_menu_controller.gd`: título + Start (carga `Level1.tscn`) + Exit
  (`get_tree().quit()`), mismo criterio "funcional, sin estilo" que el
  resto de la UI del proyecto. Layout centrado en el viewport (1280×720).
- `_force_finish_round()`: transición de estado correcta (PLACEMENT→COMBAT
  si hacía falta, guard contra doble-click/ROUND_COMPLETE), reusa
  `_complete_round()` sin duplicar lógica, el drenado de activos
  (`while active_count > 0: release(0)`) usa el mismo primitivo de
  swap-remove que ya prueba el resto del proyecto — no encontré nada mal
  acá, y ahora está corrido de verdad (sección 4.3), no solo leído.
- `_exit_to_menu()`: una línea, sin guardado (correcto, sigue pausado),
  transición limpia — confirmado con una corrida real.

### 4.2 Bug real encontrado: el botón de test desbordaba su propio ancho

El commit dice "Level1 renderiza los 3 botones correctamente apilados...
sin superponerse". Con una captura real (windowed, ver
`level1_screenshot_3buttons_fixed.png` de esta revisión) el texto "TEST: Finalizar
ronda" excedía el borde derecho del botón — 21 caracteres a fuente default
no entran en 160px (el mismo ancho que "Comenzar"/"Salir al menú", que sí
entran, son más cortos). Corregido con `add_theme_font_size_override
("font_size", 12)` en vez de agrandar el botón — agrandarlo a 220px (mi
primer intento) tapaba el punto de spawn del carril, achicar la fuente no.
Reverificado con captura nueva: texto adentro del botón, sin invadir nada.

### 4.3 Diagnóstico corregido: el "cuelgue" de headless no era del entorno

El commit dice, sobre `quit-after` en headless: "se cuelga de forma
reproducible en este entorno de ejecución — confirmado que no es un bug
del cambio, el mismo cuelgue aparece con stress-test (código viejo, ya
verificado antes)". **Esto no es correcto, y lo verifiqué de forma
directa:**

| Corrida | Resultado |
|---|---|
| `stress-test ...` headless, **sin** ruta de escena explícita | Cuelga — corre hasta el límite del `timeout` externo, sin ningún log de `[level1]` |
| La misma corrida, con `res://scenes/Level1.tscn` explícito | Sale limpia en ~3s, log normal |
| `place-all-towers real-stats start-round quit-after=8`, sin ruta explícita | Cuelga (mismo patrón) |
| La misma corrida, con `res://scenes/Level1.tscn` explícito | Sale limpia en ~8s, números idénticos al baseline de siempre |

**Causa real:** este mismo commit cambió `project.godot`
(`run/main_scene` de `Level1.tscn` a `MainMenu.tscn` — pedido explícito del
usuario, correcto en sí mismo, no lo revierto). Cualquier invocación
headless que no especifique una escena carga `MainMenu.tscn` por default
— y `main_menu_controller.gd` no leía ningún argumento de línea de
comandos ni llamaba `get_tree().quit()` en ningún caso salvo el click de
"Exit" (que en headless nunca llega). El proceso no se cuelga por el
entorno ni por nada viejo del `stress-test` — corre para siempre porque la
escena que cargó no tiene ninguna condición de salida. La comparación con
"stress-test, código viejo, ya verificado" no aplica: ese código nunca
dejó de funcionar, solo dejó de ser la escena que carga por default.

**Consecuencia real, no cosmética:** por este diagnóstico, no se corrió
ninguna verificación headless de los botones nuevos — el commit lo dice
explícito ("no se probó el click real... verificada por revisión de
código, no por click real"). Los agregué y corrí:

- `force-finish-round` (equivalente CLI del botón de test) y
  `auto-exit-to-menu` en `level_controller.gd`.
- `auto-start` y `screenshot-quit` en `main_menu_controller.gd`.

Con estos, corrí — todos con ruta de escena explícita:

| Caso | Resultado |
|---|---|
| `force-finish-round` desde `PLACEMENT`, sin `start-round` | Ronda se completa al toque, `estado:ROUND_COMPLETE`, sin activos, sin errores |
| `MainMenu.tscn -- auto-start quit-after=3` | Carga `Level1.tscn` correctamente (con el trigger deferido a un frame después de `_ready()` — sin deferir, `change_scene_to_file()` tira "Parent node is busy", artefacto de mi propio gancho de prueba llamándolo síncrono desde `_ready()`, no algo que un click real dispare) |
| `Level1.tscn -- auto-exit-to-menu screenshot-quit` | Vuelve a `MainMenu.tscn`, la pantalla renderiza título+Start+Exit sin errores |
| `MainMenu.tscn -- auto-start place-all-towers real-stats start-round quit-after=6` | Flujo completo jugador real: menú→Start→Level1→torres→ronda, números normales |

Todo pasa. La lógica de los botones nuevos era correcta desde el commit
original — lo que faltaba era la corrida real que la probara, no un
arreglo de código (salvo el bug de la sección 4.2).

### 4.4 Nota operativa, de acá en más

`run/main_scene` es `MainMenu.tscn`. Cualquier invocación headless/CLI de
`Level1.tscn` (regresión, benchmarks, tests de nivel) necesita la ruta
explícita: `--path game res://scenes/Level1.tscn -- <args>` — sin eso,
carga el menú y no hay nada que la cierre. Los comandos de las secciones 1
y 2 de este documento, escritos antes de este cambio, ya no alcanzan
copiados tal cual — quedan correctos en contenido, no en la invocación
exacta.

---

## 6. Sistema de guardado — implementado y verificado

Pedido directo del usuario (10-ago), tercera y última pieza de motor de
`fase3-alcance-v1.md` sección 6: `SaveManager` (autoload, JSON en
`user://`) guarda oro (única moneda, +10 placeholder por ronda), bajas
totales acumuladas, nivel de jugador (persistido, sin mecánica que lo
mueva todavía) y qué nodos del árbol de talentos están desbloqueados —
más botón "Tabula Rasa" en `MainMenu.tscn`, sin explicación en la UI,
pedido explícito. El oro del árbol de talentos dejó de ser un contador en
memoria (`fase3-talentos-motor.md`) y pasó a ser el oro real guardado —
una partida nueva empieza en 0 y no puede desbloquear nada hasta jugar una
ronda, verificado como comportamiento correcto, no bug. Detalle completo,
tabla de verificación (persistencia entre procesos, Tabula Rasa borrando
de verdad, separación de save real vs. de prueba) en
`fase3-guardado-motor.md`.

---

## 7. Hacer el juego ganable — derrota + encadenado

Tarjeta de Dirección (`docs/fase3-tarjeta-ganable-v1.md`, commit
`e9740ed`), pedido del usuario: revisarla y proceder. `RoundState.ROUND_LOST`
nuevo (vidas placeholder, `_max_lives=20`, resetea por ronda, delta de
`leaked_count` sin tocar `LaneEnemySystem`, sin oro al perder) +
`SaveManager.state["stage_index"]` (0-4, deliberadamente distinto de
`player_level`) para que `level_controller.gd` cargue el `LevelDef` que
corresponda en vez del `preload()` fijo de siempre — ganar avanza y
encadena al siguiente nivel (o vuelve a `MainMenu` en el último), perder
reintenta el mismo. Bug real encontrado y corregido en el camino: el guard
de "TEST: Finalizar ronda" solo chequeaba `ROUND_COMPLETE`, dejaba pisar
una derrota ya disparada. Verificado de punta a punta — incluida una
corrida que completa los 5 niveles en secuencia sin jugar ninguno de
verdad y confirma que `stage_index`/oro terminan exactamente donde
corresponde. Detalle completo, tabla de verificación y una nota sobre un
artefacto de prueba (no del juego) en `fase3-ganable-motor.md`.

---

## 8. Dirección fija de disparo — izquierda por default, no el punto más cercano del carril

Pedido del usuario (10-ago): "las torretas no se bien a donde apuntan,
algunas si apuntan horizontal a la izquierda, pero otras (la mayoria)
apuntan al centro de la pantalla". Causa: `_place_tower()` (y el equivalente
en `stress_main.gd::_fixed_dir_for()`) calculaba `fixed_dir` como la
dirección hacia `LevelDef.nearest_point_on_path(pos)` — el punto más
cercano del carril, no necesariamente hacia la izquierda. Con carriles en
L/Z (los 5 niveles de la sección 2), la mayoría de las torres de la zona
construible termina con el punto más cercano en una esquina del recorrido,
no en un tramo recto a su misma altura — de ahí que la mayoría pareciera
apuntar "al centro" en vez de a un lugar predecible.

**Corregido tal como pidió el usuario: `Vector2.LEFT` fijo, sin cálculo.**
Aplicado en los dos call sites (`level_controller.gd` y `stress_main.gd`,
que ya documentaba replicar el mismo criterio para no invalidar los
números de fps medidos con `mode=joint`). `LevelDef.nearest_point_on_path()`
queda sin llamarse desde ninguno de los dos, pero no se borra — sigue
siendo un helper de geometría válido por si hace falta para otra cosa.
Regresión estándar de `Level1.tscn` y `mode=joint` de `stress_main.gd`
verificadas sin cambios en los números (torres/proyectiles/enemigos
idénticos al baseline) — el cambio es de dirección, no de cantidad.
Verificado a ojo con una captura nueva: proyectiles de los tipos sin
targeting viajando hacia la izquierda de forma consistente.

---

## 9. Barrido de resolución con texturas reales — el motor no es GPU-bound acá

Pedido del usuario (10-ago): "fijate dentro del stress test que resolucion
soporta el motor, con texturas reales (no importa si la textura no
matchea, hace lo que puedas con las texturas que hay)".

**Método:** población realista-a-pesada constante (`stress-test
stress-towers=100 stress-enemies=2400 real-stats stress-fire-rate=0.03` —
el mismo punto de control de la sección 16 de `fase2-benchmark-conjunto.md`,
piso ya conocido ~58.5fps sin texturas) + `stress-textures=1` (torres,
enemigos y fondo con las texturas reales que ya usaba
`_enable_stress_textures()` desde Fase 2 — `torreta_recta_v2.png`,
`characters.png`, `torreta_recta_v3_small.png` tileada; ninguna es el arte
"correcto" para lo que pinta, tal como el pedido permitía explícitamente),
`--resolution <W>x<H>` (flag nativo del motor) barrida de 720p a 8K,
ventana real (Vulkan), `quit-after=20`.

**Primera corrida — con el mecanismo de captura de pantalla activo — daba
un patrón sospechoso: piso cayendo de 48.6fps (720p) a 38.6fps (8K) con el
promedio prácticamente plano (~65-68fps en las cuatro).** Ya conocía ese
patrón — es la firma de "Causa 1" (`fase2-benchmark-conjunto.md`): una
lectura síncrona de GPU puntual, no costo sostenido de juego. Acá tiene
sentido que empeore con la resolución (leer un framebuffer más grande
cuesta más), cosa que Causa 1 nunca necesitó explicar porque ahí la
resolución era siempre la misma. `level_controller.gd` no tenía el flag
`no-screenshot=1` que sí tiene `stress_main.gd` para esto — lo agregué
(mismo nombre, mismo criterio) y repetí el barrido.

**Con la captura descartada, el piso queda estable en las cinco
resoluciones:**

| Resolución | Píxeles | Piso | Promedio | Muestras bajo 60 |
|---|---|---|---|---|
| 1280×720 | 0.9M | 60.7fps | 69.2fps | 0/90 |
| 1920×1080 | 2.1M | 57.3fps | 67.6fps | 1/88 |
| 2560×1440 | 3.7M | 58.8fps | 67.5fps | 1/88 |
| 3840×2160 (4K) | 8.3M | 56.9fps | 67.4fps | 1/88 |
| 7680×4320 (8K) | 33.2M | 54.8fps | 68.7fps | 1/90 |

**Conclusión: para esta arquitectura de render (`MultiMeshInstance2D` por
`type_id`, quads chicos de 18-26px), el motor no es GPU-bound por
resolución — es CPU-bound por simulación, y eso no cambia con los píxeles
en pantalla.** De 720p a 8K (×36 en cantidad de píxeles) el piso se mueve
~6fps sin tendencia monótona clara (1440p midió más alto que 1080p) —
del mismo orden que el jitter de medición que ya se documentó en otras
secciones de este proyecto, no una degradación real por fill-rate. Para
comparar la magnitud: el cambio de backend GDScript→nativo por sí solo
movió el piso 40+fps a población moderada (`fase2-benchmark-conjunto.md`
sección 13) — la resolución, en este barrido, no se le acerca ni de
lejos.

**Respuesta directa a la pregunta:** el motor sostiene el pico realista
completo (100 torres, ~2.400 enemigos, ~850-900 proyectiles, texturas
reales en los 3 grupos) sin caída medible de piso hasta 8K — no encontré
un techo de resolución dentro de lo que un monitor real hoy ofrece. No
sé si un fill-rate real aparecería con quads más grandes o materiales más
caros (blend/transparencia, shaders); esto mide la arquitectura actual, no
descarta que resolución importe con otro tipo de contenido.
