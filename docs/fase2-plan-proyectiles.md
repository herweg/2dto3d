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

### 1.2 Láser — confirmado, y más barato de lo que pensaba

**Confirmación de la PM, 08-ago:** el láser sigue en pie, no lo reemplaza
Riel (mecanismo distinto — ver sección 3) y faltaba agregarlo al catálogo
de `docs-torretas-diseno.md`. Mecánica afinada: alto DPS mientras el
enemigo toca el haz, más un margen corto después de perder contacto (~0.5s
o un puñado de ticks) para que no se sienta que el daño corta en seco.

Con ese detalle del margen, cambio mi lectura: esto **no es un tipo de
proyectil nuevo, es el mismo mecanismo que lanzallamas (1.1) con otra
fuente.** Un temporizador de "sigo recibiendo daño" que se refresca
mientras hay contacto y decae solo cuando el contacto se corta es
exactamente `dot_time_left`/`dot_dps` — el mismo slot que ya congeló
`combat-design-v1.md` para daño en el tiempo, no uno nuevo. La única
diferencia real entre lanzallamas y láser es **quién alimenta el
temporizador cada tick**: una zona plantada en el piso (lanzallamas,
`PROJ_ZONE`) o un chequeo de overlap directo desde la torre sin spawnear
nada (láser, extensión de `tower_system.gd`). El sistema que aplica el
daño — decrementar `dot_time_left`, restar `dot_dps * delta` a `health` —
es el mismo para los dos. Confirmo la lectura original: el láser no
consume presupuesto de `ProjectileStore`, y ahora tampoco pide campos
nuevos en `EnemyStore` más allá de los 2 que ya hacía falta escribir para
lanzallamas.

Único punto de diseño a resolver antes de codear, no antes de seguir: si
un enemigo está parado sobre una zona de lanzallamas Y en el haz de un
láser al mismo tiempo, comparten el mismo slot de DoT (v1 es un slot sin
stackeo, por diseño de `combat-design-v1.md`) — el que refresca último
"gana". Es el comportamiento que ya implica el esquema congelado, no una
decisión nueva; lo dejo explícito para que no sorprenda a nadie en QA.

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

   **Reconciliación con el catálogo de 20 torretas (director, 08-ago) — ver
   sección 3 para el detalle.** El alcance de *este* congelamiento se
   amplía a 7 tipos (recto, homing, perforante, splash, misil, zona de DoT
   compartida por lanzallamas/láser) — el resto del catálogo queda
   deferido, explícitamente, no por descuido.
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

---

## 3. Reconciliación con el catálogo de 20 torretas (director, 08-ago)

Buen catálogo — el criterio de color de firma + 3 capas de escalado visual
resuelve por adelantado un problema real (20 torretas maxeadas disparando
juntas, ilegible si no hay algo que ancle la lectura). Coincido con el
catch técnico del auditor: "los `proj_type` existentes alcanzan para A/B/C
tal cual" no se sostiene mirando las entradas una por una. Mi propio triage
de las 4 que señaló, entrada por entrada — porque "necesita lógica nueva"
no es lo mismo que "es cara" o "es difícil", y conviene distinguirlas antes
de priorizar:

- **Riel** — igual que el láser (1.2): esto es un chequeo directo de la
  torre contra una línea del hash espacial, no un proyectil que viaja. La
  "carga 1-2s" es un timer del lado de la torre, no de `ProjectileStore`.
  Barato, y probablemente no compite por presupuesto de proyectiles —
  misma familia que láser, no una nueva.
- **Mortero** — trayectoria distinta (arco en vez de recta), pero mismo
  truco que ya destrabó el misil: precomputar la curva una sola vez al
  spawnear y recorrerla — el "arco" puede ser puramente visual (sombra +
  escala) sobre una trayectoria XY simple con delay. Reusa el mecanismo del
  misil casi entero.
- **Enjambre** — no es un `proj_type` nuevo: es homing (`type 1`) que ya
  existe, disparado 3-5 veces por vez en vez de una. El costo real no es de
  lógica, es de **presupuesto** — cada disparo de Enjambre consume 3-5
  entradas del `ProjectileStore` de un saque. Justo lo que señaló el
  auditor: importa para el benchmark de 3.000, no para el triage de
  comportamientos.
- **Racimo** — este sí es genuinamente distinto, y el único de los cuatro
  que no se resuelve con un truco ya conocido: necesita que un impacto
  pueda **crear proyectiles nuevos** (los 4-6 fragmentos), algo que ningún
  tipo de hoy hace. Si esto vive dentro de `SimHotPath` (paso 3), la
  llamada nativa no puede simplemente mutar el store desde Rust sin pensarlo
  — más prolijo que devuelva "acá hay que spawnear N fragmentos en este
  punto" como parte del resultado, y que GDScript haga el `spawn()` real al
  volver del batch. Es la única de las cuatro que le agrega una superficie
  nueva al contrato de `SimHotPath`, no solo un comportamiento más.

