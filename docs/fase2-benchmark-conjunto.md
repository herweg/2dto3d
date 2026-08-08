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

---

## 6. Re-corrida con el fix + `proj-type=realistic` — segundo bug encontrado, número final (08-ago)

Re-corrí `mode=joint proj-type=realistic` como pedía la sección 5. Resultado
crudo, con el bug de `_dead_marks` ya corregido: **~40-45fps en régimen
sostenido, con valles de 32fps.** Peor que el 58-65fps reportado, no mejor —
la sospecha de la sección 5 ("podría ser optimista") se confirma en la
dirección correcta, pero por una razón distinta a la que ahí se anotaba.

**Diagnóstico, mismo método de la sección 2** (aislar variable por variable,
usando los parámetros de diagnóstico que ya trae `stress_main.gd`):

| Configuración aislada | Resultado |
|---|---|
| 0 torres (solo enemigos+proyectiles a escala real) | 70-75fps — el piso sin torres está sano |
| 24 torres, todos los tipos, `proj-type=0` (recto puro) | 32-45fps — la caída no depende del tipo de proyectil inyectado |
| 24 torres sin láser/riel en el ciclo (`tower-cycle=6`) | 32-45fps — prácticamente igual, tampoco es láser/riel |
| 1 torre (ciclo sin láser/riel) | 68-77fps — una torre sola no cuesta nada |
| 6 torres (1 de cada tipo 0-5, incluida 1 lanzallamas) | 68-73fps |
| 12 torres (2 de cada tipo, 2 lanzallamas) | 63-67fps |
| 18 torres (3 de cada tipo, **3 lanzallamas**) | 37-45fps — el salto |
| 24 torres (4 de cada tipo, 4 lanzallamas) | 32-45fps |

El salto no lineal entre 2 y 3 torres lanzallamas (fila 5 de
`TOWER_TYPE_STATS`) señaló la fila exacta. Causa: al rediseñar la familia
BEAM (commit anterior), la fila 5 quedó con `fire_rate: 0.0` como si fuera
a migrar a `TOWER_MODE_BEAM` (que no usa cooldown, se salta ese chequeo por
diseño) — pero `proj_type` se dejó **a propósito** en `5` (`PROJ_ZONE`,
documentado en `tower_store.gd`), que sí pasa por el camino normal de
`TowerSystem.tick()`. Ahí, `fire_rate: 0.0` no significa "sin cooldown por
diseño" — significa "recarga instantánea": la torre plantaba una
`PROJ_ZONE` nueva **cada frame**, sin ningún límite, mientras hubiera un
enemigo a 90px. A 2.400 enemigos eso siempre es cierto. Cada zona activa
hace `hash.query_nearby()` por tick (la misma operación que la sección 2
ya había identificado como cara) — con 3-4 torres lanzallamas
retroalimentando la población de zonas sin freno, el costo escala mucho
peor que lineal con la cantidad de torres.

No era un artefacto del inyector sintético esta vez — era un dato real de
`TOWER_TYPE_STATS`, así que afectaba (o va a afectar) al juego jugable
también, no solo al benchmark, en cuanto exista más de una torre
lanzallamas cerca de tránsito de enemigos.

**Fix aplicado** (`tower_store.gd`): `fire_rate` de la fila 5 vuelve a
`2.2` (el valor que tenía antes del rediseño BEAM), con comentario dejando
explícito que es un valor puente hasta que la fila migre de verdad a
`_tick_beam()` — ver la nota "Estado de implementación" ya existente en el
mismo archivo.

### Resultado final, con los dos fixes aplicados

**2.400 enemigos, ~3.300-3.600 proyectiles (mezcla realista, 5 tipos
viajeros + 10 zonas fijas), 24 torres reales (8 tipos, `fire_rate` real),
`proj-type=realistic` explícito, backend nativo: 55-65fps sostenido,
promedio ~59-60fps, piso ~54.5fps.**

Curva completa en `stress_joint_1786209078.csv`
(`game/benchmark_results/`).

**Un detalle que vale la pena dejar anotado:** el 58-65fps que reportaba
originalmente la sección 3 — medido con *ambos* bugs activos a la vez
(dead-marks matando zonas/misiles de más, fila 5 creándolas de más) —
terminó cayendo casi en el mismo rango que el número ya verificado. No fue
que los bugs no importaran: fue que tiraban en direcciones opuestas y se
cancelaron parcialmente por casualidad. Ninguno de los dos se detectó
midiendo el fps final — los dos aparecieron leyendo código con el resultado
ya en la mano y preguntando "¿de dónde sale este número, literalmente?",
no "¿el número parece razonable?". Vale la pena como recordatorio general,
no solo para este documento.

