# Sprint 1 — Cronograma y asignaciones listas para repartir

**Base:** `sprint-01.md` (tareas T1–T9) + `auditoria-sprint1.md` (5 acciones previas
al arranque) + `definicion-escala-v1.md` (documento vivo que se cierra en T9).
Fechas: **Día 1 = viernes 07-ago-2026** (confirmado). Días hábiles, fin de semana
salteado.

| Día | Fecha |
|---|---|
| Día 0 (hoy) | jue 06-ago |
| Día 1 | vie 07-ago |
| Día 2 | lun 10-ago |
| Día 3 | mar 11-ago |
| Día 4 | mié 12-ago |
| Día 5 | jue 13-ago |

**Decisiones ya cerradas hoy (06-ago), no hace falta revisarlas en la sesión T1:**

| # | Decisión | Resultado |
|---|---|---|
| 1 | Dueño de Diseño de combate | El PM asume el rol para este sprint (sin diseñador de combate dedicado todavía) |
| 2 | Rol "Dirección de producto" | Es el mismo PM, no hay persona separada |
| 3 | Fecha de inicio del sprint | Viernes 07-ago-2026 |
| 4 | Horario de la sesión T1 | Mañana (vie 07-ago), por la tarde |
| 5 | T4 — hardware mínimo | Gama media: CPU 4 núcleos moderno, GPU eq. GTX 1660/RX 580, 8GB RAM |
| 6 | T6 — postura multijugador | No, fuera del roadmap visible |
| 7 | T7 (parte PM) — aprobación del spike | Pospuesta a propósito hasta ver el resultado de T1 (Día 2) |
| 8 | T9 — formato de publicación | Archivo nuevo, `docs/definicion-escala-v1.md` (ya creado como borrador) |

**Queda deliberadamente sin fijar hoy:** T2 (número objetivo de escala). El PM
eligió no prefijar la cifra de 20.000/30.000 propuesta por el director para no
ratificarla por default sin pasar por la sesión real — ver `auditoria-sprint1.md`,
riesgo de anclaje.

Como el PM cubre Diseño de combate y Dirección de producto, las columnas "con"
de varias tareas abajo quedan simplificadas a un solo dueño.

---

## A. Vista cronológica (para el cronograma / calendario)

### Día 0 — hoy, jue 06-ago

| Tarea | Dueño | Estado |
|---|---|---|
| Confirmar dueño de Diseño de combate | PM | ✅ Hecho — PM asume el rol |
| Aclarar rol "Dirección de producto" | PM | ✅ Hecho — es el PM |
| Fijar fecha de inicio y horario de T1 | PM | ✅ Hecho — vie 07-ago, tarde |
| Pre-decidir T4 (hardware) y T6 (multijugador) | PM | ✅ Hecho — ver tabla arriba |
| `git init` + `.gitignore` + commit inicial del POC actual | Dirección de Desarrollo | ⬜ Pendiente |
| Confirmar si el equipo tiene experiencia previa en GDExtension/C++/`godot-rust` | Dirección de Desarrollo | ⬜ Pendiente |
| Enviar convocatoria de T1 (mañana, tarde) con agenda y lista de invitados | PM | ⬜ Pendiente |

### Día 1 — vie 07-ago

| Tarea | Dueño | Notas |
|---|---|---|
| **T1** — Sesión de definición de alcance (2h), por la tarde | PM (cubre Diseño de combate y Dirección de producto); participa Dirección de Desarrollo; Negocio/Marketing si aplica | Foco real de la sesión: cerrar **T2** (número objetivo) y validar/ajustar T3, T5 y fechas de entrega — T4 y T6 ya vienen resueltos, se confirman rápido |
| **T3** arranca — documento de diseño de combate v1 | PM | No depende de T1 |
| **T5** arranca — definición de variedad de tipos de proyectil | PM | No depende de T1 |

### Día 2 — lun 10-ago

| Tarea | Dueño | Notas |
|---|---|---|
| **T2** documentado — número objetivo con pico, cifra dura | PM | Sale de T1, se escribe en `definicion-escala-v1.md` |
| **T7 (parte PM)** — aprobación formal del spike | PM | Ahora que T2 está cerrado, se decide acá, no antes |
| Dirección de Desarrollo empieza a confirmar nombres de 1-2 devs senior | Dirección de Desarrollo | Dedicación exclusiva desde día 1 de Sprint 2 |
| T3, T5 en progreso | PM | — |

