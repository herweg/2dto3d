# Manifiesto — TowerDefense 3D

**Rol:** Dirección de Desarrollo.
**Fecha:** 10-ago-2026.
**Origen:** decisión de la PM de pivotear a 3D, ya confirmada y ejecutada
sobre `/game/` (`pivot-3d-poc` fusionado a `main`, 5 tarjetas de pantallas
cerradas y verificadas — ver `docs/plan-fases.md`, `docs/pivot-3d-poc-v1.md`,
`docs/fase-3d-tarjetas-pantallas-v1.md`, `docs/fase-3d-motor-log.md` en la
raíz del repo). Este documento funda un proyecto nuevo y separado — no es
una tarjeta más sobre el árbol de `/game/`.

**Ejecuta:** Mesa de Developers (otro agente, con acceso al repo
completo). Este manifiesto es la especificación de qué migrar, con qué
nombre, y qué descartar a propósito — no una tarjeta técnica de una sola
pieza. Descomponerlo en tarjetas concretas y reportar con la misma
disciplina de siempre (hallazgos reales, no "hecho" sin verificar).

---

## 0. Qué tiene que pasar — leer esto primero

1. **Crear `/game3d/` como proyecto Godot nuevo y propio** (su propio
   `project.godot`), hermano de `/game/` en este mismo repositorio — no un
   reemplazo in-place, no un repositorio aparte.
2. **Este documento es el primer archivo del proyecto nuevo** — ya vive en
   `/game3d/docs/towerdefense_3d_manifiesto.md`, antes que cualquier
   código.
3. **`/game/` no se toca ni se borra.** Sigue existiendo tal cual, y la
   rama `_ol2d` sigue siendo el snapshot del 2D puro previo al pivot.
   `/game3d/` es de dónde sigue el desarrollo real de acá en más;
   `/game/` queda como referencia/archivo histórico hasta que se decida
   qué hacer con él — esa decisión no la toma este documento.
4. Todo lo de las secciones siguientes se ejecuta como tarjetas propias,
   en la secuencia que Mesa de Developers considere razonable — este
   documento no impone un orden salvo donde se diga explícito.

---

## 1. Por qué un proyecto nuevo y no seguir sobre `/game/`

`/game/` acumuló, en este orden: el juego 2D completo (Fases 1-4), una
POC de 3D construida encima sin saber todavía si iba a prosperar
(`poc_3d_bench.gd`, `poc_3d_fase_a.gd`, assets de prueba sueltos en
`docs/3d/`), y después el puente de render 3D real construido **al lado**
del 2D — con sufijos `_3d`/`3D` en todo, un botón "2D (legacy)" y flags
`auto-start-2d`/CLI para poder comparar durante la transición. Esa
comparación ya se hizo y ya se decidió (`plan-fases.md`) — cargar ese peso
indefinidamente en el proyecto real, cuando ya no hace falta, es la
"basura residual" que motiva este documento. Mismo criterio que ya usó
este proyecto siempre: preservar la historia (`_ol2d`, los docs de la
POC), no arrastrar sus artefactos de trabajo hacia adelante.

---

## 2. Qué se migra tal cual — arquitectura ya probada, no se re-discute

- **Toda la simulación** (`game/sim/entity_store.gd`, `enemy_store.gd`,
  `tower_store.gd`, `projectile_store.gd`, `tower_system.gd`,
  `lane_enemy_system.gd`, `dot_system.gd`, `spatial_hash.gd`, y el resto de
  `game/sim/*` que no sea un controlador de escena 2D específico) —
  `Vector2` puro, nunca dependió de cómo se renderiza
  (`exploracion-3d.md` ya lo dejó probado). Migra sin reescribir lógica.
- **El hot path en Rust** (`game/rust/`, `SimHotPath`) — sin cambios.
- **`SaveManager`, `Settings`, `TalentTreeDef`/`talents_01.tres`,
  `LevelDef` y los 5 niveles ya construidos** — datos y persistencia, sin
  cambios de formato.
- **El puente de render 3D real**, ya probado dos veces (POC aislada y
  contra el juego real): `entity_render_sync_3d.gd`,
  `typed_render_group_3d.gd`, `shared_skeleton_render_group.gd`,
  `level_controller_3d.gd`, `Level3D.tscn`. Migra, pero **renombrando** —
  ver sección 3.
- **`MainMenu`, `TalentTree`, `ConfigMenu`, `FpsOverlay`,
  `StressMenu`/`StressLaunchConfig`** — UI y flujo, sin el botón/flag de
  comparación 2D (sección 4).
- **Los assets 3D actuales** (`game/assets3d/`) — siguen siendo placeholder
  (calidad `meshy-5`, genéricos: un monstruo, una torreta), pero es lo que
  hay. Migran tal cual hasta que Arte entregue el catálogo real — no
  bloquea nada de este manifiesto.

