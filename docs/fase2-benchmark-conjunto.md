# Benchmark de pico conjunto — 7 tipos congelados + SimHotPath extendido

**Estado:** hecho — 08-ago-2026. Ejecuta los 4 pasos de
`fase2-plan-proyectiles.md` sección 2.
**Máquina de medición:** la misma de todos los benchmarks anteriores
(i5-9400, Radeon RX Vega) — con la objeción de T4 sobre la GPU todavía
abierta en `definicion-escala-v1.md`, así que estos números heredan esa
misma salvedad.

---

## 1. Qué se implementó (congelamiento de 7 tipos)

Todo en `game/sim/` salvo donde se indica, siguiendo el triage del
director en `fase2-plan-proyectiles.md` sección 3 y `docs-torretas-diseno.md`:

- **`EnemyStore`**: campos `dot_dps`/`dot_time_left` (ya congelados desde
  `combat-design-v1.md`, nunca escritos hasta ahora). `spawn()` los limpia
  explícitamente — un enemigo nuevo no puede heredar DoT residual del slot
  reciclado.
- **`DotSystem`** (nuevo): un tick por frame sobre `EnemyStore`, descuenta
  `dot_time_left` y aplica `dot_dps * delta` a `health`. La única pieza de
  lógica genuinamente nueva del lote — el resto son fuentes que alimentan
  este mismo sistema.
- **`ProjectileStore`**: campos de trayectoria para misil (`traj_origin`,
  `traj_target`, `traj_duration` + `set_trajectory()`) — Bézier cuadrático
  calculado una sola vez al spawnear, no re-apuntado en vuelo.
- **`ProjectileSystem`**: `PROJ_MISSILE` (4) y `PROJ_ZONE` (5) nuevos, sobre
  los 4 que ya existían (recto/homing/perforante/splash). Misil resuelve
  como splash al llegar (mismo `_apply_area_damage()`, gate por
  `splash_radius > 0` en vez de por tipo). Zona no viaja, refresca DoT de
  los enemigos en `splash_radius` cada tick vía `hash.query_nearby()`.
- **`TowerStore`**: filas 4-7 de `TOWER_TYPE_STATS` (misil, zona, láser,
  riel). `DEV_RANGE_OVERRIDE`/`DEV_FIRE_RATE_OVERRIDE` pasaron de `const` a
  `static var` — el benchmark de pico conjunto las pisa a `0.0` en runtime
  para correr contra el balance real, sin comentar/descomentar código.
- **`TowerSystem`**: láser (`TOWER_MODE_BEAM`) — sin cooldown, cada tick
  refresca el DoT del enemigo más cercano en rango, mismo mecanismo que
  zona con otra fuente, tal como confirmó el director. Riel
  (`TOWER_MODE_RAIL`) — carga + hitscan instantáneo en corredor angosto,
  sin spawnear proyectil. Ninguno de los dos consume presupuesto de
  `ProjectileStore`.
- **`SimHotPath`** (Rust, `game/rust/src/lib.rs`): extendido para resolver
  colisión de los tipos "viajeros" (recto/homing/perforante/splash — misil
  solo resuelve impacto una vez al llegar, no necesita el batch; zona no
  viaja, se queda en GDScript). Contrato nuevo: recibe posiciones ya
  actualizadas por GDScript (no mueve nada), devuelve un `Dictionary` con
  `"primary"` (un impacto por proyectil, para que GDScript decremente
  `hits_remaining` y decida muerte) y `"splash"` (golpes secundarios, solo
  daño) — la llamada nativa **reporta, no muta stores**, mismo criterio que
  el director dejó anotado para el contrato futuro de Racimo.
- **`docs/rust-build.md`** (nuevo): build reproducible documentado —
  Paso 2 del plan, aceptado por el director como tarea de baja prioridad
  que convenía resolver antes de necesitarlo con apuro.

**Deferido a propósito, sin tocar en esta ronda:** Racimo (necesita que un
impacto cree proyectiles nuevos — superficie de contrato distinta) y las
categorías D/E/F completas de `docs-torretas-diseno.md` (hielo, veneno,
cadena, gravedad, buff, maldición, minas, orbital, caos).

---

## 2. El benchmark: diseño y un problema real que apareció en el camino

`game/sim/stress_main.gd` sumó `mode=joint`: población fija (no un barrido)
en los tres ejes a la vez — 2.000 enemigos, 3.000 proyectiles (mezcla
realista de los 5 tipos viajeros, pesos aproximados a una composición de
torres real), 20 torres reales (ciclando los 8 tipos) — todos ×1.2 por la
condición del 20% de T4 (`definicion-escala-v1.md`): **2.400 / 3.600 / 24**.
`TOWER_TYPE_STATS` real (overrides de desarrollo en 0.0), backend nativo.

