extends Node

## Autoload chico — pasa un preset de stress-test elegido en el menú
## (StressMenu.tscn) a Level3D.tscn a través de un change_scene_to_file(),
## que no lleva argumentos de CLI (fase-3d-tarjetas-pantallas-v1.md sección
## 4: "sumar una versión mínima en UI... para que sea usable jugando, no
## solo por terminal"). `pending` se consume una sola vez (level_controller_3d.gd
## lo apaga al leerlo) para que volver al menú y entrar por "Comenzar" en un
## nivel normal no reactive stress-test por accidente.

var pending := false
var towers := 30
var enemies := 300

func set_preset(p_towers: int, p_enemies: int) -> void:
	pending = true
	towers = p_towers
	enemies = p_enemies

func consume() -> Dictionary:
	pending = false
	return {"towers": towers, "enemies": enemies}
