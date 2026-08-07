# Sprint 1 — Definición de alcance y arranque

**Duración:** 1 semana (5 días hábiles)
**Rol que lo emite:** Product Manager
**Fecha de inicio:** viernes 07-ago-2026 (Día 1). Día 2 = lun 10-ago, Día 3 = mar
11-ago, Día 4 = mié 12-ago, Día 5 = jue 13-ago.
**Referencia:** `docs/sprint-plan.md` (sección 02) — este archivo es el detalle
ejecutable de ese sprint, listo para que cada dueño arranque sin tener que releer
el resto de la documentación.

> **#Auditor — [RESUELTO 06-ago]:** fecha de inicio confirmada por el PM el
> 06-ago. Queda cerrado.

**Objetivo del sprint (una frase):** cerrar todas las decisiones de producto que el
spike técnico necesita como input, para que Sprint 2 pueda arrancar el día 1 sin
bloqueos.

**No es objetivo de este sprint:** escribir código de núcleo, decidir arquitectura de
colisión/render (ya resuelta en `docs/directorsuggestions.md`, pendiente de
validación en el spike), ni tocar el POC existente.

---

## Participantes y roles

| Rol | Responsable | Carga esperada en el sprint |
|---|---|---|
| Product Manager | (vos) | Convoca sesión, redacta "Definición de escala v1", corre bloqueos |
| Dirección de Desarrollo | (vos) — mismo rol | Confirma decisiones técnicas del spike, revisa DoD técnico |
| Diseño de combate | (vos) — rol asumido temporalmente | Entrega documento de combate + definición de variedad de tipos |
| Dirección de producto | (vos) — mismo rol | Co-decide postura sobre multijugador (T6) |
| Negocio / Marketing | No aplica | Confirmado: no hay otro título del estudio con spec de hardware para contrastar |
| Equipo técnico del spike (T7) | (vos), con soporte de Claude Code para el hot path de GDExtension | Sin experiencia previa en GDExtension/C++/`godot-rust` — se cubre leyendo lo indispensable de bindings, apoyado en asistencia de IA para la implementación |

> **#Auditor — [RESUELTO 06-ago]:** "Dirección de producto" queda confirmado como
> el mismo PM, sin persona separada — ya no hace falta invitarlo aparte a T1.
> Queda cerrado.

> **#Auditor — [RESUELTO 06-ago, con nota]:** el PM asume el rol de Diseño de
> combate para este sprint en vez de dejarlo sin dueño. Esto destraba T3 y T5 a
> tiempo, pero vale una advertencia: el punto de la sección 03 del plan de acción
> sobre riesgo de anclaje en la cifra 20.000/30.000 se agrava un poco acá — la
> misma persona que va a validar esa cifra en la sesión T1 es quien también
> aprueba el spike (T7) y publica el resultado (T9). No hay una segunda voz de
> diseño de combate que la contraste. No es motivo para bloquear el sprint, pero
> sí vale registrarlo como algo a revisar si más adelante se suma un diseñador de
> combate dedicado — puede que la cifra necesite una segunda revisión con esa
> persona antes de congelar `entity_store.gd` en Fase 2.

---

## Tareas, en orden de ejecución

### T1 — Convocar y correr la sesión de definición de alcance
**Dueño:** PM
**Cuándo:** Día 1, viernes 07-ago, por la tarde
**Duración:** 2 horas
**Bloquea a:** T2, T3, T6

Agenda propuesta para la sesión (llevarla escrita, no improvisar):

1. Presentar la cifra propuesta por el director (20.000 proyectiles simultáneos,
   pico de 30.000) como punto de partida — no como número cerrado.
2. Diseño de combate valida o ajusta esa cifra contra lo que el gameplay real
   necesita.
3. Confirmar/definir hardware mínimo objetivo (traer lo investigado en T4 si ya está).
4. Postura sobre multijugador: sí / no / "más adelante con intención" — forzar una
   respuesta explícita, no dejarla abierta.
5. Cerrar fecha de entrega de T3 (documento de combate) y T5 (variedad de tipos)
   dentro de este mismo sprint.
6. Confirmar disponibilidad del equipo técnico para el spike (T7).

**Salida de la tarea:** notas de la sesión con las 4 decisiones tomadas (número,
hardware, multijugador, fechas de T3/T5) — no hace falta acta formal, alcanza con un
documento corto compartido con todos los participantes el mismo día.

---

### T2 — Número objetivo de escala
**Dueño:** PM + Diseño de combate
**Cuándo:** cierra en T1, se documenta día 2
**Depende de:** T1

