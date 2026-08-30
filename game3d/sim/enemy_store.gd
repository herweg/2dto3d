class_name EnemyStore
extends EntityStore

var speed: PackedFloat32Array
var health: PackedFloat32Array
var stand_off: PackedFloat32Array  # distancia al ancla en la que deja de acercarse

## Índice del próximo waypoint que persigue este enemigo — usado por
## lane_enemy_system.gd (Fase 2, pantallas de carril). Ignorado por
## enemy_system.gd/el benchmark del spike, que no lo tocan. Cero por
## default (PackedInt32Array.resize() rellena con 0), así que no hace falta
## pasarlo en spawn() para los llamadores que no lo usan.
var waypoint_index: PackedInt32Array

## Daño en el tiempo — slot único sin stackeo, congelado desde
## combat-design-v1.md (0 costo en la fila de proyectil). Lo alimentan dos
## fuentes (fase2-plan-proyectiles.md 1.1/1.2): PROJ_ZONE (lanzallamas,
## projectile_system.gd) y el láser (chequeo directo de la torre,
## tower_system.gd) — ambas refrescan el mismo timer, no lo suman. Lo
## consume dot_system.gd, un tick por frame sobre todo EnemyStore.
var dot_dps: PackedFloat32Array
var dot_time_left: PackedFloat32Array

func _init(p_capacity: int) -> void:
	super._init(p_capacity)
	speed.resize(p_capacity)
	health.resize(p_capacity)
	stand_off.resize(p_capacity)
	waypoint_index.resize(p_capacity)
	dot_dps.resize(p_capacity)
	dot_time_left.resize(p_capacity)

func _swap_extra(idx: int, last: int) -> void:
	speed[idx] = speed[last]
	health[idx] = health[last]
	stand_off[idx] = stand_off[last]
	waypoint_index[idx] = waypoint_index[last]
	dot_dps[idx] = dot_dps[last]
	dot_time_left[idx] = dot_time_left[last]

func spawn(pos: Vector2, p_speed: float, p_health: float, p_stand_off: float, variant: int) -> int:
	var idx := acquire()
	if idx == -1:
		return -1
	positions[idx] = pos
	type_id[idx] = variant
	speed[idx] = p_speed
	health[idx] = p_health
	stand_off[idx] = p_stand_off
	# Un enemigo nuevo nunca hereda el DoT residual del slot reciclado —
	# a diferencia de waypoint_index, esto no lo puede dejar en manos del
	# llamador sin arriesgar daño fantasma.
	dot_dps[idx] = 0.0
	dot_time_left[idx] = 0.0
	return idx
