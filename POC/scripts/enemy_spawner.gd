extends Node

const SPAWN_RADIUS       := 720.0
const BASE_INTERVAL      := 0.58
const MIN_INTERVAL       := 0.18
const ACCEL_EVERY        := 40.0
const ACCEL_FACTOR       := 0.88
const MAX_ACTIVE_ENEMIES := 80

# [min_wave, enemy_type, spawn_chance]
# Se evalúan en orden: mayor prioridad primero (Guardian → Chaman → Bruto).
# Si ninguno pasa su roll, se spawna Goblin.
const ELITE_UNLOCK := [
	[8, 3, 0.08],   # Guardian del Pantano desde oleada 8, 8%
	[5, 2, 0.12],   # Chaman Goblin desde oleada 5, 12%
	[2, 1, 0.18],   # Goblin Bruto desde oleada 2, 18%
]

var _interval: float    = BASE_INTERVAL
var _accel_accum: float = 0.0
var _timer: Timer       = null
var _enemy_pool: Node   = null

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = _interval
	_timer.timeout.connect(_spawn)
	add_child(_timer)
	_timer.start()

func _process(delta: float) -> void:
	if GameManager.is_game_over:
		_timer.stop()
		return
	_accel_accum += delta
	if _accel_accum >= ACCEL_EVERY:
		_accel_accum = 0.0
		_interval = maxf(MIN_INTERVAL, _interval * ACCEL_FACTOR)
		_timer.wait_time = _interval

func _get_spawn_type() -> int:
	var wave := int(GameManager.elapsed_time / GameManager.DIFF_INTERVAL)
	for entry in ELITE_UNLOCK:
		if wave >= entry[0] and randf() < entry[2]:
			return entry[1]
	return 0  # Goblin por defecto

func _spawn() -> void:
	if GameManager.is_game_over or GameManager.player_ref == null:
		return
	if _enemy_pool == null:
		_enemy_pool = get_tree().get_first_node_in_group("enemy_pool")
		if _enemy_pool == null:
			return
	if _enemy_pool.get_active_count() >= MAX_ACTIVE_ENEMIES:
		return
	var angle := randf_range(0.0, TAU)
	var pos   := GameManager.player_ref.global_position + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS
	_enemy_pool.spawn(pos, _get_spawn_type())
