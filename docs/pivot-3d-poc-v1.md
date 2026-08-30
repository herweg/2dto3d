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

## 4. Idea de la PM para probar después — "bindear" animaciones compartidas

Propuesta: en vez de 2.000-2.400 esqueletos independientes, usar ~10
variantes de animación (mismo clip, distintas fases) y que los enemigos se
repartan entre esas 10 — "10 cálculos en lugar de 2000".

**Es viable y tiene mecanismo concreto en Godot, no es solo una intuición:**
`MeshInstance3D.skeleton` acepta un `NodePath` a un `Skeleton3D` externo —
varias mallas pueden apuntar al mismo esqueleto. Con 10 `Skeleton3D`
"maestros" (cada uno con su propio `AnimationPlayer` en una fase distinta
del ciclo de caminata) y 2.400 `MeshInstance3D` repartidos entre esos 10
por referencia, el cálculo de skinning pasa de 2.400 a 10 — el costo que
hoy domina la sección 3. **No implementado ni medido todavía** — queda
anotado como el candidato directo para cerrar el gap de la sección 3, con
mecanismo real, no una apuesta a ciegas. Riesgo a confirmar cuando se
pruebe: si mejora draw calls también (no solo el costo de skinning) o si
hace falta combinarlo con algo más para eso.

## 5. Qué sigue, no decidido acá

- Probar la idea de la sección 4 contra el escenario oficial de la sección
  3 — es la prueba que cerraría el gap encontrado.
- Variedad real de texturas/mallas (todo lo medido acá es un solo
  monstruo repetido) — sabemos por el proyecto 2D que el costo real vive
  ahí, no en la cantidad de instancias.
- Corregir el bug de escala en el pipeline de origen (sección 1) antes de
  generar en volumen.
- Confirmar del lado de la herramienta si `enable_pbr` se está aplicando
  de verdad.
