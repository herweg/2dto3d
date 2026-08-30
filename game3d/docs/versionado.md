# Versionado — decisiones y dificultades sobrellevadas

**Origen:** `/game3d/` nace por `docs/towerdefense_3d_manifiesto.md`, migrando
el subconjunto 3D de `/game/` (repo raíz, historial completo en
`git log`/`docs/`). Este documento no es un changelog de esa migración en
sí — es la memoria de las decisiones y dificultades reales que se
sobrellevaron para llegar al estado actual del código, filtrada a lo que
sigue siendo relevante **después** de la depuración (sin la parte 2D del
historial: pipeline de sprites, benchmark de GPUParticles2D, barrido de
resolución, bug de orientación de `EntityRenderSync` 2D, etc. — esas
dificultades no aplican a lo que quedó). Cada sección cierra con una cita a
la fuente original (documento + commit) por si hace falta el contexto
completo y todavía se tiene acceso al repo raíz.

## 1. Arquitectura base — simulación SoA + hash espacial

Desde el primer documento técnico de este proyecto la simulación se separó
del render: stores de arrays paralelos (`EntityStore` y las subclases
`EnemyStore`/`ProjectileStore`/`TowerStore`, free-list + swap-remove en vez
de esconder/mostrar nodos) más un `SpatialHash` reconstruido cada tick para
las consultas de vecindad. Esa costura resultó ser exactamente lo que hizo
posible el pivot a 3D después sin tocar una sola línea de simulación: todo
`sim/` trabaja en `Vector2` puro, sin ninguna noción de cómo se dibuja
nada. El único punto de contacto con el render es un `sync(positions,
type_ids, count)` explícito, al final de cada frame — se confirmó esto
como un hecho ya dado (no una migración) antes de decidirse el pivot en sí.

*Fuente: directorsuggestions.md, exploracion-3d.md.*

## 2. Hot path en Rust

`SimHotPath` (`rust/`) resuelve la búsqueda de colisión de los tipos de
proyectil que "viajan" (recto/homing/perforante/splash) — el resto de la
simulación (movimiento, tipos de área/misil, stores, sync de render) se
queda en GDScript. No muta ningún store — recibe posiciones ya
actualizadas y devuelve pares de colisión, una sola llamada por frame.
`ClassDB.class_exists("SimHotPath")` gatea cada call site: sin el
`.dll` compilado, el juego sigue andando en un camino GDScript puro más
lento, no se rompe.

Fricción de build real, específica de esta máquina de desarrollo (puede no
aplicar en otra): **Windows Smart App Control bloquea binarios sin firma
reconocida**, lo que descartó MinGW/GCC como toolchain — la ruta que sí
funciona es Rust vía `rustup` (`stable-msvc`, el default en Windows) más
Visual Studio Build Tools (workload "Desktop development with C++", firmado
por Microsoft). Instrucciones completas y comandos de `winget` reproducibles
quedaron documentados aparte (ver README.md de este proyecto).

*Fuente: rust-build.md; el objetivo de escala que motivó escribir esto en
Rust en primer lugar, sprint-02.md.*

## 3. POC de pivot a 3D — pipeline y hallazgos de formato

Pipeline de arte: GPT (imagen 2D) → Meshy (imagen-a-3D + rig) → post-proceso
Blender. **GLB** se eligió como formato porque es el único importador de
primera clase en Godot 4 (mallas + skin + animación + materiales en un solo
archivo) — FBX quedó como plan B, USDZ se descartó (Godot no lo importa, es
formato de AR de Apple).

**Bug de escala real, confirmado en los assets recibidos:** el bounding box
de la malla del monstruo llegaba ~170 unidades de alto en vez de ~1,7 — un
"bug de fábrica ×100" del pipeline de origen que nunca se corrigió ahí, se
compensa en cada consumidor con un `scale_fix=0.01` (ver sección 6, y
`MONSTER_SCALE_FIX` en `sim/level_controller.gd`). **No es un parche a
repetir por asset nuevo que llegue — hay que mirarlo en el pipeline de
origen si se retoma ese flujo de generación.**

