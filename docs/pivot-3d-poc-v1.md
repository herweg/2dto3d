# POC de pivot a 3D — cierre de ronda

**Rol:** Dirección de Desarrollo.
**Fecha:** 10-ago-2026.
**Branch:** `pivot-3d-poc`.
**Origen:** decisión de la PM de evaluar un pivot a 3D semi-realista,
cámara fija, sin bloqueo identificado hacia Unreal — ver discusión previa
(sin doc propio, quedó en el hilo de `plan-fases.md`/conversación). Pipeline
de arte: GPT (imagen 2D) → Meshy (imagen-a-3D + rig) → post-proceso
Blender, automatizado por una herramienta propia de la PM.

## 0. Qué no toca esta rama

Nada de `game/sim/` ni `game/rust/` cambió — `exploracion-3d.md` (08-ago) ya
había dejado probado que la simulación es `Vector2` puro, sin acoplarse al
render. Todo lo de acá es escena nueva y aislada
(`game/sim/poc_3d_fase_a.gd`, `game/sim/poc_3d_bench.gd`,
`game/scenes/Poc3D*.tscn`) más los assets de prueba
(`game/assets3d/`).

## 1. Fase A — formato, escala, material

- **Formato: GLB.** Único importador de primera clase en Godot 4 (mallas +
  skin + animación + materiales en un archivo). FBX es plan B (importador
  más nuevo, menos probado); **USDZ no lo importa Godot** — se descarta
  del pipeline de exportación para este uso, es formato de AR de Apple.
- **Bug de escala real, confirmado en los 3 `monster_*` recibidos:**
  bounding box de la malla ~170 unidades de alto en vez de ~1,7 — el "bug
  de fábrica ×0,01" que describe la nota de Post-proceso de la herramienta
  de la PM no llegó aplicado en estos archivos. Se compensó con
  `scale_fix=0.01` en la escena de prueba — **no es un parche a repetir
  por asset, hay que mirarlo en el pipeline de origen.**
- **`enable_pbr:true` no cambió nada exportable.** El material de
  `monster_pbr_m5.glb` es idéntico al de `monster_m5.glb` — mismo
  `emissiveTexture` = `baseColorTexture` (mismo source), sin normal ni
  metallic-roughness. Los 3 monster_* usan un material "emissive-boosted"
  (se auto-iluminan, ignoran luz real de escena) — barato pero opuesto al
  objetivo "semi-realista" tal como se definió. Pendiente: confirmar del
  lado de la herramienta si el flag se aplicó de verdad en esa generación.
- **Comparación visual a poly-count igual (~103k ambos, buena decisión de
  control):** `meshy-7` se ve más apagado/grisáceo que `meshy-5`, tanto en
  el atlas de textura como en el render real — confirmado dos veces, no
  una. Con 4× el costo en tokens, **pierde la comparación.** Ganador:
  `meshy-5`.
- **Animación confirmada de punta a punta en Godot** — rig biped de Meshy
  (24 huesos, clip único "walking" ~1,07s) importa y anima bien bajo
  cámara ortogonal fija.

## 2. Fase B/C — costo de render (banco en `game/sim/poc_3d_bench.gd`)

Mismo criterio del resto del proyecto: vsync off, piso real (peor frame de
una ventana de 120 medida, no promedio), Vega 56 (misma GPU de referencia
de todo el proyecto).

| Escenario | Piso (fps) | Piso (ms) | Draw calls | VRAM |
|---|---|---|---|---|
| 1 monstruo animado | — | — | 1 | 95 MB |
| 25 monstruos animados | 720 | 1,4 | 25 | 120 MB |
| 100 monstruos animados | 360 | 2,8 | 100 | 200 MB |
| 300 monstruos animados | 240 | 4,2 | 300 | 415 MB |
| 300 monstruos, sin animación (control) | 480 | 2,1 | 300 | 415 MB |
| 1.000 monstruos animados | 180 | 5,5 | 1.000 | 1,17 GB |
| 2.000 proyectiles (placeholder, cápsula sin sombreado) | ~252 | ~4,0 | 1 | 66 MB |
| **100 torres + 300 monstruos + 2.000 proyectiles** | 220 | 4,55 | 302 | 441 MB |
| **100 torres + 2.000 monstruos + 3.600 proyectiles** (techo del objetivo 2D) | 93,2 | 10,74 | 2.002 | 2,26 GB |
| **120 torres + 2.400 monstruos + 4.320 proyectiles** (×1,2 — test oficial, ver sección 4) | **54,0** | **18,53** | 2.402 | 2,69 GB |

