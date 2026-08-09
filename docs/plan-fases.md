> **Documento de alcance restringido.** Solo Dirección de Desarrollo y PM
> pueden modificar este archivo (agregar/cerrar criterios, mover el límite
> entre fases). Motor, Arte y Auditor pueden y deben seguir escribiendo
> tarjetas y hallazgos en sus propios documentos de fase — lo que no
> corresponde es que una tarjeta cierre un criterio acá directamente. Si
> algo acá parece bloquear trabajo real, es una señal para plantearlo, no
> para editarlo. Firmado — Dirección de Desarrollo, 09-ago-2026.

# Plan de fases — motor → jugable → arte real

**Rol:** Product Manager / coordinador.
**Fecha:** 09-ago-2026.
**Por qué existe este documento:** el proyecto viene usando "Fase 1", "Fase
2" en los nombres de archivo (`fase2-plan-proyectiles.md`,
`fase2-benchmark-conjunto.md`, etc.) desde que se abandonó la cadencia de
sprints con fecha (`sprint-plan.md`), pero el alcance de cada fase nunca
quedó escrito en un solo lugar — se infería del contexto. Esto lo hace
explícito, para que "cerrar Fase 2" tenga un criterio de salida claro en vez
de discutirse cada vez que se acerca.

---

## Fase 1 — Cimientos (Sprint 1-2, cerrada)

Decisión de motor (Godot + GDExtension/Rust), número objetivo de escala,
hardware mínimo (T4), documento de combate v1 (T3), variedad de proyectiles
(T5), postura de multijugador (T6), spike técnico (Ruta B alcanza el
objetivo de T2). Ver `definicion-escala-v1.md` — checklist completo,
**sin pendientes.**

---

## Fase 2 — Cerrar el motor de juego (en curso)

**Alcance: exclusivamente simulación/motor.** Que el core (`game/sim/`,
`game/render/`, `game/rust/`) sostenga el objetivo de escala (2.000-3.000
enemigos, 3.000-3.600 proyectiles, 20-24 torres, ×1.2 de margen de T4) a
60fps, con los tipos de torreta/proyectil ya congelados (recto, homing,
perforante, splash, misil, BEAM ×2 — fuego y láser —, riel). **No incluye
arte real, balance de combate, niveles, ni progresión** — eso es Fase 3/4,
ver abajo. El placeholder de color plano (`level_controller.gd::TYPE_COLORS`)
es infraestructura suficiente para cerrar Fase 2; no bloquea nada que el
motor tenga que resolver.

**Criterio de cierre — 4 de 4 puntos cumplidos (Dirección, 09-ago):**

1. ~~Benchmark de pico conjunto sostenido por encima de 60fps con margen del
   20%~~ — **hecho** (`fase2-benchmark-conjunto.md` sección 8, dos corridas
   limpias 60.3-87fps).
2. ~~Confirmar que el margen sigue vigente con costo de GPU real (filtro de
   texturas/mipmaps)~~ — **hecho, con una corrección de por medio**
   (`definicion-escala-v1.md`, revisión Mesa de Developers 09-ago: sin
   caída medible en los dos bancos). El valor de enum aplicado en
   `project.godot` estaba invertido (quedó `Nearest+Mipmaps` en vez de
   `Linear+Mipmaps` por un razonamiento con una premisa falsa, ver
   `smoke-test-motor-arte-v1.md` sección 15) — corregido. No cambia el
   veredicto de costo (ambos filtros son igual de baratos en fps), pero si
   no se corregía, la ronda 3 de Arte se iba a evaluar contra el filtro
   equivocado.
