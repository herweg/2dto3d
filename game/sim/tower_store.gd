class_name TowerStore
extends EntityStore

## Torres colocadas por el jugador (Fase 2, pantalla 1). Sin release() por
## ahora — las torres no se destruyen en v1 (ver plan de la pantalla).
##
## Variedad de torres = filas de datos sobre este mismo store, no clases
## separadas (docs/referencia-orc-problem.md, punto 3) — type_id (heredado
## de EntityStore) selecciona la fila de TOWER_TYPE_STATS. `proj_extra` es
## el parámetro que necesita el proyectil de esa torre (impactos para
## perforante, radio para splash) — ver projectile_system.gd.

var range: PackedFloat32Array
var fire_rate: PackedFloat32Array
var cooldown_left: PackedFloat32Array
var damage: PackedFloat32Array
var proj_extra: PackedFloat32Array
var dot_linger: PackedFloat32Array

## type_id → {range, fire_rate, damage, proj_type, proj_extra}. proj_type
## usa las constantes PROJ_* de projectile_system.gd (0=recto, 1=homing,
## 2=perforante, 3=splash, 4=misil) más dos modos que no spawnean proyectil
## (6=BEAM — láser y lanzallamas, 7=riel — TOWER_MODE_* abajo) — acá van
## como literales para no crear una dependencia circular entre los dos
## scripts. Congelamiento de 7 tipos (fase2-plan-proyectiles.md, sección 3,
## decisión de alcance del director 08-ago) — Racimo y las categorías D/E/F
## de docs-torretas-diseno.md quedan deferidas a propósito. Nomenclatura de
## catálogo (docs-torretas-diseno.md): misil = "Mortero" (#9, arco + delay +
## splash al impacto), lanzallamas = "Fuego" (#11, DoT de área en el suelo)
## — mismo mecanismo bajo nombres distintos en cada documento, reconciliado
## 08-ago. Riel (#3) y láser quedan sin resolver si el segundo tiene entrada
## propia en el catálogo de 20 — esa parte es decisión de diseño, no de
## nomenclatura, y sigue abierta.
const TOWER_MODE_BEAM := 6  # láser + lanzallamas: rectángulo de DoT continuo, sin ProjectileStore
const TOWER_MODE_RAIL := 7  # riel: carga + hitscan instantáneo en línea, sin ProjectileStore

## Familia BEAM (migrada por completo 08-ago, fase2-benchmark-conjunto.md
## sección 7): láser y lanzallamas son un rectángulo de área efectiva que
## parte de la torre — no un punto ni un círculo. Mismos 4 parámetros para
## los dos, solo cambian los valores:
##   - `range`      → largo del rectángulo.
##   - `proj_extra` → ancho del rectángulo. Angosto y largo en láser; ancho
##     y corto en lanzallamas.
##   - `damage`     → DPS por tick (no daño directo).
##   - `dot_linger` → cuánto se refresca `dot_time_left` en cada
##     reselección de `_tick_beam()` (tower_system.gd) — dato por fila, así
##     lanzallamas puede tener una duración mayor sin tocar código.
## Ninguna de las dos filas pasa por `ProjectileStore` — `_tick_beam()`
## filtra candidatos por `SpatialHash.query_radius()` y aplica el mismo
## chequeo de corredor que ya usaba `_tick_rail()` (dot-product + distancia
## perpendicular), reevaluado a 8Hz en vez de cada tick.
const TOWER_TYPE_STATS := {
	0: {"range": 220.0, "fire_rate": 0.6, "damage": 6.0, "proj_type": 0, "proj_extra": 0.0},   # recta
	1: {"range": 260.0, "fire_rate": 1.1, "damage": 5.0, "proj_type": 1, "proj_extra": 0.0},   # homing
	2: {"range": 190.0, "fire_rate": 0.9, "damage": 4.0, "proj_type": 2, "proj_extra": 3.0},   # perforante (3 impactos)
	3: {"range": 170.0, "fire_rate": 1.4, "damage": 7.0, "proj_type": 3, "proj_extra": 42.0},  # splash (radio 42px)
	4: {"range": 240.0, "fire_rate": 1.6, "damage": 9.0, "proj_type": 4, "proj_extra": 46.0},  # misil / "Mortero" (splash radio 46px al llegar)
	# lanzallamas / "Fuego" — familia BEAM (rectángulo ancho 70px × largo 90px, DoT bajo, linger largo).
	# fire_rate sin uso (BEAM no pasa por el cooldown de disparo, ver tower_system.gd::tick()).
	5: {"range": 90.0, "fire_rate": 0.0, "damage": 3.0, "proj_type": TOWER_MODE_BEAM, "proj_extra": 70.0, "dot_linger": 1.6},
	6: {"range": 200.0, "fire_rate": 0.0, "damage": 8.0, "proj_type": TOWER_MODE_BEAM, "proj_extra": 24.0, "dot_linger": 0.4}, # láser — rectángulo angosto y largo, linger corto
	7: {"range": 260.0, "fire_rate": 1.2, "damage": 26.0, "proj_type": TOWER_MODE_RAIL, "proj_extra": 14.0}, # riel (ancho de corredor, ya vivía como RAIL_HIT_WIDTH hardcodeado)
}

