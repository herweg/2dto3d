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

## 2. Metodología — corregida (PM, 10-ago): dos escalones, no uno

**Corrección sobre la sección original.** Había propuesto medir solo
contra 20-24 torres (el objetivo ya validado de Fase 2), descartando el
escenario de ~100 torres por venir del arnés de estrés diseñado para
forzar el techo del motor. La PM señaló algo que no separé bien: **100
torres no es en sí mismo un número patológico — es la escala plausible de
la última pantalla real**, una vez que la progresión desbloquee
suficientes slots. Lo patológico de las secciones 13-16 no era la
*cantidad* de torres, era la **cadencia forzada**
(`DEV_FIRE_RATE_OVERRIDE` a 0.004s, ~150-400× la real) para empujar
proyectiles — ese sigue sin corresponder acá. Mezclé las dos cosas, las
separo:

1. **Costo unitario:** cada efecto solo, pocas instancias — igual que
   siempre, sin cambios.
2. **Escenario cercano — 20-24 torres reales, ~2.000-2.400 enemigos,
   `fire_rate` sin pisar.** Lo que va a existir primero, y contra lo que
   la calibración de combate ya en curso va a trabajar.
3. **Escenario de escala — ~100 torres reales (número de trabajo, no
   definitivo — puede terminar siendo 50 o más), ~2.000 enemigos,
   `fire_rate` sin pisar igual, rango real (no `DEV_RANGE_OVERRIDE`).**
   Ni la cantidad de torres ni la de enemigos se fuerzan — solo se
   escala la composición manteniendo la cadencia real, que es
   exactamente lo que estas VFX van a disparar de verdad en el juego
   final. Corre en paralelo al 2, no en vez de.
4. **Si algo cuesta en el escalón 3 pero no en el 2** — no es motivo
   para descartar el efecto, es información para decidir si necesita un
   límite (ej. tope de instancias simultáneas) antes de llegar a esa
   escala, mismo espíritu que ya usó `ZONE_FIXED_COUNT` para proyectiles
   de zona.
5. **Aislar cuál, no un número agregado** — misma disciplina de siempre.

**Sobre "los enemigos no son tan costosos, es un poco irrelevante"
(PM) — cierto en general, pero no para el efecto #1 específicamente.**
Renderizado y simulación de enemigos son baratos (costo por tipo de
textura, no por instancia — confirmado varias veces ya) y desde que
recto/perforante/splash dejaron de llamar `_find_nearest_enemy()`
(`plan-fases.md`, disparo en dirección fija), el costo de targeting que
sí escalaba con cantidad de enemigos quedó acotado a homing/misil
solamente — la población de enemigos importa mucho menos hoy que cuando
se midió por primera vez. **Pero la cantidad de enemigos determina
directo cuántas "quemaduras" simultáneas puede haber en pantalla** (un
efecto sostenido por enemigo con DoT activo) — es la única de las 4
variables de esta tarjeta donde el conteo de enemigos sigue siendo la
variable que importa medir, no una que se pueda ignorar de entrada.

## 3. Qué no es esta tarjeta

No es arte final — reusar geometría/color simple (un `GPUParticles2D`
placeholder, un shader de tinte) alcanza, igual que se hizo para probar
sprite de torreta antes de que existiera arte real. No decide todavía si
estos efectos entran al juego — es dato de costo y de sensación, la
decisión de adoptarlos es aparte una vez medido.
