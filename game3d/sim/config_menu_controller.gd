extends Node2D

## Pantalla de Configuración (fase-3d-tarjetas-pantallas-v1.md, Tarjeta 5) —
## mínima a propósito, "solo el hueco para este control, no un panel
## completo" (tal como pide la tarjeta): un único CheckBox por ahora, con
## lugar para crecer. Mismo criterio funcional-sin-estilo que el resto de
## la UI de este proyecto.

func _ready() -> void:
	var layer := CanvasLayer.new()

	var title := Label.new()
	title.text = "Configuración"
	title.position = Vector2(540, 220)
	title.add_theme_font_size_override("font_size", 28)
	layer.add_child(title)

	var show_fps_check := CheckBox.new()
	show_fps_check.text = "Mostrar FPS"
	show_fps_check.position = Vector2(540, 300)
	show_fps_check.button_pressed = Settings.state.get("show_fps", true)
	show_fps_check.toggled.connect(_on_show_fps_toggled)
	layer.add_child(show_fps_check)

	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.position = Vector2(540, 380)
	back_button.size = Vector2(120, 44)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	layer.add_child(back_button)

	add_child(layer)

	# Verificación headless/CLI (mismo criterio que el resto del proyecto).
	for arg in OS.get_cmdline_user_args():
		if arg == "toggle-show-fps":
			show_fps_check.button_pressed = not show_fps_check.button_pressed
		if arg == "auto-exit-to-menu":
			get_tree().change_scene_to_file.call_deferred("res://scenes/MainMenu.tscn")

func _on_show_fps_toggled(pressed: bool) -> void:
	Settings.set_show_fps(pressed)
