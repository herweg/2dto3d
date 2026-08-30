extends CanvasLayer

## Overlay global de FPS — autoload-escena (mismo mecanismo que
## StressLaunchConfig: un autoload puede ser una escena completa, no solo
## un script) para que aparezca en todas las pantallas (MainMenu, Level,
## StressMenu, ConfigMenu, TalentTree) sin duplicarlo a mano en cada una —
## un autoload vive fuera del árbol de la escena actual, sobrevive a
## change_scene_to_file().
##
## Costo: un Label, texto actualizado cada REFRESH_INTERVAL (no por frame —
## no hace ninguna diferencia de costo real a esta escala, pero un número
## que cambia cada frame es más ruidoso de leer que uno estable). Nada
## comparable a lo que este proyecto ya midió con miles de instancias — el
## checklist de la tarjeta pide confirmar esto con captura contra el
## escenario oficial igual, no darlo por sentado.

const REFRESH_INTERVAL := 0.25

var _label: Label
var _timer := 0.0

func _ready() -> void:
	layer = 100  # por encima de cualquier CanvasLayer de HUD de pantalla (level_controller*.gd usa el default, capa 1)
	_label = Label.new()
	_label.text = "FPS: --"
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)
	_position_label()
	get_viewport().size_changed.connect(_position_label)

	# CLI (fase-3d-tarjetas-pantallas-v1.md sección 5, "todo alcanzable por
	# CLI además de por click") — override en memoria, no persiste (mismo
	# criterio que otros overrides de este proyecto, ej. `lives=`).
	for arg in OS.get_cmdline_user_args():
		if arg == "show-fps=1":
			Settings.state["show_fps"] = true
		elif arg == "show-fps=0":
			Settings.state["show_fps"] = false

	_refresh()

func _position_label() -> void:
	var vp_w: float = get_viewport().get_visible_rect().size.x
	_label.position = Vector2(vp_w - 90.0, 8.0)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < REFRESH_INTERVAL:
		return
	_timer = 0.0
	_refresh()

func _refresh() -> void:
	_label.visible = Settings.state.get("show_fps", true)
	if _label.visible:
		_label.text = "FPS: %d" % int(Performance.get_monitor(Performance.TIME_FPS))
