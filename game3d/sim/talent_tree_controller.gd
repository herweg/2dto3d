extends Node2D

## Pantalla de talentos (Fase 3, fase3-alcance-v1.md sección 3) — "frame"
## pedido por el usuario (10-ago): mecánica de desbloqueo + árbol visual
## funcionando sobre TalentTreeDef (ver docs/fase3-talentos-motor.md para
## el estado del contenido — el mecanismo de acá no depende de cuántos
## nodos haya ni de qué digan).
##
## Persistente desde el sistema de guardado (10-ago, SaveManager autoload):
## el oro que gasta cada desbloqueo y qué nodos quedaron desbloqueados
## viven en SaveManager.state, no acá — esta pantalla lee/escribe ese
## estado, no es dueña de él (así lo ven MainMenu y una futura calibración
## de combate sin duplicar nada). El costo de cada nodo (1-2) sigue siendo
## placeholder — economía de progresión sin calibrar todavía
## (fase3-alcance-v1.md sección 2) — pero la moneda que lo paga ya es real.
##
## Sin conexión a combate todavía: cada nodo declara
## effect_scope/stat_id/modifier_value (TalentTreeDef) pero nada los lee —
## TowerStore/TowerSystem no se tocan en esta tarjeta.
##
## Mismo criterio "funcional, sin estilo" que el resto de la UI del
## proyecto (botón "Comenzar" de level_controller.gd, MainMenu). Sin
## Camera2D en esta escena — igual que MainMenu.tscn — así que las
## posiciones de TalentTreeDef.positions valen tanto para _draw() del root
## (líneas de prerequisito) como para los Button dentro del CanvasLayer
## (nodos): las dos coinciden en espacio de pantalla sin transformación de
## por medio.

const TREE_DEF := preload("res://data/talents_01.tres")
## 104, no 150 — la data real (31 nodos) usa 120px de separación horizontal
## entre hermanos de una misma rama; a 150 de ancho los botones se pisaban
## entre sí (visto en captura real). El texto completo de cada nodo va de
## tooltip, no en el botón — a esta densidad no entra igual.
const NODE_SIZE := Vector2(104, 34)

const COLOR_LOCKED := Color(0.42, 0.42, 0.45)
const COLOR_AVAILABLE := Color(0.90, 0.80, 0.20)
const COLOR_UNLOCKED := Color(0.25, 0.80, 0.35)
const LINE_LOCKED := Color(0.35, 0.35, 0.38, 1.0)
const LINE_UNLOCKED := Color(0.25, 0.70, 0.35, 1.0)

var _tree: TalentTreeDef
var _unlocked: Dictionary = {}  # id (String) -> true, espejo local de SaveManager para no leerlo en cada draw
var _node_buttons: Dictionary = {}  # id (String) -> Button
var _points_label: Label

func _ready() -> void:
	_tree = TREE_DEF
	# Cargar desbloqueos previos del save — un nodo ya pago en una sesión
	# anterior tiene que aparecer desbloqueado de entrada, no perderse.
	for id in SaveManager.state["unlocked_talent_ids"]:
		_unlocked[id] = true

	var layer := CanvasLayer.new()

	var title := Label.new()
	title.text = "Talentos"
	title.position = Vector2(20, 16)
	title.add_theme_font_size_override("font_size", 28)
	layer.add_child(title)

	_points_label = Label.new()
	_points_label.position = Vector2(20, 60)
	layer.add_child(_points_label)

	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.position = Vector2(20, 660)
	back_button.size = Vector2(120, 40)
	back_button.pressed.connect(_on_back_pressed)
	layer.add_child(back_button)

	for i in _tree.ids.size():
		var id := _tree.ids[i]
		var btn := Button.new()
		# Prefijo corto (no la etiqueta larga de antes, no entraba a 120px
		# de separación entre hermanos) para que la distinción global/
		# por-torreta que pidió el usuario se vea sin tener que pasar el
		# mouse — el detalle completo (stat + valor) va de tooltip.
		var scope_prefix := "[G]" if _tree.effect_scopes[i] == TalentTreeDef.EffectScope.GLOBAL else "[T%d]" % _tree.target_tower_types[i]
		btn.text = "%s %s" % [scope_prefix, _tree.display_names[i]] if _tree.stat_ids[i] != "none" else _tree.display_names[i]
		btn.clip_text = true
		btn.tooltip_text = _effect_summary(i)
		btn.add_theme_font_size_override("font_size", 9)
		btn.size = NODE_SIZE
		btn.position = _tree.positions[i] - NODE_SIZE * 0.5
		btn.pressed.connect(_on_node_pressed.bind(id))
		layer.add_child(btn)
		_node_buttons[id] = btn

	add_child(layer)
	_refresh_node_states()

	# Primera pasada: settings (mismo criterio que level_controller.gd —
	# "gold" tiene que aplicarse antes de cualquier "unlock" de la misma
	# invocación, sin depender del orden en la línea de comandos). Escribe
	# directo en SaveManager (ya está en save_path de test si esta corrida
	# tiene argumentos — ver save_manager.gd) para poder probar "no alcanza
	# el oro" o "sí alcanza" sin depender del oro real acumulado.
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2 and parts[0] == "gold":
			SaveManager.state["gold"] = parts[1].to_int()
			SaveManager.save_game()
	_refresh_node_states()

	# Segunda pasada: acciones, en orden — soporta varios "unlock=" en la
	# misma invocación para probar una cadena de desbloqueos.
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2 and parts[0] == "unlock":
			_try_unlock(parts[1])
		if arg == "screenshot-quit":
			await get_tree().process_frame
			await get_tree().process_frame
			if DisplayServer.get_name() != "headless":
				var img := get_viewport().get_texture().get_image()
				img.save_png("res://benchmark_results/talents_screenshot.png")
				print("[talents] screenshot guardado")
			print("[talents] listo — desbloqueados: %d/%d, oro: %d" % [_unlocked.size(), _tree.ids.size(), SaveManager.state["gold"]])
			get_tree().quit()
		if arg == "auto-back":
			# Equivalente headless/CLI de "Volver" — mismo criterio de
			# return-después-de-navegar que auto-start/auto-talents en
			# main_menu_controller.gd (ver ese archivo para el porqué).
			await get_tree().process_frame
			print("[talents] auto-back: volviendo a MainMenu.tscn")
			_on_back_pressed()
			return

