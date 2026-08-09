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

**Criterio de cierre — 4 puntos, 2 cumplidos, 1 corregido en el camino, 1
todavía abierto (revisión de Dirección, 09-ago):**

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
4. **Costo de GPU con texturas reales en las 24 entidades del pico
   conjunto, no solo una — todavía NO hecho.** Los bancos que confirmaron
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

**Fase 2 queda cerrada del lado de motor cuando el punto 4 también esté
hecho — no antes.** Los otros tres ya lo están; este es el único que falta
y es barato de cerrar. Lo que sigue en vuelo (ronda 3 de arte, triage de
las 12 torretas del catálogo sin fila todavía) sigue sin bloquear nada de
esto — corresponde a Fase 3/4, ver abajo. Deuda técnica menor que sigue
pendiente sin bloquear el cierre: `TODO` de
`DEV_RANGE_OVERRIDE`/`DEV_FIRE_RATE_OVERRIDE` en `tower_store.gd` (poner en
0.0 antes de calibrar combate real — tarea de Fase 3); el bug de aspecto
cuadrado ya no está en esta lista — se corrigió en
`smoke-test-motor-arte-v1.md` sección 14 (relleno a canvas cuadrado antes
de importar, sin tocar el quad del motor).

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
no existen). Arranca cuando el punto 4 del criterio de cierre de Fase 2
también esté hecho.

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