## 3. Convención de nombres — sin sufijo "3D" / "_3d"

En `/game3d/` no hay un 2D con el que desambiguar — el sufijo pierde
sentido y solo agrega ruido a partir de ahora. Renombrar al migrar:

| En `/game/` | En `/game3d/` |
|---|---|
| `entity_render_sync_3d.gd` (`EntityRenderSync3D`) | `entity_render_sync.gd` (`EntityRenderSync`) |
| `typed_render_group_3d.gd` (`TypedRenderGroup3D`) | `typed_render_group.gd` (`TypedRenderGroup`) |
| `level_controller_3d.gd` | `level_controller.gd` |
| `Level3D.tscn` | `Level.tscn` (o el nombre temático del nivel — a criterio de quien migre) |

`shared_skeleton_render_group.gd` (`SharedSkeletonRenderGroup`) no
cambia — no tiene equivalente 2D con el que pudiera confundirse.

## 4. Qué NO se migra — la "basura residual", explícita

- `poc_3d_bench.gd`, `poc_3d_fase_a.gd`, `Poc3DBench.tscn`,
  `Poc3DFaseA.tscn` — cumplieron su función (medir y decidir), documentado
  en `pivot-3d-poc-v1.md`. La técnica que probaron ya vive en las clases
  reales de la sección 2 — no hace falta cargar el código de investigación.
- Todo lo puramente 2D (`level_controller.gd`, `Level1.tscn`,
  `entity_render_sync.gd`/`typed_render_group.gd` en su versión 2D,
  `stress_main.gd`, `benchmark_main.gd`) — se queda en `/game/`/`_ol2d`, no
  cruza a `/game3d/`.
- El botón "2D (legacy)" de `MainMenu` y los flags `auto-start-2d` y
  equivalentes — existían para comparar durante la transición, ya
  cumplieron su función.
- `docs/3d/model_meshy-5.glb`, `model_meshy-7.glb`,
  `docs/3d/monster/resultado*.{fbx,usdz,glb}`,
  `game/assets3d/monster/variants/` (73MB) — assets de prueba/comparación,
  nunca se commitearon a propósito, no hace falta llevarlos.
- `docs/try-assets/gpt/*`, `docs/try-assets/sounds/` — sueltos hace
  tiempo, sin uso confirmado. No cruzan sin que alguien confirme
  explícitamente que hacen falta.

## 5. Lo que hay que saber, no rediscutir — deuda y hallazgos ya conocidos

- **Bug de escala ×100** en los assets recibidos del pipeline
  Meshy/Blender — sigue sin corregirse en origen, se compensa con
  `scale_fix`/`WORLD_SCALE` en cada consumidor. Si migra sin corregirse,
  sigue siendo una trampa para el próximo asset nuevo que llegue.
- **Materiales "emissive-boosted"**, no PBR real — nunca se confirmó si
  `enable_pbr` se aplica de verdad del lado de la herramienta de la PM.
- **Rotación identidad en todo** — torres, enemigos y proyectiles no se
  orientan. Pendiente de que Arte defina el eje "adelante" de cada malla.
- **Presupuesto de performance, condicional a escala:** el escenario real
  de hoy (24 torres/300 enemigos) sobra margen (5,3-5,5ms); el escenario
  oficial ×1,2 (120 torres/2.400 enemigos) no entra en el budget de
  16,6ms (da 24-25ms) — aceptado sin optimizar, con gatillo explícito: si
  el catálogo real de niveles/progresión se acerca a esa escala, medir de
  nuevo antes de decidir si hace falta una fase de optimización.
- **Costo de mover transforms por frame (caminata) mayor al esperado**
  (~6ms a 2.400 instancias) — hipótesis razonada (actualización de
  transform/AABB en `RenderingServer` por nodo), nunca confirmada con
  profiler real.
- **Talentos sin efecto en combate, calibración de combate entera sin
  hacer** (vidas, oro por ronda, costos de nodos, tamaño de oleada) — no
  es deuda de 3D específicamente, es la pieza que más le falta al juego
  para tener sentido de punta a punta, y migra intacta junto con la
  simulación.

## 6. Qué decide este documento, y qué no

**Decide:** que existe un proyecto nuevo (`/game3d/`), qué se migra, con
qué nombre, y qué se descarta a propósito. **No decide:** cuándo se retira
`/game/` del repositorio (prematuro — se decide cuando `/game3d/` esté
confirmado funcionando de punta a punta, no antes), ni calibración de
combate, ni arte final — deuda que sigue viva, anotada en la sección 5
para que no se pierda en la migración, no resuelta acá.
