extends Node

var _walls: Array[Rect2] = []

func register(rect: Rect2) -> void:
	_walls.append(rect)

func unregister(rect: Rect2) -> void:
	_walls.erase(rect)

func push_out(pos: Vector2, radius: float) -> Vector2:
	for rect in _walls:
		if not rect.grow(radius).has_point(pos):
			continue
		var closest := Vector2(
			clampf(pos.x, rect.position.x, rect.end.x),
			clampf(pos.y, rect.position.y, rect.end.y)
		)
		var diff := pos - closest
		var dist_sq := diff.length_squared()
		if dist_sq > 0.0 and dist_sq < radius * radius:
			var dist := sqrt(dist_sq)
			pos += diff / dist * (radius - dist)
	return pos
