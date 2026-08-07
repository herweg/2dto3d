extends Node

const INITIAL_SIZE = 250

var _pool: Array = []
var _enemy_scene: PackedScene

func _ready() -> void:
	add_to_group("enemy_pool")
	_enemy_scene = load("res://scenes/Enemy.tscn")
	for i in INITIAL_SIZE:
		_create_enemy()
	call_deferred("_init_renderer")

func _create_enemy() -> Node:
	var e = _enemy_scene.instantiate()
	add_child(e)
	e.visible = false
	e.set_physics_process(false)
	_pool.append(e)
	return e

func _init_renderer() -> void:
	var renderer = get_tree().get_first_node_in_group("enemy_renderer")
	if renderer:
		renderer.set_pool(_pool)

func spawn(pos: Vector2, type: int = 0) -> void:
	for e in _pool:
		if not e.active and not e.dying:
			e.activate(pos, self, type)
			return
	var e = _create_enemy()
	e.activate(pos, self, type)

func return_enemy(e: Node) -> void:
	e.active = false
	e.set_physics_process(false)

func get_active_count() -> int:
	var count = 0
	for e in _pool:
		if e.active:
			count += 1
	return count
