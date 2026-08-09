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

**Criterio de cierre — 3 puntos, 2 ya cumplidos:**

1. ~~Benchmark de pico conjunto sostenido por encima de 60fps con margen del
   20%~~ — **hecho** (`fase2-benchmark-conjunto.md` sección 8, dos corridas
   limpias 60.3-87fps).
2. ~~Confirmar que el margen sigue vigente con costo de GPU real (filtro de
   texturas/mipmaps)~~ — **hecho** (`definicion-escala-v1.md`, revisión
   Mesa de Developers 09-ago: sin caída medible en los dos bancos).
3. Catálogo de tipos de torreta/proyectil sin ambigüedad de nombres —
   **hecho** (Mortero/Misil, Fuego/Lanzallamas, y ahora Láser como arma
   propia, `docs-torretas-diseno.md` #21).

**Con los 3 puntos cumplidos, Fase 2 queda cerrada del lado de motor.** Lo
que sigue en vuelo (ronda 3 de arte, triage de las 12 torretas del catálogo
sin fila todavía) no bloquea este cierre — corresponde a Fase 3/4, ver abajo.
Deuda técnica menor que sigue pendiente sin bloquear el cierre: `TODO`
de `DEV_RANGE_OVERRIDE`/`DEV_FIRE_RATE_OVERRIDE` en `tower_store.gd` (poner
en 0.0 antes de calibrar combate real — tarea de Fase 3), bug de aspecto
cuadrado forzado en el quad de render (tarjeta de motor chica, no urgente).

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

No detallado todavía en documentos — se planifica cuando arranque, mismo
criterio que ya usó este proyecto para Fase 2 (no fijar alcance sobre datos
que todavía no existen).

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