Proyectiles: primitiva placeholder (cápsula, sin textura, sin sombreado —
no hay asset generado todavía). `MultiMeshInstance3D` explícito y
nodo-por-instancia dieron el mismo número — Godot ya bachea automáticamente
geometría idéntica sin animación (1 solo draw call en los dos casos).
Torres (estáticas, idénticas): mismo bacheo automático.

## 3. El techo real: falla el margen, no el objetivo

**El objetivo (100/2.000/3.600) pasa con margen — 10,74ms de 16,6ms.**
**El test oficial con el ×1,2 de margen que este proyecto siempre exigió
(`definicion-escala-v1.md`, T4) no pasa — 18,53ms, por encima del budget.**
No lo suavizo: la arquitectura más simple posible (nodo de escena por
instancia, sin ningún truco) alcanza para el objetivo pero no para el
margen de seguridad estándar del proyecto.

**La causa está identificada, no es un misterio:** de los 2.402 draw calls,
2.400 son los monstruos — torres y proyectiles baten solos a 1 draw call
cada grupo porque son idénticos y sin animación; los monstruos no baten
porque cada uno tiene su propio estado de animación independiente
(`AnimationPlayer` + `Skeleton3D` propios). Es exactamente el riesgo que
`exploracion-3d.md` (sección 2B) había anotado en agosto: "animación
esquelética por instancia... es harina de otro costal."

## 4. Idea de la PM — animaciones compartidas — probada, cierra el gap

Propuesta: en vez de 2.400 esqueletos independientes, usar ~10 variantes
de animación (mismo clip, distintas fases) y que los enemigos se repartan
entre esas 10 — "10 cálculos en lugar de 2000".

**Implementado en `game/sim/poc_3d_bench.gd` (`shared_skel=<n>`) y medido
contra el escenario oficial de la sección 3.** `MeshInstance3D.skeleton`
(`NodePath` a un `Skeleton3D` externo) es el mecanismo real de Godot para
esto — 10 `Skeleton3D` "maestros" (cada uno con su propio
`AnimationPlayer`, fases repartidas) más 2.390 `MeshInstance3D` livianos
(mismo mesh/skin del maestro, sin `Armature` propio) que apuntan a uno de
los 10 por round-robin.

**Diagnóstico previo a construir, barato (reusa el flag `anim=0` que ya
existía):** el mismo escenario oficial (120/2.400/4.320) sin animar dio
13,33ms — contra 18,53ms animando. Esa brecha de 5,2ms es lo que la técnica
ataca; que el "techo sin animar" ya entrara en el budget (13,33 < 16,6) fue
la señal de que valía la pena construir la versión real antes de descartar
o seguir buscando otra cosa.

**Resultado real, escenario oficial completo (120 torres + 2.400
monstruos + 4.320 proyectiles), 10 maestros:**

| Variante | Piso |
|---|---|
| Animación independiente por instancia | 18,53ms — falla |
| Sin animar (techo teórico) | 13,33ms |
| **Esqueleto compartido, 10 maestros** | **7,14ms** |

**Mejor que el techo "sin animar" — no solo que "animando normal".**
Confirmado por qué, no solo observado: el ahorro no es únicamente el
cálculo de animación — 2.400 instancias completas de la escena
(`Armature`/`Skeleton3D`/`AnimationPlayer` propios, 26 nodos cada una,
~62.000 nodos en el árbol) contra 2.390 `MeshInstance3D` sueltos (un nodo
cada uno) más 10 maestros completos (~2.650 nodos totales) — mantener
62.000 nodos vivos en el árbol de escena ya costaba, aparte del cálculo de
animación en sí. Draw calls sin cambio (2.402 en las tres variantes) —
confirma que esta técnica no toca el draw call, ataca la otra mitad del
costo, que era la que dominaba.

