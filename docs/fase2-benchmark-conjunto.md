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

---

## 8. Migración `_tick_beam()` aplicada — cierra (08-ago)

Los 4 puntos del pedido de la sección 7, en el mismo pase:

1. **`SpatialHash.query_radius(pos, radius)`** (nuevo, `spatial_hash.gd`) —
   generalización de `query_nearby()` a radios mayores a una celda:
   candidatos de un cuadrado de `2×radius`, sin barrer `active_count`.
2. **`TowerSystem._tick_beam(i, delta)`** (reemplaza `_tick_laser()`) —
   geometría de rectángulo (`range`=largo, `proj_extra`=ancho), candidatos
   acotados por `hash.query_radius()`, mismo chequeo dot-product/perpendicular
   que ya probó `_tick_rail()`. Reselecciona a `BEAM_RETARGET_INTERVAL = 1/8s`
   (8Hz), no cada tick — reusa `cooldown_left` como timer, que en las filas
   BEAM no se usaba para nada hasta ahora.
3. **Fila 5 (lanzallamas) migrada** de `proj_type: PROJ_ZONE` a
   `TOWER_MODE_BEAM` — deja de tocar `ProjectileStore` por completo. El
   bug de `fire_rate: 0.0` de la sección 6 queda sin efecto (BEAM nunca lee
   `fire_rate`, ver `tower_system.gd::tick()`) — no hizo falta decidir un
   valor puente, la migración lo vuelve irrelevante.
4. **`stress_main.gd`**: `ZONE_FIXED_COUNT` a `0` (ninguna torre real
   spawnea `PROJ_ZONE` ya, sostener zonas sintéticas mediría un mecanismo
   que el juego no tiene) y comentario de `mode=joint` corregido (5 tipos
   viajeros, no 6).

