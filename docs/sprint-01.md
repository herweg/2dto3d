# Sprint 1 — Definición de alcance y arranque

**Duración:** originalmente pensada como 1 semana (5 días hábiles) — ver
actualización abajo.
**Rol que lo emite:** Product Manager
**Fecha de inicio:** viernes 07-ago-2026 (arrancó de hecho el 06-ago, el mismo
día que se escribió este documento — ver actualización).
**Referencia:** `docs/sprint-plan.md` (sección 02) — este archivo es el detalle
ejecutable de ese sprint, listo para que cada dueño arranque sin tener que releer
el resto de la documentación.

> **#Auditor — [RESUELTO 06-ago]:** fecha de inicio confirmada por el PM el
> 06-ago. Queda cerrado.

> **Actualización 06-ago, más tarde — se abandona la cadencia de días fijos.**
> El desarrollador decidió seguir trabajando a discreción, sin atar las tareas
> restantes a un calendario de "Día 1/2/3...". Se mantiene todo lo demás del
> marco (DoD explícito, criterios de aceptación, cortes duros) — lo único que
> cambia es que no hay fecha de calendario asociada a cada tarea. Donde este
> documento diga "Día N" más abajo, léase como orden de ejecución, no como
> fecha — y el corte de "10 días hábiles" del spike (Sprint 2-3, ver
> `poc-scale-action-plan.md`) se reinterpreta como **10 días de trabajo
> efectivo acumulado**, no 10 días de calendario.

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
**Cuándo:** ~~sesión de 2h agendada~~ — **absorbida por el trabajo del 06-ago**,
ver estado abajo
**Bloquea a:** T2, T3, T6 — todas ya cerradas

**Estado: CERRADO (06-ago), sin necesidad de sesión formal separada.** En vez de
una sesión de 2h agendada para un día futuro, las decisiones que esta tarea
tenía que producir (T2, T4, T6, T7, y la decisión de motor) se cerraron en
conversación directa el mismo 06-ago, con investigación de precedentes de por
medio (ver `definicion-escala-v1.md`) — más rigurosas que una sesión informal,
porque cada una quedó documentada con su justificación. No queda nada de la
agenda original sin resolver.

**Salida de la tarea:** `definicion-escala-v1.md` completo — cumplido.

---

### T2 — Número objetivo de escala
**Dueño:** PM + Diseño de combate
**Cuándo:** cierra en T1, se documenta día 2
**Depende de:** T1

Cifra dura de proyectiles y enemigos activos simultáneos, **incluyendo pico**. Nada
de "miles" o "decenas de miles" sin número. Formato esperado:

> "N proyectiles vivos simultáneos, pico de M en oleadas de clímax. K enemigos
> activos simultáneos, pico de L."

**Estado (PM, 06-ago) — CERRADO, adelantado a T1:** con investigación de
precedentes del género de por medio (Brotato, Vampire Survivors, danmaku, y
precedente real en Godot vía plugins C++/MultiMesh y *Dome Keeper* shipeado),
se fijó en **~1.500–2.000 enemigos simultáneos (pico 3.000), ~6.000–8.000
proyectiles simultáneos (pico 10.000–12.000)** — no se ratificó la cifra del
director (20.000/30.000) tal cual, se ajustó a la baja con datos de mercado.
Detalle completo en `definicion-escala-v1.md`. Queda abierto a ajustarse más
adelante si surge algo nuevo de Diseño de combate, pero no es un placeholder —
es el número de trabajo.

**Criterio de aceptación:** el número entra tal cual al documento de escala v1 (T9)
sin necesitar aclaración adicional.

---

### T3 — Documento de diseño de combate v1
**Dueño:** PM (rol de Diseño de combate)
**Cuándo:** entregar antes de que termine el sprint (fecha exacta se fija en T1)
**Depende de:** puede arrancar en paralelo a T1, no depende de la sesión

**Estado: CERRADO (06-ago).** Ver `docs/combat-design-v1.md`. Los 5 modificadores
candidatos (críticos, resistencias elementales, perforación, daño en el tiempo,
cadenas) entran en v1, cada uno con su mecánica y su costo exacto en campos
nuevos de `entity_store.gd` documentado. Nada quedó en la lista original sin
resolver — no hubo que declarar ninguno "fase futura" de los cinco candidatos;
lo que sí queda fuera de v1 son variantes más amplias de cada uno (más de 2
elementos, DoT con stackeo, cadenas sin tope, etc.), listadas explícitamente en
el documento.

**Por qué era bloqueante y no un nice-to-have:** el formato de la fila de datos por
proyectil en `entity_store.gd` (Sprint 4+) se congela contra este documento. Un
modificador agregado después de empezar a construir tiene costo de migración —
advertencia explícita del director. Ya está resuelto.

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

