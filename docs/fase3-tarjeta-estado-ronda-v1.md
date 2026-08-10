# Tarjeta — máquina de estados colocación/combate

**Rol:** Dirección de Desarrollo.
**Fecha:** 09-ago-2026.
**Origen:** `fase3-alcance-v1.md` sección 6, punto 1 — primera pieza de
motor de Fase 3, elegida como punto de partida (ver razón en
`plan-fases.md`, Fase 3). Sin ella, "combate y progresión se calibran
juntos en ciclos cortos" (alcance, sección 4 punto 4) no tiene con qué
trabajar — no hay forma de terminar una ronda para medir el ciclo.

---

## 1. Estado actual, verificado en código, no supuesto

`level_controller.gd::_process()` (líneas 414-425), modo normal (no
`stress-test`): un timer (`_spawn_timer`/`SPAWN_INTERVAL`) larga un
enemigo por vez desde `_level.spawn_point`, **para siempre, desde que la
escena carga** — sin gate, sin objetivo, sin condición de fin. Coloca
torres (`_place_tower()`, ya andando) y deja spawnear son dos cosas
completamente independientes hoy; no existe ningún concepto de "ronda".

## 2. Alcance de esta tarjeta — dos piezas, no una

**No alcanza con solo gatear el spawner detrás de un botón.** Eso cumple
la letra del pedido ("no hay spawn hasta el click") pero no produce una
ronda que *termine* — y sin fin de ronda, no hay nada que alimente los
ciclos cortos de calibración de la sección 4 punto 4. Las dos piezas:

1. **Estado `PLACEMENT` / `COMBAT`**, gate por botón.
2. **Objetivo de oleada mínimo** — no una curva de oleadas diseñada (eso
   es calibración, fuera de alcance acá, mismo criterio que
   `fase3-alcance-v1.md` sección 5) — alcanza con un conteo fijo
   (constante o campo nuevo trivial en `LevelDef`, a elección de quien
   implemente) para que "la ronda terminó" sea un hecho verificable:
   todos los enemigos del objetivo ya fueron spawneados y ya no queda
   ninguno activo (muerto o leaked).

## 3. Comportamiento por estado

**`PLACEMENT`** (default al cargar la escena):
- Colocar torres: habilitado, sin cambios (`_place_tower()` ya funciona).
- Spawner: apagado.
- Trigger de salida: botón "Comenzar" (ver sección 4).

**`COMBAT`**:
- Colocar torres: **deshabilitado** — ya está resuelto en
  `fase3-alcance-v1.md` sección 4 punto 1 ("fija durante toda la ronda, no
  se puede mover/agregar/quitar") — este estado es donde esa regla se
  aplica en código.
- Spawner: activo hasta agotar el objetivo de oleada (punto 2 de arriba).
- Torres/proyectiles/DoT: sin cambios, siguen su tick normal.

## 4. Botón "Comenzar" — primer elemento de UI real del proyecto

Vale decirlo explícito: todo lo construido hasta ahora es simulación y
render (`Node2D`, `MultiMeshInstance2D`) — no hay un solo `Control`/
`CanvasLayer` en el proyecto todavía. Esta tarjeta lo introduce. Para esta
etapa alcanza con algo funcional y sin estilo (un `Button` en un
`CanvasLayer`, posición fija) — la pantalla real de UI/HUD es trabajo de
Fase 4, no bloquea esta tarjeta.

## 5. Lo que esta tarjeta explícitamente NO resuelve

- **Qué pasa cuando la ronda termina.** ¿Vuelve a `PLACEMENT` para otra
  ronda en la misma partida? ¿Es el final de la sesión de ese nivel? Depende
  de cómo termine encajando la progresión (sección 2 de `fase3-alcance-v1.md`)
  y no tengo contexto todavía para decidirlo — **pregunta abierta para la
  PM, no la resuelvo acá.** Mínimo aceptable para esta tarjeta: al agotar
  el objetivo, loguear/marcar "ronda completa" de forma verificable
  (headless incluido, mismo criterio de regresión de siempre) — la
  transición real puede quedar como TODO explícito hasta que la pregunta
  de arriba se conteste.
- **Condición de derrota** (vida del jugador, game over) — pendiente desde
  antes de esta tarjeta, sigue sin decisión, no se mezcla acá.
- **Economía/gasto de puntos** — la tarjeta no toca cómo se gastan los
  puntos de la sección 1 punto 4 del alcance, solo el gate de cuándo se
  puede colocar.

## 6. Verificación esperada

Regresión estándar de siempre (`place-all-towers real-stats` headless) más
un caso nuevo: colocar 0 torres, apretar "Comenzar" (o el equivalente
headless/CLI), confirmar que el spawner arranca y que llegar al objetivo
de oleada deja el estado marcado como completo, sin errores.