### Día 3 — mar 11-ago

| Tarea | Dueño | Notas |
|---|---|---|
| T3, T5 en progreso | PM | — |
| Dirección de Desarrollo sigue cerrando nombres del equipo del spike | Dirección de Desarrollo | — |

### Día 4 — mié 12-ago

| Tarea | Dueño | Notas |
|---|---|---|
| **T7 (parte técnica)** cierra — nombres confirmados por escrito | Dirección de Desarrollo | No "vemos quién está libre" |
| T3, T5 deberían estar cerca del cierre | PM | Deadline Día 5 |
| **T8** (opcional) — andamiaje de carpetas `sim/`, `render/`, `data/` | Dirección de Desarrollo, si hay tiempo ocioso | Ya no bloqueado por falta de git (resuelto en Día 0) |

### Día 5 — jue 13-ago

| Tarea | Dueño | Notas |
|---|---|---|
| T3, T5 entregados — deadline | PM | — |
| **T9** — cerrar `docs/definicion-escala-v1.md` (ya existe como borrador) | PM | Completa los campos pendientes: T2, T3, T5, T7 |
| Chequeo de DoD del sprint | PM | Si falta algo, el sprint **no cierra** y el inicio de Sprint 2 se corre |

---

## B. Tarjetas por responsable (para copiar a cards / correos)

### 🟦 PM (vos) — cubre también Diseño de combate y Dirección de producto

| Campo | Detalle |
|---|---|
| **Tarjeta 1** | `git init` + `.gitignore` + commit inicial *(delegar a Dirección de Desarrollo si preferís)* |
| Estado | ⬜ Pendiente hoy |

| Campo | Detalle |
|---|---|
| **Tarjeta 2** | Enviar convocatoria de T1 (mañana, tarde) |
| Estado | ⬜ Pendiente hoy |
| DoD | Invitación enviada con hora concreta, agenda, y lista de invitados: Dirección de Desarrollo (+ Negocio/Marketing si aplica) |

| Campo | Detalle |
|---|---|
| **Tarjeta 3 (T1)** | Correr sesión de definición de alcance |
| Fecha límite | Día 1, vie 07-ago, tarde |
| Duración | 2h |
| DoD | T2 cerrado con cifra dura + pico; fechas de entrega de T3/T5 confirmadas; T4 y T6 ratificados o ajustados |

| Campo | Detalle |
|---|---|
| **Tarjeta 4 (T2)** | Documentar número objetivo de escala |
| Fecha límite | Día 2, lun 10-ago |
| DoD | Cifra dura + pico, sin ambigüedad, formato "N simultáneos, pico M" — escrito en `definicion-escala-v1.md` |

| Campo | Detalle |
|---|---|
| **Tarjeta 5 (T3)** | Documento de diseño de combate v1 |
| Fecha límite | Día 5, jue 13-ago |
| DoD | Lista cerrada de modificadores (críticos, resistencias, perforación, DoT, cadenas); lo que no entra queda "fase futura" |
| Por qué importa | Congela el esquema de `entity_store.gd` en Sprint 4+ |

| Campo | Detalle |
|---|---|
| **Tarjeta 6 (T5)** | Definición de variedad de tipos de proyectil |
| Fecha límite | Día 5, jue 13-ago, junto con T3 |
| DoD | Orden de magnitud de tipos con comportamiento único ("~10", "~50", "cientos") |

| Campo | Detalle |
|---|---|
| **Tarjeta 7 (T7 — parte PM)** | Aprobación formal del spike |
| Fecha límite | Día 2, lun 10-ago (después de cerrar T2) |
| DoD | Confirmación explícita de que el spike no entra a roadmap público hasta el checkpoint |

| Campo | Detalle |
|---|---|
| **Tarjeta 8 (T9)** | Cerrar `docs/definicion-escala-v1.md` |
| Fecha límite | Día 5, jue 13-ago |
| Depende de | T2, T3, T5, T7 (T4 y T6 ya están) |
| DoD | Sin checkboxes pendientes; cualquiera del equipo técnico puede leerlo y arrancar el spike sin preguntar nada más |

---

### 🟩 Dirección de Desarrollo (Director técnico)