**Estado: CERRADO (06-ago).** Ver `docs/projectile-variety-v1.md`. **~10-15
comportamientos únicos**, con roster inicial de 13 candidatos ya listado
(reusando lo que hoy existe — recto homing, orbital — más los ganchos mecánicos
de T3 — perforación, cadena — y variantes clásicas del género). Ninguno pide
estructura de datos nueva más allá de lo ya congelado en T3.

**Criterio de aceptación:** un número aproximado de tipos con comportamiento único
esperados para v1 (no hace falta precisión, sí orden de magnitud: "~10", "~50",
"cientos"). Cumplido.

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
**Cuándo:** ~~Día 2~~ **CERRADO 06-ago**, sin esperar a ningún día en particular
**Depende de:** T1 (necesita el número objetivo para dimensionar el spike) — T2 ya
cerró hoy, así que la dependencia está satisfecha

Dos partes:

1. Aprobar formalmente el spike de 1–2 semanas (Sprint 2–3) — no comprometer
   fecha de roadmap sin esto.
2. Confirmar el equipo del spike, dedicación exclusiva desde día 1 de Sprint 2.

**Estado (PM, 06-ago) — CERRADO, ambas partes:**
- **Aprobación formal:** aprobada. Marco de 1–2 semanas de spike (Sprint 2-3),
  con corte duro a los **10 días de trabajo efectivo acumulado** (no calendario
  — ver actualización sobre cadencia al inicio del documento). No entra a
  roadmap público hasta el checkpoint de decisión, como pidió el director.
- **Equipo:** confirmado — desarrollador único, sin otro dev senior que sumar.
  La ruta GDExtension del spike se apoya en asistencia de Claude Code para la
  implementación en C++/Rust, dado que no hay experiencia previa propia; el
  trabajo humano se concentra en leer y validar lo indispensable de bindings de
  Godot, no en escribir el binding desde cero sin apoyo. Esto reduce (no
  elimina) el riesgo de sesgo por curva de aprendizaje señalado en
  `directorsuggestions.md` — vale medir igual cuánto tiempo real consume esa
  curva dentro del corte de 10 días de trabajo del spike.

**Criterio de aceptación:** aprobación registrada con fecha; confirmación de
dedicación exclusiva del desarrollador único desde el arranque de Sprint 2.
Cumplido.

---

### T8 — (Opcional, sin bloquear el sprint) Andamiaje de proyecto
**Dueño:** PM/dev único, si hay tiempo ocioso
**Cuándo:** cualquier momento del sprint, no es prioridad

Crear la estructura de carpetas propuesta en `directorsuggestions.md`
(`sim/`, `render/`, `data/`) vacía, sin lógica. Esto no es un entregable medido en el
DoD del sprint — es trabajo de preparación opcional para no perder el primer día de
Sprint 2 en setup.

**Estado: CERRADO.** Carpetas creadas en `game/sim/`, `game/render/`,
`game/data/` (vacías, con `.gitkeep` para que git las trackee). Se creó un
directorio nuevo `game/` en la raíz del repo, hermano de `POC/`, en vez de
agregarlas dentro de `POC/` — coherente con la recomendación del memo de tratar
el POC como especificación validada, no como cimiento (`poc-scale-memo.md`,
sección 05, punto 1). Deliberadamente **no** se creó `project.godot` todavía —
inicializar el proyecto Godot real es el primer paso de Sprint 2, no de este
andamiaje, para que quede visible como trabajo del spike y no se pre-decida
en silencio acá.

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

- [x] Número objetivo de escala, con pico, sin ambigüedad (T2)
- [x] Spec de hardware mínimo definida (T4)
- [x] Documento de diseño de combate v1 cerrado (T3)
- [x] Definición de variedad de tipos de proyectil (T5)
- [x] Postura sobre multijugador, explícita (T6)
- [x] Spike aprobado formalmente, equipo confirmado (T7)

**Sprint 1 — DONE (06-ago-2026).** Cerrado en una sola sesión de trabajo el mismo
día en que se redactó este documento, no en 5 días de calendario — coherente con
la decisión de abandonar la cadencia de días fijos (ver actualización al inicio).
Sprint 2 (spike técnico) puede arrancar cuando el desarrollador decida retomarlo,
sin fecha impuesta.

---

## Riesgo específico de este sprint — [CERRADO, no se materializó]

El riesgo era que la sesión de alcance (T1) terminara sin cifras concretas y se
diera por "suficientemente cerrada" para avanzar igual. No pasó: T2 cerró con
cifra dura y pico (~6.000-8.000 proyectiles, pico 10-12k; ~1.500-2.000 enemigos,
pico 3.000), contrastada contra investigación de precedentes del género, no
"más o menos miles".
