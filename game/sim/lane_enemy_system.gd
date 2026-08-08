class_name LaneEnemySystem
extends RefCounted

## Movimiento de enemigos en carril (Fase 2, pantalla 1) — seek por
## waypoints en secuencia + repulsión blanda de obstáculos, sin pathfinding
## real. Ver docs/referencia-orc-problem.md y el plan de esta pantalla.
##
## No reemplaza a enemy_system.gd (que sigue siendo el steering radial que
## usa benchmark_main.gd) — es un sistema de movimiento alternativo sobre el
## mismo EnemyStore.

const WAYPOINT_ARRIVAL_DIST := 24.0
const OBSTACLE_PUSH_WEIGHT := 1.4

var store: EnemyStore
var waypoints: PackedVector2Array
var obstacles: PackedVector2Array
var obstacle_radius: float

var leaked_count: int = 0

func _init(p_store: EnemyStore, p_waypoints: PackedVector2Array, p_obstacles: PackedVector2Array, p_obstacle_radius: float) -> void:
	store = p_store
	waypoints = p_waypoints
	obstacles = p_obstacles
	obstacle_radius = p_obstacle_radius

func tick(delta: float) -> void:
	var i := 0
	while i < store.active_count:
		if store.health[i] <= 0.0:
			store.release(i)
			continue

		var wp_idx := store.waypoint_index[i]
		if wp_idx >= waypoints.size():
			# Llegó al último waypoint (la meta): se va, cuenta como leak.
			store.release(i)
			leaked_count += 1
			continue

		var pos := store.positions[i]
		var target := waypoints[wp_idx]
		var to_target := target - pos
		var dist := to_target.length()

		if dist <= WAYPOINT_ARRIVAL_DIST:
			store.waypoint_index[i] = wp_idx + 1
			i += 1
			continue

		var seek_dir := to_target / dist
		var avoid := _obstacle_avoidance(pos)
		var move_dir := (seek_dir + avoid * OBSTACLE_PUSH_WEIGHT)
		if move_dir.length_squared() > 0.0001:
			move_dir = move_dir.normalized()
		else:
			move_dir = seek_dir

		store.positions[i] = pos + move_dir * store.speed[i] * delta
		i += 1

## Suma vectores de repulsión de cada árbol cuyo radio de influencia
## (obstacle_radius + margen) invade la posición del enemigo — mismo
## espíritu que POC/autoloads/WallManager.gd::push_out, pero como aporte de
## steering continuo en vez de una corrección posicional dura.
func _obstacle_avoidance(pos: Vector2) -> Vector2:
	var push := Vector2.ZERO
	var influence := obstacle_radius * 1.8
	var i := 0
	while i < obstacles.size():
		var center := obstacles[i]
		var diff := pos - center
		var dist := diff.length()
		if dist < influence and dist > 0.001:
			push += (diff / dist) * (1.0 - dist / influence)
		i += 1
	return push
