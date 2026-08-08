# POC Horde-Survivor: ¿escala a decenas de miles de proyectiles?

**Memo técnico — Dirección de Desarrollo**

| | |
|---|---|
| **Para** | Product Manager |
| **De** | Dirección de Desarrollo |
| **Fecha** | 06 agosto 2026 |
| **Asunto** | Viabilidad de escala del núcleo de simulación (Godot 4.7 / GDScript) |

Evaluación del boilerplate en `/POC` contra el nuevo objetivo de producto, y lista de
decisiones que le corresponden al Product Manager y su equipo antes de comprometer el
roadmap.

---

## 00. Resumen ejecutivo

El POC valida un conjunto de patrones de rendimiento — no un motor listo para
producción. Sostiene del orden de **cientos** de enemigos y proyectiles simultáneos a
60 fps. El objetivo nuevo pide **miles** de enemigos y **decenas de miles** de
proyectiles: una diferencia de una a dos órdenes de magnitud, no un ajuste de
parámetros.

El cuello de botella no es "poco pooling". Es que cada proyectil del POC es un
`Area2D` real dentro del servidor de física de Godot, con un `Node` y una instancia de
GDScript propia evaluada cada tick. Ese diseño tiene un techo estructural muy por
debajo del objetivo. Subir los buffers de `MAX_PROJ` o el tamaño del pool no lo
resuelve.

**Recomendación en una línea:** conservar la capa de producto (armas, mejoras,
oleadas, UI) y los principios de rendimiento validados; reconstruir el núcleo de
simulación desde cero con diseño orientado a datos, después de un spike técnico corto
que responda las preguntas de la sección 3.

> **Presupuesto de frame a 60 fps: 16.6 ms/frame.** Con las ~400 entidades activas del
> POC, buena parte de ese margen ya lo consume el árbol de física + despacho de
> señales de Godot. Cada orden de magnitud adicional de proyectiles reduce ese margen
> antes de que la lógica de daño o el render toquen un solo frame.

---

## 01. Qué valida el POC — conservar

Patrones que funcionan y se trasladan aunque el núcleo se reescriba. No hay que
redescubrir esto.

- **✅ Object pooling** — cero `instantiate()` / `queue_free()` en el hot path. El
  principio se mantiene aunque cambie qué se agrupa.
  `enemy_pool.gd` · `projectile_pool.gd`

- **✅ MultiMesh para render masivo** — un draw call por tipo de entidad en vez de uno
  por instancia. Es la técnica correcta; lo que hay que revisar es *cómo* se sube el
  buffer a esa escala (ver sección 2).
  `enemy_renderer.gd` · `projectile_renderer.gd`

- **✅ Movimiento manual, sin `move_and_slide()`** — para entidades que no necesitan
  resolución física compleja, sumar posición directamente evita el narrowphase del
  motor de física. Principio correcto, y debe extenderse también a proyectiles.
  `enemy.gd:58` · `README.md`

- **✅ Resolución de paredes con AABB manual** — `WallManager.push_out()` evita queries
  al motor de física para algo tan simple como "no atravesar un rectángulo". El mismo
  principio — matemática propia en vez de motor genérico — es la base de la propuesta
  de colisión en la sección 4.
  `WallManager.gd`

- **✅ Stats por tipo, data-driven** — `TYPE_STATS` como tabla en vez de lógica
  dispersa. Formaliza bien a Resources o JSON; es la base natural para "decenas de
  miles de proyectiles distintos" en el nuevo objetivo.
  `enemy.gd:10`

- **✅ Capa de producto independiente del núcleo** — el sistema de armas, la
  progresión de XP, el spawner por oleadas y el HUD no dependen de cómo se simulan
  las entidades por dentro. Esto se puede preservar y portar aunque el núcleo de
  simulación se reescriba por completo — no es trabajo perdido.
  `weapon_base.gd` · `enemy_spawner.gd` · `GameManager.gd`

---

## 02. Qué no escala — bloqueantes arquitectónicos