### Veredicto sobre la sección 4

Con el número ya verificado (promedio ~59-60fps, piso ~54.5fps): **no pasa
la regla del 20% que fijó la PM para T4** — un piso por debajo de 60fps
durante parte del sostenido no es "60fps con margen", es por debajo del
objetivo base incluso antes de contar el margen. La opción 1 de la sección 4
("aceptar el margen ajustado") queda descartada con este dato — no es que
esté "justo en el borde", está midiblemente por debajo en los valles.

Entre las opciones 2 y 3: el hallazgo de esta sección no cambia cuál
conviene más, sigue siendo la misma elección de siempre entre optimizar lo
que ya está (zona a `find_hit()`, láser acotado a una cadencia) o estirar
`SimHotPath` a zona/misil — el fix del `fire_rate` saca el ruido de la
medición, no reemplaza esa decisión. La dejo para quien la tome, con el
número ahora confiable para apoyarla.

---

## 7. Decisión del director sobre cómo bajar el costo (08-ago)

**No elijo entre las opciones 2 y 3 tal como estaban planteadas — hay una
mejor ya a medio camino, y la pido en vez de las otras dos.**

`tower_store.gd` ya venía anotando que lanzallamas quedó **a propósito** en
`PROJ_ZONE` en vez de migrar a `TOWER_MODE_BEAM` (la familia de láser)
porque `_tick_laser()` todavía no generaliza a rectángulo. Esa migración,
cuando se haga, no es una optimización sobre el mecanismo actual de
lanzallamas — **le saca el mecanismo actual entero**: deja de ser una fila
en `ProjectileStore` con `ttl`/spawn/swap-remove y `hash.query_nearby()` por
tick, y pasa a ser lo mismo que ya es láser — un chequeo directo desde la
torre, sin tocar `ProjectileStore` para nada. Ya no hace falta
`ZONE_FIXED_COUNT` como freno artificial si la zona deja de ocupar un slot
del store. Es más cambio que la opción 2 (que solo le sacaba el costo de
alocación a `query_nearby()` sin tocar el resto) y resuelve el problema en
la raíz que ya diagnosticó la sección 2, no lo mitiga.

**Una condición, no la doy por gratis solo porque "probablemente" lo sea**
(esa palabra ya apareció una vez en este mismo archivo sobre este mismo
tema, sin medirla — no la repito sin dato encima): el chequeo de rectángulo
compartido (`_tick_beam()`) tiene que filtrar candidatos contra el
`SpatialHash` (mismo patrón de 9 celdas que ya usa `find_hit()`/
`query_nearby()`), **no** escanear `enemy_store.active_count` completo como
hace hoy `_tick_rail()`. Riel puede pagarse ese lujo porque dispara cada
`RAIL_CHARGE` = 1.2s; láser y lanzallamas van a correr **todos los ticks**
— si `_tick_beam()` termina barriendo 2.400 enemigos por torre por frame,
cambiamos una consulta acotada por hash por un brute-force sin acotar, que
es peor, no mejor.

**Pedido concreto para cuando el equipo técnico toque esta parte** (junto
con la reconciliación de nombres del catálogo que ya se acordó):

1. Generalizar `_tick_laser()`/`_tick_zone()` a un `_tick_beam()` compartido
   con geometría de rectángulo (usa `range` como largo y `proj_extra` como
   ancho, tal como ya quedó diseñado en `TOWER_TYPE_STATS`), filtrando
   candidatos por `SpatialHash`, no por barrido completo.
2. Migrar la fila 5 (lanzallamas) de `proj_type: PROJ_ZONE` a
   `TOWER_MODE_BEAM` — deja de spawnear en `ProjectileStore`.
3. Sumar cadencia de reselección de objetivo acotada (6-10 veces/seg, no
   60) para ambos — el DoT ya tiene margen de linger, no hace falta
   re-buscar blanco en cada frame para que se sienta continuo.
4. Re-correr `mode=joint` con el mismo método de las secciones 5-6 (número
   crudo, diagnóstico si no cierra, no asumir) antes de dar esto por
   resuelto.

Si después de esto el número sigue sin pasar el 20%, ahí sí correspondería
la opción 3 original (estirar `SimHotPath` a zona/misil) — pero no antes de
medir el resultado de esta migración, que ya estaba a medio camino y ataca
la causa, no el síntoma.
