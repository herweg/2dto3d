extends "res://scripts/weapon_base.gd"

const DETECTION_RADIUS_SQ := 700.0 * 700.0
const PROJ_SPEED           := 700.0
const PROJ_LIFETIME        := 2.8
const PROJ_COLOR           := Color(0.85, 0.75, 0.2, 1.0)

var _timer: float = 0.0

func _ready() -> void:
	weapon_id = "arco"
	damage = 8.0
	fire_cooldown = 2.4
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
	var dir := (target.global_position - global_position).normalized()
	_proj_pool.spawn(global_position, dir,
		_effective_proj_speed(PROJ_SPEED), PROJ_LIFETIME,
		_effective_damage(), PROJ_COLOR)
	_timer = _effective_cooldown()
