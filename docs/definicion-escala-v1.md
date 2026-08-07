# Definición de escala v1

**Rol que lo emite:** Product Manager
**Estado:** BORRADOR — iniciado 06-ago-2026, se cierra el Día 5 de Sprint 1 (jue
13-ago-2026), según T9 de `sprint-01.md`.
**Propósito:** input formal congelado que dispara Sprint 2 (spike técnico). Sprint 2
no arranca hasta que este documento esté completo — sin campos pendientes.

---

## Número objetivo de escala (T2)

**Estado: PENDIENTE.** Se decide en la sesión T1 (vie 07-ago, tarde), con la cifra
propuesta por el director en `directorsuggestions.md` (20.000 proyectiles vivos
simultáneos, pico de 30.000 en oleadas de clímax) como punto de partida de
discusión — no como número cerrado. Ver `auditoria-sprint1.md` sobre el riesgo de
ratificarla por default sin contrastarla contra el gameplay real.

> N proyectiles vivos simultáneos, pico de M. K enemigos activos simultáneos,
> pico de L. *(a completar en T1)*

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

**Estado: PENDIENTE.** Dueño: PM (rol de Diseño de combate asumido para este
sprint). Lista cerrada de modificadores de daño (críticos, resistencias,
perforación, daño en el tiempo, cadenas) a soportar en v1 — todo lo que no entre
en la lista queda etiquetado "fase futura, fuera de v1". Fecha exacta de entrega
se fija en T1, dentro de este mismo sprint (a más tardar Día 5, jue 13-ago).

---

## Variedad de tipos de proyectil (T5)

**Estado: PENDIENTE.** Dueño: PM (rol de Diseño de combate asumido para este
sprint). Orden de magnitud de tipos con comportamiento único esperados para v1
(no reskin visual — eso ya está resuelto técnicamente con atlas + custom data de
MultiMesh). Se entrega junto con T3.

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

**Aprobación formal: PENDIENTE.** Pospuesta a propósito hasta ver el resultado de
T1 (en particular, el número objetivo de T2). Se decide Día 2 (lun 10-ago),
inmediatamente después del cierre de T1.

---

## Checklist de cierre

- [ ] Número objetivo con pico (T2)
- [x] Hardware mínimo (T4)
- [ ] Documento de combate v1 (T3)
- [ ] Variedad de tipos de proyectil (T5)
- [x] Postura sobre multijugador (T6)
- [x] Equipo del spike confirmado (T7, parte equipo — desarrollador único + Claude Code)
- [ ] Spike aprobado formalmente (T7, parte aprobación — se decide Día 2)

Mientras haya un ítem sin marcar, este documento **no está cerrado** y Sprint 2 no
arranca — regla explícita de `sprint-01.md`.
