extends Node2D

## Pantalla de inicio (pedido del usuario, 09-ago) — mínima a propósito,
## mismo criterio que el resto de la UI de este proyecto (botón "Comenzar"
## de level_controller.gd): funcional, sin estilo, construida en _ready(),
## la pantalla real es Fase 4. Objetivo real es no depender de arrancar
## siempre directo en Level1.tscn para poder testear.

func _ready() -> void:
	var layer := CanvasLayer.new()

	var title := Label.new()
	title.text = "TowerDefense"
	title.position = Vector2(560, 220)
	title.add_theme_font_size_override("font_size", 32)
	layer.add_child(title)

	var start_button := Button.new()
	start_button.text = "Start"
	start_button.position = Vector2(580, 320)
	start_button.size = Vector2(120, 44)
	start_button.pressed.connect(_on_start_pressed)
	layer.add_child(start_button)

	var exit_button := Button.new()
	exit_button.text = "Exit"
	exit_button.position = Vector2(580, 380)
	exit_button.size = Vector2(120, 44)
	exit_button.pressed.connect(_on_exit_pressed)
	layer.add_child(exit_button)

	add_child(layer)

	# Verificación visual sin depender de mirar la ventana en vivo — mismo
	# criterio que level_controller.gd/stress_main.gd (Mesa de Developers,
	# revisión del commit f0cfa56). Esta pantalla no lo tenía.
	for arg in OS.get_cmdline_user_args():
		if arg == "screenshot-quit":
			await get_tree().process_frame
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				var img := get_viewport().get_texture().get_image()
				img.save_png("res://benchmark_results/mainmenu_screenshot.png")
				print("[mainmenu] screenshot guardado")
			get_tree().quit()
		if arg == "auto-start":
			# Equivalente headless/CLI del click en "Start" — para probar la
			# transición de escena real en vez de solo revisarla por código.
			# Deferido a próximo frame: un click real dispara la señal
			# después de que _ready() ya terminó de agregar nodos, no
			# durante — llamar change_scene_to_file() en el medio de eso
			# tira "Parent node is busy adding/removing children".
			await get_tree().process_frame
			print("[mainmenu] auto-start: cargando Level1.tscn")
			_on_start_pressed()

## Siempre el primer nivel — no hay selector de pantallas todavía
## (fase3-alcance-v1.md sección 2.3, sin tarjeta de motor asignada aún).
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
