extends StaticBody2D

@export var wall_size: Vector2 = Vector2(140.0, 28.0)
var _rect: Rect2

func _ready() -> void:
	queue_redraw()
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	get_node("CollisionShape2D").shape = shape
	_rect = Rect2(global_position - wall_size * 0.5, wall_size)
	WallManager.register(_rect)

func _exit_tree() -> void:
	WallManager.unregister(_rect)

func _draw() -> void:
	var r := Rect2(-wall_size * 0.5, wall_size)
	draw_rect(r.grow(5.0), Color(0.15, 0.5, 0.9, 0.28))
	draw_rect(r, Color(0.1, 0.14, 0.26, 1.0))
	draw_rect(r, Color(0.45, 0.85, 1.0, 1.0), false, 3.0)
