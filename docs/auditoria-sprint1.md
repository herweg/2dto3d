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

**El plan es de una calidad de proceso inusualmente alta — pero tiene tres huecos de
cimientos sin resolver que el propio texto ya intuye y no cierra.** No son fallas de
razonamiento técnico ni de secuenciación: son precondiciones que los documentos dan
por sentadas ("Diseño de combate", "Dirección de producto", "el spike escribe código
sobre esto") sin confirmar que existan hoy.

**Recomendación: arrancar Sprint 1 mañana como está planeado, pero cerrar hoy los
cuatro puntos de la sección 03.** Ninguno requiere replanificar — todos son de
"confirmar/hacer antes de las 9am", no de "rediseñar el plan". Dejé nota `#Auditor`
en el punto exacto de cada documento donde aparece cada hueco; este archivo es el
resumen ejecutable.

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

## 03. Problemas de cimientos — resolver hoy, antes de Sprint 1

Estos cuatro puntos ya tienen nota `#Auditor` en el documento donde aparecen. Los
resumo acá con la razón por la que los considero bloqueantes de cimientos y no
"riesgos a vigilar" — la diferencia es que **el propio DoD de Sprint 1 es
matemáticamente imposible de cumplir si alguno sigue sin resolverse mañana.**

### 3.1 — El rol de Diseño de combate no está confirmado
`sprint-01.md` — tabla de participantes

El documento se auto-señala el riesgo ("es un bloqueante de día 1") pero ninguno de
los cinco documentos confirma que exista una persona asignada. T3 (documento de
combate) y T5 (variedad de tipos) — 2 de las 9 entregas del DoD — dependen
exclusivamente de este rol, y T3 es la que congela el esquema de datos de
`entity_store.gd` en Fase 2. Sin nombre confirmado hoy, Sprint 1 no puede cerrar su
propio DoD tal como está escrito, sin importar qué tan bien salga todo lo demás.

**Acción para hoy:** confirmar el nombre por escrito antes de convocar la sesión T1
de mañana. Si no existe todavía, es una conversación de hoy con Dirección de
Desarrollo/Producto, no algo que se resuelve "durante" el sprint.

### 3.2 — "Dirección de producto" es dueño de una decisión pero no está invitado
`poc-scale-action-plan.md` (tabla sección 01, fila 6) y `sprint-01.md` (tabla de
participantes vs. dueño de T6)

La postura sobre multijugador tiene como dueño declarado "PM + Dirección de
producto" en ambos documentos, pero ninguno de los dos incluye a esa persona en la
lista de convocados a la sesión de 2 horas donde se toma esa decisión. O es un rol
real que falta invitar, o es el mismo PM con otro sombrero y el documento debería
decirlo así para no sugerir que hay una tercera voz que en los hechos no participa.

**Acción para hoy:** aclarar si "Dirección de producto" es una persona distinta;
si lo es, agregarla a la convocatoria de T1 antes de enviarla.

### 3.3 — No hay control de versiones inicializado
Verificado directamente: `/towerdefense` no tiene `.git` ni `.gitignore`.

`sprint-01.md` trata la creación de la estructura de carpetas (`sim/`, `render/`,
`data/`) como un ítem opcional (T8, "si hay tiempo ocioso"). Pero el problema no es
la estructura de carpetas — es que **no hay git**. Desde el día 1 de Sprint 2, 1-2
devs senior van a escribir código en paralelo (potencialmente sobre dos rutas,
GDScript y GDExtension) sin ningún mecanismo de historial, branching ni respaldo.
Es la forma más barata de perder trabajo real en este plan, y arreglarla hoy cuesta
minutos.

**Acción para hoy:** `git init`, `.gitignore` (excluir `.godot/imported` y
`.godot/shader_cache`, que son artefactos generados), commit inicial del estado
actual del POC. Esto no debería depender de "tiempo ocioso" — es infraestructura
mínima, no una mejora opcional.

### 3.4 — La fecha de inicio del sprint sigue en "a confirmar"
`sprint-01.md`, encabezado

Dado que el sprint arranca mañana, este campo debería decir la fecha concreta, no
"a confirmar al aceptar este documento". Es menor comparado con 3.1–3.3, pero es la
puerta de entrada del documento — si no está cerrado, tampoco está claro que el
resto del documento esté formalmente aceptado todavía.

**Acción para hoy:** fijar la fecha de inicio (mañana) explícitamente en el
documento y comunicarla junto con la convocatoria de T1.

---

## 04. Riesgos a vigilar durante el sprint — no bloquean mañana

Estos no impiden arrancar Sprint 1, pero conviene que alguien los tenga anotados
para no descubrirlos recién en Sprint 2 o 3, cuando ya cuestan más resolver.

- **Competencia en GDExtension/C++/Rust no confirmada.** Ningún documento verifica
  que el equipo asignado al spike tenga experiencia previa con `godot-rust` o
  bindings de GDExtension. Si no la tienen, la ruta B del spike mide una curva de
  aprendizaje además de la arquitectura, dentro del mismo corte de 10 días hábiles
  — puede sesgar el resultado sin que nadie lo note como tal. Ver nota en
  `directorsuggestions.md`, sección 2.5.
- **Riesgo de anclaje en la cifra 20.000/30.000.** Esa cifra nació como hipótesis
  de ingeniería del director dentro de su propia propuesta de arquitectura, no como
  un número de diseño de combate. Tratarla como "punto de partida de negociación"
  es razonable, pero solo si Diseño de combate —posiblemente alguien recién
  asignado, ver 3.1— tiene contexto real para objetarla en la sesión T1 y no la
  ratifica por default. Vale la pena que quien facilite la sesión lo diga en voz
  alta antes de presentarla.
- **Disponibilidad real de los 1-2 devs senior para Sprint 2.** T7 confirma nombres
  durante Sprint 1, lo cual está bien como tarea — pero ningún documento verifica
  que esas personas no estén comprometidas en otro trabajo que habría que liberar
  primero. Si hace falta destrabar a alguien de otro proyecto, mejor saberlo el
  día 3 de Sprint 1 que el día 1 de Sprint 2.
- **Sin herramienta de medición definida para el spike.** El plan pide "datos, no
  intuición" para el criterio de salida del spike, pero no define todavía cómo se
  va a medir fps/frame time de forma reproducible (profiler de Godot, logging
  propio, hardware de referencia física vs. emulada). No bloquea Sprint 1, pero
  conviene resolverlo antes del día 1 de Sprint 2 para no perder tiempo de spike en
  tooling.

---

## 05. Checklist accionable para hoy

- [ ] Confirmar por escrito el nombre de la persona de Diseño de combate (3.1)
- [ ] Aclarar si "Dirección de producto" es un rol separado; si lo es, sumarlo a la
      convocatoria de T1 (3.2)
- [ ] `git init` + `.gitignore` + commit inicial del POC actual (3.3)
- [ ] Fijar y comunicar la fecha de inicio del sprint en `sprint-01.md` (3.4)
- [ ] Enviar la convocatoria de la sesión T1 con hora concreta, ya con la lista de
      invitados corregida

Con estos cinco puntos cerrados, no encuentro razón para no arrancar Sprint 1 mañana
tal como está diseñado en `sprint-plan.md` y `sprint-01.md`.
