extends "res://scripts/weapon_base.gd"

const DETECTION_RADIUS_SQ := 420.0 * 420.0
const PROJ_SPEED           := 480.0
const PROJ_LIFETIME        := 1.8
const PROJ_COLOR           := Color(0.3, 1.0, 0.5, 1.0)

var _timer: float = 0.0

func _ready() -> void:
	weapon_id = "metralleta"
	damage = 0.4
	fire_cooldown = 0.07
	super._ready()

func _physics_process(delta: float) -> void:
	if _proj_pool == null or GameManager.is_game_over:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var target := _get_nearest_enemy(global_position, _effective_range_sq(DETECTION_RADIUS_SQ))
	if target == null:
		return
	var base_dir := (target.global_position - global_position).normalized()
	var dir := base_dir.rotated(randf_range(-0.2, 0.2))
	_proj_pool.spawn(global_position, dir,
		_effective_proj_speed(PROJ_SPEED), PROJ_LIFETIME,
		_effective_damage(), PROJ_COLOR)
	_timer = _effective_cooldown()
