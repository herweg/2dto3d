# Plan de acción — de POC a núcleo escalable

**Rol:** Product Manager
**Fecha:** 06 agosto 2026
**Insumo:** `docs/poc-scale-memo.md` (Dirección de Desarrollo, diagnóstico neutral) +
`docs/directorsuggestions.md` (Dirección de Desarrollo, propuesta técnica concreta)
**Estado:** propuesta de trabajo, no compromiso de roadmap. Sujeto a revisión del equipo.

---

## 00. Postura de partida

Acepto el diagnóstico del memo: el POC es una especificación validada de patrones,
no un cimiento de producción. Con `directorsuggestions.md` el director dejó de listar
preguntas neutrales y puso una apuesta concreta sobre la mesa: diseño orientado a
datos (SoA), hash espacial propio, un `multimesh_set_buffer()` por frame, y GDScript
primero, escalando a GDExtension solo si el spike lo exige. Eso cambia mi rol en este
documento: ya no tengo que dejar la arquitectura "abierta a tres opciones" — tengo que
validar la apuesta del director con datos y resolver, con dueño y fecha, la lista de 7
pedidos que él mismo puso en su sección 3 (que se superpone con, pero no es idéntica
a, las 7 preguntas del memo original).

No voy a pedir "sumá MAX_PROJ" ni voy a fijar fecha de lanzamiento todavía. Lo que sí
hago ya es lo que ambos documentos piden del lado de producto: **convertir las
preguntas/pedidos abiertos en decisiones tomadas, con dueño y fecha**, y secuenciar el
trabajo técnico alrededor de esas decisiones en vez de alrededor de una fecha
arbitraria.

Estructura de este documento:

1. Cómo voy a cerrar las preguntas abiertas (quién decide, cuándo, cómo) — reconciliando
   memo + propuesta del director
2. Cómo estructuro el spike técnico (alcance, criterios de salida, equipo) — ahora con
   la arquitectura concreta de `directorsuggestions.md` como lo que se está midiendo
3. La apuesta de arquitectura del director — qué acepto tal cual, qué sigo tratando
   como abierto
4. Secuencia de fases y checkpoints de decisión
5. Riesgos que quiero vigilar activamente
6. Qué voy a pedir al equipo esta semana

---

## 01. Cerrar las preguntas de producto (memo, sección 3)

Ninguna de estas la puede responder el equipo técnico solo. Mi trabajo es forzar la
decisión, no tomarla en el vacío. Propongo una sesión de definición de alcance
(1 sesión de 2h, PM + Dirección de Desarrollo + Diseño de combate + alguien de
negocio/marketing si hay restricción de hardware comercial) antes de que arranque el
spike, porque las respuestas a 1, 4 y 6 cambian qué mide el spike.

> **#Auditor:** la lista de invitados a esta sesión no incluye a "Dirección de
> producto", pero la tabla de abajo (fila 6) lo nombra como co-dueño de la postura
> sobre multijugador. Esta inconsistencia se propaga tal cual a `sprint-01.md`
> (tabla de participantes vs. dueño de T6). Si es un rol real y distinto del PM,
> falta invitarlo aquí; si es el mismo PM, conviene decirlo explícitamente para
> que nadie asuma que hay una tercera persona con voz en la decisión de red.

