extends CharacterBody2D

# Movimiento
var speed: float = 220.0

# Supervivencia
var max_health: float  = 100.0
var health: float      = 100.0
var hp_regen: float    = 0.0
var armor: float       = 0.0
var dodge: float       = 0.0

# Combate (globales, aplicados por weapon_base)
var damage_bonus: float     = 0.0
var attack_speed: float     = 0.0
var proj_speed_bonus: float = 0.0
var range_bonus: float      = 0.0

# Supervivencia avanzada
var life_steal: float = 0.0

# Progresión
var harvest: float = 0.0

var _last_dir: Vector2 = Vector2.RIGHT
var weapons: Array = []

@onready var _camera: Camera2D = $Camera2D

var _sprite: Sprite2D      = null
var _walk_timer: float     = 0.0
var _walk_frame: int       = 0
var _gem_pool_ref: Node    = null
var _shake_tween: Tween    = null

func _ready() -> void:
	GameManager.player_ref = self
	_setup_sprite()
	call_deferred("_find_gem_pool")

func _find_gem_pool() -> void:
	_gem_pool_ref = get_tree().get_first_node_in_group("xp_gem_pool")

func _setup_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/characters.png")
	_sprite.hframes = 5
	_sprite.vframes = 5
	_sprite.frame   = 0
	_sprite.scale   = Vector2(0.27, 0.27)
	add_child(_sprite)

func add_weapon(weapon: Node) -> void:
	add_child(weapon)
	weapons.append(weapon)

func _process(delta: float) -> void:
	if not GameManager.is_game_over and hp_regen > 0.0:
		health = minf(health + hp_regen * delta, max_health)

func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		dir.y -= 1.0

	if dir.length_squared() > 0.0:
		_last_dir = dir.normalized()
		velocity = _last_dir * speed
		_sprite.flip_h = _last_dir.x < -0.1
		_walk_timer += delta
		if _walk_timer >= 0.15:
			_walk_timer = 0.0
			_walk_frame = (_walk_frame + 1) % 2
			_sprite.frame = _walk_frame  # alterna 0 (IDLE) y 1 (WALK)
	else:
		velocity = Vector2.ZERO
		_walk_timer = 0.0
		_sprite.frame = 0

	move_and_slide()
	_collect_nearby_gems()

func _collect_nearby_gems() -> void:
	if _gem_pool_ref == null:
		return
	const PICKUP_R_SQ := 35.0 * 35.0
	for gem in _gem_pool_ref._pool:
		if gem.active and global_position.distance_squared_to(gem.global_position) < PICKUP_R_SQ:
			gem.collect()

func take_damage(amount: float) -> void:
	if GameManager.is_game_over:
		return
	if dodge > 0.0 and randf() < dodge:
		return
	var effective := maxf(0.0, amount - armor)
	health -= effective
	GameManager.player_damaged.emit(effective)
	_shake_camera()
	if health <= 0.0:
		health = 0.0
		GameManager.is_game_over = true
		GameManager.game_over.emit()

func _shake_camera() -> void:
	if _camera == null:
		return
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var intensity := 7.0
	for i in 5:
		var f := 1.0 - i * 0.18
		_shake_tween.tween_property(_camera, "offset",
			Vector2(randf_range(-intensity, intensity) * f,
					randf_range(-intensity, intensity) * f),
			0.055)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, 0.08)
