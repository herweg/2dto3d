extends CanvasLayer

const _PISTOLA_SCRIPT := preload("res://scripts/weapon_pistola.gd")
const _BACULO_SCRIPT  := preload("res://scripts/weapon_baculo.gd")
const _ORBE_SCRIPT    := preload("res://scripts/weapon_orbe.gd")
const _ARCO_SCRIPT    := preload("res://scripts/weapon_arco.gd")

const WEAPON_DEFS := {
	"pistola": {"label": "Pistola",  "desc": "Alta potencia, cadencia baja"},
	"baculo":  {"label": "Báculo",   "desc": "Magia en ráfaga continua"},
	"orbe":    {"label": "Orbe",     "desc": "Orbes que orbitan al personaje"},
	"arco":    {"label": "Arco",     "desc": "Flechas letales de largo alcance"},
}

const STAT_UPGRADES := [
	# Supervivencia
	{"id": "hp",          "label": "Salud máxima",    "desc": "+25 HP, cura 25",                "requires": ""},
	{"id": "regen",       "label": "Regeneración",    "desc": "+0.5 HP/s",                      "requires": ""},
	{"id": "armor",       "label": "Armadura",        "desc": "-1 de daño recibido",            "requires": ""},
	{"id": "dodge",       "label": "Esquiva",         "desc": "+5% chance de esquivar (máx 60%)","requires": ""},
	# Movimiento
	{"id": "speed",       "label": "Velocidad",       "desc": "+30 velocidad de movimiento",    "requires": ""},
	# Combate global
	{"id": "damage",      "label": "Daño",            "desc": "+15% daño de todas las armas",   "requires": ""},
	{"id": "atk_speed",   "label": "Cadencia",        "desc": "-10% cooldown global",           "requires": ""},
	{"id": "proj_speed",  "label": "Vel. proyectil",  "desc": "+20% velocidad de proyectiles",  "requires": ""},
	{"id": "range",       "label": "Alcance",         "desc": "+20% radio de detección",        "requires": ""},
	{"id": "life_steal",  "label": "Robo de vida",    "desc": "+5% daño infligido → HP",        "requires": ""},
	{"id": "harvest",     "label": "Cosecha",         "desc": "+25% XP ganada",                 "requires": ""},
	# Arma: Orbe
	{"id": "orbe_orb",      "label": "Orbe extra",       "desc": "Un orbe más (máx. 8)",           "requires": "orbe"},
	{"id": "orbe_cooldown", "label": "Cadencia orbe",    "desc": "20% más frecuente",              "requires": "orbe"},
	{"id": "orbe_orbit",    "label": "Vel. orbital",     "desc": "Los orbes orbitan más rápido",   "requires": "orbe"},
	# Arma: Pistola
	{"id": "pistola_damage","label": "Daño pistola",     "desc": "Daño ×1.5 por disparo",          "requires": "pistola"},
	{"id": "pistola_cd",    "label": "Cadencia pistola", "desc": "15% más frecuente",              "requires": "pistola"},
	# Arma: Báculo
	{"id": "baculo_damage", "label": "Daño báculo",      "desc": "+30% daño de magia",             "requires": "baculo"},
	{"id": "baculo_cd",     "label": "Cadencia báculo",  "desc": "20% más frecuente",              "requires": "baculo"},
	# Arma: Arco
	{"id": "arco_damage",   "label": "Daño arco",        "desc": "Daño ×1.6 por flecha",           "requires": "arco"},
	{"id": "arco_cd",       "label": "Cadencia arco",    "desc": "30% más frecuente",              "requires": "arco"},
]

# [{ btn, icon, name_lbl, desc_lbl }]
var _cards: Array[Dictionary] = []
var _current_picks: Array = []
var _items_img: Image = null

func _ready() -> void:
	layer = 8
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_items_img = load("res://assets/items.png").get_image()
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = PROCESS_MODE_ALWAYS
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.process_mode = PROCESS_MODE_ALWAYS
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-305.0, -240.0)
	vbox.custom_minimum_size = Vector2(610.0, 480.0)
	add_child(vbox)

	var title := Label.new()
	title.text = "¡ SUBE DE NIVEL !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UITheme.C_GOLD_HI)
	title.process_mode = PROCESS_MODE_ALWAYS
	UITheme.apply_font(title, true)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Elige una mejora"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	subtitle.process_mode = PROCESS_MODE_ALWAYS
	vbox.add_child(subtitle)

	_gap(vbox, 22)

	for i in 3:
		var card := _build_card(vbox, i)
		_cards.append(card)
		_gap(vbox, 8)

