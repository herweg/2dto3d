extends Node

## Preferencias de UI persistentes (fase-3d-tarjetas-pantallas-v1.md,
## Tarjeta 5) — separado de SaveManager a propósito, mismo cuidado de
## vocabulario que ya separó stage_index de player_level: SaveManager es
## progreso de partida y "Tabula Rasa" lo borra a propósito; una
## preferencia de visualización (ej. "Mostrar FPS") no debería desaparecer
## cuando el jugador reinicia su progreso — son dos cosas distintas, dos
## archivos distintos.
##
## Mismo patrón de JSON en user:// y separación test/real que SaveManager
## (save_manager.gd) — corridas con argumentos de CLI (verificación) no
## deben ensuciar la preferencia real de quien juega este build sin
## argumentos.

const SETTINGS_PATH_REAL := "user://settings.json"
const SETTINGS_PATH_TEST := "user://settings_test.json"

const DEFAULT_STATE := {
	"show_fps": false,
}

var state: Dictionary = {}
var settings_path: String = SETTINGS_PATH_REAL

func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		settings_path = SETTINGS_PATH_TEST
	load_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		state = DEFAULT_STATE.duplicate(true)
		return
	var f := FileAccess.open(settings_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[settings] %s corrupto o con formato inesperado — se usa estado default" % settings_path)
		state = DEFAULT_STATE.duplicate(true)
		return
	state = DEFAULT_STATE.duplicate(true)
	for key in parsed:
		state[key] = parsed[key]

func save_settings() -> void:
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(state))
	f.close()

func set_show_fps(value: bool) -> void:
	state["show_fps"] = value
	save_settings()
