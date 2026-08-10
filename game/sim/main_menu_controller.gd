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

## Siempre el primer nivel — no hay selector de pantallas todavía
## (fase3-alcance-v1.md sección 2.3, sin tarjeta de motor asignada aún).
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
