# Sprint 1 — Cronograma y asignaciones listas para repartir

**Base:** `sprint-01.md` (tareas T1–T9) + `auditoria-sprint1.md` (acciones previas
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

**Contexto de equipo, confirmado hoy:** sos desarrollador único — cubrís PM,
Dirección de Desarrollo, Diseño de combate y Dirección de producto. No hay
Negocio/Marketing (no aplica, sin otro título del estudio). El spike de Sprint 2
lo corrés vos, apoyado en Claude Code para la parte de GDExtension (C++/Rust) por
no tener experiencia previa ahí. Esto simplifica el reparto: ya no hace falta
convocar a nadie externo para T1, es una sesión contigo mismo para pasar del modo
"lluvia de ideas" al modo "decisión escrita" — igual vale la pena bloquear el
horario y tratarla como sesión real, no como trámite.

**Decisiones ya cerradas hoy (06-ago):**

| # | Decisión | Resultado |
|---|---|---|
| 1 | Dueño de Diseño de combate | Vos, rol asumido |
| 2 | Rol "Dirección de producto" | Vos, mismo rol |
| 3 | Fecha de inicio del sprint | Viernes 07-ago-2026 |
| 4 | Horario de la sesión T1 | Mañana (vie 07-ago), por la tarde |
| 5 | T4 — hardware mínimo | **Cerrado.** Gama media: CPU 4 núcleos moderno, GPU eq. GTX 1660/RX 580, 8GB RAM |
| 6 | T6 — postura multijugador | **Cerrado.** No, fuera del roadmap visible |
| 7 | T7 (equipo) | **Cerrado.** Desarrollador único + Claude Code para GDExtension |
| 8 | T7 (aprobación formal del spike) | Pospuesta a propósito hasta ver el resultado de T1 (Día 2) |
| 9 | T9 — formato de publicación | Archivo nuevo, `docs/definicion-escala-v1.md` (ya creado, con T4/T6/T7-equipo completos) |
| 10 | Negocio/Marketing | No aplica |
| 11 | `git init` + `.gitignore` + commit inicial | **Hecho.** 98 archivos, `.godot/` excluido. De paso se encontró y borró un instalador de 84MB (`EpicInstaller-20.1.4.msi`) que estaba mezclado en `POC/assets/` |
| 12 | Experiencia en GDExtension/C++/`godot-rust` | Ninguna previa — cubierta con apoyo de Claude Code para la implementación |

**Queda deliberadamente sin fijar:** T2 (número objetivo de escala). Elegiste no
prefijar la cifra de 20.000/30.000 del director para no ratificarla por default
sin pasar por la sesión real — ver `auditoria-sprint1.md`, riesgo de anclaje. Se
cierra en T1, mañana.

---

## A. Vista cronológica (para el cronograma / calendario)

### Día 0 — hoy, jue 06-ago — **COMPLETO**

Las 8 acciones de hoy (roles, fecha, horario, T4, T6, T7-equipo, git, chequeo
GDExtension) ya están resueltas y aplicadas en `sprint-01.md` y
`definicion-escala-v1.md`. Solo queda pendiente, si querés hacerlo hoy en vez de
mañana temprano:

| Tarea | Estado |
|---|---|
| Bloquear en tu calendario la sesión T1 de mañana por la tarde (2h) | ⬜ Pendiente |

### Día 1 — vie 07-ago

| Tarea | Notas |
|---|---|
| **T1** — Sesión de definición de alcance (2h), por la tarde | Foco real: cerrar **T2** (número objetivo de escala) con la cifra del director (20.000/pico 30.000) como punto de partida a contrastar, no a ratificar de una. T4 y T6 ya vienen resueltos, se ratifican rápido si nada cambió |
| **T3** arranca — documento de diseño de combate v1 | No depende de T1, puede arrancar antes o en paralelo |
| **T5** arranca — definición de variedad de tipos de proyectil | No depende de T1 |

### Día 2 — lun 10-ago

| Tarea | Notas |
|---|---|
| **T2** documentado — número objetivo con pico, cifra dura | Sale de T1, se escribe en `definicion-escala-v1.md` |
| **T7 (aprobación formal del spike)** | Ahora que T2 está cerrado, se decide acá — marco de 1–2 semanas, corte duro a los 10 días hábiles |
| T3, T5 en progreso | — |

### Día 3 — mar 11-ago

| Tarea | Notas |
|---|---|
| T3, T5 en progreso | — |
| *(Opcional)* Repasar lo indispensable de bindings GDExtension/`godot-rust` antes de que arranque el spike | No bloquea el sprint, pero conviene no dejarlo para el día 1 de Sprint 2 |

### Día 4 — mié 12-ago

| Tarea | Notas |
|---|---|
| T3, T5 deberían estar cerca del cierre | Deadline Día 5 |
| **T8** (opcional) — andamiaje de carpetas `sim/`, `render/`, `data/` | Ya no bloqueado por falta de git |

### Día 5 — jue 13-ago

| Tarea | Notas |
|---|---|
| T3, T5 entregados — deadline | — |
| **T9** — cerrar `docs/definicion-escala-v1.md` | Completa los campos que faltan: T2, T3, T5, T7-aprobación (T4, T6, T7-equipo ya están) |
| Chequeo de DoD del sprint | Si falta algo, el sprint **no cierra** y el inicio de Sprint 2 se corre |

---

## B. Tarjetas (para copiar a cards) — todas bajo el mismo dueño: vos

| Campo | Detalle |
|---|---|
| **Tarjeta 1** | Bloquear horario de la sesión T1 en el calendario |
| Fecha límite | Hoy o a primera hora de mañana |
| Estado | ⬜ Pendiente |

| Campo | Detalle |
|---|---|
| **Tarjeta 2 (T1)** | Correr sesión de definición de alcance |
| Fecha límite | Día 1, vie 07-ago, tarde |
| Duración | 2h |
| DoD | T2 cerrado con cifra dura + pico; fechas de entrega de T3/T5 confirmadas; T4 y T6 ratificados |

| Campo | Detalle |
|---|---|
| **Tarjeta 3 (T2)** | Documentar número objetivo de escala |
| Fecha límite | Día 2, lun 10-ago |
| DoD | Cifra dura + pico, sin ambigüedad, formato "N simultáneos, pico M" — escrito en `definicion-escala-v1.md` |

| Campo | Detalle |
|---|---|
| **Tarjeta 4 (T3)** | Documento de diseño de combate v1 |
| Fecha límite | Día 5, jue 13-ago |
| DoD | Lista cerrada de modificadores (críticos, resistencias, perforación, DoT, cadenas); lo que no entra queda "fase futura" |
| Por qué importa | Congela el esquema de `entity_store.gd` en Sprint 4+ |

| Campo | Detalle |
|---|---|
| **Tarjeta 5 (T5)** | Definición de variedad de tipos de proyectil |
| Fecha límite | Día 5, jue 13-ago, junto con T3 |
| DoD | Orden de magnitud de tipos con comportamiento único ("~10", "~50", "cientos") |

| Campo | Detalle |
|---|---|
| **Tarjeta 6 (T7 — aprobación)** | Aprobación formal del spike |
| Fecha límite | Día 2, lun 10-ago (después de cerrar T2) |
| DoD | Confirmación explícita registrada, con marco de tiempo (1–2 semanas, corte duro a los 10 días hábiles) |

| Campo | Detalle |
|---|---|
| **Tarjeta 7 (T9)** | Cerrar `docs/definicion-escala-v1.md` |
| Fecha límite | Día 5, jue 13-ago |
| Depende de | T2, T3, T5, T7-aprobación |
| DoD | Sin checkboxes pendientes — vos mismo, el día 1 de Sprint 2, tenés que poder arrancar sin preguntarte nada más |

| Campo | Detalle |
|---|---|
| **Tarjeta 8 (T8, opcional)** | Andamiaje de carpetas `sim/`, `render/`, `data/` |
| Fecha límite | Cualquier momento del sprint, no prioritario |
| DoD | Estructura vacía creada, sin lógica |

| Campo | Detalle |
|---|---|
| **Tarjeta 9 (opcional, previa al spike)** | Repasar lo indispensable de GDExtension/`godot-rust` (setup de build, hot-reload, superficie mínima de la API) |
| Fecha límite | Antes de Día 1 de Sprint 2 |
| Por qué importa | Evita que el spike mida "curva de aprendizaje" en vez de "la arquitectura escala" — ver nota en `directorsuggestions.md` |

---

*Este documento es operativo. Las decisiones ya tomadas (tabla al inicio) están
reflejadas también en `sprint-01.md` (detalle oficial del sprint) y en
`definicion-escala-v1.md` (documento vivo que se cierra en T9). La justificación
de cada acción de Día 0 está en `auditoria-sprint1.md`.*
