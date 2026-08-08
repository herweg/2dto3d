# Diseño de combate v1 (T3)

**Rol que lo emite:** Diseño de combate (rol cubierto por el mismo desarrollador único)
**Estado:** CERRADO — 06-ago-2026
**Propósito:** lista cerrada de modificadores de daño que soporta v1, con su mecánica
y su costo en el esquema de datos de `entity_store.gd` (Sprint 4+). El director es
explícito en `directorsuggestions.md`: cada campo agregado a la fila de datos
*después* de empezar a construir tiene costo de migración — este documento es lo
que se congela *antes*.

---

## Modificadores incluidos en v1

### 1. Críticos
**Mecánica:** % de probabilidad + multiplicador de daño, por arma. Se sortea **una
sola vez al spawnear el proyectil** — el valor de daño que queda guardado en la fila
ya es el final (con o sin crit aplicado), no se re-evalúa en el impacto.
**Costo en el esquema:** **0 campos nuevos.** Es el modificador más barato de los
cinco — toda la lógica vive en el momento del spawn, no en el hot path de colisión.

### 2. Resistencias elementales (acotado a 2 elementos para v1)
**Mecánica:** cada proyectil lleva un tipo de elemento — **físico o mágico** para
v1 (no más, a propósito, para no disparar el trabajo de contenido). La resistencia
no vive por instancia de enemigo, vive en la tabla `TYPE_STATS` por **tipo** de
enemigo (mismo patrón que ya usa `enemy.gd` para HP/velocidad/daño de contacto).
**Costo en el esquema:** **+1 campo** en la fila de proyectil (`element_id`, un
entero chico: 0 = físico, 1 = mágico). La resistencia en sí no cuesta nada por
instancia — es una tabla pequeña indexada por tipo de enemigo, no por enemigo vivo.

### 3. Perforación (piercing)
**Mecánica:** cada proyectil lleva un contador de "impactos restantes", fijado por
el arma al spawnear. Se resta uno por cada enemigo golpeado; el proyectil se
desactiva cuando llega a 0 (igual que hoy se desactiva al primer impacto —
`projectile.gd:_on_body_entered`).
**Costo en el esquema:** **+1 campo** (`hits_remaining`, entero chico). Reusa el
mismo chequeo de colisión que ya existe, solo cambia la condición de desactivación.

### 4. Daño en el tiempo (DoT)
**Mecánica:** un solo tipo de DoT para v1 (ej. "quemado": X daño/seg durante T
segundos). Vive como **un slot único por enemigo**, no por proyectil — los
enemigos son el lado barato de la escala (miles, no decenas de miles) según la
propia asimetría que ya usa el diseño del hash espacial. Si se reaplica el DoT
sobre un enemigo que ya lo tiene, **se refresca la duración** en vez de
stackear — no hace falta más de un slot.
**Costo en el esquema:** **+2 campos, pero en la fila de ENEMIGO, no de
proyectil** (`dot_dps`, `dot_time_left`). Cero costo adicional en la fila de
proyectil, que es la que más se multiplica a esta escala (6.000-8.000 simultáneos
contra 1.500-2.000 enemigos).

### 5. Cadenas (rebote entre enemigos)
**Mecánica:** al impactar, el daño salta a los N enemigos más cercanos al punto de
impacto, usando **el mismo hash espacial que ya construye el sistema de colisión**
— no hace falta una estructura nueva. Tope duro de saltos por proyectil (propongo
**3** como default de arranque, ajustable en balance) para no descontrolar el
costo por frame si muchos proyectiles con cadena impactan en el mismo tick.
**Costo en el esquema:** **+1 campo** (`chains_remaining`, entero chico).

---

## Fuera de v1 — fase futura, explícito

- Cualquier modificador de daño no listado arriba: daño en área/splash, marcar y
  detonar, ejecución/finisher, control de multitud más allá del `hit_flash`
  visual que ya existe (stun, slow, knockback).
- Múltiples DoT simultáneos o stackeo de DoT — v1 es un solo slot que se refresca.
- Más de 2 elementos de resistencia.
- Cadenas sin tope de saltos.

Todo lo anterior queda para una versión futura del diseño de combate, no de v1.

---

## Impacto en el esquema de `entity_store.gd` (Sprint 4+)

**Fila de PROYECTIL — campos nuevos respecto al POC actual:**

| Campo | Tipo | Modificador |
|---|---|---|
| `element_id` | int chico (0/1) | Resistencias elementales |
| `hits_remaining` | int chico | Perforación |
| `chains_remaining` | int chico | Cadenas |

**Fila de ENEMIGO — campos nuevos:**

| Campo | Tipo | Modificador |
|---|---|---|
| `dot_dps` | float | Daño en el tiempo |
| `dot_time_left` | float | Daño en el tiempo |

**Críticos: 0 campos nuevos en ninguna fila** — se resuelve al spawnear, no en el
hot path de simulación.

Este es el input que congela el formato de fila cuando arranque la Fase 2
(rediseño del núcleo). Los 3 campos de proyectil son enteros chicos (pueden
compartir un solo `PackedInt32Array` empaquetado o ir en arrays separados según
convenga en la implementación — decisión técnica de Sprint 4, no de este
documento).

---

## Pendiente — balance, no bloqueante para congelar el esquema

Estos valores son ajuste de juego, no afectan el formato de la fila, así que
pueden definirse después sin costo de migración:

- % y multiplicador de crítico por arma
- % de resistencia física/mágica por tipo de enemigo
- Cuántos impactos de perforación trae cada arma que la tenga
- DPS y duración del DoT
- Número exacto de saltos de cadena (default de arranque: 3)
- Qué armas del roster actual (pistola, báculo, orbe, arco) llevan qué
  modificador — se puede resolver en T5 o en Sprint 4
