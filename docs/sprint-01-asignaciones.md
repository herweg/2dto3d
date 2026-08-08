# Sprint 1 — Cierre y lo que sigue

**Actualización 06-ago, más tarde:** este documento nació como cronograma por
días (Día 0-5, fechas de calendario) para repartir tareas y correos. Se
abandonó esa cadencia — el desarrollador decidió seguir trabajando **a
discreción**, sin fechas fijas. Como resultado, **Sprint 1 completo se cerró en
una sola sesión de trabajo el 06-ago**, no en 5 días de calendario. Este
documento queda como resumen de cierre en vez de cronograma — la vista por
días se retira porque ya no aplica.

**Fuente de verdad actualizada:** `docs/definicion-escala-v1.md` (todos los
campos cerrados) y `docs/sprint-01.md` (detalle de cada tarea, con su estado).
Este archivo es un resumen, no reemplaza a esos dos.

---

## Qué se cerró el 06-ago (Sprint 1 completo)

| Ítem | Resultado |
|---|---|
| Roles (Diseño de combate, Dirección de producto, Dirección de Desarrollo) | Todos el mismo desarrollador único |
| `git init` + `.gitignore` + commit inicial | Hecho — 98 archivos, `.godot/` excluido. Se encontró y borró un instalador de 84MB mezclado en `POC/assets/` |
| Push inicial del repo | Hecho — `github.com/herweg/2dto3d`, rama `main`, identidad `herweg` (sin nombre real en el historial) |
| **T2** — Número objetivo de escala | ~1.500-2.000 enemigos simultáneos (pico 3.000), ~6.000-8.000 proyectiles (pico 10.000-12.000) — con investigación de precedentes del género |
| **Decisión de motor (memo Q7)** | Godot 4.7 + GDExtension, sin evaluar otro — con condición explícita de reapertura si hay brecha grande (~60% del objetivo) en el spike |
| **T3** — Documento de diseño de combate v1 | `docs/combat-design-v1.md` — 5 modificadores (críticos, resistencias, perforación, DoT, cadenas), cada uno con costo exacto en `entity_store.gd` |
| **T4** — Hardware mínimo | Gama media: CPU 4 núcleos, GPU eq. GTX 1660/RX 580, 8GB RAM |
| **T5** — Variedad de tipos de proyectil | `docs/projectile-variety-v1.md` — ~10-15 comportamientos únicos, roster inicial de 13 |
| **T6** — Postura sobre multijugador | No |
| **T7** — Aprobación del spike + equipo | Aprobado, 1-2 semanas / 10 días de trabajo efectivo de corte duro. Equipo: desarrollador único + Claude Code para GDExtension |
| **T9** — Publicar "Definición de escala v1" | `docs/definicion-escala-v1.md`, completo, todos los checkboxes cerrados |

---

## Lo que queda, sin fecha

| Ítem | Estado | Notas |
|---|---|---|
| ~~T8~~ — Andamiaje de carpetas | **Cerrado.** `game/sim/`, `game/render/`, `game/data/` creadas (vacías, `.gitkeep`). `game/` es carpeta nueva en la raíz, hermana de `POC/` — el POC no se toca. |
| **Sprint 2 — Spike técnico** | **Planificado.** Ver `docs/sprint-02.md` — 6 pasos en orden de dependencia (herramienta de medición → proyecto Godot en `game/` → caso sintético → Ruta A GDScript → Ruta B GDExtension si hace falta → `WorkerThreadPool` si hace falta → checkpoint). Listo para arrancar cuando se retome, sin fecha. |

---

*Este documento deja de actualizarse día a día. El seguimiento de lo que sigue
vive en `definicion-escala-v1.md` (qué está decidido) y en el trabajo real del
spike una vez que arranque — sin cronograma de calendario de por medio.*