Esto no se arregla subiendo constantes. Requiere rediseño antes de intentar la escala
pedida.

- **🔴 Bloqueante #1 — Colisión vía Area2D + señal `body_entered`.** Cada proyectil
  vivo es un `CollisionObject2D` real dentro del árbol de física de Godot, con
  broadphase y despacho de señales por objeto. Este mecanismo escala a cientos; no a
  decenas de miles, sin importar cuánto se optimice el resto.
  `projectile.gd:1,14,36`

- **🔴 Bloqueante #2 — Un Node + script por entidad.** Aunque esté pooled y oculto,
  Godot sigue invocando `_physics_process()` de cada Node activo cada tick, con el
  overhead de despacho dinámico y boxing de Variant propio de GDScript. Este techo es
  independiente del de física — persiste incluso si se reemplaza la colisión.
  `projectile.gd:28` · `enemy.gd:54`

- **🔴 Bloqueante #3 — Búsqueda de objetivo O(n) por arma.** `_get_nearest_enemy()` y
  `_has_enemy_in_cone()` recorren el pool completo de enemigos en cada disparo o cada
  frame por cada orbe. Con miles de enemigos y varias armas activas por jugador, el
  costo crece de forma multiplicativa sin partición espacial (grid / hash espacial).
  `weapon_base.gd:42` · `weapon_orbe.gd:59`

- **🟠 Riesgo — Sincronización de render instancia por instancia.**
  `set_instance_transform_2d()` y `set_instance_color()` se llaman una vez por entidad
  activa, desde GDScript, cada frame. A decenas de miles de instancias son decenas de
  miles de llamadas GDScript→motor solo para dibujar. Godot expone escritura de
  buffer completo (`multimesh_set_buffer`) que probablemente sea obligatoria a esta
  escala.
  `projectile_renderer.gd:47` · `enemy_renderer.gd:57`

- **🟠 Riesgo — Costo por-evento en hit/muerte.** `create_tween()` en cada muerte de
  enemigo y `get_first_node_in_group("damage_numbers")` en cada impacto son invisibles
  a cientos de eventos por segundo, pero no gratuitos. A la tasa de impactos que
  implican decenas de miles de proyectiles, hay que medirlos explícitamente, no asumir
  que siguen siendo insignificantes.
  `enemy.gd:77,98`

- **🟠 Menor — Buffers fijos (400 proyectiles / 1000 enemigos).** Fácil de subir como
  constante, pero antes de asumir que "subir el número" alcanza, hay que confirmar que
  un único `MultiMesh` sostiene buffers de ese orden de magnitud sin degradar la
  latencia de subida por frame.
  `projectile_renderer.gd:3` · `enemy_renderer.gd:3`

---

## 03. Preguntas para investigar antes de decidir

Esto le toca al Product Manager y al equipo — no son decisiones técnicas puras, son
decisiones de producto con consecuencias técnicas. Ninguna tiene respuesta todavía.

1. **¿"Decenas de miles de proyectiles" son simultáneos en pantalla, o acumulados a lo
   largo de una partida?** Cambia por completo el problema de ingeniería.
   **Acción:** fijar un número concreto ("20.000 proyectiles vivos simultáneos", no
   una figura de estilo) como requisito de producto antes de diseñar nada.

2. **¿Cuál es el techo real de entidades activas por frame en GDScript puro?** El POC
   prueba del orden de 1.000, no 5.000+.
   **Acción:** spike sintético — N quads moviéndose y colisionando sin lógica de
   juego — para encontrar dónde cae de 60 fps.

3. **¿Alcanza GDScript con arrays planos y hash espacial propio, o hace falta
   GDExtension (C++/Rust) para el hot path?**
   **Acción:** medir ambos caminos en el mismo spike antes de comprometerse a uno. La
   diferencia de esfuerzo entre los dos es grande como para decidirla sin datos.

