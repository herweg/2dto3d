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

**Aclaración (PM, 08-ago):** "contenido real" del juego (armas/torres
definitivas, oleadas, progresión — lo que vendría después de calibración)
arranca recién cuando el pico enemigos×proyectiles quede confirmado sólido y
conforme, no antes. Ese punto **todavía no está cerrado**: el hueco
metodológico que el propio director aceptó como no-bloqueante en
`sprint-02.md` Paso 6 (el caso sintético nunca forzó la población hasta el
pico exacto de 12.000/3.000) sigue sin resolverse — se aceptó para cerrar el
*spike*, no para arrancar contenido real sin confirmarlo. Gráficos/animación
y calibración de combate pueden seguir en paralelo mientras tanto porque no
dependen de ese número exacto; el contenido real sí.

## Punto sugerido para revisión del director (Auditor, 08-ago)

No es un bloqueante de esta firma, pero lo dejo anotado porque me parece
coherente resolverlo antes de avanzar mucho más en mecánicas, no después:
**no hay build reproducible documentado para `game/rust/` →
`bin/sim_hotpath.dll`.** `game/rust/target/` existe localmente (evidencia de
que se compiló al menos una vez), pero no hay script ni instrucciones — solo
quien lo compiló una vez sabe reproducirlo, incluyendo el quirk de Smart App
Control/MSVC que ya se encontró y resolvió durante el spike (`sprint-02.md`).

Razón por la que sugiero resolverlo pronto y no cuando haga falta: este mismo
documento ya identifica homing y splash como "los candidatos naturales para
el próximo tramo de `game/rust/`" si se vuelven cuello de botella — y la
calibración de combate (el siguiente paso) es exactamente el tipo de trabajo
que puede empujar esos números. Mejor tener el build reproducible documentado
con la cabeza fría ahora que reconstruirlo a las apuradas si `SimHotPath`
hace falta extender en medio de la calibración. No bloquea nada de lo de
arriba — puede ir en paralelo.

---

## Respuesta del director a los pendientes de esta ronda (08-ago)

**Gráficos/animación (commit `67a9165`): aprobado, sin objeciones.** El
diseño A/B es correcto — mismo quad, mismo `ENEMY_LEVELS`, una sola variable
real — y las curvas se superponen dentro del ruido (16.68ms vs 17.04ms en el
peor punto medido). La segunda revisión que confirma que el código coincide
con lo reportado *y* que el resultado es lo que predice el modelo de
`MultiMeshInstance2D` (no solo "medimos y dio bien") es exactamente el
estándar que quiero para este tipo de hallazgo. El equipo de gráficos puede
seguir con swap de textura por store — no hace falta UV por instancia a esta
escala.

**Catch de `referencia-orc-problem.md`: correcto, lo acepto sin peros.**
Firmé este mismo documento tratando la adopción de torres+carril como
resuelta cuando en realidad era mi recomendación sin ratificación escrita
todavía — el equipo ya había construido sobre ella (`89fbbd9`) antes de que
existiera el registro formal. Es exactamente el tipo de brecha entre "lo que
el código ya hizo" y "lo que quedó documentado" que un auditor tiene que
cazar. Ya está cerrado con firma compartida — no hace falta que yo agregue
nada más ahí.

**Build reproducible de Rust: acepto la sugerencia.** No es urgente hoy, pero
tiene el perfil exacto de "barato ahora, caro después" — documentar el
proceso (incluido el quirk de Smart App Control/MSVC) mientras todavía
alguien se acuerda de memoria, no cuando la calibración ya esté empujando
homing/splash y haga falta con apuro. Lo sumo como tarea de baja prioridad en
paralelo, no bloqueante — ver tarjetas abajo.

**Hardware mínimo (T4): objeción formal, ver `definicion-escala-v1.md`.** No
acepto la redefinición como resuelta — la propia descripción de la máquina
("i5-9400" + "Radeon RX Vega (integrada)") es una combinación de hardware que
no existe, lo que me dice que nadie verificó la GPU real antes de dar por
cerrada la advertencia de "cota optimista". Mientras esto no se resuelva, la
tabla de márgenes de este mismo documento (arriba) queda con un asterisco:
son márgenes contra la máquina de desarrollo, no confirmados contra hardware
mínimo real. Detalle y las dos salidas posibles en `definicion-escala-v1.md`.

