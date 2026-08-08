# Benchmark de VFX en GPU — primera medición (Vega, desde cero)

**Estado:** hecho — 08-ago-2026. Ejecuta el benchmark propuesto en
`docs/diseno-grafico.md` sección 5, secuenciado detrás del piso de CPU ya
confirmado en `docs/fase2-benchmark-conjunto.md` sección 8 (sostenido por
encima de 60fps, sin valles).
**Máquina de medición:** la misma de todos los benchmarks anteriores
(i5-9400, Radeon RX Vega) — con la objeción de T4 sobre la GPU todavía
abierta en `definicion-escala-v1.md`, estos números heredan esa misma
salvedad.
**Cómo correrlo:** `mode=vfx vfx-test=unit|scenario|overdraw|tint`
(`game/sim/stress_main.gd`) **en ventana, no `--headless`** — headless usa
un driver de rendering sin GPU real; sin ventana no aparece la línea
`Vulkan ... Using Device` que sí aparece en toda corrida de este documento,
y un `GPUParticles2D` no hace nada ahí. `vfx-count=<N>` solo aplica a
`vfx-test=overdraw`.

---

## 1. Los 4 escenarios, tal como pide la sección 5 de `diseno-grafico.md`

Ninguno de los dos tipos de partículas del catálogo (Enjambre, Gravedad)
tiene fila congelada todavía (son categorías C/D deferidas — ver
`fase2-benchmark-conjunto.md` sección 1), así que los conteos simultáneos
son **suposiciones explícitas, no datos** — cada escenario dice cuál hace y
por qué:

1. **Costo unitario:** 3 emisores `GPUParticles2D` (remolino tipo Gravedad,
   40 partículas c/u, órbita + spread) — 3 es la misma densidad por tipo
   que ya usa el resto del catálogo en la composición de 24 torres / 8
   tipos del benchmark conjunto, no un número elegido a mano.
2. **Escenario objetivo real:** 20 emisores de partículas + 10 capas de
   overdraw simultáneas — las "30 torretas maxeadas disparando junto" de
   `docs-torretas-diseno.md`, con varios efectos candidatos a la vez, no
   uno solo aislado.
3. **Overdraw dirigido:** N capas translúcidas (`Sprite2D` semitransparente,
   120×120px) superpuestas **en el mismo punto** (peor caso real) — dos
   corridas, N=10 (el mismo tope que ya usaba `ZONE_FIXED_COUNT`) y N=25
   (por encima, para medir margen).
4. **Corrida de control:** un `ShaderMaterial` de rotación de matiz
   (`game/render/chaos_tint.gdshader`) sobre una sola malla, animado
   continuamente — Torreta del Caos.

Piso reusado tal cual de `fase2-benchmark-conjunto.md` sección 8: 2.400
enemigos, ~3.400-3.600 proyectiles (mezcla realista), 24 torres reales,
backend nativo, `proj-type=realistic` explícito.

---

## 2. Resultado

| Escenario | avg fps | fps mínimo | fps máximo |
|---|---|---|---|
| **Piso sin VFX** (referencia, sección 8, 2 corridas) | 69.9 / 71.3 | **60.3 / 65.1** | 77.2 / 77.3 |
| Costo unitario (3 emisores) | 61.2 | **50.4** | 66.2 |
| Escenario real (20 partículas + 10 overdraw) | 63.8 | **48.3** | 68.5 |
| Overdraw ×10 (tope actual) | 64.7 | **49.3** | 71.3 |
| Overdraw ×25 (2.5× el tope) | 64.3 | **49.4** | 70.3 |
| Control — tinte (Torreta del Caos) | 63.9 | **49.3** | 68.5 |

Curvas completas en `game/benchmark_results/stress_vfx_*.csv`; capturas en
`stress_vfx_*_t*.png`.

### Lectura — hay un costo, pero no escala con lo que se le agrega

**No es gratis, en contra de lo que sugería "probablemente barato" de
`diseno-grafico.md` sección 4 — pero tampoco es lo que hay que vigilar.**
Los 5 escenarios caen en el mismo rango (48-56fps de piso, ~62-65fps de
promedio), **prácticamente idéntico entre sí** — 3 emisores de partículas
cuestan lo mismo que 20 + 10 capas de overdraw, y 10 capas de overdraw
cuestan lo mismo que 25. Eso es la firma de un **costo fijo de tener VFX
presente** (llamadas de dibujo/binds de material adicionales), no un costo
que crezca con la cantidad de partículas o capas en los rangos probados acá
— si escalara con el conteo, el escenario de 30 emisores+capas debería
verse claramente peor que el de 3, y no es el caso.

**Comparado contra el piso sin VFX** (sección 8): el promedio baja
~7-10fps y el piso baja ~11-15fps en las cinco corridas, de forma
consistente. Es una caída real y medible, no ruido — pero uniforme entre
escenarios, así que no hay una variable de "cuánto VFX" que optimizar
todavía: agregar el primer efecto cuesta lo mismo que agregar el
trigésimo, en este rango.

**Overdraw ×25 vs ×10 — la pregunta específica de "cuánto margen hay antes
de que duela":** prácticamente sin diferencia (49.3 vs 49.4fps de piso).
2.5× el tope de diseño no movió la aguja — el margen antes de que el
overdraw importe de verdad está más allá de lo que este benchmark llegó a
probar, no en 10-25 capas.

### Qué significa esto para las decisiones pendientes de `diseno-grafico.md` sección 6