func _build_card(parent: Control, idx: int) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(610.0, 100.0)
	btn.process_mode = PROCESS_MODE_ALWAYS
	btn.pressed.connect(_on_button_pressed.bind(idx))

	var _mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg; s.border_color = border
		s.set_border_width_all(2); s.set_corner_radius_all(4)
		s.content_margin_left = 10; s.content_margin_right  = 10
		s.content_margin_top  = 8;  s.content_margin_bottom = 8
		return s
	btn.add_theme_stylebox_override("normal",  _mk.call(UITheme.C_PANEL_CARD, UITheme.C_GOLD))
	btn.add_theme_stylebox_override("hover",   _mk.call(Color(0.13, 0.10, 0.05), UITheme.C_GOLD_HI))
	btn.add_theme_stylebox_override("pressed", _mk.call(UITheme.C_PANEL, UITheme.C_GOLD))
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",         UITheme.C_TEXT)
	btn.add_theme_color_override("font_hover_color",   UITheme.C_GOLD_HI)
	btn.add_theme_color_override("font_pressed_color", UITheme.C_TEXT)

	parent.add_child(btn)

	# Layout inside button
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(82.0, 82.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(icon_rect)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	text_col.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	UITheme.apply_font(name_lbl, false)
	text_col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	text_col.add_child(desc_lbl)

	return {"btn": btn, "icon": icon_rect, "name": name_lbl, "desc": desc_lbl}

func _update_card(card: Dictionary, pick: Dictionary) -> void:
	card["name"].text = pick.get("label", "")
	card["desc"].text = pick.get("desc", "")
	card["icon"].texture = ItemsSheet.get_icon(pick["id"], _items_img)

func show_menu() -> void:
	if not GameManager.first_weapon_chosen:
		_show_weapon_picks()
	else:
		_show_mixed_picks()
	visible = true

func _show_weapon_picks() -> void:
	var ids: Array = WEAPON_DEFS.keys()
	ids.shuffle()
	_current_picks = []
	for id in ids.slice(0, 3):
		_current_picks.append({
			"id": id, "is_weapon": true,
			"label": WEAPON_DEFS[id]["label"],
			"desc":  WEAPON_DEFS[id]["desc"],
		})
	for i in 3:
		_update_card(_cards[i], _current_picks[i])

func _show_mixed_picks() -> void:
	var player := GameManager.player_ref
	var active_ids: Array = []
	if player:
		for w in player.weapons:
			active_ids.append(w.weapon_id)

	var pool: Array = []

	for id in WEAPON_DEFS.keys():
		if id not in active_ids:
			pool.append({"id": id, "is_weapon": true,
				"label": WEAPON_DEFS[id]["label"], "desc": WEAPON_DEFS[id]["desc"]})

	for upg in STAT_UPGRADES:
		if upg["requires"] == "" or upg["requires"] in active_ids:
			pool.append(upg)

	pool.shuffle()
	_current_picks = pool.slice(0, 3)
	for i in mini(3, _current_picks.size()):
		_update_card(_cards[i], _current_picks[i])

func _on_button_pressed(idx: int) -> void:
	if idx >= _current_picks.size():
		return
	var pick: Dictionary = _current_picks[idx]
	if pick.get("is_weapon", false):
		_apply_weapon(pick["id"])
	else:
		_apply_stat(pick["id"])
	visible = false
	get_tree().paused = false

func _apply_weapon(id: String) -> void:
	var player := GameManager.player_ref
	if player == null:
		return
	var script: Script = null
	match id:
		"pistola": script = _PISTOLA_SCRIPT
		"baculo":  script = _BACULO_SCRIPT
		"orbe":    script = _ORBE_SCRIPT
		"arco":    script = _ARCO_SCRIPT
	if script == null:
		return
	var weapon: Node2D = script.new()
	player.add_weapon(weapon)
	GameManager.first_weapon_chosen = true

func _apply_stat(id: String) -> void:
	var player := GameManager.player_ref
	if player == null:
		return
	match id:
		"hp":
			player.max_health += 25.0
			player.health = minf(player.health + 25.0, player.max_health)
		"regen":
			player.hp_regen += 0.5
		"armor":
			player.armor += 1.0
		"dodge":
			player.dodge = minf(0.60, player.dodge + 0.05)
		"speed":
			player.speed += 30.0
		"damage":
			player.damage_bonus += 0.15
		"atk_speed":
			player.attack_speed = minf(0.80, player.attack_speed + 0.10)
		"proj_speed":
			player.proj_speed_bonus += 0.20
		"range":
			player.range_bonus += 0.20
		"life_steal":
			player.life_steal += 0.05
		"harvest":
			player.harvest += 0.25
		"orbe_orb":
			var w := _get_weapon("orbe")
			if w: w.add_orb()
		"orbe_cooldown":
			var w := _get_weapon("orbe")
			if w: w.fire_cooldown = maxf(0.05, w.fire_cooldown * 0.80)
		"orbe_orbit":
			var w := _get_weapon("orbe")
			if w: w.orbit_speed += 0.5
		"pistola_damage":
			var w := _get_weapon("pistola")
			if w: w.damage *= 1.5
		"pistola_cd":
			var w := _get_weapon("pistola")
			if w: w.fire_cooldown = maxf(0.30, w.fire_cooldown * 0.85)
		"baculo_damage":
			var w := _get_weapon("baculo")
			if w: w.damage *= 1.3
		"baculo_cd":
			var w := _get_weapon("baculo")
			if w: w.fire_cooldown = maxf(0.04, w.fire_cooldown * 0.80)
		"arco_damage":
			var w := _get_weapon("arco")
			if w: w.damage *= 1.6
		"arco_cd":
			var w := _get_weapon("arco")
			if w: w.fire_cooldown = maxf(0.80, w.fire_cooldown * 0.70)

func _get_weapon(weapon_id: String) -> Node:
	var player := GameManager.player_ref
	if player == null:
		return null
	for w in player.weapons:
		if w.weapon_id == weapon_id:
			return w
	return null

func _gap(parent: Control, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	parent.add_child(c)