Cifra dura de proyectiles y enemigos activos simultáneos, **incluyendo pico**. Nada
de "miles" o "decenas de miles" sin número. Formato esperado:

> "N proyectiles vivos simultáneos, pico de M en oleadas de clímax. K enemigos
> activos simultáneos, pico de L."

**Estado (PM, 06-ago):** deliberadamente **no** prefijado hoy — se decide recién en
T1 con la cifra del director (20.000/pico 30.000) como punto de partida de
discusión, no como número ya cerrado. Ver `auditoria-sprint1.md` sobre el riesgo de
anclarse en esa cifra sin contrastarla.

**Criterio de aceptación:** el número entra tal cual al documento de escala v1 (T9)
sin necesitar aclaración adicional.

---

### T3 — Documento de diseño de combate v1
**Dueño:** PM (rol de Diseño de combate)
**Cuándo:** entregar antes de que termine el sprint (fecha exacta se fija en T1)
**Depende de:** puede arrancar en paralelo a T1, no depende de la sesión

Lista **cerrada** de modificadores de daño que se soportan en v1: críticos,
resistencias elementales, perforación, daño en el tiempo, cadenas, u otros que el
equipo de combate considere. Todo lo que no entre en esta lista queda explícitamente
etiquetado como "fase futura, fuera de v1" — no se deja ambiguo.

**Por qué es bloqueante y no un nice-to-have:** el formato de la fila de datos por
proyectil en `entity_store.gd` (Sprint 4+) se congela contra este documento. Un
modificador agregado después de empezar a construir tiene costo de migración —
advertencia explícita del director.

**Criterio de aceptación:** cada modificador de la lista tiene, como mínimo, una
frase de cómo afecta al cálculo de daño (no hace falta el diseño numérico completo,
sí la mecánica).

---

### T4 — Spec de hardware mínimo
**Dueño:** PM (con apoyo de Negocio/Marketing si hace falta)
**Cuándo:** día 1–3, en paralelo a T1
**Depende de:** nada, puede arrancar de inmediato

Primero: buscar si el estudio ya tiene una spec de hardware mínimo definida para
otro título — reusarla si aplica. Si no existe, definirla ahora junto con
Negocio/Marketing (CPU, GPU, RAM mínimos objetivo).

**Decisión tomada (PM, 06-ago) — CERRADA:** gama media — CPU 4 núcleos moderno
(i5/Ryzen 5 o equivalente), GPU equivalente a GTX 1660 / RX 580, 8GB RAM.
Confirmado que no hay otro título del estudio con spec propia para reusar (no
aplica Negocio/Marketing) — esta spec queda como definitiva, no como borrador.

**Criterio de aceptación:** documento corto (puede ser media página) con la spec
final, listo para entrar a T9.

---

### T5 — Definición de variedad de tipos de proyectil
**Dueño:** PM (rol de Diseño de combate)
**Cuándo:** entregar antes de que termine el sprint, junto con T3
**Depende de:** puede arrancar en paralelo a T1

Responder explícitamente: de los tipos de proyectil que se esperan, ¿cuántos tienen
**comportamiento único** (no solo reskin visual)? Distinguir:

- Variedad visual (reskin, mismo comportamiento) → ya resuelto técnicamente con
  atlas + custom data de MultiMesh, no tiene costo de diseño adicional relevante.
- Variedad de comportamiento (cada tipo con lógica propia) → cada uno es trabajo de
  diseño y contenido real, no solo de motor.

**Criterio de aceptación:** un número aproximado de tipos con comportamiento único
esperados para v1 (no hace falta precisión, sí orden de magnitud: "~10", "~50",
"cientos").

---

### T6 — Postura sobre multijugador
**Dueño:** PM (también cubre "Dirección de producto")
**Cuándo:** cierra en T1
**Depende de:** T1

Respuesta explícita y por escrito: sí / no / "más adelante pero con intención". Si la
respuesta es "sí" en cualquier horizonte visible, marcarlo con urgencia — cambia la
arquitectura de simulación desde el diseño de `entity_store.gd`.

**Decisión tomada (PM, 06-ago): No.** Sin multijugador en el roadmap visible. La
arquitectura de simulación se diseña single-player desde el día 1, sin dejar
gancho explícito para netcode. Se puede reabrir en T1 si surge algo nuevo, pero
no es la postura de partida.

**Criterio de aceptación:** una línea en el documento de escala v1, sin ambigüedad.

---

### T7 — Aprobación formal del spike y confirmación de equipo
**Dueño:** vos, en ambos roles (PM aprueba / Dirección de Desarrollo confirma equipo)
**Cuándo:** Día 2 (aprobación) — ya no hace falta esperar a Día 3-4, ver estado abajo
**Depende de:** T1 (necesita el número objetivo para dimensionar el spike)