## Modo desarrollo: todas las torres alcanzan cualquier punto del nivel, para
## poder verificar los 4 comportamientos sin depender de si un enemigo pasó
## cerca en la ventana de la prueba — no es calibración, es para no confundir
## "no hay línea de vista" con "el tipo no dispara". TOWER_TYPE_STATS arriba
## queda con los rangos reales para cuando se calibre el juego de verdad;
## poner esto en 0.0 (o borrar la línea) vuelve a usar esos valores tal cual.
# TODO(calibración de combate): DEV_RANGE_OVERRIDE y DEV_FIRE_RATE_OVERRIDE
# (ambas abajo) siguen activas desde la verificación de los 4 tipos de
# proyectil y el stress test de gráficos/animación (docs/fase2-stress-test.md).
# Poner las dos en 0.0 antes de calibrar el juego de verdad — mientras sigan
# así, ninguna corrida refleja el balance real de TOWER_TYPE_STATS.
## `static var`, no `const`: el benchmark de pico conjunto
## (stress_main.gd, mode=joint) las pisa a 0.0 en tiempo de ejecución para
## esa corrida específica — TOWER_TYPE_STATS real, tal como pidió el
## director — sin tener que comentar/descomentar código a mano.
static var DEV_RANGE_OVERRIDE := 2000.0

## Mismo espíritu que DEV_RANGE_OVERRIDE, para la cadencia de disparo — usado
## por la simulación de estrés (30 torres disparando rápido). 0.0 (o borrar
## la línea) vuelve a usar el fire_rate real de TOWER_TYPE_STATS.
static var DEV_FIRE_RATE_OVERRIDE := 0.06

func _init(p_capacity: int) -> void:
	super._init(p_capacity)
	range.resize(p_capacity)
	fire_rate.resize(p_capacity)
	cooldown_left.resize(p_capacity)
	damage.resize(p_capacity)
	proj_extra.resize(p_capacity)
	dot_linger.resize(p_capacity)

func _swap_extra(idx: int, last: int) -> void:
	range[idx] = range[last]
	fire_rate[idx] = fire_rate[last]
	cooldown_left[idx] = cooldown_left[last]
	damage[idx] = damage[last]
	proj_extra[idx] = proj_extra[last]
	dot_linger[idx] = dot_linger[last]

func spawn(pos: Vector2, p_range: float, p_fire_rate: float, p_damage: float, variant: int, p_proj_extra: float = 0.0, p_dot_linger: float = 0.0) -> int:
	var idx := acquire()
	if idx == -1:
		return -1
	positions[idx] = pos
	type_id[idx] = variant
	range[idx] = p_range
	fire_rate[idx] = p_fire_rate
	cooldown_left[idx] = 0.0
	damage[idx] = p_damage
	proj_extra[idx] = p_proj_extra
	dot_linger[idx] = p_dot_linger
	return idx

## Coloca una torre del tipo `tower_type` (0-3) usando TOWER_TYPE_STATS.
func spawn_typed(pos: Vector2, tower_type: int) -> int:
	var stats: Dictionary = TOWER_TYPE_STATS[tower_type]
	var effective_range: float = DEV_RANGE_OVERRIDE if DEV_RANGE_OVERRIDE > 0.0 else stats["range"]
	var effective_fire_rate: float = DEV_FIRE_RATE_OVERRIDE if DEV_FIRE_RATE_OVERRIDE > 0.0 else stats["fire_rate"]
	# .get() con default 0.0: solo las filas de familia BEAM (5, 6) definen
	# dot_linger hoy — el resto no lo necesita y no hace falta poblarlo.
	return spawn(pos, effective_range, effective_fire_rate, stats["damage"], tower_type, stats["proj_extra"], stats.get("dot_linger", 0.0))

func proj_type_of(idx: int) -> int:
	return TOWER_TYPE_STATS[type_id[idx]]["proj_type"]
