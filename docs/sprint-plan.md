# Plan de sprints — POC → núcleo escalable

**Rol:** Product Manager
**Fecha:** 06 agosto 2026
**Insumos:** `docs/poc-scale-memo.md`, `docs/directorsuggestions.md`,
`docs/poc-scale-action-plan.md`
**Estado:** propuesta de secuenciación. El Sprint 1 está detallado y listo para
arrancar; todo lo posterior al checkpoint de decisión es tentativo a propósito —
no lo voy a fijar en firme hasta tener los datos del spike, por la misma razón que
ambos documentos técnicos piden no comprometer fecha antes de eso.

> **Actualización 06-ago, más tarde:** Sprint 1 se cerró completo el mismo día
> (ver `sprint-01-asignaciones.md`), y a partir de ahí el desarrollador decidió
> abandonar la cadencia de sprints atados a calendario — se sigue trabajando a
> discreción. Los conceptos de este documento (criterios de salida explícitos,
> corte duro del spike a los 10 días de trabajo efectivo, no fijar Fase 2 hasta
> el checkpoint) siguen vigentes; lo que ya no aplica es la duración literal de
> "1 semana por sprint" — no hay más sprints numerados con fecha, hay trabajo
> secuenciado por dependencias.

---

## 00. Cadencia elegida

**Sprints de 1 semana, no 2.** Dos razones:

1. El spike tiene un techo duro de 10 días hábiles (definido en el plan de acción).
   Un sprint de 2 semanas lo escondería dentro de un solo ciclo y perdería la
   oportunidad de cortar temprano si a mitad de camino ya hay señal clara.
2. Esta etapa es de decisiones secuenciales con dependencias fuertes (no congelar el
   esquema de datos sin el documento de combate, no arrancar el spike sin el número
   objetivo). Ciclos cortos me dejan re-priorizar rápido si algo no cierra a tiempo,
   en vez de descubrirlo dos semanas después.

Cada sprint cierra con una demo/revisión corta (30 min, PM + Dirección de Desarrollo
+ quien corresponda del sprint) con un criterio de salida explícito — no "avanzamos
bastante", sino sí/no sobre el objetivo del sprint.

No planifico en detalle más allá del checkpoint de decisión (fin de Sprint 3). A
partir de ahí, el contenido de los sprints depende de qué haya validado el spike, así
que fijarlo ahora sería planificar sobre datos que todavía no existen.

---

## 01. Vista general

```
Sprint 1  →  Definición de alcance + arranque de trabajo paralelo
Sprint 2  →  Spike técnico, semana 1
Sprint 3  →  Spike técnico, semana 2 + checkpoint de decisión
──────────────────────────────────────────────────────────────  ← re-planificación real
Sprint 4+ →  Rediseño de núcleo (alcance exacto: post-checkpoint)
```

---

## 02. Sprint 1 — Definición de alcance y arranque

**Objetivo del sprint:** cerrar todas las decisiones de producto que el spike
necesita como input, y dejar el equipo técnico listo para arrancar el spike el primer
día del Sprint 2 sin bloqueos.

**Duración:** 1 semana.

