# Fase 3 — alcance inicial (jugable)

**Rol:** Product Manager / Dirección de Desarrollo.
**Fecha:** 09-ago-2026.
**Estado:** alcance cerrado — 09-ago-2026. Las 4 preguntas abiertas de la
sección 4 quedaron resueltas (PM, misma fecha), una a la vez, con evaluación
de opciones. `plan-fases.md` ya cerró Fase 2 del lado de motor (los 4 puntos
de su criterio de cierre) — nada bloquea que Fase 3 arranque de verdad.
**Sigue sin ser un plan de implementación ni tener números de balance** —
eso es explícitamente fuera de alcance (sección 5), se define cuando el
trabajo de Fase 3 arranque en la práctica.

---

## 1. El loop central, tal como lo definió la PM

1. **Fase de colocación:** el jugador coloca torretas con el mouse sobre la
   pantalla — plataforma PC, sin joystick/touch a considerar (consistente
   con la postura de un jugador ya cerrada en Fase 1). Las torretas
   disponibles para colocar son las que ya están desbloqueadas (ver
   sección 2), dentro de las zonas de construcción del nivel
   (`buildable_zones`, ya existe en `LevelDef`). **Sin costo de colocación
   — resuelto, ver sección 4, punto 1.**
2. **Botón "Comenzar":** el jugador decide cuándo terminó de colocar y
   arranca la ronda explícitamente — no hay spawn de enemigos hasta ese
   click.
3. **La ronda:** enemigos salen y avanzan por el carril (ya implementado,
   `LaneEnemySystem`); las torretas ya colocadas hacen su trabajo sin
   intervención del jugador durante la ronda — **confirmado, sección 4
   punto 1: la colocación es fija una vez arrancada la ronda, no se puede
   mover/agregar/quitar torres en vivo.** Posible excepción, sin decidir
   todavía: boosts temporales (cadencia, daño) aplicables durante la ronda
   — no es colocación, es un sistema aparte a evaluar.
4. **Puntos:** cada enemigo eliminado otorga puntos. Los puntos son la
   moneda que desbloquea mejoras/torretas nuevas (sección 2) — no está
   dicho todavía si también sirven para algo dentro de la ronda misma.

**Lo que esto necesita de motor y no existe hoy:** un estado explícito de
"colocación" vs. "combate" con una transición gateada por un botón — hoy
`level_controller.gd` no tiene esa máquina de estados; las corridas de
prueba spawean con temporizador propio, no con un gate de UI. Es trabajo de
Fase 3, no algo que Fase 2 tuviera que anticipar.

---

## 2. Progresión — desbloqueo de torres y niveles

- Las torres se desbloquean a medida que el jugador progresa, y/o subiendo
  de nivel una torre ya desbloqueada — **dos ejes distintos** (desbloquear
  una torre nueva vs. mejorar una que ya se tiene), calibración de cuál
  gatilla cuál queda pendiente.
- La **cantidad de torretas colocables** también está sujeta a desbloqueo
  (no es ilimitado desde el principio) — otro contador a calibrar, separado
  de qué tipos están disponibles.
- Los puntos de la ronda (sección 1, punto 4) son el recurso que financia
  ambos desbloqueos.

**Lo que esto necesita y no existe hoy:** ningún sistema de persistencia —
todo lo construido en Fase 2 es estado de una sola sesión de simulación
(`EntityStore` y derivados viven y mueren con el proceso). Progresión entre
rondas implica guardar/cargar estado de desbloqueo — pieza nueva, no una
extensión de algo que ya esté armado.

---

## 3. Árbol de mejoras — estilo Path of Exile

Dos tipos de rama, conviviendo en el mismo árbol:

- **Ramas genéricas/globales:** mejoras que aplican a todas las torretas o
  al jugador en general (ejemplos no dados todavía — a definir junto con
  calibración de combate).
- **Ramificaciones por torreta:** una rama de mejoras propia por cada
  torreta del catálogo (a calibrar cuáles y cuántos nodos).

**Este es, en tamaño, probablemente el sistema más grande de Fase 3** — un
árbol de talentos estilo PoE es simultáneamente un modelo de datos nuevo
(nodos, prerequisitos, costos), una superficie de balance nueva (20+ torretas
× N nodos cada una, más las ramas globales), y una UI nueva (nada de lo
construido hasta ahora tiene pantallas de jugador, solo la escena de
combate). Vale tratarlo como su propio sub-alcance dentro de Fase 3, no como
una línea más de la lista.

---

## 4. Preguntas abiertas — resueltas, 09-ago

