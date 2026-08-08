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

**Estado: CERRADO (PM, 06-ago).**

- CPU: 4 núcleos, clase i5 / Ryzen 5 o equivalente moderno
- GPU: equivalente a GTX 1660 / RX 580
- RAM: 8 GB

Gama media. Confirmado que no hay otro título del estudio con spec propia para
reusar — queda definitiva, no sujeta a revisión en T1.

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