Comparación a poly-count igual (~103k) entre dos variantes generadas
(`meshy-5` vs `meshy-7`): `meshy-7` se veía más apagado/grisáceo, confirmado
dos veces, con 4× el costo en tokens — perdió la comparación, `meshy-5` es
la que migró. Animación (rig biped, 24 huesos, clip único) confirmada
funcionando de punta a punta bajo cámara ortogonal fija.

*Fuente: pivot-3d-poc-v1.md sección 1.*

## 4. Cierre del gap de escala — esqueletos compartidos

`MultiMeshInstance3D` bachea automáticamente geometría idéntica sin
animación a un solo draw call (confirmado con torres y proyectiles) — pero
**no anima huesos por-instancia**, así que no sirve para enemigos rigueados.
Con animación independiente por instancia, el escenario oficial (120
torres + 2.400 enemigos + 4.320 proyectiles, el mismo ×1,2 de margen que
este proyecto siempre exigió) daba **18,53ms**, por encima del budget de
16,6ms — no porque animar en sí sea caro, sino porque 2.400 instancias
completas de escena (`Armature`/`Skeleton3D`/`AnimationPlayer` propios, ~26
nodos cada una, ~62.000 nodos vivos en el árbol) ya costaban antes de
calcular una sola pose.

La técnica que cerró el gap: `SharedSkeletonRenderGroup` — un puñado de
`Skeleton3D` "maestros" completos (animando a fases repartidas) más el
resto como `MeshInstance3D` livianos (mismo mesh/skin del maestro) cuyo
`skeleton` (`NodePath`) apunta a uno de los maestros por round-robin. La
pose se comparte, la posición no. Con 10 maestros: **7,14ms** — mejor
incluso que el "techo sin animar" (13,33ms), confirmando que la mayor parte
del ahorro no era el cálculo de animación en sí, sino dejar de mantener
~62.000 nodos vivos. Draw calls sin cambio en las tres variantes (2.402) —
confirma que esta técnica ataca la otra mitad del costo, no el bacheo.

*Fuente: pivot-3d-poc-v1.md secciones 3-4.*

## 5. Sorpresa — el costo de mover transforms por frame

Dos huecos quedaban después de cerrar el gap de arriba: los enemigos
posaban quietos (no caminaban) y toda la medición era un solo monstruo
repetido. Al sumar caminata real (mover el `position` de cada instancia
cada frame, no solo animar en el lugar), el escenario oficial completo pasó
de **7,14ms (quieto) a 13,27ms (caminando)** — mover 2.400 transforms costó
**más que toda la ganancia que había dado compartir esqueleto sobre el peor
caso** (18,53→7,14ms redujo 11,4ms; caminar devolvió más de la mitad de
eso). **Hipótesis razonada, nunca confirmada con un profiler real:** cada
asignación de posición en un nodo con render dispara una actualización de
transform+AABB al `RenderingServer`; con 2.400 nodos moviéndose
independientes cada frame, esa sería la porción de costo nueva. Sigue sin
confirmarse — no subir esto a hecho si se retoma el tema.

Variedad de textura real (10 PNG distintos por hue-shift, no un tinte de
shader, repartidos round-robin) no costó nada medible — cada enemigo ya era
su propio draw call de por sí, así que la textura no rompió ningún bacheo
que no estuviera roto ya (a diferencia del hallazgo equivalente del lado
2D, donde sí importaba).

*Fuente: pivot-3d-poc-v1.md sección 5.*

## 6. Puente de render real, integrado al juego — y el hallazgo de escala de mundo

`EntityRenderSync`/`TypedRenderGroup`/`SharedSkeletonRenderGroup`
(`render/`) llevan la técnica de arriba de la POC aislada a la pantalla de
juego real (`Level.tscn`/`sim/level_controller.gd`). Mapeo de coordenadas
fijo, una sola decisión para todo el puente: **X sim → X 3D, Y sim → Z 3D,
altura fija**.