**Por qué es el primer sprint y no el spike mismo:** arrancar el spike sin estas
decisiones lo invalida — mediría un número que nadie pidió, sobre una distribución de
daño que puede cambiar el esquema de datos después. El memo y el director son
explícitos en esto (memo Q1/Q5/Q6, director #1/#3/#4/#7); tratarlo como sprint propio
en vez de "reunión previa informal" es lo que lo vuelve un compromiso real y no un
trámite.

### Objetivos concretos (Definition of Done del sprint)

| # | Entregable | Dueño | DoD |
|---|---|---|---|
| 1 | Sesión de definición de alcance realizada | PM (convoca) | Sesión de 2h con Dirección de Desarrollo, Diseño de combate, y Negocio/Marketing si aplica hardware comercial. Ocurre en los primeros 2 días del sprint, no al final. |
| 2 | Número objetivo de escala fijado | PM + Diseño de combate | Cifra dura de proyectiles/enemigos simultáneos **y pico** (punto de partida: la propuesta del director, 20.000/pico 30.000, ajustable en la sesión). Sin rango ("miles a decenas de miles"), sin ambigüedad. |
| 3 | Spec de hardware mínimo | PM + Negocio | Documento corto: CPU/GPU/RAM mínimos objetivo. Reusa spec de otro título del estudio si existe. |
| 4 | Documento de diseño de combate v1 | Diseño de combate | Lista **cerrada** de modificadores de daño (críticos, resistencias, perforación, DoT, cadenas) que se van a soportar en v1. Cualquier cosa fuera de esta lista es "fase futura", explícitamente. |
| 5 | Definición de variedad de tipos de proyectil | Diseño de combate | Respuesta explícita: ¿cuántos tipos con comportamiento único se esperan (no reskin), aproximado? Esto no bloquea el spike pero sí el diseño de `entity_store.gd` en Sprint 4+. |
| 6 | Postura sobre multijugador | PM + Dirección de producto | Sí / no / "más adelante con intención", por escrito. |
| 7 | Aprobación formal del spike | PM + Dirección de Desarrollo | Confirmación explícita de que el spike de 2 semanas (Sprint 2–3) está aprobado y no entra a ningún roadmap público hasta el checkpoint — pedido directo del director (sección 3, punto 5). |
| 8 | Equipo del spike confirmado | Dirección de Desarrollo | 1–2 devs senior, dedicación exclusiva, disponibles desde el día 1 de Sprint 2. |
| 9 | "Definición de escala v1" publicada | PM | Documento corto que junta 2–6, es el input formal congelado para Sprint 2. |

### Qué NO entra en este sprint (a propósito)

- Nada de código de spike. El equipo técnico puede empezar a preparar el andamiaje de
  proyecto (estructura de carpetas `sim/`, `render/`, `data/` de `directorsuggestions.md`)
  si tiene tiempo ocioso, pero no es un entregable del sprint ni se mide en el DoD.
- No se decide arquitectura de colisión ni motor — eso ya está resuelto por la
  propuesta del director y pendiente de validación en el spike, no es tarea de este
  sprint.
- No se toca el POC existente.

### Riesgo específico de este sprint

Que la sesión de alcance (ítem 1) termine sin números concretos y el sprint "se dé
por cumplido" igual. No lo acepto: si al cierre del sprint el ítem 2 sigue en
"más o menos miles", el sprint no está done y el inicio del spike se corre — prefiero
mover una fecha a arrancar el spike sobre un objetivo mal definido.

---

## 03. Sprint 2 — Spike técnico, semana 1

**Objetivo del sprint:** implementación base de la propuesta de `directorsuggestions.md`
en GDScript puro (`entity_store.gd`, `spatial_hash.gd`, batch de movimiento+colisión,
`multimesh_set_buffer`), y primera medición contra el número objetivo fijado en
Sprint 1.

**Entra si y solo si** Sprint 1 cerró con DoD completo. Si no, este sprint se
redefine como continuación de Sprint 1, no como spike a ciegas.

**Salida esperada al final del sprint:** primer dato duro — ¿a cuántas entidades cae
de 60 fps la ruta GDScript puro, en el hardware mínimo definido? Esto determina si el
Sprint 3 necesita medir la ruta GDExtension en serio o si alcanza con confirmar el
resultado.

*(No detallo tareas día a día acá — eso lo arma Dirección de Desarrollo al planificar
el sprint; mi rol es fijar el objetivo y el criterio de salida, no el plan de
implementación.)*

---

## 04. Sprint 3 — Spike técnico, semana 2 + checkpoint

**Objetivo del sprint:** completar la medición (incluyendo la ruta GDExtension si
Sprint 2 no alcanzó el número objetivo en GDScript puro) y cerrar el checkpoint de
decisión.

**Checkpoint de decisión (fin de sprint, PM + Dirección de Desarrollo):**

- ¿El spike alcanza el número objetivo? ¿En qué ruta?
- ¿Se autoriza construir el módulo GDExtension, o GDScript puro alcanza?
- ¿Se reabre la pregunta de motor (memo Q7)?
- Recién acá se fija alcance y fecha real de Sprint 4+.

**Regla de corte:** si a los 10 días hábiles acumulados de spike (Sprint 2 + 3) no
hay señal clara, corto igual en este checkpoint y decido con los datos que haya —
no extiendo el spike a un Sprint 4 de "más spike".

---

## 05. Sprint 4 en adelante — tentativo, a definir en el checkpoint

Intencionalmente no detallado todavía. Lo que sí puedo anticipar de la estructura,
sin comprometerla:

- Un sprint de arranque de Fase 2 dedicado a congelar el esquema de `entity_store.gd`
  contra el documento de diseño de combate (Sprint 1, ítem 4) — esto es lo primero
  que se hace, porque el director advierte que cada campo agregado después tiene
  costo de migración.
- La construcción del núcleo (`sim/`, `render/`) probablemente se planifica en
  sprints separados por sistema (`entity_store` → `spatial_hash` → `projectile_system`
  → `entity_render_sync`), en el orden de dependencia que ya sugiere la arquitectura
  de `directorsuggestions.md`.
- El port de la capa de producto (armas, XP, oleadas, HUD) puede correr en paralelo
  en un tren de sprints separado, porque no depende del núcleo terminado — solo de
  que la API de spawn (`ProjectileSystem.spawn(...)`) esté estable.

Vuelvo a planificar esto en detalle apenas cierre el checkpoint del Sprint 3, con los
números reales en la mesa.

---

## 06. Resumen para el equipo

- **Esta semana (Sprint 1):** nadie escribe código de núcleo todavía. El trabajo es
  cerrar decisiones de producto — sesión de alcance, documento de combate, spec de
  hardware.
- **Semanas 2–3 (Sprint 2–3):** spike técnico, dedicación exclusiva de 1–2 devs
  senior, con corte duro a los 10 días hábiles.
- **Semana 4 en adelante:** se planifica recién después del checkpoint, con datos
  reales.