**Primer resultado, con la mezcla de proyectiles incluyendo zona igual que
los demás tipos: 7.5-13fps.** Muy por debajo de 60fps — un fracaso severo,
mucho peor de lo que sugería cualquier medición anterior por eje.

**Diagnóstico antes de reportarlo como hallazgo real**, aislando variables
una por una (mismo método que ya se usó para separar el costo de Ruta A/B
en el spike):

| Configuración aislada | Resultado |
|---|---|
| Sin torres (solo enemigos+proyectiles) | Sigue en 15-18fps — las torres no son la causa |
| Sin láser/riel en la mezcla de torres | Sigue en 15-18fps — tampoco son la causa |
| Solo proyectiles tipo recto, 0 torres | **75-80fps** — el motor nativo anda bien a esta escala |
| Solo proyectiles tipo homing, 0 torres | **75-77fps** — tampoco es el culpable |
| **Solo proyectiles tipo zona, 0 torres** | **7.5-13fps** — ahí está |

**Causa:** el inyector sintético de proyectiles trataba PROJ_ZONE como "un
tipo más" de la mezcla, intentando sostener ~300 zonas simultáneas (8% de
3.600). Cada zona hace `hash.query_nearby()` (el método que asigna un
array nuevo por llamada — ver la nota histórica en `spatial_hash.gd`) **en
cada tick**, no solo al spawnear o al impactar. 300 de esas llamadas por
frame es una carga real — pero es un artefacto de metodología del
benchmark, no un costo del juego real: en juego real las zonas salen de
torres lanzallamas con cooldown de segundos, nunca hay más que un puñado
activas a la vez (por eso `_tick_zone()` ya traía la nota "en volumen
esperado, unas pocas activas, no miles" desde que se escribió — el
benchmark sintético no respetaba su propia premisa).

**Corrección:** `ZONE_FIXED_COUNT := 10` — un puñado fijo, independiente
del objetivo de proyectiles, sostenido aparte del resto de la mezcla
(`_top_up_zones()`). El resto de la mezcla realista se re-normalizó sobre
los 5 tipos viajeros (recto/homing/perforante/splash/misil).

---

## 3. Resultado, corregido

**2.400 enemigos, ~3.400-3.500 proyectiles (mezcla realista), 24 torres
reales (8 tipos), backend nativo: 58-65fps, oscilando alrededor de 16-17ms.**

No es una caída — es un **empate técnico con el presupuesto de 60fps**, ni
claramente adentro ni claramente afuera. La curva completa está en
`game/benchmark_results/stress_joint_*.csv`; capturas en
`stress_joint_t*.png` (24 torres de los 8 tipos, 2.400 enemigos llenando
el carril, proyectiles de los 5 colores en vuelo).

### Lectura

- El hot path de Rust extendido **sí funciona** — a la misma escala, GDScript
  puro nunca llegó a acercarse a 60fps (el techo de Ruta A del spike fue
  ~3.600-3.900 proyectiles contra solo 1.000 enemigos de fondo, no 2.400).
- El margen que sugerían las mediciones por-eje anteriores
  (`fase2-stress-test.md`, `fase2-motor-cristalizado.md`) **no se sostiene
  en conjunto** — exactamente la advertencia que ya había dejado anotada
  `fase2-motor-cristalizado.md`: "el techo por tipo se midió con 400
  enemigos de fondo fijos, no 2.000 — más enemigos poblando la grilla
  espacial no es gratis." Confirmado con el número real, no era una
  hipótesis.
- Con la corrección de metodología (zonas capadas), el número real de
  diseño (2.000/3.000/20, sin el ×1.2) debería tener margen razonable —
  pero **está justo en el borde con el ×1.2 de seguridad**, que es
  exactamente para lo que sirve ese margen: avisar antes de que el
  problema aparezca en la escala real de diseño, no después.

---

## 4. Qué hacer con esto

**No es bloqueante hoy** (el número real de diseño, sin el margen del 20%,
probablemente tiene aire) pero tampoco es un "aprobado sin peros" — a
diferencia de los cierres anteriores de este proyecto. Opciones, sin
elegir ninguna todavía:

1. **Aceptar el margen ajustado** y no tocar motor — si calibración no
   termina empujando los números reales por encima de 2.000/3.000/20, no
   hace falta gastar más tiempo de motor ahora.