| # | Pregunta / pedido | Cómo la resuelvo | Dueño |
|---|---|---|---|
| 1 | ¿Simultáneos o acumulados? Número concreto (memo Q1, director #1) | Fijar cifra dura *y* pico: propongo validar contra **"20.000 proyectiles vivos simultáneos, pico de 30.000 en oleadas de clímax"** — tomo la cifra exacta que ya propone el director en su documento como punto de partida de la negociación con Diseño de combate, no la invento de cero. Si Diseño de combate la cree exagerada para el gameplay real, se ajusta ahí, no en ingeniería. | PM + Diseño de combate |
> **#Auditor:** vale la pena que quien facilite la sesión T1 lo diga en voz alta:
> 20.000/30.000 no es una cifra de producto, es una hipótesis de ingeniería que el
> propio director generó como consecuencia de diseñar su arquitectura, no al revés.
> Tratarla como "punto de partida de negociación" es razonable, pero solo funciona
> si Diseño de combate —posiblemente una persona recién asignada a este proyecto,
> ver nota en `sprint-01.md`— realmente tiene espacio y contexto para objetarla en
> la sesión, y no la ratifica por default al no tener con qué contrastarla.
| 2 | Techo real en GDScript puro | La responde el spike (sección 2). El director ya adelanta una hipótesis de trabajo (~15.000 proyectiles simples a 60 fps en GDScript puro) — la trato como hipótesis a confirmar, no como resultado. | Dirección de Desarrollo |
| 3 | ¿GDScript alcanza o hace falta GDExtension? | La responde el spike, en paralelo sobre el mismo caso de prueba. El director ya propone dónde espera que se parta la respuesta (colisión + daño a GDExtension si hace falta, todo lo demás en GDScript) — el spike confirma o corrige ese corte, no lo redefine desde cero. | Dirección de Desarrollo |
| 4 | Hardware mínimo objetivo | Decisión de producto/negocio. Propongo alinear con la spec mínima ya usada para otros títulos del estudio si existe; si no, definirla ahora — no dejarla implícita. | PM + Negocio |
| 5 | Diseño de combate: críticos, resistencias, perforación, DoT, cadenas (memo Q5, director #3) | Diseño de combate entrega un **documento de diseño de combate cerrado para v1**, no solo una lista de modificadores — el director es explícito en que esto congela el formato de la fila de datos por proyectil (`entity_store.gd`) y que cada campo agregado después de empezar a construir tiene costo de migración. Esto lo eleva de "nice to have antes del spike" a bloqueante duro antes de que arranque la Fase 2. | Diseño de combate |
| 6 | ¿Multijugador en roadmap? (memo Q6, director #4) | Debe salir de la sesión de definición de alcance con un sí/no explícito, aunque el "sí" sea a futuro — el director es explícito en que si la respuesta es "sí" en cualquier horizonte visible, quiere saberlo *antes* de escribir `entity_store.gd`, no después (paso fijo determinístico / autoridad de servidor cambian el diseño de raíz). | PM + Dirección de producto |
| 7 | ¿Godot sigue siendo el motor correcto? | No se decide ahora. Se re-evalúa **con datos del spike**, no antes. Si el spike muestra que ni GDExtension llega al número fijado en la pregunta 1, se abre como decisión formal de continuidad de motor. | Dirección de Desarrollo + PM |
| 8 | *(nuevo, director #7)* Variedad real de tipos de proyectil: ¿cientos de tipos con muchas instancias cada uno, o comportamiento único a escala de decenas de miles? | No es lo mismo variedad visual (reskin, resuelto con atlas + custom data del MultiMesh, ya cubierto por la propuesta técnica) que variedad de comportamiento (cada tipo es trabajo de diseño y contenido, no solo de motor). Necesito que Diseño de combate/contenido fije esto en la misma sesión de alcance, junto con la pregunta 5 — determina el costo de autoría, no solo el técnico. | PM + Diseño de combate |

**Salida esperada de la sesión de definición de alcance:** un documento corto
("Definición de escala v1") con: número objetivo de proyectiles/enemigos simultáneos
(incluyendo pico), spec de hardware mínima, documento de diseño de combate cerrado
para v1, definición de variedad real de tipos de proyectil (visual vs. comportamiento),
y postura sobre multijugador. Este documento es el input formal del spike y del
congelamiento del formato de fila de `entity_store.gd` — sin él, ni el spike arranca
con el objetivo correcto ni el equipo técnico puede fijar el esquema de datos sin
tener que rehacerlo después.

---

## 02. Spike técnico (memo, recomendación #4; director, pedido #5)

Acepto el marco de 1–2 semanas que propone Dirección de Desarrollo, y el pedido
explícito del director de no dejarlo entrar a ningún roadmap público sin esa
aprobación formal (director, sección 3, punto 5). Mi rol como PM es definir qué
cuenta como "terminado" para no dejarlo abierto indefinidamente, asegurar que mida
las dos rutas en paralelo (pregunta 3), y — esto es nuevo respecto de mi primera
versión de este plan — tratar el spike como la validación de una propuesta concreta
(`directorsuggestions.md`), no como una exploración desde cero.

**Alcance del spike (propuesto, a confirmar con Dirección de Desarrollo):**

- Implementar la propuesta del director tal como está descrita en su documento:
  `entity_store.gd` (SoA + free-list con swap-remove), `spatial_hash.gd` (grilla
  uniforme sobre posiciones de enemigos), un batch único de movimiento + colisión +
  daño por tick, y `multimesh_set_buffer()` una vez por frame — sin lógica de juego
  real, sobre un caso de prueba sintético.
- Medir en el número objetivo fijado en la sesión de alcance, incluyendo el pico
  (no "hasta que caiga de 60 fps" sin más — probar directamente contra la cifra que
  importa, memo Q1 / director #1).
- Dos variantes del mismo caso de prueba: GDScript puro con hash espacial propio, y
  el mismo hot path (colisión + aplicación de daño) movido a GDExtension (C++ o Rust
  vía `godot-rust`). El director ya propone este corte específico — el spike lo
  confirma o lo corrige, no arranca de opciones genéricas sin explorar.
- Correr sobre el hardware mínimo definido en la sesión de alcance, no solo en
  máquinas de desarrollo.

**Criterios de salida (para que el spike no se alargue sin fin):**

- Responde con datos, no intuición: ¿cuántas entidades sostiene la propuesta del
  director a 60 fps en el hardware mínimo, en GDScript puro y con el hot path en
  GDExtension?
- Confirma o corrige la hipótesis de trabajo del director (~15.000 proyectiles
  simples en GDScript puro antes de necesitar GDExtension) — la trato como punto de
  partida a falsear, no como resultado adquirido.
- Si el resultado en GDScript puro ya alcanza el número objetivo de la sesión de
  alcance, no se construye GDExtension "por las dudas" — el propio director lo marca
  como apuesta más cara que hay que ganarse con datos, no asumir de entrada.
- Si a los 10 días hábiles no hay señal clara, corto el spike igual y decido con lo
  que haya — no dejo que un spike se vuelva el proyecto.

**Equipo:** 1–2 desarrolladores senior de Dirección de Desarrollo, dedicación
exclusiva. No es tarea de fondo entre otras — ambos documentos técnicos son explícitos
en que esto bloquea el roadmap, así que lo trato como bloqueante también en asignación
de gente.

---

## 03. La apuesta de arquitectura del director — qué acepto, qué sigo tratando como abierto

En mi primera versión de este plan dejé la arquitectura del núcleo como "opciones sin
elegir, a decidir en el spike". Con `directorsuggestions.md` eso ya no es correcto: el
director puso una propuesta concreta y completa (sección 2 de su documento), con
nombres de archivo y todo. Mi trabajo ahora no es generar opciones alternativas por
mi cuenta — no tengo la competencia técnica para pesarlas contra la del director — es
identificar qué parte de esa propuesta es una decisión de diseño que el spike valida,
y qué parte sigue dependiendo de que yo cierre algo primero.

**Acepto tal cual, como lo que se está validando en el spike (no rediscuto alternativas):**

- Entidades como filas en arrays paralelos (SoA), free-list + swap-remove, en vez de
  Node + script por entidad.
- Hash espacial propio (grilla uniforme) reconstruido por tick sobre posiciones de
  enemigos, en vez de Area2D/`body_entered`.
- Un solo `multimesh_set_buffer()` por grupo visual y por frame, con atlas + custom
  data para variedad visual, en vez de llamadas por instancia.
- Batch único de colisión + daño con cola de efectos secundarios (agregación de
  números de daño, temporizador de muerte en el array), en vez de señales y
  `Tween` por evento.
- GDScript primero; GDExtension solo si el spike lo exige, acotado al hot path de
  colisión + daño, no una reescritura completa.
- La capa de producto (armas, XP, oleadas, HUD, tabla de stats por tipo) se porta
  cambiando de API (`ProjectileSystem.spawn(type_id, pos, dir)`), no de diseño.

Ya no anoto "Opción A / B / C" para colisión o simulación de entidades como hacía
antes — el director ya resolvió esa evaluación con su criterio técnico, y mi rol de
PM es asegurar que el spike la mida, no repetirla con menos información que él.

**Lo que sigo tratando como abierto, porque depende de decisiones de producto que el
director no puede tomar solo:**

- El corte GDScript/GDExtension es una *hipótesis* del director (~15.000 en GDScript
  puro), no un hecho — la sección 02 de este plan la trata como tal.
- El formato exacto de la fila de datos por proyectil no se congela hasta tener el
  documento de diseño de combate (pregunta 5 / pedido director #3) y la definición de
  variedad real de tipos (pedido director #7, ver tabla de sección 01).
- La decisión de motor (memo Q7) sigue siendo condicional al resultado del spike, no
  a la propuesta — si ni GDExtension alcanza el número objetivo, se reabre.

### Fuera de alcance, a propósito (director, sección 4)

El director es explícito en que esta propuesta **no** incluye threading, multijugador,
ni motor propio — y que agregarlos sin medir sería el mismo error que está tratando de
evitar. Adopto esa misma disciplina en este plan: no voy a pedir que el equipo evalúe
paralelismo (`WorkerThreadPool`) ni arquitectura de red *dentro* del spike. El
paralelismo queda anotado como optimización posterior si el spike de un solo hilo se
queda corto; la arquitectura de red depende pura y exclusivamente de la pregunta 6
(multijugador sí/no) que tengo que cerrar en la sesión de alcance.

---

## 04. Secuencia de fases

```
Fase 0 — Definición de alcance          [1 sesión, ~2h]
  → cierra preguntas 1, 4, 5, 6 del memo
  → produce "Definición de escala v1"
         │
         ▼
Fase 1 — Spike técnico                  [1–2 semanas]
  → valida la propuesta de directorsuggestions.md (sección 03)
  → responde preguntas 2, 3 del memo con esa propuesta como base
         │
         ▼
Checkpoint de decisión (PM + Dirección de Desarrollo)
  → ¿el spike alcanza el número objetivo? ¿en qué ruta (GDScript vs GDExtension)?
  → ¿se reabre la pregunta 7 (motor)?
  → recién acá se fija alcance y fecha del rediseño de núcleo, y recién acá se
    autoriza construir el módulo GDExtension si el spike lo justifica
         │
         ▼
Fase 2 — Rediseño del núcleo de simulación
  → según lo validado en el spike, siguiendo la arquitectura de directorsuggestions.md
  → el formato de fila de entity_store.gd se congela recién con el documento de diseño
    de combate y la definición de variedad de tipos cerrados (Fase 0, pedidos 5 y 8)
  → en paralelo: portar la capa de producto (armas, XP, oleadas, HUD) — memo sección 01,
    es trabajo independiente del núcleo y no bloquea ni bloquea al spike
         │
         ▼
Fase 3 — Integración núcleo + capa de producto, medición contra el objetivo real de escala
```

**Por qué esta secuencia:** el memo advierte explícitamente contra fijar fecha o
alcance antes del spike, y el director pide lo mismo respecto de comprometer una
fecha de roadmap sin su aprobación explícita del spike. Respeto ambos — el checkpoint
de decisión es el único punto donde se compromete roadmap. Todo lo anterior es
exploración con criterios de salida claros, no compromiso.

---

## 05. Riesgos que voy a vigilar

- **Que el spike se convierta en el proyecto.** Mitigo con criterios de salida duros
  (sección 2) y un corte a los 10 días hábiles pase lo que pase.
- **Que la Fase 0 no cierre con números concretos.** Si la sesión de alcance termina
  en "más o menos miles", no la doy por cerrada — insisto en cifras duras, tal como
  pide el memo en la pregunta 1 y precisa el director en su punto 1. Sin esto el
  spike mide lo que no corresponde.
- **Que el diseño de combate (pregunta 5 / pedido director #3) siga abierto mientras
  el spike ya corrió, o peor, mientras ya se empezó a escribir `entity_store.gd`.**
  El director es explícito en que cada campo agregado a la fila después de empezar a
  construir tiene costo de migración. Por eso Fase 0 tiene que cerrar antes de Fase 2,
  no solo antes de Fase 1 — el spike puede tolerar un esquema provisorio, la
  construcción real no.
- **Construir GDExtension "por las dudas" sin que el spike lo haya justificado.** El
  propio director lo marca como apuesta cara que hay que ganarse con datos. Si en el
  checkpoint el resultado en GDScript puro ya alcanza el número objetivo, no autorizo
  la inversión en GDExtension aunque "suene más sólido a futuro" — sería exactamente
  el tipo de complejidad no medida que ambos documentos técnicos piden evitar.
- **Optimismo de motor.** Si en el checkpoint de decisión el resultado es ambiguo,
  mi default es *no* asumir que "Godot alcanza igual" — sigo la postura del memo de
  confirmarlo con datos antes de comprometer fecha.
- **Confundir variedad visual con variedad de comportamiento (pedido director #7).**
  Si Diseño de combate pide "decenas de miles de proyectiles distintos" sin aclarar
  si es reskin o comportamiento único, el costo de contenido puede dispararse sin que
  nadie lo haya presupuestado. Lo cierro explícitamente en la Fase 0.

---

## 06. Qué pido al equipo esta semana

1. Agendar la sesión de definición de alcance (Fase 0) — convoco yo, esta semana.
2. Dirección de Desarrollo: confirmar disponibilidad de 1–2 devs senior para el spike,
   dedicación exclusiva, apenas cierre Fase 0. Doy por aprobado el marco de 1–2
   semanas que pide el director en su punto 5 — queda formalizado en este documento.
3. Diseño de combate: empezar a preparar el **documento de diseño de combate cerrado
   para v1** (críticos, resistencias, perforación, DoT, cadenas — pregunta 5 / pedido
   director #3), y en la misma instancia, definir la **variedad real de tipos de
   proyectil** (visual vs. comportamiento — pedido director #7). Ambos en paralelo a
   la sesión de alcance, para no bloquear en serie algo que se puede adelantar.
4. Yo, como PM: buscar si existe ya una spec de hardware mínimo de otros títulos del
   estudio, para no definirla desde cero (pregunta 4); y llevar a la sesión de alcance
   la cifra propuesta por el director (20.000 simultáneos, pico de 30.000) como punto
   de partida de la negociación con Diseño de combate, no como número ya cerrado.

---

*Este documento es un plan de trabajo, no una decisión final de fecha. La arquitectura
del núcleo (sección 3) sigue la propuesta de `directorsuggestions.md`, sujeta a lo que
confirme o corrija el spike — no es una decisión de producto abierta a discusión, es
una apuesta técnica en validación.*
