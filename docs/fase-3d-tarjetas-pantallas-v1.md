# Tarjetas — reconstruir las pantallas del juego en 3D (post-pivot)

**Rol:** Dirección de Desarrollo.
**Fecha:** 10-ago-2026.
**Origen:** decisión de producto de la PM de pivotear a 3D
(`plan-fases.md`). La POC que valida la escala real está cerrada y con
datos — `docs/pivot-3d-poc-v1.md`. `main` ya tiene todo fusionado
(`pivot-3d-poc` + el juego 2D existente, conviviendo). La línea 2D previa
al pivot queda preservada intacta en la rama `_ol2d` por si hace falta
volver — no la toquen, no hace falta portarle nada de lo de acá.

**Ejecuta:** Mesa de Developers (otro agente con acceso al proyecto, no
Dirección). Estas tarjetas son la especificación — la implementación,
las decisiones de detalle dentro de cada tarjeta, y la verificación son
suyas, con el mismo criterio de reportar hallazgos y sorpresas que usó
este proyecto siempre.

---

## 0. Contexto obligatorio antes de tocar código

**La simulación no cambia — solo la capa de render.** `game/sim/` y
`game/rust/` siguen en `Vector2` de punta a punta, sin ninguna referencia
a 3D (`exploracion-3d.md`, sección 1 — el único punto de contacto sim↔render
ya es explícito: `EntityRenderSync.sync(positions, type_ids, count)`, un
paquete por store por frame). No reescriban `EntityStore`/`EnemyStore`/
`TowerStore`/`ProjectileStore`/`TowerSystem`/etc. — lean primero
`game/render/entity_render_sync.gd` y `game/render/typed_render_group.gd`
para ver el patrón que hay que replicar en 3D, no reinventar.

**Hay dos costos distintos, no uno, y la técnica correcta es distinta para
cada uno — esto ya se midió, no hay que redescubrirlo:**

| Tipo de entidad | Técnica | Por qué |
|---|---|---|
| Torres, proyectiles (sin animación, idénticos por tipo) | `MultiMeshInstance3D`, uno por `type_id` — mismo patrón que `TypedRenderGroup` hoy en 2D | Godot bachea esto solo a 1 draw call por grupo. Medido: 100 torres o 4.320 proyectiles, 1 draw call cada grupo (`docs/pivot-3d-poc-v1.md` sección 2). |
| Enemigos (rigueados, animados) | **NO** `MultiMeshInstance3D` — Godot no anima huesos por-instancia ahí. Usar la técnica de esqueleto compartido: N `Skeleton3D` "maestros" animados + `MeshInstance3D` livianos que apuntan su `.skeleton` (NodePath) a uno de los maestros | Confirmado en la POC (`exploracion-3d.md` sección 2B lo había anticipado como riesgo; `game/sim/poc_3d_bench.gd::_spawn_shared_skeleton_group()` es la implementación de referencia, ya probada) — sin esto, 2.400 enemigos animados cuestan 18,53ms de piso; con esto, 7,14ms quieto / 13,27ms caminando. |

**Assets disponibles hoy, calidad placeholder (no es arte final, mismo
criterio que ya usó este proyecto con sprites 2D antes de tener arte
real):**
- `game/assets3d/monster/monster_m5.glb` — enemigo genérico rigueado,
  **requiere `scale = Vector3(0.01, 0.01, 0.01)` al instanciar** (bug de
  escala ×100 en el archivo recibido, no corregido en origen todavía —
  ver sección 6 de `pivot-3d-poc-v1.md`; no lo parcheen distinto a como ya
  lo hace `poc_3d_bench.gd`, para no divergir).
- `game/assets3d/tower/tower_m5.glb` — torreta genérica estática, sin fix
  de escala necesario.
- Material de los `monster_*`: "emissive-boosted" (se auto-ilumina,
  ignora luz real de la escena) — no es PBR real todavía. Si el look final
  importa antes de tener arte real, es una pregunta para Arte, no para
  esta tarjeta.
- **`game/sim/poc_3d_bench.gd` es la referencia de implementación viva**
  para todo lo de esta sección — cámara ortogonal fija, esqueleto
  compartido, caminata, variedad de textura. Léanlo antes de escribir
  nada de cero.

**Vara de performance a mantener — la misma que ya usa el proyecto,
ahora en 3D:** piso real (peor frame de una ventana medida, no promedio),
vsync off, 16,6ms (60fps) como bar, y el escenario "oficial" con ×1,2 de
margen ya definido: **120 torres, 2.400 enemigos animados y caminando,
4.320 proyectiles → hoy da 12,91ms** (`pivot-3d-poc-v1.md` sección 5). Si
algo de lo que construyan en las tarjetas de abajo hace que ese número
empeore, repórtenlo — no lo escondan detrás de un escenario más fácil.

---

## 1. Puente de render 3D real (`EntityRenderSync3D` / equivalente) — la pieza central

**Todo lo demás depende de esta.** Reemplaza, para la pantalla de juego
real (no la POC), el render placeholder de color plano 2D por los assets
3D reales, bajo cámara fija.

- Clases nuevas (nombre a criterio de Mesa de Developers), una por cada
  técnica de la sección 0 — no una sola clase que intente las dos cosas:
  1. Grupo estático tipado (torres/proyectiles) — `MultiMeshInstance3D`
     por `type_id`, mismo contrato de entrada que `TypedRenderGroup` hoy
     (`positions`, `type_ids`, `count`).
  2. Grupo animado (enemigos) — esqueleto compartido, extraído/refactorizado
     de `poc_3d_bench.gd::_spawn_shared_skeleton_group()` a una clase
     reusable, no copy-paste del script de investigación.