**Dos números de escala distintos, para dos problemas distintos — punto de
confusión real al leer el código en frío:** `scale_fix` (0,01 en
`monster_m5.glb`) corrige el bug de origen ×100 de la sección 3. `WORLD_SCALE`
(20,0, constante separada en `sim/level_controller.gd`) es otra cosa —
compensa que los assets, ya corregidos, siguen en escala "real" (~1-2
unidades) dentro de un mundo medido en unidades de simulación (cientos:
`obstacle_radius`=22, `TOWER_MIN_SPACING`=48). Este segundo problema no
apareció hasta la primera captura real de la pantalla integrada — sin
`WORLD_SCALE`, torres y enemigos eran del tamaño de un píxel, invisibles a
la distancia de cámara del nivel. Calibrado a ojo contra la geometría de
nivel existente, no es un número de diseño de arte.

**El número empeora al integrar con el juego real — reportado, no
escondido:** el escenario oficial (120 torres/2.400 enemigos, cadencia
real) mide ~13ms de render puro en la POC aislada, pero corrido de verdad
contra el resto del juego (simulación completa, hash espacial, UI) el piso
medido fue **~24-25ms**, por encima del budget de 16,6ms. La causa no es un
regresión de la técnica — es que la POC nunca sumó el costo de simulación/
juego real (~13,5ms de piso ya existente en esa misma escala, sin ningún
render 3D todavía) a lo que sí mide render. **Aceptado sin optimizar, con
gatillo explícito:** el escenario real de hoy (24 torres/300 enemigos)
sobra margen (5,3-5,5ms); revisar si el catálogo real de niveles/
progresión se acerca a la escala oficial.

**Deuda conocida, no resuelta:** rotación identidad en todo — torres,
enemigos y proyectiles no se orientan a su dirección de disparo/movimiento;
los materiales de los assets `monster_*` son "emissive-boosted"
(auto-iluminados, ignoran luz real de escena), nunca se confirmó si el
flag de PBR del pipeline de origen se estaba aplicando de verdad.

*Fuente: fase-3d-tarjetas-pantallas-v1.md, fase-3d-motor-log.md.*

## 7. Prueba de estrés integrada al menú real

Antes, medir población alta (torres/enemigos) sólo era posible por flags de
CLI contra una escena de investigación aparte — no alcanzable jugando, y
con el riesgo de terminar midiendo un camino de render distinto al que el
jugador realmente usa (justo lo que pasó con el primer POC, aislado del
resto del juego — ver sección 6). `StressMenu.tscn` cierra ese hueco:
navega al mismo `Level.tscn`/render real con un preset de población
(`StressLaunchConfig`, autoload que pasa el preset a través de
`change_scene_to_file()`, que no lleva argumentos de CLI). Los controles
finos de población siguen existiendo por CLI para diagnóstico
(`stress-towers=`/`stress-enemies=`, etc.) — la pantalla es la versión
usable jugando, no un reemplazo del camino de terminal.

*Fuente: fase-3d-tarjetas-pantallas-v1.md sección 4.*

## 8. Guardado y configuración — por qué son dos autoloads separados

`SaveManager` (progreso de partida: oro, nivel, bajas, talentos
desbloqueados, `stage_index`) y `Settings` (preferencias de UI, hoy solo
`show_fps`) son dos archivos JSON distintos en `user://`, con dos autoloads
distintos — a propósito, no por descuido. El botón "Tabula Rasa" borra el
progreso de partida sin pedir confirmación (pedido explícito: sin ningún
texto que explique qué hace más allá del nombre) — una preferencia de
visualización no debería desaparecer solo porque el jugador reinició su
progreso, son dos cosas conceptualmente distintas. Mismo cuidado de
vocabulario que ya separó `stage_index` (progreso de campaña, qué nivel se
alcanzó) de `player_level` (meta-progresión de slots de torre) dentro del
propio `SaveManager`.

El overlay de FPS (`FpsOverlay.tscn`, autoload-escena — un autoload puede
ser una escena completa, no solo un script, mismo mecanismo que
`StressLaunchConfig`) lee `Settings.state["show_fps"]` cada
`REFRESH_INTERVAL` y aparece en todas las pantallas sin duplicarse a mano
en cada una, porque un autoload vive fuera del árbol de la escena actual y
sobrevive a `change_scene_to_file()`.