func _effect_summary(i: int) -> String:
	if _tree.stat_ids[i] == "none":
		return "(sin efecto — nodo de entrada)"
	if _tree.effect_scopes[i] == TalentTreeDef.EffectScope.GLOBAL:
		return "GLOBAL: %s %+.2f" % [_tree.stat_ids[i], _tree.modifier_values[i]]
	return "Torreta %d: %s %+.2f" % [_tree.target_tower_types[i], _tree.stat_ids[i], _tree.modifier_values[i]]

## Único punto de desbloqueo — botón real y flag `unlock=<id>` (headless)
## pasan por acá, mismo criterio que _start_round()/_force_finish_round()
## de level_controller.gd. Chequea prerequisito y costo (contra el oro real
## de SaveManager, no un contador local); no hace nada si ya está
## desbloqueado, si el id no existe, si el padre no está desbloqueado, o si
## no alcanza el oro. SaveManager.spend_gold() persiste el gasto,
## SaveManager.unlock_talent() persiste el nodo — los dos antes de tocar el
## espejo local _unlocked, para que un desbloqueo real y uno rechazado no
## puedan divergir entre memoria y disco.
func _try_unlock(id: String) -> bool:
	if _unlocked.has(id):
		return false
	var i := _tree.index_of(id)
	if i == -1:
		push_error("[talents] nodo desconocido: " + id)
		return false
	var parent := _tree.parent_ids[i]
	if parent != "" and not _unlocked.has(parent):
		return false
	if not SaveManager.spend_gold(_tree.costs[i]):
		return false
	SaveManager.unlock_talent(id)
	_unlocked[id] = true
	_refresh_node_states()
	return true

func _on_node_pressed(id: String) -> void:
	_try_unlock(id)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## Recalcula color/disabled de cada nodo según su estado (bloqueado — gris,
## disponible — amarillo, desbloqueado — verde) y el texto de puntos.
## Redibuja las líneas de prerequisito (_draw()) para que reflejen el mismo
## estado.
func _refresh_node_states() -> void:
	_points_label.text = "Oro: %d" % SaveManager.state["gold"]
	for i in _tree.ids.size():
		var id := _tree.ids[i]
		var btn: Button = _node_buttons[id]
		if _unlocked.has(id):
			btn.self_modulate = COLOR_UNLOCKED
			btn.disabled = true
		else:
			var parent := _tree.parent_ids[i]
			var prereq_ok := parent == "" or _unlocked.has(parent)
			var can_afford: bool = _tree.costs[i] <= SaveManager.state["gold"]
			if prereq_ok and can_afford:
				btn.self_modulate = COLOR_AVAILABLE
				btn.disabled = false
			else:
				btn.self_modulate = COLOR_LOCKED
				btn.disabled = true
	queue_redraw()

func _draw() -> void:
	for i in _tree.ids.size():
		var parent := _tree.parent_ids[i]
		if parent == "":
			continue
		var pi := _tree.index_of(parent)
		if pi == -1:
			continue
		var color := LINE_UNLOCKED if (_unlocked.has(_tree.ids[i]) and _unlocked.has(parent)) else LINE_LOCKED
		draw_line(_tree.positions[pi], _tree.positions[i], color, 3.0)
