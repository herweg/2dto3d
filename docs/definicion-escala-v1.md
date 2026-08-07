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

**Estado: DECIDIDO (PM, 06-ago).**

- CPU: 4 núcleos, clase i5 / Ryzen 5 o equivalente moderno
- GPU: equivalente a GTX 1660 / RX 580
- RAM: 8 GB

Gama media — sujeto a ajuste en T1 si el estudio ya tiene una spec definida para
otro título (en ese caso se reusa esa, no esta).

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

**Estado: PENDIENTE.** El PM pospuso a propósito la aprobación formal hasta ver el
resultado de T1 (en particular, el número objetivo de T2). Se decide Día 2
(lun 10-ago), inmediatamente después del cierre de T1. Dirección de Desarrollo
confirma nombres de 1–2 devs senior con dedicación exclusiva en la misma fecha.

---

## Checklist de cierre

- [ ] Número objetivo con pico (T2)
- [x] Hardware mínimo (T4)
- [ ] Documento de combate v1 (T3)
- [ ] Variedad de tipos de proyectil (T5)
- [x] Postura sobre multijugador (T6)
- [ ] Spike aprobado formalmente, equipo confirmado por nombre (T7)

Mientras haya un ítem sin marcar, este documento **no está cerrado** y Sprint 2 no
arranca — regla explícita de `sprint-01.md`.