*Fuente: fase3-guardado-motor.md (SaveManager); fase-3d-tarjetas-
pantallas-v1.md sección 5 (FpsOverlay/Settings/ConfigMenu).*

## 9. Árbol de talentos — modelo de datos

`TalentTreeDef` (SoA, arrays paralelos — mismo criterio que los stores de
simulación, evita sub-recursos anidados en el `.tres`) describe un árbol
estilo PoE: 31 nodos repartidos en 3 ramas (Ofensiva/Control/Economía),
cada uno con costo, posición, y efecto (global o específico por tipo de
torre). El diseño real se ajustó a las restricciones concretas del esquema
ya construido en vez de al diseño ideal pensado de entrada — el criterio
fue "qué entra en los datos que ya existen", no rediseñar el schema para
acomodar una idea. **A propósito, solo el frame:** el árbol se puede
navegar/desbloquear con oro real (integrado a `SaveManager`), pero
ningún efecto todavía modifica combate — ver sección 10.

*Fuente: fase3-talentos-motor.md.*

## 10. Deuda de diseño heredada

Dos piezas que no son deuda nueva de este proyecto — vienen de antes del
pivot y migran intactas porque nadie las resolvió mientras tanto: (1) los
efectos del árbol de talentos no están conectados a combate — desbloquear
un nodo no cambia ningún número real todavía; (2) la calibración de combate
en sí (vidas, oro por ronda, costo de torres, tamaño de oleada) nunca se
hizo — los números actuales son placeholders funcionales (`GOLD_PER_ROUND`
= 10 arbitrario, `wave_enemy_count` fijo por nivel, vidas sin ajustar),
suficientes para que el loop de juego sea verificable, no para que esté
balanceado.

## 11. Qué no migró y por qué

Ver `docs/towerdefense_3d_manifiesto.md` sección 4 — la lista completa
(POC de investigación, todo lo puramente 2D, el botón/flags de comparación,
assets de prueba nunca commiteados) vive ahí, no se duplica acá para no
tener dos fuentes de verdad. Una desviación de esa lista, decidida durante
la migración misma y documentada para que no se lea como un descuido:
`monster_m7.glb`/`monster_pbr_m5.glb` (~31MB) tampoco migraron, aunque una
lectura literal del manifiesto los incluía — nada de lo que sí migró los
carga (solo los cargaban los scripts de POC que quedaron afuera), así que
traerlos hubiera sido exactamente la "basura residual" que el manifiesto
pide no arrastrar.

## 12. Fuentes

| Tema | Documento(s) en `/docs/` del repo raíz | Commit(s) |
|---|---|---|
| Arquitectura SoA / hash espacial | `directorsuggestions.md` | — |
| Sim 3D-ready desde el día uno | `exploracion-3d.md` | — |
| Hot path Rust — por qué | `sprint-02.md` | `20c9f06` |
| Build del hot path, fricción de esta máquina | `rust-build.md` | — |
| POC 3D — formato/escala/meshy-5 vs meshy-7 | `pivot-3d-poc-v1.md` §1 | `e1fd74f` |
| Esqueletos compartidos — cierre del gap | `pivot-3d-poc-v1.md` §3-4 | `fddb246`, `677967c` |
| Caminata — costo mayor al esperado | `pivot-3d-poc-v1.md` §5 | `8edc42c` |
| Puente de render real + WORLD_SCALE + hallazgo de integración | `fase-3d-tarjetas-pantallas-v1.md`, `fase-3d-motor-log.md` | — |
| Guardado/Settings separados, FpsOverlay | `fase3-guardado-motor.md`, `fase-3d-tarjetas-pantallas-v1.md` §5 | `6576f5c`, `a1a1971` |
| Árbol de talentos | `fase3-talentos-motor.md` | `2e5c119` |

Si `/game3d/` se extrae a un repositorio propio en algún momento, un
`git subtree split`/`git filter-repo` sobre este path (no una copia
estática) preserva el historial que estas citas referencian.
