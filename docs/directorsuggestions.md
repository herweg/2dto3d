# Cómo lo construiría yo — propuesta técnica del director

**Complementa a [`poc-scale-memo.md`](poc-scale-memo.md).** Ese memo era neutral:
listaba qué preguntas había que responder antes de decidir. Este documento no es
neutral — es mi apuesta concreta de cómo construiría el núcleo de simulación si
tuviera que empezar hoy, y qué necesito que el PM resuelva para que esa apuesta no se
convierta en la excusa de nadie más adelante.

---

## 1. La decisión de fondo

El problema del POC no es "Godot es lento". Es que **cada entidad es un objeto vivo
del motor** (Node + script + Area2D en el árbol de física) cuando en realidad es un
puñado de números: posición, velocidad, daño, vida, tipo. Un enemigo o un proyectil no
necesita señales, ni un `_ready()`, ni un lugar en el árbol de escena — necesita una
fila en una tabla.

Mi apuesta: **diseño orientado a datos (SoA) + hash espacial propio + escritura de
buffer completo para el render**, primero en GDScript puro, escalando a GDExtension
sólo si el spike demuestra que GDScript no alcanza. No reescribiría esto directamente
en C++ "por las dudas" — es una apuesta más cara que hay que ganarse con datos, no
asumir de entrada.

---

## 2. Arquitectura que propondría

```
sim/
  entity_store.gd        — arrays planos (SoA) + free-list con swap-remove
  spatial_hash.gd         — grilla uniforme: build() e insert() sobre enemigos
  projectile_system.gd    — movimiento + colisión + daño, un solo batch por tick
  enemy_system.gd          — steering al jugador + push-out de paredes (se conserva del POC)
render/
  entity_render_sync.gd   — un solo multimesh_set_buffer() por grupo visual y por frame
data/
  projectile_defs.tres    — tabla de tipos de proyectil (formaliza TYPE_STATS del POC)
  enemy_defs.tres         — tabla de tipos de enemigo
(capa de producto, se porta del POC casi sin cambios)
  weapon_*.gd, GameManager.gd, enemy_spawner.gd, HUD, upgrade_menu.gd
    → llaman a ProjectileSystem.spawn(type_id, pos, dir) en vez de instanciar Nodes
```

### 2.1 Entidades como filas, no como Nodes

Un único `EntityStore` (autoload) por tipo de entidad (proyectiles, enemigos) con
arrays paralelos: `positions: PackedVector2Array`, `velocities: PackedVector2Array`,
`health: PackedFloat32Array`, `type_id: PackedInt32Array`, `ttl: PackedFloat32Array`,
etc. Nada de esto vive en el árbol de escena.

Reciclado con **free-list + swap-remove**: al morir una entidad, se la reemplaza por
la última entidad activa del array y se reduce `active_count` en uno. Así el loop
principal siempre itera `0..active_count` sin nunca visitar entradas muertas — el POC
hoy recorre el pool completo (`for p in _pool: if not p.active: continue`) incluso
cuando la mayoría está inactiva. A 400 elementos no se nota; a 50.000, sí.

### 2.2 Colisión: hash espacial propio, no el servidor de física

Nada de `Area2D` ni `body_entered`. Una grilla uniforme reconstruida cada tick a
partir de las posiciones de los **enemigos** (miles, no decenas de miles — es el lado
barato de la asimetría). Cada proyectil, en su propio batch de movimiento, consulta
sólo la celda donde cayó (más vecinas si el radio lo exige) y hace `distance_squared_to`
contra los pocos enemigos de esa celda. Esto convierte una colisión que hoy es
O(proyectiles × enemigos) en la práctica en algo cercano a O(proyectiles).

### 2.3 Render: un buffer, no una llamada por instancia

Reemplazar `set_instance_transform_2d()` / `set_instance_color()` llamados en loop por
una sola escritura de `multimesh_set_buffer()` por frame, construida en un solo paso
sobre los mismos arrays que ya recorre el sistema de movimiento — no un recorrido
aparte para "sincronizar visuales".

La variedad visual ("decenas de miles de proyectiles distintos") no implica decenas de
miles de `MultiMesh`. Con un atlas de textura y datos por-instancia (custom data del
`MultiMesh`, que Godot permite codificar como color) un shader puede elegir el frame
del atlas por instancia. Un solo `MultiMesh` + un atlas cubre cientos de variantes
visuales distintas sin multiplicar draw calls.

### 2.4 Daño y eventos: batch, no señales

La colisión y la aplicación de daño ocurren en el mismo paso, sobre los arrays, sin
`emit_signal` ni `has_method()` por impacto. Los efectos secundarios (muerte, drop de
XP, número de daño en pantalla) se empujan a una cola y se procesan una vez por frame,
con un tope explícito — si caen 400 números de daño en el mismo frame, se agregan
("+3.200 ×14") en vez de instanciar 400 labels. La animación de muerte deja de ser un
`Tween` por enemigo y pasa a ser un temporizador más en el array, resuelto en el mismo
batch que ya escribe el buffer de render.

### 2.5 GDScript primero, GDExtension si hace falta

