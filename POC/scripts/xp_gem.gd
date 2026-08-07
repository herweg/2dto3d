extends Node2D

var xp_value: float = 1.0
var active: bool = false
var _pool_ref: Node = null

func activate(pos: Vector2, value: float, pool: Node) -> void:
	global_position = pos
	xp_value = value
	active = true
	_pool_ref = pool

func collect() -> void:
	if not active:
		return
	active = false
	GameManager.add_xp(xp_value)
	if _pool_ref:
		_pool_ref.return_gem(self)