**Nomenclatura del catálogo, en el mismo pase** (`docs-torretas-diseno.md`,
sección de revisión 08-ago): Mortero (#9) = misil del motor (arco + delay +
splash), Fuego (#11) = lanzallamas del motor (DoT de área) — correspondencia
mecánica, no arbitraria. Riel (#3) sigue confirmado distinto de láser. **Lo
que sigue sin resolver, porque es diseño y no nomenclatura:** si láser tiene
entrada propia en el catálogo de 20 o si Riel lo reemplaza — esa pregunta no
la fuerzo, queda igual de abierta que antes.

### Número crudo — dos corridas, mismo método de las secciones 5-6

`mode=joint proj-type=realistic`, sin diagnóstico adicional porque **cerró
limpio, no hizo falta aislar nada**:

| Corrida | Régimen sostenido (post-rampa) |
|---|---|
| 1 (`stress_joint_1786210888.csv`) | 60.3-85.8fps, ni una muestra por debajo de 60 |
| 2 (`stress_joint_1786210916.csv`) | 65.1-87.0fps, ni una muestra por debajo de 60 |

**2.400 enemigos, ~3.400-3.600 proyectiles (mezcla realista, 5 tipos
viajeros — ya sin zona sintética), 24 torres reales (8 tipos, láser y
lanzallamas migrados a `TOWER_MODE_BEAM`), backend nativo: sostenido por
encima de 60fps en las dos corridas, sin valles por debajo del umbral.**
Pasa la regla del 20% de T4 con margen real, no un empate técnico — a
diferencia de las secciones 3 y 6.

**Por qué esto y no las opciones 2/3 originales:** la fila 5 dejó de ocupar
un slot de `ProjectileStore` — no hay `ttl`/swap-remove/`query_nearby()` por
tick que optimizar, el mecanismo completo que causaba el costo (secciones 2
y 6) desapareció. Consistente con lo que ya anotaba la sección 7: atacó la
causa, no el síntoma, y el resultado lo confirma.

**No hace falta extender `SimHotPath` a zona/misil** — la condición del
pedido original ("si con eso todavía no pasa el 20%") no se cumple. Zona ya
no tiene fuente real que sostenga volumen; misil sigue resolviendo una sola
vez al llegar, nunca fue el costo por tick que importaba medir.

**Siguiente paso, sin bloquear nada de lo anterior:** benchmark de VFX en
GPU (`docs/diseno-grafico.md` sección 5), ya secuenciado detrás de este piso
de CPU — que ahora sí queda confiable para apoyarlo.

---

## 9. Tests reales en `Level1.tscn` (no el arnés sintético) — bug encontrado (08-ago)

Todo lo de las secciones 1-8 corrió sobre `stress_main.gd`, el arnés de
benchmark. Antes de dar la migración por buena de verdad, faltaba probarla
donde el jugador la va a usar: la pantalla jugable real
(`level_controller.gd`, `Level1.tscn`), con los 8 tipos colocados de
verdad y estadísticas reales (`real-stats`, nuevo flag CLI — pone
`DEV_RANGE_OVERRIDE`/`DEV_FIRE_RATE_OVERRIDE` en 0.0 para esa corrida, sin
tocar el default que sigue usando la verificación visual de siempre).

**Primer resultado, familia BEAM aislada (`place-types=5,6`, stats reales,
30s): 0 muertes.** Ni lanzallamas ni láser mataron un solo enemigo en 30
segundos — sospechoso, porque la geometría de `_tick_beam()` ya corrió sin
errores miles de veces en el benchmark conjunto.

**Causa: `level_controller.gd` nunca instanció ni tickeaba `DotSystem`.**
`stress_main.gd` sí lo hace desde que se congelaron los 7 tipos (sección 1)
— la pantalla jugable real, no. `_tick_beam()`/`_tick_laser()` (antes) sí
escribían `enemy_store.dot_dps`/`dot_time_left` correctamente, pero nada
en `Level1.tscn` los consumía para restarle vida a `health` — el DoT nunca
hizo daño en la pantalla real desde que existe, solo se medía "vivo" en el
benchmark sintético. No es un bug de esta migración — es un gap que esta
migración expuso al ser la primera vez que alguien corrió láser/lanzallamas
contra enemigos reales fuera de `stress_main.gd`.

**Fix:** `level_controller.gd` instancia `DotSystem` en `_ready()` y lo
tickea en `_process()`, mismo patrón que `stress_main.gd`.

### Verificación por tipo, aislado, con el fix (stats reales, 30s, 8 torres del mismo tipo salvo donde se indica)

| Configuración | Muertes | Activos al final | Leaks |
|---|---|---|---|
| Lanzallamas solo (×8) | 19 | 6 | 0 |
| Láser solo (×8) | 23 | 2 | 0 |
| Riel solo (×8) | 25 | 0 | 0 |
| BEAM combinado (5+6 alternados, ×8) | 21 | 4 | 0 |
| **Los 8 tipos juntos** (`place-all-towers`) | 27 | 0 | 0 |

Cero leaks en todos los casos — todo enemigo que se spawneó murió antes de
llegar a la meta, con estadísticas reales (no `DEV_RANGE_OVERRIDE`), en la
pantalla jugable de verdad. Captura de la corrida combinada:
`level1_screenshot_t14.png` (8 torres de los 8 colores en la zona gris,
proyectiles activos en el carril).

---

## 10. ¿Cuesta el targeting? (09-ago, prueba breve)

Pregunta puntual: ¿cuánto cuesta que una torre "elija" a quién dispararle
(`_find_nearest_enemy()`, brute-force sobre `enemy_store.active_count`)
contra no elegir nada? `mode=targeting` (nuevo, `stress_main.gd`): 24
torres, 2.400 enemigos reales (mismo objetivo ×1.2 de siempre), cadencia
forzada a 20 disparos/seg por torre (bien por encima del fire_rate real,
para que el costo se note si existe) — única diferencia entre las dos
corridas es la dirección: `targeting-variant=fixed` (fija, sin buscar
nada) vs `=nearest` (la búsqueda real).

| Variante | avg fps | fps mínimo |
|---|---|---|
| `fixed` (sin targeting) | 124.8 | 81.2 |
| `nearest` (con targeting) | 116.0 | 76.2 |

**Sí cuesta, pero poco — y solo a la cadencia forzada de esta prueba.**
~7% de diferencia (unos 0.6ms/frame para las 24 torres juntas) a 20
disparos/seg por torre. El fire_rate real del catálogo ronda 1 disparo/seg
— a esa cadencia el costo medido acá escala ÷20, así que en juego real es
indistinguible del ruido de medición. No hace falta optimizar
`_find_nearest_enemy()` con esto — el número que importaría vigilar es
cadencia × torres, no la búsqueda en sí.

> **PM — idea de diseño, 09-ago, con una aclaración de nomenclatura
> importante.** Esta prueba mide **targeting** (`_find_nearest_enemy()` —
> a qué enemigo apunta una torre al elegir blanco), no **homing**
> (`PROJ_HOMING`/`_steer_homing()` — el proyectil re-apuntando en vuelo
> tick a tick, un mecanismo distinto, ya medido aparte desde Sprint 2, y ya
> naturalmente acotado a un solo tipo de torre, la Homing). Hoy
> `_find_nearest_enemy()` lo usan casi todas las torres del catálogo
> (recto, perforante, splash, misil, homing — todas menos beam/riel que
> targetean distinto), así que "limitarlo a ciertas torretas" sería un
> cambio de diseño real, no uno chico: el resto pasaría a necesitar un modo
> de targeting "tonto" (fijo, orden de spawn, aleatorio) como comportamiento
> base, y "busca al más cercano" se volvería una mejora que se gana, no el
> default.
>
> **Vale la pena explorarlo como palanca de diseño** (diferenciar torres
> baratas/tontas de torres mejoradas/inteligentes, con costo real como
> justificación narrativa) — pero que quede claro: **la propia medición de
> arriba dice que no hace falta por rendimiento.** Si se persigue, es una
> decisión de gameplay/progresión, no una respuesta a un problema de
> motor. No implementar esto todavía — es una idea para la lista de
> calibración de combate, no una tarjeta activa.

---

## 11. Costo de `TypedRenderGroup` con textura real en varios `type_id` (09-ago) — cierra punto 4 de `plan-fases.md`

Pregunta puntual, distinta a todo lo medido hasta acá: las 20 torretas del
catálogo van a tener sprite propio, lo que significa un `MultiMeshInstance2D`
(y un bind de textura) **por `type_id` presente**, vía `TypedRenderGroup` —
no el `EntityRenderSync` + `set_type_colors()` compartido que usa
`_tower_render` en el resto de los modos de `stress_main.gd`. Ningún banco
corrido hasta ahora (ni éste, ni `fase2-vfx-benchmark.md`) ejercita ese
camino de render a población real. No hace falta arte final para probarlo —
alcanza con reusar `torreta_recta_v2.png` (el placeholder ya recortado y
cuadrado, `smoke-test-motor-arte-v1.md` sección 14) asignado a los 8
`type_id` a la vez, misma imagen en los 8 pero 8 binds de textura reales, no
uno solo. Sin costo de créditos de Arte.

**Cómo se corrió:** nuevo flag `tower-sprite-test=1` en `stress_main.gd` —
reemplaza `_tower_render` (EntityRenderSync, color plano) por un
`TypedRenderGroup` con `set_sprite_for_type(t, tex, tex)` para los 8 tipos,
mismo `torreta_recta_v2.png` en todos. Resto del banco sin cambios:
`mode=joint proj-type=realistic`, población ×1.2 completa (2.400/~3.400-3.600/24),
backend nativo, **en ventana, Vulkan real** (confirmado
`Vulkan 1.3.260 - Forward+ - Using Device #0: AMD - Radeon RX Vega` en las
6 corridas). Verificado por captura que el sprite realmente se está
dibujando, no cayendo a un fallback silencioso
(`stress_joint_towers_row_check.png` — torretas reconocibles, no cuadrados
de color). 3 pares baseline/texturizado, mismo método A/B de siempre.

| Corrida | Baseline (color plano) avg fps | Con textura real (8 type_id) avg fps |
|---|---|---|
| 1 | 64.71 | 61.93 |
| 2 | 64.94 | 63.82 |
| 3 | 64.85 | 62.71 |
| **Promedio** | **64.83** | **62.82** |

**Corrección (Dirección, 09-ago): el piso reportado abajo originalmente era
un promedio de los pisos de cada corrida, no el piso de cada corrida por
separado** — la misma vara que ya usaba la sección 8 (cero muestras bajo
60) no se aplicó acá sin avisar que era un criterio distinto. Desglose real,
sin volver a correr nada (los CSV de `BenchmarkLogger` de las 6 corridas ya
lo tenían):

| Corrida | Piso individual | Muestras bajo 60fps |
|---|---|---|
| Baseline 1 | 50.5 | 2/25 |
| Baseline 2 | 53.6 | 2/25 |
| Baseline 3 | 49.9 | 2/24 |
| Texturizado 1 | 49.3 | 5/23 |
| Texturizado 2 | 49.3 | 4/24 |
| Texturizado 3 | 52.5 | 6/24 |

**Las 6 corridas tienen muestras por debajo de 60fps — no es una sola
corrida arrastrando el promedio.** Antes de aceptar esto como "inconsistencia
del piso de `mode=joint`" sin más (la lectura por defecto, dado que
`fase2-benchmark-conjunto.md` sección 8 sí había cerrado limpio, cero
muestras bajo 60, dos corridas), investigué la causa en vez de etiquetarlo
ruido — exactamente lo que ya se había hecho mal una vez hoy mismo, en la
revisión de T4 (`definicion-escala-v1.md`).

**Causa 1, confirmada — captura de pantalla del propio arnés.**
`_maybe_screenshot()` llama `get_viewport().get_texture().get_image()` (una
lectura síncrona de GPU) en `t=5.0s` (`_shot_times[0]` para `mode=joint`,
`total_time=10.0`, `[total_time*0.5, total_time*0.95]`). Las 6 corridas
tienen su peor muestra (49.3-53.6fps) concentrada exactamente en la
ventana `elapsed≈5.0-5.5s` — no es coincidencia: esa función no corre en
`--headless` (confirmado antes de este hallazgo, en la revisión de T4 de
hoy, las corridas headless no mostraban este patrón concentrado en un
punto fijo, sino ruido disperso a lo largo de toda la corrida o ninguna
muestra baja en absoluto). Agregado `no-screenshot=1` (nuevo flag,
diagnóstico) para aislarlo sin tocar nada más — 2 corridas de control
(1 baseline, 1 texturizado, misma población, ventana, Vulkan real) con el
flag activo: el piso sube a 56.4-57.3fps, la muestra de ~49-53fps
desaparece por completo.

**Causa 2, evidencia fuerte pero no aislada del todo — ráfagas de
reposición del arnés sintético.** Con la captura ya descartada, sigue
habiendo un dip más chico (56-59fps) recurrente cada ~2.1-2.2s, presente
por igual en baseline y texturizado (no lo causa esta tarjeta). Correlaciona
con claridad con caídas periódicas de `proj_count` en el mismo CSV (ej.
`stress_joint_1786304971.csv`: proj cae de 3587 a 3010 entre `t=2.11s` y
`t=3.07s`, fps cae de 68.7 a 59.4-59.7 en la misma ventana) — consistente
con que muchos proyectiles inyectados juntos durante la rampa comparten
vida útil similar y expiran en tandas sincronizadas, y `_top_up_projectiles()`
reponiendo esa tanda de golpe (acotado a `MAX_SPAWN_PER_FRAME=300`, con
resolución de tipo por RNG por cada spawn) cuesta más CPU por frame que el
tick estacionario del resto de la corrida. Mismo espíritu que el hallazgo
de PROJ_ZONE en la sección 2 de este documento: un artefacto del método de
inyección sintética del arnés, no necesariamente un costo del juego real
(que nunca repone población a un objetivo fijo frame a frame — las torres
disparan a su propia cadencia). **No lo doy por probado al 100%** — la
correlación es clara pero no instrumenté el conteo de spawns por frame
para confirmarlo de forma directa; queda como hipótesis fuerte, no hecho
cerrado.

**Lo que esto no cambia:** la Causa 2 afecta por igual a baseline y
texturizado (aparece en ambos, con o sin el flag de esta tarjeta), así que
no invalida la comparación A/B de la sección de arriba (~3% de costo
incremental por las 8 texturas) — esa lectura sigue en pie. Lo que sí
cambia: la afirmación de "ambas condiciones se sostienen cómodas arriba de
60fps de promedio" de más abajo describía un promedio, no el estándar de
"cero muestras bajo 60" que cerró la sección 8 — con ese estándar, ninguna
de las 6 corridas de hoy cierra limpio todavía, con o sin las texturas de
esta tarjeta.

### Lectura

**Sí cuesta, de forma chica pero consistente y reproducible — no es
ruido.** ~2fps de promedio (~3%) en las tres corridas, siempre en la misma
dirección (texturizado por debajo de baseline las 3 veces, nunca al revés).
La diferencia sobrevive incluso descontando el ruido de corrida a corrida
ya identificado arriba (captura de pantalla + ráfagas de reposición) porque
esas dos causas afectan a baseline y texturizado por igual — el ~3% es el
delta que queda *después* de esas dos fuentes de ruido, no confundido con
ellas.

**No pone en riesgo el promedio del objetivo, pero el piso de `mode=joint`
en sí todavía no cierra limpio contra el estándar de la sección 8** (ver
arriba) — eso es anterior a esta tarjeta, no causado por las texturas. El
costo de pasar de 1 draw call de torres a 8 no compite en magnitud con lo
que ya se resolvió en la sección 8 (la migración BEAM). Con las 20 torretas
reales del catálogo (más `type_id` que las 8 de hoy, pero cada una con su
propio bind también hoy en el diseño actual), el costo esperado escala con
cantidad de tipos *presentes*, no con cantidad de torres — 8 tipos ya
cuestan lo medido acá aunque hubiera 3 o 30 torres de cada uno, mismo
principio que ya confirmó `fase2-vfx-benchmark.md` para partículas/overdraw
("costo fijo de tener el efecto presente, no por cuánto se agrega").

**Tarjeta del punto 4 de `plan-fases.md` ejecutada** — dato listo para que
Dirección/PM decida el cierre de ese punto (y de Fase 2 del lado de motor);
no lo cierro acá, ese documento es de alcance restringido a Dirección de
Desarrollo/PM.

## 12. ¿La Causa 2 aparece en `Level1.tscn` real? (09-ago) — pedido de Dirección

Pregunta puntual de Dirección, en vez de seguir instrumentando el arnés
sintético: correr la misma población (2.400 enemigos, 24 torres) por el
camino de producción real (`Level1.tscn`, `BenchmarkLogger` ya cableado
detrás de `stress-test`) y ver si el dip periódico de la Causa 2 (sección
11) aparece ahí también. Si no aparece, es un artefacto del arnés
(`_top_up_projectiles()` no existe fuera de `stress_main.gd`, igual que
`_maybe_screenshot()` de la Causa 1). Si aparece, es un hallazgo real de
motor.

### La pantalla nunca había corrido a esta escala — 4 gaps encontrados, los 4 necesarios para tener un dato real

`stress-test stress-towers=24 stress-enemies=2400 real-stats` no dio un
número usable en el primer intento — dio tres números distintos, cada uno
sin sentido por una razón distinta, hasta corregir:

1. **`MAX_ENEMIES := 360`** — tope duro muy por debajo de 2.400 (heredado
   del stress-test original de esta pantalla, pensado contra 300, nunca
   contra el objetivo real de T2/T4). Primer intento: `enemigos activos:
   360`, la rampa se cortaba ahí. Subido a 2.500.
2. **Grilla de torres fuera de rango.** `_setup_stress_test()` barría toda
   la zona construible hacia la derecha (hasta x=410+); los enemigos
   caminan pegados a `waypoints` (`level_01.tres`), no por todo
   `path_rects` — con `real-stats` (rango real 170-260px) nunca llegaban.
   Resultado con el tope ya corregido: `proyectiles activos: 0, muertes:
   0` en 15s con 2.400 enemigos activos. Reescrito a dos columnas pegadas
   al borde del carril (x=30/100, mismo x que ya probó
   `_place_all_types_test()` con muertes reales, sección 9).
3. **Spawn concentrado en `spawn_point`.** `_stress_top_up_enemies()`
   spawneaba todo en `spawn_point + jitter` chico — con salud alta (no se
   filtra por muertes, por diseño) y sin nada más una vez alcanzado el
   objetivo, arma una sola "ola" densa que avanza en bloque y cruza casi
   todas las torres en el mismo instante, no una población en régimen
   distribuida por todo el carril (que es como spawnea `mode=joint`, vía
   `_random_point_in_path()`). Corregido al mismo patrón — necesario para
   que la comparación contra la sección 11 sea real, no solo para que
   "ande".
4. **Vsync nunca desactivado en esta pantalla.** `stress_main.gd` ya tenía
   el fix de `fase2-vfx-benchmark.md` sección 3 (monitor a 144Hz
   enmascarando el techo real); `level_controller.gd` nunca lo heredó
   porque nunca se había corrido a población real antes de hoy. Sin esto,
   el primer resultado con los 3 fixes de arriba ya aplicados daba fps
   sospechosamente redondos (120.0/110.0/100.0 exactos) — el techo del
   monitor, no el motor. Agregado el mismo guard que ya usa
   `stress_main.gd`.

Los 4 son correcciones necesarias para obtener cualquier dato, no
construcción nueva más allá de lo que pedía la pregunta — pero vale
dejarlo anotado: **esta pantalla nunca se había verificado a la población
real de T2/T4 antes de hoy**, ni siquiera de forma incidental. Los tests
de la sección 9 (27 muertes, 0 leaks) corrieron con `ENEMY_HEALTH` normal
y sin barrer la escala completa.

### Resultado, con los 4 fixes aplicados — 3 corridas de confirmación

Ventana, Vulkan real, `real-stats`, mismo objetivo ×1.2 de siempre
(2.400/24):

| Corrida | Piso | Techo | Promedio | Muestras bajo 60fps |
|---|---|---|---|---|
| 1 | 78.6 | 300.8 | 112.85 | 0/110 |
| 2 | 78.3 | 301.9 | 112.63 | 0/110 |
| 3 | 80.2 | 301.6 | 113.49 | 0/111 |

**El dip periódico no aparece.** Sin correlación visible entre `proj_count`
y `fps` (a diferencia de la sección 11, donde las caídas de `proj_count`
coincidían con las caídas de fps de forma clara) — acá el fps baja de
forma suave y monotónica a lo largo de la corrida (rampa de vsync
desactivado asentándose, no un patrón periódico), sin ningún valle por
debajo de 60fps en ninguna de las 3 corridas. Piso ~78-80fps, muy por
encima del umbral, con margen real de sobra incluso para el 20% de T4.

**Confirma la Causa 2 como artefacto del arnés, no hallazgo de motor** —
mismo diagnóstico que la Causa 1: `_top_up_projectiles()` (el mecanismo
cuyo costo de ráfaga correlacionaba con los dips de la sección 11) no
existe fuera de `stress_main.gd`; el camino de producción repone
proyectiles disparo a disparo, a la cadencia real de cada torre, nunca en
lote. Por construcción, no por argumento — mismo criterio que ya cerró la
Causa 1.

Dato completo para Dirección/PM — no cierro el punto 4 ni Fase 2 acá.

---

**Herramientas nuevas en `level_controller.gd`**, quedan disponibles para
la próxima vez que haga falta verificar algo en esta pantalla sin pasar por
`stress_main.gd`: `place-all-towers` (los 8 tipos, uno de cada), `place-types=<csv>`
(subconjunto arbitrario, para aislar como arriba), `real-stats` (stats
reales en vez del override de desarrollo). `LaneEnemySystem.killed_count`
(nuevo, junto a `leaked_count` que ya existía) — necesario para poder
distinguir "murió por daño" de "llegó vivo a la meta" sin instrumentación
ad-hoc.
