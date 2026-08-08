# Plan: exprimir el motor en el eje de proyectiles (08-ago-2026)

**Contexto:** con T4 cerrado (ver `definicion-escala-v1.md`, condición del
20%), el cuello de botella que queda es el que ya señalaba
`fase2-motor-cristalizado.md`: proyectiles. Este documento planifica el
próximo paso concreto — no es una decisión más, es la ejecución de la
palanca que ya estaba identificada y sin tirar.

---

## 0. La palanca a tirar, dicho una vez más para que no se pierda

`SimHotPath` (`game/rust/src/lib.rs`) hoy solo resuelve colisión simple de
un impacto — no sabe de homing, perforante, splash, ni de lo que sigue en
la sección 1. Por eso `tick_native()` no se usa en la Pantalla 1: el
contenido real corre en `tick()` (GDScript), que es exactamente el camino
cuyo techo mide `fase2-stress-test.md` (2.700-4.400 según tipo). Sprint 2 ya
demostró qué pasa cuando se mueve colisión simple a Rust: de un techo
GDScript de ~3.600 a 144fps sostenidos por encima de 8.500. **Extender
`SimHotPath` para cubrir la variedad real de proyectiles es la palanca —
no hay una segunda opción más barata sin tocar esto.**

---

## 1. Triage técnico de los 4 mecanismos que confirmó la PM

| Arma | Qué es en realidad | Trabajo nuevo |
|---|---|---|
| **Básico** | `PROJ_STRAIGHT`, ya existe | Ninguno |
| **Lanzallamas** | Zona persistente, DPS mientras el enemigo está encima | Tipo nuevo + campos de DoT en `EnemyStore` (ver 1.1) |
| **Láser** | DPS alto mientras hay un enemigo en el haz — sprite fijo | Probablemente **no es un proyectil** (ver 1.2) |
| **Misiles** | Trayectoria fija precalculada al spawn ("firulete" visual, sin re-apuntado), explota (splash ya probado) | Tipo nuevo, reusa `splash_radius` (ver 1.3) |

### 1.1 Lanzallamas — el único que pide esquema nuevo de verdad

No es "dispara y muere al primer impacto" como los 4 tipos de hoy — es
"aparece, se queda, y mientras un enemigo esté cerca le refresca DoT cada
tick". `combat-design-v1.md` ya congeló el costo de esquema para DoT
(`dot_dps`, `dot_time_left` en la fila de ENEMIGO, 0 campos en proyectil) —
nunca se implementó porque nada lo necesitó hasta ahora. Para esto hace
falta:
- Los 2 campos de DoT en `EnemyStore` (ya congelados, solo falta
  escribirlos).
- Un `PROJ_ZONE` en `ProjectileStore`/`ProjectileSystem`: velocidad ~0,
  vive por su `ttl`, y en vez de morir al primer impacto, cada tick hace
  `hash.query_nearby()` (ya existe, lo usa splash) y refresca
  `dot_dps`/`dot_time_left` de cada enemigo en rango — no aplica daño
  directo, alimenta el DoT.
- Un sistema chico que cada tick, sobre `EnemyStore`, resta
  `dot_time_left` y aplica `dot_dps * delta` a `health` — no existe
  todavía, es la única pieza de lógica genuinamente nueva del lote.

### 1.2 Láser — antes de tocar código, una pregunta de arquitectura

Tal como lo describís ("sprite fijo", DPS mientras el enemigo está encima)
esto suena a que la torre daña directo a lo que tiene en el haz cada tick —
**sin spawnear un proyectil**. Si es así, no consume presupuesto de
`ProjectileStore` para nada: es una extensión de `tower_system.gd` (chequeo
de overlap en una línea/cono desde la torre, mismo costo que el targeting
que ya existe) más un `dot`-like tick de daño directo. Antes de que alguien
empiece a construirlo como "un proyectil que no se mueve" — que sería
mezclar dos modelos por accidente — conviene confirmar esto con quien lo
vaya a implementar. Si es así, el láser en realidad **ayuda** al problema
de proyectiles en vez de sumarle carga: es presupuesto que no compite con
el resto.

### 1.3 Misiles — el más barato de sumar, más barato todavía de lo que dije

Reusa el chequeo de impacto + daño en área que ya tiene `PROJ_SPLASH` tal
cual. Lo único nuevo es cómo se actualiza `velocity` cada tick.

