class_name UITheme
extends RefCounted

# ── Paleta dark fantasy ──────────────────────────────────────
const C_BG_DEEP    := Color(0.027, 0.024, 0.055)  # #07060E
const C_PANEL      := Color(0.074, 0.059, 0.031)  # #130F08
const C_PANEL_CARD := Color(0.090, 0.072, 0.038)  # tarjetas upgrade, ligeramente más claro
const C_BORDER_DK  := Color(0.239, 0.133, 0.031)  # #3D2208
const C_GOLD       := Color(0.659, 0.439, 0.125)  # #A87020
const C_GOLD_HI    := Color(0.831, 0.627, 0.251)  # #D4A040
const C_TEXT       := Color(0.918, 0.847, 0.690)  # #EAD8B0  parchment
const C_TEXT_MUTED := Color(0.541, 0.451, 0.333)  # #8A7355
const C_BLOOD      := Color(0.478, 0.063, 0.063)  # #7A1010  game over

# ── Fuentes (se cargan bajo demanda) ─────────────────────────
static var _font_bold: Font = null
static var _font_reg:  Font = null
static var _fonts_loaded: bool = false

static func _load_fonts() -> void:
	if _fonts_loaded:
		return
	_fonts_loaded = true
	if ResourceLoader.exists("res://assets/fonts/Cinzel-Bold.ttf"):
		_font_bold = load("res://assets/fonts/Cinzel-Bold.ttf")
	if ResourceLoader.exists("res://assets/fonts/Cinzel-Regular.ttf"):
		_font_reg = load("res://assets/fonts/Cinzel-Regular.ttf")
	if _font_bold and _font_reg == null:
		_font_reg = _font_bold

static func apply_font(ctrl: Control, bold: bool = false) -> void:
	_load_fonts()
	var f: Font = _font_bold if bold else _font_reg
	if f:
		ctrl.add_theme_font_override("font", f)

# ── Helpers de StyleBox ───────────────────────────────────────
static func _flat(bg: Color, border: Color, margins: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	if margins:
		s.content_margin_left   = 12
		s.content_margin_right  = 12
		s.content_margin_top    = 6
		s.content_margin_bottom = 6
	return s

# ── Button factory ────────────────────────────────────────────
static func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  _flat(C_PANEL,           C_GOLD))
	btn.add_theme_stylebox_override("hover",   _flat(Color(0.11, 0.09, 0.05), C_GOLD_HI))
	btn.add_theme_stylebox_override("pressed", _flat(Color(0.05, 0.04, 0.02), C_GOLD))
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",         C_TEXT)
	btn.add_theme_color_override("font_hover_color",   C_GOLD_HI)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)
	apply_font(btn, false)

static func styled_button(text: String, w: float, h: float,
		font_size: int = 18, always: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", font_size)
	if always:
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
	style_button(btn)
	return btn

# ── Panel oscuro con borde dorado ─────────────────────────────
static func dark_panel(w: float, h: float) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = C_PANEL
	panel.custom_minimum_size = Vector2(w, h)
	return panel

# ── Separador decorativo ─────────────────────────────────────
static func gold_sep(parent: Control, font_size: int = 14) -> void:
	var lbl := Label.new()
	lbl.text = "── ✦ ──"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", C_GOLD)
	lbl.modulate.a = 0.55
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(lbl)
