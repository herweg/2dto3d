# Fase 3D — log de Mesa de Developers

**Rol:** Mesa de Developers.
**Origen:** `docs/fase-3d-tarjetas-pantallas-v1.md` (Dirección de Desarrollo,
commit `0148c38`), 4 tarjetas en orden de dependencia. Este documento es el
equivalente de `fase3-motor-log.md` para la ronda de tarjetas del pivot a
3D — hallazgos, no decisiones (Motor reporta datos, Dirección decide).

---

## 1. Tarjeta 1 — Puente de render 3D real

**Clases nuevas** (`game/render/`), una por técnica, sin reinventar el
patrón 2D (`EntityRenderSync`/`TypedRenderGroup`):

- `entity_render_sync_3d.gd` (`EntityRenderSync3D`) — equivalente 3D de
  `EntityRenderSync`, `MultiMeshInstance3D` en formato `TRANSFORM_3D`, un
  solo `multimesh_set_buffer()` por grupo por frame. Soporta color
  por-instancia (`set_type_colors()`, mismo motivo que la versión 2D) —
  usado por proyectiles, que no necesitan malla distinta por tipo.
- `typed_render_group_3d.gd` (`TypedRenderGroup3D`) — equivalente 3D de
  `TypedRenderGroup`, un `EntityRenderSync3D` por `type_id` con material
  teñido — usado por torres, que si van a necesitar malla/material propio
  por tipo más adelante (Arte).
- `shared_skeleton_render_group.gd` (`SharedSkeletonRenderGroup`) —
  extraído/refactorizado de `poc_3d_bench.gd::_spawn_shared_skeleton_group()`
  a una clase reusable con capacidad fija preasignada + `sync(positions,
  count)` por frame (la POC poblaba una grilla estática una sola vez; acá
  las entidades activas cambian cada frame vía spawn/release de
  `EnemyStore`, swap-remove). Usado por enemigos.

**Mapeo de coordenadas** (una sola decisión, consistente en los 3 grupos +
geometría de nivel + raycast): **X sim → X 3D, Y sim → Z 3D, altura fija**.

**Cámara:** `Camera3D` ortogonal fija, mismo ángulo diagonal que
`poc_3d_bench.gd`, encuadrada contra `LevelDef.background_rect` en vez de
una grilla de población.

**Geometría de nivel:** generada en `_build_level_geometry()` a partir de
los mismos datos de `LevelDef` (`path_rects`, `buildable_zones`,
`obstacles`, `spawn_point`/`goal_point`, `background_*`) — planos/
cilindros de color plano, construidos una sola vez en `_ready()` (no por
frame). Confirmado que generaliza a los 5 niveles sin tocar código por
nivel — ver sección 2.

**Colocación de torres:** raycast cámara→plano `y=0`
(`Camera3D.project_ray_origin`/`project_ray_normal` + intersección), mismo
patrón de ~10 líneas que ya dejaba `exploracion-3d.md` sección 2A.
**Advertencia de cobertura:** revisado por código y probado end-to-end vía
colocación programática (`place-types`/`place-all-towers`, headless y en
ventana) — el click real de mouse no se probó (no hay forma simple de
simular un click real headless); mismo criterio que ya usó este proyecto
con la colocación 2D ("queda para que lo pruebes vos a mano").

### Hallazgo 1 — desajuste de escala (encontrado por captura, no a ojo)

Los assets 3D (`monster_m5.glb`, `tower_m5.glb`) están en escala "real"
(~1-2 unidades tras el `scale_fix` que corrige el bug de origen, la misma
escala que usaba `GRID_SPACING=2.5` en `poc_3d_bench.gd`), pero el mapeo
de coordenadas deja el mundo en unidades de sim
(`obstacle_radius`=22, `TOWER_MIN_SPACING`=48, etc. — cientos/miles de
unidades). Sin corrección, torres/enemigos quedaban del tamaño de un
píxel, invisibles a la distancia de cámara real del nivel — visible en la
primera captura de verificación, no en el código. Corregido con un factor
`WORLD_SCALE=20.0` (calibrado a ojo contra `obstacle_radius`/
`TOWER_MIN_SPACING` por captura, no es un número de arte) aplicado sobre
la malla de torres (nuevo parámetro `scale` en `EntityRenderSync3D`/
`TypedRenderGroup3D`) y sobre el `scale_fix` de enemigos
(`SharedSkeletonRenderGroup`). Confirmado por captura tras el fix — torres
y enemigos visibles, proporcionados contra el resto de la geometría.