**Decisión de alcance:** el congelamiento del paso 1 se amplía a **7
tipos** — recto, homing, perforante, splash, misil, y la zona de DoT
compartida entre lanzallamas y láser (que no son un `proj_type` nuevo cada
uno, son una sola pieza de sistema con dos fuentes). Riel entra gratis en
la misma familia que láser (no consume presupuesto de proyectiles, así que
no hace falta esperarlo para el benchmark). **Racimo, y las categorías D/E/F
completas (hielo, veneno, cadena, gravedad, buff, maldición, minas, orbital,
caos) quedan deferidas a una ronda de contenido posterior** — no por
descuido, por la misma disciplina que ya viene sosteniendo este proyecto:
no se construye por las dudas antes de que haga falta. El benchmark del
paso 4 se arma con los 7 tipos de esta ronda (Riel y láser suman variedad
visual y de mecánica sin sumar carga de `ProjectileStore`), no con las 20
torretas completas — es representativo de los perfiles de costo reales
(disparo simple, re-apuntado continuo, multi-impacto, consulta de área,
trayectoria precomputada, DPS sostenido por zona) sin inventar trabajo que
todavía nadie pidió.

Gráficos/animación y el resto del diseño en papel de las 20 torres siguen su
curso en paralelo — nada de esto los bloquea ni depende de ellos.

---

## 4. Resultado — los 4 pasos ejecutados (08-ago-2026)

Los 7 tipos congelados en la sección 3 están implementados y corrieron por
el benchmark. Reporte completo, incluido el diagnóstico de un problema real
que apareció en el camino: `docs/fase2-benchmark-conjunto.md`.

**Resumen de una línea:** el benchmark de pico conjunto (2.000 enemigos,
3.000 proyectiles, 20 torres — todo ×1.2 por la condición del 20% de T4)
**ronda justo la línea de 60fps (58-65fps)** con el hot path de Rust
extendido — no es una aprobación cómoda, es un empate técnico. En el
camino se encontró y corrigió un problema real de metodología del
benchmark (PROJ_ZONE inyectado como si fuera un proyectil más de volumen,
cuando en juego real nunca hay más que un puñado activas) — sin esa
corrección, el número reportado hubiera sido un falso negativo severo
(7.5-13fps). Detalle completo, cifras por eje y qué hacer con esto en el
documento dedicado.

---

## 5. Arquitectura de láser/lanzallamas — cristalizada (PM, 08-ago, post-benchmark)

Tarjeta pendiente de la ronda anterior ("coordinar la confirmación de
arquitectura del láser con quien lo vaya a implementar") cerrada con
mecánica concreta, no solo con un sí/no:

**Ambos son un rectángulo de área efectiva que parte de la torreta** —
mismos 4 parámetros (largo, ancho, DPS/tick, duración de linger), distintos
valores: láser angosto+largo+DPS alto+linger corto; lanzallamas
ancho+corto+DPS bajo+linger largo. Detalle completo, valores y estado de
implementación en `tower_store.gd` (comentario sobre `TOWER_TYPE_STATS`,
filas 5 y 6) — no lo repito acá para no tener dos fuentes de verdad.

**Conecta directo con el hallazgo de la sección 4, arriba:** si lanzallamas
migra de `PROJ_ZONE` (fila 5 hoy) a la misma familia `TOWER_MODE_BEAM` que
ya usa láser, deja de consumir `ProjectileStore` y de llamar
`hash.query_nearby()` por tick — exactamente la causa que encontró el
diagnóstico de 7.5-13fps. No es un cambio hecho todavía (`_tick_laser()`
sigue siendo círculo+un blanco, no rectángulo — ver nota en
`tower_store.gd`), pero cuando se generalice a un `_tick_beam()`
compartido, probablemente vuelve innecesario el workaround de
`ZONE_FIXED_COUNT := 10` en vez de solo mitigarlo.

**Pendiente, no resuelto acá:** la nota visual del PM sobre estados
(prendido fuego, etc.) — capturada en `combat-design-v1.md`, modificador 4,
como restricción de diseño (un solo estado visual por enemigo aunque haya
más de un efecto mecánico activo) para cuando se retomen las categorías
D/E/F.

**Reconciliación pendiente con `docs-torretas-diseno.md`, para que quede
anotada:** el catálogo de 20 no tiene una entrada llamada "Láser" — lo más
cercano por nombre es Riel (#3), que es un mecanismo distinto (hitscan de
carga, no DPS continuo). Tampoco usa los nombres "misil" ni "lanzallamas" —
lo más cercano es Mortero (#9, trayectoria en arco) y Fuego (#11, zona de
DoT), que no son necesariamente lo mismo que lo implementado acá. Tres
mecanismos con nombre y fila real en `tower_store.gd` sin contraparte clara
en el catálogo de la PM — vale una pasada de reconciliación de nombres
antes de que Dirección de Arte (`docs/diseno-grafico.md`) tenga que adivinar
qué ilustrar para cada fila.
