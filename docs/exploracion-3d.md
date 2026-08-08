# Exploración — ¿pasar la presentación a 3D?

**Estado:** exploratorio, sin decisión. No toca código — el equipo técnico
está trabajando en la migración de `_tick_beam()` en este momento.
**Origen:** pregunta directa del PM, 08-ago — "¿tendría un costo
considerable? creo que solo aplicable a la visual, los cálculos de
movimiento y sus cálculos pudieran seguir en 2D (z=0) por simplicidad."
**Respuesta corta:** la intuición es correcta y, más que correcta, ya es
así — la arquitectura actual separa simulación de render desde el primer
documento de este proyecto (`directorsuggestions.md`), así que "3D solo en
lo visual" no es una propuesta nueva, es explotar una costura que ya existe.
El costo real no está donde parece — está en la pregunta de **qué tipo de
3D**, no en el "3D" en sí. Ver sección 2.

---

## 1. Por qué la simulación no se entera del cambio

Todo lo que hoy calcula posición, colisión, daño y targeting trabaja sobre
`Vector2` puro, sin ninguna referencia a cómo se dibuja después:

- `EntityStore`/`EnemyStore`/`ProjectileStore`/`TowerStore` — arrays de
  `PackedVector2Array`, sin campo de altura ni de orientación 3D.
- `SpatialHash`, `find_hit()`, `query_nearby()` — hash 2D sobre `(x, y)`.
- `SimHotPath` (Rust) — mismo hash 2D, mismo contrato de arrays.
- `LaneEnemySystem`, `TowerSystem`, `DotSystem` — toda la lógica de
  steering, targeting y daño en el plano.

El único punto de contacto entre simulación y render es
`EntityRenderSync.sync(positions, type_ids, count)` — un paso explícito,
al final de cada frame, que empaqueta `positions` en un buffer y hace una
sola escritura a `RenderingServer`. Ese fue el diseño desde el principio
(`directorsuggestions.md`, sección 2.3), no una casualidad que ahora
convenga: la simulación nunca supo que el render existía, así que cambiar
el render no le pide nada a la simulación. **z=0 no es una simplificación
nueva que haya que introducir — es el estado actual, implícito, de todo el
proyecto.** Pasar a 3D visual no cambia una sola línea de
`game/sim/*` ni de `game/rust/`.

---

## 2. Dónde está el costo real: dos "3D" muy distintos

"Pasar a 3D" puede significar dos cosas con costos de producción que no se
parecen en nada. Separarlas es el punto central de este documento.

### 2A. Sprites en un mundo 3D (billboards) — costo bajo, reusa casi todo

La cámara y la escena pasan a `Camera3D`/`Node3D`, pero los enemigos,
proyectiles y torres siguen siendo imágenes planas — las mismas que ya
está diseñando Arte (`docs/diseno-grafico.md`) — dibujadas sobre un quad
que siempre mira a cámara (`billboard` en `MultiMeshInstance3D`/
`StandardMaterial3D`). Es la técnica de juegos como *Clash Royale* o
*Age of Empires* clásico: mundo con profundidad y cámara angulada, actores
planos.

- **Motor:** `MultiMeshInstance2D` → `MultiMeshInstance3D`, formato de
  transform de 8 floats (2D) a 12 (3D, una matriz 3×4). El patrón — un
  solo `multimesh_set_buffer()` por grupo por frame — no cambia; cambia
  el tamaño del paquete. `TypedRenderGroup` necesita el mismo cambio,
  contenido, sin tocar su lógica de enrutar por `type_id`.
- **Cámara:** `Camera2D` → `Camera3D` en ángulo (isométrico o
  perspectiva descendente) — configuración, no arquitectura nueva.
- **Colocar torres con el mouse:** hoy `_place_tower()` usa
  `get_global_mouse_position()` directo (2D nativo). En 3D hace falta un
  raycast desde cámara contra el plano `y=0` (`Camera3D.project_ray_origin`/
  `project_ray_normal` + intersección de plano) — patrón estándar de
  Godot, unas 10 líneas, no una pieza de arquitectura nueva.
- **Arte:** se reusa el pipeline que Arte ya está armando — paleta,
  colores de firma, prompts de ChatGPT para sprites 2D. Cero retrabajo de
  ese lado.
- **Lo que sí hay que rehacer, y no es gratis:** todo lo que hoy se dibuja
  con `_draw()` (carril, zonas construibles, obstáculos, spawn/meta) es
  `CanvasItem`/2D puro — no existe en `Node3D`. Necesita convertirse a
  geometría real (un plano con textura, o decals) para ser visible desde
  una cámara angulada. Es trabajo real pero acotado — geometría estática
  de nivel, no simulación.

### 2B. Modelos 3D reales — costo alto, compite con el plan de arte actual