### Hallazgo 2 — el número empeora al integrar con el juego real (reportado, no escondido)

La sección 1 de la tarjeta pide explícito: correr el escenario oficial
(120 torres, 2.400 enemigos, `real-stats`) contra la pantalla real, no
contra la POC, y reportar si el número empeoró. **Empeoró, con margen
claro, no ruido:**

| Escenario (120 torres / 2.400 enemigos, `real-stats`, mismo backend nativo) | avg_frame_time_ms, ventana de 15 frames (`BenchmarkLogger`) |
|---|---|
| `Level1.tscn` (2D, referencia — mismo camino de sim real) | ~13,4-13,6ms estable (pico de rampa ~16ms) |
| `Level3D.tscn` (3D, este puente) | ~24-25ms estable (pico ~27ms) |
| `poc_3d_bench.gd` (solo render, sin sim real — pivot-3d-poc-v1.md sección 5) | 12,91-13,27ms (caminando) |

El costo de render 3D medido en aislado por la POC (~13ms) no desaparece
al sumarse al costo real de sim/2D que ya existía (~13,5ms) — se suman,
dando ~24-25ms, por encima del budget de 16,6ms (60fps). **Esto es
información nueva, no una contradicción de la POC:** la POC nunca corrió
junto al resto de un frame de juego real (round state, `SpatialHash`,
hot path nativo, UI) — esta es la primera medición de esa combinación.
**No lo intenté esconder detrás de un escenario más fácil** (sección 0 de
la tarjeta lo pide explícito) — lo reporto tal cual salió. Nota
metodológica: `BenchmarkLogger` promedia ventanas de 15 frames, no es el
"piso del peor frame" que usó `poc_3d_bench.gd` — mismo instrumento que ya
usaba `Level1.tscn` para sus propias corridas de stress-test, así que la
comparación 2D vs 3D de la tabla es consistente entre sí, pero no
directamente comparable al número de piso-de-peor-frame de la POC.

**No se investigó ni se optimizó más allá de esto** (no lo pide la
Tarjeta 1, que es sobre el puente de render, no sobre presupuesto) — queda
anotado para que Dirección decida si amerita una Fase de aislamiento
(¿cuánto es esqueleto compartido vs. sync de transform de 2.400 nodos por
frame, la misma sorpresa que ya encontró `pivot-3d-poc-v1.md` sección 5
para "caminar"? ¿amerita bajar `SHARED_SKEL_MASTERS`? ¿son 120 torres/
2.400 enemigos el escenario real más exigente, dado que el catálogo real
de niveles tiene objetivos de oleada mucho más chicos — ver sección 2?).

## 2. Tarjeta 2 — Adaptar los 5 niveles a geometría 3D

**No fue una tarjeta separada en la práctica** — `_build_level_geometry()`
(Tarjeta 1) genera la geometría a partir de los datos que cada `LevelDef`
ya tenía (`path_rects`/`buildable_zones`/`obstacles`/`spawn_point`/
`goal_point`/`background_color`/`background_rect`), sin dato nuevo en
paralelo, tal como pedía la tarjeta. **Confirmado que generaliza a los 5,
no solo al nivel 1:**

- Smoke test headless de `stage=0..4` (colocación de torres + ronda real)
  — las 5 cargan y corren sin error de consola.
- Captura de pantalla real de `stage=2` (forma de carril distinta —
  zigzag en vez de L —, `background_color` propio de ese nivel) contra la
  de `stage=0` — geometría, obstáculos y marcadores de spawn/meta se ven
  correctos y proporcionados en las dos, sin tocar código por nivel.

Sin arte final, tal como pide la tarjeta — planos/cilindros de color
plano, mismo criterio que el resto de esta ronda.

## 3. Tarjeta 3 — Pantallas de menú

Confirmado antes de tocar nada, tal como pedía la tarjeta: `MainMenu.tscn`
y `TalentTree.tscn` son UI pura (`Control`/`Button` por código,
`main_menu_controller.gd`/`talent_tree_controller.gd`) — no dibujan mundo
de juego, no necesitaban reescritura por el pivot. `TalentTree.tscn` no
tiene ninguna referencia a `Level1.tscn`/nivel — cero cambios ahí.

**Único cambio real:** `MainMenu._on_start_pressed()` apunta a
`Level3D.tscn` en vez de `Level1.tscn`.

