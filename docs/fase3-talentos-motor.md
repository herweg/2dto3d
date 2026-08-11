# Árbol de talentos — contenido "real" para el frame

**Rol:** Dirección de Desarrollo.
**Fecha:** 09-ago-2026 (ver `game/data/talent_tree_def.gd`, que ya apuntaba
acá antes de que este documento existiera — "la próxima interacción" era
esta).

**Antes de diseñar nada, leí el esquema que el equipo ya construyó**
(`TalentTreeDef`, arreglos paralelos estilo SoA) en vez de inventar uno
propio — tenía un primer borrador con nodos de doble prerequisito y
capstones de dos efectos, y los dos rompían contra restricciones reales
del modelo ya implementado:

- **Un solo padre por nodo** (`parent_ids` es un string, no un array —
  "árbol simple, no grafo general", comentario explícito en el código). Mi
  diseño original pedía nodos que necesitaban rango de tronco *y* un nodo
  hermano a la vez — no entra. Rediseñado a cadenas de un solo padre;
  sigue leyéndose PoE (tronco → se abre la sub-rama en el nodo donde
  corresponde), solo que la profundidad la da la cadena en sí, no un
  prerequisito doble.
- **Un solo `stat_id`/`modifier_value` por nodo** (arreglos paralelos, no
  una lista de efectos por nodo). Mis capstones con trade-off (+daño
  /-cadencia en el mismo nodo) tampoco entraban — quedaron como un único
  efecto grande en vez de una decisión de doble filo. Anotado como idea
  para más adelante si el esquema crece a soportar multi-efecto, no para
  ahora.

Con eso resuelto, generé directamente `game/data/talents_01.tres` con
contenido real — no una descripción para transcribir a mano.

---

## 1. Forma del árbol

Un `root` ("Núcleo", sin efecto) del que cuelgan 3 troncos — Ofensiva,
Control, Economía — cada uno con 3 rangos (1 punto c/u) que dan un bonus
chico y parejo, y de los que cuelgan dos sub-cadenas de 3 nodos cada una,
más un nodo capstone (costo 2) al final del tronco. **31 nodos en total**
(1 root + 3 troncos × 10) — suficiente para que el frame tenga líneas de
conexión y estados reales que probar, sin ser un ejercicio de balance.

**Corrección sobre mi propio plan inicial:** iba a apoyarme en que 31
nodos "obligaran" a resolver scroll/paneo, pero `talent_tree_controller.gd`
no tiene `Camera2D` ni scroll — es un `CanvasLayer` fijo, mismo criterio
que `MainMenu.tscn`. No inventé esa necesidad ni le pedí al equipo que la
resuelva sin que yo la haya verificado: en cambio, calculé las 31
posiciones para que entren en los 1280×720 reales sin superponerse.
Verificado con un chequeo de pares (AABB, `NODE_SIZE=150×44`) antes de
darlo por bueno — cero solapamientos, todos los nodos con margen real
contra el borde del viewport. Si el árbol final crece mucho más que esto
por torreta, scroll/paneo sí va a hacer falta — pero esa es una tarjeta
aparte, no algo que estos 31 nodos resuelvan de rebote.

Dos nodos usan `effect_scope=TOWER_TYPE` en vez de `GLOBAL` (uno en
Ofensiva sobre perforante, uno en Control sobre lanzallamas) — a propósito,
para que el frame ejercite las dos rutas de dato que ya expone el schema,
no solo la global que dominaba el placeholder viejo.

## 2. Convención de valores, para quien conecte esto a combate después

- **Nodos `GLOBAL` sobre un stat multiplicativo** (daño, cadencia, DoT,
  radio de splash, resistencia elemental, puntos por baja):
  `modifier_value` es una fracción — `0.05` = +5%, `-0.05` = -5% (mismo
  criterio que ya usaba el placeholder viejo, `damage_all: 0.05`,
  `fire_rate_all: -0.05`). Se asume que el sistema de combate suma todos
  los nodos con el mismo `stat_id` alocados — no está confirmado que ese
  sumador exista todavía, es la lectura más simple y es la que ya
  implicaba el placeholder anterior.
- **Nodos `TOWER_TYPE`**: `modifier_value` es un delta plano sobre el
  campo real de `TowerStore` (`pierce_hits` → `proj_extra` cuando
  `proj_type=PIERCE`, `damage` → `TowerStore.damage`) — mismo criterio que
  ya usaban `flamethrower_2`/`pierce_1` en el placeholder viejo.
- **`ctrl_deb_1`/`3` y `off_pen_1`/`3`** usan `elemental_resist_reduction_all`
  con signo positivo (`+0.10` = reduce 10 puntos porcentuales la
  resistencia enemiga) — no negativo, para no mezclar "resta a la
  resistencia" con "resta al daño" bajo la misma convención de signo.
- **`tower_slots_all`** y `off_pen_2`'s `pierce_hits` son conteos, no
  fracciones — `1.0` = +1 unidad flat, igual que ya hacía `pierce_1` en el
  placeholder anterior.
- **`ctrl_capstone` (`vulnerable_dot_dmg_all`)** es un stat con nombre
  propio, no uno que ya exista en el motor — representa "daño extra contra
  enemigos con DoT activo" (condición chequeable hoy vía
  `EnemyStore.dot_time_left > 0`), pero conectarlo es trabajo de combate
  aparte, no de esta tarjeta — mismo espíritu que el resto del árbol
  ("plumbing de datos, sin conectar todavía", comentario de
  `talent_tree_def.gd`).

## 3. Las 3 ramas, con qué representan

- **Ofensiva ("Poder de Fuego"):** daño global + crítico + penetración
  (reduce resistencia enemiga, +1 blanco para perforante). Capstone
  "Sobrecarga": +20% daño global, sin la contrapartida de cadencia que
  tenía mi borrador original — no entraba en un nodo de un solo efecto.
- **Control ("Dominio del Campo"):** duración/fuerza de DoT + splash +
  debilitación (resistencia enemiga, duración de DoT, un nodo que
  potencia lanzallamas específicamente). Capstone "Punto Débil": bonus de
  daño contra enemigos con DoT activo — el único nodo del árbol pensado
  para necesitar lógica condicional cuando se conecte de verdad, no solo
  sumar un stat.
- **Economía ("Ingeniería"):** puntos por baja + slots de torre +
  cadencia global (menor cooldown). Capstone "Economía de Guerra": +2
  slots de torre de una vez.

## 4. Estado de prueba sugerido para el frame, no un número de diseño

Con 31 nodos alcanza para probar los tres estados visuales que un árbol
real necesita a la vez (asignado / disponible-no-tomado / bloqueado por
prerequisito) sin necesitar un guion de prueba aparte — alcanza con
asignar, por ejemplo, el tronco completo de Ofensiva (3) + una sub-rama
completa (3) + el tronco de Economía a rango 2 (2), y dejar Control sin
tocar, para ver los tres estados conviviendo.