Dos partes:

1. Aprobar formalmente el spike de 1–2 semanas (Sprint 2–3) — no comprometer
   fecha de roadmap sin esto.
2. Confirmar el equipo del spike, dedicación exclusiva desde día 1 de Sprint 2.

**Estado (PM, 06-ago):**
- Aprobación formal (parte 1) pospuesta a propósito hasta ver el resultado de T1
  (en particular T2, el número objetivo). Agendada para el Día 2 (lun 10-ago),
  inmediatamente después de que cierre T1.
- Equipo (parte 2): **confirmado — desarrollador único, sin otro dev senior que
  sumar.** La ruta GDExtension del spike se apoya en asistencia de Claude Code
  para la implementación en C++/Rust, dado que no hay experiencia previa propia;
  el trabajo humano se concentra en leer y validar lo indispensable de bindings
  de Godot, no en escribir el binding desde cero sin apoyo. Esto reduce (no
  elimina) el riesgo de sesgo por curva de aprendizaje señalado en
  `directorsuggestions.md` — vale medir igual cuánto tiempo real consume esa
  curva dentro del corte de 10 días hábiles del spike.

**Criterio de aceptación:** aprobación registrada con fecha; confirmación de
dedicación exclusiva del desarrollador único desde día 1 de Sprint 2.

---

### T8 — (Opcional, sin bloquear el sprint) Andamiaje de proyecto
**Dueño:** PM/dev único, si hay tiempo ocioso
**Cuándo:** cualquier momento del sprint, no es prioridad

Crear la estructura de carpetas propuesta en `directorsuggestions.md`
(`sim/`, `render/`, `data/`) vacía, sin lógica. Esto no es un entregable medido en el
DoD del sprint — es trabajo de preparación opcional para no perder el primer día de
Sprint 2 en setup.

> **#Auditor — [RESUELTO 06-ago]:** repositorio git inicializado, `.gitignore`
> agregado (excluye `.godot/`, y ya deja previsto espacio para artefactos de build
> de GDExtension — `bin/`, `target/`, `*.o`, `*.so`, `*.dll`) y primer commit
> hecho (98 archivos). De paso, al revisar `POC/assets/` antes de commitear
> apareció un instalador de 84MB (`EpicInstaller-20.1.4.msi`) mezclado con los
> assets reales — se eliminó, no pertenecía al proyecto. Queda cerrado.

---

### T9 — Publicar "Definición de escala v1"
**Dueño:** PM
**Cuándo:** último día del sprint
**Depende de:** T2, T3, T4, T5, T6, T7

Documento corto que junta las salidas de T2–T7 en un solo lugar: número objetivo con
pico, hardware mínimo, documento de combate (o link a él), variedad de tipos,
postura sobre multijugador, y confirmación de que el spike está aprobado con equipo
asignado. Este es el input formal congelado que dispara Sprint 2 — sin este
documento completo, Sprint 2 no arranca.

**Decisión tomada (PM, 06-ago):** se publica como archivo nuevo,
`docs/definicion-escala-v1.md`, no mezclado con otro documento. Ver borrador
iniciado con los campos ya decididos (T4, T6) y pendientes marcados (T2, T3, T5,
T7).

**Criterio de aceptación:** cualquier persona del equipo técnico puede leer este
documento y empezar el spike sin tener que preguntar nada más.

---

## Definition of Done del sprint

El sprint está **done** solo si las 9 tareas están completas y "Definición de escala
v1" (T9) está publicada con:

- [ ] Número objetivo de escala, con pico, sin ambigüedad (T2)
- [ ] Spec de hardware mínimo definida (T4)
- [ ] Documento de diseño de combate v1 cerrado (T3)
- [ ] Definición de variedad de tipos de proyectil (T5)
- [ ] Postura sobre multijugador, explícita (T6)
- [ ] Spike aprobado formalmente, equipo confirmado por nombre (T7)

Si al final del día 5 falta cualquiera de estos puntos, el sprint **no está done** y
el inicio de Sprint 2 se corre — no se arranca el spike con inputs incompletos. Mejor
mover una fecha que medir el número equivocado.

---

## Riesgo específico de este sprint

Que la sesión de alcance (T1) termine sin cifras concretas y el equipo la dé por
"suficientemente cerrada" para avanzar. No lo es. Si el número sigue en "más o menos
miles" al cierre del sprint, T2 no está cumplida y el sprint no cierra, aunque el
resto de las tareas sí.
