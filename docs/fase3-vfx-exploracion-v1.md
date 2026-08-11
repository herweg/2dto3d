# Explorar el presupuesto de GPU — VFX reales, no decorativos

**Rol:** Dirección de Desarrollo.
**Fecha:** 10-ago-2026.
**Origen:** hallazgo de Mesa de Developers (`fase3-motor-log.md` sección
9) — el motor es CPU-bound, no GPU-bound, para la arquitectura actual;
pedido de la PM: usar ese margen para VFX reales.

## 0. Por qué esto no es una sorpresa, y por qué no es un problema a corregir

**Ya estaba anticipado, no es un hallazgo nuevo — es la confirmación
precisa de algo que quedó anotado desde Fase 1.** Cuando se resolvió la
objeción de T4 (`definicion-escala-v1.md`), dejé escrito: "los bottlenecks
medidos hasta ahora son CPU-bound no GPU-bound... importaría más una vez
que empiece trabajo real de VFX/shaders." Ese momento es este. El barrido
de resolución de la sección 9 lo confirma con números — piso estable de
720p a 8K, ×36 en píxeles sin mover la aguja.

**Y no es que el motor "no explote la GPU" por descuido — es la
consecuencia directa de una decisión de diseño ya tomada.** La técnica de
ilustración elegida en Fase 2 (`diseno-grafico.md` sección 9) es
"vectorial plano de bordes marcados" — a propósito sin gradientes, sin
sombreado, sin especular, sin bisel — es decir, a propósito **la clase de
contenido más barata posible para la GPU.** Quads chicos (18-26px),
materiales simples, sin blend caro. El margen de GPU no es una falla, es
lo que queda de no haber gastado nada ahí todavía — la sección 9 lo dice
explícito: "no descarta que resolución importe con blend/transparencia
real o shaders". Ahora se prueba esa variable, con la misma disciplina que
ya midió VFX una vez (`fase2-vfx-benchmark.md`), no con la promesa
optimista de motor ("no debería ser problema salvo shaders caros") sin
confirmarla.

## 1. Cuatro candidatos, los cuatro atados a mecánica real — no solo decoración

| # | Efecto | Dispara con | Perfil de costo |
|---|---|---|---|
| 1 | **Quemadura** (pedido de la PM) | `EnemyStore.dot_time_left > 0` | **Sostenido** — activo mientras dura, puede estar prendido en muchos enemigos a la vez si hay varias torres BEAM/DoT cerca. El más importante de probar: es el único de los 4 que no es un burst. |
| 2 | **Explosión de impacto** (pedido de la PM) | `_apply_area_damage()` (splash) y el impacto del misil | Burst, uno por golpe de área — frecuencia baja (splash/misil no son los tipos que más disparan). |
| 3 | **Chispa de impacto** | Cualquier golpe de recto/perforante/homing | Burst, pero la frecuencia más alta de los 4 — cada disparo normal pega, no solo los de área. Candidato con más chance de costar algo. |
| 4 | **Efecto de muerte** | Enemigo llega a 0 de vida, antes de `EntityStore.release()` | Burst, frecuencia atada a cuánto mata el jugador — más presente cuanto mejor vaya la partida, no al revés. |

Los 4 son información para el jugador, no solo estética — quemadura y
chispa hacen visible algo que hoy es invisible (¿a quién le estoy
pegando? ¿quién tiene DoT?), explosión y muerte cierran el ciclo de
"pasó algo" que hoy no tiene ninguna señal.

**No incluyo** un efecto continuo para el rectángulo BEAM (láser/
lanzallamas) — hoy no tiene ninguna representación visual, pero eso es
una decisión de forma/aspecto (le toca a Arte, no es una prueba de costo
de GPU) más que algo para prototipar acá. Queda anotado para cuando
Arte lo evalúe, no es parte de esta tarjeta.

## 2. Metodología — la de siempre, con un ajuste importante

Mismo criterio que `fase2-vfx-benchmark.md`: costo unitario → escenario
real → escalar, nunca saltar al extremo. **El ajuste:** esa vez la
población de referencia era el pico sintético (×1.2 de T4). Acá **no** —
la frecuencia de disparo/muerte/DoT depende de mecánica de juego real
(cadencia real de `TOWER_TYPE_STATS`, no `DEV_FIRE_RATE_OVERRIDE`
forzado), así que hay que medir contra la población y cadencia que el
juego de verdad va a producir — **20-24 torres reales, ~2.000-2.400
enemigos, fire_rate sin pisar.** El escenario de 100 torres/cadencia
forzada (`fase2-benchmark-conjunto.md` secciones 13-16) fue diseñado para
encontrar el techo del motor, no para representar cuántas explosiones por
segundo pasan en una partida real — usarlo acá mediría un caso que no es
el que importa.

1. **Costo unitario:** cada efecto solo, pocas instancias, confirmar que
   se ve y dispara donde corresponde (igual que se hizo con las torretas:
   sprite-test antes de creer el número).
2. **Escenario real:** población real de combate (arriba), backend
   nativo (ya default), dirección fija de disparo (ya implementada) — los
   4 efectos a la vez, comparado contra el piso ya validado sin VFX en
   esa misma población.
3. **Si algo cuesta, aislar cuál** — mismo criterio de siempre, no un
   número agregado que tape cuál de los 4 es el caro. La quemadura (único
   sostenido) es la primera sospechosa si algo se mueve.

## 3. Qué no es esta tarjeta

No es arte final — reusar geometría/color simple (un `GPUParticles2D`
placeholder, un shader de tinte) alcanza, igual que se hizo para probar
sprite de torreta antes de que existiera arte real. No decide todavía si
estos efectos entran al juego — es dato de costo y de sensación, la
decisión de adoptarlos es aparte una vez medido.
