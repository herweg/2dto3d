extends "res://scripts/weapon_base.gd"

const ORBIT_RADIUS        := 65.0
const DETECTION_RADIUS_SQ := 480.0 * 480.0
const FIRE_CONE_COS       := 0.82
const PROJ_SPEED          := 420.0
const PROJ_LIFETIME       := 2.2
const PROJ_COLOR          := Color(1.0, 0.95, 0.25, 1.0)

var orb_count: int     = 1
var orbit_speed: float = 2.3

var _angle: float = 0.0
var _fire_timers: Array[float] = []
var _orb_local: Array[Vector2] = []

func _ready() -> void:
	weapon_id = "orbe"
	damage = 1.0
	fire_cooldown = 0.16
	_fire_timers.resize(orb_count)
	_fire_timers.fill(0.0)
	_orb_local.resize(orb_count)
	super._ready()

func add_orb() -> void:
	if orb_count >= 8:
		return
	orb_count += 1
	_fire_timers.resize(orb_count)
	_fire_timers[orb_count - 1] = 0.0
	_orb_local.resize(orb_count)
	_orb_local[orb_count - 1] = Vector2.ZERO

func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	for i in orb_count:
		var a := _angle + (TAU / orb_count) * i
		_orb_local[i] = Vector2(cos(a), sin(a)) * ORBIT_RADIUS
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _proj_pool == null or _enemy_pool_ref == null or GameManager.is_game_over:
		return
	var eff_range_sq := _effective_range_sq(DETECTION_RADIUS_SQ)
	var enemies: Array = _enemy_pool_ref._pool
	for i in orb_count:
		_fire_timers[i] -= delta
		if _fire_timers[i] > 0.0:
			continue
		var orb_world := global_position + _orb_local[i]
		var fire_dir  := _orb_local[i].normalized()
		if _has_enemy_in_cone(orb_world, fire_dir, enemies, eff_range_sq):
			_fire_timers[i] = _effective_cooldown()
			_proj_pool.spawn(orb_world, fire_dir,
				_effective_proj_speed(PROJ_SPEED), PROJ_LIFETIME,
				_effective_damage(), PROJ_COLOR)

func _has_enemy_in_cone(from: Vector2, dir: Vector2, enemies: Array, range_sq: float) -> bool:
	for enemy in enemies:
		if not enemy.active:
			continue
		var to_e: Vector2 = enemy.global_position - from
		if to_e.length_squared() > range_sq:
			continue
		if to_e.normalized().dot(dir) >= FIRE_CONE_COS:
			return true
	return false

func _draw() -> void:
	for offset in _orb_local:
		draw_circle(offset, 18.0, Color(0.15, 0.45, 1.0, 0.2))
		draw_circle(offset, 9.0, Color(0.5, 0.8, 1.0, 1.0))
		draw_circle(offset + Vector2(-2.5, -2.5), 3.5, Color(1.0, 1.0, 1.0, 0.85))
