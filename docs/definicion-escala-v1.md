# Definición de escala v1

**Rol que lo emite:** Product Manager
**Estado:** **CERRADO — 06-ago-2026.** Completado en una sola sesión de trabajo,
no en los 5 días de calendario originalmente previstos por `sprint-01.md` — el
desarrollador decidió abandonar la cadencia de días fijos y trabajar a
discreción; este documento quedó completo el mismo día en que se abrió.
**Propósito:** input formal congelado que dispara Sprint 2 (spike técnico). Sprint 2
puede arrancar cuando el desarrollador decida retomarlo — sin campos pendientes
acá, sin fecha impuesta tampoco.

---

## Número objetivo de escala (T2)

**Estado: CERRADO (06-ago), adelantado a T1.** Fijado con investigación de
precedentes del género de por medio (ver más abajo), no solo sobre la cifra del
director — se contrastó contra Brotato (tope 100 enemigos), Vampire Survivors
(100.000+ entidades combinadas en late-game "roto", no su objetivo de diseño
sano), danmaku tradicional (cientos a bajos miles de balas) y precedente real en
Godot (Dome Keeper shipeado, plugins C++/MultiMesh para bullet-hell).

> **~1.500–2.000 enemigos activos simultáneos, pico de 3.000. ~6.000–8.000
> proyectiles vivos simultáneos, pico de 10.000–12.000.**

Es 15–20× el techo actual del POC (400–1.000), por encima de cualquier tower
defense o bullet-hell tradicional documentado, y bien por debajo del extremo
degradado de Vampire Survivors (100k+, no su punto sano). Queda abierto a
ajustarse si surge algo nuevo de diseño de combate más adelante, pero no es un
placeholder — es el número de trabajo para el spike.

---

## Decisión sobre el motor (memo Q7)

**Estado: CERRADO (06-ago), adelantado — el memo original (`poc-scale-memo.md`,
sección 03, pregunta 7) y el plan de acción proponían dejar esto abierto hasta
tener datos del spike. Se decidió cerrarlo hoy en base a investigación de
precedentes, no a datos propios del spike.**

**Seguimos con Godot 4.7 + GDExtension**, sin evaluar otro motor. Razones:

- La arquitectura propuesta en `directorsuggestions.md` (C++ vía GDExtension +
  MultiMesh + estructura de datos propia, sin `Area2D`) ya existe como patrón
  probado en Godot: plugins open-source (`BlastBullets2D`, `PerfBullets`)
  implementan exactamente esto para juegos bullet-hell.
- Hay precedente comercial shipeado: *Dome Keeper* (Godot, +26.000 reseñas
  "Muy positivas" en Steam) maneja miles de entidades en pantalla en producción.
- Godot no tiene equivalente a Unity DOTS (paralelismo automático multi-núcleo)
  — es el gap real. Pero GDExtension da velocidad nativa de un solo hilo, y
  `WorkerThreadPool` permite paralelizar a mano si hace falta. Esa palanca queda
  pendiente *si* el spike de un solo hilo se queda corto — no se construye antes
  de medir.
- Cambiar de motor ahora tiraría la capa de producto ya validada en el POC
  (armas, XP, oleadas, UI) sin necesidad probada.

**Riesgo a vigilar en el spike:** el GDExtension solo paga su costo si se
procesan arrays completos entre llamadas al motor, no si se llama a la API de
Godot por entidad — un loop con muchas llamadas chicas puede terminar más lento
que GDScript por el costo de marshaling. El diseño de `directorsuggestions.md`
(un solo `multimesh_set_buffer()` por frame, batch de colisión+daño) ya está
alineado con esto; vale la pena que la implementación del spike no se aparte de
ese patrón.

**Condición explícita de revisión (no es una decisión cerrada para siempre):**
esta decisión se reabre si aparece una **brecha grande entre el objetivo de T2 y
lo que el spike mide realmente**. Definición concreta de "brecha grande", para
que no quede como criterio subjetivo:

1. El spike mide el techo en GDScript puro (ruta A) y con el hot path en
   GDExtension de un solo hilo (ruta B), como ya especifica
   `poc-scale-action-plan.md` sección 02.
2. Si la ruta B (GDExtension) **no alcanza ~60% del objetivo de T2**
   (referencia: menos de ~4.800 proyectiles / ~1.200 enemigos simultáneos de la
   meta de ~8.000/~2.000), el primer paso **no** es cambiar de motor — es sumar
   `WorkerThreadPool` para paralelizar el batch entre núcleos, tal como ya
   preveía `directorsuggestions.md` sección 4 como optimización posterior.
