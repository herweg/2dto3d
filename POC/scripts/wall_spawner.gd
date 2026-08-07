extends Node

const WALL_SCENE := preload("res://scenes/Wall.tscn")
const COUNT    := 12
const MIN_DIST := 280.0
const MAX_DIST := 1200.0

func _ready() -> void:
	for i in COUNT:
		var angle := randf() * TAU
		var dist  := randf_range(MIN_DIST, MAX_DIST)
		var pos   := Vector2(cos(angle), sin(angle)) * dist
		var wall  := WALL_SCENE.instantiate()
		wall.wall_size = Vector2(120.0, 24.0) if randi() % 2 == 0 else Vector2(24.0, 120.0)
		wall.position  = pos
		# call_deferred: garantiza que wall._ready() corre fuera de la fase ready del arbol
		get_parent().call_deferred("add_child", wall)
