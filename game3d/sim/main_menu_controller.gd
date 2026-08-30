extends Node2D

## Pantalla de inicio — mínima a propósito, mismo criterio que el resto de
## la UI de este proyecto (botón "Comenzar" de level_controller.gd):
## funcional, sin estilo, construida en _ready(). Objetivo real es no
## depender de arrancar siempre directo en Level.tscn para poder testear.
##
## Estado de partida (10-ago, SaveManager autoload) — status en la esquina
## para poder verificar a ojo que persiste entre sesiones sin abrir el
## JSON a mano, y botón "Tabula Rasa" para borrarlo todo. Pedido explícito
## del usuario: el botón va sin ningún texto que explique qué hace más
## allá de su nombre — a propósito, no un olvido — separado del resto con
## espacio de sobra para no aparecer como "un botón más" sin necesitar
## explicarlo con palabras.

var _status_label: Label

func _ready() -> void:
	var layer := CanvasLayer.new()

	var title := Label.new()
	title.text = "TowerDefense"
	title.position = Vector2(560, 220)
	title.add_theme_font_size_override("font_size", 32)
	layer.add_child(title)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 16)
	layer.add_child(_status_label)
	_refresh_status()

	# Viewport de 720px de alto (project.godot) — 6 botones a 50px de paso,
	# más el hueco de sobra antes de Tabula Rasa (ver abajo), entran sin
	# salirse de pantalla.
	var start_button := Button.new()
	start_button.text = "Start"
	start_button.position = Vector2(580, 300)
	start_button.size = Vector2(140, 44)
	start_button.pressed.connect(_on_start_pressed)
	layer.add_child(start_button)

	var talents_button := Button.new()
	talents_button.text = "Talentos"
	talents_button.position = Vector2(580, 350)
	talents_button.size = Vector2(140, 44)
	talents_button.pressed.connect(_on_talents_pressed)
	layer.add_child(talents_button)

	# Prueba de Estrés — navega a StressMenu.tscn, que a su vez lanza
	# Level.tscn (el camino de render real) con un preset de población.
	var stress_button := Button.new()
	stress_button.text = "Prueba de Estrés"
	stress_button.position = Vector2(580, 400)
	stress_button.size = Vector2(140, 44)
	stress_button.pressed.connect(_on_stress_pressed)
	layer.add_child(stress_button)

	# Configuración — hueco mínimo para "Mostrar FPS", con lugar para crecer.
	var config_button := Button.new()
	config_button.text = "Configuración"
	config_button.position = Vector2(580, 450)
	config_button.size = Vector2(140, 44)
	config_button.pressed.connect(_on_config_pressed)
	layer.add_child(config_button)

	var exit_button := Button.new()
	exit_button.text = "Exit"
	exit_button.position = Vector2(580, 500)
	exit_button.size = Vector2(140, 44)
	exit_button.pressed.connect(_on_exit_pressed)
	layer.add_child(exit_button)

	var tabula_rasa_button := Button.new()
	tabula_rasa_button.text = "Tabula Rasa"
	tabula_rasa_button.position = Vector2(580, 580)
	tabula_rasa_button.size = Vector2(140, 44)
	tabula_rasa_button.pressed.connect(_on_tabula_rasa_pressed)
	layer.add_child(tabula_rasa_button)

	add_child(layer)

	# Verificación visual sin depender de mirar la ventana en vivo — mismo
	# criterio que level_controller.gd/stress_main.gd (Mesa de Developers,
	# revisión del commit f0cfa56). Esta pantalla no lo tenía.
	for arg in OS.get_cmdline_user_args():
		if arg == "tabula-rasa":
			# Equivalente headless/CLI del botón — no navega, se puede
			# combinar sin riesgo con otros flags de esta misma pantalla.
			_on_tabula_rasa_pressed()
		var parts := arg.split("=")
		if parts.size() == 2 and parts[0] == "set-level":
			# No hay ninguna mecánica que suba de nivel todavía
			# (fase3-alcance-v1.md sección 2, sin calibrar) — este flag
			# solo existe para probar que player_level persiste, no
			# simula progresión real.
			SaveManager.state["player_level"] = parts[1].to_int()
			SaveManager.save_game()
			_refresh_status()
		if arg == "screenshot-quit":
			await get_tree().process_frame
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				var img := get_viewport().get_texture().get_image()
				img.save_png("res://benchmark_results/mainmenu_screenshot.png")
				print("[mainmenu] screenshot guardado")
			get_tree().quit()
		if arg == "auto-start" or arg == "auto-talents" or arg == "auto-stress" or arg == "auto-config":
			# Equivalente headless/CLI del click en "Start"/"Talentos" — para
			# probar la transición de escena real en vez de solo revisarla
			# por código. Deferido a próximo frame: un click real dispara la
			# señal después de que _ready() ya terminó de agregar nodos, no
			# durante — llamar change_scene_to_file() en el medio de eso
			# tira "Parent node is busy adding/removing children". `return`
			# después: change_scene_to_file() ya deja este nodo fuera del
			# árbol, seguir iterando args acá (ej. screenshot-quit de esta
			# misma pantalla) pega contra un get_tree() nulo — no es un caso
			# real (un click no dispara dos señales a la vez), pero si se
			# combinan estos flags de prueba en la misma invocación sí.
			await get_tree().process_frame
			if arg == "auto-start":
				print("[mainmenu] auto-start: cargando Level.tscn")
				_on_start_pressed()
			elif arg == "auto-stress":
				print("[mainmenu] auto-stress: cargando StressMenu.tscn")
				_on_stress_pressed()
			elif arg == "auto-config":
				print("[mainmenu] auto-config: cargando ConfigMenu.tscn")
				_on_config_pressed()
			else:
				print("[mainmenu] auto-talents: cargando TalentTree.tscn")
				_on_talents_pressed()
			return

## Siempre el primer nivel — no hay selector de pantallas todavía
## (sin tarjeta de motor asignada aún).
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Level.tscn")

func _on_stress_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/StressMenu.tscn")

func _on_config_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ConfigMenu.tscn")

func _on_talents_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TalentTree.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

## "Tabula Rasa" (pedido del usuario, 10-ago) — sin confirmación, a
## propósito (mismo pedido: nada que explique qué hace más allá del
## nombre). Refresca el status en pantalla al toque, para que el efecto
## sea visible sin tener que salir y volver a entrar.
func _on_tabula_rasa_pressed() -> void:
	SaveManager.wipe_all_data()
	_refresh_status()

func _refresh_status() -> void:
	var s := SaveManager.state
	# Planeta: stage_index+1 (1-5), tal como pide fase3-tarjeta-ganable-v1.md
	# — el índice guardado es 0-4, pero mostrar "Planeta 0" confundiría a
	# cualquiera que no sepa que es 0-based.
	_status_label.text = "Nivel: %d   Oro: %d   Bajas totales: %d   Planeta: %d/5" % [s["player_level"], s["gold"], s["total_kills"], int(s["stage_index"]) + 1]
