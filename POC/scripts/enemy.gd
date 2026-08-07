extends CharacterBody2D

# -- Tipos y stats por tipo --
const TYPE_GOBLIN   := 0
const TYPE_BRUTO    := 1
const TYPE_CHAMAN   := 2
const TYPE_GUARDIAN := 3

# [base_hp, base_speed, contact_dmg, attack_rate, gem_drops]
const TYPE_STATS := {
	0: [2.0,   80.0, 10.0, 1.0, 2],   # Goblin: HP 3→2, gems 1→2
	1: [12.0,  52.0, 20.0, 1.2, 4],   # Bruto:  HP 18→12
	2: [10.0,  68.0,  8.0, 0.8, 3],
	3: [60.0,  32.0, 35.0, 1.5, 6],
}

const CONTACT_RANGE := 28.0

var enemy_type: int   = TYPE_GOBLIN
var health: float     = 3.0
var active: bool      = false
var dying: bool       = false
var hit_flash: float  = 0.0

var _speed: float       = 80.0
var _contact_dmg: float = 10.0
var _attack_rate: float = 1.0
var _gem_drops: int     = 1
var _attack_cooldown: float = 0.0
var _pool_ref: Node = null

func _ready() -> void:
	add_to_group("enemies")

func activate(pos: Vector2, pool: Node, type: int = TYPE_GOBLIN) -> void:
	enemy_type = type
	var s: Array = TYPE_STATS[type]
	var dm: float = GameManager.difficulty_mult
	health        = s[0] * dm
	_speed        = s[1] * (1.0 + (dm - 1.0) * 0.5)
	_contact_dmg  = s[2]
	_attack_rate  = s[3]
	_gem_drops    = s[4]

	global_position  = pos
	active           = true
	dying            = false
	set_physics_process(true)
	scale            = Vector2.ONE
	_attack_cooldown = _attack_rate
	hit_flash        = 0.0
	_pool_ref        = pool

func _physics_process(delta: float) -> void:
	if not active or GameManager.player_ref == null:
		return
	var to_player := GameManager.player_ref.global_position - global_position
	global_position += to_player.normalized() * _speed * delta
	global_position  = WallManager.push_out(global_position, 12.0)

	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		if to_player.length_squared() < CONTACT_RANGE * CONTACT_RANGE:
			GameManager.player_ref.take_damage(_contact_dmg)
			_attack_cooldown = _attack_rate
		else:
			_attack_cooldown = 0.1

	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 6.0)

func take_hit(damage: float, col: Color = Color(1.0, 0.9, 0.5, 1.0)) -> void:
	if not active:
		return
	health -= damage
	hit_flash = 1.0
	var dn := get_tree().get_first_node_in_group("damage_numbers")
	if dn:
		dn.show_damage(global_position + Vector2(randf_range(-6.0, 6.0), -12.0), damage, col)
	if health <= 0.0:
		die()

func die() -> void:
	active = false
	dying  = true
	set_physics_process(false)
	GameManager.kill_count += 1
	GameManager.enemy_killed.emit(global_position)

	var gem_pool := get_tree().get_first_node_in_group("xp_gem_pool")
	if gem_pool:
		for i in _gem_drops:
			var offset := Vector2.ZERO
			if _gem_drops > 1:
				offset = Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
			gem_pool.spawn(global_position + offset, 1.0)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.12)
	tw.tween_callback(_return_to_pool)

func _return_to_pool() -> void:
	dying     = false
	scale     = Vector2.ONE
	hit_flash = 0.0
	if _pool_ref:
		_pool_ref.return_enemy(self)
