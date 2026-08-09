# Fase 3 — alcance inicial (jugable)

**Rol:** Product Manager / Dirección de Desarrollo.
**Fecha:** 09-ago-2026.
**Estado:** captura inicial de las bases del producto, tal como las dio la
PM — no es un plan de implementación todavía. `plan-fases.md` señalaba este
documento como el hueco real pendiente (Fase 1 y 2 arrancaron con un memo de
alcance, Fase 3 no tenía ninguno); esto lo cierra.
**No arranca todavía.** `plan-fases.md` deja el cierre de Fase 2 condicionado
al punto 4 de su criterio de cierre (banco de GPU con texturas reales en las
24 entidades del pico, no solo una) — este documento registra alcance para
cuando esa condición se cumpla, no antes.

---

## 1. El loop central, tal como lo definió la PM

1. **Fase de colocación:** el jugador coloca torretas con el mouse sobre la
   pantalla — plataforma PC, sin joystick/touch a considerar (consistente
   con la postura de un jugador ya cerrada en Fase 1). Las torretas
   disponibles para colocar son las que ya están desbloqueadas (ver
   sección 2); una vez desbloqueada, una torreta **es libre de colocar**
   — no hay costo de colocación individual descrito, ver pregunta abierta
   en sección 4.
2. **Botón "Comenzar":** el jugador decide cuándo terminó de colocar y
   arranca la ronda explícitamente — no hay spawn de enemigos hasta ese
   click.
3. **La ronda:** enemigos salen y avanzan por el carril (ya implementado,
   `LaneEnemySystem`); las torretas ya colocadas hacen su trabajo sin
   intervención del jugador durante la ronda (no hay mención de acciones
   del jugador *durante* el combate — colocar es antes, no en vivo).
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

## 4. Preguntas abiertas — no las estoy respondiendo acá, quedan para cuando Fase 3 arranque

1. **¿Hay costo de colocación dentro de la ronda, además del desbloqueo
   meta?** El mensaje de la PM dice "una vez que está desbloqueada está
   libre para usar" — leo eso como "sin costo por placement", pero vale
   confirmarlo explícitamente antes de diseñar la economía, porque cambia
   la superficie de balance por completo (si no hay costo por torreta, el
   límite real de poder del jugador es 100% la cantidad de slots
   desbloqueados, no un presupuesto por ronda).
2. **¿Cuántas pantallas/niveles van a existir, y qué poder hace falta para
   cada una?** Ya estaba anotado como pregunta abierta por la propia PM en
   esta misma conversación — `LevelDef` tiene el campo de fondo listo desde
   Fase 2, pero hoy solo existe contenido real para una (`level_01.tres`).
3. **¿Las mejoras del árbol son permanentes (cuentan para toda partida
   futura) o por-run (se resetean)?** No especificado todavía — determina
   si hace falta un sistema de guardado persistente (más pesado) o alcanza
   con estado en memoria por sesión de juego (más liviano, parecido a lo
   que ya existe).
4. **¿Calibración de combate (HP/daño real, no los valores de prueba de
   `TOWER_TYPE_STATS`) se hace antes o junto con la progresión?** Probable
   que tengan que iterar juntas (el desbloqueo determina qué poder tiene el
   jugador en cada punto, lo cual determina cuánta vida/daño necesitan los
   enemigos de cada nivel) — no es estrictamente secuencial, vale anotarlo
   para no tratarlas como dos tareas independientes.

---

## 5. Fuera de alcance de este documento

Calibración numérica de cualquier cosa (vida, daño, costos de desbloqueo,
nodos del árbol) — esto es alcance, no números. Los números se definen
cuando Fase 3 arranque de verdad, con el motor ya cerrado del todo
(`plan-fases.md`, punto 4 pendiente).