4. **¿Cuál es el hardware mínimo objetivo?** Decenas de miles de proyectiles a 60 fps
   en una laptop de gama baja es un problema distinto a en desktop de gama alta.
   **Acción:** especificación mínima definida junto con producto/marketing, no
   asumida por el equipo técnico.

5. **¿Qué tan compleja es la lógica de daño por impacto?** Críticos, resistencias
   elementales, perforación, daño en el tiempo, cadenas — cada modificador multiplica
   el costo por impacto a esta escala.
   **Acción:** definir el diseño de combate deseado antes de fijar el presupuesto de
   cómputo por proyectil.

6. **¿Multijugador o sincronización en red están en el roadmap?** Cambiaría la
   arquitectura de forma radical (netcode determinístico o autoridad de servidor).
   **Acción:** debe decidirse antes del rediseño del núcleo, no después.

7. **¿Godot sigue siendo el motor correcto para este objetivo?** Si el spike muestra
   que ni GDExtension sostiene el número que defina producto, hay que evaluarlo
   abiertamente.
   **Acción:** no asumir de antemano que "más optimización" lo resuelve — que lo
   confirme el spike.

   > **Actualización 06-ago:** decidido con antelación al spike, en base a
   > investigación de precedentes (no a datos propios): se sigue con Godot +
   > GDExtension. Hay patrón probado en la comunidad (plugins C++/MultiMesh para
   > bullet-hell) y precedente comercial shipeado (*Dome Keeper*) manejando miles
   > de entidades en producción. El gap real frente a Unity es la falta de un
   > ECS/DOTS con paralelismo automático — mitigable con `WorkerThreadPool` si el
   > spike de un solo hilo se queda corto, no evaluado de antemano. Detalle en
   > `definicion-escala-v1.md`.
   >
   > **No es una decisión cerrada para siempre.** Se reabre formalmente si el
   > spike mide una brecha grande entre el objetivo de T2 y el resultado real:
   > concretamente, si ni GDExtension de un solo hilo ni GDExtension +
   > `WorkerThreadPool` llegan a ~60% del objetivo. Ver condición completa en
   > `definicion-escala-v1.md`, sección "Decisión sobre el motor".

---

## 04. La distancia, en números

Lo que el POC prueba hoy contra lo que pide el objetivo declarado (asumiendo el rango
medio de "miles" y "decenas de miles" hasta que la pregunta 01 tenga respuesta).

| Métrica | POC — validado | Objetivo declarado | Factor |
|---|---|---|---|
| Enemigos activos simultáneos | 250 – 1.000 | 2.000 – 5.000 *("unos miles" — a confirmar)* | 2× – 20× |
| Proyectiles activos simultáneos | 80 – 400 | 10.000 – 50.000 *("decenas de miles" — a confirmar)* | 25× – 600× |
| Tipos de proyectil distintos | 5 *(un script por arma)* | sin definir *(pregunta 01 / 05)* | — |
| Mecanismo de colisión | Servidor de física (Area2D) | a definir *(ver sección 4)* | — |

---

## 05. Recomendación final

### No construir el producto final directamente sobre este boilerplate

1. **Tratar el POC como especificación validada, no como cimiento.** Documenta qué
   funciona y por qué; no es el punto de partida del código de producción.
2. **Preservar y portar la capa de producto** — armas, mejoras, progresión, oleadas,
   UI — que es independiente de cómo se simulan las entidades por dentro.
3. **Reconstruir el núcleo de simulación** con diseño orientado a datos: arrays planos
   en vez de un Node por entidad, hash espacial propio en vez del servidor de física,
   y escritura de buffer completo para el render en vez de llamada por instancia.
4. **No fijar fecha ni alcance todavía.** Correr primero un spike técnico de 1–2
   semanas enfocado solo en las preguntas de la sección 3, con un número objetivo
   concreto que defina producto — no el equipo técnico por su cuenta.

---

*Referencias de código: `/POC/scripts`, `/POC/autoloads` — Godot 4.7 · GDScript ·
revisión sobre el estado actual del repositorio.*
