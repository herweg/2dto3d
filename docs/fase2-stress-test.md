# Fase 2 — Test de estrés de la Pantalla 1

**Estado:** hecho — 08-ago-2026.
**Qué es:** benchmark de ingeniería sobre los sistemas reales de la Pantalla 1
(`LaneEnemySystem`, `ProjectileSystem` con los 4 tipos de proyectil,
`TowerSystem`) — no la pantalla jugable en sí, un arnés aparte
(`game/sim/stress_main.gd` + `game/scenes/Stress.tscn`) que carga la misma
geometría (`level_01.tres`) y barre poblaciones sintéticas para encontrar
dónde cae de 60fps (16.7ms) y separar el costo de cada pieza.
**Reporte visual completo (curvas, capturas):** ver artifact publicado en
esta sesión de trabajo.
**Máquina de medición:** la misma del spike de Sprint 2 (i5-9400, Radeon RX
Vega) — cota optimista, no el piso de hardware mínimo.

---

## Cómo correrlo

```
Godot_v4.7-stable_win64_console.exe --path game --scene res://scenes/Stress.tscn -- mode=<enemies|projectiles|towers> [proj-type=mixed|0|1|2|3] [tower-type=0-3] [level-duration=<s>] [hold-at-peak=<s>]
```

`--scene` corre esa escena sin tocar `run/main_scene` de `project.godot`
(que sigue apuntando a `Level1.tscn`). Tres modos, cada uno barre su propia
lista de niveles (`ENEMY_LEVELS`/`PROJ_LEVELS`/`TOWER_LEVELS` en
`stress_main.gd`), reponiendo población tipo "fuente" (mismo patrón que
`BenchmarkSpawner` de Sprint 2) y registrando con `BenchmarkLogger`
(reusado tal cual, sin tocar) en `game/benchmark_results/stress_<modo>_*.csv`.

## Resultado

| Eje | Cae de 60fps en | Nota |
|---|---|---|
| Enemigos solos (sin combate) | **~5.730** simultáneos | Barato — esquivar obstáculos + render no pesa |
| Proyectiles — recto | ~4.360 | Igual de barato que el de Sprint 2 |
| Proyectiles — perforante | ~4.410 | Prácticamente igual al recto |
| Proyectiles — homing | **~2.710** | El más caro — re-apunta cada tick, no solo al spawnear |
| Proyectiles — splash | **~2.780** | Consulta extra al hash espacial en cada impacto |
| Torretas explosivas, cadencia máxima | **~800** | Ahí empieza a doler |
| Torretas explosivas, 1.200 | **13fps (75ms)** | Colapso — 6× el presupuesto de frame |

**Lectura:**

- Los enemigos (incluso con esquivado de obstáculos real, no el seek radial
  simple del spike) son el eje más barato por lejos — no hace falta
  vigilarlo a las escalas de diseño actuales.
- La colisión de proyectiles en GDScript puro sigue siendo el cuello de
  botella conocido desde Sprint 2 (~3.600-3.900 en el caso sintético
  simple) — acá, con la variedad de 4 comportamientos real, el rango es
  ~2.700-4.400 según el tipo. Homing y splash pagan trabajo extra real
  (re-apuntado por tick / consulta de splash por impacto) — no es gratis
  tener variedad.
- **Hallazgo nuevo, fuera del radar de Sprint 2:** el *targeting* de
  torres — cada torre lista para disparar escanea todos los enemigos
  buscando el más cercano, fuerza bruta — es un cuello de botella
  independiente de la colisión de proyectiles. Con torretas masivas
  (cientos) se vuelve el problema dominante, no la cantidad de
  proyectiles en el aire.

## Qué hacer con esto (no bloqueante, para cuando haga falta)

- Si el diseño nunca pone más de un centenar de torres en pantalla, el
  targeting por fuerza bruta no hace falta tocarlo.
- Si en algún momento se permiten torres masivas, el targeting necesita el
  mismo tratamiento que ya recibió la colisión en el spike: apoyarse en el
  `SpatialHash` existente (o extender `SimHotPath` en Rust) en vez de
  escanear todos los enemigos por torre.
- Si homing/splash se vuelven un cuello de botella real en producción, son
  los candidatos naturales para el próximo tramo de `game/rust/` —
  `SimHotPath` hoy no sabe de los 4 tipos (`tick_native()` en
  `projectile_system.gd` tiene la nota); extenderlo ahí es la palanca que
  ya existe.

## Nota sobre las variables de desarrollo activas

`DEV_RANGE_OVERRIDE` y `DEV_FIRE_RATE_OVERRIDE` en `tower_store.gd` siguen
activas (rango exagerado, cadencia rápida) — quedaron así después de la
verificación de los 4 tipos de proyectil y se usaron tal cual para este
test de estrés. `TOWER_TYPE_STATS` tiene los valores reales sin tocar.
Poner cualquiera de las dos en `0.0` vuelve al balance real cuando toque
calibrar.
