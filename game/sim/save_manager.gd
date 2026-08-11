extends Node

## Estado de partida persistente (Fase 3, fase3-alcance-v1.md secciones 2 y
## 4 punto 3 — "implica que Fase 3 necesita un sistema de guardado/carga de
## punta a punta"). Pedido directo del usuario, 10-ago: guardar monstruos
## eliminados, nivel de jugador, estado del árbol de talentos, oro (única
## moneda por ahora) — más "Tabula Rasa" para borrar todo.
##
## JSON en user://, no Resource/.tres — esto es data generada en tiempo de
## ejecución (no autoría de diseño como LevelDef/TalentTreeDef), JSON es
## el camino estándar de Godot para partidas guardadas y evita el lío de
## class_name/rescan que ya mordió al árbol de talentos
## (fase3-talentos-motor.md sección 5.1).
##
## Autoload (project.godot, [autoload]) — MainMenu, Level1 y TalentTree
## necesitan leer/escribir el mismo estado, y change_scene_to_file() no
## pasa datos entre escenas; un autoload es la forma estándar de Godot de
## compartir estado entre pantallas sin acoplarlas a mano.

const SAVE_PATH_REAL := "user://savegame.json"
## Corridas de prueba (cualquier invocación con argumentos de línea de
## comandos — nada de lo que exporta este juego hoy usa argumentos para
## jugar de verdad) escriben acá, no en el save real — evita que la
## regresión de Motor deje oro/talentos falsos en la partida de quien
## juegue este build sin argumentos.
const SAVE_PATH_TEST := "user://savegame_test.json"

const DEFAULT_STATE := {
	"player_level": 1,
	"gold": 0,
	"total_kills": 0,
	"unlocked_talent_ids": [],
}

var state: Dictionary = {}
var save_path: String = SAVE_PATH_REAL

func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		save_path = SAVE_PATH_TEST
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		state = DEFAULT_STATE.duplicate(true)
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[save] %s corrupto o con formato inesperado — se usa estado default" % save_path)
		state = DEFAULT_STATE.duplicate(true)
		return
	# Merge sobre el default, no reemplazo directo — un save viejo al que
	# se le agregó un campo nuevo (ej. una partida antes de esta tarjeta)
	# no debe faltarle una clave que el resto del código asume presente.
	state = DEFAULT_STATE.duplicate(true)
	for key in parsed:
		state[key] = parsed[key]

func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(state))
	f.close()

## "Tabula Rasa" (pedido del usuario, 10-ago) — a propósito sin
## confirmación ni explicación en la UI, pedido explícito. Vuelve al
## estado default y lo persiste — no alcanza con resetear en memoria, la
## próxima carga tiene que ver lo mismo.
func wipe_all_data() -> void:
	state = DEFAULT_STATE.duplicate(true)
	save_game()
	print("[save] Tabula Rasa — estado de partida borrado (%s)" % save_path)

func add_gold(amount: int) -> void:
	state["gold"] += amount
	save_game()

func spend_gold(amount: int) -> bool:
	if state["gold"] < amount:
		return false
	state["gold"] -= amount
	save_game()
	return true

func add_kills(amount: int) -> void:
	state["total_kills"] += amount
	save_game()

func is_talent_unlocked(id: String) -> bool:
	return state["unlocked_talent_ids"].has(id)

func unlock_talent(id: String) -> void:
	if not is_talent_unlocked(id):
		state["unlocked_talent_ids"].append(id)
		save_game()
