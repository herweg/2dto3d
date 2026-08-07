extends CanvasLayer

@onready var fps_label: Label = $FpsLabel
@onready var kills_label: Label = $KillsLabel
@onready var enemies_label: Label = $EnemiesLabel
@onready var health_label: Label = $HealthLabel
@onready var game_over_label: Label = $GameOverLabel

var _enemy_pool: Node = null
var _level_label: Label
var _xp_bar: ProgressBar
var _timer_label: Label
var _wave_label: Label
var _wave_tween: Tween = null
var _go_panel: Control = null
var _go_stats: Dictionary = {}
var _equip_bar: HBoxContainer
var _last_weapon_count: int = -1
var _items_img: Image = null

func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.wave_scaled.connect(_on_wave_scaled)
	game_over_label.visible = false
	call_deferred("_find_pool")

	_level_label = Label.new()
	_level_label.position = Vector2(10, 122)
	add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.position = Vector2(10, 148)
	_xp_bar.size = Vector2(220, 14)
	_xp_bar.show_percentage = false
	_xp_bar.max_value = 10.0
	_xp_bar.value = 0.0
	add_child(_xp_bar)

	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.position = Vector2(-120.0, 10.0)
	_timer_label.size = Vector2(110.0, 28.0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.add_theme_font_size_override("font_size", 20)
	_timer_label.add_theme_color_override("font_color", UITheme.C_GOLD_HI)
	UITheme.apply_font(_timer_label, true)
	add_child(_timer_label)

	_wave_label = Label.new()
	_wave_label.set_anchors_preset(Control.PRESET_CENTER)
	_wave_label.offset_left   = -220.0
	_wave_label.offset_right  =  220.0
	_wave_label.offset_top    = -50.0
	_wave_label.offset_bottom =  50.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 26)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.15))
	_wave_label.modulate.a = 0.0
	add_child(_wave_label)

	_items_img = load("res://assets/items.png").get_image()
	_build_equip_bar()
	_build_game_over_panel()

func _find_pool() -> void:
	_enemy_pool = get_tree().get_first_node_in_group("enemy_pool")

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	kills_label.text = "Kills: %d" % GameManager.kill_count
	if _enemy_pool:
		enemies_label.text = "Enemies: %d" % _enemy_pool.get_active_count()
	if GameManager.player_ref:
		var pct := int(GameManager.player_ref.health / GameManager.player_ref.max_health * 100.0)
		health_label.text = "HP: %d%%" % pct
	_level_label.text = "Lv. %d" % GameManager.level
	_xp_bar.max_value = GameManager.xp_to_next
	_xp_bar.value = GameManager.xp
	var secs := int(GameManager.elapsed_time)
	_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	var wcount: int = GameManager.player_ref.weapons.size() if GameManager.player_ref else 0
	if wcount != _last_weapon_count:
		_last_weapon_count = wcount
		_refresh_equip_bar()

func _on_wave_scaled(new_mult: float) -> void:
	var wave_num := int(GameManager.elapsed_time / GameManager.DIFF_INTERVAL)
	_wave_label.text = "— Oleada %d —\nEnemigos +%d%% HP / +%d%% velocidad" % [
		wave_num,
		int((new_mult - 1.0) * 100.0),
		int((new_mult - 1.0) * 50.0)
	]
	_wave_label.modulate.a = 1.0
	if _wave_tween:
		_wave_tween.kill()
	_wave_tween = create_tween()
	_wave_tween.tween_interval(2.5)
	_wave_tween.tween_property(_wave_label, "modulate:a", 0.0, 1.2)

