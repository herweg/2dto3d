extends Node

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Fondo — shader de piedra/dungeon
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/dungeon_bg.gdshader")
	bg.material = mat
	canvas.add_child(bg)

	# Contenido centrado
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-190.0, -185.0)
	center.custom_minimum_size = Vector2(380.0, 370.0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(center)

	# Título
	var title := Label.new()
	title.text = "SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_HI)
	UITheme.apply_font(title, true)
	center.add_child(title)

	# Separador decorativo
	UITheme.gold_sep(center, 16)

	# Tagline
	var tagline := Label.new()
	tagline.text = "¿Cuánto tiempo sobrevivirás?"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	center.add_child(tagline)

	_gap(center, 52)

	# Botones
	var play := UITheme.styled_button("JUGAR", 240.0, 54.0, 22)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	center.add_child(play)

	_gap(center, 10)

	var quit := UITheme.styled_button("SALIR", 240.0, 44.0, 16)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	center.add_child(quit)

	# Hint inferior
	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20.0, -48.0)
	hint.text = "WASD / Flechas — Moverse       Esc — Pausa"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	canvas.add_child(hint)

func _gap(parent: Control, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	parent.add_child(c)