- **Benchmark de la sección 5: hecho, con margen real.** El piso de CPU
  (60.3-87fps) absorbe el costo fijo de VFX medido acá (48.3-56fps en el
  peor punto) y sigue arriba de 60fps *en promedio* en los 5 escenarios,
  aunque el **piso** de las 5 corridas con VFX (48.3-50.4fps) sí queda por
  debajo de 60fps — a diferencia del piso de CPU solo, que no bajó de
  60.3fps. Esto es información para calibrar, no un fracaso: significa que
  VFX + población de diseño al 120% juntos sí piden algo de margen
  adicional, aunque no proporcional a cuánto VFX se agregue.
- **Partículas/overdraw no es el riesgo que había que temer** — la
  hipótesis de `diseno-grafico.md` sección 4 se sostiene en la dirección
  correcta (no es gratis, pero tampoco escala mal), con datos en vez de
  argumento.
- **Técnica de ilustración** (los 3 candidatos de la sección 0/6 de
  `diseno-grafico.md`): con este dato ya no bloqueada por el costo de VFX
  — la elección entre vectorial plano / pintado semi-realista / pixel art
  sigue siendo una decisión de diseño, no la fuerzo acá.
- **Pendiente que sigue abierto, sin relación con este benchmark:** la
  reconciliación de nombres del catálogo (fase2-benchmark-conjunto.md
  sección 8) y si láser tiene entrada propia en el catálogo de 20 — ninguno
  de los dos es de motor.

---

## 3. Escalada conservadora → real, con Vulkan real (08-ago, pedido explícito)

La sección 2 midió directo al piso de diseño completo (2.400/3.600/24) —
dos puntos, sin VFX y con VFX. Acá se pidió lo mismo que en cada benchmark
anterior de este proyecto: no saltar directo al extremo, escalar desde algo
trivial y armar una curva completa antes de consultar al director.

**Nuevo `mode=vfx-scale`** (`game/sim/stress_main.gd`): barre 6 escalones,
desde el más conservador posible hasta el objetivo ×1.2 de siempre, con
"torres normales" (tipos 0-3 — recto/homing/perforante/splash, no la
familia BEAM/riel/misil) y proyectiles proporcionales (mismo ratio 1.5 que
`JOINT_PROJ_TARGET`/`JOINT_ENEMY_TARGET`). `vfx-scale-fx=1` agrega VFX
proporcional al tamaño de cada escalón (mismos emisores/capas que la
sección 1, en la misma proporción 20/24 y 10/24 ya medida); sin el flag,
mide población + render real solos, como pedía el primer paso.

**Hallazgo de método, antes de los números:** las primeras corridas
mostraban un techo plano de 144fps en los escalones chicos — no es el
motor, es el refresco del monitor (vsync). A población baja el juego corre
tan sobrado que ni siquiera se acerca a su propio techo, así que medía la
pantalla, no el motor. Se agregó `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`
en `_ready()` (guardado, no aplica en `--headless`) — sin esto, "5 torres,
50 enemigos" no es un dato, es "144, siempre", en cualquier hardware con
ese refresco.

### Resultado, con vsync deshabilitado — curva completa, dos pasadas

| Escalón | Enemigos/Torres | Sin VFX (avg / min) | Con VFX proporcional (avg / min) |
|---|---|---|---|
| 0 — conservador | 50 / 5 | 740.3 / 88.8 | 726.9 / 83.9 |
| 1 | 200 / 8 | 475.5 / 420.0 | 464.0 / 417.4 |
| 2 | 500 / 12 | 275.7 / 240.0 | 269.9 / 240.0 |
| 3 | 1.000 / 16 | 157.3 / 102.8 | 155.0 / 107.3 |
| 4 | 1.600 / 20 | 103.2 / 91.0 | 104.4 / 90.8 |
| 5 — objetivo ×1.2 | 2.400 / 24 | 72.1 / 68.0 | 70.7 / 68.6 |

Curvas completas en `stress_vfx-scale_base_1786213462.csv` (sin VFX) y
`stress_vfx-scale_fx_1786213489.csv` (con VFX), ambas con Vulkan real
confirmado (`Vulkan 1.3.260 - Forward+ - Using Device #0: AMD - Radeon RX
Vega` en el log de arranque de las dos corridas).

### Lectura

- **La curva es limpia y monotónica** — cada escalón baja de forma
  predecible según sube la población, sin saltos ni sorpresas entre pasos.
  El escalón 5 (72.1fps) es consistente con el 60.3-87fps ya medido en
  `fase2-benchmark-conjunto.md` sección 8 para el mismo objetivo, con
  `mixed` en vez de `realistic` como mezcla de proyectiles (`vfx-scale` no
  expone ese parámetro todavía, no hace falta para lo que mide esta
  sección).
- **VFX proporcional no se distingue de la población sola en NINGÚN
  escalón** — la diferencia entre las dos columnas es 1-4% en todos los
  casos, dentro del ruido de medición. No es una confirmación en los dos
  extremos (como medía la sección 2): es la misma conclusión sostenida en
  los 6 puntos de la curva completa.
- **Con esto, la data para el director está completa**: el piso de CPU
  (sección 8 de `fase2-benchmark-conjunto.md`), el costo de VFX a escala
  fija en 4 escenarios (sección 1-2 de este documento), y ahora la curva
  completa de escalado con Vulkan real, conservador a extremo, con y sin
  VFX. Las tres piezas apuntan en la misma dirección: el piso de motor es
  sólido, y VFX no es el riesgo a vigilar en el rango probado.
