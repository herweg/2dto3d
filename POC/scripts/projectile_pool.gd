extends Node

const INITIAL_SIZE = 400

var _pool: Array = []
var _proj_scene: PackedScene

func _ready() -> void:
	add_to_group("projectile_pool")
	_proj_scene = load("res://scenes/Projectile.tscn")
	for i in INITIAL_SIZE:
		_create_projectile()
	call_deferred("_init_renderer")

func _init_renderer() -> void:
	var renderer := get_tree().get_first_node_in_group("projectile_renderer")
	if renderer:
		renderer.set_pool(_pool)

func _create_projectile() -> Node:
	var p = _proj_scene.instantiate()
	add_child(p)
	p.monitoring = false
	p.set_physics_process(false)
	_pool.append(p)
	return p

func spawn(pos: Vector2, dir: Vector2, spd: float = 420.0, lt: float = 2.2, dmg: float = 1.0, col: Color = Color(1.0, 0.95, 0.25, 1.0)) -> void:
	for p in _pool:
		if not p.active:
			p.activate(pos, dir, self, spd, lt, dmg, col)
			return
	var p = _create_projectile()
	p.activate(pos, dir, self, spd, lt, dmg, col)

func return_projectile(p: Node) -> void:
	p.active = false
	p.monitoring = false
	p.set_physics_process(false)

func get_active_count() -> int:
	var count = 0
	for p in _pool:
		if p.active:
			count += 1
	return count