**Cierra el gap de la sección 3 con margen de sobra.** No hace falta seguir
buscando otra optimización para esta escala.

## 5. Caminata real + variedad de textura — pedido de la PM, medido

Dos huecos que quedaban: los enemigos posaban quietos (no caminaban), y
todo lo medido era un solo monstruo repetido (sabíamos por el proyecto 2D
que el costo real de variedad vive ahí, no en la cantidad de instancias).

- **Caminata:** `walk=1` en `poc_3d_bench.gd` — cada enemigo (`is_enemy`)
  se mueve en -X a velocidad constante y hace wrap al llegar al borde de
  la grilla, real movimiento de transform cada frame, no solo animación en
  el lugar.
- **Variedad de textura, real, no simulada:** `docs/3d/make_texture_variants.py`
  genera N PNG con hue-shift real sobre la textura original (archivos
  distintos, no un tinte de shader). `tex_variants=10` las reparte
  round-robin, duplicando el material base y reemplazando su textura
  (mismo mesh/skin compartido — variedad de piel y esqueleto compartido no
  compiten entre sí). **Las 10 PNG generadas (73MB, ~7,3MB cada una — el
  hue-shift le gana a la compresión plana del original) no están
  commiteadas** — regenerables con un comando
  (`python docs/3d/make_texture_variants.py <textura_original> game/assets3d/monster/variants 10`),
  no vale duplicar ese peso en el repo para un placeholder de prueba.

**Resultado, escenario oficial completo (120 torres + 2.400 monstruos +
4.320 proyectiles, esqueleto compartido con 10 maestros):**

| Variante | Piso |
|---|---|
| Quieto, sin variedad de textura (sección 4) | 7,14 ms |
| **+ caminata real** | **13,27 ms** |
| + caminata + 10 texturas reales | 12,91 ms |

**Sorpresa — caminar cuesta más que animar el esqueleto, y no lo
esperaba.** De 7,14ms a 13,27ms, ~6,1ms extra por mover 2.400 transforms
por frame — más que toda la ganancia que dio compartir esqueleto sobre el
peor caso (18,53→7,14ms redujo 11,4ms; caminar devuelve más de la mitad de
eso). **Hipótesis razonada, no confirmada con profiler:** cada
`Node3D.position =` en un nodo con render dispara una actualización al
`RenderingServer` (transform + AABB de culling); con 2.400 nodos moviéndose
independientes cada frame, esa es la porción de costo nueva — no medí esto
con un profiler nativo para confirmarlo a fondo. **Sigue pasando el
budget** (12,91-13,27ms de 16,6ms) pero con mucho menos margen que la
versión quieta (3,3-3,7ms libres contra 9,46ms) — vale vigilarlo si se
suma más costo en paralelo (sim real, UI), porque este test sigue siendo
solo render.

**Variedad de textura no costó nada medible** (12,91 vs 13,27, dentro del
ruido) — a diferencia del hallazgo 2D (`fase2-benchmark-conjunto.md`
sección 11, `TypedRenderGroup`), acá cada enemigo ya era su propio draw
call de por sí (2.402 sin cambio en las tres filas de la tabla), así que
la textura no rompe ningún bacheo que no estuviera roto ya.

## 6. Qué sigue, no decidido acá

- Corregir el bug de escala en el pipeline de origen (sección 1) antes de
  generar en volumen.
- Confirmar del lado de la herramienta si `enable_pbr` se está aplicando
  de verdad.
- El esqueleto compartido asume que compartir pose entre instancias no se
  nota en un tower defense con muchos enemigos en pantalla (10 fases
  repartidas entre miles) — validado acá solo visualmente en chico (30
  instancias, 5 maestros), no a la escala/velocidad de cámara real del
  juego.
- El costo de caminata (sección 5) queda con hipótesis sin confirmar del
  todo — si el margen restante (~3,5ms) preocupa más adelante, vale
  perfilar de verdad en vez de seguir sobre la hipótesis.
