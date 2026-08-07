extends Node

const POOL_SIZE := 300
const GEM_SCRIPT := preload("res://scripts/xp_gem.gd")

var _pool: Array = []

func _ready() -> void:
	add_to_group("xp_gem_pool")
	for i in POOL_SIZE:
		_create_gem()
	call_deferred("_init_renderer")

func _init_renderer() -> void:
	var r := get_tree().get_first_node_in_group("xp_gem_renderer")
	if r:
		r.set_pool(_pool)

func _create_gem() -> void:
	var gem: Node2D = GEM_SCRIPT.new()
	add_child(gem)
	_pool.append(gem)

func spawn(pos: Vector2, value: float = 1.0) -> void:
	for gem in _pool:
		if not gem.active:
			gem.activate(pos, value, self)
			return
	_create_gem()
	_pool[-1].activate(pos, value, self)

func return_gem(gem: Node2D) -> void:
	gem.active = false