Empezaría el spike íntegramente en GDScript con este diseño. Mi hipótesis de trabajo
— no un hecho confirmado, es justamente lo que el spike debe medir — es que SoA +
hash espacial + buffer único puede sostener del orden de varios miles a ~15.000
proyectiles simples a 60 fps en GDScript puro, y que decenas de miles simultáneos
probablemente exige mover el paso de colisión + aplicación de daño a un módulo
GDExtension (C++ o Rust vía `godot-rust`), dejando todo lo demás — armas, mejoras,
oleadas, UI, definición de contenido — en GDScript. Es una escalada acotada, no una
reescritura completa del juego en C++.

> **#Auditor:** ningún documento de la cadena confirma que el equipo (los 1–2 devs
> senior que se van a asignar al spike) tenga experiencia previa con GDExtension en
> C++ o con `godot-rust`. Si no la tienen, la ruta B del spike no mide solo "¿esta
> arquitectura escala?" sino que además absorbe una curva de aprendizaje de
> bindings de Godot dentro de un corte duro de 10 días hábiles — eso puede sesgar
> el resultado del spike (ruta GDExtension mal medida por falta de fluidez, no por
> límite real de la técnica). Vale la pena que Dirección de Desarrollo confirme
> esto al mismo tiempo que confirma nombres para el spike (T7 de `sprint-01.md`),
> no descubrirlo recién al arrancar la ruta B en Sprint 2 o 3.

### 2.6 Qué se porta del POC tal cual

El sistema de armas, la progresión de XP, el spawner por oleadas, el HUD y el patrón
de tabla de stats por tipo no cambian de diseño — cambian de API. Donde hoy
`weapon_metralleta.gd` llama `_proj_pool.spawn(...)` sobre un pool de Nodes, llamaría
a `ProjectileSystem.spawn(type_id, pos, dir)` sobre el nuevo store. El trabajo de
diseño de armas ya hecho en el POC no se pierde.

---

## 3. Qué espero del Product Manager

No es una lista de preguntas abiertas — es lo que necesito que esté resuelto para
poder ejecutar la propuesta de arriba sin tener que adivinar sobre la marcha.

1. **Un número, no una figura de estilo.** "Decenas de miles" tiene que convertirse en
   un requisito concreto — por ejemplo *"20.000 proyectiles vivos simultáneos, pico de
   30.000 en oleadas de clímax"* — antes de que el spike empiece. Sin ese número no
   hay forma de saber si la propuesta de la sección 2 alcanza o si hace falta escalar
   a GDExtension desde el día uno.

2. **Especificación de hardware mínimo**, salida de una decisión de plataforma/mercado
   que le corresponde a producto, no a ingeniería. Cambia el presupuesto de frame
   real, no el teórico de 16.6 ms.

3. **Un documento de diseño de combate** — críticos, resistencias, perforación, daño
   en el tiempo, cadenas — antes de que se congele el formato de la fila de datos por
   proyectil. Cada campo que se agrega a esa fila después de empezar a construir tiene
   costo de migración; cada uno definido antes, no.

4. **Decisión sobre multijugador/red**, sí o no o "más adelante pero con intención".
   Si la respuesta es "sí" en cualquier horizonte visible, la arquitectura de
   simulación cambia de raíz (paso fijo determinístico, autoridad de servidor) y
   preferiría saberlo antes de escribir `entity_store.gd`, no después.

5. **Aprobación explícita de 1–2 semanas de spike** antes de que cualquier fecha de
   este trabajo entre a un roadmap público. El spike no es una formalidad — es lo que
   convierte "yo creo que esto escala" en un número medido.

6. **Tratar el resultado del spike como restricción de producto, no como sugerencia.**
   Si el techo medido es 20.000 y no 50.000, la decisión de "aceptamos 20.000",
   "invertimos en GDExtension para llegar a 50.000" o "ajustamos la propuesta del
   juego" es de producto, con el número real en la mesa — no algo que ingeniería
   decida en soledad ni algo que se ignore porque ya se prometió una cifra más alta.

7. **Definir cuánta variedad real hace falta.** "Decenas de miles de proyectiles
   distintos" es, para el motor, una cuestión de cuántas *filas de datos* distintas
   existen — pero cada fila con comportamiento propio (no sólo reskin visual) es
   trabajo de diseño y de contenido, no sólo de motor. Necesito saber si el objetivo
   son cientos de tipos con muchas instancias cada uno, o si de verdad se espera
   comportamiento único a esa escala, porque el costo de autoría no es el mismo.

---

## 4. Fuera de alcance de esta propuesta (a propósito)

No estoy proponiendo threading, multijugador, ni un motor propio — cualquiera de esos
tres puede terminar siendo necesario, pero ninguno se decide en este documento. El
diseño de la sección 2 deja espacio para agregar paralelismo (dividir el batch de
proyectiles en chunks sobre `WorkerThreadPool`) como optimización posterior si el
spike de un solo hilo se queda corto — no lo doy por sentado desde ahora porque
agregar complejidad no medida todavía es exactamente el error que este documento
intenta evitar.