1. **¿Hay costo de colocación dentro de la ronda, además del desbloqueo
   meta? — RESUELTO (PM, 09-ago).** Sin costo por torreta individual. El
   límite real de poder es la **cantidad de torres colocables**, atada al
   **nivel de jugador** (meta-progresión, no el nivel/pantalla de la
   sección 4 punto 2 — son dos conceptos de "nivel" distintos, hay que
   mantenerlos separados en el vocabulario del proyecto de acá en más).
   Ejemplo dado: nivel de jugador 1 = 1 torre colocable; la curva exacta
   queda para calibración, no para este documento. La colocación ocurre
   una sola vez, al inicio de la partida (antes de "Comenzar", sección 1) y
   **es fija durante toda la ronda** — no se puede mover, agregar ni quitar
   una vez arrancada.
   > **Sub-pregunta nueva, abierta, no decidida:** ¿boosts temporales
   > (cadencia, daño, u otros) aplicables *durante* la ronda, sin que
   > cuenten como re-colocación? Explícitamente "a evaluar" — no es parte
   > de esta resolución, es una idea separada para cuando se calibre
   > progresión/combate.
2. **¿Cuántas pantallas/niveles van a existir? — RESUELTO, cantidad (PM,
   09-ago).** **5**, reusando la progresión temática ya propuesta en
   `diseno-grafico.md` sección 2: luna helada (entrada) → planeta rocoso/
   desértico → luna/jungla alienígena → gigante gaseoso → estrella (clímax).
   Ese documento la había dejado como "plantilla reusable, no un conteo
   final" — queda promovida a número de trabajo. `LevelDef` tiene el campo
   de fondo listo desde Fase 2; hoy solo existe contenido real para el
   primero (`level_01.tres`), faltan los otros 4. **Qué poder hace falta
   para cada una queda para calibración** (fuera de alcance de este
   documento, sección 5) — la cantidad no prejuzga la curva.
3. **¿Las mejoras del árbol son permanentes o por-run? — RESUELTO
   (PM, 09-ago). Permanentes.** Coherente con la referencia a Path of Exile
   de la sección 3 y con "el jugador progresa" de la sección 2. **Implica
   que Fase 3 necesita un sistema de guardado/carga de punta a punta** —
   hoy no existe ninguno (todo lo de Fase 2 vive en memoria, muere con el
   proceso). No es una extensión de algo ya armado, es pieza nueva; vale
   tratarla como su propio sub-alcance de motor dentro de Fase 3, mismo
   criterio que la sección 3 ya aplicó al árbol de mejoras en sí.
4. **¿Calibración de combate se hace antes o junto con la progresión? —
   RESUELTO (PM, 09-ago). Juntas, en ciclos cortos.** Confirma la lectura
   que ya traía esta sección: no se fija la curva de progresión a ciegas ni
   se calibra HP/daño contra una composición hipotética — prototipo mínimo
   de ambas a la vez, ajustado en el mismo ciclo de playtesting. Mismo
   criterio de "medir en vez de apostar" que ya usó el proyecto para T2, la
   técnica de ilustración, y el resto de las decisiones de Fase 1/2.

---

## 5. Fuera de alcance de este documento

Calibración numérica de cualquier cosa (vida, daño, costos de desbloqueo,
nodos del árbol) — esto es alcance, no números. Los números se definen
cuando el trabajo de Fase 3 arranque en la práctica, en ciclos cortos junto
con combate (sección 4, punto 4) — no antes.

---

## 6. Qué pide esto de motor, ahora que el alcance está cerrado

Tres piezas nuevas, ninguna es extensión de algo que ya exista — para que
Dirección de Desarrollo pueda armar tarjetas de trabajo directo desde acá:

1. **Máquina de estados colocación/combate** (sección 1) — gate explícito
   por botón "Comenzar", `level_controller.gd` no lo tiene hoy.
2. **Sistema de guardado/carga** (secciones 2 y 4 punto 3) — desbloqueos y
   árbol de mejoras son permanentes, todo lo de Fase 2 es estado en memoria
   que muere con el proceso.
3. **4 niveles de contenido nuevos** (sección 4 punto 2) — `LevelDef` ya
   soporta el campo de fondo, falta el contenido real de planeta rocoso,
   jungla alienígena, gigante gaseoso y estrella (solo existe `level_01.tres`).

El árbol de mejoras en sí (sección 3) y la UI de jugador que necesita son,
por tamaño, su propio sub-alcance — no lo desglosé en tareas de motor acá
porque calibración/combate lo va a moldear en el mismo ciclo corto de la
sección 4 punto 4, no antes.
