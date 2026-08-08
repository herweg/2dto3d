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

## type_id → {range, fire_rate, damage, proj_type, proj_extra}. proj_type
## usa las constantes PROJ_* de projectile_system.gd (0=recto, 1=homing,
## 2=perforante, 3=splash) — acá van como literales para no crear una
## dependencia circular entre los dos scripts.
const TOWER_TYPE_STATS := {
	0: {"range": 220.0, "fire_rate": 0.6, "damage": 6.0, "proj_type": 0, "proj_extra": 0.0},   # recta
	1: {"range": 260.0, "fire_rate": 1.1, "damage": 5.0, "proj_type": 1, "proj_extra": 0.0},   # homing
	2: {"range": 190.0, "fire_rate": 0.9, "damage": 4.0, "proj_type": 2, "proj_extra": 3.0},   # perforante (3 impactos)
	3: {"range": 170.0, "fire_rate": 1.4, "damage": 7.0, "proj_type": 3, "proj_extra": 42.0},  # splash (radio 42px)
}

## Modo desarrollo: todas las torres alcanzan cualquier punto del nivel, para
## poder verificar los 4 comportamientos sin depender de si un enemigo pasó
## cerca en la ventana de la prueba — no es calibración, es para no confundir
## "no hay línea de vista" con "el tipo no dispara". TOWER_TYPE_STATS arriba
## queda con los rangos reales para cuando se calibre el juego de verdad;
## poner esto en 0.0 (o borrar la línea) vuelve a usar esos valores tal cual.
# TODO(calibración de combate): DEV_RANGE_OVERRIDE y DEV_FIRE_RATE_OVERRIDE
# (ambas const, abajo) siguen activas desde la verificación de los 4 tipos de
# proyectil y el stress test de gráficos/animación (docs/fase2-stress-test.md).
# Poner las dos en 0.0 antes de calibrar el juego de verdad — mientras sigan
# así, ninguna corrida refleja el balance real de TOWER_TYPE_STATS.
const DEV_RANGE_OVERRIDE := 2000.0

## Mismo espíritu que DEV_RANGE_OVERRIDE, para la cadencia de disparo — usado
## por la simulación de estrés (30 torres disparando rápido). 0.0 (o borrar
## la línea) vuelve a usar el fire_rate real de TOWER_TYPE_STATS.
const DEV_FIRE_RATE_OVERRIDE := 0.06

func _init(p_capacity: int) -> void:
	super._init(p_capacity)
	range.resize(p_capacity)
	fire_rate.resize(p_capacity)
	cooldown_left.resize(p_capacity)
	damage.resize(p_capacity)
	proj_extra.resize(p_capacity)

func _swap_extra(idx: int, last: int) -> void:
	range[idx] = range[last]
	fire_rate[idx] = fire_rate[last]
	cooldown_left[idx] = cooldown_left[last]
	damage[idx] = damage[last]
	proj_extra[idx] = proj_extra[last]

func spawn(pos: Vector2, p_range: float, p_fire_rate: float, p_damage: float, variant: int, p_proj_extra: float = 0.0) -> int:
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
	return idx

## Coloca una torre del tipo `tower_type` (0-3) usando TOWER_TYPE_STATS.
func spawn_typed(pos: Vector2, tower_type: int) -> int:
	var stats: Dictionary = TOWER_TYPE_STATS[tower_type]
	var effective_range: float = DEV_RANGE_OVERRIDE if DEV_RANGE_OVERRIDE > 0.0 else stats["range"]
	var effective_fire_rate: float = DEV_FIRE_RATE_OVERRIDE if DEV_FIRE_RATE_OVERRIDE > 0.0 else stats["fire_rate"]
	return spawn(pos, effective_range, effective_fire_rate, stats["damage"], tower_type, stats["proj_extra"])

func proj_type_of(idx: int) -> int:
	return TOWER_TYPE_STATS[type_id[idx]]["proj_type"]