Enemigos, torres y proyectiles como mallas 3D modeladas, texturizadas y
(para los enemigos, que caminan) rigueadas y animadas por esqueleto. Esto
**no es una extensión** del trabajo de Arte que ya está en curso — es un
pipeline distinto de punta a punta: modelado, UV, texturizado, rigging,
animación por hueso en vez de frames de sprite. El documento de dirección
de arte actual (`docs/diseno-grafico.md`) está pensado enteramente para
sprites 2D generados por prompt; nada de ese trabajo se traslada a mallas
3D sin rehacerse.

Del lado de motor tampoco es simétrico con 2A: `MultiMesh` en modo 3D
puede instanciar una malla real (no solo un quad), así que el motor
*puede* soportarlo — pero animación esquelética por instancia dentro de
`MultiMesh` es harina de otro costal (Godot no anima huesos por-instancia
en un `MultiMesh` de la misma forma simple que swappear una textura, como
hace hoy `EntityRenderSync.set_sprite()`). Es una pieza de investigación
técnica propia, no una extensión de lo que ya existe.

**No recomiendo evaluar 2B ahora.** No porque no sea viable — porque es un
proyecto de arte y de motor distinto al que está en curso, y comprometerse
sin haber probado 2A primero sería exactamente el error que este proyecto
viene evitando desde el spike de Sprint 2: apostar sin medir.

---

## 3. Costo de GPU — pendiente de medir, no de adivinar

Este proyecto ya tiene un benchmark de VFX en GPU pendiente y greenlit
(`docs/diseno-grafico.md`, respuesta del director sección 8), secuenciado
después de re-confirmar el piso de CPU del benchmark conjunto. Un cambio a
3D (2A) agrega una pregunta más a esa misma categoría: cuánto cuesta
profundidad, un mínimo de luz (aunque sea una sola `DirectionalLight3D` o
directamente materiales sin sombreado) y billboards a la escala de
2.000-3.000 instancias, contra la Vega 56 con la condición del 20% de T4.

Mi expectativa razonada, no medida: bajo. `MultiMeshInstance3D` con
material sin iluminación (`unshaded`) y sin sombras proyectadas es una
técnica muy transitada en juegos con miles de instancias — el costo
adicional sobre el pipeline 2D actual debería ser menor que el de
cualquiera de los efectos de partículas que ya está evaluando el
benchmark de la sección 5 de `diseno-grafico.md`. Pero es una expectativa,
no un dato — si esto avanza, se mide con el mismo método de siempre
(`stress_main.gd::mode=enemies`, la misma comparación A/B que ya se usó
para sprite vs. color plano en `fase2-stress-test.md`), no se asume.

---

## 4. Recomendación

1. **La pregunta "¿cuesta caro pasar a 3D?" tiene una respuesta distinta
   según a cuál de las dos 2A/2B se refiera** — no es una sola decisión.
2. **Si el interés es 2A (sprites en mundo 3D, cámara con profundidad):**
   costo bajo, motor y arte casi enteros se reusan. Es razonable evaluarlo
   en paralelo al trabajo en curso, sin apuro — no compite por los mismos
   archivos que está tocando el equipo ahora mismo.
3. **Si el interés es 2B (modelos 3D reales, animación esquelética):** es
   una decisión de producto mucho más grande — redefine el pipeline de
   arte completo, no solo el de motor — y ameritaría su propio documento
   de alcance y presupuesto, no una sección de este. No lo recomiendo
   evaluar todavía.
4. **Antes de tocar una sola línea de motor:** confirmar con la PM cuál de
   las dos se está preguntando en realidad. Este documento asume que la
   intención (por cómo está planteada la pregunta — "solo aplicable a la
   visual") es 2A.

## 5. Si más adelante se aprueba explorar 2A — spike propuesto, no ejecutado

Mismo patrón que todo spike anterior de este proyecto: medir antes de
comprometer.

1. Un `EntityRenderSync3D` (o una bandera en el actual) que empaquete el
   buffer en formato `TRANSFORM_3D` en vez de `TRANSFORM_2D`, billboard
   activado, sobre el mismo `QuadMesh`/sprite que ya existe.
2. `Camera3D` angulada reemplazando `Camera2D` en una escena de prueba —
   no en `Level1.tscn` real todavía.
3. Correr el mismo barrido de `stress_main.gd::mode=enemies` (300→7.000)
   con el render 3D en vez del 2D, mismo `BenchmarkLogger`, comparación
   directa contra los ~5.730 ya conocidos.
4. Recién con ese número, decidir si 2A entra a `Level1.tscn` de verdad.

No se ejecuta nada de esto ahora — queda anotado para cuando el equipo
técnico esté libre y haya decisión de la PM sobre el punto 4 de la sección
anterior.