> **Corrección de la PM, 08-ago:** el misil **no necesita homing real.** No
> hace falta re-apuntar al enemigo vivo cada tick — el objetivo es que
> impacte donde *hubo* un enemigo al momento del disparo, no que seleccione
> en vuelo. El "firulete" (algunos giros antes de llegar) es puramente
> visual/animación, no lógica de targeting continuo. Esto se puede resolver
> más barato: calcular una trayectoria fija (spline chico o waypoints, 2-3
> puntos de control) **una sola vez al spawnear**, y en cada tick avanzar
> `position` a lo largo de esa curva ya calculada — el mismo costo que mover
> en línea recta, no el de re-evaluar dirección contra un objetivo cada
> frame. Esto tira abajo la cota de costo que había puesto (~2.710, el techo
> de homing) — el estimado correcto es más cercano al de recto/perforante
> (~4.360-4.410), a confirmar en el benchmark del paso 4, no a asumir. Queda
> como **hipótesis a probar**, no como hecho — si medido resulta más caro de
> lo esperado, no cambia el plan (splash ya está reusado, sigue siendo el
> tipo más barato de sumar en trabajo de diseño), solo el número de costo.

---

## 2. Orden de trabajo propuesto

1. **Congelar el esquema antes de tocar `game/rust/`** — mismo criterio que
   ya se usó para crítico/perforación/splash: `PROJ_ZONE` y `PROJ_MISSILE`
   como `type_id` nuevos, los 2 campos de DoT en `EnemyStore`, confirmar si
   láser entra a `ProjectileStore` o no (sección 1.2). Esto es diseño de
   datos, no requiere `game/rust/` compilado — puede arrancar ya.

   **Actualización 08-ago:** `docs/docs-torretas-diseno.md` (catálogo de ~20
   torretas, diseño en papel de la PM) llegó después de este triage y no
   está reconciliado contra él — ver la revisión al final de ese documento.
   No cambia el orden de trabajo: el alcance de *este* congelamiento sigue
   siendo básico/misiles/lanzallamas/láser (lo que ya bloquea el benchmark de
   2.000/3.000/20). El resto del catálogo (Riel, Mortero, Racimo, Enjambre,
   y sobre todo las categorías D/E/F, que piden `proj_type` genuinamente
   nuevos) es contenido para después — extenderlo ahora sería construir por
   las dudas, exactamente lo que este proyecto viene evitando. Si el
   benchmark de 20 torres necesita representar más variedad que los 4 tipos
   actuales + misiles/lanzallamas para ser creíble, esa es una decisión del
   PM/director a tomar antes del paso 4, no una que yo deba forzar acá.
2. **Documentar el build reproducible de `game/rust/` — esto ya no es "en
   paralelo, no bloqueante" como dije la vez pasada.** Si el próximo paso es
   literalmente extender `SimHotPath`, alguien va a tener que compilarlo de
   nuevo pronto — mejor que el proceso (incluido el quirk de Smart App
   Control/MSVC que ya se resolvió una vez) esté escrito antes de que haga
   falta, no durante. Subo la prioridad de la sugerencia del auditor de
   "cuando haya tiempo" a "antes del paso 3".
3. **Extender `SimHotPath`** para cubrir movimiento (recto/homing/misil) +
   resolución de impacto (simple/perforante/splash/zona) en una sola llamada
   nativa por frame, mismo contrato que ya validó Sprint 2 — arrays
   completos de ida, resultado de vuelta, sin llamadas por-entidad.
   `tick_native()` en `projectile_system.gd` ya tiene la función esperando
   que se le saque la limitación actual (nota explícita en el código).
4. **Repetir el benchmark conjunto** (la tarjeta que ya había quedado
   pendiente) pero ahora contra `SimHotPath` extendido, no contra GDScript:
   2.000 enemigos de fondo, 3.000 proyectiles con mezcla real de los ~6-7
   tipos que existan para entonces, 20 torres a `TOWER_TYPE_STATS` real
   (overrides en 0.0). Criterio de aceptación: **120% del objetivo**, no
   100% — la condición que dejó la PM en T4.

Gráficos/animación y el diseño en papel de las 20 torres siguen su curso en
paralelo — nada de esto los bloquea ni depende de ellos.