**Recomendado, no obligatorio, aplicado:** botón "2D (legacy)" (sin estilo
especial, a propósito — botón de desarrollo, no una opción real de juego)
más el flag CLI equivalente `auto-start-2d`, para tener la versión 2D
como punto de comparación mientras la 3D termina de verificarse — mismo
criterio de verificación incremental que ya usó este proyecto (backend
nativo, dirección fija).

Verificado headless: `auto-start` → `Level3D.tscn`, `auto-start-2d` →
`Level1.tscn`, los dos cargan y corren sin error.

## 4. Tarjeta 4 — Prueba de estrés integrada al menú

Como la Tarjeta 1 ya estaba lista para cuando llegó esta, se armó directo
contra el camino de render REAL (no `poc_3d_bench.gd` standalone) — la
advertencia de la tarjeta ("si prueban un camino distinto al que el juego
usa de verdad, el número puede dejar de ser representativo") queda
resuelta de origen, no como deuda pendiente.

- Botón "Prueba de Estrés" en `MainMenu` → `StressMenu.tscn` (nueva
  pantalla, mismo patrón de `Button.new()` por código) → 2 presets
  ("Escala real", 30/300 — "Escala oficial ×1,2", 120/2.400, el mismo
  escenario de la sección 0 de la tarjeta) → `Level3D.tscn` en modo
  stress-test real.
- Sin CLI: el preset se pasa vía `StressLaunchConfig` (autoload nuevo,
  `game/sim/stress_launch_config.gd`, registrado en `project.godot`) —
  `change_scene_to_file()` no lleva argumentos, así que hacía falta un
  canal aparte del CLI existente (`stress-towers=`/`stress-enemies=`, que
  siguen disponibles para diagnóstico por terminal, sin cambios).
  `pending` se consume una sola vez para no reactivarse solo al volver al
  menú y entrar por "Comenzar".
- Controles finos de población: siguen siendo CLI únicamente, tal como
  permite la tarjeta ("no hace falta un slider fino").

Verificado end-to-end headless: `MainMenu -- auto-stress
auto-launch-official` recorre `MainMenu → StressMenu → Level3D.tscn` y
llega a 120 torres colocadas / 2.400 enemigos activos sin pasar por CLI de
stress-test — el mismo número que reporta la tabla del Hallazgo 2.

## 5. Qué queda afuera de esta ronda, a propósito

`level_controller_3d.gd` es una adaptación de `level_controller.gd` (2D),
no una reescritura desde cero — mismo esqueleto de estado, mismo parseo
de CLI de dos pasadas, mismo spawner/oro/vidas/guardado. Lo que se dejó
afuera de esta primera pasada (no lo pedía la Tarjeta 1, `level_controller.gd`
2D lo sigue teniendo intacto — nada de esto se perdió, sigue vivo en la
rama 2D mientras conviven):

- **VFX reales** (`fase3-vfx-exploracion-v1.md`) — los 4 placeholders
  (quemadura/explosión/chispa/muerte) son quads/partículas 2D, no
  traducidos a `GPUParticles3D`/overlay 3D todavía.
- **`stress-textures=1`** (reemplazo de textura vía `SpriteAtlas`) — sin
  sentido en 3D, el render real ya usa los assets 3D por default.
- **Diagnósticos puntuales 2D** (`sprite-test`, `orientation-test`,
  `sprite-test-mipmap-filter`) — específicos del bug de orientación de
  `EntityRenderSync` 2D, no aplican al puente 3D.
- **Orientación/apuntado de torres y enemigos** — todas las instancias
  quedan con rotación identidad (mismo alcance que las cápsulas de
  proyectil sin orientar de `poc_3d_bench.gd`). No lo pedía esta tarjeta;
  queda anotado para cuando Arte defina el eje "adelante" real de cada
  malla.

## 6. Qué no decide este documento

No decide si el Hallazgo 2 (piso ~24-25ms en el escenario oficial,
integrado) bloquea algo — es dato para que Dirección lo evalúe contra el
catálogo real de niveles (objetivos de oleada muy por debajo de 2.400) y
decida si amerita una fase de optimización dedicada. No decide arte final
(assets siguen en calidad `meshy-5`, placeholder). No corrige el bug de
escala del pipeline de origen (`pivot-3d-poc-v1.md` sección 6, sigue
abierto). No calibra economía/combate — deuda heredada de antes del pivot,
sigue siéndolo.
