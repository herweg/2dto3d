extends "res://scripts/weapon_base.gd"

const DETECTION_RADIUS_SQ := 380.0 * 380.0
const PROJ_SPEED           := 520.0
const PROJ_LIFETIME        := 1.6
const PROJ_COLOR           := Color(0.75, 0.35, 1.0, 1.0)

var _timer: float = 0.0

func _ready() -> void:
	weapon_id = "baculo"
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
	var dir := (target.global_position - global_position).normalized().rotated(randf_range(-0.15, 0.15))
	_proj_pool.spawn(global_position, dir,
		_effective_proj_speed(PROJ_SPEED), PROJ_LIFETIME,
		_effective_damage(), PROJ_COLOR)
	_timer = _effective_cooldown()
