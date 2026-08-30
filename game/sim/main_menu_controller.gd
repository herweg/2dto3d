extends Node2D

## Pantalla de inicio (pedido del usuario, 09-ago) — mínima a propósito,
## mismo criterio que el resto de la UI de este proyecto (botón "Comenzar"
## de level_controller.gd): funcional, sin estilo, construida en _ready(),
## la pantalla real es Fase 4. Objetivo real es no depender de arrancar
## siempre directo en Level1.tscn para poder testear.
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

	var start_button := Button.new()
	start_button.text = "Start"
	start_button.position = Vector2(580, 320)
	start_button.size = Vector2(120, 44)
	start_button.pressed.connect(_on_start_pressed)
	layer.add_child(start_button)

	var talents_button := Button.new()
	talents_button.text = "Talentos"
	talents_button.position = Vector2(580, 380)
	talents_button.size = Vector2(120, 44)
	talents_button.pressed.connect(_on_talents_pressed)
	layer.add_child(talents_button)

	# Prueba de Estrés (fase-3d-tarjetas-pantallas-v1.md, Tarjeta 4) — antes
	# solo alcanzable por CLI (poc_3d_bench.gd). Navega a StressMenu.tscn,
	# que a su vez lanza Level3D.tscn (el camino de render real, Tarjeta 1)
	# con un preset de población.
	var stress_button := Button.new()
	stress_button.text = "Prueba de Estrés"
	stress_button.position = Vector2(580, 440)
	stress_button.size = Vector2(140, 44)
	stress_button.pressed.connect(_on_stress_pressed)
	layer.add_child(stress_button)

	# Recomendado, no obligatorio (fase-3d-tarjetas-pantallas-v1.md sección
	# 3): dejar la versión 2D alcanzable mientras se termina de verificar la
	# 3D — mismo criterio de verificación incremental que ya usó este
	# proyecto (backend nativo, dirección fija, etc.), punto de comparación
	# en vez de reemplazo de un saque. Sin estilo especial a propósito —
	# botón de desarrollo, no una opción real de juego.
	var legacy_button := Button.new()
	legacy_button.text = "2D (legacy)"
	legacy_button.position = Vector2(580, 500)
	legacy_button.size = Vector2(120, 44)
	legacy_button.pressed.connect(_on_start_2d_pressed)
	layer.add_child(legacy_button)

	var exit_button := Button.new()
	exit_button.text = "Exit"
	exit_button.position = Vector2(580, 560)
	exit_button.size = Vector2(120, 44)
	exit_button.pressed.connect(_on_exit_pressed)
	layer.add_child(exit_button)

	var tabula_rasa_button := Button.new()
	tabula_rasa_button.text = "Tabula Rasa"
	tabula_rasa_button.position = Vector2(580, 660)
	tabula_rasa_button.size = Vector2(120, 44)
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
		if arg == "auto-start" or arg == "auto-talents" or arg == "auto-start-2d" or arg == "auto-stress":
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
				print("[mainmenu] auto-start: cargando Level3D.tscn")
				_on_start_pressed()
			elif arg == "auto-start-2d":
				print("[mainmenu] auto-start-2d: cargando Level1.tscn")
				_on_start_2d_pressed()
			elif arg == "auto-stress":
				print("[mainmenu] auto-stress: cargando StressMenu.tscn")
				_on_stress_pressed()
			else:
				print("[mainmenu] auto-talents: cargando TalentTree.tscn")
				_on_talents_pressed()
			return

## Siempre el primer nivel — no hay selector de pantallas todavía
## (fase3-alcance-v1.md sección 2.3, sin tarjeta de motor asignada aún).
## Apunta a la pantalla 3D real (fase-3d-tarjetas-pantallas-v1.md, Tarjeta
## 3 — único cambio real de esta tarjeta en este archivo) desde el pivot a
## 3D; Level1.tscn (2D) sigue existiendo, alcanzable por "2D (legacy)".
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Level3D.tscn")

func _on_start_2d_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_stress_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/StressMenu.tscn")

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