- **Mapeo de coordenadas:** decidir y documentar una convención fija
  (recomendado: X sim → X 3D, Y sim → Z 3D, altura fija en 0) — es una
  decisión de una línea, pero tiene que ser una sola y consistente en
  todo el puente, no redecidida por cada llamador.
- **Cámara:** `Camera3D` ortogonal fija reemplaza `Camera2D` — mismo
  ángulo que ya usa `poc_3d_bench.gd` (o el que Arte prefiera, es una
  decisión de aspecto, no de motor).
- **Geometría de nivel que hoy es `_draw()` (2D puro, no existe en 3D):**
  carril, zonas de colocación, obstáculos, spawn/meta
  (`exploracion-3d.md` sección 1) necesitan geometría real — un plano con
  textura o color plano alcanza como placeholder, igual que se hizo para
  torres antes de tener arte real. No hace falta arte final acá.
- **Colocación de torres con el mouse:** hoy usa
  `get_global_mouse_position()` (2D nativo). En 3D hace falta un raycast
  cámara→plano `y=0` — `exploracion-3d.md` sección 2A ya deja el patrón
  exacto (`Camera3D.project_ray_origin`/`project_ray_normal` + intersección
  de plano), ~10 líneas, no arquitectura nueva.
- **Verificación:** captura de pantalla comparando contra la POC (mismo
  aspecto visual esperado), más el escenario oficial de la sección 0 corrido
  contra la pantalla real (no contra `Poc3DBench.tscn`) — confirmar que el
  número no empeoró al integrarlo con el resto del juego real (UI, sim
  completo corriendo, no solo render aislado).

## 2. Adaptar los 5 `LevelDef` a geometría 3D

Cada uno de los 5 niveles ya construidos (`LevelDef`, con `waypoints`/
`path_rects`/`obstacles`/paleta temática de `diseno-grafico.md`) necesita
su geometría 3D — generada a partir de esos mismos datos, no un dato
nuevo en paralelo. Placeholder de color/plano por tema alcanza, mismo
criterio que el resto de esta tarjeta. Puede avanzar en paralelo a la
Tarjeta 1 (no compite por los mismos archivos), pero no se puede verificar
del todo hasta que el puente de render exista.

## 3. Pantallas de menú — `MainMenu`, `TalentTree`: cambio mínimo

**Importante, para no gastar trabajo de más:** `MainMenu.tscn` y
`TalentTree.tscn` son UI pura (`Control`/`Button` creados por código en
`main_menu_controller.gd`/`talent_tree_controller.gd`) — no dibujan el
mundo del juego, así que **no necesitan reescritura por el pivot en sí**.
Confirmen esto antes de tocarlas, no asuman que todo hay que rehacerlo.

- Único cambio real: el botón "Start" apunta a la nueva pantalla de nivel
  3D (Tarjeta 1) en vez de `Level1.tscn`.
- Recomendado, no obligatorio: mientras la versión 3D se termina de
  verificar, dejar ambas alcanzables (un flag CLI o botón de desarrollo
  para la versión 2D vieja) — mismo criterio de verificación incremental
  que usó este proyecto en cada migración anterior (backend nativo,
  dirección fija, etc.), no reemplazar de un saque sin punto de comparación.
- Talentos, Exit, Tabula Rasa, el status de guardado: sin cambios.

## 4. Prueba de estrés integrada al menú del juego (no solo CLI)

Hoy `Poc3DBench.tscn`/`poc_3d_bench.gd` es una escena de investigación
aparte, solo por flags de CLI, no alcanzable jugando. Pedido explícito:
que se pueda lanzar desde el menú real.

- Agregar un botón (mismo patrón que los demás botones de `MainMenu`,
  `Button.new()` por código) — ej. "Prueba de Estrés" — que cargue una
  escena de estrés real.
- **Decisión de fondo, no cosmética:** una vez que exista el puente de
  render real (Tarjeta 1), el botón debería probar el camino de render
  REAL del juego (`EntityRenderSync3D`/grupo animado de la Tarjeta 1), no
  la lógica de spawn standalone de `poc_3d_bench.gd` — si prueban un
  camino distinto al que el juego usa de verdad, el número que midan
  puede dejar de ser representativo sin que nadie lo note. Si por
  secuencia esta tarjeta se hace antes de que la 1 esté lista, arrancar
  reusando `poc_3d_bench.gd` como está y dejarlo anotado como deuda a
  resolver cuando la 1 exista — no bloquear esta tarjeta por eso.
- Mantener los controles de población como flags de CLI (ya existen:
  `count`/`counts`, `shared_skel`, `walk`, `tex_variants`, `proj_count`)
  y sumar una versión mínima en UI (unos pocos botones de preset —
  "escala real", "escala oficial ×1,2" — alcanza, no hace falta un slider
  fino) para que sea usable jugando, no solo por terminal.

---

## Orden recomendado

**1 primero, siempre** — todo lo demás depende de que el puente de render
exista. **2 puede correr en paralelo a 1** (no compite por archivos, solo
no se puede verificar del todo hasta que 1 esté). **3 depende de 1**
(necesita una pantalla de nivel real para apuntar el botón "Start"). **4
depende de 1** para la versión que vale la pena confiar — puede arrancar
antes con la salvedad ya anotada arriba.

## Qué no es esta ronda de tarjetas

No decide arte final (los assets siguen en calidad `meshy-5`, placeholder).
No corrige el bug de escala del pipeline de origen (`pivot-3d-poc-v1.md`
sección 6, sigue abierto, no bloquea esto). No conecta los efectos del
árbol de talentos a combate ni calibra números de juego — eso ya era
deuda heredada de la línea 2D antes del pivot, sigue siéndolo.
