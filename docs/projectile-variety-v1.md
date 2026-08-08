# Variedad de tipos de proyectil v1 (T5)

**Rol que lo emite:** Diseño de combate (rol cubierto por el mismo desarrollador único)
**Estado:** CERRADO — 06-ago-2026
**Complementa a:** `combat-design-v1.md` (T3) — los modificadores de daño (crítico,
elemento, perforación, DoT, cadena) se aplican *sobre* estos comportamientos, no
al revés.

---

## Variedad visual vs. variedad de comportamiento

Distinción que ya resuelve `directorsuggestions.md` sección 2.3: **variedad
visual** (reskin — mismo comportamiento, otro sprite/color/atlas frame) no tiene
costo de diseño relevante ni cuenta para este documento — un atlas + custom data
de `MultiMesh` cubre cientos de variantes visuales sin trabajo extra. Lo que sí
cuesta diseño y contenido real es **variedad de comportamiento**: cada patrón de
movimiento/targeting distinto es una entrada nueva en el "catálogo de
comportamientos" que el núcleo tiene que soportar.

**Orden de magnitud para v1: ~10-15 comportamientos únicos.** Docenas de "tipos
de proyectil" que vea el jugador son combinaciones de estos comportamientos base
+ modificadores de T3 + variedad visual — no 10-15 sistemas de movimiento
completamente aislados unos de otros.

---

## Roster inicial de comportamientos (13)

| # | Comportamiento | Reusa | Notas |
|---|---|---|---|
| 1 | **Recto homing** | Ya existe (pistola/báculo/arco) | Dirección fija al spawn, hacia el enemigo más cercano |
| 2 | **Orbital** | Ya existe (orbe) | Orbita al jugador, dispara en cono |
| 3 | **Perforante** | `hits_remaining` (T3) | Sigue de largo tras cada impacto hasta agotar el contador |
| 4 | **Cadena/rebote** | `chains_remaining` + hash espacial (T3) | Salta a enemigos cercanos al impactar |
| 5 | **Cono/abanico** | Movimiento recto ×N | Dispara varios proyectiles en spread simultáneo desde un solo disparo |
| 6 | **Homing en vuelo** | — | Persigue al objetivo mientras viaja, no solo direcciona al spawn (a diferencia de #1) |
| 7 | **Bumerán** | — | Sale, llega a rango máximo, vuelve hacia el jugador |
| 8 | **Zona persistente** | `dot_dps`/`dot_time_left` (T3, en enemigo) | Se planta en el piso, aplica DoT a quien la pise mientras dura |
| 9 | **Aura creciente** | Similar a orbital | Orbita muy cerca del jugador, crece de tamaño/daño con el tiempo |
| 10 | **Pulso radial** | — | Anillo de daño que se expande desde el punto de origen, sin dirección — no viaja como los demás |
| 11 | **Carga** | — | Vuela lento, gana daño/tamaño cuanto más tiempo lleva en el aire |
| 12 | **Enjambre errático** | Movimiento recto + ruido | Varios proyectiles chicos con desvío aleatorio leve por frame |
| 13 | **Lanza** | Movimiento recto | Corto alcance, muy rápida, daño alto en un solo golpe |

---

## Qué significa esto para `entity_store.gd` (Sprint 4+)

Ningún comportamiento de la lista necesita un sistema aparte del ya propuesto en
`directorsuggestions.md` — todos son variaciones de **cómo se actualiza
`velocity`/`position` cada tick** y **cuándo se considera "impacto"**, sobre el
mismo array plano de proyectiles. La diferencia entre comportamientos es lógica
de movimiento (una función distinta por `type_id`, tabla-driven como ya hace
`TYPE_STATS` en `enemy.gd`), no una estructura de datos distinta. Los únicos
campos de datos nuevos que estos comportamientos podrían pedir, más allá de los
ya definidos en T3, son banderas chicas de estado (ej. "ya rebotó al volver" para
el bumerán, "tiempo en vuelo" para la carga) — se resuelven al mismo costo que
los campos ya congelados en T3, no antes de Sprint 4.

---

## Qué queda fuera de v1

Cualquier comportamiento no listado arriba (ej. invocación de proyectiles
autónomos/familiares, teletransporte, proyectiles que se dividen al impactar) —
fase futura. La lista de 13 es el roster de arranque para Sprint 4+, no un
compromiso de contenido final; se puede recortar o ampliar durante producción
sin afectar el esquema de datos, porque todos comparten la misma estructura.
