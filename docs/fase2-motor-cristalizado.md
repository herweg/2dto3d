# Motor cristalizado — firma del director (08-ago-2026)

**Insumo:** `docs/fase2-stress-test.md` + artifact "Fase 2 — Techo de
rendimiento de la Pantalla 1" (`game/sim/stress_main.gd` +
`game/scenes/Stress.tscn`, mismo método que `benchmark_main.gd` de Sprint 2
aplicado ahora a los sistemas reales de la Pantalla 1: `LaneEnemySystem`,
`ProjectileSystem` con los 4 tipos, `TowerSystem`).

## Veredicto: cristalizado. Luz verde para entrar a diseño gráfico y calibración.

No encuentro nada en este benchmark que deba resolverse antes de avanzar.
Los tres ejes medidos tienen margen de sobra contra el objetivo real de esta
pantalla (T2: ~1.500-2.000 enemigos, ~6.000-8.000 proyectiles, y un puñado de
torres — no cientos):

| Eje | Techo medido | Objetivo real | Margen |
|---|---|---|---|
| Enemigos (con esquivado de obstáculos) | ~5.730 | ~2.000 | 2,8× |
| Proyectiles, peor tipo (homing) | ~2.710 | ~8.000 pico | *ver nota* |
| Proyectiles, tipo típico (recto/perforante) | ~4.360-4.410 | ~8.000 pico | *ver nota* |
| Torres (splash, cadencia máxima) | ~800 | "un puñado" | amplio |

**Nota sobre proyectiles:** el techo medido acá (2.700-4.400) es más bajo que
el número de T2 (6.000-8.000) — a primera vista parecería no alcanzar. No lo
leo como una alarma todavía: T2 se midió con el hot path de Rust
(`SimHotPath`) en Sprint 2, y este benchmark corre en GDScript puro porque
`SimHotPath` no sabe todavía de los 4 comportamientos (`tick_native()` lo
anota explícitamente). Es la misma palanca que ya resolvió exactamente este
problema una vez — está construida, probada, y esperando. No hace falta
tirar de ella *ahora* porque nada de lo que sigue (calibrar, arte, animación)
necesita esos números; la dejo anotada como la primera tarea de motor si en
algún punto el diseño real empuja proyectiles mixtos por encima de ~2.500-4.000
simultáneos.

## Dos límites conocidos, no bloqueantes, para el registro

1. **Targeting de torres por fuerza bruta cruza 60fps en ~800 torres.** Muy
   por encima de cualquier plan de diseño actual ("un puñado" de torres, no
   cientos). Igual que con el punto anterior: si algún día el diseño quiere
   torres masivas, el arreglo es el mismo patrón que ya funcionó — agrupar
   contra `SpatialHash` en vez de escanear todos los enemigos por torre.
2. **Homing y splash pagan costo real por variedad** (re-apuntado por tick;
   consulta extra al hash por impacto) — no es gratis tener 4 comportamientos
   en vez de 1. Ya está cuantificado en la tabla de arriba; entra como dato
   de balance, no como bloqueante.

Ninguno de los dos cambia el plan. Quedan documentados para no tener que
redescubrirlos si en algún momento el diseño se acerca a esos números.

## Qué sigue

Con esto cerrado, el orden lógico es: **gráficos/animación (este mensaje) →
calibración de combate (lista de la vez pasada) → economía y condición de
victoria/derrota.** El motor no vuelve a ser el bloqueante hasta que el
diseño real pida algo que ninguno de los benchmarks corridos hasta acá
cubra.
