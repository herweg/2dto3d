# Fase 3 — árbol de talentos, frame

**Rol:** Mesa de Developers (Motor).
**Fecha:** 10-ago-2026.
**Origen:** pedido directo del usuario — "hace la pantalla de talentos
(arbol estilo poe)... Solo genera el frame, en la proxima interaccion lo
configuraremos correctamente en base a notas." Corresponde al sub-alcance
que `fase3-alcance-v1.md` sección 3 ya había separado como su propio ítem
grande dentro de Fase 3, sin descomponer en tarjeta de motor hasta ahora.

---

## 1. Qué es "el frame" acá

Mecanismo de árbol de talentos funcionando de punta a punta — datos,
render, desbloqueo, gating por prerequisito y por costo — **desacoplado
de cuántos nodos existan o qué hagan**. Lo que esta tarjeta
deliberadamente NO hace, con la misma disciplina de "no calibrar sin que
lo pidan" que ya usó este proyecto en niveles/máquina de estados:

- **No conecta ningún efecto a combate.** Cada nodo declara
  `effect_scope`/`stat_id`/`modifier_value` (ver sección 2) pero nada en
  `TowerStore`/`TowerSystem` los lee todavía. Aplicar esto es la próxima
  interacción.
- **No tiene economía real.** `_points_available` es un placeholder fijo
  (10) — cuántos puntos da el juego y cuándo sigue siendo "otro contador a
  calibrar" sin resolver (`fase3-alcance-v1.md` sección 2).
- **No persiste.** El desbloqueo vive en memoria, muere con el proceso —
  guardado sigue pausado (`plan-fases.md`).

## 2. Modelo de datos — `TalentTreeDef`

`game/data/talent_tree_def.gd`: arreglos paralelos (mismo criterio SoA que
`EnemyStore`/`TowerStore`/`ProjectileStore`, evita sub-recursos anidados en
el `.tres`, frágiles de escribir a mano sin el editor). Un índice = un
nodo: `ids`, `display_names`, `positions`, `parent_ids` (`""` = raíz —
árbol simple, un padre por nodo, no grafo general), `costs`,
`effect_scopes` (`GLOBAL`/`TOWER_TYPE`), `target_tower_types` (índice de
`TowerStore.TOWER_TYPE_STATS`, `-1` si `GLOBAL`), `stat_ids`,
`modifier_values`.

**La distinción global/por-torreta que pidió el usuario está en el dato,
no hardcodeada en la pantalla** — `effect_scopes[i]`/`target_tower_types[i]`
son campos genéricos, la pantalla no sabe ni le importa cuántos tipos de
torre existen.

## 3. Contenido actual — `talents_01.tres`

31 nodos en 3 ramas desde una raíz común (`root`): ofensiva (`off_*`,
daño/crítico/perforación), control (`ctrl_*`, DoT/splash/debuffs) y
economía (`eco_*`, puntos por muerte/slots de torre/cadencia), cada rama
con tronco de 3 nodos + 2 sub-ramas + capstone. Dos nodos ya usan
`TOWER_TYPE` en vez de `GLOBAL` (perforante y lanzallamas, los mismos
ejemplos que dio el usuario). Esto ya no es contenido placeholder de
prueba — es el árbol real, y el mecanismo de esta tarjeta lo sostiene sin
cambios de código, que era el objetivo del frame.

## 4. Mecánica implementada

- **Estados visuales por nodo:** bloqueado (gris, prerequisito no cumplido
  o sin puntos), disponible (amarillo, clickeable), desbloqueado (verde,
  deshabilitado). Prefijo `[G]`/`[T<n>]` en el texto del botón — visible
  sin pasar el mouse; detalle completo (stat + valor) en `tooltip_text`.
- **Líneas de prerequisito** (`_draw()` en el nodo raíz de la escena, sin
  `Camera2D` en esta pantalla — mismas coordenadas que los `Button` del
  `CanvasLayer`, no hace falta transformar nada): grises si el link no
  está desbloqueado de los dos lados, verdes si sí.
- **`_try_unlock(id)`** — único punto de entrada, botón real y flag CLI
  `unlock=<id>` pasan por acá. Rechaza: ya desbloqueado, id inexistente,
  prerequisito no cumplido, puntos insuficientes.
