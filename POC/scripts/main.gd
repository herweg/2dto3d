extends Node2D

const UpgradeMenuScript := preload("res://scripts/upgrade_menu.gd")
const DebugUpgradePanelScript := preload("res://scripts/debug_upgrade_panel.gd")

@onready var background: ColorRect = $BackgroundLayer/Background

var _upgrade_menu: CanvasLayer
var _debug_panel: CanvasLayer
var _pause_menu: CanvasLayer

func _ready() -> void:
	var tex: Texture2D = load("res://assets/grass_tile.png")
	if background and background.material and tex:
		background.material.set_shader_parameter("grass_tex", tex)
		background.material.set_shader_parameter("tile_size", 600.0)

	_upgrade_menu = UpgradeMenuScript.new()
	add_child(_upgrade_menu)

	_debug_panel = DebugUpgradePanelScript.new()
	add_child(_debug_panel)

	_add_vignette()
	_build_pause_menu()
	GameManager.level_up.connect(_on_level_up)
	call_deferred("_on_level_up")

func _on_level_up() -> void:
	get_tree().paused = true
	_upgrade_menu.show_menu()

func _process(_delta: float) -> void:
	if GameManager.player_ref and background and background.material:
		background.material.set_shader_parameter(
			"player_pos", GameManager.player_ref.global_position
		)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_F1:
			_debug_spawn_200()
		KEY_F2:
			_debug_panel.toggle()
		KEY_R:
			if GameManager.is_game_over:
				GameManager.reset()
				get_tree().paused = false
				get_tree().reload_current_scene()
		KEY_ESCAPE:
			if GameManager.is_game_over:
				_go_to_menu()
			else:
				_toggle_pause()

func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	rect.material = mat
	layer.add_child(rect)

func _build_pause_menu() -> void:
	_pause_menu = CanvasLayer.new()
	_pause_menu.layer = 12
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.visible = false
	add_child(_pause_menu)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(overlay)

	var card := ColorRect.new()
	card.color = UITheme.C_PANEL
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-155.0, -155.0)
	card.size     = Vector2(310.0, 310.0)
	_pause_menu.add_child(card)

	# Borde dorado sobre el card
	var border := ColorRect.new()
	border.color = Color(0.0, 0.0, 0.0, 0.0)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_style.border_color = UITheme.C_GOLD
	border_style.set_border_width_all(2)
	# Use a Panel instead to show the border
	card.add_child(border)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_HI)
	UITheme.apply_font(title, true)
	vbox.add_child(title)

	UITheme.gold_sep(vbox, 13)

	_pm_gap(vbox, 12)
	_pm_button(vbox, "CONTINUAR  [Esc]", _toggle_pause)
	_pm_gap(vbox, 6)
	_pm_button(vbox, "MENÚ PRINCIPAL", _go_to_menu)
	_pm_gap(vbox, 6)
	_pm_button(vbox, "SALIR", func() -> void: get_tree().quit())

func _pm_gap(parent: Control, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	parent.add_child(c)

func _pm_button(parent: Control, text: String, cb: Callable) -> void:
	var btn := UITheme.styled_button(text, 220.0, 44.0, 16, true)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(cb)
	parent.add_child(btn)

func _toggle_pause() -> void:
	if _upgrade_menu.visible:
		return
	var pausing := not get_tree().paused
	get_tree().paused = pausing
	_pause_menu.visible = pausing

func _go_to_menu() -> void:
	get_tree().paused = false
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _debug_spawn_200() -> void:
	if GameManager.player_ref == null:
		return
	var pool := get_tree().get_first_node_in_group("enemy_pool")
	if pool == null:
		return
	for i in 200:
		var angle := float(i) / 200.0 * TAU
		var pos := GameManager.player_ref.global_position + Vector2(cos(angle), sin(angle)) * 550.0
		pool.spawn(pos)