| Campo | Detalle |
|---|---|
| **Tarjeta 1** | `git init` + `.gitignore` + commit inicial |
| Fecha límite | Hoy, jue 06-ago |
| DoD | Repo con historial arrancado, `.godot/imported` y `shader_cache` excluidos |

| Campo | Detalle |
|---|---|
| **Tarjeta 2** | Confirmar experiencia del equipo en GDExtension/C++/`godot-rust` |
| Fecha límite | Hoy, jue 06-ago |
| DoD | Respuesta explícita sí/no; si no, decidir si hace falta capacitación o refuerzo antes del spike |

| Campo | Detalle |
|---|---|
| **Tarjeta 3** | Participar en sesión T1 |
| Fecha límite | Día 1, vie 07-ago, tarde |

| Campo | Detalle |
|---|---|
| **Tarjeta 4 (T7 — parte técnica)** | Confirmar 1-2 devs senior por nombre para el spike |
| Fecha límite | Día 4, mié 12-ago |
| DoD | Nombres concretos, dedicación exclusiva, disponibles día 1 de Sprint 2 |

| Campo | Detalle |
|---|---|
| **Tarjeta 5 (T8, opcional)** | Andamiaje de carpetas `sim/`, `render/`, `data/` |
| Fecha límite | Cualquier momento del sprint, no prioritario |
| DoD | Estructura vacía creada, sin lógica |

---

### 🟧 Negocio / Marketing (solo si aplica — hardware comercial)

| Campo | Detalle |
|---|---|
| **Tarjeta 1** | Confirmar si el estudio ya tiene spec de hardware mínimo de otro título |
| Fecha límite | Día 1, vie 07-ago (antes de T1 si es posible) |
| DoD | Spec existente aportada, o confirmación de que no hay una — el borrador del PM (gama media) queda firme si no aparece nada mejor |

---

### ⬜ Equipo técnico del spike (1-2 devs senior — nombres se confirman en T7)

Sin tareas de código en Sprint 1 — regla explícita ("nadie escribe código de
núcleo todavía"). Única acción esta semana:

| Campo | Detalle |
|---|---|
| **Tarjeta 1** | Confirmar disponibilidad exclusiva desde Día 1 de Sprint 2 |
| Fecha límite | Cuando Dirección de Desarrollo los nombre (Día 4, mié 12-ago) |
| DoD | Confirmación individual de dedicación exclusiva, sin otros compromisos superpuestos |

---

## C. Borradores cortos de correo, por destinatario

**Para Dirección de Desarrollo:**
> Asunto: Sprint 1 — 2 acciones hoy, spike arranca en Sprint 2
> Antes de que arranque el sprint mañana necesito dos cosas resueltas hoy: (1)
> inicializar git en el repo (no lo tiene) para que el spike de Sprint 2 no
> arranque sin control de versiones, y (2) confirmarme si el equipo tiene
> experiencia previa con GDExtension/C++ o `godot-rust` — si no la tiene, prefiero
> saberlo ahora que en medio del spike. El resto de tu semana: sesión de alcance
> mañana (vie 07-ago) por la tarde, y confirmar 1-2 devs senior por nombre para el
> spike, dedicación exclusiva desde el día 1 de Sprint 2 (nombres para el
> miércoles 12-ago). Ya cerré yo mismo el hardware mínimo (gama media) y la
> postura de "no multijugador" — lo único que falta validar en la sesión es el
> número objetivo de escala.

**Para Negocio/Marketing (si aplica):**
> Asunto: Spec de hardware mínimo — ¿ya existe?
> Ya armé un borrador de hardware mínimo para el nuevo núcleo de simulación (gama
> media: CPU 4 núcleos, GPU eq. GTX 1660/RX 580, 8GB RAM). Antes de darlo por
> cerrado: ¿el estudio ya tiene una spec mínima definida para otro título? Si
> existe, la reusamos en vez de la mía. Necesito la respuesta antes de la sesión
> de mañana (vie 07-ago) por la tarde si es posible.

---

*Este documento es operativo, para repartir tareas. Las decisiones ya tomadas
(tabla al inicio) están reflejadas también en `sprint-01.md` (detalle oficial del
sprint) y en `definicion-escala-v1.md` (documento vivo que se cierra en T9). La
justificación de cada acción de Día 0 está en `auditoria-sprint1.md`.*