- **Botón "Volver"** → `MainMenu.tscn`, agregado ahí un botón "Talentos"
  entre "Start" y "Exit".

## 5. Bugs encontrados y corregidos en el camino

**5.1 `class_name TalentTreeDef` no se resolvía en corridas headless
directas — no era un cuelgue de verdad.** Primera corrida headless tiraba
`Parse Error: Could not find type "TalentTreeDef"` y el proceso no
llegaba nunca a salir (mismo síntoma superficial que el cuelgue diagnosticado
en `fase3-motor-log.md` sección 4, causa distinta esta vez). Un
`class_name` nuevo necesita que Godot re-escanee el proyecto para
registrarlo globalmente — no pasa solo — mismo fix que ya documentaba
`rust-build.md` para extensiones nuevas: una corrida con
`--editor --quit-after 60` una sola vez. Después de eso, todas las
corridas headless normales cargan `TalentTreeDef` sin problema.

**5.2 Los nodos se pisaban entre sí con la data real (31 nodos).** El
ancho de botón que probé primero (150px) asumía separación holgada — la
data real usa 120px entre hermanos de la misma rama. Visto en una captura
real (no en teoría): tres columnas de una misma fila superpuestas,
imposibles de leer. Corregido: `NODE_SIZE` a 104×34, texto del botón
recortado (`clip_text`) con prefijo corto de alcance en vez de la
descripción completa (que no entraba a esta densidad ni achicando la
fuente), detalle completo movido a `tooltip_text`. Verificado de nuevo con
captura — limpio, sin superposición, en los 31 nodos.

## 6. Verificación

CLI equivalentes a cada interacción real, mismo criterio que el resto del
proyecto (`level_controller.gd`, `main_menu_controller.gd`): `unlock=<id>`
(repetible, para probar cadenas), `points=<n>` (override del placeholder,
primera pasada — order-independent respecto a `unlock=`), `auto-back`
(equivalente a "Volver"), `screenshot-quit`.

| Caso | Resultado |
|---|---|
| Carga limpia, sin argumentos | 0/31 desbloqueados, 10 puntos, sin errores |
| `unlock=root unlock=off_trunk_1 unlock=off_pen_1 unlock=off_pen_2`, `points=5` | 4/31, 1 punto — coincide con costos (1+1+1+1) |
| `unlock=eco_capstone` (sin ningún prerequisito de la cadena desbloqueado) | 0/31 — rechazado correctamente, 4 niveles de profundidad |
| `unlock=bogus` (id inexistente) | `push_error`, sin crash, resto de la ronda sigue normal |
| `points=0 unlock=root` y `unlock=root points=0` (dos órdenes) | Los dos dan 0/31 — confirma que `points=` no depende del orden en la línea de comandos |
| `MainMenu.tscn -- auto-talents ...` | Carga `TalentTree.tscn`, procesa el resto de los argumentos ahí |
| `TalentTree.tscn -- ... auto-back` | Vuelve a `MainMenu.tscn` limpio |
| Captura de ventana, mezcla de estados (bloqueado/disponible/desbloqueado) | Sin superposición, líneas correctas, prefijos `[G]`/`[T2]`/`[T5]` legibles |

**Nota sobre las herramientas de prueba, no del juego:** `auto-talents` y
`auto-back` combinados en la misma invocación rebotan indefinidamente
(cada pantalla vuelve a leer los mismos argumentos de línea de comandos al
cargar, así que la segunda pantalla dispara la navegación de vuelta, que
dispara la de ida, etc.) — no es un bug de la navegación real (un click
real no se "reproduce" solo en la siguiente pantalla), es una propiedad de
cómo funcionan los flags de CLI acá. Cada transición se probó aislada.

## 7. Qué sigue — no se decide ni se ejecuta acá

Conectar `effect_scope`/`stat_id`/`modifier_value` a `TowerStore`/
`TowerSystem` real, calibrar `_points_available` y el costo de cada nodo
contra una economía de progresión de verdad, decidir si el árbol real
tiene más de un prerequisito por nodo en algún punto (el modelo de datos
lo soporta con un cambio acotado si hace falta) — todo esto es la "próxima
interacción en base a notas" que pidió el usuario, no un pendiente
olvidado.
