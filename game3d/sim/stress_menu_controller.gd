extends Node2D

## Prueba de estrés integrada al menú del juego — lanza el camino de render
## REAL del juego (Level.tscn / level_controller.gd), no un standalone
## aparte, para no medir un camino que el jugador no juega (ver
## versionado.md). Presets nada más, sin slider fino — los controles finos
## de población siguen disponibles por CLI (`stress-towers=`/
## `stress-enemies=`, etc.) para diagnóstico, esta pantalla es la versión
## usable jugando.

func _ready() -> void:
	var layer := CanvasLayer.new()

	var title := Label.new()
	title.text = "Prueba de Estrés"
	title.position = Vector2(500, 160)
	title.add_theme_font_size_override("font_size", 28)
	layer.add_child(title)

	var real_button := Button.new()
	real_button.text = "Escala real (30 torres / 300 enemigos)"
	real_button.position = Vector2(460, 260)
	real_button.size = Vector2(360, 44)
	real_button.pressed.connect(func(): _launch(30, 300))
	layer.add_child(real_button)

	# 120/2400 — escenario "oficial" (×1,2 de margen sobre el objetivo de
	# escala real), ver versionado.md.
	var official_button := Button.new()
	official_button.text = "Escala oficial ×1,2 (120 torres / 2.400 enemigos)"
	official_button.position = Vector2(460, 320)
	official_button.size = Vector2(360, 44)
	official_button.pressed.connect(func(): _launch(120, 2400))
	layer.add_child(official_button)

	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.position = Vector2(460, 400)
	back_button.size = Vector2(160, 44)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	layer.add_child(back_button)

	add_child(layer)

	# Verificación headless/CLI (mismo criterio que el resto del proyecto).
	for arg in OS.get_cmdline_user_args():
		if arg == "auto-launch-real":
			await get_tree().process_frame
			_launch(30, 300)
			return
		if arg == "auto-launch-official":
			await get_tree().process_frame
			_launch(120, 2400)
			return

func _launch(towers: int, enemies: int) -> void:
	StressLaunchConfig.set_preset(towers, enemies)
	get_tree().change_scene_to_file("res://scenes/Level.tscn")