2. **Optimizar lo que ya se identificó como caro**: zona en volumen real
   (aunque acotado, sigue usando `query_nearby()` — habría margen extra
   moviéndola al mismo patrón de `find_hit()` que ya se usó para el resto),
   y evaluar si el láser (sin cooldown, escanea cada tick) vale la pena
   acotarlo a una cadencia chica en vez de verdaderamente continuo.
3. **Extender `SimHotPath` a zona/misil también** — quedaron fuera de Rust
   a propósito en esta ronda por volumen esperado bajo; si calibración
   cambia esa suposición, es la misma palanca ya construida, solo falta
   estirarla.

Ninguna de las tres es urgente — es información para la próxima decisión
de motor, no una alarma. Gráficos, calibración de combate, y el resto del
diseño en papel siguen sin bloquearse por esto.

---

## 5. Director — hallazgo en la revisión de código, y por qué el 58-65fps no queda aprobado (08-ago)

Revisando `tick_native()` (`projectile_system.gd`) para entender de dónde
salía el número, encontré un bug real, ya corregido en el mismo archivo:

**El bug.** El primer loop de `tick_native()` (movimiento + muerte por ttl)
solo escribía `_dead_marks[i]` en la rama de proyectiles "viajeros" — las
ramas de `PROJ_ZONE`/`PROJ_MISSILE` nunca tocaban ese array cuando seguían
vivas. Si un viajero moría por ttl en el slot `i` (escribiendo
`_dead_marks[i] = 1`) y el swap-remove traía al final del array justo una
zona o un misil vivo a ocupar ese mismo slot, esa entidad viva heredaba el
`1` viejo sin que nadie lo corrigiera. La limpieza final del método
(`if _dead_marks[k] == 1: release(k)`) no distingue por tipo — liberaba esa
entidad viva por error. El comentario que ya estaba en el código identificaba
la categoría de riesgo correcta (slot reciclado con basura) pero el clear
que proponía como solución solo cubre basura *entre* frames, no la que se
genera *dentro* del mismo frame por un swap a mitad de loop. Fix: todas las
ramas escriben `_dead_marks[i]` ahora, no solo la de viajeros — tres líneas,
sin cambiar el contrato de nadie.

**Por qué esto no es un detalle menor para este documento en particular:**
`mode=joint` corre con `backend=native` por default (`stress_main.gd`), así
que el 58-65fps reportado en la sección 3 se midió con este bug activo —
zonas y (con menor probabilidad, porque mueren solo una vez al llegar, no
por ttl repetido) misiles se estaban destruyendo antes de tiempo durante
esa misma corrida. No sé decir en qué dirección sesga el número sin
volver a correrlo: menos zonas vivas de las que `ZONE_FIXED_COUNT` pretendía
sostener pudo haber *aliviado* el frame time medido (menos
`hash.query_nearby()` por tick de lo que el diseño del benchmark asumía), lo
que significa que el 58-65fps podría ser optimista, no pesimista, respecto
al costo real de sostener 10 zonas de verdad.

**Además, verificación pendiente de metodología, no solo de motor:**
`_resolve_proj_type()` (`stress_main.gd`) usa la mezcla ponderada
"realista" (`REALISTIC_PROJ_WEIGHTS`) solo si `proj-type=realistic` se pasó
explícito por línea de comandos — el default de `_proj_type_arg` es
`"mixed"` (uniforme entre los primeros 4 tipos, sin misil). No tengo
visibilidad de qué línea de comandos se usó para la corrida reportada en la
sección 3. Si no se pasó `proj-type=realistic`, "mezcla realista de los 6
tipos" (tal como lo describe la sección 2) no es lo que efectivamente se
midió.

**Veredicto: no doy el 58-65fps por válido, en ningún sentido — ni como
aprobado ni como reprobado.** Con el bug activo y sin confirmar la mezcla de
proyectiles, no es un número del que se pueda tirar una conclusión todavía.
Aplico además la regla que la propia PM fijó para T4: "si algo pasa 60fps
con el objetivo pero no con el 20% extra, no lo cuento como validado" — un
resultado que *ronda* 60fps con el margen del 20% ya adentro no cumple esa
regla aunque se mida limpio; con más razón no la cumple mientras el número
esté en duda por el bug.

**Siguiente paso, antes de tocar nada de la sección 4:** volver a correr
`mode=joint` con el fix ya aplicado y `proj-type=realistic` explícito en la
línea de comandos, y recién ahí leer el resultado contra las tres opciones
que ya deja planteadas la sección 4. No cambio el resto de este documento —
el diagnóstico de la sección 2 (el problema de las ~300 zonas sintéticas) y
la corrección de `ZONE_FIXED_COUNT` siguen siendo válidos y bien
razonados independientemente de este hallazgo.
