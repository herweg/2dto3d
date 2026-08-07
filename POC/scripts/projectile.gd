extends Area2D

var speed: float    = 420.0
var lifetime: float = 2.2
var damage: float   = 1.0
var color: Color    = Color(1.0, 0.95, 0.25, 1.0)

var direction: Vector2 = Vector2.RIGHT
var active: bool = false
var _lifetime_left: float = 0.0
var _pool_ref: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func activate(pos: Vector2, dir: Vector2, pool: Node, spd: float, lt: float, dmg: float, col: Color) -> void:
	global_position = pos
	direction = dir.normalized()
	speed = spd
	_lifetime_left = lt
	damage = dmg
	color = col
	active = true
	monitoring = true
	set_physics_process(true)
	_pool_ref = pool

func _physics_process(delta: float) -> void:
	if not active:
		return
	global_position += direction * speed * delta
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_deactivate()

func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, color)
		var player := GameManager.player_ref
		if player and player.life_steal > 0.0:
			player.health = minf(player.health + damage * player.life_steal, player.max_health)
		_deactivate()

func _deactivate() -> void:
	active = false
	monitoring = false
	set_physics_process(false)
	if _pool_ref:
		_pool_ref.return_projectile(self)
