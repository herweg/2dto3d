class_name BenchmarkSpawner
extends RefCounted

## Paso 2 de sprint-02.md — spawner sintético. Rampa por niveles desde 0
## hasta el pico objetivo, sosteniendo la población con un "fuente" que
## repone lo que muere (por ttl o por impacto) cada frame, para poder medir
## frame time en un plateau estable a cada nivel, no solo en el instante del
## spawn masivo.

const SPAWN_RING := 850.0
const MAX_SPAWN_PER_FRAME := 800

var proj_store: ProjectileStore
var enemy_store: EnemyStore

var proj_levels: Array
var enemy_levels: Array
var level_idx: int = 0
var level_duration: float
var _level_timer: float = 0.0

var proj_speed_min := 250.0
var proj_speed_max := 450.0
var proj_life := 3.0
var proj_damage := 4.0

var enemy_speed_min := 40.0
var enemy_speed_max := 90.0
var enemy_health := 1.0e6  # no diseñado para morir en el spike — ver nota en sprint-02.md
var enemy_stand_off_min := 60.0
var enemy_stand_off_max := 240.0  # anillo de "melee" alrededor del ancla — ver nota en enemy_system.gd

func _init(p_proj: ProjectileStore, p_enemy: EnemyStore, p_proj_levels: Array, p_enemy_levels: Array, p_level_duration: float) -> void:
	proj_store = p_proj
	enemy_store = p_enemy
	proj_levels = p_proj_levels
	enemy_levels = p_enemy_levels
	level_duration = p_level_duration

func current_proj_target() -> int:
	return proj_levels[level_idx]

func current_enemy_target() -> int:
	return enemy_levels[level_idx]

func at_final_level() -> bool:
	return level_idx >= proj_levels.size() - 1

func tick(delta: float) -> void:
	_level_timer += delta
	if _level_timer >= level_duration and not at_final_level():
		level_idx += 1
		_level_timer = 0.0

	_top_up_projectiles()
	_top_up_enemies()

func _top_up_projectiles() -> void:
	var target := current_proj_target()
	var spawned := 0
	while proj_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var dir := Vector2.from_angle(randf() * TAU)
		var pos := dir * randf_range(0.0, 40.0)
		var speed := randf_range(proj_speed_min, proj_speed_max)
		proj_store.spawn(pos, dir * speed, proj_life, proj_damage, randi() % 4)
		spawned += 1

func _top_up_enemies() -> void:
	var target := current_enemy_target()
	var spawned := 0
	while enemy_store.active_count < target and spawned < MAX_SPAWN_PER_FRAME:
		var dir := Vector2.from_angle(randf() * TAU)
		var pos := dir * SPAWN_RING
		var stand_off := randf_range(enemy_stand_off_min, enemy_stand_off_max)
		enemy_store.spawn(pos, randf_range(enemy_speed_min, enemy_speed_max), enemy_health, stand_off, randi() % 4)
		spawned += 1
