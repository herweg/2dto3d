extends Node2D

const POOL_SIZE := 32

var _pool: Array[Label] = []

func _ready() -> void:
	add_to_group("damage_numbers")
	for i in POOL_SIZE:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.visible = false
		add_child(lbl)
		_pool.append(lbl)

func show_damage(world_pos: Vector2, amount: float, col: Color) -> void:
	for lbl in _pool:
		if not lbl.visible:
			_activate(lbl, world_pos, amount, col)
			return

func _activate(lbl: Label, world_pos: Vector2, amount: float, col: Color) -> void:
	lbl.text = str(int(amount)) if amount >= 1.0 else "%.1f" % amount
	lbl.add_theme_color_override("font_color", col)
	lbl.position  = world_pos
	lbl.modulate.a = 1.0
	lbl.visible   = true
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", world_pos.y - 38.0, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void: lbl.visible = false)