3. **Recién si, incluso con GDExtension + `WorkerThreadPool`, la brecha sigue
   siendo grande** (mismo umbral de ~60%), se reabre formalmente la pregunta 7
   del memo (¿sigue siendo Godot el motor correcto?) como decisión de producto,
   no técnica — con los números reales del spike sobre la mesa, no antes.

Este umbral (60%) es un default razonable, no un compromiso rígido — ajustable
si al ver los datos del spike el criterio no se siente correcto.

---

## Hardware mínimo objetivo (T4)

**Estado: CERRADO (PM, 06-ago).** **Actualizado (PM, 08-ago).**

- CPU: i5-9400, 6 núcleos @2.9GHz (o equivalente)
- GPU: AMD Radeon RX Vega 56, 8GB, **discreta** (corregido 08-ago — ver
  objeción del director y respuesta de la PM más abajo; la línea original
  decía "integrada", lo cual no existe en esta combinación de CPU)
- RAM: 8 GB (sin cambios)

**Decisión (PM, 08-ago):** se redefine el hardware mínimo como el de la
máquina de desarrollo donde ya se corrieron el spike de Sprint 2 y el stress
test de Fase 2 — no hay diferencia significativa respecto a la spec de gama
media definida el 06-ago (de hecho, más núcleos de CPU), y se considera
suficiente. Esto **resuelve retroactivamente** la advertencia de "cota
optimista, no el piso de hardware mínimo" que traían `sprint-02.md` y
`fase2-stress-test.md`: ambos benchmarks ya miden contra el mínimo real, no
hace falta correrlos de nuevo en otra máquina.

Gama media original (06-ago, referencia histórica): CPU 4 núcleos moderno,
GPU eq. GTX 1660 / RX 580, 8GB RAM.