3. Catálogo de tipos de torreta/proyectil sin ambigüedad de nombres —
   **hecho** (Mortero/Misil, Fuego/Lanzallamas, y ahora Láser como arma
   propia, `docs-torretas-diseno.md` #21).
4. ~~Costo de GPU con texturas reales en las 24 entidades del pico
   conjunto, no solo una~~ — **hecho** (ver la cadena completa abajo: tres
   rondas de revisión, cerrado con una corrida en `Level1.tscn` real,
   78.3-80.2fps de piso, cero muestras bajo 60). Los bancos que confirmaron
   el punto 2 no ejercitan esto: `mode=joint` no renderiza ninguna textura
   (quads de color plano — confirmado en código, no supuesto), y
   `mode=vfx` ejercita texturas reales de partículas/overdraw pero no el
   camino de render que van a usar las 20 torretas con sprite propio
   (`TypedRenderGroup`, un `MultiMeshInstance2D` — y un bind de textura —
   por `type_id` presente, no uno solo). Con 20 torretas de catálogo
   distintas eventualmente, eso son hasta 20 draw calls de torre en vez de
   1, más los binds de textura de enemigos/proyectiles si también reciben
   sprite — un eje de costo real que ningún benchmark corrido hasta ahora
   mide. No hace falta arte final para probarlo: alcanza con reusar
   `torreta_recta_v2.png` (u otro placeholder) asignado a varios `type_id`
   a la vez a través de `TypedRenderGroup` en `mode=joint`, población
   completa. Tarjeta para Mesa de Developers, sin costo de créditos de
   Arte.
   > **Mesa de Developers, 09-ago — tarjeta ejecutada, resultado en
   > `fase2-benchmark-conjunto.md` sección 11.** Costo chico pero
   > consistente (~2fps / ~3% de promedio en 3 pares baseline/texturizado,
   > mismo sentido las 3 veces), piso sin diferencia medible — no pone en
   > riesgo el objetivo. Dato listo para que Dirección/PM decida si esto
   > cierra el punto o hace falta algo más — no lo cierro yo acá, ver la
   > nota de alcance al principio de este documento.
   >
   > **Dirección, 09-ago — el costo incremental queda aceptado, el punto
   > sigue sin cerrar por una razón distinta.** El ~3% de las 8 texturas
   > está bien medido y no es el problema. Lo que no cierra es el piso en
   > sí: `fase2-benchmark-conjunto.md` sección 11 reporta 51.3fps/50.4fps
   > como **promedio de los pisos** de las 3 corridas — no el piso de cada
   > corrida por separado. La sección 8 (la corrida histórica que sí valida
   > Fase 2) puso la barra en el mínimo de cada muestra ("cero muestras bajo
   > 60"), no en un promedio; esta sección la corre contra el promedio
   > ("ambas condiciones se sostienen cómodas arriba de 60fps de promedio")
   > sin marcar que es una vara distinta. Y el mismo número (~51fps de piso)
   > ya había aparecido hoy en la revisión de T4 de `definicion-escala-v1.md`
   > en una corrida de `mode=joint` sin ningún cambio de por medio, etiquetado
   > ahí como "varianza de medición... no regresión" sin verificarlo. Dos
   > apariciones del mismo número en el mismo día sin investigar todavía es
   > una coincidencia que vale mirar, no una explicación.
   >
   > **Pido el desglose de piso por corrida** (probablemente ya está en los
   > CSV de `BenchmarkLogger` de las 6 corridas de hoy, no hace falta volver
   > a correr nada) — si las 6 rondan holgadas por encima de 60 y solo el
   > promedio se ve arrastrado por una corrida puntual, cierro el punto sin
   > más trámite. Si "varias muestras bajo 60" del comentario de T4 se repite
   > en más de una corrida de las 6, eso es una inconsistencia del piso de
   > `mode=joint` en sí — anterior a esta tarjeta y a la migración BEAM, no
   > causada por las texturas — y ameritaría entender la causa (¿la fase de
   > rampa del spawner realmente termina antes de que arranque la medición
   > de piso, o no?) antes de dar Fase 2 por cerrada del lado de motor.
   >
   > **Mesa de Developers, 09-ago — desglose hecho, no fue una corrida
   > arrastrando el promedio: las 6 tienen muestras bajo 60fps** (2/25,
   > 2/25, 2/24 en baseline; 5/23, 4/24, 6/24 en texturizado — tabla completa
   > en `fase2-benchmark-conjunto.md` sección 11). Investigué la causa en
   > vez de repetir el error de hoy con T4 (etiquetar "varianza" sin
   > verificar). Dos causas, no una:
   >
   > 1. **Confirmada:** `_maybe_screenshot()` hace una lectura síncrona de
   >    GPU a `t=5.0s` fijo — coincide exacto con la peor muestra de las 6
   >    corridas (49.3-53.6fps, todas en `elapsed≈5.0-5.5s`). Corrida de
   >    control con la captura desactivada (`no-screenshot=1`, flag nuevo):
   >    esa muestra desaparece, el piso sube a 56-57fps.
   > 2. **Hipótesis fuerte, no aislada al 100%:** con la captura ya
   >    descartada, sigue habiendo un dip más chico (56-59fps) cada
   >    ~2.1-2.2s, presente por igual con y sin las texturas de esta
   >    tarjeta — correlaciona con caídas periódicas de `proj_count` en el
   >    mismo CSV, consistente con ráfagas de reposición del inyector
   >    sintético (`_top_up_projectiles()`) después de que un lote de
   >    proyectiles spawneados juntos durante la rampa expira junto. Mismo
   >    espíritu que el hallazgo de PROJ_ZONE de la sección 2 — probable
   >    artefacto del método del arnés, no necesariamente costo del juego
   >    real — pero no instrumenté el conteo de spawns por frame para
   >    confirmarlo de forma directa, así que lo dejo como hipótesis fuerte,
   >    no hecho cerrado.
   >
   > **La causa 2 afecta por igual a baseline y texturizado, así que no
   > invalida el ~3% de costo incremental de las 8 texturas** (esa
   > comparación A/B sigue en pie) — pero sí significa que, con el mismo
   > estándar que cerró la sección 8 (cero muestras bajo 60), ninguna de
   > las 6 corridas de hoy cierra limpio todavía, con o sin las texturas de
   > esta tarjeta. No cierro el punto 4 ni Fase 2 — dato completo para que
   > Dirección/PM decida si esto alcanza (el promedio no está en riesgo, la
   > causa 1 ya no aplica en juego real porque `Level1.tscn` no hace
   > capturas de pantalla) o si vale la pena aislar la causa 2 del todo
   > antes de cerrar.
   >
   > **Dirección, 09-ago.** Esta sí es la investigación que pedía — Causa 1
   > queda aceptada como cerrada (correlación de timing exacta más corrida
   > de control aislándola, no una historia sin verificar) y es irrelevante
   > para el juego real por construcción: `_maybe_screenshot()` es exclusivo
   > de `stress_main.gd`, `Level1.tscn` nunca lo llama. Buena disciplina de
   > proceso también — citaron su propio error de hoy con T4 en vez de
   > repetirlo. Vale seguir así.
   >
   > **No cierro todavía, por un paso más — barato, no una reapertura.**
   > Causa 2 tiene la misma propiedad que la Causa 1 (`_top_up_projectiles()`
   > también es exclusivo del arnés sintético — el juego real nunca repone
   > población a un objetivo fijo, cada torre dispara a su propia cadencia
   > independiente), pero sigue en "hipótesis fuerte", no confirmada. En vez
   > de pedir instrumentar conteo de spawns por frame dentro del arnés
   > (seguir puliendo una herramienta sintética), pido el chequeo más directo:
   > correr la misma población por `Level1.tscn` (que ya tiene
   > `BenchmarkLogger` cableado detrás de `stress-test`, no hace falta
   > construir nada) y ver si el dip periódico de ~2.1s aparece ahí también.
   > Si no aparece — el camino de producción real no tiene el patrón, tal
   > como predice la Causa 2 — cierro el punto 4 y Fase 2 del lado de motor
   > con ese dato, sin otra ronda. Si aparece igual en `Level1.tscn`, es un
   > hallazgo real de motor y no un artefacto del arnés, y ahí sí ameritaría
   > mirarlo a fondo antes de cerrar.
   >
   > **Mesa de Developers, 09-ago — corrido, el dip no aparece.** "No hace
   > falta construir nada" resultó optimista: `stress-test
   > stress-towers=24 stress-enemies=2400 real-stats` no dio un número
   > usable hasta corregir 4 gaps, los 4 necesarios solo para tener un dato
   > (no agregado extra) — el detalle completo está en
   > `fase2-benchmark-conjunto.md` sección 12: `MAX_ENEMIES` era un tope de
   > 360 (heredado del stress-test original de esta pantalla, nunca pensado
   > contra la escala de T2/T4), la grilla de torres quedaba fuera de rango
   > real, el spawner sintético concentraba todo en `spawn_point` en vez de
   > repartirlo por el carril (arma una "ola" en vez de población en
   > régimen), y esta pantalla nunca había desactivado vsync (mismo bug de
   > techo de monitor que ya se había encontrado y corregido en
   > `stress_main.gd`, nunca heredado acá). Ninguno es diseño a propósito —
   > los 4 son gaps de una pantalla que nunca se había corrido a la
   > población real de T2/T4 antes de hoy.
   >
   > Con los 4 corregidos, 3 corridas de confirmación (ventana, Vulkan
   > real, mismo objetivo ×1.2): **piso 78.3-80.2fps, cero muestras bajo
   > 60fps en las tres.** Sin la correlación proj_count/fps que sí se veía
   > en la sección 11 — el fps baja suave y monótono, no en dips
   > periódicos. Confirma la Causa 2 como artefacto del arnés, mismo
   > criterio que ya cerró la Causa 1: `_top_up_projectiles()` tampoco
   > existe fuera de `stress_main.gd`, el camino de producción repone
   > proyectiles disparo a disparo a la cadencia real de cada torre, nunca
   > en lote.
   >
   > No cierro el punto 4 ni Fase 2 yo — dato completo para que
   > Dirección/PM lo haga.
   >
   > **Dirección, 09-ago — cierro el punto 4.** Piso 78.3-80.2fps, cero
   > muestras bajo 60 en las tres corridas, en el camino de producción real
   > — no el arnés sintético — con el mismo objetivo ×1.2 que validó la
   > sección 8. Eso limpia la duda de fondo que abrí dos veces (que el piso
   > fuera un promedio, no un mínimo real; que el patrón periódico pudiera
   > ser costo real de motor) con el estándar más fuerte posible: la escena
   > que de verdad va a jugar el usuario, no una comparación indirecta. Los
   > 4 gaps que encontraron en el camino no me preocupan — son síntomas
   > concretos y verificables (tope duro, 0 muertes, fps redondos), no
   > decisiones de diseño discutibles, y cada uno se explica solo.
   >
   > Vale decirlo explícito: dos rondas seguidas pidiendo "un paso más" y
   > las dos veces la investigación resolvió la duda de verdad en vez de
   > taparla — esa es la disciplina que este documento existe para proteger.
   > Punto 4: **hecho.**
   >
   > **Mesa de Developers, 09-ago — información nueva, posterior al cierre,
   > no una reapertura de la sección 12.** Pedido del usuario: repetir la
   > corrida de la sección 12 con textura real en los 3 grupos (torres,
   > enemigos, fondo — no solo torres) y forzando `proj_count` al objetivo
   > real (~3.600), que la sección 12 nunca empujó. Detalle completo en
   > `fase2-benchmark-conjunto.md` sección 13. Dos hallazgos:
   >
   > 1. Encontré y corregí un bug real en `TowerSystem.tick()` en el camino
   >    (necesario para poder forzar la cadencia lo suficiente) — expuesto
   >    por la regresión de siempre, no a ojo: `place-all-towers real-stats`
   >    pasó de 6 a 120 proyectiles activos sin que el cambio debiera
   >    tocar ese caso. Corregido, reconfirmado en 6.
   > 2. **`level_controller.gd` nunca usó el backend nativo** —
   >    `_proj_system.tick()` (GDScript), nunca `tick_native()`
   >    (`SimHotPath`), a diferencia de `stress_main.gd` desde el principio
   >    de este documento. Nunca se notó porque ningún test en esta pantalla
   >    había sostenido suficientes proyectiles reales para que importe
   >    (sección 12: máximo ~17). A población moderada (~500 proyectiles,
   >    ya bien por encima de cualquier cadencia de diseño real): GDScript
   >    da piso 43.1fps/44 de 53 muestras bajo 60; con `backend=native`
   >    (agregado como flag, sin cambiar el default) piso 52.4-55.2fps/1-2
   >    de 73-74 bajo 60. La diferencia es varias veces mayor que cualquier
   >    costo de textura medido hasta ahora.
   >
   > No reabro el punto 4 — la pregunta que cerraba (¿aparece el dip
   > periódico en producción?) sigue resuelta, y esto es un eje de costo
   > distinto (backend de colisión, no textura ni población sintética). Pero
   > es información real sobre la pantalla que Fase 2 dio por cerrada, así
   > que la dejo escrita en vez de guardármela. Dos preguntas abiertas, sin
   > decidir yo: ¿pasa `Level1.tscn` a `backend=native` por default?
   > ¿`_find_nearest_enemy()` necesita dejar de ser brute-force para las 20
   > torretas reales del catálogo, o alcanza con que solo BEAM/RAIL usen el
   > hash (rango acotado) como hoy?
   >
   > **Dirección, 09-ago.** Acepto el encuadre — el punto 4 en sí no se
   > reabre, la pregunta que cerraba sigue contestada. Pero tengo que
   > corregirme algo a mí mismo: cuando cerré el punto 4 cité la sección 12
   > como validación "con el mismo objetivo ×1.2 que la sección 8" — eso no
   > era cierto, y no lo sabía en ese momento. La sección 12 nunca pasó de
   > ~17 proyectiles reales; el techo estructural que lo impedía recién se
   > encontró hoy. Lo que la sección 12 sí validó (que el dip periódico es
   > artefacto del arnés) se sostiene igual — pero "la escena real aguanta a
   > escala real" nunca estuvo probado hasta esta tarjeta, y no debí
   > describirlo como si lo estuviera. Dejarlo sin corregir sería peor que
   > el error original.
   >
   > **No deshago el cierre de Fase 2.** Los puntos 1-3 no dependen de nada
   > de esto, y la comparación de costo de textura del punto 4 tampoco — la
   > arquitectura ya la sostiene (costo por tipo de textura presente, no por
   > cantidad de instancias, confirmado independientemente en las secciones
   > 8, 11 y ahora 13). Pero esto **sí es más grande que "una pregunta
   > distinta"**: es la primera vez que se sabe que la pantalla que
   > realmente va a jugar el usuario (`run/main_scene` en `project.godot`)
   > no aguanta el objetivo de escala — con o sin textura, por dos causas
   > que ni siquiera son la que se estaba buscando. Lo trato como condición
   > de arranque de contenido real, no como punto 5 de un criterio ya
   > cerrado:
   >
   > **Antes de que Fase 3 calibre ningún número de combate sobre
   > `Level1.tscn`, esto tiene que estar resuelto — bloquea contenido, no
   > bloquea diseño/alcance.**
   > 1. `backend=native` pasa a default en `Level1.tscn` — **sí, decidido.**
   >    El dato no deja margen de duda (43fps→52-55fps de piso a población
   >    moderada, ya con muestras bajo 60 en ambos casos, así que ninguno de
   >    los dos es "opcional"), `stress_main.gd` lo prueba hace rato sin
   >    problema, y la regresión de hoy ya salió limpia. No hace falta otra
   >    ronda para esto — ejecútenlo.
   > 2. `_find_nearest_enemy()` — no decido todavía, pido un solo dato más:
   >    proj_count real (~3.600) con `backend=native` ya activo, no
   >    GDScript. Sección 13 mide GDScript a ~3.600 (9-11fps) y nativo solo
   >    a ~500 (52-55fps) — nunca los dos juntos en el mismo punto. Ese
   >    número aísla cuánto del catastrófico 9-11fps es backend y cuánto es
   >    targeting; con eso decido si toca extender el hash a las 20 torretas
   >    o alcanza con lo que ya cubre BEAM/RAIL.
   >
   > **Mesa de Developers, 09-ago.**
   >
   > 1. **Ejecutado.** `SimHotPath` se instancia siempre en `_ready()` de
   >    `level_controller.gd`, `_backend_native` default `true`.
   >    `backend=gdscript` queda como override explícito solo para
   >    diagnóstico (usado abajo, para poder seguir comparando). Regresión
   >    (`place-all-towers real-stats`, headless): idéntico de siempre —
   >    `torres: 8, proyectiles activos: 6, muertes: 7, leaks: 0`.
   > 2. **Dato aislado, mismo punto de población, misma sesión** (detalle
   >    completo en `fase2-benchmark-conjunto.md` sección 14) —
   >    `stress-fire-rate=0.004`, texturas en los 3 grupos, ventana, Vulkan
   >    real, un backend después del otro, sin cambiar nada más:
   >
   >    | Backend | proj_count | Piso | Promedio post-rampa |
   >    |---|---|---|---|
   >    | GDScript | 3878-4000 | 7.6 | 8.4 |
   >    | Nativo | 3936-4000 | 7.8 | 10.6 |
   >
   >    **El backend explica casi nada a esta escala** — piso
   >    prácticamente idéntico (7.6 vs 7.8), promedio post-rampa sube
   >    ~25% (8.4→10.6) pero sigue catastrófico. Contraste directo con la
   >    sección 13 a población moderada, donde el mismo cambio de backend
   >    sí movía el piso de forma grande (43→52-55fps). A ~3.600-4.000 el
   >    costo dominante ya no es la colisión que acelera `SimHotPath` — es
   >    `_find_nearest_enemy()`, sin tocar por el backend nativo, escalado
   >    por la cantidad de disparos/frame que hacen falta para sostener esa
   >    población con solo 24 torres. No decido ni implemento el fix del
   >    hash — dato de aislamiento, tal como se pidió.
   >
   > **Dirección, 09-ago — (a) confirmado, (b) no lo hago todavía, y esta
   > vez no pido otro dato: la razón es la condición del test, no el
   > número.** El dato de aislamiento es exactamente lo que pedí y está
   > bien medido — pero mide un caso deliberadamente patológico en dos ejes
   > a la vez: `DEV_RANGE_OVERRIDE` (rango ilimitado, el peor caso posible
   > para brute-force y el que menos favorece al hash) y
   > `stress-fire-rate=0.004` (250 disparos/seg por torre, ~150-400× más
   > rápido que cualquier fila real de `TOWER_TYPE_STATS`, 0.6-1.6s). El
   > propio dato de la sección 14 ya lo dice: rango real ayudaría al hash,
   > cadencia real jamás pediría este volumen de búsquedas. No sé, con lo
   > que hay hoy, si 24-20 torres a fire_rate real generan alguna vez algo
   > cercano a 3.600 proyectiles simultáneos — esa es una pregunta de
   > diseño de combate (Fase 3), no algo que pueda inferir de un test
   > armado para forzar el peor caso.
   >
   > **No construyo el hash para `_find_nearest_enemy()` ahora.** Sería
   > gastar trabajo de motor real contra un escenario que todavía no sé si
   > el juego real produce — exactamente el tipo de apuesta sin medir que
   > este proyecto viene evitando desde el spike de Sprint 2. Queda anotado
   > como riesgo conocido, con gatillo explícito en vez de quedar flotando:
   > **si la calibración de combate de Fase 3 acerca la composición real
   > (rango real, cadencia real) a este volumen de proyectiles, se vuelve a
   > medir bajo esas condiciones — no las de este test — antes de decidir
   > si hace falta.**
   >
   > Con esto, la condición de arranque de contenido queda resuelta: (a)
   > hecho, (b) evaluado y conscientemente no accionado todavía. Nada
   > bloquea que Fase 3 arranque, calibración de combate incluida.
   >
   > **Mesa de Developers, 09-ago — pedido del usuario: pantalla de estrés
   > "última instancia del juego", evitando a propósito rango ilimitado y
   > cadencia patológica.** Detalle completo en `fase2-benchmark-conjunto.md`
   > sección 15. ~100 torres reales (8 tipos), `real-stats` (rango real
   > 170-260px, no `DEV_RANGE_OVERRIDE`), cadencia dentro del límite real de
   > un disparo por tick (`stress-fire-rate=0.02`, con el trade-off anotado
   > explícitamente — no la ráfaga patológica de la sección 13). Resultado:
   > **piso 34.1fps, 52/55 muestras bajo 60** — con un punto de control aún
   > más limpio (`stress-fire-rate=0.03`, sin ambigüedad de tick): piso
   > 38.0fps, tampoco pasa. Con las dos condiciones no-representativas ya
   > afuera, sigue sin sostener el objetivo. No decide nada de Fase 3 ni del
   > hash — dato adicional, tal como pidió el director la vez pasada.
   >
   > **Dirección, 09-ago — esto sí es el gatillo que dejé anotado arriba, y
   > cambio la decisión.** La vez pasada no construí el hash porque la única
   > evidencia combinaba dos condiciones patológicas a la vez (rango
   > ilimitado + cadencia ~150-400× real) y no sabía si algo remotamente
   > parecido ocurriría en juego real. Esta corrida saca las dos — rango
   > real, cadencia que respeta el límite físico de un disparo por tick,
   > incluso un punto de control sin ninguna ambigüedad de timing — y el
   > resultado sigue siendo el mismo problema. Con eso, "gastar trabajo de
   > motor contra un escenario que no sé si el juego produce" deja de
   > aplicar: 100 torres es una composición de progresión tardía plausible
   > (`fase3-alcance-v1.md` ya deja la cantidad de torretas como eje de
   > desbloqueo propio, no exótico), no un extremo sintético.
   >
   > **Tarjeta para Mesa de Developers — generalizar el patrón de
   > `_tick_beam()`, no inventar uno nuevo.** `SpatialHash.query_radius()` +
   > `_nearest_in()` ya existen, ya están probados en producción para la
   > familia BEAM (`tower_system.gd`, sección 7 de
   > `fase2-benchmark-conjunto.md`) — es la misma búsqueda de vecino más
   > cercano que hace falta acá, filtrada por celda en vez de barrer
   > `enemy_store.active_count` completo. Alcance:
   > 1. Los 5 tipos que llaman `_find_nearest_enemy()` en el loop principal
   >    de `tick()` (recto/homing/perforante/splash/misil) — el call site
   >    que la sección 15 mide.
   > 2. `_tick_rail()` también la llama — su propio comentario ("no vale la
   >    pena acotarlo todavía") razonaba sobre frecuencia por-torre
   >    (RAIL_CHARGE=1.2s), no sobre cantidad de torres — con el mismo
   >    helper ya construido para el punto 1, extenderlo acá es marginal,
   >    no una segunda pieza de trabajo.
   > 3. **Verificación:** re-correr el escenario exacto de la sección 15
   >    (100 torres, `real-stats`, `stress-fire-rate=0.02` y el punto de
   >    control 0.03) — objetivo, limpiar 60fps de piso. Más la regresión
   >    estándar completa (`mode=joint` de `stress_main.gd`, no solo
   >    `place-all-towers` de esta pantalla) — esto toca `game/sim/
   >    tower_system.gd`, código compartido por las dos pantallas, no un
   >    cambio acotado a una sola.

**Fase 2 queda cerrada del lado de motor — los 4 puntos cumplidos (09-ago,
Dirección), cierre confirmado, no revertido.** Lo que sigue en vuelo (ronda
3 de arte, triage de las 12 torretas del catálogo sin fila todavía) sigue
siendo Fase 4 adelantada, no bloqueaba nada de esto. Deuda técnica menor
que sigue pendiente sin bloquear nada: `TODO` de
`DEV_RANGE_OVERRIDE`/`DEV_FIRE_RATE_OVERRIDE` en `tower_store.gd` (poner en
0.0 antes de calibrar combate real — tarea de Fase 3); el bug de aspecto
cuadrado ya no está en esta lista — se corrigió en
`smoke-test-motor-arte-v1.md` sección 14.

**Condición de arranque de contenido — resuelta (Dirección, 09-ago).**
`Level1.tscn` no aguantaba el objetivo de escala por dos causas ajenas al
criterio de cierre (backend de colisión, targeting brute-force). Backend:
corregido, `native` ya es el default. Targeting: sigue siendo brute-force
a propósito — el único dato que muestra que pesa viene de un test
deliberadamente patológico (rango ilimitado + cadencia ~150-400× la real),
no de condiciones de juego reales, así que construir el hash ahora sería
apostar sin medir el caso que de verdad importa. Queda como riesgo
conocido con gatillo explícito: si la calibración de combate de Fase 3
acerca la composición real a este volumen de proyectiles, se re-mide bajo
esas condiciones antes de decidir. **Nada bloquea que Fase 3 arranque,
calibración de combate incluida.**

---

## Fase 3 — Jugable (siguiente)

Estadísticas de combate real (calibración, no solo el balance de prueba de
`TOWER_TYPE_STATS`), niveles (`LevelDef` ya tiene el campo de fondo/tema
listo desde Fase 2, falta contenido real de niveles), progresión (economía,
desbloqueo de torres, qué determina qué torres están disponibles cuándo).
Los 12 tipos de torreta del catálogo de 20 que todavía no tienen fila en
`TOWER_TYPE_STATS` (categorías D/E/F + Racimo/Enjambre/Francotiradora/
Serpiente) se implementan acá, a medida que el diseño de progresión los
necesite — no antes.

**Alcance inicial ya capturado:** `fase3-alcance-v1.md` (09-ago) — loop de
colocación → "Comenzar" → ronda, puntos por baja como moneda de desbloqueo
(torres nuevas y cantidad de slots), árbol de mejoras estilo Path of Exile
(ramas globales + ramas por torreta). Es alcance, no números — la
calibración se define cuando Fase 3 arranque de verdad, mismo criterio que
ya usó este proyecto para Fase 2 (no fijar números sobre datos que todavía
no existen). **Habilitada para arrancar** — Fase 2 ya cerró del lado de
motor (09-ago). Primer paso sugerido: la pregunta abierta de
`fase3-alcance-v1.md` sección 4 punto 1 (¿costo de colocación dentro de la
ronda, o el desbloqueo es el único gate?) antes de tocar cualquier número.

---

## Fase 4 — Arte real

Reemplazo del placeholder de color plano por sprites reales de las 20+
torretas y los enemigos, usando el pipeline ya validado en Fase 2 (paleta
industrial fronteriza, técnica vectorial plano, GPT como herramienta,
`prompts-arte-torretas-v1.md`). **El trabajo de arte ya en curso (rondas 1-3
de la Torreta Recta, `qa-prueba-assets-v1.md`/`smoke-test-motor-arte-v1.md`)
es Fase 4 adelantada, no un bloqueante de Fase 2** — se documentó dentro de
la carpeta de Fase 2 porque ocurrió en paralelo mientras el motor todavía
estaba en curso, pero conceptualmente pertenece acá. No hace falta
detenerlo ni repetirlo; simplemente no es parte del criterio de cierre de
Fase 2.