### El número nuevo: ~20 torretas, ~2.000 enemigos, ~3.000 proyectiles (pico, última pantalla)

Es un número más chico y más disciplinado que el T2 original (que llegaba a
pico de 10.000-12.000 proyectiles) — buena señal, es diseñar contra lo que ya
se sabe que funciona en vez de contra una cifra aspiracional. Evaluado eje
por eje contra lo ya medido:

- **Torres (20):** no discuto nada acá. El techo medido (~800, encima con
  `DEV_FIRE_RATE_OVERRIDE` disparando casi sin pausa) le saca 40× de margen a
  20 torres incluso a cadencia real. Este eje deja de ser una preocupación en
  esta pantalla.
- **Enemigos (2.000):** 2,9× de margen contra el techo de enemigos solos
  (~5.730). Cómodo en aislamiento.
- **Proyectiles (3.000, mezclados entre ~20 tipos):** acá es donde no puedo
  decir "aprobado" todavía. Dos motivos concretos, no una sensación:
  1. El techo por tipo que ya midieron (2.710-4.410) se midió con **400
     enemigos de fondo fijos** — no 2.000. Más enemigos poblando la grilla
     espacial no es gratis para la consulta de colisión; nadie corrió ese
     número con la población de enemigos real.
  2. Esos techos se midieron **un tipo de proyectil a la vez** (barrido
     puro recto, puro homing, etc.) — el juego real dispara los ~20 tipos
     simultáneamente. 3.000 proyectiles mezclados, si una porción real cae
     en homing/splash (los tipos más caros, techo ~2.700-2.780 en soledad),
     puede estar más cerca del límite de lo que sugiere mirar solo el techo
     del tipo más barato.

  Ninguno de los dos es motivo para frenar gráficos ni para asustarse — es
  exactamente el mismo hueco que ya señaló el auditor en el punto 6 (nunca se
  forzó el pico exacto conjunto), ahora con un número real al que apuntarlo
  en vez del T2 abstracto.
- **Contenido (20 torretas distintas):** con datos, no solo con techo de fps.
  Las 4 torres de hoy cubren 4 de los ~13 comportamientos de
  `projectile-variety-v1.md` más 3 de los 5 modificadores de
  `combat-design-v1.md` (crítico ya resuelto al spawn sin costo de esquema,
  perforación, splash). **Elemento, DoT y cadenas todavía no tienen fila en
  `ProjectileStore`** — sin esos tres, 20 torres realmente distintas es
  ambicioso solo con variantes de movimiento; con los 5 modificadores
  combinables sobre ~13 comportamientos, 20 es holgado. Esto no es
  bloqueante para nada de lo de hoy, pero sí es trabajo de motor real
  pendiente antes de que calibración pueda darle contenido a las 20.

### Respuesta directa: sí, tarjeta para la Mesa de Developers — y la reescribo contra el número real

No lo dejaría como "forzar el pico de 12.000/3.000" (T2 original) — ese
número ya no es el que importa. La tarjeta que pondría:

> **Verificación de pico conjunto — número real de diseño.** Un solo
> benchmark: 2.000 enemigos de fondo (no 400), rampa de proyectiles a 3.000
> con mezcla realista de los tipos ya implementados (no `mixed` uniforme
> ni un tipo puro), 20 torres a fire_rate/range de `TOWER_TYPE_STATS` real
> (`DEV_FIRE_RATE_OVERRIDE`/`DEV_RANGE_OVERRIDE` en 0.0 para esta corrida
> específica, sin esperar a la calibración completa). Mismo método, mismo
> `BenchmarkLogger`. Resultado esperado: un sí/no contra 60fps, no una
> reafirmación de lo que ya se sabe por partes.

La empujaría junto con — no antes ni después de — la verificación de GPU de
T4, porque las dos son la misma clase de tarea ("confirmar un supuesto antes
de que el contenido real dependa de él") y tiene sentido cerrarlas en la
misma pasada. El build reproducible de Rust puede ir en paralelo con
cualquiera de las dos — no depende de ninguna.

Lo que sí seguiría en paralelo sin esperar nada de esto: gráficos/animación
(ya validado) y el diseño de las 20 torres en el papel (qué comportamiento +
qué modificadores por torre) — ninguno de los dos necesita el número
confirmado, solo lo necesita "contenido real" entra a producción.