> **Director — objeción, 08-ago. No acepto esto como resuelto.** La propia
> línea de arriba dice "AMD Radeon RX Vega **(integrada)**" en la misma
> máquina que un **i5-9400** — un CPU Intel de escritorio. No existe ese
> combo: Intel no trae gráficos integrados AMD, y un i5-9400 de socket no es
> una APU. O es una Radeon RX Vega **discreta** (RX Vega 56/64), que es una
> gama bastante *por encima* de una GTX 1660/RX 580 — no "sin diferencia
> significativa" como dice la decisión de arriba — o directamente nadie
> verificó qué GPU tiene esta máquina antes de redefinir T4 con ella.
>
> Esto no es un detalle de forma. Firmé `fase2-motor-cristalizado.md`
> asumiendo margen de sobra en los tres ejes contra hardware mínimo real. Si
> la GPU real de esta máquina es una Vega discreta, ese margen puede no
> existir para alguien con una GTX 1660/RX 580 de verdad — exactamente el
> escenario que la advertencia original de "cota optimista" quería señalar,
> y que esta redefinición dio por resuelto sin comprobarlo.
>
> **No revierto la decisión — la PM la puede sostener — pero no la doy por
> cerrada hasta que pase una de estas dos cosas:**
> 1. Se confirma qué GPU tiene realmente la máquina de desarrollo (Administrador
>    de dispositivos / `dxdiag` alcanza, dos minutos) y, si es Vega discreta,
>    se decide con los ojos abiertos si el estudio acepta ese riesgo para
>    usuarios con GTX 1660/RX 580 real, o se consigue una máquina más
>    representativa para remedir; o
> 2. La PM confirma explícitamente que la redefinición es intencional pese a
>    la diferencia de GPU (una llamada de negocio legítima — "ya no nos
>    importa esa gama baja" — pero tiene que decirse así, no como "no hay
>    diferencia significativa").
>
> Hasta que uno de los dos pase, trato el margen reportado en
> `fase2-motor-cristalizado.md` como **no confirmado en hardware mínimo
> real**, igual que antes del 08-ago.

> **PM, 08-ago — respuesta a la objeción.** Confirmado: es una Vega 56 8GB
> **discreta** (corregido arriba), no integrada — el director tenía razón en
> que la línea original estaba mal. La autoricé yo. No es la gama "media"
> que habíamos definido el 06-ago, pero tampoco es gama alta moderna (Vega 56
> es de 2017); la trato como una base razonable dado que es la única máquina
> de test disponible ahora. Propuesta concreta para compensar la diferencia:
> **todo benchmark que se corra en esta máquina tiene que llegar a ~120% del
> objetivo real** (20% de margen arbitrario, no derivado de nada más fino)
> antes de darlo por bueno — si algo pasa 60fps con el objetivo pero no con
> ese 20% extra, no lo cuento como validado. Es un parche mientras no
> tengamos otra máquina para medir, no una solución definitiva.

> **Director — acepto, con un matiz que vale la pena que quede escrito.** El
> 20% es razonable como colchón general y prefiero esto — una decisión
> explícita con un número, aunque sea arbitrario — a la redefinición sin
> comprobar que había antes. Un matiz técnico que cambia cuánto me preocupa
> esto: **todo lo medido hasta ahora es CPU-bound** (consulta al hash
> espacial, targeting de torres por fuerza bruta — GDScript de un solo hilo),
> no GPU-bound. El CPU de esta máquina (i5-9400, 6 núcleos) está mucho más
> cerca de la spec original que la GPU — así que el riesgo real que este 20%
> tiene que cubrir hoy es más chico de lo que un GTX1660-vs-Vega56 sugeriría
> a primera vista. Eso cambia **cuándo** este parche deja de alcanzar: en
> cuanto el trabajo de gráficos meta algo con costo real de GPU (shaders más
> pesados, VFX con overdraw, partículas) en vez de los quads planos/sprites
> simples de hoy, ahí sí la brecha de GPU empieza a importar de verdad y el
> 20% plano deja de ser suficiente sin revisarlo. Lo dejo anotado para
> retomarlo en ese momento, no ahora — **T4 queda cerrado con esta condición.**

---

## Documento de diseño de combate v1 (T3)

**Estado: CERRADO (06-ago).** Ver `docs/combat-design-v1.md` — documento completo.

Los 5 modificadores candidatos entran en v1: críticos (0 campos nuevos, resuelto
al spawn), resistencias elementales acotadas a físico/mágico (+1 campo en
proyectil), perforación (+1 campo en proyectil), daño en el tiempo — un slot sin
stackeo, vive en el enemigo no en el proyectil (+2 campos en fila de enemigo,
0 en proyectil), y cadenas con tope duro de saltos vía el mismo hash espacial de
colisión (+1 campo en proyectil). Esquema de `entity_store.gd` (Sprint 4+) ya
tiene su lista de campos nuevos congelada.

---

## Variedad de tipos de proyectil (T5)

**Estado: CERRADO (06-ago).** Ver `docs/projectile-variety-v1.md`. **~10-15
comportamientos únicos** para v1, con un roster inicial de 13 candidatos (recto
homing, orbital, perforante, cadena, cono/abanico, homing en vuelo, bumerán,
zona persistente, aura creciente, pulso radial, carga, enjambre errático,
lanza). Ninguno pide una estructura de datos distinta a la ya congelada en
T3 — todos son variantes de movimiento sobre el mismo array plano de
proyectiles, seleccionadas por `type_id` como ya hace `TYPE_STATS` en `enemy.gd`.

---

## Postura sobre multijugador (T6)

**Estado: DECIDIDO (PM, 06-ago). No.**

Sin multijugador en el roadmap visible. La arquitectura de simulación se diseña
single-player desde el día 1 de Sprint 4+, sin gancho explícito para netcode.
Reabrible en T1 si surge información nueva, pero no es la postura de partida.

---

## Aprobación del spike y equipo (T7)

**Equipo: CERRADO (PM, 06-ago).** Desarrollador único, sin otro dev senior que
sumar. Sin experiencia previa en GDExtension/C++/`godot-rust` — se cubre con
apoyo de Claude Code para la implementación de esa ruta; el trabajo humano se
concentra en leer y validar lo indispensable de bindings de Godot.

**Aprobación formal: CERRADO (PM, 06-ago).** Spike de 1-2 semanas aprobado, con
corte duro a los 10 días de trabajo efectivo acumulado (no calendario — ver
`sprint-01.md`, actualización sobre cadencia). No entra a roadmap público hasta
el checkpoint de decisión.

---

## Checklist de cierre

- [x] Número objetivo con pico (T2)
- [x] Hardware mínimo (T4)
- [x] Documento de combate v1 (T3)
- [x] Variedad de tipos de proyectil (T5)
- [x] Postura sobre multijugador (T6)
- [x] Equipo del spike confirmado (T7, parte equipo — desarrollador único + Claude Code)
- [x] Spike aprobado formalmente (T7, parte aprobación)
- [x] Decisión sobre motor (memo Q7) — Godot + GDExtension, sin evaluar otro

**Todos los ítems cerrados — este documento está completo.** Sprint 2 (spike
técnico) puede arrancar cuando el desarrollador decida retomarlo, sin fecha
impuesta. Único condicionante activo: la condición de reapertura del motor
(sección "Decisión sobre el motor") si el spike mide una brecha grande contra
estos objetivos.
