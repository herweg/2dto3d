# Auditoría independiente — plan POC → núcleo escalable, previo a Sprint 1

**Rol:** Auditor externo de soluciones informáticas
**Fecha:** 06 agosto 2026
**Alcance:** revisión de `poc-scale-memo.md`, `directorsuggestions.md`,
`poc-scale-action-plan.md`, `sprint-plan.md` y `sprint-01.md`, más una verificación
directa del código en `/POC` y del estado del repositorio.
**Encargo:** evaluar si el plan tiene cimientos sólidos para que Sprint 1 arranque
mañana tal como está escrito, o si hoy es el día para ajustar algo antes de eso.

---

## 00. Veredicto

**El plan es de una calidad de proceso inusualmente alta — pero tenía cuatro huecos
de cimientos sin resolver que el propio texto ya intuía y no cerraba.** No eran
fallas de razonamiento técnico ni de secuenciación: eran precondiciones que los
documentos daban por sentadas ("Diseño de combate", "Dirección de producto", "el
spike escribe código sobre esto") sin confirmar que existieran hoy.

**Actualización 06-ago, tarde — los cuatro puntos de la sección 03 están
resueltos.** Se confirmó que es un proyecto de desarrollador único (cubre PM,
Dirección de Desarrollo, Diseño de combate y Dirección de producto), lo cual
resuelve 3.1 y 3.2 de raíz; se inicializó git con `.gitignore` y primer commit
(3.3); y se fijó fecha de inicio (3.4, viernes 07-ago-2026). Detalle de cada uno
en la sección 03. Sprint 1 arranca mañana sin bloqueantes de cimientos pendientes.

---

## 01. Validación técnica — lo que confirmé contra el código real

Antes de auditar el proceso, verifiqué que el diagnóstico técnico del memo no fuera
retórica. Leí `projectile.gd`, `enemy.gd`, `weapon_base.gd`, `weapon_orbe.gd`,
`projectile_renderer.gd`, `enemy_renderer.gd`, `projectile_pool.gd`, `enemy_pool.gd`,
`WallManager.gd` y `GameManager.gd` contra cada afirmación del memo. Resultado: **el
diagnóstico es preciso, no es una simplificación vendida como urgencia.**

| Afirmación del memo | Verificado en código |
|---|---|
| Cada proyectil es un `Area2D` real con señal `body_entered` | `projectile.gd:1,14,36` — confirmado literal |
| Node + script por entidad, `_physics_process()` corre cada tick aunque esté pooled | `projectile.gd:28`, `enemy.gd:54` — confirmado |
| Búsqueda de objetivo O(n) sobre el pool completo | `weapon_base.gd:47` (`_get_nearest_enemy`) y `weapon_orbe.gd:60` (`_has_enemy_in_cone`) recorren `_pool` entero — confirmado |
| Sync de render instancia por instancia, no buffer completo | `projectile_renderer.gd:56-60`, `enemy_renderer.gd:87-97` — un `set_instance_transform_2d`/`set_instance_color` por entidad activa, cada frame — confirmado |
| Buffers fijos (400 proyectiles / 1000 enemigos) | `projectile_renderer.gd:3` (`MAX_PROJ := 400`), `enemy_renderer.gd:3` (`MAX_ENEMIES := 1000`) — confirmado |
| `create_tween()` por muerte, `get_first_node_in_group` por impacto | `enemy.gd:77,98` — confirmado |
| El propio POC declara su objetivo como 400-1000 entidades, no más | `POC/README.md:3-4` lo dice explícitamente | 

No encontré ninguna afirmación técnica del memo o de la propuesta del director que
no se sostenga al leer el código. Esto importa para la auditoría de proceso: **la
apuesta arquitectónica de la sección 03 no parte de un diagnóstico débil.**

---

## 02. Fortalezas del proceso — para no tirar lo que funciona

Como auditor, vale nombrar esto con la misma seriedad que los huecos: si alguien lee
solo la sección 03 y decide "esto está mal planeado", se equivoca.

- **Disciplina de "no fecha sin datos".** Los tres documentos de producto (memo,
  plan de acción, sprint plan) repiten la misma regla — no comprometer roadmap
  antes del spike — y el sprint plan la hace cumplir con un corte duro de 10 días
  hábiles. Es raro ver esa disciplina sostenida a través de cuatro documentos
  distintos sin que se diluya.
- **Cadena de trazabilidad real.** Cada decisión del plan de acción cita la pregunta
  exacta del memo o el punto exacto de la propuesta del director que la origina
  (memo Q1, director #3, etc.). Esto hace auditable el plan — pude verificar cada
  afirmación porque el documento decía dónde nació.
- **Separación de autoridad correcta.** El PM no rediscute la arquitectura técnica
  (reconoce explícitamente "no tengo la competencia técnica para pesarla") pero sí
  fuerza que las decisiones de producto (número objetivo, hardware, combate,
  multijugador) se tomen con dueño y fecha en vez de quedar implícitas. Es la
  división de responsabilidad correcta entre Dirección de Desarrollo y PM.
- **"Fuera de alcance" explícito.** Tanto el director como el PM nombran
  threading, multijugador y motor propio como fuera de esta etapa *a propósito*,
  no por omisión. Evita la forma más común de scope creep en spikes técnicos.
- **DoD verificable, no aspiracional.** Sprint 1 no se da por cumplido con "la
  sesión fue productiva" — exige una cifra dura sin ambigüedad como criterio de
  aceptación de T2, y el propio documento se niega de antemano a aceptar "más o
  menos miles" como resultado válido.

---

## 03. Problemas de cimientos — estado al cierre del 06-ago

Los cuatro puntos de esta sección quedaron resueltos hoy. Registro qué se
encontró, por qué importaba, y cómo quedó cerrado — para que quede el rastro de
la decisión, no solo el resultado.

### 3.1 — [RESUELTO] El rol de Diseño de combate no estaba confirmado
El documento se auto-señalaba el riesgo ("es un bloqueante de día 1") pero ningún
documento confirmaba que existiera una persona asignada, y T3/T5 —2 de las 9
entregas del DoD— dependían exclusivamente de ese rol. **Resolución:** es un
proyecto de desarrollador único; el rol lo cubre la misma persona que el resto.
Nota abierta a futuro (no bloqueante): si más adelante se suma un diseñador de
combate dedicado, vale una segunda revisión de la cifra de escala y del documento
de combate antes de congelar `entity_store.gd`, ya que hoy la misma persona valida
y aprueba sin una segunda voz que la contraste.

### 3.2 — [RESUELTO] "Dirección de producto" era dueño de una decisión pero no
estaba invitado
La postura sobre multijugador tenía como dueño declarado "PM + Dirección de
producto" en dos documentos distintos, sin que esa persona apareciera nunca en la
lista de convocados. **Resolución:** es la misma persona que el PM — no hay
tercera voz que faltara invitar. Corregido en `sprint-01.md`.

### 3.3 — [RESUELTO] No había control de versiones inicializado
Verificado: no había `.git` ni `.gitignore`. **Resolución:** `git init` +
`.gitignore` (excluye `.godot/`, y deja previsto espacio para artefactos de build
de GDExtension) + commit inicial de 98 archivos. Hallazgo adicional durante la
verificación: `POC/assets/` tenía un instalador de 84MB (`EpicInstaller-20.1.4.msi`)
mezclado con los assets reales del juego — se eliminó antes de commitear, no
pertenecía al proyecto.

### 3.4 — [RESUELTO] La fecha de inicio del sprint seguía en "a confirmar"
**Resolución:** fecha de inicio fijada en viernes 07-ago-2026, con el resto del
cronograma de Sprint 1 (Días 2–5) derivado de esa fecha en `sprint-01.md` y
`sprint-01-asignaciones.md`.

### 3.5 — [Nuevo, no bloqueante] Contexto de equipo real
Al resolver 3.1 y 3.2 surgió un dato que cambia la lectura del resto del plan:
es un desarrollador único, no un estudio con roles separados. Esto no invalida
nada de lo evaluado en la sección 02 (la disciplina de proceso sigue siendo
correcta y vale la pena mantenerla aunque sea una sola persona autoimponiéndosela)
pero sí cambia el riesgo de "GDExtension sin experiencia previa" señalado en
`directorsuggestions.md`: se cubre con apoyo de Claude Code para la
implementación, lo cual mitiga la curva de aprendizaje pero no la elimina — sigue
valiendo medir en el spike cuánto tiempo se va en el flujo de trabajo con la
herramienta versus en la arquitectura misma.

---

## 04. Riesgos a vigilar durante el sprint — no bloquean mañana

- **Competencia en GDExtension/C++/Rust — mitigada, no eliminada.** Confirmado:
  sin experiencia previa, cubierta con apoyo de Claude Code para la
  implementación. Reduce el riesgo de que la ruta B del spike mida solo una curva
  de aprendizaje, pero conviene medir explícitamente en el spike cuánto tiempo se
  va en el flujo de trabajo (build, hot-reload, superficie de la API) versus en la
  arquitectura misma, para no confundir ambas cosas en el resultado.
- **Riesgo de anclaje en la cifra 20.000/30.000 — vigente.** Esa cifra nació como
  hipótesis de ingeniería del director dentro de su propia propuesta de
  arquitectura, no como un número de diseño de combate. Con un desarrollador único
  cubriendo también el rol de Diseño de combate (3.1), este riesgo se acentúa un
  poco: no hay una segunda voz que la objete en la sesión T1. Vale la pena
  contrastarla explícitamente contra lo que el gameplay real necesita al cerrar
  T2, no solo ratificarla porque ya está escrita en un documento previo.
- **Disponibilidad — ya no aplica.** Resuelto en 3.5: es un desarrollador único,
  no hace falta liberar a nadie de otro proyecto.
- **Sin herramienta de medición definida para el spike.** El plan pide "datos, no
  intuición" para el criterio de salida del spike, pero no define todavía cómo se
  va a medir fps/frame time de forma reproducible (profiler de Godot, logging
  propio). No bloquea Sprint 1, pero conviene resolverlo antes del día 1 de
  Sprint 2 para no perder tiempo de spike en tooling.

---

## 05. Checklist accionable — estado al cierre del 06-ago

- [x] Confirmar dueño de Diseño de combate (3.1) — desarrollador único
- [x] Aclarar rol "Dirección de producto" (3.2) — mismo desarrollador único
- [x] `git init` + `.gitignore` + commit inicial del POC actual (3.3)
- [x] Fijar y comunicar la fecha de inicio del sprint (3.4) — vie 07-ago-2026
- [ ] Bloquear en el calendario el horario de la sesión T1 (mañana, tarde)

Con los cuatro puntos de cimientos cerrados, no encuentro razón para no arrancar
Sprint 1 mañana tal como está diseñado en `sprint-plan.md` y `sprint-01.md`. Lo
único operativo que queda para hoy es agendar el bloque de la sesión T1 en el
calendario — el resto de T2–T9 se ejecuta durante la semana según
`sprint-01-asignaciones.md`.
