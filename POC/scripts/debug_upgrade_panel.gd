extends CanvasLayer

var _rows: Array = []
var _bg: ColorRect = null
var _vbox: VBoxContainer = null

func _ready() -> void:
	layer = 11
	process_mode = PROCESS_MODE_ALWAYS
	visible = false

func toggle() -> void:
	if not visible:
		_rebuild_ui()
	visible = not visible

func _rebuild_ui() -> void:
	_rows.clear()
	if _bg:
		_bg.queue_free()
		_bg = null
	if _vbox:
		_vbox.queue_free()
		_vbox = null

	var player := GameManager.player_ref
	if player == null:
		return

	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bg.position = Vector2(-332.0, 6.0)
	_bg.size = Vector2(326.0, 8.0)
	add_child(_bg)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vbox.position = Vector2(-328.0, 10.0)
	_vbox.custom_minimum_size = Vector2(318.0, 0.0)
	add_child(_vbox)

	var title := Label.new()
	title.text = "DEBUG UPGRADES  [F2]"
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_vbox.add_child(title)

	_add_row("Velocidad",
		func(): return "%.0f" % GameManager.player_ref.speed,
		func(s): GameManager.player_ref.speed = maxf(30.0, GameManager.player_ref.speed + s * 30.0)
	)
	_add_row("HP máx",
		func(): return "%.0f" % GameManager.player_ref.max_health,
		func(s):
			var p := GameManager.player_ref
			p.max_health = maxf(25.0, p.max_health + s * 25.0)
			if s < 0: p.health = minf(p.health, p.max_health)
	)
	_add_row("Regen HP/s",
		func(): return "%.1f" % GameManager.player_ref.hp_regen,
		func(s): GameManager.player_ref.hp_regen = maxf(0.0, GameManager.player_ref.hp_regen + s * 0.5)
	)
	_add_row("Armadura",
		func(): return "%.0f" % GameManager.player_ref.armor,
		func(s): GameManager.player_ref.armor = maxf(0.0, GameManager.player_ref.armor + s * 1.0)
	)
	_add_row("Esquiva %",
		func(): return "%.0f%%" % (GameManager.player_ref.dodge * 100.0),
		func(s): GameManager.player_ref.dodge = clampf(GameManager.player_ref.dodge + s * 0.05, 0.0, 0.60)
	)
	_add_row("Daño %",
		func(): return "+%.0f%%" % (GameManager.player_ref.damage_bonus * 100.0),
		func(s): GameManager.player_ref.damage_bonus = maxf(0.0, GameManager.player_ref.damage_bonus + s * 0.15)
	)
	_add_row("Cadencia %",
		func(): return "-%.0f%%" % (GameManager.player_ref.attack_speed * 100.0),
		func(s): GameManager.player_ref.attack_speed = clampf(GameManager.player_ref.attack_speed + s * 0.10, 0.0, 0.80)
	)
	_add_row("Vel.Proj %",
		func(): return "+%.0f%%" % (GameManager.player_ref.proj_speed_bonus * 100.0),
		func(s): GameManager.player_ref.proj_speed_bonus = maxf(0.0, GameManager.player_ref.proj_speed_bonus + s * 0.20)
	)
	_add_row("Alcance %",
		func(): return "+%.0f%%" % (GameManager.player_ref.range_bonus * 100.0),
		func(s): GameManager.player_ref.range_bonus = maxf(0.0, GameManager.player_ref.range_bonus + s * 0.20)
	)
	_add_row("Robo vida",
		func(): return "%.0f%%" % (GameManager.player_ref.life_steal * 100.0),
		func(s): GameManager.player_ref.life_steal = clampf(GameManager.player_ref.life_steal + s * 0.05, 0.0, 1.0)
	)
	_add_row("Cosecha %",
		func(): return "+%.0f%%" % (GameManager.player_ref.harvest * 100.0),
		func(s): GameManager.player_ref.harvest = maxf(0.0, GameManager.player_ref.harvest + s * 0.25)
	)

	for w in player.weapons:
		var sep := HSeparator.new()
		sep.custom_minimum_size = Vector2(0.0, 4.0)
		_vbox.add_child(sep)

		var wlabel := Label.new()
		wlabel.text = "[%s]" % w.weapon_id
		wlabel.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		_vbox.add_child(wlabel)

		var w_ref: Node2D = w
		_add_row("Cooldown",
			func(): return "%.3fs" % w_ref.fire_cooldown,
			func(s):
				if s > 0:
					w_ref.fire_cooldown = maxf(0.04, w_ref.fire_cooldown * 0.85)
				else:
					w_ref.fire_cooldown = minf(2.0, w_ref.fire_cooldown / 0.85)
		)
		_add_row("Daño",
			func(): return "%.2f" % w_ref.damage,
			func(s): w_ref.damage = maxf(0.1, w_ref.damage + s * (w_ref.damage * 0.2))
		)

		if w.weapon_id == "orbe":
			_add_row("Orbes",
				func(): return str(w_ref.orb_count),
				func(s):
					if s > 0:
						w_ref.add_orb()
					elif w_ref.orb_count > 1:
						w_ref.orb_count -= 1
						w_ref._fire_timers.resize(w_ref.orb_count)
						w_ref._orb_local.resize(w_ref.orb_count)
			)
			_add_row("Orb speed",
				func(): return "%.1f" % w_ref.orbit_speed,
				func(s): w_ref.orbit_speed = maxf(0.5, w_ref.orbit_speed + s * 0.5)
			)

	_bg.size.y = 32.0 + _rows.size() * 30.0 + player.weapons.size() * 34.0

func _add_row(label_text: String, getter: Callable, adjuster: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0.0, 28.0)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.custom_minimum_size = Vector2(100.0, 0.0)
	hbox.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(80.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	for sgn in [-1, 1]:
		var btn := Button.new()
		btn.text = "-" if sgn < 0 else "+"
		btn.custom_minimum_size = Vector2(36.0, 0.0)
		btn.pressed.connect(adjuster.bind(sgn))
		hbox.add_child(btn)

	_vbox.add_child(hbox)
	_rows.append({"label": val_lbl, "getter": getter})

func _process(_delta: float) -> void:
	if not visible:
		return
	for row in _rows:
		if GameManager.player_ref == null:
			break
		row["label"].text = row["getter"].call()