func _build_game_over_panel() -> void:
	_go_panel = Control.new()
	_go_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_go_panel.process_mode = PROCESS_MODE_ALWAYS
	_go_panel.visible = false
	add_child(_go_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.80)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_go_panel.add_child(bg)

	var card := ColorRect.new()
	card.color = UITheme.C_BLOOD
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-215.0, -200.0)
	card.size     = Vector2(430.0, 400.0)
	_go_panel.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-195.0, -185.0)
	vbox.custom_minimum_size = Vector2(390.0, 370.0)
	_go_panel.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_HI)
	UITheme.apply_font(title, true)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	vbox.add_child(subtitle)
	_go_stats["subtitle"] = subtitle

	var sep1 := HSeparator.new()
	sep1.custom_minimum_size = Vector2(0.0, 14.0)
	vbox.add_child(sep1)

	for pair in [
		["kills",     "Kills"],
		["nivel",     "Nivel alcanzado"],
		["dificultad","Dificultad"],
		["armas",     "Armas usadas"],
	]:
		var row := _stat_row(pair[1])
		vbox.add_child(row[0])
		_go_stats[pair[0]] = row[1]

	var sep2 := HSeparator.new()
	sep2.custom_minimum_size = Vector2(0.0, 14.0)
	vbox.add_child(sep2)

	var hint := Label.new()
	hint.text = "R  —  Reiniciar        ESC  —  Menú principal"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	vbox.add_child(hint)

func _stat_row(label_text: String) -> Array:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0.0, 42.0)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200.0, 0.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	hbox.add_child(lbl)

	var val := Label.new()
	val.custom_minimum_size = Vector2(180.0, 0.0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", UITheme.C_TEXT)
	hbox.add_child(val)

	return [hbox, val]

func _build_equip_bar() -> void:
	_equip_bar = HBoxContainer.new()
	_equip_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_equip_bar.offset_top = -74
	_equip_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_equip_bar.add_theme_constant_override("separation", 6)
	add_child(_equip_bar)

func _refresh_equip_bar() -> void:
	for child in _equip_bar.get_children():
		child.queue_free()
	if GameManager.player_ref == null:
		return
	for weapon in GameManager.player_ref.weapons:
		_equip_bar.add_child(_make_equip_slot(weapon.weapon_id))

func _make_equip_slot(weapon_id: String) -> Control:
	var outer := Control.new()
	outer.custom_minimum_size = Vector2(64.0, 70.0)

	var bg := ColorRect.new()
	bg.color = Color(UITheme.C_PANEL.r, UITheme.C_PANEL.g, UITheme.C_PANEL.b, 0.90)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48.0, 48.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.texture = ItemsSheet.get_icon(weapon_id, _items_img)
	vbox.add_child(icon_rect)

	var lbl := Label.new()
	lbl.text = _weapon_display_name(weapon_id)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	vbox.add_child(lbl)

	return outer

func _weapon_display_name(weapon_id: String) -> String:
	match weapon_id:
		"pistola": return "Pistola"
		"baculo":  return "Báculo"
		"orbe":    return "Orbe"
		"arco":    return "Arco"
	return weapon_id.capitalize()

func _on_game_over() -> void:
	var secs := int(GameManager.elapsed_time)
	var mins := secs / 60
	var s    := secs % 60
	_go_stats["subtitle"].text    = "Sobreviviste %d:%02d" % [mins, s]
	_go_stats["kills"].text       = str(GameManager.kill_count)
	_go_stats["nivel"].text       = "Lv. %d" % GameManager.level
	var wave := int(GameManager.elapsed_time / GameManager.DIFF_INTERVAL)
	_go_stats["dificultad"].text  = "Oleada %d  (×%.1f)" % [wave, GameManager.difficulty_mult]
	var weapon_names: Array[String] = []
	if GameManager.player_ref:
		for w in GameManager.player_ref.weapons:
			weapon_names.append(_weapon_display_name(w.weapon_id))
	_go_stats["armas"].text = ", ".join(weapon_names) if weapon_names.size() > 0 else "Ninguna"

	_go_panel.modulate.a = 0.0
	_go_panel.visible    = true
	var tw := create_tween()
	tw.tween_property(_go_panel, "modulate:a", 1.0, 0.55)
