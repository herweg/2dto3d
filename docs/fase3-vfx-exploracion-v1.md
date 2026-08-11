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

## 2. Por qué separé mal la escala de la cadencia (corrección, PM, 10-ago)

Había descartado medir contra ~100 torres por venir del arnés de estrés
que forzaba el techo del motor. La PM separó lo que yo no había separado:
**100 torres no es en sí un número patológico — es la escala plausible de
la última pantalla real**, una vez que la progresión desbloquee
suficientes slots. Lo patológico de las secciones 13-16 no era la
*cantidad* de torres, era la **cadencia forzada**
(`DEV_FIRE_RATE_OVERRIDE` a 0.004s, ~150-400× la real). Ese eje sigue sin
corresponder acá — las 4 fases de abajo, en ambos escenarios de
población, corren siempre con `real-stats` (cadencia y rango reales, sin
pisar nada).

**Sobre "los enemigos no son tan costosos, es un poco irrelevante" (PM)
— cierto en general, con una excepción puntual.** Renderizado y
simulación de enemigos son baratos (costo por tipo de textura, no por
instancia), y desde que recto/perforante/splash dejaron de llamar
`_find_nearest_enemy()` (disparo en dirección fija), el costo de
targeting que sí escalaba con enemigos quedó acotado a homing/misil
nomás — la población de enemigos pesa mucho menos que cuando se midió
por primera vez. **Pero determina directo cuántas "quemaduras"
simultáneas puede haber en pantalla** — la única de las 4 variables de
esta tarjeta donde el conteo de enemigos sigue siendo justo lo que hay
que medir.

## 3. Las 4 fases, qué armar en cada una, y el test que la valida

Ninguna fase se salta — cada una depende de que la anterior haya pasado.
Todas con `backend=native` (ya default) y `real-stats` (cadencia/rango
sin pisar, en todas las fases, incluida la de escala).

### Fase 0 — Construir el placeholder de cada efecto

Geometría/color simple (`GPUParticles2D` de un color plano, o un shader
de tinte para la quemadura) — no arte final, mismo criterio que ya se usó
para probar sprite de torreta antes de que existiera arte real. Cuatro
flags nuevos, uno por efecto, para poder aislar en la Fase 4 sin
reconstruir nada: `vfx-burn=1`, `vfx-explosion=1`, `vfx-spark=1`,
`vfx-death=1`. Un quinto, `vfx-real=1`, activa los 4 juntos — el que se
usa en las Fases 2 y 3.

**No es una fase de medición** — es la que arma lo que las otras 3 miden.

### Fase 1 — Costo unitario (correctness, no performance)

**Cómo armar:** una escena chica, un puñado de torres/enemigos, cada
efecto encendido de a uno (`vfx-burn=1` solo, después `vfx-explosion=1`
solo, etc.) — no los 4 juntos todavía.

**Qué valida la idea:** que el efecto dispara donde y cuando corresponde,
no que sea barato — eso lo miden las Fases 2/3. Checklist, los 4 tienen
que cumplir los tres puntos:
- Aparece exactamente en el evento que le corresponde (quemadura nace/
  muere con `dot_time_left`, explosión en el punto de impacto de área,
  chispa en el punto de impacto normal, muerte en la posición del
  enemigo al llegar a 0 de vida) — verificado por captura, no a ojo en
  vivo.
- Ninguno deja rastro después de que su condición ya no aplica (quemadura
  que sigue prendida sin DoT activo = falla).
- Cero errores de consola en una corrida headless corta con los 4 flags
  encendidos a la vez, aunque sea con población mínima.

**No pasa a Fase 2 ningún efecto que falle cualquiera de los tres.**

### Fase 2 — Escenario cercano (20-24 torres reales)

**Cómo armar:** `stress-test stress-towers=24 stress-enemies=2400
real-stats vfx-real=1`, ventana, Vulkan real, backend nativo (default).

**Primero, sin VFX, en la misma sesión** — no reusar un número viejo:
demasiado cambió desde la última vez que se midió este punto exacto
(disparo en dirección fija, backend nativo por default) para confiar en
un piso de hace varios commits. Correr el mismo escenario sin
`vfx-real=1` primero, ese es el piso de referencia de hoy.

**Qué valida la idea:**
- **Piso con los 4 VFX ≥ 60fps** — la vara de siempre en este proyecto,
  sin excepción para VFX.
- Delta contra el piso sin VFX medido en el mismo paso, reportado aunque
  sea chico — igual que se hizo con el costo de las 8 texturas (~3%), un
  número de referencia para lo que sigue, no solo un pass/fail.

Si no pasa, no se sigue a Fase 3 sin antes pasar por Fase 4 (aislar cuál).

### Fase 3 — Escenario de escala (~100 torres reales)

**Cómo armar:** `stress-test stress-towers=100 stress-enemies=2000
real-stats vfx-real=1` — mismo criterio, `real-stats` sin pisar. **Dato
nuevo, no medido todavía:** nunca se corrió este escenario exacto (100
torres a cadencia real, sin forzar) ni siquiera sin VFX — las secciones
13-16 siempre forzaron la cadencia. Primer paso acá es esa corrida sin
VFX, antes de agregar nada.

**Qué valida la idea — vara más blanda que la Fase 2, a propósito:** esta
escala es "número de trabajo, no compromiso tomado"
(`plan-fases.md`) — no es un objetivo ya comprometido como 20-24 torres.
- Si el piso (con y sin VFX) ya está por debajo de 60fps **incluso sin
  VFX**, el problema es de escala en sí, no de estos efectos — se anota
  y no bloquea nada de esta tarjeta (es la misma discusión de brute-force
  targeting que ya quedó pendiente, condicionada a que la calibración de
  combate se acerque a esta composición).
- Si el piso sin VFX está bien pero cae con VFX, sí es información
  directa de esta tarjeta — pasa a Fase 4.

### Fase 4 — Aislar cuál, si algo no pasó en Fase 2 o 3

**Cómo armar:** repetir el escenario que falló, un flag a la vez
(`vfx-burn=1` solo, `vfx-explosion=1` solo, etc.) en vez de los 4 juntos
— mismo método que ya separó backend de targeting, y captura de pantalla
de dip periódico.

**Qué valida la idea:** identifica qué efecto explica la caída y cuánto,
no solo que "algo" cuesta. Con eso: (a) si es la quemadura y el costo
crece con cantidad de enemigos con DoT simultáneo, la palanca es un tope
de instancias (mismo patrón que `ZONE_FIXED_COUNT` para proyectiles de
zona), no descartar el efecto; (b) si es otro, se decide caso por caso
cuando aparezca el dato, no antes.

## 4. Qué no es esta tarjeta

No es arte final — reusar geometría/color simple (un `GPUParticles2D`
placeholder, un shader de tinte) alcanza, igual que se hizo para probar
sprite de torreta antes de que existiera arte real. No decide todavía si
estos efectos entran al juego — es dato de costo y de sensación, la
decisión de adoptarlos es aparte una vez medido.
